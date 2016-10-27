#!/usr/bin/env ruby

#Author: Sameer Paithankar

#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'spreadsheet'


class AccountMappings
  
  attr_accessor :pashFile, :readsFile, :outputDir, :readName, :refFile, :lffFile, :usableReads
  
  def initialize(pashFile, outputDir, readsFile, refFile, lffFile, usableReads)
    
    @pashFile = pashFile
    @readsFile = readsFile
    @refFile = refFile
    @lffFile = lffFile
    @readName = File.basename(@readsFile)
    @readName = @readName.split(".")
    @readName = readName[0]
    
    if(usableReads)
      @usableReads = usableReads
    else
      @usableReads = 'N'
    end
   
    
    if(outputDir)
      @outputDir = outputDir
    else
      @outputDir = Dir.pwd
    end
    
    
    system("mkdir -p #{@outputDir}")
    
    createReadsOffsetFile() # Wrapper for makeReadsOffset.rb
    puts "Reads Offset File Created"
    
    getLengths() # Wrapper for getMappingLengths.exe
    puts "Mappings Lengths Calculated"
    
    intersect() # Wrapper for mappingsOntoLff.exe
    puts "Intersection done"
    
    getExcelSheets() # For creating excel sheets
    puts "Excel workbook created"
    
    
    
  end

  def createReadsOffsetFile
    command = "makeReadsOffset.rb -r #{@readsFile} -o #{@outputDir}/#{@readName}.off > #{@outputDir}/log.readsOffset.#{@readName} 2>&1"
    system(command)
    $stderr.puts "makeReadsOffset command = #{command}"
  end

  def getLengths
    command = "getMappingLengths.exe -p #{@pashFile} -o #{@outputDir}/#{@readName}.mappingLengths -r #{@outputDir}/#{@readName}.off -t > #{@outputDir}/log.getMappingLengths.#{@readName} 2>&1"
    system(command)
    $stderr.puts "getMappingLengths command = #{command}"
  end
  
  def intersect
    labelsHash = {}
    rr = BRL::Util::TextReader.new(@lffFile)
    rr.each {|ll|
      ff = ll.split(/\t/) 
      buff = ""
      buff << ff[0] <<":" << ff[2] <<":"<<ff[3]
      if (!labelsHash.key?(buff)) then
	labelsHash[buff]=1
	$stderr.puts "added track #{buff}"
      end
    }
    rr.close()

