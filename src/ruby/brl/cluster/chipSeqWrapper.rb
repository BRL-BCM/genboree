#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
#require 'brl/genboree/genboreeUtil'
require 'cgi'
require 'socket'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'
require 'brl/cluster/clusterJobRunner'

module BRL
module Cluster
  # == Overview
  # This ruby script is to be used as a wrapper to run the pash program on a cluster. It can be invoked from galaxy or any other programmatic context.
  # This script accepts command line arguments and flags that allow full specification of all aspects of the pash job to be run on the cluster

  class ChipSeqWrapper
    
    def initialize(optsHash)
      @optsHash = optsHash
      @chipSeqCommandString = ""      
      @inputFileString = ""
      @outputDirString = ""
      @schedulerCommandString = ""
      @notificationEmail = ""
      setParameters()
    end

    def setParameters()
      
      genbConf = BRL::Genboree::GenboreeConfig.load()      
      @chipSeqCommandString += "chipSeqEDACCDriver.rb "      
      bedFile = @optsHash['--bedFile']
      bedFileName = bedFile.split(/\//).last
      @chipSeqCommandString += "-b ./#{bedFileName} "
      localHostName = Socket.gethostname
   
      @inputFileString+=localHostName.to_s+":"+bedFile
      @inputFileString = CGI.escape(@inputFileString)      
      outputFile = @optsHash['--outFile'] 
      outputDirName = outputFile.split(/\//).slice(0..-2).join("/")+"/"
      outputFileName = outputFile.split(/\//).last
      @outputDirString += localHostName.to_s+":"+outputDirName
      @outputDirString = CGI.escape(@outputDirString)
      
      @chipSeqCommandString += "-o ./#{outputFileName} -S #{@optsHash['--study']} -E #{@optsHash['--experiment']} -s #{@optsHash['--sample']} "
      @chipSeqCommandString+=checkHashforOption(@optsHash, '--tagSize','-t',36)
      @chipSeqCommandString+=",rm ./#{bedFileName}"
      #@pashCommandString+=" > ./pashMessages 2>&1"
      #puts @chipSeqCommandString
      @chipSeqCommandString = CGI.escape(@chipSeqCommandString)
      
      @notificationEmail = @optsHash['--email']
      
      @schedulerCommandString+="ruby #{genbConf.schedulerExecutable} "
      @schedulerCommandString+="-e #{@notificationEmail} "
      @schedulerCommandString+="-c #{@chipSeqCommandString} "
      @schedulerCommandString+="-i #{@inputFileString} "
      @schedulerCommandString+="-o #{@outputDirString} "
      @schedulerCommandString+="-r #{genbConf.chipSeqResourceFlag}=1 "
      if(genbConf.retainChipSeqDir=="yes" or genbConf.retainChipSeqDir=="true")
        @schedulerCommandString+="-k "
      end
      
      #puts @inputFileString
      #puts @outputDirString
      #puts @pashCommandString
      #puts @schedulerCommandString
    end
    
    def checkHashforOption(optionsHash,optionKey, optionFlag, defaultValue)      
      commandFragment=""
      flagValue = nil
      if(optionsHash.has_key?(optionKey)) then
        flagValue = optionsHash[optionKey]
      else
        flagValue = defaultValue unless defaultValue.nil?
      end
      commandFragment+="#{optionFlag} #{flagValue} " unless flagValue.nil?
      return commandFragment
    end

    def work()
      system(@schedulerCommandString)
    end
    
    def ChipSeqWrapper.processArguments()      
      optsArray = [['--bedFile','-b', GetoptLong::REQUIRED_ARGUMENT],                  
                  ['--outFile','-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--tagSize', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--study', '-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--email', '-e', GetoptLong::REQUIRED_ARGUMENT],
                  ['--experiment', '-E', GetoptLong::REQUIRED_ARGUMENT],
                  ['--sample', '-s', GetoptLong::REQUIRED_ARGUMENT],                  
                  ['--help','-h', GetoptLong::NO_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      if(optsHash.key?('--help')) then
        ChipSeqWrapper.usage()        
      end

      unless(progOpts.getMissingOptions().empty?)
        ChipSeqWrapper.usage("USAGE ERROR: some required arguments are missing")        
      end
      if(optsHash.empty?) then
        ChipSeqWrapper.usage()        
      end
      return optsHash
    end

    def ChipSeqWrapper.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
     puts "PROGRAM DESCRIPTION:
           Performs peak calling on a BED input file, and generates a Genboree Lff track
           according to the EDACC recommanedation document.

           COMMAND LINE ARGUMENTS:
           --bedFile    |-b   => BED file containing uniquely mapping reads.
           --email      |-e   => email to which notifications about the job should be sent
           --outFile    |-o   => output lff file
           --tagSize    |-t   => [optional] tag size (default 36)
           --study      |-S   => EDACC study
           --experiment |-E   => EDAC Experiment
           --sample     |-s   => EDACC Sample
           --help       |-h   => [optional flag] Output this usage info and exit

           USAGE:
            chipSeqWrapper.rb -b tags.bed -o peaks.lff -S Study1 -E Experiment1 -s Sample1"
      exit(2);
    end
  end


########################################################################################
# MAIN
########################################################################################

  # Process command line options
  optsHash = ChipSeqWrapper.processArguments()
  chipSeqWrapper = ChipSeqWrapper.new(optsHash)
  chipSeqWrapper.work();


end
end # module BRL ; module Cluster ;
