#!/usr/bin/env ruby

# Program for computing fold coverage between two sets of Solexa lanes

#Author: Sameer Paithankar

#Loading Libraries

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'spreadsheet'

class PropFile
  
  attr_accessor :summarySet1, :summarySet2, :mappedReadsSet1, :mappedReadsSet2, :lffSet1, :lffSet2, :readLengthsSet1, :readLengthsSet2
  
  def initialize(file)
    
    # Read File generate error if file not found
    begin
      reader = BRL::Util::TextReader.new(file)
    rescue => err
      $stderr.puts "#{file} not found"
      exit(14)
    end
    
    reader.each_line { |line|
      if(line =~ /^summarySet1/)
        @summarySet1 = line.chomp.split("=")
        @summarySet1 = @summarySet1[1].split(",")
      elsif(line =~ /^summarySet2/)
        @summarySet2 = line.chomp.split("=")
        @summarySet2 = @summarySet2[1].split(",")
      elsif(line =~ /^mappedReadsSet1/)
        @mappedReadsSet1 = line.chomp.split("=")
        @mappedReadsSet1 = @mappedReadsSet1[1].split(",")
      elsif(line =~ /^mappedReadsSet2/)
        @mappedReadsSet2 = line.chomp.split("=")
        @mappedReadsSet2 = @mappedReadsSet2[1].split(",")
      elsif(line =~ /^lffSet1/)
        @lffSet1 = line.chomp.split("=")
        @lffSet1 = @lffSet1[1].split(",")
      elsif(line =~ /^lffSet2/)
        @lffSet2 = line.chomp.split("=")
        @lffSet2 = @lffSet2[1].split(",")
      elsif(line =~ /^readLengthsSet1/)
        @readLengthsSet1 = line.chomp.split("=")
        @readLengthsSet1 = @readLengthsSet1[1].split(",")
      elsif(line =~ /^readLengthsSet2/)
        @readLengthsSet2 = line.chomp.split("=")
        @readLengthsSet2 = @readLengthsSet2[1].split(",")
      end
    }
  
  
    # Do error checks:
    # Check if all info is present
    if(@summarySet1.nil? or @summarySet2.nil? or @mappedReadsSet1.nil? or @mappedReadsSet2.nil? or @lffSet1.nil? or  @lffSet2.nil? or @readLengthsSet1.nil? or @readLengthsSet2.nil?)
      $stderr.puts "One or more of the necessary information is missing. Make sure the properties file has all of the following information:"
      $stderr.print "summarySet1\nsummarySet2\nmappedReadsSet1\nmappedReadsSet2\nlffSet1\nlffSet2\nreadLengthsSet1\nreadLengthsSet2\n"
      exit(14)
    else
      $stderr.puts "Properties file scanned."
    end
    
    
  end
  
end


