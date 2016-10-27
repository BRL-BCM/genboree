#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunManageGenboreeProjects


DEFAULTUSAGEINFO ="

      Usage: Create a new Genboree project or subproject but also can delete or rename an existing project.
      
  
      Mandatory arguments:

    -p    --newProjectName            #[newProjectName].
    -a    --action            [create/delete/rename].
    -n    --projectName            #[projectName].
    -u    --userId            #[userId].
    -b    --baseProject            #[baseProject].
    -g    --groupId            #[groupId].
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
          
      methodName = "runManageGenboreeProjects"

      optsArray = [
                    ['--newProjectName', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--action', '-a', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--userId', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProject', '-b', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--groupId', '-g', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runManageGenboreeProjects(optsHash)
      createProject = ManageGenboreeProjects.new(optsHash['--groupId'], optsHash['--userId'], optsHash['--projectName'], optsHash['--action'], optsHash['--baseProject'], optsHash['--newProjectName'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunManageGenboreeProjects.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunManageGenboreeProjects.runManageGenboreeProjects(optsHash)
