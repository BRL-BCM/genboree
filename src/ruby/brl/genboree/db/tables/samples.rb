require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# SAMPLE RELATED TABLES - DBUtil Extension Methods for dealing with Sample-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: samples
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  COUNT_SAMPLES_SQL = 'select count(*) from samples '
  SAMPLES_SELECT_ALL_SQL = 'select * from samples '
  SELECT_SAMPLE_BY_NAME_SQL = 'select * from samples where saName = ?'
  SELECT_SAMPLEID_BY_NAME_SQL = 'select saId from samples where saName = ?'
  SELECT_SAMPLE_BY_ID_SQL = 'select * from samples where saId = ?'
  SELECT_AVPS_FOR_SAMPLE_SQL =  "select samplesAttNames.saName, samplesAttValues.saValue from " +
                                "samplesAttNames, samplesAttValues, samples2attributes " +
                                "where samples2attributes.saId = ? and " +
                                "samplesAttNames.saAttNameId = samples2attributes.saAttNameId " +
                                "and samplesAttValues.saAttValueId = samples2attributes.saAttValueId"
  # ############################################################################
  # METHODS
  # ############################################################################
  def countSamples()
    retVal = nil
    begin
      connectToDataDb()                                   # Lazy connect to data database
      stmt = @dataDbh.prepare(COUNT_SAMPLES_SQL)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#countSamples():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAllSamples(maxNum=nil)
    retVal = nil
    begin
      stmtSql = SAMPLES_SELECT_ALL_SQL.dup
      stmtSql += " order by saName limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllSamples():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectSampleByName(sampleName)
    retVal = nil
    begin
      connectToDataDb()
      stmtSql = SELECT_SAMPLE_BY_NAME_SQL
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(sampleName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectSampleByName():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectSampleIdByName(sampleName)
    retVal = nil
    begin
      connectToDataDb()
      stmtSql = SELECT_SAMPLEID_BY_NAME_SQL
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(sampleName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectSampleIdByName():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectSampleById(sampleId)
    retVal = nil
    begin
      connectToDataDb()
      stmtSql = SELECT_SAMPLE_BY_ID_SQL
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(sampleId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectSampleBId():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAllAttributeValuesForSample(sampleId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_AVPS_FOR_SAMPLE_SQL)
      stmt.execute(sampleId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllAttributeValuesForSample():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: samplesAttNames
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  COUNT_SAMPLES_ATT_NAMES_SQL = 'select count(*) from samplesAttNames '
  SAMPLES_ATT_NAMES_SELECT_ALL_SQL = 'select * from samplesAttNames '
  # ############################################################################
  # METHODS
  # ############################################################################
  def countSamplesAttNames()
    retVal = nil
    begin
      connectToDataDb()                                   # Lazy connect to data database
      stmt = @dataDbh.prepare(COUNT_SAMPLES_ATT_NAMES_SQL)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#countSamplesAttNames():", @err, COUNT_SAMPLES_ATT_NAMES_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAllSamplesAttNames(maxNum=nil)
    retVal = nil
    begin
      stmtSql = SAMPLES_ATT_NAMES_SELECT_ALL_SQL.dup
      stmtSql += " order by saName limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllSamplesAttNames():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: samplesAttValues
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  COUNT_SAMPLES_ATT_VALUES_SQL = 'select count(*) from samplesAttValues '
  SAMPLES_ATT_VALUES_SELECT_ALL_SQL = 'select * from samplesAttValues '
  # ############################################################################
  # METHODS
  # ############################################################################
  def countSamplesAttValues()
    retVal = nil
    begin
      connectToDataDb()                                   # Lazy connect to data database
      stmt = @dataDbh.prepare(COUNT_SAMPLES_ATT_VALUES_SQL)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#countSamplesAttValues():", @err, COUNT_SAMPLES_ATT_VALUES_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAllSamplesAttValues(maxNum=nil)
    retVal = nil
    begin
      stmtSql = SAMPLES_ATT_VALUES_SELECT_ALL_SQL.dup
      stmtSql += " order by saValue limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllSamplesAttValues():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: samples2attributes
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SAMPLES2ATTRIBUTES_SELECT_ALL = 'select * from samples2attributes '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllSamples2Attributes(maxNum=nil)
    retVal = nil
    begin
      stmtSql = SAMPLES2ATTRIBUTES_SELECT_ALL.dup
      stmtSql += " order by saId, saAttNameId, saAttValueId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllSamples2Attributes():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfSamples2Attributes(blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = SAMPLES2ATTRIBUTES_SELECT_ALL.dup
      stmtSql += " limit ?, #{blockSize} "
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      loop {
        stmt.execute(currRowOffset)
        retVal = stmt.fetch_all()
        break if(retVal.empty?)
        yield(retVal)
        currRowOffset += blockSize
        break if(retVal.size < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#eachBlockOfSamples2Attributes():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
