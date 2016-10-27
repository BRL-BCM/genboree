#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  GenerateJavaScripts


DEFAULTUSAGEINFO ="

      Usage: Takes a javaScriptTemplate, a json file and a location to deploy a custom javaScript file.
      
  
      Mandatory arguments:

    -p    --defaultPropFile            #[defaultPropFile].
    -r    --refSeqId            #[refSeqId].
    -i    --projectlink            #[projectlink].
    -o    --javaScriptName            #[javaScriptName].
    -n    --projectName            #[projectName].
    -t    --templateName            #[templateName].
    -b    --baseProject            #[baseProject].
    -l    --link            #[link].
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
          
      methodName = "runGenerateJavaScripts"

      optsArray = [
                    ['--defaultPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--refSeqId', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectlink', '-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--javaScriptName', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--templateName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProject', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--link', '-l', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runGenerateJavaScripts(optsHash)
        ProccessJavaScriptTemplate.new(optsHash['--templateName'], optsHash['--javaScriptName'], optsHash['--refSeqId'], optsHash['--link'], optsHash['--projectlink'], optsHash['--baseProject'], optsHash['--projectName'], optsHash['--defaultPropFile'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::GenerateJavaScripts.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::GenerateJavaScripts.runGenerateJavaScripts(optsHash)
