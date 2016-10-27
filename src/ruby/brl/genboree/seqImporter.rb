#!/usr/bin/env ruby
$VERBOSE = nil
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/db/dbrc'
require 'dbi'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/sql/binning'
include BRL::Genboree

module BRL ; module Genboree

class SeqImportError < StandardError ; end

class SeqImporter

  # ##############################################################################
  # CONSTANTS
  # ##############################################################################
  MAX_SEQ_FILE_SIZE = 1_500_000_000
  SEQ_FILE_BASE = 'seq.data.'

  # ##############################################################################
  # ATTRIBUTES
  # ##############################################################################
  @@attributes = [  :verbose, :maxSeqFileSize, :fmetaInfo, :seqDir,:currSeqFileName,
                    :currSeqFile, :currFrefRec, :currRidSequenceRec, :currRid2RidSeqIdRec,
                    :currFileSize, :currOffset, :currRecSize, :currSeqFileNum, :fastaFileName,
                    :fastaFile, :dataDbName, :dbu, :dbrcFileName ]

  # ----------------------------------------------------------------------------
  # INITIALIZATION
  # ----------------------------------------------------------------------------
  def initialize(optsHash)
    initAttributes(@@attributes)
    @optsHash = optsHash
    setParams(optsHash)
    init()
    @binner = BRL::SQL::Binning.new()
  end

  def setParams(optsHash)
    @dataDbName = optsHash['--dataDbName']
    @fastaFileName = optsHash['--fastaFile']
    @maxSeqFileSize = optsHash.key?('--maxSeqFileSize') ? optsHash['--maxSeqFileSize'].to_i : MAX_SEQ_FILE_SIZE
    @verbose = optsHash.key?('--verbose') ? true : false
    @dbrcFileName = nil
  end

  # ----------------------------------------------------------------------------
  # PUBLIC  METHODS
  # ----------------------------------------------------------------------------
  def import()
    # Init counters
    @currFileSize = @currRecSize = @currSeqFileNum = @currOffset = 0
    # Init [first] linearized sequence file
    initSeqFile()
    # Open fasta file or error
    begin
      @fastaFile = BRL::Util::TextReader.new(@fastaFileName)
    rescue => err
      raise SeqImportError.new("ERROR: couldn't open fasta file because of this error:\n    '#{err}' with backtrace:\n\n    " + err.backtrace.join("\n"))
    end
    # Read fasta file by record
    processFastaFile()
    # Clean up
    begin
      @fastaFile.close()
      @currSeqFileName = nil
      @dbu.clear()
    rescue
    end

    return
  end

  # ----------------------------------------------------------------------------
  # PROTECTED METHODS
  # ----------------------------------------------------------------------------
  protected

  def init()
    setUpDb()       # Set up db
    getFmetaInfo()  # Get fmeta
    getSeqDir()     # Get seqDir
  end

  def setUpDb()
    # Load Genboree Config File (has the dbrcKey in it to use for this machine
    @genbConfig = ENV.key?('GENB_CONFIG') ? GenboreeConfig.new(ENV['GENB_CONFIG']) : GenboreeConfig.new()
    @genbConfig.loadConfigFile()
    @dbrcFileName = @genbConfig.dbrcFile
    @dbu = BRL::Genboree::DBUtil.new(@genbConfig.dbrcKey, nil, @dbrcFileName)
    @dbu.setNewDataDb(@dataDbName)
    connectResult = @dbu.connectToDataDb()
    unless(connectResult)
      @err = SeqImportError.new("ERROR: couldn't connect to data DB for '#{@genbConfig.dbrcKey}' from info in '#{@dbrcFileName}'. Details:\n#{@dbu.err.message}\n\n" + @dbu.err.backtrace.join("\n") + "\n\n")
      raise @err
    end
    return
  end

  def getFmetaInfo()
    @fmetaInfo = {}
    @dbu.setNewDataDb(@dataDbName) if(@dbu.dataDbName.nil?) # set data db if not already
    fmetaRows = @dbu.selectAllFmeta()
    fmetaRows.each { |row|
      @fmetaInfo[row['fname']] = row['fvalue']
    }
    unless(!@fmetaInfo.nil? and @fmetaInfo.key?('MIN_BIN') and !@fmetaInfo['MIN_BIN'].empty?)
      @minBin = @fmetaInfo['MIN_BIN'] = 1000
    else
      @minBin = @fmetaInfo['MIN_BIN'].to_i
    end
    return @fmetaInfo
  end

  # Get the sequence storage dir using the fmeta table.
  def getSeqDir()
    getFmetaInfo() if(@fmetaInfo.nil? or @fmetaInfo.empty?)
    unless(!@fmetaInfo.nil? and @fmetaInfo.key?('RID_SEQUENCE_DIR') and !@fmetaInfo['RID_SEQUENCE_DIR'].empty?)
      # Make up the dir, create it, add it to the database
      @seqDir = "/usr/local/brl/data/genboree/ridSequences/#{@dataDbName}"
      begin
        Dir::mkdir(@seqDir)
      rescue
      end
      @dbu.insertFmetaEntry('RID_SEQUENCE_DIR', @seqDir)
    else
      @seqDir = @fmetaInfo['RID_SEQUENCE_DIR']
    end
    # Try to make the dir if it doesn't exist yet
    unless(File::exist?(@seqDir) and File::directory?(@seqDir))
      begin
        Dir::mkdir(@seqDir)
      rescue
      end
    end
    return @seqDir
  end

  def initSeqFile()
    @currSeqFile.close() unless(@currSeqFile.nil?)
    @currSeqFileNum = Time.now.to_i + 1
    @currSeqFileName = SEQ_FILE_BASE + @currSeqFileNum.to_s
    @currSeqFile = File.open(@seqDir + '/' + @currSeqFileName, 'w+')
    @currFileSize = 0
    @currOffset = 0
  end

  def processFastaFile()
    # Set up records used to insert/update the database
    # The 'new' fref record
    frefRec = [nil, nil, nil, nil, 1, '+', 1, 'Chromosome']
    # The ridSequence record
    ridSequenceRec = Array.new(3)
    # The rid2ridSeqId record
    rid2ridSeqIdRec = Array.new(4)

    @fastaFile.readline('>') # suck in 'blank' record at beginning
    @fastaFile.each('>') { |faRecTxt|
      # Are we over the rough max sequence file limit?
      if(@currFileSize >= @maxSeqFileSize)
        initSeqFile() # Current file full, open another seq file
      end
      @currRecSize = 0
      # Get the recName from the defline
      recName = frefRec[1] = extractRecName(faRecTxt)
      # Get rid for existing fref record for recName, if any
      rid = @dbu.selectRidByName(recName)
      # Go through each line of fastaRec
      currLineNum = 0
      begin
        faRecTxt.each("\n") { |line|
          if(currLineNum == 0) # skip the first line, it's the defline we got above
            currLineNum += 1
            next
          end
          # Skip comment lines (those with ; as the first non-whitespace)
          next if(line =~ /^\s*;/)
          line = line.chomp.strip
          line = line.chomp('>')
          @currRecSize += line.size
          # Write bytes
          @currSeqFile.print(line)
          @currFileSize += line.size
          currLineNum += 1
        }
        # Clear faRecTxt to help/force GC
        faRecTxt = '' ; faRecTxt = nil
        # Put this fasta record into fref table
        frefRec[0] = rid
        frefRec[2] = @currRecSize
        frefRec[3] = @binner.bin(@minBin, 1, @currRecSize)
        if(rid.nil?) # no pre-existing fref, insert new one
          rid = @dbu.insertFrefRec(frefRec)
        else # have an fref for this rid already, update it
          @dbu.updateFrefRec(frefRec)
          # Remove old entries in ridSequence and rid2ridSeqId
          oldRefSeqIds = @dbu.selectRidSeqIdByRid(rid)
          $stderr.puts "ARJ_DEBUG: number of old RefSeqIds: #{oldRefSeqIds.size}\n    #{oldRefSeqIds.inspect}"
          oldRefSeqIds.each { |rec|
            result = @dbu.deleteRidSequence(rec['ridSeqId'])
            $stderr.puts "ARJ_DEBUG: result of deleting '#{rec['ridSeqId']}' is '#{result}'"
          }
          @dbu.deleteRid2RidSeqId(rid)
        end
        # Put file locations into ridSequence table
        ridSequenceRec[1] = @currSeqFileName
        ridSeqId = @dbu.insertRidSequenceRec(ridSequenceRec)
        # Put file/seq info into rid2ridSeqId table
        rid2ridSeqIdRec[0] = rid
        rid2ridSeqIdRec[1] = ridSeqId
        rid2ridSeqIdRec[2] = @currOffset
        rid2ridSeqIdRec[3] = @currRecSize
        @dbu.insertRid2RidSeqIdRec(rid2ridSeqIdRec)
        # Update current offset in sequence file
        @currOffset = @currFileSize
      rescue => @err
        $stderr.puts "ERROR: problem putting sequence info into db. Error: '#{@err}'. Backtrace:\n\n" + @err.backtrace.join("\n")
        raise SeqImportError.new("ERROR: problem inserting sequence info into db. rror: '#{@err}'. Backtrace:\n\n" + @err.backtrace.join("\n"))
      end
    }
    return
  end

  def extractRecName(faRecTxt)
    defline = ''
    faRecTxt.each("\n") { |line| defline = line.strip ; break ; } # read only first line
    # Get the recName
    defline =~ /^(\S+)/
    recName = $1
    return recName
  end

  # ----------------------------------------------------------------------------
  # CLASS METHODS
  # ----------------------------------------------------------------------------
  def SeqImporter.processArguments
    optsArray = [
                  ['--dataDbName', '-d', GetoptLong::REQUIRED_ARGUMENT],
                  ['--fastaFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--maxSeqFileSize', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                  ['--help', '-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    SeqImporter.usage() if(optsHash.key?('--help') or !progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def SeqImporter.usage(msg='')
    puts "\n#{msg}\n" unless(msg.empty?)
    puts "

  PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    --dataDbName     | -d  =>  Name of Genboree annotation database to import into.
    --fastaFile      | -f  =>  Fasta file. One or more fasta recs.
    --maxSeqFileSize | -s  =>  [optional] Maximum size of linearized sequence
                               file before starting a new one in btyes.
                               Default: 1_500_000_000 ; Value of -1 = no limit.
    --verbose        | -n  =>  [optional flag] Turn on debugging and timing output.
    --help           | -h  =>  [optional flag] Print usage info and exit.

  USAGE:

  " ;
    exit(134);
  end # def SeqImporter.usage(msg='')
end

end ; end

# ##############################################################################
#  MAIN
# ##############################################################################
# When run on the command line, this library will do the insertion of Fasta
# sequence into Genbore.
# Get command line args
optsHash = BRL::Genboree::SeqImporter.processArguments()
# Init deployment object, read properties file, set params
importer = BRL::Genboree::SeqImporter.new(optsHash)
begin
  # Sequence upload
  importer.import()
rescue => err
  $stderr.puts "ERROR: a problem uploading the sequence data occurred. Details:\n    #{err}\n\n   " + err.backtrace.join("\n")
  exit(135)
end
exit(0)
