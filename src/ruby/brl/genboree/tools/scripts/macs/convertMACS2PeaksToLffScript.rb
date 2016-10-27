#!/usr/bin/env ruby
require 'pathname'
require 'brl/util/util'
# Require scriptDriver.rb
require 'brl/script/scriptDriver'

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  class ConvertMACS2PeaksToLffScript < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.6"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--inputFile" =>  [ :REQUIRED_ARGUMENT, "-i", "MACS results file (.xls)" ],
      "--outputFile" =>  [ :REQUIRED_ARGUMENT, "-o", "Name of lff output file to create" ],
      "--track" =>  [ :REQUIRED_ARGUMENT, "-t", "Name of track to create (must be in \"a:b\" format)" ],
      "--class" =>  [ :REQUIRED_ARGUMENT, "-c", "Class of track to be created" ],
      "--avp" =>  [:REQUIRED_ARGUMENT, "-a", "Attribute value pairs to be added to track. Comma separated list of \"a=b\" values" ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Script to convert MACS output to lff format. Inherits from ScriptDriver",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=filePath1.xls --outputFile=filePath2.lff --track=Type%3ASubtype%20otherInfo --class=Class --avp=a1%3Db1,c1%3Dd1",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      validateAndProcessArgs()
      runConverter()
      # Must return a suitable exit code number
      return EXIT_OK
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def validateAndProcessArgs
      @inputFile = @optsHash['--inputFile']
      @outputFile = @optsHash['--outputFile']
      @track = @optsHash['--track']
      @class = @optsHash['--class']
      @avps = @optsHash['--avp'].split(/,/)
    end

    # Method that performs actual conversion
    def runConverter
      @track =~ /([^:]+):(.+)/
      nType = $1
      nSubtype = $2
      nType = @track.split(":")[0]
      nSubtype = @track.split(":")[1]
      ifh = File.open(@inputFile, "r")
      ofh = File.open(@outputFile, "w")
      line = nil
      cStart = 0
      cStop = 0
      cAdjust = 0
      chrom =  nil
      val = nil
      bandWidth = 200
      ifh.each {|line|
        if (line =~ /^\s*#/) then
          if (line =~ /band\s*width\s*=\s*(\d+)/) then
            bandWidth = $1
          end
          next
        end
        if ( line =~ /^\s*$/) then
          next
        end
        if (line=~/fold_enrichment/) then
          next
        end
        ff = line.strip.split(/\t/)
        chrom = ff[0]
        cStart = ff[1].to_i
        cStop = ff[2].to_i
        val = ff[5]
        minusLog10Qvalue = ff[6]
        foldEnrichment = ff[7]
        ofh.print "#{@class}\t#{chrom}_#{cStart}_#{cStop}\t#{nType}\t#{nSubtype}\t#{chrom}\t#{cStart}\t#{cStop}\t+\t.\t#{val}\t.\t.\tpileup=#{val}; minusLog10Qvalue=#{minusLog10Qvalue}; foldEnrichment=#{foldEnrichment};"
        @avps.each{|avp|
          ofh.print("; #{avp}")
          }
        ofh.puts
      }
      ifh.close()
      ofh.close()

    end

  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::ConvertMACS2PeaksToLffScript)
end
