#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunAddColorsAndProp


DEFAULTUSAGEINFO ="

      Usage: This application takes color names and annotates the lff file also changes the name of the track and the class
      
  
      Mandatory arguments:

    -p    --defaultPropFile            #[defaultPropFile].
    -t    --threshold            #[threshold].
    -f    --classifiedClassName            #[classifiedClassName].
    -c    --trackColors            #[trackColors].
    -e    --classifiedTypeName            #[classifiedTypeName].
    -b    --classifiedFile            #[classifiedFile].
    -g    --defaultTrackName            #[defaultTrackName].
    -i    --intersectFileName            #[intersectFileName].
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
          
      methodName = "runAddColors"

      optsArray = [
                    ['--defaultPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--threshold', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--classifiedClassName', '-f', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--trackColors', '-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--classifiedTypeName', '-e', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--classifiedFile', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--defaultTrackName', '-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--intersectFileName', '-i', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runAddColors(optsHash)
        AddColorsAndProp.new(optsHash['--intersectFileName'], optsHash['--classifiedFile'], optsHash['--trackColors'], optsHash['--threshold'], optsHash['--classifiedTypeName'], optsHash['--classifiedClassName'], optsHash['--defaultTrackName'], optsHash['--defaultPropFile'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunAddColorsAndProp.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunAddColorsAndProp.runAddColors(optsHash)
