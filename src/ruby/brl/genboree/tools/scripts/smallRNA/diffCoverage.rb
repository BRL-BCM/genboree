#!/usr/bin/env ruby

# Program for comparing coverage between two read sets compared to the same reference genome

# Author : Sameer Paithankar


#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'spreadsheet'


class DiffCoverage
  
  attr_accessor :lffFirst, :lffSecond, :mappedFirst, :mappedSecond, :outputDir, :file, :record, :trackHash1, :trackHash2, :count
  
  def initialize(lffFirst, lffSecond, mappedFirst, mappedSecond, outputDir, file)
    
    @lffFirst = lffFirst
    @lffSecond = lffSecond
    @mappedFirst = mappedFirst.to_i
    @mappedSecond = mappedSecond.to_i
    @file = file
    
    if(outputDir)
      @outputDir = outputDir
      system("mkdir -p #{@outputDir}")
    else
      @outputDir = Dir.pwd
    end
    
    
    findDiffCoverage()
    
  end
  
  def findDiffCoverage()
    
    #Hashes for storing file contents
    @trackHash1 = Hash.new{}
    @trackHash2 = Hash.new{}
    
    #Making readers for both coverage files
    @readerFirst = BRL::Util::TextReader.new(@lffFirst)
    @readerSecond = BRL::Util::TextReader.new(@lffSecond)
    
    #Getting basenames of both coverage files
    fileName1 = File.basename(@lffFirst)
    fileName2 = File.basename(@lffSecond)

    # Making Hash for the the first file    
    @readerFirst.each { |line|
      
      l1 = line.chomp.split(/\t/)
      track = l1[3].to_s; name = l1[1].to_s
      chr= l1[4]; start = l1[5].to_i; stop = l1[6].to_i
      coverage = l1[9].to_i
      key = "#{name}=#{track}=#{chr}=#{start}=#{stop}"
      if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
        if(!@trackHash1.has_key?(key))
          @trackHash1[key] = coverage
        end
      end
      
    }
    
    #Making Hash for the second file
    @readerSecond.each { |line|
      
      l1 = line.chomp.split(/\t/)
      track = l1[3].to_s; name = l1[1].to_s
      chr= l1[4]; start = l1[5].to_i; stop = l1[6].to_i
      coverage = l1[9].to_i
      if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
        key = "#{name}=#{track}=#{chr}=#{start}=#{stop}"
        if(!@trackHash2.has_key?(key))
          @trackHash2[key] = coverage
        end
      end
      
    }
    
    
    #Iterating through the first file (@trackHash1) to find matches in the second file (@trackHash2)
    #Names that match will be stored in an array for future reference
    fileHash = Hash.new{}
    tabHash = Hash.new{}
    tabCount = Hash.new{}
    Spreadsheet.client_encoding = 'UTF-8' # Setting Encoding
    book = Spreadsheet::Workbook.new
    nameArray = Array.new()
    nameArrayCount = 0
    excelRow = 0
    
    @trackHash1.each_key { |key1|
      
      @record = ""; @count = 0
      data1 = key1.to_s.split("=")
      name = data1[0]; track = data1[1]; chr = data1[2]; start = data1[3]; stop = data1[4]
      coverage1 = @trackHash1[key1].to_i

      #Opening track specific output file
      if(!fileHash.has_key?("#{@file}.#{track}"))
            
        ff = File.open("#{@outputDir}/#{@file}.#{track}", "w")
        fileHash["#{@file}.#{track}"] = ff
      
      end
      
      #Opening RNA and CpG Island track specific work sheets
      if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
        if(!tabHash.has_key?(track))
          
          sheet = book.create_worksheet
          sheet.name = "#{track}"
          tabHash[track] = sheet
          tabCount[track] = 0
          tabHash[track].row(tabCount[track]).insert 0, "fold change comparison for #{track}"
          tabCount[track] += 1
          tabHash[track].row(tabCount[track]).insert 0, "#{fileName1}"
          tabCount[track] += 1
          tabHash[track].row(tabCount[track]).insert 0, "#{fileName2}"
          tabCount[track] += 1
            
        end
      end
      
      @trackHash2.each_key { |key2|
        
        coverage2 = @trackHash2[key2].to_i
        
        if(key1 == key2)
          
          @count += 1
          nameArray[nameArrayCount] = key1
          nameArrayCount += 1
          
          normCov1 = (coverage1.to_f*@mappedSecond.to_f) / (coverage2.to_f*@mappedFirst.to_f)
          normCov2 = (coverage2.to_f*@mappedFirst.to_f) / (coverage1.to_f*@mappedSecond.to_f)
          
          @record = "#{name}\t#{chr}\t#{start}\t#{stop}\t#{coverage1}\t#{coverage2}\t#{normCov1}\t#{normCov2}\n"
          #print @record
          fileHash["#{@file}.#{track}"].print(@record)
          if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
              tabHash[track].row(tabCount[track]).insert 0, "#{name}", chr, start.to_i, stop.to_i, coverage1.to_i, coverage2.to_i, normCov1, normCov2 
              tabCount[track] += 1 
            
          end
        end
      
      }
       
      #In case of no match in the second sample (coverage == 0 in the second file)
      if(@count == 0)
        normCov1 = ((coverage1.to_f*@mappedSecond.to_f) / (1.0*@mappedFirst.to_f))
        normCov2 = ((1.0*@mappedFirst.to_f) / (coverage1.to_f*@mappedSecond.to_f))
        
        @record = "#{name}\t#{chr}\t#{start}\t#{stop}\t#{coverage1}\t0\t#{normCov1}\t#{normCov2}\n"
        #print @record
        fileHash["#{@file}.#{track}"].print(@record)
        
        if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
              tabHash[track].row(tabCount[track]).insert 0, "#{name}", chr, start.to_i, stop.to_i, coverage1.to_i, 0, normCov1, normCov2
              tabCount[track] += 1
            
        end
      end
      
    
    }
    
    puts "First file Scanned....."
    
    #Iterating through the second file and adding records to respective files if the annotation has not been covered previously
    #If so, the coverage for that annotation in the first sample will be 0
    
    @trackHash2.each_key { |key2|
      countExist = 0
      nameArray.each { |item|
        if(item == key2)
          countExist += 1
        end
      }
      
      if(countExist == 0)
        data = key2.split("=")
        name = data[0]; track = data[1]; chr = data[2]; start = data[3]; stop = data[4]
        coverage2 = @trackHash2[key2]
        normCov1 = ((1.0*@mappedSecond.to_f) / (coverage2.to_f*@mappedFirst.to_f))
        normCov2 = ((coverage2.to_f*@mappedFirst.to_f) / (1.0*@mappedSecond.to_f))
        @record = "#{name}\t#{chr}\t#{start}\t#{stop}\t0\t#{coverage2}\t#{normCov1}\t#{normCov2}\n"
        #print @record
        fileHash["#{@file}.#{track}"].print(@record)
        if(track =~ /RNA/ or track =~ /GC_CpgIslands/)
              tabHash[track].row(tabCount[track]).insert 0, "#{name}", chr, start.to_i, stop.to_i, 0, coverage2.to_i, normCov1, normCov2 
              tabCount[track] += 1
          
        end
      end
    }
      
    
    fileHash.each_key { |key|
      fileHash[key].close()  
    }
    
    book.write "#{@outputDir}/#{@file}.diffcoverage.xls"
    
    puts "Done"
  
  end
  
