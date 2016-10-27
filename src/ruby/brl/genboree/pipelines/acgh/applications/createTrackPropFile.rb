#!/usr/bin/env ruby

require 'cgi'
require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'


module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class  RunCreateVGPTracksDescriptionFile


DEFAULTUSAGEINFO ="

      Usage: create intermediary property files to generate the vgp property file.
      
  
      Mandatory arguments:

    -a    --agilentTrack            #[agilentTrack].
    -r    --refTrackName            #[refTrackName].
    -p    --trackPropFile            #[trackPropFile].
    -s    --trackString            #[trackString].
    -c    --chromosomeView      Flag
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
          
      methodName = "runRunCreateVGPTracksDescriptionFile"

      optsArray = [
                    ['--agilentTrack', '-a', GetoptLong::REQUIRED_ARGUMENT],
                    ['--refTrackName', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--trackPropFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--trackString', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--chromosomeView', '-c',   GetoptLong::NO_ARGUMENT],
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



    def self.runRunCreateVGPTracksDescriptionFile(optsHash)
        CreateVGPTracksDescriptionFile.new(optsHash['--trackPropFile'], optsHash['--agilentTrack'], optsHash['--refTrackName'], optsHash['--trackString'], optsHash['--chromosomeView'])
    end
  
end

end; end; end; end; end;  #namespace
#puts "-------Before ----------"
#puts ARGV.inspect
optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunCreateVGPTracksDescriptionFile.parseArgs()
#puts "-------After ----------"
#puts ARGV.inspect trying to pass some other args using -- --some -s -t -etc
#optsHash['--extraArgs'] =  CGI.escape(ARGV.join(" "))
#puts optsHash.inspect
BRL::Genboree::Pipelines::Acgh::Applications::RunCreateVGPTracksDescriptionFile.runRunCreateVGPTracksDescriptionFile(optsHash)
