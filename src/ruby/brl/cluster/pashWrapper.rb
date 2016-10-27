#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
#require 'brl/genboree/genboreeUtil'
require 'cgi'
require 'socket'
require 'fileutils'
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

  class PashWrapper
    
    def initialize(optsHash)
      @optsHash = optsHash
      @pashCommandString = ""
      @genomeName = ""
      @inputFileString = ""
      @outputDirString = ""
      @schedulerCommandString = ""
      @notificationEmail = ""
      setParameters()
    end

    def setParameters()
     
     
      @genomeName = @optsHash['--genomeName']
     
      genbConf = BRL::Genboree::GenboreeConfig.load()
      
      @pashCommandString+=genbConf.pashExecutable+" -S . "
                       
      @pashCommandString+=checkHashforOption(@optsHash, '--diagonals','-d',100)
      @pashCommandString+=checkHashforOption(@optsHash, '--patternWeight','-k',13)
      @pashCommandString+=checkHashforOption(@optsHash, '--patternLength','-n',21)
      @pashCommandString+=checkHashforOption(@optsHash, '--samplingPattern','-m',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--verticalWordOffset','-G',2)
      @pashCommandString+=checkHashforOption(@optsHash, '--score','-s',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--gzip','-z',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--self','-A',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--indexMemory','-M',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--ignoreList','-L',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--maxMappings','-N',nil)
      @pashCommandString+=checkHashforOption(@optsHash, '--bisulfiteSeq','-B',nil)

      
      readsFile = @optsHash['--readsFile']      
      readsFileName = readsFile.split(/\//).last
      @pashCommandString += "-v ./#{readsFileName}.limit "
      localHostName = Socket.gethostname  
      @inputFileString+=localHostName.to_s+":#{readsFile}"
      @inputFileString = CGI.escape(@inputFileString)      
      outputFile = @optsHash['--outputFile']      
      outputDirName = outputFile.split(/\//).slice(0..-2).join("/")+"/"
      outputFileName = outputFile.split(/\//).last
      @pashCommandString += "-o ./#{outputFileName} " 
      @outputDirString += localHostName.to_s+":"+outputDirName
      @outputDirString = CGI.escape(@outputDirString)
    

      
      if(@pashCommandString=~/\-B/)
        genomeFileName = genbConf.genomeFilesDir+@genomeName.to_s+"/ref.dnameth.fa"
        lineLimit = 400000
      else
        genomeFileName = genbConf.genomeFilesDir+@genomeName.to_s+"/ref.fa"
        lineLimit = 4000000
      end      
      @pashCommandString += "-h #{genomeFileName} "
       
      @clusterJobCommandString = CGI.escape("head -n #{lineLimit} ./#{readsFileName} > ./#{readsFileName}.limit")
      @clusterJobCommandString += ","+ CGI.escape(@pashCommandString)
      @clusterJobCommandString += ","+ CGI.escape("rm ./#{readsFileName}")
      @clusterJobCommandString += ","+ CGI.escape("rm ./#{readsFileName}.limit")

      @clusterJobCommandString = CGI.escape(@clusterJobCommandString)
      
      @notificationEmail = @optsHash['--email']
      
      @schedulerCommandString+="ruby #{genbConf.schedulerExecutable} "
      @schedulerCommandString+="-e #{@notificationEmail} "
      @schedulerCommandString+="-c #{@clusterJobCommandString} "
      @schedulerCommandString+="-i #{@inputFileString} "
      @schedulerCommandString+="-o #{@outputDirString} "
      @schedulerCommandString+="-r #{genbConf.pashMapResourceFlag}=1 "
      if(genbConf.retainPashMapDir=="yes" or genbConf.retainPashMapDir=="true")
        @schedulerCommandString+="-k "
      end
      #puts @inputFileString
      #puts @outputDirString
      #puts @pashCommandString
      
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
    
    def PashWrapper.processArguments()
      optsArray = [['--genomeName','-g', GetoptLong::REQUIRED_ARGUMENT],
                  ['--readsFile','-r', GetoptLong::REQUIRED_ARGUMENT],
                  ['--outputFile','-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--email', '-e', GetoptLong::REQUIRED_ARGUMENT],
                  ['--diagonals','-d', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--patternWeight','-k', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--patternLength','-n', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--samplingPattern','-m', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--verticalWordOffset','-G', GetoptLong::OPTIONAL_ARGUMENT],                  
                  ['--score','-s', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--gzip','-z',  GetoptLong::NO_ARGUMENT],                  
                  ['--self','-A', GetoptLong::NO_ARGUMENT],
                  ['--indexMemory','-M', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--ignoreList','-L', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--maxMappings','-N', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--bisulfiteSeq','-B', GetoptLong::NO_ARGUMENT],
                  ['--help','-H', GetoptLong::NO_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      if(optsHash.key?('--help')) then
        PashWrapper.usage()        
      end

      unless(progOpts.getMissingOptions().empty?)
        PashWrapper.usage("USAGE ERROR: some required arguments are missing")        
      end
      if(optsHash.empty?) then
        PashWrapper.usage()        
      end
      return optsHash
    end

    def PashWrapper.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "PROGRAM DESCRIPTION:
          This ruby script is to be used as a wrapper to run the pash program on a cluster. It can be invoked from galaxy or any other programmatic context.
          This script accepts command line arguments and flags that allow full specification of all aspects of the pash job to be run on the cluster          
            
          COMMAND LINE ARGUMENTS:
            -g or --genomeName  => This flag is required and indicates the species name of the genome against which mapping is to be done. The genome files are
                                   accessible from all cluster execution hosts. Hence the files need not be provided.
            -r or --readsFile   => This flag is required and specifies the location of the file containing reads to be pash mapped. An absolute filepath is necessary.                                 
            -o or --outputFile  => This flag is required and specifies the output file into which the results of the mapping should be copied. An absolute filepath is necessary.                                   
            -e or --email       => This flag is required and should be followed by the email to which notifications about the job should be sent
            
            The flags that follow are all optional. Default values when applicable are specified
            -d or --diagonals               <number of diagonals> default = 100
            -k or --patternWeight           <pattern weight> Number of sampled positions in the sampling pattern default = 13
            -n or --patternLength           total length of sampling pattern, including unsampled positions default = 21
            -m or --samplingPattern         sampling pattern (e.g. 11011 would sample the two positions, skip one position, then sample the next two
            -G or --verticalWordOffset      <vertical word offset gap - must be a multiple of diagonal offset gap> default = 2
            -s or --score                   -s <scoreCutoff>
            -z or --gzip                    request gzip-ed output (default is text)
            -A or --self                    Job is a self-comparison, so skip half the comparison to increase speed and avoid redundancy (note if this is turned on when not doing
                                            self-comparison, half the matches will not be found!)
            -M or --indexMemory             index of the vertical sequence hash in MB(default 1024)
            -L or --ignoreList              ignore the kmers present in the ignore list file
            -N or --maxMappings             maximum number of mappings per read
            -B or --bisulfiteSeq            perform mapping of bisulfite sequencing reads
            -h or --help                    print usage info and exit

          USAGE:
           pashWrapper.rb -g test -r /usr/local/brl/home/clusterUser/WORKSPACE/bin/myReads.fastq -o /usr/local/brl/home/clusterUser/WORKSPACE/output.txt -e raghuram@bcm.edu"
      
      exit(2);
    end
  end


########################################################################################
# MAIN
########################################################################################

  # Process command line options
  optsHash = PashWrapper.processArguments()
  pashWrapper = PashWrapper.new(optsHash)
  pashWrapper.work();


end
end # module BRL ; module Cluster ;
