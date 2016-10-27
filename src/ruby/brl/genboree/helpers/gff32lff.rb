#!/usr/bin/env ruby
require 'pathname'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'stringio'
require 'uri'

module BRL ; module Script
  class GFF32Lff < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--inputFile"    =>     [ :REQUIRED_ARGUMENT, "-i", "input gff3 file." ],
      "--outputFile"   =>     [ :REQUIRED_ARGUMENT, "-o", "output lff file."],
      "--trackClass"   =>     [ :REQUIRED_ARGUMENT, "-c", "track class."],
      "--help"         =>     [ :NO_ARGUMENT, "-h", "help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "A program to convert gff3 files into lff. ",
      :authors      => [ "Sameer Paithankar (paithank@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=file.gff --outputFile=file.lff -c gff3Class"
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
      gff3Reader = File.open(@inputFile)
      lffWriter = File.open(@outputFile, 'w')
      orphan = nil
      lineCount = 0
      writeBuffer = ""
      fastaPragmaEncountered = false
      @attributesHash = {}
      begin
        # Do chunked reading/writing to minimize IO since bed files can be very large
        while(!gff3Reader.eof?)
          readBuffer = gff3Reader.read(READ_BUFFER_SIZE)
          buffIO = StringIO.new(readBuffer)
          buffIO.each_line { |line|
            if(line =~ /\n$/)
              lineCount += 1
              line = orphan + line if(!orphan.nil?)
              orphan = nil
              line.strip!
              next if(line.nil? or line.empty?)
              if(line =~ /^##FASTA/)
                fastaPragmaEncountered = true
                break
              end
              next if(line =~ /^\s*$/ or line =~ /^#/)
              dataFields = line.split(/\t/)
              raise "Line number: #{lineCount} has insufficient or too many number of columns." if(dataFields.size < 9 or dataFields.size > 9)
              parseLine(dataFields)
              raise "start and stop coordinates are not integer values at line number: #{lineCount}" if(@chromStart !~ /^\d+$/ or @chromEnd !~ /^\d+$/)
              # Try to set the name
              if(@attributesHash.has_key?("Name"))
                @name = @attributesHash['Name']
              elsif(@attributesHash.has_key?("ID"))
                @name = @attributesHash["ID"]
              elsif(@attributesHash.has_key?("Alias"))
                @name = @attributesHash["Alias"]
              else
                @name = "#{@chrom}:#{@chromStart}-#{@chromEnd}"
              end
              writeBuffer << "#{@class}\t#{@name}\t#{@trackType}\t#{@trackSubtype}\t#{@chrom}\t#{@chromStart}\t#{@chromEnd}\t#{@strand}\t#{@phase}\t#{@score}\t.\t.\t"
              @attributesHash.each_key { |key|
                writeBuffer << "#{key}=#{@attributesHash[key]}; "
              }
              writeBuffer << "\n"
              if(writeBuffer.size >= WRITE_BUFFER_SIZE)
                lffWriter.write(writeBuffer)
                writeBuffer = ''
              end
              @attributesHash.clear()
            else
              orphan = line
            end
          }
          buffIO.close()
          break if(fastaPragmaEncountered)
        end
        if(!writeBuffer.empty?)
          lffWriter.write(writeBuffer)
          writeBuffer = ''
        end
        lffWriter.close()
        gff3Reader.close()
      rescue => err
        lffWriter.close() if(!lffWriter.closed?)
        gff3Reader.close() if(!gff3Reader.closed?)
        $stdout.puts("Error:\n#{err.message}")
        raise "Error:\n#{err.message}\n\nBacktrace: #{err.backtrace.join("\n")}"
      end
      # Must return a suitable exit code number
      return EXIT_OK
    end

    # Parse line into variables
    # [+dataFields+]
    # [+returns+] nil
    def parseLine(dataFields)
      @chrom = dataFields[0]
      @trackType = ( dataFields[1] == "." ? "GFF3" : dataFields[1] )
      @trackSubtype = ( dataFields[2] == "." ? "Track" : dataFields[2] )
      @chromStart = dataFields[3]
      @chromEnd = dataFields[4]
      @score = ( dataFields[5] == "." ? "1.0" : dataFields[5] )
      if(dataFields[6] == "?" or dataFields[6] == ".")
        @strand = '+'
      else
        @strand = dataFields[6]
      end
      @phase = dataFields[7]
      attributes = dataFields[8].split(";")
      attributes.each { |avp|
        attrName = avp.split("=")[0]
        attrValue = avp.split("=")[1]
        if(attrName =~ /%3D/ or attrName =~ /%3B/ or attrName =~ /%2C/ or attrName =~ /%09/) # Unescape ";", ",", "tab" and "="
          if(attrName =~ /%09/) # Tab
            attrName.gsub!("%09", " ")
          elsif(attrName =~ /%3B/) # semi-colon
            attrName.gsub!("%3B", "|")
          else
            # No-op
          end
          attrName = URI.unescape(attrName)
        end
        @attributesHash[attrName] = nil
        if(attrValue =~ /%3D/ or attrValue =~ /%3B/ or attrValue =~ /%2C/ or attrValue =~ /%09/) # Unescape ";", ",", "tab" and "="
          if(attrValue =~ /%09/)
            attrValue.gsub!("%09", " ")
          elsif(attrValue =~ /%3B/)
            attrValue.gsub!("%3B", "|")
          else
            # No-op
          end
          attrValue =  URI.unescape(attrValue)
        end
        @attributesHash[attrName] = attrValue
      }
    end

    # Do validation of the inputs
    # [+returns+] nil
    def validateAndProcessArgs()
      @inputFile = @optsHash['--inputFile']
      @outputFile = @optsHash['--outputFile']
      @class = @optsHash['--trackClass']
      if(!File.exists?(@inputFile))
        raise("File: #{@inputFile} not found!")
      end
      if(@class =~ /\t/)
        raise("Track class cannot contain a tab character")
      end
    end
  end
end ; end # module BRL ; module Script

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::GFF32Lff)
end
