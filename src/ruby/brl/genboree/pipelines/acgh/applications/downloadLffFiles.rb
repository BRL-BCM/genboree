#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunDownloadLffFile


DEFAULTUSAGEINFO ="

      Usage: Download a genboree track from a Genboree database.
      
  
      Mandatory arguments:

    -n    --numberOfExtraFiles            #[numberOfExtraFiles].
    -t    --trackNames            #[trackNames].
    -r    --refSeqId            #[refSeqId].
    -o    --lffFileToDownload            #[lffFileToDownload].
    -u    --userId            #[userId].
    -x    --chrDefinitionFileExtension            #[chrDefinitionFileExtension].
    -e    --entryPointsOnly                Flag
    -d    --removeExtraEntryPoints          Flag
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
          
      methodName = "runDownloadLffFile"

      optsArray = [
                    ['--trackNames', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--refSeqId', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--lffFileToDownload', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--userId', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--numberOfExtraFiles', '-n', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--chrDefinitionFileExtension', '-x', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--entryPointsOnly', '-e', GetoptLong::NO_ARGUMENT],
                    ['--removeExtraEntryPoints', '-d', GetoptLong::NO_ARGUMENT],
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



    def self.runDownloadLffFile(optsHash)
          DownloadLffFile.new(optsHash['--lffFileToDownload'], optsHash['--refSeqId'], optsHash['--userId'], optsHash['--trackNames'], optsHash['--entryPointsOnly'], optsHash['--removeExtraEntryPoints'], optsHash['--numberOfExtraFiles'], optsHash['--chrDefinitionFileExtension'])
    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunDownloadLffFile.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunDownloadLffFile.runDownloadLffFile(optsHash)
