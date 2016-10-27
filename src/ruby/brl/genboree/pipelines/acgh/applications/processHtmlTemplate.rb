#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunProccessRhtmlTemplate


DEFAULTUSAGEINFO ="

      Usage: Takes a template (template using rhtml tags) and a json file and generates a html file.
      
  
      Mandatory arguments:

    -j    --jsonPropFile            #[jsonPropFile].
    -o    --htmlOutputFile            #[htmlOutputFile].
    -r    --rhtmlFile            #[rhtmlFile].
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
          
      methodName = "runProccessRhtmlTemplate"

      optsArray = [
                    ['--jsonPropFile', '-j', GetoptLong::REQUIRED_ARGUMENT],
                    ['--htmlOutputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--rhtmlFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
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



    def self.runProccessRhtmlTemplate(optsHash)
        ProccessRhtmlTemplate.new(optsHash['--rhtmlFile'], optsHash['--htmlOutputFile'], optsHash['--jsonPropFile'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunProccessRhtmlTemplate.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunProccessRhtmlTemplate.runProccessRhtmlTemplate(optsHash)
