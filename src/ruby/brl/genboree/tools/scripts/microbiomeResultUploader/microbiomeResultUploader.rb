#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'

# Main Wrapper class
class MicrobiomeResultUploader
  OUTBUFFER = 16_000
  # Constructor
  # [+optsHash+] command line args
  # [+returns+] nil
  def initialize(optsHash)
    @roiFile = optsHash['--roiFile']
    @arrayFile = optsHash['--arrayFile']
    @wigFile = optsHash['--wigFile']
    @scratch = optsHash['--scratch']
    @skippedProbesFile = optsHash['--skippedProbesFile']
    @missingProbesFile = optsHash['--missingProbesFile']
    @skippedProbesWriter = File.open(@skippedProbesFile, 'w')
    @missingProbesWriter = File.open(@missingProbesFile, 'w')
    @trackName = optsHash['--trackName']
    @sample = @trackName.split(":")[0]
    @scratch = "." unless(@scratch)
    begin
      initScoreHash()
      validateFile()
      processFiles()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Initializes score hash
  # [+returns+] nil
  def initScoreHash()
    $stdout.puts "Initializing score hash..."
    @scoreHash = {}
    rr = File.open(@roiFile)
    rr.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^#/)
      fields = line.split(/\s/)
      @scoreHash[fields[3]] = nil
    }
    rr.close()
  end

  # Goes through data file, sets up the score hash (for each block of pragmas) with the correct values and then calls
  # method for writing out wig file
  # [+returns+] mil
  def processFiles()
    @scoreHash.each_key { |key|
      @scoreHash[key] = nil
    }
    $stdout.puts "Generating wig files..."
    arrReader = File.open(@arrayFile)
    wigPresent = false
    skippedList = []
    arrReader.each_line {|line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#(?!#)/)
      data = line.split(/\s+/)
      if(data[1] !~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i) # score value is not numeric
        skippedList.push(data[0])
      else
        @scoreHash[data[0]] = data[1]
      end
    }
    generateWig()
    if(!skippedList.empty?)
      buff = ""
      skippedList.each { | probe|
        buff << "#{probe.inspect}\n"
      }
      @skippedProbesWriter.print(buff)
      @skippedProbesWriter.close()
    end
  end

  # Generates wig file(span=1)
  # [+returns+] nil
  def generateWig()
    $stdout.puts "Generating wig file for track: #{@trackName.inspect}..."
    buffer = ''
    ww = File.open(@wigFile, "w")
    ww.print("track name='#{@trackName}' type=wiggle_0\n")
    rr = File.open(@roiFile)
    rr.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#/)
      fields = line.split(/\s+/)
      chr = fields[0]
      startCoord = fields[1].to_i
      endCoord = fields[2].to_i
      name = fields[3]
      value = @scoreHash[name]
      if(!value.nil? and value =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i)
        buffer << "fixedStep chrom=#{chr} start=#{startCoord + 1} span=1 step=1\n" # Since the first base for bed/bedGraph starts from 0
        span = endCoord - startCoord
        span.times {
          buffer << "#{value}\n"
        }
      end
      if(buffer.size >= OUTBUFFER)
        ww.print(buffer)
        buffer = ''
      end
    }
    ww.print(buffer) if(!buffer.empty?)
    buffer = ''
    rr.close()
    ww.close()
  end

  # validates data file
  # [+returns+] nil
  def validateFile()
    $stdout.puts "Validating array/probe file"
    rr = File.open(@arrayFile)
    missingList = []
    rr.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#(?!#)/)
      fields = line.split(/\s+/) # Can be tab or space delimited, playing safe
      if(@scoreHash.has_key?(fields[0]))
        if(!@scoreHash[fields[0]].nil?)
          raise "Probe Name: #{fields[0].inspect} present twice in probe file (Line Number:#{rr.lineno}) for sample: #{sample}. All probes must be present only once for a particular sample."
        else
          @scoreHash[fields[0]] = fields[1]
        end
      else
        missingList << fields[0]
      end
    }
    if(!missingList.empty?)
      buff = ""
      missingList.each { | probe|
        buff << "#{probe.inspect}\n"
      }
      @missingProbesWriter.print(buff)
      @missingProbesWriter.close()
    end
    rr.close()
  end


  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stdout.puts "ERROR:\n #{msg}"
    $stdout.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}" # Print it to stdout since stderr stream will be going to the user in email
    exit(14)
  end

end









# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is intended to be called by microbiomeResultUploaderWrapper.rb.
    -r  --roiFile                     => path to file with roi track (bed format, sorted by chr, start and end) (required)
    -a  --arrayFile                   => path to file with array data (required)
    -w  --wigFile                     => output wig file (required)
    -S  --skippedProbesFiles          => path to file to which the skipped probes (probes with non numeric score values) will be written out. (This will be later used by the wrapper to include the names of the skipped probes in the email. ) (required)
    -M  --missingProbesFiles          => path to file to which the missing probes (not present in the reference track) will be written out. (This will be later used by the wrapper to include the names of the missing probes in the email. ) (required)
    -s  --scratch                     => scratchDir (optional) (defaults to pwd)
    -T  --trackname                   => default track name to use
    -v  --version                     => version
    -h  --help                        => Display help

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
      ['--roiFile','-r',GetoptLong::REQUIRED_ARGUMENT],
      ['--arrayFile','-a',GetoptLong::REQUIRED_ARGUMENT],
      ['--wigFile','-w',GetoptLong::REQUIRED_ARGUMENT],
      ['--skippedProbesFile','-S',GetoptLong::REQUIRED_ARGUMENT],
      ['--missingProbesFile','-M',GetoptLong::REQUIRED_ARGUMENT],
      ['--scratch','-s',GetoptLong::OPTIONAL_ARGUMENT],
      ['--trackName','-T',GetoptLong::REQUIRED_ARGUMENT],
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

  def self.runMicrobiomeResultUploader(optsHash)
    microbiomeResultUploaderObj = MicrobiomeResultUploader.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.runMicrobiomeResultUploader(optsHash)
