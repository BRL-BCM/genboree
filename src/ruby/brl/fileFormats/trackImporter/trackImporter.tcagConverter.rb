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
    class TCAGConverter
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
        @trackData.dataFile = @optsHash['--dataFile']
        @trackData.configFile = @optsHash['--configFile']
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
        avpHash = Hash.new
        reader = BRL::Util::TextReader.new(@trackData.dataFile)
        writer = BRL::Util::TextWriter.new("#{@trackData.outputFile}",  "w", 0)

        firstLine = true
        hashTemplate = Hash.new

        #load in configuration file and convert it into a Hash
        jsonFile = File.new( @trackData.configFile )
        jsonData = jsonFile.read

        configHash = JSON.parse(jsonData)

        hashFields = configHash['hashfields']
        defaultValues = configHash['defaultValues']
        ignoreColumns = configHash['excludeColumns']

        #Start Reading Data File
        reader.each { | line |
          arrSplit = line.strip.split(/\t/)

          if(firstLine)
            #Set up the hashTemplate
            arrSplit.each_with_index { |columnName, positionCount|
              match = false
              if(ignoreColumns.include?(columnName))
                hashTemplate[positionCount] = "IGNORE"
              else
                hashFields.each { |key, value|
                  value.each { |search|
                    if(search.nil? and match == false)
                      hashTemplate[positionCount] = "DEFAULT"
                    elsif(search == columnName)
                      hashTemplate[positionCount] = key
                      match = true
                    end
                  }
                }
                if(!match)
                  hashTemplate[positionCount] = "AVP=" + columnName
                end
              end
            } #End arrSplit.each_with_index

            #No Longer the First Line
            firstLine = false
          else
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

            #tStart

            #tEnd

            #AVPs
            if(configHash['avp'] != nil)
              avpAction = configHash['avp']
              if(avpAction == "Genes \t to ,")
                if(avpHash["Genes"] != nil)
                  avpHash["Genes"].gsub!("\\t",",")
                end
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
      def TCAGConverter.processArguments()
        # We want to add all the prop_keys as potential command line options
        optsArray = [
          ['--class',        '-c', GetoptLong::REQUIRED_ARGUMENT],
          ['--type',         '-t', GetoptLong::REQUIRED_ARGUMENT],
          ['--subtype',      '-s', GetoptLong::REQUIRED_ARGUMENT],
          ['--configFile',   '-o', GetoptLong::REQUIRED_ARGUMENT],
          ['--dataFile',    '-i', GetoptLong::REQUIRED_ARGUMENT],
          ['--outputFile',   '-f', GetoptLong::REQUIRED_ARGUMENT],
          ['--help',         '-h', GetoptLong::NO_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        TCAGConverter.usage() if(optsHash.key?('--help'));

        unless(progOpts.getMissingOptions().empty?)
          TCAGConverter.usage("USAGE ERROR: some required arguments are missing")
        end

        TCAGConverter.usage() if(optsHash.empty?);
        return optsHash
      end

      # Displays a message to a user if either the required variables are missing or
      #  the help command line argument is raised
      # [msg]         [optional; default=''] The message to display to the user
      # [+returns+]   nothing
      def TCAGConverter.usage(msg='')
        unless(msg.empty?)
          puts("\n#{msg}\n")
        end
        puts "
  PROGRAM DESCRIPTION:
    The TCAG To LFF converter serves as a way of converting information from the
    TCAG genomic database to the Genboree LFF format. It takes a configuration
    file, a sql file, and a data file. The data file is from TCAG and correspond to a single dataset.

    COMMAND LINE ARGUMENTS:
      -c    => Name of the class
      -t    => Name of the type
      -s    => Name of the Subtype
      -o    => Name of the configuration file
      -d    => Name of the data file
      -f    => Name of the output file
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
        trackImporter.tcagConverter.rb  -c Class -t Type -s SubType -o tcag.config.json -i indel.hg18.v8.aug.2009.txt -f output.lff.gz";
        exit(134);
      end
    end
  end; end

#optsHash = BRL::TrackImporter::TCAGConverter.processArguments()
#importClass = BRL::TrackImporter::TCAGConverter.new(optsHash)
#importClass.run()