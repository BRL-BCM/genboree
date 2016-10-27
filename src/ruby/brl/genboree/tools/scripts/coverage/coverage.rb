#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'

class SignalCoverage
  CoverageStruct = Struct.new(:chrom, :start, :end, :array)
  BUFFERSIZE = 32_000_000
  MAXBUFFER = 5_000_000
  FORMAT_HASH = {'bed' => nil, 'gff' => nil, 'gtf' => nil, 'gff3' => nil, 'lff' => nil, 'bedGraph' => nil}
  # [+Constructor+]
  # [+optsHash+] command line options
  # [+returns+] nil
  def initialize(optsHash)
    @userEmail = nil
    @jobId = nil
    @userEmail = optsHash['--userEmail'] unless(optsHash['--userEmail'].nil?)
    @jobId = optsHash['--jobId'] unless(optsHash['--jobId'].nil?)
    @inputFile = optsHash['--inputFile']
    @trackName = optsHash['--trackName']
    @useScore = optsHash['--useScore'].nil? ? nil : "true"
    begin
      @fileType = optsHash['--fileType']
      raise "Unknown format type: #{@fileType}" if(!FORMAT_HASH.has_key?(@fileType))
      raise "--trackName does not have a ':'" if(@trackName !~ /:/)
      raise "File: #{@inputFile} not found" if(!File.exists?(@inputFile))
      @bedReader = File.open(@inputFile)
      @wigWriter = File.open(optsHash['--outputFile'], "w")
      compCoverage()
      $stderr.puts "coverage.rb - all done"
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # computes coverage of bed file
  # buffers the output and writes it out in chunks
  # [+returns+] nil
  def compCoverage()
    orphan = nil
    covObj = CoverageStruct.new(nil, nil, nil, [])
    outBuffer = "track type=wiggle_0 name='#{@trackName}'\n" # start with the track header line
    $stderr.puts "Processing file...."
    while(!@bedReader.eof?)
      fileBuff = @bedReader.read(BUFFERSIZE)
      buffIO = StringIO.new(fileBuff)
      chrom = nil
      chromEnd = nil
      chromStart = nil
      score = 0
      buffIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          line.strip!
          next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
          currRec = line.split(/\t/)
          # subtract 1 from the start coord from all non 0 start formats
          case @fileType
          when 'bed'
            chrom = currRec[0]
            chromStart = currRec[1].to_i
            chromEnd = currRec[2].to_i
            score = currRec[4].to_f
          when 'lff'
            chrom = currRec[4]
            chromStart = currRec[5].to_i - 1
            chromEnd = currRec[6].to_i
            score = currRec[9].to_f
          when 'bedGraph'
            chrom = currRec[0]
            chromStart = currRec[1].to_i
            chromEnd = currRec[2].to_i
            score = currRec[3].to_f
          when 'gff'
            chrom = currRec[0]
            chromStart = currRec[3].to_i - 1
            chromEnd = currRec[4].to_i
            score = currRec[5].to_f
          when 'gff3'
            chrom = currRec[0]
            chromStart = currRec[3].to_i - 1
            chromEnd = currRec[4].to_i
            score = currRec[5].to_f
          when 'gtf'
            chrom = currRec[0]
            chromStart = currRec[3].to_i - 1
            chromEnd = currRec[4].to_i
            score = currRec[5].to_f
          end
          # Add block header if :chrom is nil or if chrom from currAnno
          # is not equal to the set :chrom or if
          # currAnno does not overlap the coverage structure
          # Also initialize :array in the coverage structure
          if(covObj.chrom.nil? or covObj.chrom != chrom or chromStart >= covObj.end or chromEnd <= covObj.start)
            if(!covObj.chrom.nil?)
              covObj.array.each { |value|
                outBuffer << "#{value}\n"
              }
            end
            outBuffer << "fixedStep chrom=#{chrom} start=#{chromStart + 1} span=1 step=1\n"
            if(@useScore.nil?)
              covObj.array = Array.new((chromEnd - chromStart), 1)
            else
              covObj.array = Array.new((chromEnd - chromStart), score)
            end
            covObj.start = chromStart
            covObj.end = chromEnd
            covObj.chrom = chrom
            if(outBuffer.size >= MAXBUFFER)
              @wigWriter.print(outBuffer)
              outBuffer = ""
            end
            next
          end
          numToShift = chromStart - covObj.start
          numToShift.times { |ii|
            outBuffer << "#{covObj.array.shift}\n"
          }
          covObj.start += numToShift
          numToIcr = ( (covObj.end > chromEnd ? chromEnd : covObj.end) - covObj.start )
          if(@useScore.nil?)
            numToIcr.times { |ii|
              covObj.array[ii] += 1
            }
          else
            numToIcr.times { |ii|
              covObj.array[ii] += score
            }
          end
          numToGrow = (covObj.end > chromEnd ? 0 : (chromEnd - covObj.end))
          covObj.end += numToGrow
          if(@useScore.nil?)
            numToGrow.times { |ii|
              covObj.array << 1
            }
          else
            numToGrow.times { |ii|
              covObj.array << score
            }
          end
          if(outBuffer.size >= MAXBUFFER)
            @wigWriter.print(outBuffer)
            outBuffer = ""
          end
        else
          orphan = line
        end
      }
    end
    covObj.array.each { |value|
      outBuffer << "#{value}\n"
    }
    @wigWriter.print(outBuffer) if(!outBuffer.empty?)
    outBuffer = ""
    @wigWriter.close
    @bedReader.close
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR from coverage.rb:\n #{msg}"
    $stderr.puts "ERROR Backtrace from coverage.rb:\n #{msg.backtrace}"
    exit(14)
  end

end

# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is used for computing base level coverage from a bed file and producing a fixedStep
  wig file with a span of 1. Note that this tool only works on bed files which have been sorted by BOTH chrom start and end coords

  Notes: Intended to be called via the Genboree Workbench
    -i  --inputFile                     => input file (required)
    -f  --fileType                      => format of the file (Accepted formats: 'bed', 'lff', 'bedGraph', 'gff', 'gff3', 'gtf') (required)
    -o  --outputFile                    => output wig file (required)
    -t  --trackName                     => wig file track name (required)
    -e  --userEmail                     (optional)
    -j  --jobId                         (optional)
    -u  --useScore                      => use score from the input file to compute coverage instead of actual occurance (optional)
    -v  --version                       => Version of the program
    -h  --help                          => Display help

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
    optsArray=[
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--fileType','-f',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputFile','-o',GetoptLong::REQUIRED_ARGUMENT],
      ['--trackName','-t',GetoptLong::REQUIRED_ARGUMENT],
      ['--userEmail','-e',GetoptLong::OPTIONAL_ARGUMENT],
      ['--jobId','-j',GetoptLong::OPTIONAL_ARGUMENT],
      ['--useScore','-u',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performSignalCoverage(optsHash)
    sigCovObj = SignalCoverage.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performSignalCoverage(optsHash)
