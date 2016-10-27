require 'brl/genboree/dbUtil'

module BRL ; module Genboree
class DBUtil  # previously organized as module FidTextTable
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_COMMENTS_BY_FID_AND_FTYPEID =  'SELECT * FROM fidText WHERE textType="t" AND fid=? AND ftypeid=?'
  SELECT_SEQUENCE_BY_FID_AND_FTYPEID =  'SELECT * FROM fidText WHERE textType="s" AND fid=? AND ftypeid=?'
  SELECT_ALL_FIDTEXT_BY_FIDS = 'SELECT * FROM fidText WHERE fid IN %FIDS%'
  SELECT_FID_WITH_COMMENTS_BY_FTYPEID_AND_FIDS = 'select fid, text from fidText where textType="t" and ftypeid = ? and fid in ( '
  SELECT_FID_WITH_SEQUENCE_BY_FTYPEID_AND_FIDS = 'select fid, text from fidText where textType="s" and ftypeid = ? and fid in ( '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectCommentsByFidAndFtypeid(fid, ftypeid)
    retVal = []
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_COMMENTS_BY_FID_AND_FTYPEID)
      stmt.execute(fid, ftypeid)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_COMMENTS_BY_FID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectSequenceByFidAndFtypeid(fid, ftypeid)
    retVal = []
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_SEQUENCE_BY_FID_AND_FTYPEID)
      stmt.execute(fid, ftypeid)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_SEQUENCE_BY_FID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectFidWithCommentsByFtypeIdAndFids(ftypeId, fids)
    retVal = nil
    return retVal if(fids.nil? or fids.empty?)
    begin
      connectToDataDb()
      sql = SELECT_FID_WITH_COMMENTS_BY_FTYPEID_AND_FIDS.dup
      fids.each {|fId|
        fId = fId.to_s.gsub(/\\/, "\\")
        fId = fId.to_s.gsub(/'/, "\\\\'")
        sql << "'#{fId}',"
      }
      sql.chomp!(",")
      sql << ")"
      stmt = @dataDbh.prepare(sql)
      stmt.execute(ftypeId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectFidWithSequenceByFtypeIdAndFids(ftypeId, fids)
    retVal = nil
    return retVal if(fids.nil? or fids.empty?)
    begin
      connectToDataDb()
      sql = SELECT_FID_WITH_SEQUENCE_BY_FTYPEID_AND_FIDS.dup
      fids.each {|fId|
        fId = fId.to_s.gsub(/\\/, "\\")
        fId = fId.to_s.gsub(/'/, "\\\\'")
        sql << "'#{fId}',"
      }
      sql.chomp!(",")
      sql << ")"
      stmt = @dataDbh.prepare(sql)
      stmt.execute(ftypeId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectAllFidTextByFids(fids = nil)
    retVal = []
    sql = ""
    begin
      if(fids.nil?)
        retVal = selectAll(:userDB, "fidText", "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
      else
        connectToDataDb()
        sql = SELECT_ALL_FIDTEXT_BY_FIDS.dup
        fidsSqlSetStr = DBUtil.makeSqlSetStr(fids.size)
        sql.gsub!(/%FIDS%/, fidsSqlSetStr)
        stmt = @dataDbh.prepare(sql)
        stmt.execute(*(fids))
        retVal = stmt.fetch_all()
      end
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_ALL_FIDTEXT_BY_FIDS)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  FT_CLEAN_ORPHANS_SQL = "delete low_priority from fidText where not exists(select null from fdata2 where fdata2.fid = fidText.fid) limit 10000"
  def cleanFidTextOrphans()
    client = nil
    retVal = 0
    begin
      client = getMysql2Client(:userDB)
      # Delete 10,000 orphan records at a time, using a low_priority delete. Because not too
      # many records and scheduled by low_priority, other db ops should be able to do their thing
      # on this table.
      currNumRowsAffected = 0
      numAffectedSinceLastSleep = 0
      loop {
        client.query(FT_CLEAN_ORPHANS_SQL, :cast_booleans => true)
        currNumRowsAffected = client.affected_rows rescue nil
        if(currNumRowsAffected and currNumRowsAffected > 0)
          retVal += currNumRowsAffected
          numAffectedSinceLastSleep += currNumRowsAffected
          # Should we take a little pause? Maybe, if enough records. 2.5 secs every 200,000 on average
          if(numAffectedSinceLastSleep >= 100_000)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleted #{retVal.inspect} rows so far.")
            numAffectedSinceLastSleep = 0
            sleep(5) if(rand > 0.5)
          end
        else # something wrong or 0 rows affected; regardless, stop
          break
        end
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, FT_CLEAN_ORPHANS_SQL)
    ensure
      client.close rescue nil
    end
    return retVal
  end
end # updates to class DBUtil
end ; end # module BRL ; module Genboree
