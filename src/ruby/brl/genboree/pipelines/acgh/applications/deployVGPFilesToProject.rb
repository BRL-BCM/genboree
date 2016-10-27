#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunDeployVGPFilesToProject


DEFAULTUSAGEINFO ="

      Usage: Transfer VGP files to the right location on the genboree project.
      
  
      Mandatory arguments:

    -p    --defaultPropFile            #[defaultPropFile].
    -r    --resultDirNamePrefix            #[resultDirNamePrefix].
    -n    --projectName            #[projectName].
    -g    --numberOfGenomicPanels            #[numberOfGenomicPanels].
    -o    --contentPart            #[contentPart].
    -d    --scratchDir            #[scratchDir].
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
          
      methodName = "runDeployVGPFilesToProject"

      optsArray = [
                    ['--defaultPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--resultDirNamePrefix', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--numberOfGenomicPanels', '-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--contentPart', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--scratchDir', '-d', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runDeployVGPFilesToProject(optsHash)
    	DeployVGPFilesToProject.new(optsHash['--baseProject'], optsHash['--projectName'], optsHash['--resultDirNamePrefix'], optsHash['--scratchDir'], optsHash['--contentPart'], optsHash['--numberOfGenomicPanels'], optsHash['--defaultPropFile'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunDeployVGPFilesToProject.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunDeployVGPFilesToProject.runDeployVGPFilesToProject(optsHash)
