require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# ASSAY RELATED TABLES - DBUtil Extension Methods for dealing with Assay-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: assayData
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  ASSAYDATA_SELECT_ALL = 'select * from assayData'
  SELECT_ASSAYDATA_BY_ID_SQL = 'select * from assayData where id = ?'
  SELECT_ASSAYDATA_BY_ASSAYID_SQL = 'select * from assayData where assayId = ?'
  SELECT_ASSAYDATA_BY_SAMPLEID_SQL = 'select * from assayData where sampleId = ?'
  SELECT_FILELOC_BY_IDS = 'select fileLocation from assayData where assayId = ? AND assayRunId = ? AND sampleId = ?'
  INSERT_ASSAYDATA= 'insert into assayData values (?,?,?,?,?,?)'
  INSERT_MULTI_ASSAYDATA= 'insert into assayData values '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllAssayData(maxNum=nil)
    retVal = nil
    begin
      stmtSql = ASSAYDATA_SELECT_ALL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfAssayData(blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = ASSAYDATA_SELECT_ALL.dup
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
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def selectAssayDataById(assayId, maxNum=nil)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAYDATA_BY_ID_SQL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayDataByAssayId(assayId,maxNum=nil)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAYDATA_BY_ASSAYID_SQL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfAssayDataByAssayId(assayId, blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = SELECT_ASSAYDATA_BY_ASSAYID_SQL.dup
      stmtSql += " limit ?, #{blockSize} "
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      loop {
        stmt.execute(assayId,currRowOffset)
        retVal = stmt.fetch_all()
        break if(retVal.empty?)
        yield(retVal)
        currRowOffset += blockSize
        break if(retVal.size < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def selectAssayDataBySampleId(sampleId,maxNum=nil)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAYDATA_BY_SAMPLEID_SQL.dup
      stmtSql += " order by sampleId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(sampleId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfAssayDataBySampleId(sampleId, blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = SELECT_ASSAYDATA_BY_SAMPLEID_SQL.dup
      stmtSql += " limit ?, #{blockSize} "
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      loop {
        stmt.execute(sampleId,currRowOffset)
        retVal = stmt.fetch_all()
        break if(retVal.empty?)
        yield(retVal)
        currRowOffset += blockSize
        break if(retVal.size < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def selectFileLocByIDs(assayId, runId, sampleId)
    retVal = nil
    begin
      stmtSql = SELECT_FILELOC_BY_IDS
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId, runId, sampleId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertAssayDataEntry(sampleId, assayId, runId, fileLocation, date)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_ASSAYDATA)
      retVal = stmt.execute(nil, sampleId, assayId, runId, fileLocation, date)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_ASSAYDATA)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertMultiAssayDataEntries(values, records)
    #args are arrays
    retVal = nil
    begin
      connectToDataDb()
      ####
      # this can't be set higher than 1665, due to sql limitation of
      # 10k values (1665 * 6 = just under 10k)
      ####
      numRecordsToParse = 1665
      # puts "records = #{records}"

      if(records <= numRecordsToParse)
        insertStatement = INSERT_MULTI_ASSAYDATA
        1.upto(records) { |i|
          #add to insert statement
          if (i != 1)
            insertStatement << ","
          end
          insertStatement << "(?,?,?,?,?,?)"
        }
        stmt = @dataDbh.prepare(insertStatement)
        retVal = stmt.execute(*values)
      else # large # of data fields, have to split into chunks
        offset = 0
        counter = 0
        while (counter < values.length-1)
          insertStatement = "insert into assayData values "
          # do the next chunk
          i = 0
          while(i<(numRecordsToParse*6))
            break if(counter >= values.length-1)
            #add to insert statement
            if(i != 0)
              insertStatement << ","
            end
            insertStatement << "(?,?,?,?,?,?)"
            counter += 6
            i = i + 6
          end
          stmt = @dataDbh.prepare(insertStatement)
          retVal = stmt.execute(*values.slice(offset,(counter-offset)))
          offset += (numRecordsToParse * 6);
        end # while
      end # if (records < numRecordsToParse)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, insertStatement)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: assay
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  ASSAY_SELECT_ALL = 'select * from assay '
  SELECT_ASSAY_BY_ASSAYID_SQL = 'select * from assay where id = ? '
  SELECT_ASSAY_BY_ASSAYNAME_SQL = 'select * from assay where name'
  INSERT_ASSAY= 'insert into assay values (?,?,?,?,?)'
  GET_MAX_ASSAYID = 'SELECT MAX(id) FROM assay'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllAssays(maxNum=nil)
    retVal = nil
    begin
      stmtSql = ASSAYS_SELECT_ALL
      stmtSql += " order by id limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayByAssayId(assayId)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAY_BY_ASSAYID_SQL
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayByName(assayName, useLike=false)
    retVal = nil
    begin
      connectToDataDb()
      stmtSql = SELECT_ASSAY_BY_ASSAYNAME_SQL.dup
      if(useLike)
        stmtSql += (" like CONCAT('%', ?, '%')")
      else
        stmtSql += " = ? "
      end
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getMaxAssayId()
    retVal = nil
    begin
      stmtSql = GET_MAX_ASSAYID
      connectToDataDb()
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertAssayEntry(assayName, recordSize, annoAttribute, annoTrack)
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_ASSAY)
      retVal = stmt.execute(nil, assayName, recordSize, annoAttribute, annoTrack)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_ASSAY)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return getMaxAssayId()
  end

  # --------
  # Table: assayRecordFields
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  ASSAYRECORDFIELDS_SELECT_ALL = 'select * from assayRecordFields '
  SELECT_ASSAYRECORDFIELDS_BY_ASSAYID_SQL = 'select * from assayRecordFields where assayId = ?'
  SELECT_ASSAYRECORDFIELDS_BY_ID_SQL = 'select * from assayRecordFields where id = ?'
  SELECT_ASSAYRECORDFIELDS_BY_FIELDNAME_SQL = 'select * from assayRecordFields where fieldName'
  INSERT_ASSAYRECORD_FIELDDEF= 'insert into assayRecordFields values (?,?,?,?,?,?,?)'
  INSERT_MULTI_ASSAYRECORD_FIELDDEF= 'insert into assayRecordFields values '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllAssayRecordFields(maxNum=nil)
    retVal = nil
    begin
      stmtSql = ASSAYRECORDFIELDS_SELECT_ALL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfAssayRecordFields(blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = ASSAYRECORDFIELDS_SELECT_ALL.dup
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
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def selectAssayRecordFieldsByAssayId(assayId, maxNum=nil)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAYRECORDFIELDS_BY_ASSAYID_SQL.dup
      stmtSql += " order by fieldNumber limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayRecordFieldsById(fieldId,maxNum=nil)
    retVal = nil
    begin
      stmtSql = SELECT_ASSAYRECORDFIELDS_BY_ID_SQL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(fieldId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayRecordFieldsByFieldName(fieldName, useLike=false)
    retVal = nil
    begin
      connectToDataDb()
      stmtSql = SELECT_ASSAYRECORDFIELDS_BY_FIELDNAME_SQL.dup
      if(useLike)
        stmtSql += (" like CONCAT('%', ?, '%')")
      else
        stmtSql += " = ? "
      end
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(fieldName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def eachBlockOfAssayRecordFieldsByFieldName(fieldName, useLike=false, blockSize=10_000, &block )
    retVal = []
    currRowOffset = 0
    begin
      stmtSql = ASSAYRECORDFIELDS_SELECT_ALL.dup
      if(useLike)
        stmtSql += (" like CONCAT('%', ?, '%')")
      else
        stmtSql += " = ? "
      end
      connectToDataDb()
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(fieldName)
      loop {
        stmt.execute(fieldName, currRowOffset)
        retVal = stmt.fetch_all()
        break if(retVal.empty?)
        yield(retVal)
        currRowOffset += blockSize
        break if(retVal.size < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def insertAssayRecordFieldEntry(assayId,fieldName,fieldNumber,dataType,size,offset)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_ASSAYRECORD_FIELDDEF)
      retVal = stmt.execute(nil, assayId, fieldName, fieldNumber, dataType, size, offset)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_ASSAYRECORD_FIELDDEF)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertMultiRecordEntries(values, records)
    #args are arrays
    retVal = nil
    begin
      connectToDataDb()
      ####
      # this can't be set higher than 1428, due to sql limitation of
      # 10k values (1428 * 7 = just under 10k)
      ####
      numRecordsToParse = 1428
      if(records <= numRecordsToParse)
        insertStatement = INSERT_MULTI_ASSAYRECORD_FIELDDEF.dup
        1.upto(records) { |i|
          #add to insert statement
          if (i != 1)
            insertStatement << ","
          end
          insertStatement << "(?,?,?,?,?,?,?)"
        }
        stmt = @dataDbh.prepare(insertStatement)
        retVal = stmt.execute(*values)
      else # large # of data fields, have to split into chunks
        offset = 0
        counter = 0
        while(counter < values.length-1)
          insertStatement = "insert into assayRecordFields values "
          # do the next chunk
          i = 0
          while(i<(numRecordsToParse*7))
            break if(counter >= values.length-1)
            #add to insert statement
            if (i != 0)
              insertStatement << ","
            end
            insertStatement << "(?,?,?,?,?,?,?)"
            counter += 7;
            i = i + 7
          end
          stmt = @dataDbh.prepare(insertStatement)
          retVal = stmt.execute(*values.slice(offset,(counter-offset)))
          offset += (numRecordsToParse * 7);
        end # while
      end # if (records < numRecordsToParse)
      #retVal = stmt.execute(nil, assayId, fieldName, fieldNumber, dataType, size, offset)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, insertStatement)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: assayRun
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  ASSAYRUN_SELECT_ALL = 'select * from assayRun '
  SELECT_ASSAYRUN_BY_ID = 'select * from assayRun where id = ?'
  SELECT_ASSAYRUNID_BY_ASSAYID_NAME = 'select id from assayRun where assayId = ? and name = ?'
  INSERT_ASSAYRUN= 'insert into assayRun values (?,?,?,?)'
  GET_MAX_ASSAYRUNID = 'SELECT MAX(id) FROM assayRun'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllAssayRunFields(maxNum=nil)
    retVal = nil
    begin
      stmtSql = ASSAYRUN_SELECT_ALL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayRunByID(id)
      retVal = nil
    begin
      stmtSql = SELECT_ASSAYRUN_BY_ID
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(id)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssayRunByNameAndID(assayId, runName)
      retVal = nil
    begin
      stmtSql = SELECT_ASSAYRUNID_BY_ASSAYID_NAME
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(assayId, runName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertAssayRunEntry(assayId, name, date)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_ASSAYRUN)
      retVal = stmt.execute(nil, assayId, name, date)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_ASSAYRUN)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getMaxRunId()
    retVal = nil
    begin
      stmtSql = GET_MAX_ASSAYRUNID
      connectToDataDb()
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: assay2GenomeAnnotation
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  ASSAY2GENOMEANNOTATION_SELECT_ALL = 'select * from assay2GenomeAnnotation '
  SELECT_ASSAY2GENOMEANNOTATION_BY_ID = 'select * from assay2GenomeAnnotation where id = ?'
  INSERT_ASSAY2GENOMEANNOTATION= 'insert into assay2GenomeAnnotation values (?,?,?,?)'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllAssay2GenomeAnnotationFields(maxNum=nil)
    retVal = nil
    begin
      stmtSql = ASSAY2GENOMEANNOTATION_SELECT_ALL.dup
      stmtSql += " order by assayId limit #{maxNum} " unless(maxNum.nil?)
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAssay2GenomeAnnotationByID(id)
      retVal = nil
    begin
      stmtSql = SELECT_ASSAY2GENOMEANNOTATION_BY_ID
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(stmtSql)
      stmt.execute(id)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, stmtSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertIntoAssay2GenomeAnnotation(assayId, recordNum, attrValue)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_ASSAY2GENOMEANNOTATION)
      retVal = stmt.execute(nil, assayId, recordNum, attrValue)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_ASSAY2GENOMEANNOTATION)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