# collect lff class:type:subtype
    newLabel=""
    label=nil
    labelsHash.keys.each {|label|
      if (label=~/(\S+):(\S+):(\S+)/) then 
        newLabel<< label <<";" << "#{@readName}:#{@readName}:#{$2}_#{$3};" 
      end
    }
    command = "mappingsOntoLff.exe -p #{@pashFile} -T #{@outputDir}/#{@readName}.trackIntersect.is "
    command << "-o #{@outputDir}/#{@readName}.trackSummaryOutput.is -r #{@outputDir}/#{@readName}.off "
    command << "-R #{@refFile} -l #{@lffFile} -t -s . -L #{@outputDir}/#{@readName}.trackCoverage.lff -n #{@outputDir}/#{@readName}.nameCount.is -N \"#{newLabel}\" > #{@outputDir}/log.mapIntersect.#{@readName} 2>&1"
    system(command)
    $stderr.puts "mappingsOntoLff command = #{command}"
  end
  
  def getExcelSheets
  
    #Creating small RNA specific lff files:
    
   
    grepCommand =  "grep -i \"RNA_miRNA\" #{@outputDir}/#{@readName}.trackCoverage.lff > #{@outputDir}/miRNA.lff"
    $stderr.puts "grep command #{grepCommand}"
    system(grepCommand)
    system("grep snoRNA #{@outputDir}/#{@readName}.trackCoverage.lff > #{@outputDir}/snoRNA.lff")
    system("grep piRNA #{@outputDir}/#{@readName}.trackCoverage.lff > #{@outputDir}/piRNA.lff")
    system("grep scaRNA #{@outputDir}/#{@readName}.trackCoverage.lff > #{@outputDir}/scaRNA.lff")
    system("grep GC_CpgIslands #{@outputDir}/#{@readName}.trackCoverage.lff > #{@outputDir}/cpg.lff")
    
    Spreadsheet.client_encoding = 'UTF-8' # Setting Encoding
    book = Spreadsheet::Workbook.new
    sheet1 = book.create_worksheet
    sheet2 = book.create_worksheet
    sheet3 = book.create_worksheet
    sheet4 = book.create_worksheet
    sheet5 = book.create_worksheet
    sheet6 = book.create_worksheet
    sheet7 = book.create_worksheet
    
    sheet1.name = "summary" 
    sheet2.name = "read lengths" 
    sheet3.name = "miRNAs"
    sheet4.name = "snoRNAs"
    sheet5.name = "piRNAs"
    sheet6.name = "CpG Islands"
    sheet7.name = "scaRNAs"
    
    #Reading output files

    #readerSummary = BRL::Util::TextReader.new("#{@outputDir}/#{@readName}.trackSummaryOutput.is")
    readerLength = BRL::Util::TextReader.new("#{@outputDir}/#{@readName}.mappingLengths")
    #miRNARead = BRL::Util::TextReader.new("#{@outputDir}/miRNA.lff")
    #snoRNARead = BRL::Util::TextReader.new("#{@outputDir}/snoRNA.lff")
    #piRNARead = BRL::Util::TextReader.new("#{@outputDir}/piRNA.lff")
    #scaRNARead = BRL::Util::TextReader.new("#{@outputDir}/scaRNA.lff")
    #cpgRead = BRL::Util::TextReader.new("#{@outputDir}/cpg.lff")
    
    miRNARead = IO.popen("sort -k 10,10nr #{@outputDir}/miRNA.lff","r" )
    snoRNARead = IO.popen("sort -k 10,10nr #{@outputDir}/snoRNA.lff", "r")
    piRNARead  = IO.popen("sort -k 10,10nr #{@outputDir}/piRNA.lff", "r")
    scaRNARead = IO.popen("sort -k 10,10nr #{@outputDir}/scaRNA.lff", "r")
    cpgRead = IO.popen("sort -k 10,10nr #{@outputDir}/cpg.lff", "r" )
    #readerLength = IO.popen("sort -k 2,2nr #{@outputDir}/#{@readName}.mappingLengths", "r")
    readerSummary = IO.popen("sort -k 1,1 -k 2,2 -k 3,3 #{@outputDir}/#{@readName}.trackSummaryOutput.is", "r")
    
    counterSummary = 3
    counterLength = 2
    countLength = 0
    lineCount = 0
    countArray = Array.new()
    countArrayCount = 0
    
    begin
      readerSummary.each { |line|
	
	if(line =~ /class/)
	  line = ""
	  end
	  line = line.chomp.split(/\t/)
	  next if(line.nil? or line.empty?)
	  line.size.times { |ii|
	    if(ii < 3)
	      sheet1.row(counterSummary).insert ii, line[ii]
	    elsif(ii == 3)
	      sheet1.row(counterSummary).insert ii, line[ii].to_i
	      countArray[countArrayCount] = line[ii].to_i
	      countArrayCount += 1
	    end
	  }
	#end
	counterSummary += 1
	lineCount += 1
      }
      
      countSummary = countSummary.to_i
      
      sheet1[0,3] = @readName; sheet1[1,3] = "Total reads"; sheet1[2,3] = "Count"; sheet1[2,4] = "%"
      
      summaryArray = countArray
      
      countArray = Array.new()
      countArrayCount = 0
      lineCount = 0
      readerLength.each { |line|

	line = line.chomp.split(/\t/)
	next if(line.nil? or line.empty?)
	line.size.times { |ii|
	  sheet2.row(counterLength).insert ii, line[ii].to_i
	if(ii == 1)
	    countLength = countLength.to_i + line[ii].to_i
	    countArray[countArrayCount] = line[ii].to_i
	    countArrayCount += 1
	  end
	}	
	
	counterLength += 1
	lineCount += 1
      }
      
      totalMaped = countLength
      countLength = @usableReads
      
      sheet1.row(1).insert 4, countLength
      sheet2.row(counterLength).insert 1, totalMaped
      sheet2[0,0] = "Mapping Length"; sheet2[0,1] = @readName; sheet2[1,1] = "Count"; sheet2[counterLength,0] = "Total";  sheet2[1,2] = "Percent"
      
      ii = 2; jj = 2
    
      lineCount.times { |cc|
	val = (countArray[cc].to_f / countLength.to_f)
	row = sheet2.row(ii)
	row.set_format jj, Spreadsheet::Format.new(:number_format => '0.0')
	
	row[jj] = val 
	ii += 1
	
      }
      
      ii = 3
      jj = 4
      
      summaryArray.size.times { |cc|
	val = (summaryArray[cc].to_f / countLength.to_f)
	sheet1.row(ii).insert jj, val
	ii += 1
	
      }
      
      miRNAHash = Hash.new{}
      snoRNAHash = Hash.new{}
      piRNAHash = Hash.new{}
      cpgHash = Hash.new{}
      scaRNAHash = Hash.new{}
      
      sumMiRNA = 0
      sumSnoRNA = 0
      sumPiRNA = 0
      sumCPG = 0
      sumScaRNA = 0
      tempArray = Array.new()
      rowCount = 2
      ii = 0
      
      miRNARead.each { |line|

	line = line.chomp.split(/\t/)
	sumMiRNA = sumMiRNA + line[9].to_i
	sheet3.row(rowCount).insert 0, line[1], line[9].to_i
	tempArray[ii] = line[9].to_i
        rowCount += 1
        ii += 1
      
      }
      
      rowCount = 2
      tempArray.size.times { |ii|
	
	  val = tempArray[ii].to_f / countLength.to_f
	
	sheet3.row(rowCount).insert 2, val
	rowCount += 1
		
      }
      
      rowCount = 2
      tempArray = Array.new()
      ii = 0
      snoRNARead.each { |line|

	line = line.chomp.split(/\t/)
	sumSnoRNA = sumSnoRNA + line[9].to_i
	sheet4.row(rowCount).insert 0, line[1], line[9].to_i
	tempArray[ii] = line[9].to_i
        rowCount += 1
        ii += 1
      
      }
      
      rowCount = 2
      tempArray.size.times { |ii|
	
	  val = tempArray[ii].to_f / countLength.to_f
	
	sheet4.row(rowCount).insert 2, val
	rowCount += 1	
      
      }

      rowCount = 2
      tempArray = Array.new()
      ii = 0
      piRNARead.each { |line|

	line = line.chomp.split(/\t/)
	sumPiRNA = sumPiRNA + line[9].to_i
	sheet5.row(rowCount).insert 0, line[1], line[9].to_i
	tempArray[ii] = line[9].to_i
        rowCount += 1
        ii += 1
      
      }
      
      rowCount = 2
      tempArray.size.times { |ii|
	
	  val = tempArray[ii].to_f / countLength.to_f
	
	sheet5.row(rowCount).insert 2, val
	rowCount += 1	
      
      }
      
      rowCount = 2
      tempArray = Array.new()
      ii = 0
      cpgRead.each { |line|

	line = line.chomp.split(/\t/)
	sumCPG = sumCPG + line[9].to_i
	sheet6.row(rowCount).insert 0, line[1], line[9].to_i
	tempArray[ii] = line[9].to_i
        rowCount += 1
        ii += 1
      
      }
      
      rowCount = 2
      tempArray.size.times { |ii|
	
	  val = tempArray[ii].to_f / countLength.to_f
	
	sheet6.row(rowCount).insert 2, val
	rowCount += 1	
      
      }
      
      rowCount = 2
      tempArray = Array.new()
      ii = 0
      scaRNARead.each { |line|

	line = line.chomp.split(/\t/)
	sumScaRNA = sumScaRNA + line[9].to_i
	sheet7.row(rowCount).insert 0, line[1], line[9].to_i
	tempArray[ii] = line[9].to_i
        rowCount += 1
        ii += 1
      
      }
      
      rowCount = 2
      tempArray.size.times { |ii|
	
	  val = tempArray[ii].to_f / countLength.to_f
	
	sheet7.row(rowCount).insert 2, val
	rowCount += 1	
      
      }
      
      
      sheet3[1,0] = "Name"; sheet3[0,1] = "#{@readName}.miRNA"; sheet3[1,1] = "Count"; sheet3[1,2] = "Percentage"
      sheet4[1,0] = "Name"; sheet4[0,1] = "#{@readName}.snoRNA"; sheet4[1,1] = "Count"; sheet4[1,2] = "Percentage"
      sheet5[1,0] = "Name"; sheet5[0,1] = "#{@readName}.piRNA"; sheet5[1,1] = "Count"; sheet5[1,2] = "Percentage"
      sheet6[1,0] = "Name"; sheet6[0,1] = "#{@readName}.cpgIslands"; sheet6[1,1] = "Count"; sheet6[1,2] = "Percentage"
      sheet7[1,0] = "Name"; sheet7[0,1] = "#{@readName}.scaRNA"; sheet7[1,1] = "Count"; sheet7[1,2] = "Percentage"
      
      
      
      
      
      book.write "#{@outputDir}/#{@readName}.xls" 

    rescue => err
      $stderr.puts "Details: #{err.message}"
      exit()
    end

  end


  
