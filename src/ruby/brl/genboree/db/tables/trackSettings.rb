require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# TRACK-SETTINGS (display mostly) RELATED TABLES - DBUtil Extension Methods for dealing with Track-Display-Settings-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: featuretolink
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_LINK_BY_USERID_FTYPEID = 'select l.*
                                    from featuretolink ftl, link l
                                    where l.linkId = ftl.linkId
                                    and ftl.ftypeid = ? and ftl.userId = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  def selectLinksByFtypeIdUserId(fTypeId, userId)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_LINK_BY_USERID_FTYPEID)
      stmt.execute(fTypeId, userId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectLinksByFtypeIdUserId():", @err, SELECT_LINK_BY_USERID_FTYPEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: featuretostyle
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_STYLE_BY_USERID_FTYPEID = 'select s.*
                                    from featuretostyle fts, style s
                                    where s.styleId = fts.styleId
                                    and fts.ftypeid = ? and fts.userId = ?'
  SELECT_STYLE_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, style.description
                                          from featuretostyle
                                          left join style on style.styleId = featuretostyle.styleId
                                          left join ftype on ftype.ftypeid = featuretostyle.ftypeid where userId = '
  SELECT_STYLE_MAP_NAME_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, style.name
                                          from featuretostyle
                                          left join style on style.styleId = featuretostyle.styleId
                                          left join ftype on ftype.ftypeid = featuretostyle.ftypeid where userId = '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectStyleByFtypeIdUserId(fTypeId, userId)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_STYLE_BY_USERID_FTYPEID)
      stmt.execute(fTypeId, userId)
      retVal = stmt.fetch()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectStyleByFtypeIdUserId():", @err, SELECT_STYLE_BY_USERID_FTYPEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get all track styles as a trackName => long style name mapping table for a given userId.
  # Can optionally filter for specific trackNames.
  # **GOOD FOR CACHING IN CODE, because tracks*styles is typically small**
  def selectTracksStyleMap(userId, trackNames=nil)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_STYLE_MAP_FOR_TRACKS_AND_USER.dup
      sql << " #{userId} "
      unless(trackNames.nil?)
        sql << ' and concat(ftype.fmethod, ":", ftype.fsource) in ('
        cc = 0
        trackNames.each { |trk|
          if(cc == 0)
            sql << "'#{client.escape(trk)}'"
          else
            sql << ",'#{client.escape(trk)}'"
          end
          cc = 1
        }
        sql << ")"
      end
      # get all results
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksStyleMap():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  def selectTracksStyleNameMap(userId, trackNames=nil)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_STYLE_MAP_NAME_FOR_TRACKS_AND_USER.dup
      sql << " #{userId} "
      unless(trackNames.nil?)
        sql << ' and concat(ftype.fmethod, ":", ftype.fsource) in ('
        cc = 0
        trackNames.each { |trk|
          if(cc == 0)
            sql << "'#{client.escape(trk)}'"
          else
            sql << ",'#{client.escape(trk)}'"
          end
          cc = 1
        }
        sql << ")"
      end
      # get all results
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksStyleMap():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  def deleteFeaturetoStyleRecsByUserId(userId)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "delete from featuretostyle where userId = #{userId}"
      client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteFeaturetoStyleRecsByUserId():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  # --------
  # Table: featuretocolor
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_COLOR_BY_USERID_FTYPEID = 'select c.* from featuretocolor ftc, color c where c.colorId = ftc.colorId and ftc.ftypeid = ? and ftc.userId = ?'
  SELECT_COLOR_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, color.value
                                          from featuretocolor
                                          left join color on color.colorId = featuretocolor.colorId
                                          left join ftype on ftype.ftypeid = featuretocolor.ftypeid where userId = '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectColorByFtypeIdUserId(fTypeId, userId)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_COLOR_BY_USERID_FTYPEID)
      stmt.execute(fTypeId, userId)
      retVal = stmt.fetch()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectColorByFtypeIdUserId():", @err, SELECT_COLOR_BY_USERID_FTYPEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get all track colors as a trackName => #hexColor  mapping table for a given userId.
  # Can optionally filter for specific trackNames.
  # **GOOD FOR CACHING IN CODE, because tracks*colors is typically small**
  def selectTracksColorMap(userId, trackNames=nil)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_COLOR_MAP_FOR_TRACKS_AND_USER.dup
      sql << " #{userId} "
      unless(trackNames.nil?)
        sql << ' and concat(ftype.fmethod, ":", ftype.fsource) in ('
        cc = 0
        trackNames.each { |trk|
          if(cc == 0)
            sql << "'#{client.escape(trk)}'"
          else
            sql << ",'#{client.escape(trk)}'"
          end
          cc = 1
        }
        sql << ")"
      end
      # get all results
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksColorMap():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  def deleteFeaturetoColorRecsByUserId(userId)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "delete from featuretocolor where userId = #{userId}"
      client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteFeaturetoColorRecsByUserId():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  # --------
  # Table: featuresort
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_ORDER_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featuresort.sortKey
                                          from featuresort
                                          left join ftype on ftype.ftypeid = featuresort.ftypeid where userId = '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectTracksOrderMap(userId, trackNames=nil)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ORDER_MAP_FOR_TRACKS_AND_USER.dup
      sql << " #{userId} "
      unless(trackNames.nil?)
        sql << ' and concat(ftype.fmethod, ":", ftype.fsource) in ('
        cc = 0
        trackNames.each { |trk|
          if(cc == 0)
            sql << "'#{client.escape(trk)}'"
          else
            sql << ",'#{client.escape(trk)}'"
          end
          cc = 1
        }
        sql << ")"
      end
      # get all results
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksOrderMap():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  def deleteFeatureSortRecsByUserId(userId)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "delete from featuresort where userId = #{userId}"
      client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteFeatureSortRecsByUserId():", @err, sql)
    ensure
      client.close() rescue nil
    end
    return retVal
  end

  # --------
  # Table: Color
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_ALL_COLORS = 'select * from color'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllColors()
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_COLORS.dup
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: Style
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_ALL_STYLES = 'select * from style'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllStyles()
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_STYLES.dup
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end


  # --------
  # Table: featuredisplay
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectDisplayByFtypeIdUserId(fTypeId, userId)
    return selectByMultipleFieldsAndValues(:userDB, 'featuredisplay', {'ftypeid'=>fTypeId, 'userId'=>userId}, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: featuresort
  # --------
  SELECT_RANK_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featuresort.sortkey
                                          from featuresort
                                          left join ftype on ftype.ftypeid = featuresort.ftypeid where userId = ? '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectSortByFtypeIdUserId(fTypeId, userId)
    return selectByMultipleFieldsAndValues(:userDB, 'featuresort', {'ftypeid'=>fTypeId, 'userId'=>userId}, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all track ranks as a trackName => sortkey  mapping table for a given userId.
  # Can optionally filter for specific trackNames.
  # **GOOD FOR CACHING IN CODE, because tracks*colors is typically small**
  def selectTracksRankMap(userId, trackNames=nil)
    retVal = nil
    begin
      connectToDataDb()
      sql = SELECT_RANK_MAP_FOR_TRACKS_AND_USER.dup
      unless(trackNames.nil?)
        sql << ' and concat(ftype.fmethod, ":", ftype.fsource) in '
        sql << DBUtil.makeSqlSetStr(trackNames.size)
      end
      stmt = @dataDbh.prepare(sql)
      # execute with appropriate args to fill in bind slots
      if(trackNames.nil?)
        stmt.execute(userId)
      else
        stmt.execute(userId, trackNames)
      end
      # get all results
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksRankMap():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: featureurl
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_ALL_FEATUREURL_SQL = 'select * from featureurl '
  SELECT_FEATURERUL_BY_FTYPEID = 'select * from featureurl where ftypeid = ? '
  UPDATE_DESC_FOR_FYTPEID = 'update featureurl set description = ? where ftypeid = ? '
  SELECT_DESC_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featureurl.description
                                          from featureurl
                                          left join ftype on ftype.ftypeid = featureurl.ftypeid '
  SELECT_DESC_URL_LABEL_MAP_FOR_TRACKS_AND_USER = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featureurl.url, featureurl.description, featureurl.label
                                          from featureurl
                                          left join ftype on ftype.ftypeid = featureurl.ftypeid '
  SELECT_FEATURERUL_BY_FTYPEIDS = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featureurl.url, featureurl.description, featureurl.label from ftype, featureurl where ftype.ftypeid = featureurl.ftypeid and ftype.ftypeid in  '
  SELECT_DESCRIPTION_BY_FTYPEIDS = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, featureurl.description from ftype, featureurl where ftype.ftypeid = featureurl.ftypeid and ftype.ftypeid in  '
  INSERT_FEATUREURL_ON_DUP_KEY_UPDATE = "insert into featureurl values (?, ?, ?, ?) on duplicate key update url=values(url), description=values(description), label=values(label) "
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllFeatureurl()
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_ALL_FEATUREURL_SQL)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectAllFeatureurl():", @err, SELECT_ALL_FEATUREURL_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get all track descriptions as a trackName => description mapping table.
  # Can optionally filter for specific trackNames.
  # **GOOD FOR CACHING IN CODE, because tracks*desc is typically small**
  def selectTracksDescMap(trackNames=nil, includeUrlAndLabel=false)
    retVal = nil
    begin
      connectToDataDb()
      sql = nil
      unless(includeUrlAndLabel)
        sql = SELECT_DESC_MAP_FOR_TRACKS_AND_USER.dup
      else
        sql = SELECT_DESC_URL_LABEL_MAP_FOR_TRACKS_AND_USER.dup
      end
      unless(trackNames.nil? or trackNames.empty?)
        sql << ' where concat(ftype.fmethod, ":", ftype.fsource) in '
        sql << "("
        lastIdx = trackNames.size - 1
        trackNames.size.times { |ii|
          if( ii == lastIdx )
            sql << "\"#{Mysql2::Client.escape(trackNames[ii])}\""
          else
            sql << "\"#{Mysql2::Client.escape(trackNames[ii])}\","
          end
        }
        sql << ")"
      end
      stmt = @dataDbh.prepare(sql)
      stmt.execute()
      # get all results
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectTracksDescMap():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectFeatureurlByFtypeId(ftypeId)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_FEATURERUL_BY_FTYPEID)
      stmt.execute(ftypeId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectFeatureurlByFtypeId():", @err, SELECT_FEATURERUL_BY_FTYPEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectFeatureurlByFtypeIds(ftypeIdList)
    retVal = nil
    return retVal if(ftypeIdList.nil?)
    ftypeIdList = [ftypeIdList] if(!ftypeIdList.is_a?(Array))
    begin
      connectToDataDb()             # Lazy connect to data database
      sql = SELECT_FEATURERUL_BY_FTYPEIDS.dup()
      sql << DBUtil.makeSqlSetStr(ftypeIdList.size)
      stmt = @dataDbh.prepare(sql)
      stmt.execute(*ftypeIdList)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectFeatureurlByFtypeIds():", @err, SELECT_FEATURERUL_BY_FTYPEIDS)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def selectDescriptionByFtypeIds(ftypeIdList)
    retVal = nil
    return retVal if(ftypeIdList.nil?)
    ftypeIdList = [ftypeIdList] if(!ftypeIdList.is_a?(Array))
    begin
      connectToDataDb()             # Lazy connect to data database
      sql = SELECT_DESCRIPTION_BY_FTYPEIDS.dup()
      sql << DBUtil.makeSqlSetStr(ftypeIdList.size)
      stmt = @dataDbh.prepare(sql)
      stmt.execute(*ftypeIdList)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectFeatureurlByFtypeIds():", @err, SELECT_FEATURERUL_BY_FTYPEIDS)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateDescriptionByFtypeId(ftypeId, description)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_DESC_FOR_FYTPEID)
      stmt.execute(description, ftypeId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.updateDescriptionByFtypeId(): ", @err, UPDATE_DESC_FOR_FYTPEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateFeatureurlByFtypeId(ftypeId, updateData)
    return updateByFieldAndValue(:userDB, 'featureurl', updateData, 'ftypeid', ftypeId, 'ERROR: #{self.class}##{__method__}()')
  end

  def insertFeatureurl(ftypeId, url, description, label)
    return insertRecords(:userDB, 'featureurl', [ftypeId, url, description, label], false, 1, 4, false, 'ERROR: #{self.class}##{__method__}()')
  end

  def insertFeatureUrlOnDupKeyUpdate(ftypeid, url, description, label)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_FEATUREURL_ON_DUP_KEY_UPDATE)
      stmt.execute(ftypeid, url, description, label)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.insertFeatureUrlOnDupKeyUpdate(): ", @err, INSERT_FEATUREURL_ON_DUP_KEY_UPDATE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal

  end

end # class DBUtil
end ; end # module BRL ; module Genboree
