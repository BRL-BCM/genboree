#!/usr/bin/env ruby
require 'json'
require 'fileutils'

require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'


class AccountMap

   def initialize(optsHash)
        @input    = optsHash['--jsonFile']

   end
   

  def work
    
    
    jsonObj = JSON.parse(File.read(@input))
    
    
   
    input  = jsonObj["input"]
    output = jsonObj["output"]
    runName = jsonObj["settings"]["analysisName"]
    @refGenome = jsonObj["settings"]["refGenome"]
    @lffFile = jsonObj["settings"]["lffFile"]
    
    line =""
    puts input
    @baseName = File.basename(input[0])
    @scratch = "/scratch"
    system("grep '@' #{File.expand_path(output[0])}/#{@baseName}_WithoutAdaptors.fa.fastq | cut -d'_' -f3 |rubySumInput.rb > UsableReads.txt")
    reader = File.open("UsableReads.txt")
    reader.each { |line|
      line =line.split(/sum=/)
      puts line[1]
    }
    command = "accountForMappings.rb -p #{File.expand_path(output[0])}/#{@baseName}.pash3.0.Map.output.txt -o #{File.expand_path(output[0])} -r #{File.expand_path(output[0])}/#{@baseName}_WithoutAdaptors.fa -R #{@refGenome} -l #{@lffFile} -u #{line[1].to_i }"    
    puts command
    system(command)
  end
  
   def AccountMap.usage(msg='')
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
      def AccountMap.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          AccountMap.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash
        
          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end 

end

optsHash = AccountMap.processArguements()
performQCUsingFindPeaks = AccountMap.new(optsHash)
performQCUsingFindPeaks.work()
