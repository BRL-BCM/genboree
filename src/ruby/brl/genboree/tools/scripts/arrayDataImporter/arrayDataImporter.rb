#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'

# Main Wrapper class
class ArrayDataImporter
  OUTBUFFER = 16_000
  # Constructor
  # [+optsHash+] command line args
  # [+returns+] nil
  def initialize(optsHash)
    @roiFile = optsHash['--roiFile']
    @arrayFile = optsHash['--arrayFile']
    @wigDir = optsHash['--wigFileDir']
    @scratch = optsHash['--scratch']
    @skippedProbesFile = optsHash['--skippedProbesFile']
    @missingProbesFile = optsHash['--missingProbesFile']
    @gzip = optsHash['--gzipFiles']
    @skippedProbesWriter = File.open(@skippedProbesFile, 'w')
    @missingProbesWriter = File.open(@missingProbesFile, 'w')
    @trackName = nil
    @trackName = optsHash['--trackName'] if(optsHash['--trackName'])
    @scratch = "." unless(@scratch)
    begin
      initScoreHash()
      validateArrayFile()
      processArrayFiles()
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

  # Goes through array file, sets up the score hash (for each block of pragmas) with the correct values and then calls
  # method for writing out wig file
  # [+returns+] mil
  def processArrayFiles()
    @scoreHash.each_key { |key|
      @scoreHash[key] = nil
    }
    $stdout.puts "Generating wig files..."
    arrReader = File.open(@arrayFile)
    track = nil
    track = @trackName.dup() if(!@trackName.nil?)
    wigPresent = false
    skippedList = []
    arrReader.each_line {|line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#(?!#)/)
      if(line =~ /^##\s*trackName\s*=\s*/) # has pragma (track name)
        generateWig(track) if(wigPresent)
        pragma = line.split("=")
        track = (!pragma[1].nil? and !pragma[1].empty?) ? pragma[1].strip : @trackName
        @scoreHash.each_key { |key|
          @scoreHash[key] = nil
        }
      else # data line
        wigPresent = true
        data = line.split(/\s+/)
        if(data[1].nil? or data[1].empty? or !data[1].valid?(:float)) # score value is not numeric
          skippedList.push(data[0])
        else
          @scoreHash[data[0]] = data[1]
        end
      end
    }
    if(wigPresent)
      generateWig(track)
    end
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
  # track (name of wig track)
  # [+returns+] nil
  def generateWig(track)
    $stdout.puts "Generating wig file for track: #{track.inspect}..."
    buffer = ''
    wigFile = "#{@wigDir}/#{Time.now.to_f}.wig"
    ww = File.open(wigFile, "w")
    ww.print("track name='#{track}' type=wiggle_0\n")
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
      if(!value.nil? and value.valid?(:float))
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
    `gzip #{wigFile}` if(@gzip)
  end

  # validates array data file
  # [+returns+] raises error if a probe name is found which is not part of @scoreHash
  def validateArrayFile()
    $stdout.puts "Validating array/probe file"
    rr = File.open(@arrayFile)
    track = nil
    missingList = []
    rr.each_line { |line|
      line.strip!
      next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#(?!#)/)
      if(line =~ /^##\s*trackName\s*=\s*/)
        @scoreHash.each_key { |key|
          @scoreHash[key] = nil
        }
        pragma = line.split('=')
        track = pragma[1].strip if(!pragma[1].nil?)
        raise "No Track name provided. A track name must be provided either via the pragma or via the UI when launching the job." if((track.nil? or track.empty?) and @trackName.nil?)
      else
        raise "No Track name provided. A track name must be provided either via the pragma or via the UI when launching the job." if((track.nil? or track.empty?) and @trackName.nil?)
        fields = line.split(/\s+/) # Can be tab or space delimited, playing safe
        if(@scoreHash.has_key?(fields[0]))
          if(!@scoreHash[fields[0]].nil?)
            raise "Probe Name: #{fields[0].inspect} present twice in probe file (Line Number:#{rr.lineno}) for trackName: #{track.inspect}. All probes must be present only once for a particular track."
          else
            @scoreHash[fields[0]] = fields[1]
          end
        else
          missingList << fields[0]
        end
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

  Description: This tool is intended to be called by arrayDataImporterWrapper.rb. The tool imports array based data given a ROI Track and a probe/array data file
  by generating a wig file and uploading it in Genboree.
    -r  --roiFile                     => path to file with roi track (bed format, sorted by chr, start and end) (required)
    -a  --arrayFile                   => path to file with array data (required)
    -w  --wigFileDir                     => dir to write output wig files (required)
    -S  --skippedProbesFiles          => path to file to which the skipped probes (probes with non numeric score values) will be written out. (This will be later used by the wrapper to include the names of the skipped probes in the email. ) (required)
    -M  --missingProbesFiles          => path to file to which the missing probes (not present in the reference track) will be written out. (This will be later used by the wrapper to include the names of the missing probes in the email. ) (required)
    -s  --scratch                     => scratchDir (optional) (defaults to pwd)
    -T  --trackname                   => default track name to use (optional)
    -z  --gzipFiles                   => gzip the wig files (optional)
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
      ['--wigFileDir','-w',GetoptLong::REQUIRED_ARGUMENT],
      ['--skippedProbesFile','-S',GetoptLong::REQUIRED_ARGUMENT],
      ['--missingProbesFile','-M',GetoptLong::REQUIRED_ARGUMENT],
      ['--scratch','-s',GetoptLong::OPTIONAL_ARGUMENT],
      ['--trackName','-T',GetoptLong::OPTIONAL_ARGUMENT],
      ['--gzipFiles','-z',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performArrayDataImporter(optsHash)
    arrayDataImporterObj = ArrayDataImporter.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performArrayDataImporter(optsHash)
