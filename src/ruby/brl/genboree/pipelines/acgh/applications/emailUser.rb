#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunSendEmailToUser


DEFAULTUSAGEINFO ="

      Usage: Send an email to a genboree user to let him/her know that the job has finish or failed.
      
  
      Mandatory arguments:

    -p    --defaultPropFile            #[defaultPropFile].
    -m    --messageType            #[messageType].
    -n    --projectName            #[projectName].
    -u    --userId            #[userId].
    -o    --originalProjName            #[originalProjName].
    -r    --rawFileName            #[rawFileName].
    -b    --baseProject            #[baseProject].
    -d    --duplicatedProject      Flag only if duplicated
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
          
      methodName = "runSendEmailToUser"

      optsArray = [
                    ['--defaultPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--messageType', '-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--userId', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--originalProjName', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--rawFileName', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProject', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--duplicatedProject', '-d', GetoptLong::NO_ARGUMENT],
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



    def self.runSendEmailToUser(optsHash)
    			SendEmailToUser.new(optsHash['--baseProject'], optsHash['--projectName'], optsHash['--userId'], optsHash['--rawFileName'], optsHash['--messageType'], optsHash['--defaultPropFile'], optsHash['--duplicatedProject'], optsHash['--originalProjName'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunSendEmailToUser.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunSendEmailToUser.runSendEmailToUser(optsHash)
