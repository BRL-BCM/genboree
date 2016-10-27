#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunJsonFromLff


DEFAULTUSAGEINFO ="

      Usage: Transform a lff file into a json file, some of the arguments are hard coded for now.
      
  
      Mandatory arguments:

    -r    --refSeqId            #[refSeqId].
    -f    --lffFileName            #[lffFileName].
    -n    --projectName            #[projectName].
    -t    --trackName            #[trackName].
    -j    --jsonFileName            #[jsonFileName].
    -s    --serverName            #[serverName].
    -b    --baseProject            #[baseProject].
    -v,   --version             Display version.
    -h,   --help, 			   Display help
      
"


    def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end
    
    def self.printVersion()
      puts BRL::Genboree::Pipelines::Acgh::AGILENT_PIPELINE_VERSION
      exit(0)
    end

    def self.parseArgs()
          
      methodName = "runJsonFromLff"

      optsArray = [
                    ['--refSeqId', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--lffFileName', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--jsonFileName', '-j', GetoptLong::REQUIRED_ARGUMENT],
                    ['--serverName', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProject', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--version', '-v',   GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      
      if(optsHash.key?('--help'))
        printUsage()
      elsif(optsHash.key?('--version'))
        printVersion()
      end
      printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)

      return optsHash
    end



    def self.runJsonFromLff(optsHash)
    			JsonFromLff.new(optsHash['--lffFileName'], optsHash['--jsonFileName'], optsHash['--refSeqId'], optsHash['--trackName'], optsHash['--serverName'], optsHash['--baseProject'], optsHash['--projectName'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunJsonFromLff.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunJsonFromLff.runJsonFromLff(optsHash)
