#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/db/dbrc'
require 'dbi'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
include BRL::Genboree

module BRL ; module Genboree

class SeqRetriever
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # MAIN_GENB = 'genboree'
  CHR_SORT_RE = /^.*chr(.+)$/i
	BASES_PER_LINE = 70
	PRETTY_FASTA_RE = /\S{1,#{BASES_PER_LINE}}/
  OK, BAD_REFSEQID, UNK_REFNAME, NO_SEQ_FILE, SEQ_FILE_UNEXIST, FROM_BEYOND_END,
    FROM_NEGATIVE, TO_BEYOND_END, TO_NEGATIVE, NO_SEQ_DIR, BAD_UPLOADID, UNK_RID,
    NO_ANNOS_FOUND, TOO_MANY_ANNOS_FOUND, SEQ_OUTPUTTED =
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
  DEFAULT_LINE_THROTTLE = 25_000
  DEFAULT_THROTTLE_LEN = 1

  # ############################################################################
  # ATTRIBUTES
  # ############################################################################
  attr_accessor :rangeWarn, :err, :from, :to, :doRevCompl, :doAllUpper, :doAllLower, :useMasked
  attr_accessor :genbConfig, :cachedFileHandles, :frefsByRid, :frefsByName
  attr_accessor :refSeqID, :refName, :rid, :currDataDB, :currRidSeqId, :currRidSeqIdInfo
  attr_accessor :dbu, :currFrefRec
  attr_accessor :groupName, :dbName

  def initialize(dbrcFileName=nil, doThrottle=false)
    @refSeqID = nil
    @refName = refName
    @dbrcFileName = dbrcFileName
    @doThrottle = doThrottle
    @totalLineCount = 0
    @dataDBList = []
    @fmetaInfo = {}
    @frefsByRid = {}
    @frefsByName = {}
    @cachedFileHandles = {}
    @seqDir = @rid = @currDataDB = @currRidSeqId = nil
    @doRevCompl = @doAllUpper = @doAllLower = @useMasked = false
    @groupName = @dbName = nil
    @from = @to = nil
    @err = nil
    @rangeWarn = nil
    # Load Genboree Config File (has the dbrcKey in it to use for this machine
    @genbConfig = GenboreeConfig.new()
    @genbConfig.loadConfigFile()
    @dbu = BRL::Genboree::DBUtil.new(@genbConfig.dbrcKey, nil, @dbrcFileName)
  end

  def clear()
    @fmetaInfo.clear
    @dataDBList.clear
    @frefsByRid = {}
    @frefsByName = {}
    @totalLineCount = 0
    @seqDir = @rid = @currDataDB = @currRidSeqId = @err = @rangeWarn = nil
    @doRevCompl = @doAllUpper = @doAllLower = @useMasked = false
    @groupName = @dbName = nil
    @dbu.clear() unless(@dbu.nil?)
    closeCachedFileHandles()
    return
  end

  def prematureDBDisconnect()
    # Disconnect from main genboree db and the data db prematurely, due to
    # long running operation. DB work should be all done when this is called,
    # and only cached info needed.
    begin
      @dbu.clear() unless(@dbu.nil?)
    rescue => @err
    end
    return
  end

  def openCachedFileHandle(fileFullPath)
    filePath = File.expand_path(fileFullPath.untaint)
    fileHandle = nil
    if(@cachedFileHandles.key?(filePath))
      fileHandle = @cachedFileHandles[filePath]
     elsif(!(File.exist?(filePath)))
      fileHandle = SEQ_FILE_UNEXIST
     else
      fileHandle = File.open(filePath)
      @cachedFileHandles[filePath] = fileHandle
     end
    return fileHandle
  end

  def closeCachedFileHandles()
    @cachedFileHandles.each_value { |fileHandle|
      begin
        fileHandle.close unless(fileHandle.nil?)
      rescue
      end
    }
    @cachedFileHandles.clear
    return
  end

  def prettyPrintSequence(sequence)
    outBuffer = '' # reduce calls to Kernel#puts, which actually is Apache::Request#write() right now
    sequence.scan(PRETTY_FASTA_RE) { |seqLine|
      outBuffer << seqLine
      outBuffer << "\n"
      @totalLineCount +=1
      if(@doThrottle and @totalLineCount > 0 and (@totalLineCount % DEFAULT_LINE_THROTTLE) == 0)
        print outBuffer
        outBuffer = ''
        sleep(DEFAULT_THROTTLE_LEN)
      end
    }
    print outBuffer # 'flush' any remainder
    return
  end

  def prettyPrintSeqFromFile(seekStart, readLength, seqFile)
    outBuffer = '' # reduce calls to Kernel#puts, which actually is Apache::Request#write() right now
    basesOutput = 0
    unless(@doRevCompl) # Forward is easy
      # Go to first byte where to start reading
      seqFile.seek(seekStart, IO::SEEK_SET)
      # Read the file a bit at a time, directly outputting text
      while(basesOutput < readLength and !seqFile.eof?)
        basesToRead = (basesOutput + BASES_PER_LINE > readLength) ? (readLength % BASES_PER_LINE) : BASES_PER_LINE
        sequence = seqFile.read(basesToRead)
        if(@doAllUpper ^ @doAllLower)
          sequence = sequence.upcase if(@doAllUpper)
          sequence = sequence.downcase if(@doAllLower)
        end
        outBuffer << sequence
        outBuffer << "\n"
        @totalLineCount += 1
        if(@doThrottle and @totalLineCount > 0 and (@totalLineCount % DEFAULT_LINE_THROTTLE) == 0)
          print outBuffer
          outBuffer = ''
          sleep(DEFAULT_THROTTLE_LEN)
        end
        basesOutput += BASES_PER_LINE
      end
    else # Reverse is harder
      actualFileSize = File.size(File.expand_path(seqFile.path.untaint).untaint)
      currPos = seekStart + readLength - 1
      currPos = actualFileSize - 1 if(currPos >= actualFileSize)
      while((basesOutput < readLength) and !(currPos < 0))
        basesToRead = (basesOutput + BASES_PER_LINE > readLength) ? (readLength % BASES_PER_LINE) : BASES_PER_LINE
        # Where to start reading?
        currPos = (currPos < basesToRead) ? -1 : currPos - basesToRead
        # Seek and read
        seqFile.seek(currPos + 1, IO::SEEK_SET)
        sequence = seqFile.read(basesToRead).reverse.tr('agtcAGTC', 'tcagTCAG')
        if(@doAllUpper ^ @doAllLower)
          sequence = sequence.upcase if(@doAllUpper)
          sequence = sequence.downcase if(@doAllLower)
        end
        outBuffer << sequence
        outBuffer << "\n"
        @totalLineCount += 1
        if(@doThrottle and @totalLineCount > 0 and (@totalLineCount % DEFAULT_LINE_THROTTLE) == 0)
          print outBuffer
          outBuffer = ''
          sleep(DEFAULT_THROTTLE_LEN)
        end
        basesOutput += BASES_PER_LINE
      end
    end
    print outBuffer # 'flush' any remainder
		return
	end
  
  # provide chunked streaming of a sequence
  # @param [Fixnum] seekStart the starting position of the desired subsequence from the sequence file
  # @param [Fixnum] readLength the number of bases to read
  # @param [File] seqFile the opened file handle object for the sequence file
  def generateSeqFromFile(seekStart, readLength, seqFile)
    raise(ArgumentError, "generateSeqFromFile expects a code block and none was given!") unless(block_given?)
    outBuffer = '' # reduce calls to Kernel#puts, which actually is Apache::Request#write() right now
    basesOutput = 0
    unless(@doRevCompl) # Forward is easy
      # Go to first byte where to start reading
      seqFile.seek(seekStart, IO::SEEK_SET)
      # Read the file a bit at a time, directly outputting text
      while(basesOutput < readLength and !seqFile.eof?)
        basesToRead = (basesOutput + BASES_PER_LINE > readLength) ? (readLength % BASES_PER_LINE) : BASES_PER_LINE
        sequence = seqFile.read(basesToRead)
        if(@doAllUpper ^ @doAllLower)
          sequence = sequence.upcase if(@doAllUpper)
          sequence = sequence.downcase if(@doAllLower)
        end
        outBuffer << sequence
        outBuffer << "\n"
        yield outBuffer
        outBuffer = ''
        basesOutput += BASES_PER_LINE
      end
    else # Reverse is harder
      actualFileSize = File.size(File.expand_path(seqFile.path.untaint).untaint)
      currPos = seekStart + readLength - 1
      currPos = actualFileSize - 1 if(currPos >= actualFileSize)
      while((basesOutput < readLength) and !(currPos < 0))
        basesToRead = (basesOutput + BASES_PER_LINE > readLength) ? (readLength % BASES_PER_LINE) : BASES_PER_LINE
        # Where to start reading?
        currPos = (currPos < basesToRead) ? -1 : currPos - basesToRead
        # Seek and read
        seqFile.seek(currPos + 1, IO::SEEK_SET)
        sequence = seqFile.read(basesToRead).reverse.tr('agtcAGTC', 'tcagTCAG')
        if(@doAllUpper ^ @doAllLower)
          sequence = sequence.upcase if(@doAllUpper)
          sequence = sequence.downcase if(@doAllLower)
        end
        outBuffer << sequence
        outBuffer << "\n"
        yield outBuffer
        outBuffer = ''
        basesOutput += BASES_PER_LINE
      end
    end
    yield outBuffer # 'flush' any remainder
    return
  end

  # initialize instance variables for accessing sequence data in a user database
  # @param [String] dbName the name of the user database to prepare
  # @param [String] groupName the name of the user group where the user database called dbName resides
  # @return [String] frefsByRid hash
  def setupUserDb(groupName, dbName)
    retVal = {}
    @groupName = groupName
    @dbName = dbName
    dbNameRecs = self.dbu.selectRefseqByNameAndGroupName(dbName, groupName)
    unless(dbNameRecs.nil? or dbNameRecs.empty?)
      dbName = dbNameRecs.first["databaseName"]
    else
      raise(ArgumentError, "No databases with dbName #{dbName} were found!")
    end
    if(dbNameRecs.length > 1)
      raise(ArgumentError, "SQL query selectRefseqByNameAndGroupName returned more than one record!")
    end
    self.dbu.setNewDataDb(dbName) # if set fails, handled in getFmetaInfo()
    self.currDataDB = dbName
    self.getFmetaInfo() # if get fails, handled in getSeqDir()
    seqDir = self.getSeqDir()
    if(seqDir == NO_SEQ_DIR)
      raise(ArgumentError, "No sequence directory (a RID_SEQUENCE_DIR key) found in fMeta for userDb: #{@fmetaInfo.inspect}!")
    end
    retVal = self.getFrefs()
    if(@frefsByRid.empty?)
      raise(ArgumentError, "Failed to get fRefs for userDb!")
    end
    return retVal
  end

  # Get and save a data DB using an uploadid if not already set
  def getDataDBNameByUploadId(uploadId, doAutoInit=true)
    retVal = OK
    # Only get and set the data-db if we haven't already
    if(@currDataDB.nil? or @currDataDB.empty? or @dbu.dataDbName.nil? or @dbu.dataDbName.empty?)
      begin
        dataDBNameRows = @dbu.selectDBNameByUploadID(uploadId)
        if(dataDBNameRows.nil? or dataDBNameRows.empty?)
          retVal = BAD_UPLOADID
        else
          @currDataDB = dataDBNameRows['databaseName']
          retVal = @currDataDB
        end
      rescue Exception => @err
        retVal =  BAD_UPLOADID
      end
      if(doAutoInit and (retVal.kind_of?(String))) # get fref and fmeta data automatically
        @dbu.setNewDataDb(@currDataDB)
        @dbu.connectToDataDb()
        self.getFmetaInfo()
        self.getSeqDir()
      end
    end
    return retVal
  end

  # Cache fref data for the current data DB
  # - Can take a long time if lots of chrs, used only if needed.
  def getFrefs(force=false)
    raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
    @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
    if(force or @frefsByRid.empty?)
      frefRows = @dbu.selectAllRefNames()
      @frefsByRid.clear
      frefRows.each { |row|
        @frefsByRid[row['rid'].to_i] = row
        @frefsByName[row['refname']] = row
      }
      frefRows.clear
    end
    return @frefsByRid
  end

  # Get and cache fmeta data for the current data DB
  def getFmetaInfo()
    raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
    @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
    fmetaRows = @dbu.selectAllFmeta()
    @fmetaInfo.clear
    fmetaRows.each { |row|
      @fmetaInfo[row['fname']] = row['fvalue']
    }
    return @fmetaInfo
  end

  # Get the sequence storage dir using the fmeta table.
  def getSeqDir()
    getFmetaInfo() if(@fmetaInfo.nil? or @fmetaInfo.empty?)
    unless(!@fmetaInfo.nil? and @fmetaInfo.key?('RID_SEQUENCE_DIR') and !@fmetaInfo['RID_SEQUENCE_DIR'].empty?)
      @seqDir = nil
      return NO_SEQ_DIR
    else
      return @seqDir = @fmetaInfo['RID_SEQUENCE_DIR']
    end
  end

  # Get the fref record for the rid under consideration
  def getFrefForRid(rid)
    # First, let's see if it's in the @frefNamesByRid
    if(@frefsByRid.key?(rid))
      @currFrefRec = @frefsByRid[rid]
    else
      raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
      # Set the database
      @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
      frefsForRid = @dbu.selectFrefsByRid(rid)
      return UNK_REFNAME if(frefsForRid.nil? or frefsForRid.empty?)
      # Get and save fref
      @currFrefRec = frefsForRid.first()
    end
    return @currFrefRec
  end

  # Get ridSeqId for an entrypoint name.
  def getRidSeqIdForRefName(refName)
    raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
    # Set the database
    @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
    # Get and save fref
    if(@frefsByName.key?(refName))
      @currFrefRec = @frefsByName[refName]
    else
      # Get the rid
      frefsForName = @dbu.selectFrefsByName(refName)
      return UNK_REFNAME if(frefsForName.nil? or frefsForName.empty?)
      @currFrefRec = frefsForName.first()
      @rid = frefsForName['rid']
    end
    # Get ridSeqId for rid
    return self.getRidSeqIdForRid(@rid)
  end

  # Get a ridSeqId for an entrypoint name.
  def getRidSeqIdForRid(rid=@rid)
    raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
    # Set the database
    @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
    @currRidSeqId = nil
    begin
      @currRidSeqInfo = @dbu.selectRidSeqIdByRid(rid) # This will actually be a result set at this point
      if(@currRidSeqInfo.nil? or @currRidSeqInfo.empty?)
        @currRidSeqId = nil
      else
        @currRidSeqInfo = @currRidSeqInfo.first() # Replace result set with the first [and only] row record
        @currRidSeqId = @currRidSeqInfo['ridSeqId']
      end
    rescue Exception => @err
    end
    return @currRidSeqId
  end

  # Get and cache seq file info using an ridSeqId
  def getFileInfoByRidSeqId(ridSeqId=@currRidSeqId)
    raise "ERROR: no current data database set." if(@currDataDB.nil? or @currDataDB.empty?)
    @dbu.setNewDataDb(@currDataDB) if(@dbu.dataDbName.nil?) # set data db if not already
    unless(ridSeqId.nil?)
      @currFileInfo = @dbu.selectFilesByRidSeqId(ridSeqId)
    else
      @currFileInfo = nil
    end
    if(@currFileInfo.nil?)
      return NO_SEQ_FILE
    else
      @currFileInfo = @currFileInfo.first()
      return @currFileInfo
    end
  end

  # Assign from and to in increasing order and with robust assumptions.
  def setFromAndTo(from, to)
    # Make sure we have an fref record
    if(@currFrefRec.nil? or @currFrefRec.empty? or @currFrefRec == UNK_REFNAME)
      @currFrefRec = getFrefForRid(@rid)
      return UNK_REFNAME if(@currFrefRec == UNK_REFNAME)
    end
    refLength = @currFrefRec['rlength']
    retVal = OK
    if(from > to)
      @from,@to = to,from
    else
      @from,@to = from,to
    end
    @from = 1 if(@from == 0)
    @to = 1 if(@to == 0)
    if(@from < 0)
      @rangeWarn = FROM_NEGATIVE
      @from = 1
    elsif(@from > refLength)
      retVal =  FROM_BEYOND_END
    end
    if(@to > refLength)
      @rangeWarn = TO_BEYOND_END
      @to = refLength
    elsif(@to < 0)
      retVal = TO_NEGATIVE
    end
    return retVal
  end
  
  # Assign from and to in increasing order and with robust assumptions.
  # @param [Integer, nil] from
  # @param [Integer, nil] to
  # @return [Integer] non-zero codes indicate failure
  def setFromAndToAllowNil(from, to)
    # Make sure we have an fref record
    if(@currFrefRec.nil? or @currFrefRec.empty? or @currFrefRec == UNK_REFNAME)
      @currFrefRec = getFrefForRid(@rid)
      return UNK_REFNAME if(@currFrefRec == UNK_REFNAME)
    end
    refLength = @currFrefRec['rlength']
    retVal = OK
    
    # allow flexible setting of from and to on the interface side
    if(from.nil? and to.nil?)
      # set from and to to provide the whole chromosome on the backend
      from = 1
      to = @currFrefRec['rlength']
    elsif(from.nil? and !to.nil?)
      # implied from start
      from = 1
    elsif(!from.nil? and to.nil?)
      # implied to end
      to = @currFrefRec['rlength']
    else
      # both are set, nothing to do
    end
    
    if(from > to)
      @from,@to = to,from
    else
      @from,@to = from,to
    end
    @from = 1 if(@from == 0)
    @to = 1 if(@to == 0)
    if(@from < 0)
      @rangeWarn = FROM_NEGATIVE
      @from = 1
    elsif(@from > refLength)
      retVal =  FROM_BEYOND_END
    end
    if(@to > refLength)
      @rangeWarn = TO_BEYOND_END
      @to = refLength
    elsif(@to < 0)
      retVal = TO_NEGATIVE
    end
    return retVal
  end
  
  # Output a sequence in a range, using a seq file--use for long/many results
  def outputSeqDataForRange(from, to, fileInfo=@currFileInfo, refSeqIdInfo=@currRidSeqInfo)
    # Make sure we have an fref record
    if(@currFrefRec.nil? or @currFrefRec.empty? or @currFrefRec == UNK_REFNAME)
      @currFrefRec = getFrefForRid(@rid)
      return UNK_REFNAME if(@currFrefRec == UNK_REFNAME)
    end
    refLength = @currFrefRec['rlength']
    setStatus = setFromAndTo(from, to)
    return setStatus if(setStatus == FROM_BEYOND_END or setStatus == TO_NEGATIVE)
    seekStart = @from - 1
    readLength = @to - @from + 1
    # Get offset info
    fileOffset = refSeqIdInfo['offset']
    # Open file if it exists
    getSeqDir() if(@seqDir.nil? or @seqDir.empty?)
    seqFileName = fileInfo['seqFileName']
    seqFileFullPath = @seqDir + '/' + seqFileName
    seqFileFullPath += '.masked' if(@useMasked)
    seqFile = self.openCachedFileHandle(seqFileFullPath)
    return seqFile if(seqFile == SEQ_FILE_UNEXIST)
    prettyPrintSeqFromFile(fileOffset + seekStart, readLength, seqFile)
    return OK
  end

  # Get a sequence in a range, using a seq file--use for short/few results
  def getSeqDataForRange(from, to, fileInfo=@currFileInfo, refSeqIdInfo=@currRidSeqInfo)
    # Make sure we have an fref record
    if(@currFrefRec.nil? or @currFrefRec.empty? or @currFrefRec == UNK_REFNAME)
      @currFrefRec = getFrefForRid(@rid)
      return UNK_REFNAME if(@currFrefRec == UNK_REFNAME)
    end
    refLength = @currFrefRec['rlength']
    setStatus = setFromAndTo(from, to)
    return setStatus if(setStatus == FROM_BEYOND_END or setStatus == TO_NEGATIVE)
    seekStart = @from - 1
    readLength = @to - @from + 1
    # Get offset info
    fileOffset = refSeqIdInfo['offset']
    # Open file if it exists
    getSeqDir() if(@seqDir.nil? or @seqDir.empty?)
    seqFileName = fileInfo['seqFileName']
    seqFileFullPath = @seqDir + '/' + seqFileName
    seqFileFullPath += '.masked' if(@useMasked)
    seqFile = self.openCachedFileHandle(seqFileFullPath)
    return seqFile if(seqFile == SEQ_FILE_UNEXIST)
    seqFile.seek(fileOffset + seekStart, IO::SEEK_SET)
    sequence = seqFile.read(readLength)
    sequence = sequence.reverse.tr('agtcAGTC', 'tcagTCAG') if(@doRevCompl)
    unless(@doAllUpper and @doAllLower)
      sequence = sequence.upcase if(@doAllUpper)
      sequence = sequence.downcase if(@doAllLower)
    end
    sequence = '' if(sequence.nil?)
    return sequence
  end

  # define deflines based on chromosome input and optional start, stop
  # also set seqRetriever instance variables so that a subsequent sequence retrieval will exactly correspond to the defline
  # @param [String, Integer] refName the name of or rid associated with the chromosome to create a defline for
  # @param [Integer] from the (optional) sequence start position on the chromosome
  # @param [Integer] to the (optional) sequenece end position on the chromosome
  # @return [String] a defline for the whole chromosome or for a subsequence of the chromosome named in chromName
  def makeDefline(refName, from=nil, to=nil)
    retVal = OK
    setRefNameAndRid(refName)
    setFromAndToAllowNil(from,to)
    if(from.nil? and to.nil?)
      # then write a simple defline indicating the following sequence is the whole chromosome
      retVal = ">#{@refName}\n"
    else
      # write a defline including validated from and to for the chromosome subsequence
      retVal = ">#{@refName}:#{@from}-#{@to}\n"
    end
    return retVal
  end

  def makeSeqDefline(deflineID, rid, from, to, addCurrWarnings=true)
    # Is the rid an rid or actually a refName?
    refName = rid
    if(rid.kind_of?(Fixnum) or rid =~ /^\d+$/) # The rid needs to be converted to refName
      raise "ERROR: unknown rid '#{rid}' in the current data db.\n(currFrefRec:#{CGI.escapeHTML(@currFrefRec.inspect)})" if(@currFrefRec.nil? or @currFrefRec.empty?)
      @rid = rid.to_i
      if(@frefsByName.key?(rid))
        @refName = refName = @frefsByName[rid]
      else
        @refName = refName = @currFrefRec['refname']
      end
    end
    # Make sure we have an fref record
    if(@currFrefRec.nil? or @currFrefRec.empty? or @currFrefRec == UNK_REFNAME)
      @rid = rid
      @currFrefRec = getFrefForRid(rid)
      return UNK_REFNAME if(@currFrefRec == UNK_REFNAME)
    end
    # Set from<to in robust manner
    setFromAndTo(from, to)
    retVal = ">#{deflineID}|#{@refName}|#{@from}|#{@to}| DNA_SRC: #{@refName} START: #{@from} STOP: #{@to} STRAND: #{@doRevCompl ? '-' : '+'} "
    retVal << "MASKED: true" if(@useMasked)
    if(addCurrWarnings and !@rangeWarn.nil?)
      if(@rangeWarn == FROM_NEGATIVE)
        retVal += "(Start set to 1; original start was negative.) "
      end
      if(@rangeWarn == SeqRetriever::TO_BEYOND_END)
        retVal += "(Stop set to #{@to}; original stop was longer than #{@refName}.) "
      end
    end
    return retVal
  end

  def getFdataByFid(uploadId, fid, doAutoInit=true)
    # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, doAutoInit)
    # 2) Get the fdatas
    fdatas = @dbu.selectFdataByFid(fid, BRL::Genboree::DBUtil::FDATA2)
    return fdatas
  end

  def getFdataByGname(uploadId, gname, doAutoInit=true)
    # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, doAutoInit)
    # 2) Get the fdatas
    order = (@doRevCompl ? BRL::Genboree::DBUtil::REV_ORDER : BRL::Genboree::DBUtil::FWD_ORDER)
    fdatas = @dbu.selectFdataByGname(gname, BRL::Genboree::DBUtil::FDATA2, order)
    return fdatas
  end

  def getFdataByExactGname(uploadId, gname, ftypeid=nil, rid=nil, doAutoInit=true)
    # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, doAutoInit)
    # 2) Get the fdatas
    order = (@doRevCompl ? BRL::Genboree::DBUtil::REV_ORDER : BRL::Genboree::DBUtil::FWD_ORDER)
    fdatas = @dbu.selectFdataByExactGname(gname, ftypeid, rid, BRL::Genboree::DBUtil::FDATA2, order)
    return fdatas
  end

  def getGroupFdataByFtypeidAndRid(uploadId, ftypeId, rid, doAutoInit=true)
    # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, doAutoInit)
    # 2) Get the fdatas
    order = (@doRevCompl ? BRL::Genboree::DBUtil::REV_ORDER : BRL::Genboree::DBUtil::FWD_ORDER)
    fdatas = @dbu.selectGroupFdataByFtypeidAndRid(ftypeId, rid, BRL::Genboree::DBUtil::FDATA2, order)
    return fdatas
  end

  def getFdataByFtypeidAndRid(uploadId, ftypeId, rid, doAutoInit=true)
     # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, doAutoInit)
    # 2) Get the fdatas
    order = (@doRevCompl ? BRL::Genboree::DBUtil::REV_ORDER : BRL::Genboree::DBUtil::FWD_ORDER)
    fdatas = @dbu.selectFdataByFtypeidAndRid(ftypeId, rid, BRL::Genboree::DBUtil::FDATA2, order)
    return fdatas
  end

  ##############################################################################
  # Use above setup and info methods to do more complex seq retrieval
  ##############################################################################
  # Get an annotation's sequence (given the start/stop of annotation
  def getSequenceForRange(uploadId, rid, from, to, outputDirect=false)
    # 1) Get and save a data db name. Do auto-initialize fref and fmeta info from this db.
    self.getDataDBNameByUploadId(uploadId, true)
    # 2) Set the rid
    if(rid.kind_of?(Fixnum) or rid =~ /^\d+$/)
      @rid = rid.to_i
      if(@frefsByRid.key?(@rid))
        @currFrefRec = @frefsByRid[@rid]
      else
        @currFrefRec = @dbu.selectFrefsByRid(@rid).first()
      end
      raise "ERROR: unknown rid (for an entrypoint) '#{rid}' in the current data db." if(@currFrefRec.nil? or @currFrefRec.empty?)
      @refName = @currFrefRec['refname']
    else # assume we were given the refName, not the rid itself
      @refName = rid
      if(@frefsByName.key?(@refName))
        @currFrefRec = @frefsByName[@refName]
      else
        @currFrefRec = @dbu.selectFrefsByName(@refName).first()
      end
      raise "ERROR: unknown refName '#{rid}' in the current data db." if(@currFrefRec.nil? or @currFrefRec.empty?)
      @rid = @currFrefRec['rid']
    end
    # 3) Get the ridSeqId
    @currRidSeqId = ridSeqId = self.getRidSeqIdForRid(@rid)
    # 4) Get the seq file using the ridSeqId
    fileInfo = self.getFileInfoByRidSeqId(ridSeqId)
    unless(fileInfo)
      if(fileInfo == NO_SEQ_FILE)
        raise "\n\nERROR: no sequence file found for ridSeqId '#{ridSeqId}' (status: #{fileInfo.inspect}, using masked? #{@useMasked})\n\n"
      else
        raise "\n\nERROR: unknown seqFile lookup status '#{fileInfo.class}:#{fileInfo.inspect}'\n\n"
      end
    end
    # 5) Get the sequence in the seq file
    if(outputDirect) # Then we have some large region or many regions. Save memory.
      sequence = outputSeqDataForRange(from, to, fileInfo)
    else # Short region or few regions, output fast.
      sequence = self.getSeqDataForRange(from, to, fileInfo)
    end
    # DONE
    return sequence
  end
  
  # Set both @refName and @rid so that they agree
  # @param [Integer, String] rid (or refName) to setup
  # @return [true, false] success or failure of operation
  def setRefNameAndRid(rid)
		retVal = false
		begin
			if(rid.kind_of?(Fixnum) or rid =~ /^\d+$/)
				@rid = rid.to_i
				if(@frefsByRid.key?(@rid))
					@currFrefRec = @frefsByRid[@rid]
				else
					@currFrefRec = @dbu.selectFrefsByRid(@rid).first()
				end
				raise "ERROR: unknown rid (for an entrypoint) '#{rid}' in the current data db." if(@currFrefRec.nil? or @currFrefRec.empty?)
				@refName = @currFrefRec['refname']
			else # assume we were given the refName, not the rid itself
				@refName = rid
				if(@frefsByName.key?(@refName))
					@currFrefRec = @frefsByName[@refName]
				else
					@currFrefRec = @dbu.selectFrefsByName(@refName).first()
				end
				raise "ERROR: unknown refName '#{rid}' in the current data db." if(@currFrefRec.nil? or @currFrefRec.empty?)
				@rid = @currFrefRec['rid']
			end
		rescue => error
			$stderr.debugPuts(__FILE__, __method__, "ERROR", "Encountered error while setting @refName and @rid -- has dbu.setNewDataDb() or setupUserDb() been invoked? #{error}\n#{error.backtrace.join(" \n")}")
			raise error
		end
		retVal = true
		return retVal
	end

  # return sequence data in chunks for a specified subset (range) of the sequence
  # all parameters are optional so that instance variables set in makeDefline may be more explicitly used here
  # @param [Integer, String] rid the row id for the sql table used to look up the sequence data file
  #   or the refName associated with that row
  # @param [Integer, nil] from the starting point to read sequence data from
  # @param [Integer, nil] to the ending point to read sequence data to
  def yieldSequenceForRange(rid=@rid, from=@from, to=@to)
    retVal = OK
    raise(ArgumentError, "yieldSequenceForRange expects a code block and none was given!") unless(block_given?)
    # 1) Set @rid, @refName and @currFrefRec
    setRefNameAndRid(rid)
    # 2) Set the @currRidSeqId and @currRidSeqInfo
    ridSeqId = self.getRidSeqIdForRid(@rid)
    if(@currRidSeqId.nil?)
      # then dbu select failed, and @currRidSeqInfo is also nil or is empty
      raise "ERROR: unable to get ridSeqId for RID #{@rid}"
    end
    # 3) Get the seq file using the ridSeqId, also sets @currFileInfo
    fileInfo = self.getFileInfoByRidSeqId(ridSeqId)
    unless(fileInfo)
      if(fileInfo == NO_SEQ_FILE)
        raise "\n\nERROR: no sequence file found for ridSeqId '#{ridSeqId}' (status: #{fileInfo.inspect}, using masked? #{@useMasked})\n\n"
      else
        raise "\n\nERROR: unknown seqFile lookup status '#{fileInfo.class}:#{fileInfo.inspect}'\n\n"
      end
    end
    # 4) Prepare the seq file
    setStatus = setFromAndToAllowNil(from, to) # validate the given range
    if(setStatus == FROM_BEYOND_END or setStatus == TO_NEGATIVE)
      raise(ArgumentError, "Inappropriate values for range, setStatus=#{setStatus}")
    end
    seekStart = @from - 1
    readLength = @to - @from + 1
    # Get offset info
    fileOffset = @currRidSeqInfo['offset']
    # Open file if it exists
    getSeqDir() if(@seqDir.nil? or @seqDir.empty?) # should have already been called by setupUserDb
    seqFileName = fileInfo['seqFileName']
    seqFileFullPath = @seqDir + '/' + seqFileName
    seqFileFullPath += '.masked' if(@useMasked)
    seqFile = self.openCachedFileHandle(seqFileFullPath)
    if(seqFile == SEQ_FILE_UNEXIST)
      raise "ERROR: Unable to open sequence file seqFileFullPath=#{seqFileFullPath}"
    end
    generateSeqFromFile(fileOffset + seekStart, readLength, seqFile) {|outBuffer| yield "#{outBuffer}"}
    return retVal
  end
  
  # Yield genome-wide FASTA sequence data for the given database
  # @param [String] groupName the group that the database is in
  # @param [String] dbName the name of the database
  # @return [Integer] status code mapped at beginning of seqRetriever
  def yieldFastaSequenceForGenome(groupName=@groupName, dbName=@dbName)
    retVal = OK
    setupUserDb(groupName, dbName) if(groupName != @groupName or dbName != @dbName)
    if(@groupName.nil? or @dbName.nil?)
      raise "ERROR: @groupName=#{@groupName} or @dbName=#{@dbName} is missing and required to generate a sequence."
    end
    if(@frefsByName.empty?)
      setupUserDb(@groupName, @dbName)
    end
    @frefsByName.each_key{ |refname|
      yield makeDefline(refname)
      yieldSequenceForRange() {|subSequence| yield subSequence}
    }
    return retVal
  end

  def getAnnoSequence(uploadId, rid, from, to, outputDirect=false)
    sequence = getSequenceForRange(uploadId, rid, from, to, outputDirect)   # Get sequence for a single range.
    return sequence
  end

end # class SeqRetriever

end ; end # module BRL ; module Genboree
