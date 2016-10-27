#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunRenameTracksInLffFile


DEFAULTUSAGEINFO ="

      Usage: change the type subtype and class of an lff file.
      
  
      Mandatory arguments:

    -f    --lffFileToModify            #[lffFileToModify].
    -o    --newLffFile            #[newLffFile].
    -c    --className            #[className].
    -u    --subTypeName            #[subTypeName].
    -t    --typeName            #[typeName].
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
          
      methodName = "runRenameTracksInLffFile"

      optsArray = [
                    ['--lffFileToModify', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--newLffFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--className', '-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--subTypeName', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--typeName', '-t', GetoptLong::REQUIRED_ARGUMENT],
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

    def self.runRenameTracksInLffFile(optsHash)
        RenameTracksInLffFile.new(optsHash['--lffFileToModify'], optsHash['--newLffFile'], optsHash['--className'], optsHash['--typeName'], optsHash['--subTypeName'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunRenameTracksInLffFile.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunRenameTracksInLffFile.runRenameTracksInLffFile(optsHash)
