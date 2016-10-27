#!/usr/bin/env ruby
#Script  combines coverage information for multiple experiments

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'
require 'cgi'
require 'bigdecimal'


class Coverage
  
  
  def initialize(optsHash)
    @file     = optsHash['--file']
    @outputDir = File.expand_path(optsHash['--outputDir'])
    @usableReads = optsHash['--usableReads']
    @sampleType = optsHash['--sampleType']
    controlCount = 0
    sampleCount = 0
    @controlIndex=[]
    @sampleIndex =[]
    @foldCalcultaion = false
  
    if(@sampleType != nil )
       @foldCalcultaion = true
       @sampleTypeTemp = @sampleType.split(",")
      for i in 0...@sampleTypeTemp.size
	if(@sampleTypeTemp[i]=="control")
	  @controlIndex[controlCount] = i
	  controlCount +=1
	else
	  @sampleIndex[sampleCount] = i
	  sampleCount += 1
	end
      end
          

    end
    
    
    
    if(optsHash['--usableReads']!="")
      @arrayOfUsableReads = @usableReads.split(/,/)
    end
    
    @arrayOfFiles = @file.split(/,/)
    
    
  end
  
  
  # Reading files
  def fileReads()
    
    coverageHash = Hash.new {|hash,key| hash[key] = Hash.new{ |hash,key| hash[key] = [] }}     
    numOfFiles = @arrayOfFiles.size
    tempNew = []*numOfFiles
    joinedKey = Struct.new(:name, :chrom, :chrStart, :chrEnd, :strand, :coverage )
    values = []
    totalCoverage = Hash.new {|hash,key| hash[key] = Hash.new{ |hash,key| hash[key] = Hash.new(0) }}
    for ii in (0...numOfFiles)
      
        inputFileHandle = BRL::Util::TextReader.new(@arrayOfFiles[ii])
        coverage = 0
        inputFileHandle.each_line { |line|
            line.strip!
            column = line.split(/\t/)
            
            # Creating hash of hash of struct      
            subType = column[1] + "_" + column[4] + "_" + column[5] + "_" + column[6]
            if(coverageHash[column[3]].key?(subType))
              temp = coverageHash[column[3]][subType]
              temp.coverage[ii] = column[9]
              coverageHash[column[3]][subType] = temp
            else
              
              jk = joinedKey.new(column[1], column[4], column[5], column[6], column[7], [0]*numOfFiles)
              jk.coverage[ii] = column[9]
              coverageHash[column[3]][subType] = jk
            end
        
            ## Creating hash of array for stroing the total coverage for each subtype ( as key) and array( index of array is the file order)
             if(totalCoverage[column[3]].key?(ii))
              temp = totalCoverage[column[3]][ii]
              totalCoverage[column[3]][ii] = temp.to_i + column[9].to_i
            else
              totalCoverage[column[3]][ii] = column[9]
             end
                        
        }
        inputFileHandle.close 
    end
    
        coverageHash.each { |kk1, vv1|
          currentPath = @outputDir
          outputFileHandle = File.open(currentPath+"/"+"#{kk1}.xls", "w+")
          outputFileHandle.print "\t\t\t\t\t"
          for i in 0...numOfFiles
	    outputFileHandle.print "#{CGI.unescape(File.basename(@arrayOfFiles[i]))}\t#{@arrayOfUsableReads[i]}\t"
          end
          outputFileHandle.write "\nChrom\tChromStart\tChromEnd\tStrand\tName\t"
          for i in 0...numOfFiles
	    outputFileHandle.write "Counts\tPercentage\t"
          end
          if( @foldCalcultaion == true)
	    outputFileHandle.write "\tFold Change"
          end
          outputFileHandle.puts
          vv1.each { |kk2, vv2|
	    @controlSum = 0.00
            @sampleSum = 0.00
            outputFileHandle.print "#{vv2[:chrom]}\t#{vv2[:chrStart]}\t#{vv2[:chrEnd]}\t#{vv2[:strand]}\t#{vv2[:name]}\t"
            for jj in (0...numOfFiles)
                percent = 0.00
                
                begin
                  if(totalCoverage[kk1].key?(jj))
                    total = totalCoverage[kk1][jj]
                    if(!@usableReads.empty?)
		      total = @arrayOfUsableReads[jj].to_i
                    end
                    percent = (vv2.coverage[jj].to_f*100)/total
                    if(@foldCalcultaion == true)
		      if (@controlIndex.include?(jj))
			@controlSum = percent + @controlSum
			
		      end
		      if(@sampleIndex.include?(jj))
			@sampleSum = percent + @sampleSum
			
		      end
                    
                    end
                  end
                rescue
		 
                  $stderr.puts "error"
                end
               
                outputFileHandle.print "#{vv2.coverage[jj]}\t"
                outputFileHandle.printf('%.5f',percent)
                outputFileHandle.print "%\t"
                
            end
            if(@foldCalcultaion == true)
	      if(@controlSum==0)
		@controlSum =1
	      end
	      fold = @sampleSum/@controlSum.to_f
	      outputFileHandle.print "\t"
	      outputFileHandle.printf('%.5f',fold)
            end
            
            outputFileHandle.print "\n"
          }
          outputFileHandle.close         
        } 
  end
  
  # Process Arguements form the command line input
  def Coverage.processArguements()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--file'  ,    '-f', GetoptLong::REQUIRED_ARGUMENT],
		    ['--outputDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
		    ['--usableReads','-u', GetoptLong::OPTIONAL_ARGUMENT],
		    ['--sampleType' ,'-s', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help'       ,'-h',GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      Coverage.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
    
      Coverage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
  end
  
  
  # Display usage info and quit.
  def Coverage.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    Combines coverage information for multiple experiments. Creates the output files of names of the unique subtypes
    present in the files provided.
   
  COMMAND LINE ARGUMENTS:
    --file         | -f => lff files ( see below for example)
    --outputDir    | -o => output directory location
    --usableReads  | -u => [Optional] usable reads
    --sampleType   | -s => [Optional] smample type
    --help         | -h => [Optional flag]. Print help info and exit.

 usage:
 
 combineMultipleCoverageExperimentsByNameAndChromosomeLocation.rb -f 'file1.lff,file2.lff,file3.lff' -u '234,'234,343' -s 'sample,control,sample'


  ";
      exit;
  end # 
end

# Process command line options
 optsHash = Coverage.processArguements()
 exp = Coverage.new(optsHash)
 exp.fileReads
