#!/usr/bin/env ruby
require 'pathname'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'stringio'

module BRL ; module Script
  class Bed2Lff < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--inputFile"    =>     [ :REQUIRED_ARGUMENT, "-i", "input bed file." ],
      "--outputFile"   =>     [ :REQUIRED_ARGUMENT, "-o", "output lff file."],
      "--trackType"    =>     [ :REQUIRED_ARGUMENT, "-t", "track type."],
      "--trackSubType" =>     [ :REQUIRED_ARGUMENT, "-u", "track subtype."],
      "--trackClass"   =>     [ :REQUIRED_ARGUMENT, "-c", "track class."],
      "--coordSystem"   =>    [ :OPTIONAL_ARGUMENT, "-C", "coordinate system: 0 or 1."],
      "--help"         =>     [ :NO_ARGUMENT, "-h", "help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "A program to convert bed files into lff. ",
      :authors      => [ "Sameer Paithankar (paithank@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=file.bed --outputFile=file.lff --coordSystem 0"
      ]
    }

    READ_BUFFER_SIZE = WRITE_BUFFER_SIZE = 4 * 1024 * 1024

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      validateAndProcessArgs()
      initBedHash()
      bedReader = File.open(@inputFile)
      lffWriter = File.open(@outputFile, 'w')
      orphan = nil
      lineCount = 0
      bedFieldsCount = nil
      writeBuffer = ""
      begin
        # Do chunked reading/writing to minimize IO since bed files can be very large
        while(!bedReader.eof?)
          readBuffer = bedReader.read(READ_BUFFER_SIZE)
          buffIO = StringIO.new(readBuffer)
          buffIO.each_line { |line|
            if(line =~ /\n$/)
              lineCount += 1
              line = orphan + line if(!orphan.nil?)
              orphan = nil
              line.strip!
              next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#/ or line =~ /^track/ or line =~ /^browser/)
              dataFields = line.split(/\s+/)
              if(bedFieldsCount.nil?)
                bedFieldsCount = dataFields.size
                if(bedFieldsCount < 3)
                  raise("The bed format requires at least 3 fields. Line: #{line}")
                end
                if(bedFieldsCount > 9 and bedFieldsCount < 12)
                  raise("For processing blocks, ALL fields [10-12] must be present")
                end
              else
                if(bedFieldsCount != dataFields.size) # The number of fields should be consistent throughout the file
                  raise("Number of fields: #{dataFields.size} at line number: #{lineCount} does not match the number of fields of the first line: #{bedFieldsCount}")
                end
              end
              updateBedFieldHash(dataFields)
              chrom = @bedFieldHash[:chrom]
              raise "start and stop coordinates are not integer values at line number: #{lineCount}" if(@bedFieldHash[:chromStart] !~ /^\d+$/ or @bedFieldHash[:chromEnd] !~ /^\d+$/)
              chromStart = ( @coordSystem == '0' ? @bedFieldHash[:chromStart].to_i + 1 : @bedFieldHash[:chromStart].to_i )
              chromEnd = @bedFieldHash[:chromEnd]
              raise "stop coordinate is smaller than start coordinate on line #{lineCount}" if(chromEnd.to_i < chromStart.to_i)
              name = !@bedFieldHash[:name].nil? ? @bedFieldHash[:name] : "#{chrom}:#{chromStart}-#{chromEnd}"
              strand = !@bedFieldHash[:strand].nil? ? @bedFieldHash[:strand] : "+"
              phase = !@bedFieldHash[:phase].nil? ? @bedFieldHash[:phase] : "."
              score = !@bedFieldHash[:score].nil? ? @bedFieldHash[:score] : "1.0"
              hexColor = nil
              if(!@bedFieldHash[:itemRgb].nil?)
                if(@bedFieldHash[:itemRgb] == '0')
                  hexColor = '#000000'
                else
                  hexColor = generateHexColor(@bedFieldHash[:itemRgb], lineCount)
                end
              end
              thickStart = @bedFieldHash[:thickStart]
              thickEnd = @bedFieldHash[:thickEnd]
              if(bedFieldsCount < 10)
                writeBuffer << "#{@class}\t#{name}\t#{@type}\t#{@subType}\t#{chrom}\t#{chromStart}\t#{chromEnd}\t#{strand}\t#{phase}\t#{score}"
                if(hexColor or thickStart or thickEnd)
                  writeBuffer << "\t.\t.\t"
                end
                writeBuffer << "annotationColor=#{hexColor}; " if(hexColor)
                writeBuffer << "thickStart=#{thickStart}; " if(thickStart)
                writeBuffer << "thickEnd=#{thickEnd}; " if(thickEnd)
                writeBuffer << "\n"
              else
                blockCount = @bedFieldHash[:blockCount].to_i
                blockStarts = @bedFieldHash[:blockStarts].split(",")
                blockSizes = @bedFieldHash[:blockSizes].split(",")
                if(blockCount != blockStarts.size or blockCount != blockSizes.size)
                  raise "blockStarts: #{blockStarts} and blockSizes: #{blockSizes} do not correspond to blockCount: #{blockCount} at line number: #{lineCount}"
                end
                blockCount.times { |ii|
                  blockStart = chromStart + blockStarts[ii].to_i
                  chromEnd = ( ( blockStart +  blockSizes[ii].to_i ) - 1 )
                  writeBuffer << "#{@class}\t#{name}\t#{@type}\t#{@subType}\t#{chrom}\t#{blockStart}\t#{chromEnd}\t#{strand}\t#{phase}\t#{score}\t.\t.\t"
                  # According to the UCSC bed specs, 'lower-numbered fields must always be populated if higher-numbered fields are used'
                  # Ergo, we can assume that 'avp' fields will be present
                  writeBuffer << "annotationColor=#{hexColor}; thickStart=#{thickStart}; thickEnd=#{thickEnd}; "
                  writeBuffer << "\n"
                }
              end
              resetBedFieldHash()
              if(writeBuffer.size >= WRITE_BUFFER_SIZE)
                lffWriter.write(writeBuffer)
                writeBuffer = ''
              end
            else
              orphan = line
            end
          }
          buffIO.close()
        end
        if(!writeBuffer.empty?)
          lffWriter.write(writeBuffer)
          writeBuffer = ''
        end
        lffWriter.close()
        bedReader.close()
      rescue => err
        lffWriter.close() if(!lffWriter.closed?)
        bedReader.close() if(!bedReader.closed?)
        $stdout.puts("Error:\n#{err.message}")
        raise "Error:\n#{err.message}\n\nBacktrace: #{err.backtrace.join("\n")}"
      end
      # Must return a suitable exit code number
      return EXIT_OK
    end

    # Updates '@bedFieldHash' with value for each bed record
    # [+dataFields+]
    # [+returns+] nil
    def updateBedFieldHash(dataFields)
      dataFields.each_index { |ii|
        @bedFieldHash[@bedIdxHash[ii]] = dataFields[ii]
      }
    end

    # Resets all values in @bedFieldHash to nil
    # [+returns+] nil
    def resetBedFieldHash()
      @bedFieldHash.each_key { |key|
        @bedFieldHash[key] = nil
      }
    end

    # Initialize hashes with the required bed fields and an index hash
    # [+returns+] nil
    def initBedHash()
      @bedFieldHash = {
                        :chrom => nil,
                        :chromStart => nil,
                        :chromEnd => nil,
                        :name => nil,
                        :score => nil,
                        :strand => nil,
                        :thickStart => nil,
                        :thickEnd => nil,
                        :itemRgb => nil,
                        :blockCount => nil,
                        :blockCount => nil,
                        :blockSizes => nil,
                        :blockStarts => nil
                      }
      @bedIdxHash = {
                      0 => :chrom,
                      1 => :chromStart,
                      2 => :chromEnd,
                      3 => :name,
                      4 => :score,
                      5 => :strand,
                      6 => :thickStart,
                      7 => :thickEnd,
                      8 => :itemRgb,
                      9 => :blockCount,
                      10 => :blockSizes,
                      11 => :blockStarts
                    }
    end


    # validates color (r, g, b) value
    # [+color+] color value in decimal (r, g, b)
    # [+lineCount+]
    # [+returns+] hex color value
    def generateHexColor(color, lineCount)
      raise "Incorrect format for rgbItem column at line number: #{lineCount}" if(color !~ /^\d+,\d+,\d+$/)
      return "##{color.split(/,/).map { |xx| ("%.2X" % xx.to_i) }.join('')}"
    end



    # Do validation of the inputs
    # [+returns+] nil
    def validateAndProcessArgs()
      @inputFile = @optsHash['--inputFile']
      @outputFile = @optsHash['--outputFile']
      @type = @optsHash['--trackType']
      @subType = @optsHash['--trackSubType']
      @class = @optsHash['--trackClass']
      if(!File.exists?(@inputFile))
        raise("File: #{@inputFile} not found!")
      end
      if(@type =~ /:/ or @type =~ /\t/ or @subType =~ /:/ or @subType =~ /\t/)
        raise("Track Type and Subtype cannot contain a ':' or a tab character")
      end
      if(@class =~ /\t/)
        raise("Track class cannot contain a tab character")
      end
      @coordSystem = @optsHash['--coordSystem'] ? @optsHash['--coordSystem'] : '0'
    end
  end
end ; end # module BRL ; module Script

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::Bed2Lff)
end
