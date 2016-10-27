#!/usr/bin/env ruby
require 'json'
require 'fileutils'

require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'


class PashMap

   def initialize(optsHash)
        @input    = optsHash['--jsonFile']

   end
   

  def work
    
    
    jsonObj = JSON.parse(File.read(@input))
    
    
   
    input  = jsonObj["input"]
    output = jsonObj["output"]
    runName = jsonObj["settings"]["analysisName"]
    targetGenome = jsonObj["settings"]["targetGenome"]
    kWeight = jsonObj["settings"]["kWeight"]
    kspan = jsonObj["settings"]["kSpan"]
    scratch = jsonObj["settings"]["scratch"]
    gap = jsonObj["settings"]["gap"]
    diagonals = jsonObj["settings"]["diagonals"]
    maxMapping = jsonObj["settings"]["maxMappings"]
    @targetGenome = jsonObj["settings"]["targetGenome"]
    puts input
    @baseName = File.basename(input[0])
    @scratch = "/scratch"
    command = "pash-3.0lx.exe -v #{File.expand_path(output[0])}/#{@baseName}.output.tags -h #{@targetGenome} -k #{kWeight} -n #{kspan} -S #{@scratch} -s 22 -G #{gap} -d #{diagonals} -o #{File.expand_path(output[0])}/#{@baseName}.pash3.0.Map.output.txt -N #{maxMapping} > #{File.expand_path(output[0])}/log.pash-3.0 2>&1"
    
    puts command
    system(command)
  end
  
   def PashMap.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "
      
        PROGRAM DESCRIPTION:
          Wrapper to run preparesmallRNA.fastq.rb. It is a wrapper to filter the fastq file.
         
        COMMAND LINE ARGUMENTS:
          --file         | -f => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.
      
       usage:
       
      ruby removeAdaptarsWrapper.rb -f jsonFile  
      
        ";
            exit;
        end # 
      
      # Process Arguements form the command line input
      def PashMap.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          PashMap.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash
        
          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end 

end

optsHash = PashMap.processArguements()
performQCUsingFindPeaks = PashMap.new(optsHash)
performQCUsingFindPeaks.work()
