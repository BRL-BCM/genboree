#!/usr/bin/env ruby

# Load library files
require 'getoptlong'
require 'brl/util/textFileUtil'
require 'stringio'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'

# Main class for removing redundant reads
class RemoveRedundantReads

  # Constructor
  # [+optsHash+] opts hash with command line args
  # [+returns+] nil
  def initialize(optsHash)
    @userEmail = nil
    @jobId = nil
    @userEmail = optsHash['--userEmail'] unless(optsHash['--userEmail'].nil?)
    @jobId = optsHash['--jobId'] unless(optsHash['--jobId'].nil?)
    @inputFile = optsHash['--inputFile']
    @fileFormat = optsHash['--fileFormat']
    @onlyStart = optsHash['--onlyStartForSorting'] ? true : false
    @noStrand = optsHash['--noStrandForSorting'] ? true : false
    @scratchDir = optsHash['--scratchDir'] ? optsHash['--scratchDir'] : '.'
    @outputFile = optsHash['--outputFile']
    @tempOutputFile = "#{@outputFile}.#{Time.now.to_f}.tmp"
    @onlySort = optsHash['--onlySort']
    begin
      raise "file: #{@inputFile} not found" if(!File.exists?(@inputFile))
      case @fileFormat
      when 'lff'
        removeRedundantReadsFromLFF()
      when 'bed'
        removeRedundantReadsFromBed()
      when 'bedGraph'
        removeRedundantReadsFromBedGraph()
      when 'gtf'
        removeRedundantReadsFromGTF()
      when 'gff3'
        removeRedundantReadsFromGFF3()
      when 'gff'
        removeRedundantReadsFromGFF()
      else
        raise "Unsupported file format: #{@fileFormat}"
      end
      if(@onlySort)
        system("mv #{@tempOutputFile} #{@outputFile}")
        $stderr.puts "removeRedundantReads.rb - all done"
      else
        reader = File.open(@tempOutputFile)
        writer = File.open(@outputFile, "w")
        orphan = nil
        prevChr = ""
        prevStart = 0
        prevEnd = 0
        outBuffer = ""
        chr = nil
        while(!reader.eof?)
          fileBuff = reader.read(32_000_000)
          buffIO = StringIO.new(fileBuff)
          buffIO.each_line { |line|
            line = orphan + line if(!orphan.nil?)
            orphan = nil
            if(line =~ /\n$/)
              line.strip!
              next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/ or line =~ /^track/)
              currRec = line.split(/\t/)
              case @fileFormat
              when 'bed'
                chr = currRec[0]
                chromStart = currRec[1].to_i
                chromEnd = currRec[2].to_i
              when 'lff'
                chr = currRec[4]
                chromStart = currRec[5].to_i
                chromEnd = currRec[6].to_i
              when 'bedGraph'
                chr = currRec[0]
                chromStart = currRec[1].to_i
                chromEnd = currRec[2].to_i
              when 'gff'
                chr = currRec[0]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              when 'gff3'
                chr = currRec[0]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              when 'gtf'
                chr = currRec[0]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              end
              if(chr == prevChr and chromStart == prevStart and chromEnd == prevEnd)
                #$stderr.puts "skipping non unique line: #{line}."
              else
                outBuffer << "#{line}\n"
              end
              prevChr = chr
              prevStart = chromStart
              prevEnd = chromEnd
              if(outBuffer.size >= 32_000)
                writer.print(outBuffer)
                outBuffer = ""
              end
            else
              orphan = line
            end
          }
        end
        writer.print(outBuffer) if(!outBuffer.empty?)
        outBuffer = ''
        writer.close()
        reader.close()
        $stderr.puts "removeRedundantReads.rb - all done"
      end
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end

  end

  # removes redundant reads from a bed file
  # [+returns+] nil
  def removeRedundantReadsFromBed()
    # take strand into account while sorting
    if(!@noStrand)
      if(@onlyStart) #  do not use stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k6,6 -k1,1 -k2,2n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else # also stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k6,6 -k1,1 -k2,2n -k3,3n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        $stderr.puts "command to run: #{sortCmd}"
        system(sortCmd)
      end
    # don't use strand for sorting
    else
      if(@onlyStart)
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k2,2n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k2,2n -k3,3n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        $stderr.puts "command to run: #{sortCmd}"
        system(sortCmd)
      end
    end

  end

  # removes redundant reads from a lff file
  # [+returns+] nil
  def removeRedundantReadsFromLFF()
    # take strand into account while sorting
    if(!@noStrand)
      if(@onlyStart) #  do not use stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k8,8 -k5,5 -k6,6n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else # also stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k8,8 -k5,5 -k6,6n -k7,7n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    # don't use strand for sorting
    else
      if(@onlyStart)
        sortCmd = " cat #{@inputFile} | sort -k5,5 -k6,6n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else
        sortCmd = " cat #{@inputFile} | sort -k5,5 -k6,6n -k7,7n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    end
  end

  # remove redundant reads from bedGraph file
  # [+returns+] nil
  def removeRedundantReadsFromBedGraph()
    if(@onlyStart)
      sortCmd = " cat #{@inputFile} | sort -k1,1 -k2,2n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
      system(sortCmd)
    else
      sortCmd = " cat #{@inputFile} | sort -k1,1 -k2,2n -k3,3n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
      system(sortCmd)
    end
  end

  # remove redundant reads from gff file
  # [+returns+] nil
  def removeRedundantReadsFromGFF()
    # take strand into account while sorting
    if(!@noStrand)
      if(@onlyStart) #  do not use stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else # also stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    # don't use strand for sorting
    else
      if(@onlyStart)
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    end
  end

  # remove redundant reads from gtf file
  # [+returns+] nil
  def removeRedundantReadsFromGTF()
    # take strand into account while sorting
    if(!@noStrand)
      if(@onlyStart) #  do not use stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else # also stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    # don't use strand for sorting
    else
      if(@onlyStart)
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    end
  end

  # remove redundant reads from gff3 file
  # [+returns+] nil
  def removeRedundantReadsFromGFF3()
    # take strand into account while sorting
    if(!@noStrand)
      if(@onlyStart) #  do not use stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else # also stop/end coord for sorting
        sortCmd = " cat #{@inputFile} | sort -k7,7 -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    # don't use strand for sorting
    else
      if(@onlyStart)
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      else
        sortCmd = " cat #{@inputFile} | sort -k1,1 -k4,4n -k5,5n -T #{@scratchDir} -S 1G -o #{@tempOutputFile}"
        system(sortCmd)
      end
    end
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR from removeRedundancyReads.rb:\n#{msg}"
    $stderr.puts "ERROR Backtrace from removeRedundancyReads.rb:\n#{msg.backtrace}"
    exit(14)
  end