end


class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
  Program description: #Program for intersection of pash mapping output with lff annotations, computing distribution of read mapping lengths and generating an excel report 
        
     
  Mandatory Arguments: 
    
    -p  --pashMap  #output from Pash-3.0.exe 
    -o  --outputDir  #output Dir for storing all output files.
    -r  --readsFile  #reads file generated from prepareSmallRna.rb
    -R  --refFile #chromosome offset file
    -l  --lffFile #lff file to find intersection
    -v  --version #Version of the program
    -u  --usableReads
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
    methodName="performAccountMappings"
    optsArray=[
      ['--pashFile','-p',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDir','-o',GetoptLong::OPTIONAL_ARGUMENT],
      ['--readsFile','-r',GetoptLong::REQUIRED_ARGUMENT],
      ['--refFile','-R',GetoptLong::REQUIRED_ARGUMENT],
      ['--lffFile','-l',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--usableReads', '-u', GetoptLong::OPTIONAL_ARGUMENT],
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
    
  def self.performAccountMappings(optsHash)
    AccountMappings.new(optsHash['--pashFile'], optsHash['--outputDir'], optsHash['--readsFile'], optsHash['--refFile'], optsHash['--lffFile'], optsHash['--usableReads'])
  end
    
end


optsHash = RunScript.parseArgs()
RunScript.performAccountMappings(optsHash)
