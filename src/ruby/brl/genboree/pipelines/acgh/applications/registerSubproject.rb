#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunRegisterSubProjects


DEFAULTUSAGEINFO ="

      Usage: Register subprojects into the main or base project and add links to the subproject.
      
  
      Mandatory arguments:

    -p    --defaultPropFile            #[defaultPropFile].
    -n    --projectName            #[projectName].
    -s    --serverName            #[serverName].
    -b    --baseProject            #[baseProject].
    -l    --projectPath            #[projectPath].
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
          
      methodName = "runRegisterSubProjects"

      optsArray = [
                    ['--defaultPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--serverName', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProject', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectPath', '-l', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runRegisterSubProjects(optsHash)
    			RegisterSubProjects.new(optsHash['--projectPath'], optsHash['--serverName'], optsHash['--baseProject'], optsHash['--projectName'], optsHash['--defaultPropFile'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunRegisterSubProjects.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunRegisterSubProjects.runRegisterSubProjects(optsHash)
