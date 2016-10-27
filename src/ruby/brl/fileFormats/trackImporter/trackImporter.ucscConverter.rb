#!/usr/bin/env ruby
require 'json'
require 'brl/util/textFileUtil'
require 'brl/util/util'

# == Overview.
# This class attempts to convert data that it obtains from the UCSC database and
#  turn it into the LFF Format that Genboree uses
#
#
module BRL; module TrackImporter
    class UCSCConverter
      # CONSTRUCTOR. Creates an instance of the importer class and completes the
      # initial configuration.
      #
      # [+optsHash+]  A set of configuration variables.
      #               * --class  = Name of the LFFClass
      #               * --type  = Name of the LFFType
      #               * --subtype  = Name of the LFFSubType
      #               * --configFile  = Configuration File To use
      #               * --inputFile  = Data File to get the UCSC information
      #               * --outputFile  = Output file to write the converted information
      # [+returns+]   Instance of +ImporterClass+
      def initialize()
      end

      # Takes the parameters that have been passed in and turns them into class
      #  variables
      # [+returns+]   nothing
      def setParameters()
        @trackData.lffClass = @optsHash['--class']
        @trackData.lffType = @optsHash['--type']
        @trackData.lffSubType = @optsHash['--subtype']
        @trackData.configFile = @optsHash['--configFile']
        @trackData.mappingFile = @optsHash['--inputFile']
        @trackData.dataFile = @optsHash['--dataFile']
        @trackData.outputFile = @optsHash['--outputFile']
      end

      # Attempts to convert the UCSC data into the LFF Format using the given
      # information using the following steps
      # * Read the SQL and Configuration File
      # * Assign different UCSC columns to the proper LFF columns
      # * Convert the data from the UCSC data file to the LFF file
      # [+returns+]   Nothing
      def run(trackData)
        @trackData = trackData
        
        #load in configuration file and convert it into a Hash
        jsonFile = File.new( @trackData.configFile )
        jsonData = jsonFile.read

        configHash = JSON.parse(jsonData)

        #--------------------------------
        #Find properties for table to be converted
        #--------------------------------
        hashFields = configHash['hashfields']
        defaultValues = configHash['defaultValues']
        ignoreColumns = configHash['excludeColumns']

        hashTemplate = Hash.new
        #--------------------------------
        #Parse the schema to find mappings between field names and column numbers
        #--------------------------------

        reader = BRL::Util::TextReader.new(@trackData.mappingFile)

        boParse = 0
        positionCount = 0

        reader.each { | line |
          if(line =~ /CREATE\sTABLE/)
            boParse = 1
          elsif((line =~ /KEY/) or (line =~ /()\sENGINE/))
            boParse = 0
          elsif(boParse == 1)
            match = false
            arrSplit = line.strip.split(/\s+/)
            fieldName = arrSplit[0]
            fieldName.gsub!("`","")

            #ignore certain fields
            if(ignoreColumns.include?(fieldName))
              hashTemplate[positionCount] = "IGNORE"
            else #Search for a field
              hashFields.each { |key, value|
                value.each { |search|
                  if(search.nil? and match == false)
                    hashTemplate[positionCount] = "DEFAULT"
                  elsif(search == fieldName)
                    hashTemplate[positionCount] = key
                    match = true
                  end
                }
              }
              if(!match)
                hashTemplate[positionCount] = "AVP=" + fieldName
              end
            end
            positionCount += 1
          end
        }
        reader.close
        #--------------------------------
        #Ensure all required fields are found
        #--------------------------------
        hashFields.each { |key, value|
          hasNull = false
          value.each { |search|
            hasNull = true if(search.class.to_s == "NilClass")
          }

          raise "Required field #{key} not present" unless(hasNull or hashTemplate.has_value?(key))
        }

        #--------------------------------
        #Parse the data file to generate lff records
        #--------------------------------

        avpHash = Hash.new

        reader = BRL::Util::TextReader.new(@trackData.dataFile)

        writer = BRL::Util::TextWriter.new("#{@trackData.outputFile}",  "w", 0)

        reader.each { | line |
          arrSplit = line.strip.split(/\t/)

          #Reset to DefaultValues
          lffClass = @trackData.lffClass
          name = defaultValues['name']
          lffType = @trackData.lffType
          lffSubtype = @trackData.lffSubType
          chrom = defaultValues['chrom']
          start = defaultValues['start']
          stop = defaultValues['stop']
          strand = defaultValues['strand']
          phase = defaultValues['phase']
          score = defaultValues['score']
          qStart = defaultValues['qStart']
          qStop = defaultValues['qStop']
          avp = defaultValues['attribute-comments']
          freeformComments = defaultValues["freeform-comments"]

          #Parse using template
          arrSplit.each_with_index { |data, count|
            case hashTemplate[count].to_s
            when "lffChrom"
              chrom = data.to_s
            when "lffStart"
              start = data.to_s
            when "lffStop"
              stop = data.to_s
            when "lffName"
              name = data.to_s
            when "lffStrand"
              strand = data.to_s
            when "lffPhase"
              phase = data.to_s
            when "lffScore"
              score = data.to_s
            when "lffQstart"
              qStart = data.to_s
            when "lffQstop"
              qStop = data.to_s
            when /^AVP/
              if avp == defaultValues['attribute-comments']
                avp = ''
              end
              attribute = "#{hashTemplate[count].gsub("AVP=","")}"
              avpHash[attribute] = data;
            when "lffFreeFormComment"
              freeformComments = data.to_s
            end
          }

          #Special Cases and Formatting
          #class

          #name
          if(configHash['name'] != nil)
            nameAction = configHash['name']
            if(nameAction == "prepend with chromosome number")
              name = chrom.gsub("chr", "") + name
            end
          end
          if(name == '.')
            name = "#{chrom}:#{start}-#{stop}"
          end

          #type

          #subtype

          #ref

          #start
          start = start.to_i + 1

          #stop
          if(start == stop)
            stop = stop.to_i + 1
          end

          #Strand

          #Phase

          #Score
          if(configHash['score'] != nil)
            scoreHash = configHash['score']
            scoreHash.each { |key, value|
              if(avpHash.has_key?(key))
                avpValue = avpHash[key]
                value.each { |attribute, newScore|
                  if(avpValue == attribute)
                    score = newScore
                  end
                }
              end

            }
          end
          #tStart

          #tEnd

          #AVPs
          if(configHash['avp'] != nil)
            avpAction = configHash['avp']
            if(avpAction == "replace gieStain with bandType")
              avpHash["bandType"] = avpHash["gieStain"]
              avpHash.delete("gieStain")
            end
          end

          avpHash.each { |attribute, value|
            attribute.strip!
            value.strip!
            if(not ((attribute == '') or (value =='')))
              value.gsub!(";",",")
              avp += "#{attribute}=#{value}; "
            end
          }

          #Sequence

          #Free Form Comments

          #Blocks inside individual entries
          blockHit = false
          withEndBlock = configHash['withEndBlock']
          withEndBlock.each { |key, value|
            #Deals with gene exons
            if(avpHash.has_key?(key) and not blockHit)
              blockHit = true

              arrExonStarts = ""
              arrExonEnds = ""

              exonStart = value["start"]
              exonStart.each { |key|

                if(avpHash.has_key?(key))
                  arrExonStarts = avpHash[key].split(/,/)
                end
              }
              exonStop = value["stop"]
              exonStop.each { |key|
                if(avpHash.has_key?(key))
                  arrExonEnds = avpHash[key].split(/,/)
                end
              }

              exxonCount = 0
              arrExonStarts.each { |exonStart|
                exonStart = exonStart.to_i + 1
                #puts "#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{exonStart}\t#{arrExonEnds[i]}\t#{strand}\t#{phase}\t#{score}\t#{qStart}\t#{qStop}\t#{avp}\t#{freeformComments}"
                writer.puts("#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{exonStart}\t#{arrExonEnds[exxonCount]}\t#{strand}\t#{phase}\t#{score}\t#{qStart}\t#{qStop}\t#{avp}\t#{freeformComments}")
                exxonCount += 1
              }
            end
          }

          if(not blockHit)

            withEndBlock = configHash['withSizeBlock']
            withEndBlock.each { |key, value|
              #Deals with gene exons
              if(avpHash.has_key?(key) and not blockHit)
                blockHit = true

                arrtStarts = ""
                arrBlockSizes = ""

                exonStart = value["start"]
                exonStart.each { |key|
                  if(avpHash.has_key?(key))
                    arrtStarts = avpHash[key].split(/,/)
                  end
                }

                exonStop = value["size"]
                exonStop.each { |key|
                  if(avpHash.has_key?(key))
                    arrBlockSizes = avpHash[key].split(/,/)
                  end
                }

                arrtCount = 0
                arrtStarts.each { |tStart|
                  tStart = tStart.to_i
                  tEnd = tStart + arrBlockSizes[arrtCount].to_i
                  tStart = tStart + 1

                  #puts "#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{start}\t#{stop}\t#{strand}\#{phase}\t#{score}\t#{qStart}\t#{qStop}\t#{avp}\t#{freeformComments}"
                  writer.puts("#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t#{tStart}\t#{tEnd}\t#{avp}\t#{freeformComments}")
                  arrtCount += 1
                }
              end
            }
          end
          
          if(not blockHit)
            #puts "#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t#{qStart}\t#{qStop}\t#{avp}\t#{freeformComments}"
            writer.puts("#{lffClass}\t#{name}\t#{lffType}\t#{lffSubtype}\t#{chrom}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t#{qStart}\t#{qStop}\t#{avp}\t#{freeformComments}")
          end
        }

        #Clean Up
        reader.close
        writer.close

      end

      # Process the arguments that have been passed in and makes sure the required
      # ones are met.
      # [+returns+]   nothing
      def UCSCConverter.processArguments()
        # We want to add all the prop_keys as potential command line options
        optsArray =	[ ['--class',        '-c', GetoptLong::REQUIRED_ARGUMENT],
          ['--type',         '-t', GetoptLong::REQUIRED_ARGUMENT],
          ['--subtype',   	 '-s', GetoptLong::REQUIRED_ARGUMENT],
          ['--configFile',   '-o', GetoptLong::REQUIRED_ARGUMENT],
          ['--inputFile',    '-i', GetoptLong::REQUIRED_ARGUMENT],
          ['--dataFile',     '-d', GetoptLong::REQUIRED_ARGUMENT],
          ['--outputFile',   '-f', GetoptLong::REQUIRED_ARGUMENT],
          ['--help',         '-h', GetoptLong::NO_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        UCSCConverter.usage() if(optsHash.key?('--help'));

        unless(progOpts.getMissingOptions().empty?)
          UCSCConverter.usage("USAGE ERROR: some required arguments are missing")
        end

        UCSCConverter.usage() if(optsHash.empty?);
        return optsHash
      end

      # Displays a message to a user if either the required variables are missing or
      #  the help command line argument is raised
      # [msg]         [optional; default=''] The message to display to the user
      # [+returns+]   nothing
      def UCSCConverter.usage(msg='')
        unless(msg.empty?)
          puts("\n#{msg}\n")
        end
        puts "
  PROGRAM DESCRIPTION:
    The UCSC To LFF converter serves as a way of converting information from the
    UCSC genomic database to the Genboree LFF format. It takes a configuration
    file, a sql file, and a data file. The data file and sql file are from UCSC
    and correspond to a single dataset.

    COMMAND LINE ARGUMENTS:
     	-c    => Name of the class
      -t    => Name of the type
      -s    => Name of the Subtype
      -o    => Name of the configuration file
      -i    => Name of the .sql input file
      -d    => Name of the data file
      -f    => Name of the output file
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
    trackImporter.ucscConverter.rb -c Class -t Type -s SubType -o config.json -i all_bacends.sql -d all_bacends.txt.gz -f all_bacends.lff.gz";
        exit(134);
      end
    end
  end; end

# Process command line options
#optsHash = BRL::TrackImporter::UCSCConverter.processArguments()
#puts optsHash.size
#optsHash.keys.each do |data|
#puts data
#end
#optsHash.each do |data|
#puts data
#end
# Instantiate analyzer using the program arguments
#testClass = BRL::TrackImporter::UCSCConverter.new(optsHash)
# Do it
#testClass.run()
