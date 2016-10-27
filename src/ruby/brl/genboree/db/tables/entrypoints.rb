require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# FREF RELATED TABLES - DBUtil Extension Methods for dealing with Fref-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: fref
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  FREF_KEY_COLUMNS = [ 'rid', 'refname', 'rlength' ]
  INSERT_FREF = 'insert into fref values ( %values% )'
  UPDATE_FREF_FOR_RID = 'update fref set %setStr% where rid = ?'
  UPDATE_NAME_BY_ID = 'update fref set refname = ? where rid = ?'
  # ############################################################################
  # METHODS
  # ############################################################################
  def countFrefs()
    return countRecords(:userDB, 'fref', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectAllRefNames(orderByrefname=true)
    return selectAllFields(:userDB, 'fref', FREF_KEY_COLUMNS, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", { :sortBy => 'refname' })
  end

  def selectFrefsByRid(rid)
    return selectFieldsByFieldAndValue(:userDB, 'fref', FREF_KEY_COLUMNS, false, 'rid', rid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
  alias selectFrefByRid selectFrefsByRid

  def selectFrefsByRids(rids)
    return selectFieldsByFieldWithMultipleValues(:userDB, 'fref', FREF_KEY_COLUMNS, false, 'rid', rids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectRidByName(refName)
    retVal = nil
    resultSet = selectFieldsByFieldAndValue(:userDB, 'fref', FREF_KEY_COLUMNS, false, 'refname', refName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    unless(resultSet.nil? or resultSet.empty?) # then we found an existing one. It will be REPLACED.
      retVal = resultSet.first['rid']
    end
    return retVal
  end

  def selectFrefsByNames(names)
    return selectFieldsByFieldWithMultipleValues(:userDB, 'fref', FREF_KEY_COLUMNS, false, 'refname', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_FIRST_FREF = 'select * from fref order by refname limit 1'
  def selectFirstFref()
    retVal = sql = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FIRST_FREF
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_FREF_BY_NAME_SQL = "select rid,refname,rlength,gname from fref where refname like '{refname}'"
  def selectFrefsByName(refNamePattern, exactMatch=false)
    retVal = sql = nil
    begin
      client = getMysql2Client(:userDB)
      refNamePattern = (refNamePattern.strip + '%') unless(exactMatch)
      sql = SELECT_FREF_BY_NAME_SQL.gsub(/\{refname\}/, mysql2gsubSafeEsc(refNamePattern.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end
  alias selectFrefByName selectFrefsByName

  def insertFrefRec(frefRec)
    rid = nil
    begin
      connectToDataDb()
      # Make the valueStr
      valueStr = frefRec.map{|xx| xx = 'NULL' if(xx.nil?) ; @dataDbh.quote("#{xx.to_s}") }.join(", ")
      insertSql = INSERT_FREF.gsub(/%values%/, valueStr)
      @dataDbh.do(insertSql)
      rid = @dataDbh.func(:insert_id)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, insertSql)
    ensure
    end
    return rid
  end

  def updateFrefRec(frefRec)
    rid = frefRec[0].to_i
    # Make the setStr
    connectToDataDb()
    quotedFrefRec = frefRec.map{|xx| xx = 'NULL' if(xx.nil?) ; @dataDbh.quote("#{xx.to_s}") }
    setStr =  "refname = '#{frefRec[1]}', rlength = '#{frefRec[2]}', rbin = '#{frefRec[3]}', " +
              "ftypeid = '#{frefRec[4]}', rstrand = '#{frefRec[5]}', gid = '#{frefRec[6]}', gname = '#{frefRec[7]}'"
    updateSql = UPDATE_FREF_FOR_RID.gsub(/%setStr%/, setStr)
    begin

      stmt = @dataDbh.prepare(updateSql)
      stmt.execute(rid)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, updateSql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  def updateFrefByRid(rid, updateData)
    return updateByFieldAndValue(:userDB, 'fref', updateData, 'rid', rid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Updates only refName by rid
  # [+rid+]
  # [+refName+] name of the entrypoint/chromosome
  # [+returns+] number of rows changed
  def updateRefNameByRid(rid, refName)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_NAME_BY_ID)
      stmt.execute(refName, rid)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_NAME_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a fref record by its name. The name has to be an exact match
  # [+refName+]
  # [+returns+] Number of rows deleted
  def deleteFrefByName(refName)
    return deleteByFieldAndValue(:userDB, 'fref', 'refname', refName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: ridSequence
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  RIDSEQUENCE_KEY_COLUMNS = [ 'ridSeqId', 'seqFileName', 'deflineFileName' ]
  INSERT_RID_SEQUENCE = 'insert into ridSequence values ( %values% )'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllRidSequences()
    return selectAllFields(:userDB, 'ridSequence', RIDSEQUENCE_KEY_COLUMNS, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectFilesByRidSeqId(ridSeqId)
    return selectFieldsByFieldAndValue(:userDB, 'ridSequence', RIDSEQUENCE_KEY_COLUMNS, false, 'ridSeqId', ridSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Mod this for RidSequenceTable
  def insertRidSequenceRec(ridSequenceRec)
    ridSeqId = nil
    # Make the valueStr
    valueStr = ridSequenceRec.map{|xx| xx = 'NULL' if(xx.nil?) ; @dataDbh.quote("#{xx.to_s}") }.join(", ")
    insertSql = INSERT_RID_SEQUENCE.gsub(/%values%/, valueStr)
    begin
      connectToDataDb()
      @dataDbh.do(insertSql)
      ridSeqId = @dataDbh.func(:insert_id)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, insertSql)
    ensure
    end
    return ridSeqId
  end

  def deleteRidSequence(ridSeqId)
    return deleteByFieldAndValue(:userDB, 'ridSequence', 'ridSeqId', ridSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: rid2ridSeqId
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  RID2RIDSEQID_KEY_COLUMNS = [ 'rid', 'ridSeqId', 'offset', 'length' ]
  INSERT_RID2RIDSEQID = 'insert into rid2ridSeqId values ( %values% )'
  # ############################################################################
  # METHODS
  # ############################################################################
  RID2RIDSEQID_SELECT_ALL = 'select rid,ridSeqId,offset,length from rid2ridSeqId '
  def selectAllRid2RidSeqIds()
    return selectAllFields(:userDB, 'rid2ridSeqId', RID2RIDSEQID_KEY_COLUMNS, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectRidSeqIdByRid(rid)
    return selectFieldsByFieldAndValue(:userDB, 'rid2ridSeqId', RID2RIDSEQID_KEY_COLUMNS, false, 'rid', rid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertRid2RidSeqIdRec(rid2ridSeqIdRec)
    # Make the valueStr
    valueStr = rid2ridSeqIdRec.map{|xx| xx = 'NULL' if(xx.nil?) ; @dataDbh.quote("#{xx.to_s}") }.join(", ")
    insertSql = INSERT_RID2RIDSEQID.gsub(/%values%/, valueStr)
    begin
      connectToDataDb()
      @dataDbh.do(insertSql)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, insertSql)
    ensure
    end
    return
  end

  def deleteRid2RidSeqId(rid)
    return deleteByFieldAndValue(:userDB, 'rid2ridSeqId', 'rid', rid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