class FoldCoverage
  
  attr_accessor :propFile, :fileObj, :rowC, :score, :sumCountArray, :countArray, :countArrayRow, :countArrayCol, :hashCount
  attr_accessor :colArray, :placer, :rowCount, :chr, :start, :stop, :annoArray, :col4, :col5, :col7, :col8, :col9, :col10, :col11
  def initialize(propFile)
    
    @propFile = propFile
    
    createExcel()

    
  end
  
  
  
  def createExcel()
    @fileObj = PropFile.new(@propFile)
    Spreadsheet.client_encoding = 'UTF-8' # Setting Encoding
    
    # Creating excel workbook
    book = Spreadsheet::Workbook.new
    
    # Sheet1 for summary data
    sheet1 = book.create_worksheet
    sheet1.name = "summary"
    # Sheet2 for read length data
    sheet2 = book.create_worksheet
    sheet2.name = "read lengths"
    
    # Combining all the summary files
    allSummaryFiles = Array.new()
    allReadLengths = Array.new()
    ii = 0
    @fileObj.summarySet1.each { |file|
      allSummaryFiles[ii] = file
      ii += 1
    }
    @fileObj.summarySet2.each { |file|
      allSummaryFiles[ii] = file
      ii += 1
    }
    
    ii = 0
    @fileObj.mappedReadsSet1.each { |reads|
      allReadLengths[ii] = reads.to_i
      ii += 1
    }
    @fileObj.mappedReadsSet2.each { |reads|
      allReadLengths[ii] = reads.to_i
      ii += 1
    }
    fileHead = 3; totalReadsHead = 3; countHead = 3; percentHead = 4; readsMappedCount = 0 # Initializing counters
    
    # Make tab for summary 
    summaryFileCounter = 0; countColumnCount = 3
    allSummaryFiles.each { |summaryFile|
      begin
        reader = BRL::Util::TextReader.new(summaryFile)
      rescue => err
        $stderr.puts "#{summaryFile} not found"
        exit(14)
      end
      summaryFileCounter += 1
      fileName = File.basename(summaryFile)
      fileName = fileName.split(".")
      fileName = fileName[0]
      sheet1.row(0).insert fileHead, fileName
      fileHead += 2
      sheet1.row(1).insert totalReadsHead, "Total Reads", allReadLengths[readsMappedCount]
      totalReadsHead += 2
      sheet1.row(2).insert countHead, "Count"
      countHead += 2
      sheet1.row(2).insert percentHead, "%"
      percentHead += 2
      rowCount = 3
      reader.each_line { |line|
        data = line.chomp.split(/\t/)
        
        
        if(summaryFileCounter == 1)
          percentVal = data[3].to_f / allReadLengths[readsMappedCount].to_f
          sheet1.row(rowCount).insert 0, data[0], data[1], data[2], data[3], percentVal
          rowCount += 1;
        else
          percentVal = data[3].to_f / allReadLengths[readsMappedCount].to_f
          sheet1.row(rowCount).insert countColumnCount, data[3], percentVal
          rowCount += 1; 
        end
        
      }
      readsMappedCount += 1; countColumnCount += 2
    }
    
    
    # Make tab for read mapping lengths
    # Combining all read mapping lengths files
    allReadLengthFiles = Array.new()
    ii = 0
    @fileObj.readLengthsSet1.each { |file|
      allReadLengthFiles[ii] = file
      ii += 1
    }
    @fileObj.readLengthsSet2.each { |file|
      allReadLengthFiles[ii] = file
      ii += 1
    }
    
    fileNameCount = 0; fileHead = 1; countPercentHead = 1; readsMappedCount = 0
    sheet2.row(0).insert 0, "Mapping Length"
    fileCounter = 0
    allReadLengthFiles.each { |file|
      begin
        reader = BRL::Util::TextReader.new(file)
      rescue => err
        $stderr.puts "#{file} not found"
        exit(14)
      end
      fileCounter += 1
      fileName = File.basename(allSummaryFiles[fileNameCount])
      fileName = fileName.split(".")
      fileName = fileName[0]
      fileNameCount += 1
      
      sheet2.row(0).insert fileHead, fileName
      fileHead += 2
      sheet2.row(1).insert countPercentHead, "Count", "Percent"
      
      rowCount = 2
      reader.each_line { |line|
        data = line.chomp.split(/\t/)
        
        
        if(fileCounter == 1)
          percentVal = data[1].to_f / allReadLengths[readsMappedCount].to_f
          sheet2.row(rowCount).insert 0, data[0], data[1], percentVal
          rowCount += 1;
        else
          percentVal = data[1].to_f / allReadLengths[readsMappedCount].to_f
          sheet2.row(rowCount).insert countPercentHead, data[1], percentVal
          rowCount += 1; 
        end
        
      }
      if(fileCounter == 1)
        sheet2.row(rowCount).insert 0, "Total", allReadLengths[readsMappedCount]
      else
        sheet2.row(rowCount).insert countPercentHead, allReadLengths[readsMappedCount] 
      end
      readsMappedCount += 1; countPercentHead += 2
    }
    
    # Tab for each RNA and cpgIsland track
    trackHash = Hash.new{}
    allLffFiles = Array.new()
    ii = 0
    @fileObj.lffSet1.each {|file|
      allLffFiles[ii] = file
      ii += 1
    }
    @fileObj.lffSet2.each { |file|
      allLffFiles[ii] = file
      ii += 1
    }
    
    @hashCount = Hash.new{}
    allLffFiles.each { |file|
  
      begin
        reader = BRL::Util::TextReader.new(file)
      rescue => err
        $stderr.puts "#{file} not found"
        exit(14)
      end
      
      # Make a list for all the names(annotations) for each track (for RNA and CpG Island)
      reader.each_line { |line|
        data = line.chomp.split(/\t/)
        if(data[3] =~ /RNA/ or data[3] =~ /CpgIslands/i)
          #print "#{line}\t"
          track = data[3].split("_")
          track = track[1]
          if(trackHash.has_key?(track))
            val = "#{data[3]}=#{data[1]}=#{data[4]}=#{data[5]}=#{data[6]}" 
            trackHash[track][val.to_s] = nil if(!trackHash.has_key?(val.to_s))
            
          else
            trackHash[track] = Hash.new{}; 
            val = "#{data[3]}=#{data[1]}=#{data[4]}=#{data[5]}=#{data[6]}"
            trackHash[track][val.to_s] = nil
            
          end
          
        end
      }
      
    }
    
    # For each name (annotation) for each track, iterate over all files to fill in the count for that annoation
    #For each track, creat a tab in the excel workbook
    tabHash = Hash.new{}; foldHash = Hash.new{}
    @sumCountArray = Array.new()
    @countArray = Array.new()
    trackHash.each_key { |track|
      
      fileHeadCount = 4; countPercentCount = 4
      @rowC = 0
      sheet = book.create_worksheet
      sheet.name = "Combined read coverage for #{track}"
      tabHash[track] = sheet
    
      allSummaryFiles.size.times { |ii|
        fileName = File.basename(allSummaryFiles[ii])
        fileName = fileName.split(".")
        fileName = fileName[0]
        tabHash[track].row(@rowC).insert fileHeadCount, fileName
        fileHeadCount += 2
      }
      @rowC += 1
      sheet.row(@rowC).insert 0, "Name", "chrom", "chromStart", "chromStop"
      allSummaryFiles.size.times { |ii|
        tabHash[track].row(@rowC).insert countPercentCount, "Count", "Percent"
        countPercentCount += 2
      }
      @rowC += 1
      
      @countArrayRow = 0; @annoArray = Array.new(); annoCount = 0; @sumCountArray = Array.new(allLffFiles.size)
      @sumCountArray.size.times { |ii|
        @sumCountArray[ii] = 0  
      }
      trackHash[track].each_key { |annotation|
        contents = annotation.split("=")
        anno = contents[1]; 
        @annoArray[annoCount] = annotation
        annoCount += 1
        @chr = contents[2]; @start = contents[3].to_i; @stop = contents[4].to_i
        tabHash[track].row(@rowC).insert 0, "#{anno.to_s}", "#{@chr}", @start, @stop
        @rowC += 1
        arrayCount = 0; annoPlacer = 3; @countArrayCol = 0; @colArray = Array.new() 
        allLffFiles.each { |file|
          @score = 0
          reader = BRL::Util::TextReader.new(file)
          reader.each_line { |line|
            data = line.chomp.split(/\t/)
            if(data[1].to_s == anno.to_s)
              @score = data[9].to_i; 
              break
            end
          }
          
          
          @sumCountArray[arrayCount] = @sumCountArray[arrayCount] + @score 
          arrayCount += 1; 
          
          @colArray[@countArrayCol] = @score
          @countArrayCol += 1
        }
        @countArray[@countArrayRow] = @colArray
        @countArrayRow += 1  ; @colArray = Array.new()
      }
      
      #Adding percentages for the annoations:
      @rowCount = 2 
      @countArray.size.times { |ii|
        @placer = 4
        @countArray[ii].size.times { |jj|
          value = @countArray[ii][jj].to_f / @sumCountArray[jj].to_f
          tabHash[track].row(@rowCount).insert @placer, @countArray[ii][jj], value
          @placer += 2
        }
        @rowCount += 1
      }
      setSize = @sumCountArray.size / 2
      
      # Making tabs for differential fold coverage
      sheet = book.create_worksheet
      sheet.name = "Differential fold coverage for #{track}"
      foldHash[track] = sheet
      @rowC = 0
      foldHash[track].row(@rowC).insert 0, "Name", "chrom", "chromStart", "chromStop"
      @rowC += 1
      
      @annoArray.size.times { |ii|
        contents = @annoArray[ii].split("=")
        @chr = contents[2]; @start = contents[3].to_i; @stop = contents[4].to_i 
        foldHash[track].row(@rowC).insert 0, "#{contents[1]}", "#{@chr}", "#{@start}", "#{@stop}"
        @col4 = 0.0
        setSize.times { |jj|
          @col4 = @col4 + (@countArray[ii][jj].to_f/@sumCountArray[jj].to_f)   
        }
        @col5 = 0.0
        jj = setSize
        setSize.times {
          @col5 = @col5 + (@countArray[ii][jj].to_f/@sumCountArray[jj].to_f)
          jj += 1
        }
        @col6 = @col4 / @col5; @col7 = @col5 / @col4
        @col8 = 0.0
        @fileObj.mappedReadsSet1.size.times { |reads|
          @col8 = @col8 + (@countArray[ii][reads].to_f / @fileObj.mappedReadsSet1[reads].to_f)
        }
        @col9 = 0.0
        jj = setSize
        @fileObj.mappedReadsSet2.size.times { |reads|
          @col9 = @col9 + (@countArray[ii][jj].to_f / @fileObj.mappedReadsSet2[reads].to_f)
          jj += 1
        }
        @col10 = @col8 / @col9; @col11 = @col9 / @col8
        foldHash[track].row(@rowC).insert 4, @col4, @col5, @col6, @col7, @col8, @col9, @col10, @col11
        @rowC += 1
      }
      @sumCountArray = Array.new(); @countArray = Array.new()
    }
    
    
    
    
    
    book.write "foldCoverage.xls"
    $stderr.puts "Excel work book created."
    
  end
  
end




class RunScript
  
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
  
  
  Description: Program for computing fold change between two sets of Solexa lanes. An excel work book with the relevant information is created
  Note: The order of the files has to be consistent for all atribute-value pairs
  Mandatory Arguments:
    
    -f  --propFile => properties file with all the input information
    -v  --version => Version of the program
    -h  --help => Display help
    
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
    methodName="performFoldCoverage"
    optsArray=[
      ['--propFile','-f',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
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
    
  def self.performFoldCoverage(optsHash)
    FoldCoverage.new(optsHash['--propFile'])
  end
  
end

optsHash = RunScript.parseArgs()
RunScript.performFoldCoverage(optsHash)