end



class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
  Program description: # Program for comparing coverage between two read sets (samples) compared to the same reference genome
 
  Arguments: 
    
    -a  --lffFirst  #Coverage file from the first sample
    -b  --lffSecond  #Coverage file from the second sample
    -x  --mappedFirst # No of reads mapped from the first sample
    -y  --mappedSecond # No of reads mapped from the second sample
    -d  --outputDir # Output Dir (default: pwd)
    -f  --file  # output file names root
    -v  --version #Version of the program
    -h  --help #Display help 
    
    Usage: 
    
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
    puts VERSION_NUMBER
    exit(0)
  end
    
  def self.parseArgs()
    methodName="performDiffCoverage"
    optsArray=[
      ['--lffFirst','-a',GetoptLong::REQUIRED_ARGUMENT],
      ['--lffSecond','-b',GetoptLong::REQUIRED_ARGUMENT],
      ['--mappedFirst','-x',GetoptLong::REQUIRED_ARGUMENT],
      ['--mappedSecond','-y',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDir','-d',GetoptLong::OPTIONAL_ARGUMENT],
      ['--file','-f',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT],
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end
    
  def self.performDiffCoverage(optsHash)
    DiffCoverage.new(optsHash['--lffFirst'], optsHash['--lffSecond'], optsHash['--mappedFirst'], optsHash['--mappedSecond'], optsHash['--outputDir'], optsHash['--file'])
  end
    
end


optsHash = RunScript.parseArgs()
RunScript.performDiffCoverage(optsHash)

