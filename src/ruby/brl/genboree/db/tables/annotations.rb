require 'brl/util/util'
require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# FDATA2 RELATED TABLES - DBUtil Extension Methods for dealing with Fdata2-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: fdata2
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  FDATA_HASH = {  0 => 'fdata2', 1 => 'fdata2_cv', 2 => 'fdata2_gv' }
  FDATA2,FDATA2_CV,FDATA2_GV = 0,1,2
  FWD_ORDER, REV_ORDER = 0,1
  FDATA_RID = 1

  # ############################################################################
  # METHODS
  # ############################################################################
  def lockFdata(lockType)
    return lockTables(:userDB, ['fdata2'], lockType, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def countFdatas(tableCode=FDATA2)
    return countRecords(:userDB, FDATA_HASH[tableCode], "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectFdataByFtypeId(ftypeId, maxNum=10_000)
    return selectFieldsByFieldAndValue(:userDB, 'fdata2', [ 'fstart', 'fstop' ], false, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", maxNum)
  end

  def selectFdataCountByFtypeId(ftypeId)
    return countByFieldAndValue(:userDB, 'fdata2', 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectMaxScoreByFtypeId(ftypeId)
    return selectFieldsByFieldAndValue(:userDB, 'fdata2', [ 'max(fscore) as maxFscore' ], false, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectMinScoreByFtypeId(ftypeId)
    return selectFieldsByFieldAndValue(:userDB, 'fdata2', [ 'min(fscore) as minFscore' ], false, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getMaxFidFromFdata()
    return selectAllFields(:userDB, 'fdata2', [ 'max(fid)' ], false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # First lock the fdata2 table, get the max(id) of the table, insert a terminal record to *block* the ids so that we can do our insert. Finally, release the lock
  # [+sentinalFidOffset+]
  # [+returns+] maxFid
  def insertFdataSentinalRecord(sentinalFidOffset)
    retVal = sql = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "lock tables fdata2 write"
      client.query(sql, :cast_booleans => true)
      sql = "select max(fid) AS fid from fdata2"
      resultSet = client.query(sql, :cast_booleans => true)
      maxFidRecs = resultSet.entries
      if(maxFidRecs.nil? or maxFidRecs.empty?)
        maxFid = 0
      else
        maxFid = maxFidRecs.first['fid'].nil? ? 0 : maxFidRecs.first['fid']
      end
      sentinalFid = maxFid  + (sentinalFidOffset + 1)
      # Insert sentinal fdata2 entry with the terminal fid
      # Since gname is part of the primary key, adding the terminal fid as part of the gname will keep the primary key unique in case of multiple cuncurrent uploads.
      sql = "insert into fdata2 values (#{sentinalFid}, 99999, 99999, 99999, 0.000000, 99999, 999999.999, '+', '0', NULL, NULL, 'bogusRecord_#{sentinalFid}', NULL, NULL, NULL)"
      client.query(sql, :cast_booleans => true)
      sql = "unlock tables"
      client.query(sql, :cast_booleans => true)
      retVal = maxFid
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      sql = "unlock tables"
      client.query(sql, :cast_booleans => true)
      client.close() rescue nil
    end
    return retVal
  end

  # Retrieve a unique list of annotation NAMES.
  # - optionally match a specific pattern
  # - optionally return upto a maximum number of results
  # - optionally return a random set of matching names (most useful if a max result number is being used and
  #   even more so if max result number + no pattern)
  # [ftypeid]     - id of track to get anno names from
  # [limit] - if present (recommended!!!), will add a 'limit {limit}' constraint to the SQL; else it will be all gnames
  #           and maybe quite slow!
  # [likePattern] - if present, will be used to create an SQL where clause of the form 'and gname like "{likePattern}'
  # [random]      - if present, will be used to give back a random set of names matching the pattern; has NO effect
  #                 when there is no limit because all results are being returned anyway.
  # [returns] - table of result rows with 1 column: 'gname'
  SELECT_DISTINCT_GNAMES_FOR_TRACK = "select distinct(gname) as gname from fdata2 where ftypeid = '{ftypeId}' "
  def selectDistinctGnamesByTrack(ftypeId, limit=nil, likePattern=nil, random=false)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DISTINCT_GNAMES_FOR_TRACK.dup.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      # Deal with pattern
      if(likePattern)
        sql << " and gname like '#{likePattern}' "  # <= Do not escape, assumed to be an SQL %-pattern
      end
      # Deal with random result set, if approrpriate
      if(limit and random)
        sql << " order by rand() "
      else
        # Ensure dealing with limits on the sorted list
        sql << " order by gname "
      end
      # Apply limit if any
      if(limit)
        raise ArgumentError, "ERROR: #{File.basename(__FILE__)}:#{__method__}() => If provided, the 'limit' argument must be >= 0." unless(limit > 0)
        sql << " limit #{limit}"
      end
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  def selectStartStopByRidAndFtypeIdOrderedByStartStop(rid, ftypeId)
    desiredFields = [ 'fstart', 'fstop' ]
    extraOpts = { :orderBy => [ 'fstart', 'fstop' ] }
    selectCond = { 'rid' => rid, 'ftypeid' => ftypeId }
    return selectFieldsByMultipleFieldsAndValues(:userDB, 'fdata2', desiredFields, false, selectCond, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", extraOpts )
  end

  def selectFdata2ByRidAndFtypeIdAndGnameOrderedByCoord(rid, ftypeId, gname, raiseErr=false)
    retVal = nil
    extraOpts = { :orderBy => [ 'fstart', 'fstop' ] }
    selectCond = { 'rid' => rid, 'ftypeid' => ftypeId, 'gname' => gname }
    retVal = selectByMultipleFieldsAndValues(:userDB, 'fdata2', selectCond, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", extraOpts )
    # reraise any caught error, if asked and encountered
    raise @err if(@err and raiseErr)
    return retVal
  end

  def selectFdataCoordByExactGname(ftypeId, gname, order=FWD_ORDER, raiseErr=false)
    retVal = nil
    desiredFields = [ 'rid', 'fstart', 'fstop' ]
    selectCond = { 'ftypeid' => ftypeId, 'gname' => gname }
    extraOpts = ((order == FWD_ORDER) ? { :orderBy => [ 'fstart', 'fstop' ] } : { :descOrderBy => [ 'fstop', 'fstart' ] } )
    retVal = selectFieldsByMultipleFieldsAndValues(:userDB, 'fdata2', desiredFields, false, selectCond, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", extraOpts)
    # reraise any caught error, if asked and encountered
    raise @err if(@err and raiseErr)
    return retVal
  end

  def selectMaxFstopFromFdataForRidAndFtypeId(rid, ftypeId)
    return selectFieldsByMultipleFieldsAndValues(:userDB, 'fdata2', [ 'max(fstop) as maxFstop' ], false, { 'rid' => rid, 'ftypeid' => ftypeId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_START_STOP_SCORE_BY_RID_AND_FTYPEID = "select fstart, fstop, fscore from fdata2 where ftypeid = '{ftypeId}' and rid = '{rid}' "
  def selectStartStopAndScoreByFtypeIdAndRid(ftypeId, rid, blockSize=10_000)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_START_STOP_SCORE_BY_RID_AND_FTYPEID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql << " limit {offset}, #{blockSize}"
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return
  end

  FID_SELECT_SQL = "select fdata2.gname, fdata2.rid, fstart, fstop, fdata2.ftypeid, fscore, refname, fstrand from %table%, fref where fdata2.fid = '{fid}' and fref.rid=fdata2.rid "
  def selectFdataByFid(fid, tableCode=FDATA2)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = FID_SELECT_SQL.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      sql = sql.gsub(/\{fid\}/, mysql2gsubSafeEsc(fid.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  GNAME_SELECT_SQL = "select fdata2.gname, fdata2.rid, fstart, fstop, fdata2.ftypeid, fscore, refname, fstrand from %table%,fref where fdata2.gname like '{gname}' and fref.rid=fdata2.rid "
  def selectFdataByGname(gnamePattern, tableCode=FDATA2, order=FWD_ORDER)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = GNAME_SELECT_SQL.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      # Make gname a safe pattern
      escGnamePattern = "#{mysql2gsubSafeEsc(gnamePattern.to_s.strip)}%"
      sql = sql.gsub(/\{gname\}/, escGnamePattern)
      sql << (order==FWD_ORDER ? ' order by fref.refname, fdata2.fstart, fdata2.fstop ' : ' order by fref.refname, fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_FIDS_BY_EXACT_GNAME = "select fid from %table% as fdata2 where fdata2.gname = '{gname}' "
  def selectFidsByExactGname(gname, ftypeId=nil, rid=nil, tableCode=FDATA2, maxNum=10_000)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FIDS_BY_EXACT_GNAME.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      sql = sql.gsub(/\{gname\}/, mysql2gsubSafeEsc(gname.to_s))
      unless(ftypeId.nil?)
        sql += " and fdata2.ftypeid = '#{mysql2gsubSafeEsc(ftypeId.to_s)}' "
      end
      unless(rid.nil?)
        sql += " and fdata2.rid = '#{mysql2gsubSafeEsc(rid.to_s)}' "
      end
      unless(maxNum.nil?)
        sql += " limit #{maxNum} "
      end
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Use with limit=2 to test if the annotations have variable span
  SELECT_DATA_SPANS = "select distinct (fstop-fstart) as span from fdata2 where ftypeid = '{ftypeId}' "
  def selectDataSpanByFtypeId(ftypeId, limit=10_000)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DATA_SPANS.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      sql += " limit #{limit}" if(limit and limit.is_a?(Fixnum))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_RECORD_FROM_FDATA_BY_FTYPE_SQL = "select 1 from fdata2 where ftypeid = '{ftypeId}' limit 1 "
  def selectFdataExistsForFtypeId(ftypeId)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_RECORD_FROM_FDATA_BY_FTYPE_SQL.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  EXACT_GNAME_SELECT_SQL = "select fdata2.gname, fdata2.rid, fstart, fstop, fdata2.ftypeid, fscore, refname, fstrand from %table%,fref where fdata2.gname = '{gname}' and fref.rid=fdata2.rid "
  def selectFdataByExactGname(gname, ftypeId=nil, rid=nil, tableCode=FDATA2, order=FWD_ORDER)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = EXACT_GNAME_SELECT_SQL.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      # Make gname a safe pattern
      sql = sql.gsub(/\{gname\}/, mysql2gsubSafeEsc(gname.to_s))
      unless(ftypeId.nil?)
        sql += " and fdata2.ftypeid = '#{mysql2gsubSafeEsc(ftypeId.to_s)}' "
      end
      unless(rid.nil?)
        sql += " and fdata2.rid = '#{mysql2gsubSafeEsc(rid.to_s)}' "
      end
      sql << (order==FWD_ORDER ? ' order by fref.refname, fdata2.fstart, fdata2.fstop ' : ' order by fref.refname, fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  FTYPE_RID_SELECT_SQL = "select gname, rid, fstart, fstop, ftypeid, fscore, fstrand from %table% where ftypeid = '{ftypeId}' and rid = '{rid}' "
  def selectFdataByFtypeidAndRid(ftypeId, rid, tableCode=FDATA2, order=FWD_ORDER)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = FTYPE_RID_SELECT_SQL.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select annotation data by ftypeid and rid
  #
  # WARNING: This method may return MANY rows. use eachBlockOfFdataColsByFtypeidAndRid to control this
  #
  # [+ftypeid+]     Id of the track, ftype.ftypeid
  # [+rid+]         Id of the entrypoint, fref.rid
  # [+columns+]     The columns that will be select from fdata2, default is *
  # [+order+]       The sort order of the results, 0 => ASC, 1 => DESC
  # [+returns+]     Array of fdata2 Row objects
  SELECT_FDATA_BY_RID_AND_FTYPEID = "select %columns% from fdata2 where ftypeid = '{ftypeId}' and rid = '{rid}' "
  def selectFdataColsByFtypeidAndRid(ftypeId, rid, columns='*', order=FWD_ORDER)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FDATA_BY_RID_AND_FTYPEID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      columns = columns.join(', ') if(columns.is_a?(Array))
      sql = sql.gsub(/%columns%/, columns)  # don't escape, supposed to provide things like "*" or column list (as a csv string ready to use)
      sql << (order==FWD_ORDER ? ' order by fref.refname, fdata2.fstart, fdata2.fstop ' : ' order by fref.refname, fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select annotation data by start/stop locations
  #
  # Uses the Binning class to construct query that takes advantage of rtree
  # Searching by landmark also requires rid and ftypeid
  #
  # [+ftypeid+]     Id of the track, ftype.ftypeid
  # [+rid+]         Id of the entrypoint, fref.rid
  # [+columns+]     The columns that will be select from fdata2, default is *
  # [+order+]       The sort order of the results, 0 => ASC, 1 => DESC
  # [+blockSize+]   The number of records returned per enumeration
  # [+block+]       block arg
  # [+returns+]     nil
  def eachBlockOfFdataColsByFtypeidAndRid(ftypeId, rid, columns='*', order=FWD_ORDER, blockSize=10_000, raiseErr=false)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FDATA_BY_RID_AND_FTYPEID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      columns = columns.join(', ') if(columns.is_a?(Array))
      sql = sql.gsub(/%columns%/, columns)  # don't escape, supposed to provide things like "*" or column list (as a csv string ready to use)
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      sql << " limit {offset}, #{blockSize}"
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
      raise @err if(@err and raiseErr)
    end
    return
  end

  def selectFdataInChunks(ftypeId, rid, ridLength, columns="*", order=FWD_ORDER, start=nil, stop=nil, chunkSize=50_000, raiseErr=false)
    start = 1 if(start.nil?)
    stop = ridLength if(stop.nil?)
    stop = stop.to_i
    chunkStart = start.to_i
    chunkStop = chunkStart + chunkSize
    chunkStop = stop if(chunkStop > stop)
    columns = columns.join(', ') if(columns.is_a?(Array))
    begin
      loop {
        #yield getFdataWithoutOverlaps(ftypeId, rid, columns, order=FWD_ORDER, chunkStart, chunkStop)
        eachBlockOfFdataByLandmark(rid, ftypeId, chunkStart, chunkStop, columns, order, 20_000, raiseErr) {|chunk| yield chunk }
        chunkStart = (chunkStop + 1)
        chunkStop = chunkStart + chunkSize
        chunkStop = stop if(chunkStop > stop)
        break if(chunkStart > stop)
      }
    rescue => @err
      if(raiseErr)
        raise @err
      else
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "Error in looping over fdata2 records")
      end
    end
    return
  end

  def getFdataWithoutOverlaps(ftypeId, rid, columns, order=FWD_ORDER, start=1, stop=1)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      binner = BRL::SQL::Binning.new()
      sql = "select %columns% from fdata2 where rid = #{mysql2gsubSafeEsc(rid.to_s)} and ftypeid = #{mysql2gsubSafeEsc(ftypeId.to_s)} and %binClause% and fstart >= #{mysql2gsubSafeEsc(start.to_s)} and fstart <= #{mysql2gsubSafeEsc(stop.to_s)} "
      columns = columns.join(', ') if(columns.is_a?(Array))
      sql.gsub!( /%columns%/, columns)
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql.gsub!( /%binClause%/, binClause)
      sql += (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sql: #{sql.inspect}")
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Select annotation data by start/stop locations
  #
  # Uses the Binning class to construct query that takes advantage of rtree
  # Searching by landmark also requires rid and ftypeid
  #
  # [+rid+]         Id of the entrypoint, fref.rid
  # [+ftypeid+]     Id of the track, ftype.ftypeid
  # [+start+]       The start location of the desired range
  # [+stop+]        The stop location of the desired range
  # [+columns+]     The columns that will be select from fdata2, default is *
  # [+order+]       The sort order of the results, 0 => ASC, 1 => DESC
  # [+blockSize+]   The number of records returned per enumeration
  # [+block+]       block arg
  # [+returns+]     nil
  SELECT_FDATA_BY_LANDMARK_AS_CHUNKS = "select %columns% from fdata2 where rid = '{rid}' and ftypeid = '{ftypeId}' and %binClause% and fstart >= '{start}' and fstart <= '{stop}'"
  def eachBlockOfFdataByLandmark(rid, ftypeid, start, stop, columns='*', order=FWD_ORDER, blockSize=10_000, raiseErr=false, &block)
    client = nil
    retVal = []
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      binner = BRL::SQL::Binning.new()
      columns = columns.join(', ') if(columns.is_a?(Array))
      sql = SELECT_FDATA_BY_LANDMARK_AS_CHUNKS.gsub(/%columns%/, columns) # <= do not escape, should support column lists like "*" and csv strings of columns etc
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql = sql.gsub(/%binClause%/, binClause)
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeid.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql = sql.gsub(/\{stop\}/, mysql2gsubSafeEsc(stop.to_s)).gsub(/\{start\}/, mysql2gsubSafeEsc(start.to_s))
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      sql << " limit {offset}, #{blockSize} "
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
      #resultSet = client.query(sql.gsub(/\{offset\}/, offset.to_s), :cast_booleans => true)
      #retVal = resultSet.entries
    rescue => @err
      if(raiseErr)
        client.close() rescue false
        raise @err
      else
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      end
    ensure
      client.close rescue false
    end
    return retVal
  end

  FTYPE_RID_GROUPED_SELECT_SQL = "select gname, rid, min(fstart), max(fstop), fstrand from fdata2 where ftypeid = '{ftypeId}' and rid = '{rid}' group by gname "
  def selectGroupFdataByFtypeidAndRid(ftypeId, rid, tableCode=FDATA2, order=FWD_ORDER)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = FTYPE_RID_GROUPED_SELECT_SQL.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  LOCATION_BY_FIDS_SQL = "select gname, rid, fstart, fstop, ftypeid, fscore, fstrand from %table% where fid in {fidSet} "
  def selectLocationsByFids(fids, tableCode=FDATA2, order=nil)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = LOCATION_BY_FIDS_SQL.dup
      # Set the specific table
      sql = sql.gsub(/%table%/, FDATA_HASH[tableCode])
      #sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      fidSet = DBUtil.makeMysql2SetStr(fids)
      sql = sql.gsub(/\{fidSet\}/, fidSet)
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_DISTINCT_RIDS_SQL = "select distinct fdata2.rid, refname, rlength from fdata2, fref where fdata2.ftypeid = '{ftypeId}' and fref.rid = fdata2.rid "
  def selectDistinctRidsByFtypeId(ftypeId, sortByrefname=true)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DISTINCT_RIDS_SQL.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      sql << " order by fref.refname " if(sortByrefname)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_DISTINCT_RIDS_SQL_BY_FTYPEID_AND_GNAME = "select distinct fdata2.rid, refname, rlength from fdata2, fref where fdata2.ftypeid = '{ftypeId}' and fdata2.gname = '{gname}' and fref.rid = fdata2.rid "
  def selectDistinctRidsByFtypeIdAndGname(ftypeId, gname, sortByrefname=true)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DISTINCT_RIDS_SQL_BY_FTYPEID_AND_GNAME.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{gname\}/, mysql2gsubSafeEsc(gname.to_s))
      sql << " order by fref.refname " if(sortByrefname)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select annotation data by start/stop locations
  #
  # Uses the Binning class to construct query that takes advantage of rtree
  # Searching by landmark also requires rid and ftypeid
  #
  # WARNING: This method may return MANY rows. use eachBlockOfFdataByLandmark to control this
  #
  # [+rid+]         Id of the entrypoint, fref.rid
  # [+ftypeid+]     Id of the track, ftype.ftypeid
  # [+start+]       The start location of the desired range
  # [+stop+]        The stop location of the desired range
  # [+columns+]     The columns that will be select from fdata2, default is *
  # [+order+]       The sort order of the results, 0 => ASC, 1 => DESC
  # [+returns+]     Array of fdata2 Row objects
  SELECT_FDATA_BY_LANDMARK = "select %columns% from fdata2 where rid = '{rid}' and ftypeid = '{ftypeId}' and %binClause% and fstop >= '{start}' and fstart <= '{stop}'"
  def selectFdataByLandmark(rid, ftypeId, start, stop, columns='*', order=FWD_ORDER)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      binner = BRL::SQL::Binning.new()
      columns = columns.join(', ') if(columns.is_a?(Array))
      sql = SELECT_FDATA_BY_LANDMARK.gsub(/%columns%/, columns) # <= do not escape, should support column lists like "*" and csv strings of columns etc
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql = sql.gsub(/%binClause%/, binClause)
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql = sql.gsub(/\{stop\}/, mysql2gsubSafeEsc(stop.to_s)).gsub(/\{start\}/, mysql2gsubSafeEsc(start.to_s))
      sql << (order==FWD_ORDER ? ' order by fdata2.fstart, fdata2.fstop ' : ' order by fdata2.fstop DESC, fdata2.fstart DESC ')
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end



  SELECT_AVPS_BY_FIDS =   "select fid, name, value from fid2attribute, attNames, attValues
                          where fid2attribute.attNameId = attNames.attNameId and fid2attribute.attValueId = attValues.attValueId and
                          attNames.name in %ATTR_NAMES% and fid2attribute.fid in %FIDS%"
  def selectAVPsByFids(attrNames, fids, tableCode=FDATA2)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_AVPS_BY_FIDS.gsub(/%table%/, FDATA_HASH[tableCode])
      attrNamesSqlSetStr = DBUtil.makeMysql2SetStr(attrNames)
      fidsSqlSetStr = DBUtil.makeMysql2SetStr(fids)
      sql = sql.gsub(/%ATTR_NAMES%/, attrNamesSqlSetStr)
      sql = sql.gsub(/%FIDS%/, fidsSqlSetStr)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SELECT_ALL_AVPS_BY_FIDS = "SELECT fid, name, value FROM fid2attribute f2a, attNames, attValues WHERE f2a.attNameId = attNames.attNameId AND f2a.attValueId = attValues.attValueId AND f2a.fid IN %FIDS% "
  def selectAllAVPsByFids(fids, tableCode=FDATA2)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_AVPS_BY_FIDS.gsub(/%table%/, FDATA_HASH[tableCode])
      fidsSqlSetStr = DBUtil.makeMysql2SetStr(fids)
      sql = sql.gsub(/%FIDS%/, fidsSqlSetStr)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  def insertFdata(rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, ftarget_start, ftarget_stop, gname, displayCode, displayColor, groupContextCode)
    data = [rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, ftarget_start, ftarget_stop, gname, displayCode, displayColor, groupContextCode ]
    return insertFdatas(data, 1)
  end

  def insertFdatas(data, numFdatas)
    return insertRecords(:userDB, 'fdata2', data, true, numFdatas, 14, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def deleteFdata2RecByFid(fid)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = "delete from fdata2 where fid = #{Mysql2::Client.escape(fid.to_s)}"
      client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end
  # --------
  # Table: attNames
  # --------  # ############################################################################
  # METHODS
  # ############################################################################
  def countAttributes()
    return countRecords(:userDB, 'attNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectAllAttributes(maxNum=nil)
    extraOpts = ( (maxNum.nil?) ? nil : { :simpleLimit => maxNum, :orderBy => [ name ] } )
    return selectAll(:userDB, 'attNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", extraOpts)
  end

  def selectAllAttNames()
    return selectAll(:userDB, 'attNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectAttributesByName(attName, useLike=false)
    retVal = nil
    if(useLike)
      retVal = selectByFieldAndKeyword(:userDB, 'attNames', 'name', attName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    else
      retVal = selectByFieldAndValue(:userDB, 'attNames', 'name', attName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    return retVal
  end

  def selectAttributesByIds(attNameIds)
    return selectByFieldWithMultipleValues(:userDB, 'attNames', 'attNameId', attNames, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: attValues
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def countAttValues()
    return countRecords(:userDB, 'attValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectAllAttValues()
    return selectAllFields(:userDB, 'attValues', [ ' attValueId', 'value' ], false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectValuesByText(text, useLike=false)
    retVal = nil
    if(useLike)
      retVal = selectByFieldAndKeyword(:userDB, 'attValues', 'value', text, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    else
      retVal = selectByFieldAndValue(:userDB, 'attValues', 'value', text, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    return retVal
  end

  def selectValueByMD5(md5)
    return selectByFieldAndKeyword(:userDB, 'attValues', 'md5', md5, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectValueViaMD5(text)
    digest = MD5.hexdigest(text)
    return selectByFieldAndKeyword(:userDB, 'attValues', 'md5', digest, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def loadDataWithFileInAttValues(filePath, replace=false, ignoreDup=false)
    retVal = sql = nil
    begin
      raise "Cannot have both replace and ignoreDup as true." if(replace and ignoreDup)
      doReplace = replace ? "replace" : ""
      ignoreDuplicate = ignoreDup ? "ignore" : ""
      sql = "load data local infile '#{filePath}' #{doReplace} #{ignoreDuplicate} into table attValues fields terminated by '\t' (@col1) set value = @col1, md5 = md5(@col1) "
      client = getMysql2Client(:userDB)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.loadDataWithFileInAttValues()", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: fid2attribute
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def countFid2Attribute()
    return countRecords(:userDB, 'fid2attribute', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_ATTNAMEIDS_AND_ATTVALUEIDS_BY_FID_AND_ATTNAMEIDS = "select attNameId, attValueId from fid2attribute where fid2attribute.fid = '{fid}' and fid2attribute.attNameId in {attNameIdSet}"
  def selectAttNameIdsAndAttValueIdsByFidAndAttNameIds(fid, attNameIds)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_ATTNAMEIDS_AND_ATTVALUEIDS_BY_FID_AND_ATTNAMEIDS.dup
      sql = sql.gsub(/\{fid\}/, mysql2gsubSafeEsc(fid.to_s))
      attNameIdSet = DBUtil.makeMysql2SetStr(attNameIds)
      sql = sql.gsub(/\{attNameIdSet\}/, attNameIdSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_ATTNAMEID_AND_ATTNAME_BY_FTYPEID = "select attNames.attNameId, attNames.name from ftype2attributeName, attNames where attNames.attNameId = ftype2attributeName.attNameId and ftype2attributeName.ftypeid = '{ftypeId}' "
  def selectAttNameIdAndAttNameByFtypeId(ftypeId)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_ATTNAMEID_AND_ATTNAME_BY_FTYPEID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_FIDS_AND_ATTNAMEIDS_AND_ATTVALUENAMES_BY_FIDS_AND_ATTNAMEIDS =
    " select fid2attribute.fid, fid2attribute.attNameId, attValues.value from fid2attribute, attValues
      where fid2attribute.attValueId = attValues.attValueId
      and fid2attribute.attNameId in {attNameIdSet} and fid2attribute.fid in {fidSet} "
  def selectFidsAttNameIdAndAttValueNamesByFidsAndAttNameIds(fids, attNameIds)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FIDS_AND_ATTNAMEIDS_AND_ATTVALUENAMES_BY_FIDS_AND_ATTNAMEIDS.dup
      attNameIdSet = DBUtil.makeMysql2SetStr(attNameIds)
      fidSet = DBUtil.makeMysql2SetStr(fids)
      sql = sql.gsub(/\{attNameIdSet\}/, attNameIdSet).gsub(/\{fidSet\}/, fidSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SELECT_ATTNAMEIDS_AND_ATTVALUENAMES_BY_FID_AND_ATTNAMEIDS =
    " select fid2attribute.attNameId, attValues.value from fid2attribute, attValues
      where fid2attribute.fid = '{fid}'
      and fid2attribute.attValueId = attValues.attValueId
      and fid2attribute.attNameId in {attNameIdSet} "
  def selectAttNameIdsAndAttValueNamesByFidAndAttNameIds(fid, attNameIds)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_ATTNAMEIDS_AND_ATTVALUENAMES_BY_FID_AND_ATTNAMEIDS.dup
      sql = sql.gsub(/\{fid\}/, mysql2gsubSafeEsc(fid.to_s))
      attNameIdSet = DBUtil.makeMysql2SetStr(attNameIds)
      sql = sql.gsub(/\{attNameIdSet\}/, attNameIdSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_ATTVALUE_BY_FID_AND_ATTNAMEID = "select attValues.value from attValues, fid2attribute where fid2attribute.fid = '{fid}' and fid2attribute.attNameId = '{attNameId}' and fid2attribute.attValueId = attValues.attValueId "
  def selectAttValueByFidAndAttNameId(fid, attNameId, maxNum=nil)
    client = retVal = extraOpts = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_ATTVALUE_BY_FID_AND_ATTNAMEID.dup
      sql = sql.gsub(/\{fid\}/, mysql2gsubSafeEsc(fid.to_s)).gsub(/\{attNameId\}/, mysql2gsubSafeEsc(attNameId.to_s))
      sql << " limit #{maxNum} " unless(maxNum.nil?)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_ATTNAME_ATTVALUE_BY_FID = "select attNames.name, attValues.value from attValues, attNames, fid2attribute where fid2attribute.fid = '{fid}' and fid2attribute.attNameId = attNames.attNameId and fid2attribute.attValueId = attValues.attValueId"
  def selectAttNameAttValueByFid(fid, maxNum=nil)
    client = retVal = extraOpts = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = SELECT_ATTNAME_ATTVALUE_BY_FID.dup
      sql = sql.gsub(/\{fid\}/, mysql2gsubSafeEsc(fid.to_s))
      sql << " limit #{maxNum} " unless(maxNum.nil?)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  F2A_FOR_ATTR_VALUE_SQL = "select fid from fid2attribute where attNameId = '{attNameId}' and attValueId = '{attValueId}' "
  def selectFidsByAttrValue(attrId, valueId, maxNum=nil)
    client = retVal = extraOpts = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = F2A_FOR_ATTR_VALUE_SQL.dup
      sql = sql.gsub(/\{attNameId\}/, mysql2gsubSafeEsc(attrId.to_s)).gsub(/\{attValueId\}/, mysql2gsubSafeEsc(valueId.to_s))
      sql << " limit #{maxNum} " unless(maxNum.nil?)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  F2A_FOR_ATTR_VALUE_FTYPE_SQL = "select fid2attribute.fid from fid2attribute,fdata2 where fdata2.ftypeid = '{ftypeId}' and fdata2.fid = fid2attribute.fid and fid2attribute.attNameId = '{attNameId}' and fid2attribute.attValueId = '{attValueId}' "
  def selectFidsByAttrValueFtype(attrId, valueId, ftypeId, maxNum=nil)
    client = retVal = extraOpts = nil
    begin
      client = getMysql2Client(:userDB)                                 # Lazy connect to data database
      sql = F2A_FOR_ATTR_VALUE_SQL.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{attValueId\}/, mysql2gsubSafeEsc(valueId.to_s)).gsub(/\{attNameId\}/, mysql2gsubSafeEsc(attrId.to_s))
      sql << " limit #{maxNum} " unless(maxNum.nil?)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  F2A_CLEAN_ORPHANS_SQL = "delete low_priority from fid2attribute where not exists(select null from fdata2 where fdata2.fid = fid2attribute.fid) limit 10000"
  def cleanFid2AttributeOrphans()
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
        client.query(F2A_CLEAN_ORPHANS_SQL, :cast_booleans => true)
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
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, F2A_CLEAN_ORPHANS_SQL)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # ---------
  # Table: blockLevelDataInfo
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def insertBlockLevelDataInfoRecords(data, numRecords)
    return insertRecords(:userDB, 'blockLevelDataInfo', data, true, numRecords, 13, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectBlockLevelDataInfoByFid(fid)
    return selectByFieldAndValue(:userDB, 'blockLevelDataInfo', 'fid', fid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
  alias selectBlockLevelDataInfoRecordByFid selectBlockLevelDataInfoByFid

  def selectBlockLevelDataInfoRecordsByFileName(fileName)
    return selectByFieldAndValue(:userDB, 'blockLevelDataInfo', 'fileName', fileName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectNumRecordCountByFtypeId(ftypeId)
    return selectFieldsByFieldAndValue(:userDB, 'blockLevelDataInfo', [ 'sum(numRecords) as numRecordCount' ], false, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectBlockLevelDataExistsForFtypeId(ftypeId)
    return selectFieldsByFieldAndValue(:userDB, 'blockLevelDataInfo', [ '1' ], false, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", { :simpleLimit => 1 })
  end

  def selectMaxFstopFromBlockLevelDataForRidAndFtypeId(rid, ftypeId)
    return selectFieldsByMultipleFieldsAndValues(:userDB, 'blockLevelDataInfo', [ 'max(fstop) as maxFstop' ], false, { 'rid' => rid, 'ftypeid' => ftypeId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectDistinctFileNamesByFtypeId(ftypeId)
    return selectFieldsByFieldAndValue(:userDB, 'blockLevelDataInfo', [ 'fileName' ], true, 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_BLOCKLEVELDATAINFO_BY_FTYPEID_AND_RID = "select * from blockLevelDataInfo where ftypeid = '{ftypeId}' and rid = '{rid}' order by fileName, offset "
  def selectBlockLevelDataInfoByFtypeIdAndRid(ftypeId, rid, blockSize=10000)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_BLOCKLEVELDATAINFO_BY_FTYPEID_AND_RID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql << " limit {offset}, #{blockSize}"
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select annotation data by start/stop locations
  #
  # Uses the Binning class to construct query that takes advantage of rtree
  # Searching by landmark also requires rid and ftypeid
  #
  # [+rid+]         Id of the entrypoint, fref.rid
  # [+ftypeid+]     Id of the track, ftype.ftypeid
  # [+start+]       The start location of the desired range
  # [+stop+]        The stop location of the desired range
  # [+order+]       The sort order of the results, 0 => ASC, 1 => DESC
  # [+blockSize+]   The number of records returned per enumeration
  # [+block+]       block arg
  # [+returns+]     nil
  def eachBlockOfBlockLevelDataInfoByLandmark(rid, ftypeid, start, stop, blockSize=10_000, raiseErr=false)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "select * from blockLevelDataInfo
              where rid = #{mysql2gsubSafeEsc(rid.to_s)}
              and ftypeid = #{mysql2gsubSafeEsc(ftypeid.to_s)}
              and %binClause%
              and fstop >= #{mysql2gsubSafeEsc(start.to_s)}
              and fstart <= #{mysql2gsubSafeEsc(stop.to_s)}
              order by fileName, offset "
      binner = BRL::SQL::Binning.new()
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql.gsub!(/%binClause%/, binClause)
      sql << " limit {offset}, #{blockSize}"
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
      raise @err if(@err and raiseErr)
    end
    return
  end

  def eachBlockOfBlockLevelDataInfoByLandmarkOrderedByCoord(rid, ftypeid, start, stop, blockSize=10_000, raiseErr=false)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = " select * from blockLevelDataInfo
              where rid = #{mysql2gsubSafeEsc(rid.to_s)}
              and ftypeid = #{mysql2gsubSafeEsc(ftypeid.to_s)}
              and %binClause%
              and fstop >= #{mysql2gsubSafeEsc(start.to_s)}
              and fstart <= #{mysql2gsubSafeEsc(stop.to_s)}
              order by fstart, fstop "
      binner = BRL::SQL::Binning.new()
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql.gsub!(/%binClause%/, binClause)
      sql << " limit {offset}, #{blockSize}"
      offset = 0
      loop {
        loopSql = sql.gsub(/\{offset\}/, offset.to_s)  # keep main sql unmodified as we loop, so as to replace {offset} each time
        resultSet = client.query(loopSql, :cast_booleans => true)
        retVal = resultSet.entries
        break if(retVal.nil? or retVal.empty?)
        yield(retVal)
        break if(retVal.size < blockSize) # Shortcut to prevent obvious no-op SQL select at end
        offset += blockSize
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
      raise @err if(@err and raiseErr)
    end
    return
  end

  SELECT_BLOCKLEVELDATAINFO_BY_LANDMARK_ORDERED_BY_COORD = "select * from blockLevelDataInfo where rid = '{rid}' and ftypeid = '{ftypeId}' and %binClause% and fstop >= '{start}' and fstart <= '{stop}' order by fstart, fstop"
  def selectBlockLevelDataInfoRecordsByLandmark(rid, ftypeId, start, stop)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_BLOCKLEVELDATAINFO_BY_LANDMARK_ORDERED_BY_COORD.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql = sql.gsub(/\{stop\}/, mysql2gsubSafeEsc(stop.to_s)).gsub(/\{start\}/, mysql2gsubSafeEsc(start.to_s))
      binner = BRL::SQL::Binning.new()
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql.gsub!(/%binClause%/, binClause)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_BLOCKLEVELDATAINFO_FOR_FID_BETWEEN = "select * from blockLevelDataInfo where fid >= '{minFid}' and fid <= '{maxFid}' "
  def selectBlockLevelDataInfoForFidBetween(minFid, maxFid)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_BLOCKLEVELDATAINFO_BY_LANDMARK_ORDERED_BY_COORD.dup
      sql = sql.gsub(/\{minFid\}/, mysql2gsubSafeEsc(minFid.to_s)).gsub(/\{maxFid\}/, mysql2gsubSafeEsc(maxFid.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_DISTINCT_RIDS_BLOCKLEVEL_SQL = "select distinct blockLevelDataInfo.rid, refname, rlength from blockLevelDataInfo, fref where blockLevelDataInfo.ftypeid = '{ftypeId}' and fref.rid = blockLevelDataInfo.rid "
  def selectDistinctRidsByFtypeIdForBlockLevelData(ftypeId, sortByrefname=true)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DISTINCT_RIDS_BLOCKLEVEL_SQL.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      sql << " order by fref.refname" if(sortByrefname)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Replaces records for blockLevelDataInfo table
  # [+data+] array of records to replace
  # [+numRecords+] number of records to replace
  def replaceBlockLevelDataInfoRecords(data, numRecords)
    return replaceRecords(:userDB, 'blockLevelDataInfo', data, numRecords, 14, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: zoomLevels
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  # to check if the track has any zoom level records
  def checkIfTrackHasZoomInfo(ftypeId)
    return selectByFieldAndValue(:userDB, 'zoomLevels', 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", { :simpleLimit => 10 })
  end

  # Gets all records from zoomLevels table for a a particular chromosome
  # [+rid+]
  # [+ftypeId+]
  # [+returns+] Array of row objects
  def selectZoomLevelsByRidAndFtypeid(rid, ftypeId)
    return selectByMultipleFieldsAndValues(:userDB, 'zoomLevels', { 'rid' => rid, 'ftypeid' => ftypeId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Inserts 'numRecords' records in zoomLevels table
  # [+data+] an array or an array of arrays
  # [+numRecords+] number of records
  # [+returns+] number of records inserted
  def insertZoomLevelRecords(data, numRecords)
    return insertRecords(:userDB, 'zoomLevels', data, true, numRecords, 14, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Replaces records for zoomLevels table
  # [+data+] array of records to replace
  # [+numRecords+] number of records to replace
  def replaceZoomLevelRecords(data, numRecords)
    return replaceRecords(:userDB, 'zoomLevels', data, numRecords, 15, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertOnDuplicateUpdateZoomLevels(data, numRecords, columnN)
    insertOnDuplicateKey(tableType, tableName, data, true, numRecords, 14, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", columnNames, columnValues)
  end

  # Gets zoom Level recs by rid, ftypeId, fstart and fstop ordered by fstart and fstop
  # [+rid+] rid (entrypoint)
  # [+ftypeId+]
  # [+level+] zoomLevel (4 or 5)
  # [+fstart+] start coordinate
  # [+fstop+] end coordinate
  # [+return+] retVal DBI:row object
  SELECT_ZOOM_LEVELS_BY_RID_FTYPEID_LEVEL_FSTART_FSTOP_ORDERED_BY_COORDS =
    " select * from zoomLevels
      where rid = '{rid}'
      and ftypeid = '{ftypeId}'
      and level = '{level}'
      and %binClause%
      and fstop >= '{start}'
      and fstart <= '{stop}'
      order by fstart, fstop "
  def getZoomLevelsByRidAndFtypeIdAndLevelAndFstartAndFstopOrderedByCoords(rid, ftypeId, level, start, stop)
    retVal = nil
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ZOOM_LEVELS_BY_RID_FTYPEID_LEVEL_FSTART_FSTOP_ORDERED_BY_COORDS.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{rid\}/, mysql2gsubSafeEsc(rid.to_s))
      sql = sql.gsub(/\{stop\}/, mysql2gsubSafeEsc(stop.to_s)).gsub(/\{start\}/, mysql2gsubSafeEsc(start.to_s))
      sql = sql.gsub(/\{level\}/, mysql2gsubSafeEsc(level.to_s))
      binner = BRL::SQL::Binning.new()
      binClause = binner.makeBinSQLWhereExpression(start, stop)
      sql.gsub!(/%binClause%/, binClause)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
