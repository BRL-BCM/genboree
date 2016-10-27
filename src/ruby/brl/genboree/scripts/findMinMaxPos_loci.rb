#!/usr/bin/env ruby

#Program for finding the minimum (start) and the maximum (stop) positions (with buffer if needed) for each gene (1 entry for all isoforms)

#Loading libraries

require 'cgi'
require 'getoptlong'
require 'md5'
require 'brl/util/util'
require 'brl/util/textFileUtil'


class FindMinMax
  attr_accessor :lffFile, :outputLff, :class, :type, :subtype, :buffer, :geneHash, :posArray
  
  def initialize(lffFile, outputLff, gClass, type, subtype, buffer)
    @lffFile=lffFile #UCSC repeat file to be converted into lff format
    if(gClass)
      @gClass=gClass
    else
      @gClass="01.Loci"
    end
    if(type)
      @type=type
    else
      @type="Gene"
    end
    if(subtype)
      @subtype=subtype
    else
      @subtype="loci"
    end
    if(buffer)
      @buffer=buffer.to_i
    else
      @buffer=0
    end
    @outputLff=BRL::Util::TextWriter.new(outputLff) #Opening file for writing
    numberOfRecords=createMinMaxHash()
    
    if(numberOfRecords < 1)
      $stderr.puts "The file #{@lffFile} is empty"
      exit(12)
    end
    
    createLffFile()
  end
  
  def createMinMaxHash
    return nil if(@lffFile.nil?)
     
    begin     # Read lff file
      reader = BRL::Util::TextReader.new(@lffFile)
    rescue => err
      $stderr.puts "ERROR: file #{@lffFile} does not exist."
      exit(14)
    end
    counter=0 #For counting the no of lines in the input (.lff) file 
    @geneHash=Hash.new{} # Hash for storing HUGO accessions
    @posArray=Array.new()
    counter=0
    begin
      reader.each { |line |
        next if(line =~ /^\s*[#]/)
        next if(line.nil? or line.empty?)
        aa=line.chomp.split(/\t/)# split in tab
        next if( (aa.length < 2) or (aa[0] =~ /^[#\[]/) ) #skip lines with comments or empty
        acc = nil
        if(aa[1] =~ /\./)
          name = aa[1].split(".")
          acc = name[0]
        else
          acc = aa[1]
        end
 #Storing gene names (HUGO accessions) in a hash as keys and "posArray" as value
        # Avoid hap and random chromosomes
        if(aa[4] !~ /hap/ and aa[4] !~ /random/)
          if(@geneHash.has_key?(acc))
            tempArray = @geneHash[acc]
            if(aa[5].to_i < tempArray[5].to_i)# Checking whether starting position is smaller than the starting position for the previous isoform
              tempArray[5] = aa[5] #replacing starting position if new isoform has smaller start position 
            end
            if(aa[6].to_i > tempArray[6].to_i)# Checking whether stopping position is greater than the stopping position of the previous isoform
              tempArray[6] = aa[6] # Replacing stopping position if new isoform has greater stopping position
            end
          else
            @posArray = aa #Storing records in array (each column as a value)
            @geneHash[acc] = @posArray
          end
        end
        counter+=1
      }
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{reader.line.inspect}"
      return -1
    end
    reader.close()
    return counter
  end
  
  def createLffFile
    @geneHash.each_key{|key|
      temp=@geneHash[key]
      temp[0] = @gClass
      temp[1] = key
      temp[2] = @type
      temp[3] = @subtype
      temp[5] = temp[5].to_i
      temp[6] = temp[6].to_i
      temp[5] -= @buffer
      temp[6] += @buffer
      i=0
      temp.size.times do
        @outputLff.print temp[i].to_s+"\t"
        i+=1
      end
      @outputLff.print "\n"
    }
  end
  
end


class RunfindMinMaxPos

  
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
    
    Usage: Find the minimum and maximum positions for each gene with buffer (optional)
    
    Mandatory Arguments:
    
    -f  --lffFile  #lff file from which the minimum and maximum positions for each gene have to be calculated
    -o  --outputFile  #File for Output
    -c  --class # Selecting the class of the records (defaulted to 01.Loci) 
    -t  --type # Selecting type of the records (defaulted to Gene)
    -u  --subtype # Selecting subtype of records (defaulted to loci)
    -b  --buffer # Extending the length of gene. Adding to max and subtracting from min (defaulted to 0)
    -v  --version #Version of the program
    -h  --help #Display help
    
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
      methodName="performFindMinMax"
      optsArray=[
        ['--lffFile','-f',GetoptLong::REQUIRED_ARGUMENT],
        ['--outputFile','-o',GetoptLong::REQUIRED_ARGUMENT],
        ['--class','-c',GetoptLong::OPTIONAL_ARGUMENT],
        ['--type','-t',GetoptLong::OPTIONAL_ARGUMENT],
        ['--subtype','-u',GetoptLong::OPTIONAL_ARGUMENT],
        ['--buffer','-b',GetoptLong::OPTIONAL_ARGUMENT],
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
    
    def self.performFindMinMax(optsHash)
      FindMinMax.new(optsHash['--lffFile'],optsHash['--outputFile'],optsHash['--class'],optsHash['--type'],optsHash['--subtype'],optsHash['--buffer'])
    end
    
end
optsHash = RunfindMinMaxPos.parseArgs()
RunfindMinMaxPos.performFindMinMax(optsHash)