end

# Class for running script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is used for removing redundant reads from any of the annotation formats (non wig) supported by Genboree. The formats currently
  include: LFF, BED, BEDGRAPH, GFF3, GFF, GTF. The tool can also be used JUST for sorting

  Notes: Make sure --fileFormat matches the format of the file correctly !!!
         Always provide non compressed file as input

    -i  --inputFile => path to annotation (reads) file (required)
    -f  --fileFormat => any of these formats: lff, bed, bedGraph, gff, gff3, gtf (required)
    -o  --outputFile => path to the output file (required)
    -s  --onlyStartForSorting => use only start coord for sorting reads (defualt: uses both start and stop coords for sorting) (optional)
    -n  --noStrandForSorting => do not use strand info (+ or -) for sorting. (defualt: use strand) (optional)
        Note that bedGraph does not have a strand column so only --onlyStartForSorting option will be used
    -S  --scrachDir (optional) (default: pwd)
    -e  --userEmail (optional)
    -j  --jobId => job id of the job this tool is involved in (optional)
    -T  --onlySort => only sort the files. Do not remove the redundant reads (optional)
    -v  --version => Version of the program
    -h  --help => Display help
    USAGE: removeRedundantReads.rb -i file.lff -f lff -o res.lff
    USAGE (for only sorting): removeRedundantReads.rb -i file.lff -f lff -o res.lff --onlySort
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
      ['--fileFormat','-f',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputFile','-o',GetoptLong::REQUIRED_ARGUMENT],
      ['--onlyStartForSorting','-s',GetoptLong::OPTIONAL_ARGUMENT],
      ['--noStrandForSorting','-n',GetoptLong::OPTIONAL_ARGUMENT],
      ['--scratchDir','-S',GetoptLong::OPTIONAL_ARGUMENT],
      ['--userEmail','-e',GetoptLong::OPTIONAL_ARGUMENT],
      ['--jobId','-j',GetoptLong::OPTIONAL_ARGUMENT],
      ['--onlySort','-T',GetoptLong::OPTIONAL_ARGUMENT],
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

  def self.performRemoveRedundantReads(optsHash)
    RemoveRedundantReads.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performRemoveRedundantReads(optsHash)
