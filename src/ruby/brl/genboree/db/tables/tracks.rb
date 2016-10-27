require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# FTYPE RELATED TABLES - DBUtil Extension Methods for dealing with Ftype-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: ftype
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Ftype records
  # [+returns+] Array of 0+ ftype record rows
  def countFtypes()
    return countRecords(:userDB, "ftype", "ERROR: [#{File.basename($0)}] DBUtil#countFtypes():")
  end

  # Is this a high-density storage track (as opposed to regular fdata2-backed track)
  # [+trackId+] Either an ftypeId (Integer) or a track name (String).
  # [+raises+]  ArgumentError if no such track name in the user db.
  # [+returns+] true if the track is an HDHV track, false otherwise
  def isHDHV?(trackId)
    valueRecs = self.getTrackRecordType(trackId)
    return (valueRecs.size > 0)
  end

  # Get the track data type (gbTrackRecordType attribute's value) for the given track.
  # This is only set for HDHV tracks and tells the type of track.
  # [+trackId+] Either an ftypeId (Integer) or a track name (String)
  # [+raises+]  ArgumentError if no such track name in the user db.
  # [+returns+] Array with 1 record with just the value column or with no records (non-HDHV track)
  def getTrackRecordType(trackId)
    ftypeId = trackId
    # Get ftypeId for trackId if necessary
    if(trackId.is_a?(String)) # then got a track:name
      ftypeRecs = DBUtil.selectFtypeByTrackName(trackId)
      if(ftypeRecs.size > 0)
        ftypeId = ftypeRecs.first["ftypeId"]
      else  # no ftype records with that track name
        raise ArgumentError, "ERROR: [#{File.basename($0)}] no tracks named #{trackId.inspect} found."
      end
    end
    # Get track data type (gbTrackDataType attribute's value)
    return selectFtypeAttrValueByFtypeIdAndAttrNameText(ftypeId, "gbTrackRecordType")
  end

  ALL_FTYPES_SQL = "select * from ftype "
  def selectAllFtypes(noComponents=true, includePartialEntities=false)
    retVal = sql = nil
    begin
      client = getMysql2Client(:userDB)
      sql = ALL_FTYPES_SQL.dup
      if(noComponents)
        sql +=  "where (ftype.fmethod != 'Component' and ftype.fsource != 'Chromosome') and " +
                "(ftype.fmethod != 'Supercomponent' and ftype.fsource != 'Sequence') "
      end
      unless(includePartialEntities)
        sql << " and ftype.ftypeid NOT IN (select ftype.ftypeid from ftype, ftype2attributes, ftypeAttrNames,
          ftypeAttrValues where ftypeAttrNames.name = 'gbPartialEntity' and ftypeAttrValues.value = true and
          ftype.ftypeid = ftype2attributes.ftype_id and ftypeAttrNames.id = ftype2attributes.ftypeAttrName_id and
          ftypeAttrValues.id = ftype2attributes.ftypeAttrValue_id) "
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

  def selectFtypeByTrackName(trackName)
    lffType, lffSubtype = trackName.split(/:/)
    return selectByMultipleFieldsAndValues(:userDB, 'ftype', { 'fmethod' => lffType, 'fsource' => lffSubtype }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectFtypesByIds(ftypeids)
    return selectByFieldWithMultipleValues(:userDB, 'ftype', 'ftypeid', ftypeids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Ftypes using a list of trackn ames
  # [+names+]   Array of unique ftype names (fmethod:fsource)
  # [+returns+] Array of 0+ ftype records
  def selectFtypesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, "ftype", "concat(fmethod, ':', fsource)", names, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypesByNames():")
  end

  # Get Ftypes by matching an AVP by ids; get all ftypes [in _this_ database only] possessing the attribute and its value
  # indicated by +ftypeAttrNameId+ whose value is +ftypeAttrValueId+.
  # [+ftypeAttrNameId+]   ftypeAttrNames.id for the ftype attribute to consider
  # [+ftypeAttrValueId+]  ftypeAttrValues.id for the ftype attribute value to match
  # [+returns+]           Array of 0+ ftype records
  def selectFtypesByAttributeNameAndValueIds(ftypeAttrNameId, ftypeAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, "ftype", ftypeAttrNameId, ftypeAttrValueId, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypesByAttributeNameAndValueIds():")
  end

  # Get Ftypes by matching an AVP by text; get all ftypes [in _this_ database only] possessing the attribute and its value
  # named in +ftypeAttrNameText+ whose value is +ftypeAttrValueText+.
  # [+ftypeAttrNameText+]   Ftype attribute name to consider
  # [+ftypeAttrValueText+]  Ftype attribute value to match
  # [+returns+]             Array of 0+ ftype records
  def selectFtypeByAttributeNameAndValueTexts(ftypeAttrNameText, ftypeAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, "ftype", ftypeAttrNameText, ftypeAttrValueText, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeByAttributeNameAndValueTexts():")
  end

  def insertFtype(method, source, ignoreDup=false)
    return insertRecords(:userDB, "ftype", [method, source], true, 1, 2, ignoreDup, "ERROR: [#{File.basename($0)}] DBUtil#insertFtype()")
  end

  # Gets Attributes information (excluding display and defauly display) for a track list
  # [+ftypeIdList+] An array of ftypeids
  # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
  # [+returns] Array of 0+ DBI rows
  SELECT_FTYPEATTRIBUTESINFO_BYFTYPEID_LIST =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, ftypeAttrNames.name, ftypeAttrValues.value from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrNames on (ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id)
      join ftypeAttrValues on (ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id)
      where ftype.ftypeid in {ftypeIdSet} "
  def selectFtypeAttributesInfoByFtypeIdList(ftypeIdList, attributeList=nil)
    retVal = sql = resultSet = nil
    unless(ftypeIdList.nil?)
      ftypeIdList = [ ftypeIdList ] unless(ftypeIdList.is_a?(Array))
      begin
        client = getMysql2Client(:userDB)
        ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
        sql = SELECT_FTYPEATTRIBUTESINFO_BYFTYPEID_LIST.dup.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
        # Optionally add in attribute list to restrict result set
        if(attributeList)
          sql << " and ftypeAttrNames.name in "
          sql << DBUtil.makeMysql2SetStr(attributeList)
        end
        # Execute query
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Gets a map with just attribute names for a track list
  # [+ftypeIdList+] An array of ftypeids
  # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
  # [+returns] Array of 0+ DBI rows
  SELECT_FTYPEATTRIBUTES_NAMES_MAP_BY_FTYPEID_LIST =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, ftypeAttrNames.name from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrNames on(ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id)
      where ftype.ftypeid in {ftypeIdSet} "
  def selectFtypeAttributeNamesMapByFtypeIdList(ftypeIdList, attributeList=nil)
    retVal = sql = resultSet = nil
    unless(ftypeIdList.nil?)
      ftypeIdList = [ ftypeIdList ] unless(ftypeIdList.is_a?(Array))
      begin
        client = getMysql2Client(:userDB)
        ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
        sql = SELECT_FTYPEATTRIBUTES_NAMES_MAP_BY_FTYPEID_LIST.dup.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
        # Optionally add in attribute list to restrict result set
        if(attributeList)
          sql << " and ftypeAttrNames.name in "
          sql << DBUtil.makeMysql2SetStr(attributeList)
        end
        # Execute query
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Gets a map with just attribute values for a track list
  # [+ftypeIdList+] An array of ftypeids
  # [+returns] Array of 0+ DBI rows
  SELECT_FTYPEATTRIBUTES_VALUES_MAP_BY_FTYPEID_LIST =
    " select concat(ftype.fmethod,\":\",ftype.fsource) as trackName, ftypeAttrValues.value from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrValues on (ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id)
      where ftype.ftypeid in {ftypeIdSet} "
  def selectFtypeAttributeValuesMapByFtypeIdList(ftypeIdList)
    retVal = sql = resultSet = nil
    unless(ftypeIdList.nil?)
      ftypeIdList = [ ftypeIdList ] unless(ftypeIdList.is_a?(Array))
      begin
        client = getMysql2Client(:userDB)
        ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
        sql = SELECT_FTYPEATTRIBUTES_VALUES_MAP_BY_FTYPEID_LIST.dup.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
        # Execute query
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Gets attribute names for ALL tracks
  # [+returns] Array of 0+ DBI rows
  SELECT_ATTRIBUTE_NAMES_FOR_ALL_TRACKS =
    " select distinct(ftypeAttrNames.name) as attributeName from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrNames on (ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id) "
  def selectFtypeAttributeNamesForAllTracks()
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ATTRIBUTE_NAMES_FOR_ALL_TRACKS.dup
      # Execute query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end
  alias selectAttributeNamesForAllTracks selectFtypeAttributeNamesForAllTracks

  # Gets attribute values for ALL tracks
  # [+returns] Array of 0+ DBI rows
  SELECT_ATTRIBUTE_VALUES_FOR_ALL_TRACKS =
    " select distinct(ftypeAttrValues.value) as attributeValue from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrValues on (ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id) "
  def selectFtypeAttributeValuesForAllTracks()
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ATTRIBUTE_VALUES_FOR_ALL_TRACKS.dup
      # Execute query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Gets Attributes information (only display and defauly display) for a track list
  # [+ftypeIdList+] An array of ftypeids
  # [+userId+]
  # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
  # [+returns] Array of 0+ DBI rows
  SELECT_FTYPEATTRIBUTES_DISPLAYINFO_BYFTYPEID_LIST =
    " select concat(ftype.fmethod, \":\", ftype.fsource) as trackName, ftypeAttrNames.name, ftypeAttrDisplays.rank, ftypeAttrDisplays.color, ftypeAttrDisplays.flags from ftype2attributes
      join ftype on (ftype2attributes.ftype_id = ftype.ftypeid)
      join ftypeAttrNames on (ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id)
      join ftypeAttrValues on (ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id)
      left join ftypeAttrDisplays on (ftype2attributes.ftypeAttrName_id = ftypeAttrDisplays.ftypeAttrName_id)
      where ftypeAttrDisplays.genboreeuser_id = '{userId}' and ftype.ftypeid in {ftypeIdSet} "
  def selectFtypeAttributesDisplayInfoByFtypeIdList(ftypeIdList, userId, attributeList=nil)
    retVal = sql = resultSet = nil
    unless(ftypeIdList.nil?)
      ftypeIdList = [ ftypeIdList ] unless(ftypeIdList.is_a?(Array))
      begin
        client = getMysql2Client(:userDB)
        ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
        sql = SELECT_FTYPEATTRIBUTES_DISPLAYINFO_BYFTYPEID_LIST.dup.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
        sql = sql.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
        # Optionally add in attribute list to restrict result set
        if(attributeList)
          sql << " and ftypeAttrNames.name in "
          sql << DBUtil.makeMysql2SetStr(attributeList)
        end
        # Execute query
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Insert multiple ftype records using column data.
  # If an existing ftype is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for fmethod and fsource columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numFtypes+]  Number of ftype  names to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Ftypes.
  # [+returns+]     Number of rows inserted
  def insertFtypes(data, numFtypes)
    return insertRecords(:userDB, "ftype", data, true, numFtypes, 2, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtypes():")
  end

  def updateFtypeById(ftypeid, method, source)
    return updateByFieldAndValue(:userDB, "ftype", {"fmethod"=>method, "fsource"=>source}, "ftypeid", ftypeid, "ERROR: [#{File.basename($0)}] DBUtil#updateFtypeById()")
  end

  # Delete ftype records using ftypeids.
  # [+ftypeIds+]     Array of ftypeids to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypesByFtypeIds(ftypeIds)
    return deleteByFieldWithMultipleValues(:userDB, "ftype", "ftypeid", ftypeIds, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypesByFtypeIds():")
  end

  # --------
  # Table: ftypeAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_FTYPE_ATTRNAME = "update ftypeAttrNames set name = ?, state = ? where id = ?"
  INSERT_INTO_FTYPEATTRNAMES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID = "insert into ftypeAttrNames values (NULL, ?, ?) on duplicate key update id = last_insert_id(id)"
  #:startdoc:
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all FtypeAttrNames records
  # [+returns+] 1 row with count
  def countFtypeAttrNames()
    return countRecords(:userDB, "ftypeAttrNames", "ERROR: [#{File.basename($0)}] DBUtil#countFtypeAttrNames():")
  end

  # Get all FtypeAttrNames records
  # [+returns+] Array of 0+ ftypeAttrNames records
  def selectAllFtypeAttrNames()
    return selectAll(:userDB, "ftypeAttrNames", "ERROR: [#{File.basename($0)}] DBUtil#selectAllFtypeAttrNames():")
  end

  # Get FtypeAttrNames record by its id
  # [+id+]      The ID of the ftypeAttrName record to return
  # [+returns+] Array of 0 or 1 ftypeAttrNames records
  def selectFtypeAttrNameById(id)
    return selectByFieldAndValue(:userDB, "ftypeAttrNames", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrNameById():")
  end

  # Get FtypeAttrNames records using a list of ids
  # [+ids+]     Array of ftypeAttrNames IDs
  # [+returns+] Array of 0+ ftypeAttrNames records
  def selectFtypeAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, "ftypeAttrNames", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrNamesByIds():")
  end

  # Get FtypeAttrName record by its name
  # [+name+]    The unique name of the ftypeAttrName record to return
  # [+returns+] Array of 0 or 1 ftypeAttrNames records
  def selectFtypeAttrNameByName(name)
    return selectByFieldAndValue(:userDB, "ftypeAttrNames", "name", name, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrNameByName():")
  end

  # Get FtypeAttrNames using a list of names
  # [+names+]   Array of unique ftypeAttrNames names
  # [+returns+] Array of 0+ ftypeAttrNames records
  def selectFtypeAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, "ftypeAttrNames", "name", names, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrNamesByNames():")
  end

  # Select a FtypeAttrDisplays record using a userId, ftypeId, and ftypeAttrName.
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrName+]   The ftypeAttrName for the ftype (track) attribute to be displayed.
  # [+returns+]         Array of 0 or 1 FtypeAttrDisplays records
  SELECT_FTYPEATTRNAME_BY_FTYPEID_AND_ATTRNAME =
    " select ftypeAttrNames.* from ftypeAttrNames, ftype2attributes
      where ftypeAttrNames.id = ftype2attributes.ftypeAttrName_id
      and ftype2attributes.ftype_id = '{ftypeId}' and ftypeAttrNames.name = '{name}' "
  def selectFtypeAttrNameByFtypeIdAndAttrNameText(ftypeId, ftypeAttrName)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRNAME_BY_FTYPEID_AND_ATTRNAME.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{name\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Insert an entry into the ftypeAttrNames table and set the last insert id as that id
  # [+name+] name of the attribute
  # [+state+] default: 0
  # [+returns] Number of Rows inserted
  def insertFtypeAttrNameOnDupKeyUpdateWithLastInsertId(name, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_INTO_FTYPEATTRNAMES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID)
      stmt.execute(name, state)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertFtypeAttrNameOnDupKeyUpdateWithLastInsertId():", @err, INSERT_INTO_FTYPEATTRNAMES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new FtypeAttrNames record
  # [+name+]    Unique ftypeAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertFtypeAttrName(name, state=0)
    data = [ name, state ]
    return insertFtypeAttrNames(data, 1)
  end

  # Insert multiple FtypeAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numFtypeAttrNames+]  Number of ftype attribute names to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many FtypeAttrNames.
  # [+returns+]     Number of rows inserted
  def insertFtypeAttrNames(data, numFtypeAttrNames)
    return insertRecords(:userDB, "ftypeAttrNames", data, true, numFtypeAttrNames, 2, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtypeAttrNames():")
  end

  # Delete a FtypeAttrName record using its id.
  # [+id+]      The ftypeAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrNameById(id)
    return deleteByFieldAndValue(:userDB, "ftypeAttrNames", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrNameById():")
  end

  # Delete FtypeAttrName records using their ids.
  # [+ids+]     Array of ftypeAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, "ftypeAttrNames", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrNamesByIds():")
  end

  # --------
  # Table: ftypeAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_FTYPE_ATTRVALUE = "update ftypeAttrValues set value = ?, sha1 = ?, state = ? where id = ?"
  INSERT_INTO_FTYPEATTRVALUES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID = "insert into ftypeAttrValues values (NULL, ?, ?, ?) on duplicate key update id = last_insert_id(id)"
  #:startdoc:
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all FtypeAttrValues records
  # [+returns+] 1 row with count
  def countFtypeAttrValues()
    return countRecords(:userDB, "ftypeAttrValues", "ERROR: [#{File.basename($0)}] DBUtil#countFtypeAttrValues():")
  end

  # Get all FtypeAttrValues records
  # [+returns+] Array of 0+ ftypeAttrValues records
  def selectAllFtypeAttrValues()
    return selectAll(:userDB, "ftypeAttrValues", "ERROR: [#{File.basename($0)}] DBUtil#selectAllFtypeAttrValues():")
  end

  # Get FtypeAttrValues record by its id
  # [+id+]      The ID of the ftypeAttrValues record to return
  # [+returns+] Array of 0 or 1 ftypeAttrValues records
  def selectFtypeAttrValueById(id)
    return selectByFieldAndValue(:userDB, "ftypeAttrValues", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueById():")
  end

  # Get FtypeAttrValues records using a list of ids
  # [+ids+]     Array of ftypeAttrValues IDs
  # [+returns+] Array of 0+ ftypeAttrValues records
  def selectFtypeAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, "ftypeAttrValues", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValuesByIds():")
  end

  # Get FtypeAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the ftypeAttrValue record to return
  # [+returns+] Array of 0 or 1 ftypeAttrValue records
  def selectFtypeAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, "ftypeAttrValues", "sha1", sha1, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueBySha1():")
  end

  # Get FtypeAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the ftypeAttrValue records to return
  # [+returns+] Array of 0+ ftypeAttrNames records
  def selectFtypeAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, "ftypeAttrValues", "sha1", sha1s, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueBySha1s():")
  end

  # Get FtypeAttrValues record by the exact value
  # [+value+]   The value of the ftypeAttrValue record to return
  # [+returns+] Array of 0 or 1 ftypeAttrValue records
  def selectFtypeAttrValueByValue(value)
    return selectFtypeAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get FtypeAttrValues records using a list of the exact values
  # [+values+]  Array of values of the ftypeAttrValue records to return
  # [+returns+] Array of 0+ ftypeAttrNames records
  def selectFtypeAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectFtypeAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a ftype, using the attribute id.
  # "what's the value of the ___ attribute for this ftype?"
  #
  # [+ftypeId+]         The id of the ftype.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectFtypeAttrValueByFtypeIdAndAttributeNameId(ftypeId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, "ftype", ftypeId, attrNameId, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueByFtypeIdAndAttributeNameId():")
  end

  # Select the value record for a particular attribute of a ftype, using the attribute name (text).
  # "what's the value of the ___ attribute for this ftype?"
  #
  # [+ftypeId+]         The id of the ftype.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectFtypeAttrValueByFtypeIdAndAttributeNameText(ftypeId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, "ftype", ftypeId, attrNameText, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueByFtypeIdAndAttributeNameText():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all ftypes), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectFtypeAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, "ftype", attrNameId, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValuesByAttributeNameId():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all ftypes), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectFtypeAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, "ftype", attrNameText, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValuesByAttributeNameText():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all ftypes), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectFtypeAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, "ftype", attrNameIds, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValuesByAttributeNameIds():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all ftypes), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectFtypeAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, "ftype", attrNameTexts, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValuesByAttributeNameTexts():")
  end

  # Select an attribute->value "map" for the given attributes of particular ftype, using attribute ids
  # "what are the current values associated with these attributes for this ftype, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+ftypeId+]         The id of the ftype to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectFtypeAttrValueMapByEntityAndAttributeIds(ftypeId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, "ftype", ftypeId, attrNameIds, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrAttributeValueMapByEntityAndAttributeIds():")
  end

  # Select an attribute->value "map" for the given attributes of particular ftype, using attribute names
  # "what are the current values associated with these attributes for this ftype, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+ftypeId+]   The id of the ftype to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectFtypeAttrValueMapByEntityAndAttributeTexts(ftypeId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, "ftype", ftypeId, attrNameTexts, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrValueMapByEntityAndAttributeTexts():")
  end

  SELECT_FTYPEATTRVALUE_BY_FTYPEID_AND_ATTRNAMETEXT =
    " select ftypeAttrValues.value from ftypeAttrNames, ftypeAttrValues, ftype2attributes
      where ftype2attributes.ftype_id = '{ftypeId}'
      and ftypeAttrNames.name = '{name}'
      and ftype2attributes.ftypeAttrName_id = ftypeAttrNames.id
      and ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id"
  def selectFtypeAttrValueByFtypeIdAndAttrNameText(ftypeId, attrNameText)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRVALUE_BY_FTYPEID_AND_ATTRNAMETEXT.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{name\}/, mysql2gsubSafeEsc(attrNameText.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_FTYPEATTRVALUE_BY_FTYPEID_AND_ATTRNAMEDID =
    " select ftypeAttrValues.value from ftypeAttrValues, ftype2attributes
      where ftype2attributes.ftype_id = '{ftypeId}'
      and ftype2attributes.ftypeAttrName_id = '{attrNameId}'
      and ftype2attributes.ftypeAttrValue_id = ftypeAttrValues.id"
  def selectFtypeAttrValueByFtypeIdAndAttrNameId(ftypeId, attrNameId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRVALUE_BY_FTYPEID_AND_ATTRNAMEDID.dup
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{attrNameId\}/, mysql2gsubSafeEsc(attrNameId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Insert a new FtypeAttrValues record
  # [+value+]    Unique ftypeAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertFtypeAttrValue(value, state=0)
    data = [value, state ]
    return insertFtypeAttrValues(data, 1)
  end

  # Insert an entry into the ftypeAttrValues table and set the last insert id as that id
  # [+value+] value
  # [+state+] default: 0
  # [+returns] Number of Rows inserted
  def insertFtypeAttrValueOnDupKeyUpdateWithLastInsertId(value, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_INTO_FTYPEATTRVALUES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID)
      stmt.execute(value, SHA1.hexdigest(value.to_s), state)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertFtypeAttrNameOnDupKeyUpdateWithLastInsertId():", @err, INSERT_INTO_FTYPEATTRNAMES_DUP_KEY_UPDATE_WITH_LAST_INSERT_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert multiple FtypeAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertFtypeAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numFtypeAttrValues+]  Number of ftype attribute values to insert using values in +data+.
  #                         - This is required because the data array may be flat and yet
  #                           have the dynamic field values for many FtypeAttrValues.
  # [+returns+]     Number of rows inserted
  def insertFtypeAttrValues(data, numFtypeAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, "ftypeAttrValues", dataCopy, true, numFtypeAttrValues, 3, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtypeAttrValues():")
  end

  # Delete a FtypeAttrValues record using its id.
  # [+id+]      The ftypeAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValueById(id)
    return deleteByFieldAndValue(:userDB, "ftypeAttrValues", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrValueById():")
  end

  # Delete FtypeAttrValues records using their ids.
  # [+ids+]     Array of ftypeAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, "ftypeAttrValues", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrValuesByIds():")
  end

  # Delete a FtypeAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The ftypeAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, "ftypeAttrValues", "sha1", sha1, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrValueBySha1():")
  end

  # Delete FtypeAttrValues records using their sha1 digests.
  # [+ids+]     Array of ftypeAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, "ftypeAttrValues", "sha1", sha1s, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrValuesByIds():")
  end

    # Delete a FtypeAttrValues record using the exact value.
  # [+sha1+]    The ftypeAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValueByValue(value)
    return deleteFtypeAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete FtypeAttrValues records using their exact values
  # [+values+]  Array of ftypeAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteFtypeAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: ftype2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ###########################################################################
  INSERT_INTO_FTYPE2ATTRIBUTE_DUP_KEY_UPDATE = "insert into ftype2attributes values (?, ?, ?) on duplicate key update ftypeAttrValue_id = ?"
  #:startdoc:
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Ftype2Attributes records
  # [+returns+] 1 row with count
  def countFtype2Attributes()
    return countRecords(:userDB, "ftype2attributes", "ERROR: [#{File.basename($0)}] DBUtil#countFtype2Attributes():")
  end

  # Get all Ftype2Attributes records
  # [+returns+] Array of 0+ ftype2attributes records
  def selectAllFtype2Attributes()
    return selectAll(:userDB, "ftype2attributes", "ERROR: [#{File.basename($0)}] DBUtil#selectAllFtype2Attributes():")
  end

  # Get Ftype2Attributes records by ftype_id ; i.e. get all the AVP mappings (an ID triple) for a ftype
  # [+ftypeId+] The ftype_id for the Ftype2Attributes records to return
  # [+returns+] Array of 0+ ftype2attributes records
  def selectFtype2AttributesByFtypeId(ftypeId)
    return selectByFieldAndValue(:userDB, "ftype2attributes", "ftype_id", ftypeId, "ERROR: [#{File.basename($0)}] DBUtil#selectFtype2AttributesByFtypeId():")
  end

  SELECT_FTYPE2ATTRIBUTE_BY_FTYPEID_AND_ATTRNAMEID_AND_ATTRVALUEID =
    " select * from ftype2attributes where ftype_id = '{ftypeId}' and ftypeAttrName_id = '{attrNameId}' and ftypeAttrValue_id = '{attrValueId}' "
  def selectFtypeAttributeByFtypeIdAndAttributeNameIdAndAttributeValueId(ftypeId, attrNameId, attrValueId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPE2ATTRIBUTE_BY_FTYPEID_AND_ATTRNAMEID_AND_ATTRVALUEID.dup.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      sql = sql.gsub(/\{attrNameId\}/, mysql2gsubSafeEsc(attrNameId.to_s)).gsub(/\{attrValueId\}/, mysql2gsubSafeEsc(attrValueId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_FTYPEATTR_NAMES_AND_VALUES =
    " select * from ftype2attributes fa
      left join ftypeAttrNames fan on fan.id = fa.ftypeAttrName_id
      left join ftypeAttrValues fav on fav.id = fa.ftypeAttrValue_id
      where fa.ftype_id = '{ftypeId}' "
  def selectFtypeAttributeNamesAndValuesByFtypeId(ftypeId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTR_NAMES_AND_VALUES.dup.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Get all track attributes as a trackName, attrName, attValue mapping table.
  # Can optionally filter to specifc attributes and/or specific trackNames.
  # **GOOD FOR CACHING IN CODE, because tracks*attributes is typically small**
  SELECT_FTYPEATTR_VALUE_MAP_FOR_TRACKS =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, ftypeAttrNames.name, ftypeAttrValues.value from ftype2attributes
      left join ftypeAttrNames on ftypeAttrNames.id = ftype2attributes.ftypeAttrName_id
      left join ftypeAttrValues on ftypeAttrValues.id = ftype2attributes.ftypeAttrValue_id
      left join ftype on ftype.ftypeid = ftype2attributes.ftype_id "
  def selectTracksAvpMap(attributes=nil, trackNames=nil)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTR_VALUE_MAP_FOR_TRACKS.dup
      unless(attributes.nil? and trackNames.nil?)
        sql << " where "
        if(attributes)
          sql << " ftypeAttrNames.name in "
          sql << DBUtil.makeMysql2SetStr(attributes)
        end
        if(trackNames)
          sql << " and " if(attributes)
          sql << " concat(ftype.fmethod, ':', ftype.fsource) in "
          sql << DBUtil.makeMysql2SetStr(trackNames)
        end
      end
      # Execute query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all Ftype2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+attrNameId+]   ftypeAttrName_id for tha attribute
  # [+attrValueId+]  ftypeAttrValue_id for the attribute value
  # [+returns+]           Array of 0+ ftype2attributes records
  SELECT_FTYPE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = "select * from ftype2attributes where ftypeAttrName_id = '{attrNameId}' and ftypeAttrValue_id = '{attrValueId}' "
  def selectFtype2AttributesByAttrNameIdAndAttrValueId(attrNameId, attrValueId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql = sql.gsub(/\{attrNameId\}/, attrNameId).gsub(/\{attrValueId\}/, mysql2gsubSafeEsc(attrValueId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Insert a new Ftype2Attributes record ; i.e. set a new AVP for a ftype.
  # Note: this does NOT update any existing triple involving the ftype_id and the ftypeAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that ftype.
  # [+ftypeId+]           ftype_id for whom to associate an AVP
  # [+ftypeAttrNameId+]   ftypeAttrName_id for the attribute
  # [+ftypeAttrValueId+]  ftypeAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertFtype2Attribute(ftypeId, ftypeAttrNameId, ftypeAttrValueId)
    data = [ ftypeId, ftypeAttrNameId, ftypeAttrValueId ]
    return insertFtype2Attributes(data, 1)
  end

  def insertFtype2AttributeOnDupKeyUpdate(ftypeId, ftypeAttrNameId, ftypeAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_INTO_FTYPE2ATTRIBUTE_DUP_KEY_UPDATE)
      stmt.execute(ftypeId, ftypeAttrNameId, ftypeAttrValueId, ftypeAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}]DBUtil#insertFtype2AttributeOnDupKeyUpdate():", @err, INSERT_INTO_FTYPE2ATTRIBUTE_DUP_KEY_UPDATE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert multiple Ftype2Attributes records using field data.
  # If a duplicate ftype2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for ftype_id, ftypeAttrName_id, and ftypeAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numFtype2Attributes+]  Number of ftype2attributes to insert using values in +data+.
  #                          - This is required because the data array may be flat and yet
  #                            have the dynamic field values for many Ftype2Attributes.
  # [+returns+]     Number of rows inserted
  def insertFtype2Attributes(data, numFtype2Attributes, dupKeyUpdateCol=false, flatten=true)
    return insertRecords(:userDB, "ftype2attributes", data, false, numFtype2Attributes, 3, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtype2Attributes():", dupKeyUpdateCol, flatten)
  end

  # Update the value associated with a particular ftype's attribute.
  # All triples associating the ftype to an attribute will have their value replaced.
  # [+ftypeId+]           ID of the ftype whose AVP we are updating
  # [+ftypeAttrNameId+]   ID of ftypeAttrName whose value to update
  # [+ftypeAttrValueId+]  ID of the ftypeAttrValue to associate with the attribute for a particular ftype
  def updateFtype2AttributeForFtypeAndAttrName(ftypeId, ftypeAttrNameId, ftypeAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteFtype2AttributesByFtypeIdAndAttrNameId(ftypeId, ftypeAttrNameId)
      retVal = insertFtype2Attribute(ftypeId, ftypeAttrNameId, ftypeAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateFtype2AttributeForFtypeAndAttrName():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Ftype2Attributes records for a given ftype, or for a ftype and attribute name,
  # or for a ftype and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a ftype, or to remove the association of a particular
  # attribute with the ftype, or to remove the association only if a particular value is involved.
  # [+ftypeId+]           ftype_id for which to delete some AVP info
  # [+ftypeAttrNameId+]   [optional] ftypeAttrName_id to disassociate with the ftype
  # [+ftypeAttrValueId+]  [optional] ftypeAttrValue_id to further restrict which AVPs are disassociate with the ftype
  # [+returns+]           Number of rows deleted
  DELETE_FTYPE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = "delete from ftype2attributes where ftype_id = '{ftypeId}' "
  def deleteFtype2AttributesByFtypeIdAndAttrNameId(ftypeId, ftypeAttrNameId=nil, ftypeAttrValueId=nil)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = DELETE_FTYPE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      unless(ftypeAttrNameId.nil?)
        sql << " and ftypeAttrName_id = '#{mysql2gsubSafeEsc(ftypeAttrNameId.to_s)}'"
      end
      unless(ftypeAttrValueId.nil?)
        sql << " and ftypeAttrValue_id = '#{mysql2gsubSafeEsc(ftypeAttrValueId.to_s)}'"
      end
      # Execute query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = (resultSet ? resultSet.affected_rows : 0)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: ftypeAttrDisplays
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_FTYPEATTRDISPLAY_BY_ID = "update ftypeAttrDisplays set ftype_id = ?, ftypeAttrName_id = ?, genboreeuser_id = ?, rank = ?, color = ?, flags = ?, state = ? where id = ? "
  UPDATE_FTYPEATTRDISPLAY_RANK_BY_ID = "update ftypeAttrDisplays set rank = ? where id = ?"
  UPDATE_FTYPEATTRDISPLAY_RANK_BY_USERID_AND_FTYPEID_AND_ATTRID = "update ftypeAttrDisplays set rank = ? where genboreeuser_id = ? and ftype_id = ? and ftypeAttrName_id = ? "
  #:startdoc:
  # <b>(Value = 1)</b> If this bit set in +flags+ column, then display "{attr}={value}" not just "{value}"
  DISPLAY_FTYPEATTRNAME_AND_VALUE = 1
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all FtypeAttrDisplays records
  # [+returns+] 1 row with count
  def countFtypeAttrDisplays()
    return countRecords(:userDB, "ftypeAttrDisplays", "ERROR: [#{File.basename($0)}] DBUtil#countFtypeAttrDisplays():")
  end

  # Get all FtypeAttrDisplays records
  # [+returns+] Array of 0+ ftypeAttrDisplays record rows
  def selectAllFtypeAttrDisplays()
    return selectAll(:userDB, "ftypeAttrDisplays", "ERROR: [#{File.basename($0)}] DBUtil#selectAllFtypeAttrDisplays():")
  end

  # Get FtypeAttrDisplay record by its id
  # [+id+]      The ID of the ftypeAttrDisplay record to return
  # [+returns+] Array of 0 or 1 ftypeAttrDisplay record rows
  def selectFtypeAttrDisplayById(id)
    return selectByFieldAndValue(:userDB, "ftypeAttrDisplays", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrDisplayById():")
  end

  # Get FtypeAttrDisplays records using a list of ids
  # [+ids+]     Array of ftypeAttrDisplay IDs
  # [+returns+] Array of 0+ ftypeAttrDisplay records
  def selectFtypeAttrDisplaysByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, "ftypeAttrDisplays", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrDisplaysByIds():")
  end

  # Get FtypeAttrDisplays records by genboreeuser_id (i.e. get ALL the ftype attribute display records for a particular user)
  # - By convention, the +userId=0+ is the default user.
  # - This query doesn't sort the results, it just gets all the records for the +userId+
  #
  # [+userId+]  The genboreeuser_id to get ftypeAttrDisplays records for
  # [+returns+] Array of 0+ ftypeAttrDisplay records
  def selectFtypeAttrDisplaysByUserId(userId)
    return selectByFieldAndValue(:userDB, "ftypeAttrDisplays", "genboreeuser_id", userId, "ERROR: [#{File.basename($0)}] DBUtil#selectFtypeAttrDisplaysByUserId():")
  end

  # Get FtypeAttrDisplays records by genboreeuser_id and ftype_id
  # (i.e. get all the ftype attribute display records for a track for a particular user)
  # - By convention, the +userId=0+ is the default user.
  # - Results are sorted by (rank)
  #
  # [+userId+]  The genboreeuser_id for whom to get ftypeAttrDisplays records for
  # [+ftypeId+] The ftype_id of the track to get ftypeAttrDisplay records for
  # [+returns+] Array of 0+ ftypeAttrDisplays records
  SELECT_FTYPEATTRDISPLAYS_BY_USERID_AND_FTYPEID = "select * from ftypeAttrDisplays where genboreeuser_id = '{userId}' and ftype_id = '{ftypeId}' order by rank "
  def selectFtypeAttrDisplaysByUserIdAndFtypeId(userId, ftypeId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRDISPLAYS_BY_USERID_AND_FTYPEID.dup
      sql = sql.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s)).gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Get FtypeAttrDisplays records by genboreeuser_id and a list of ftype_ids
  # (i.e. get all the ftype attribute display records for a set of tracks for a particular user)
  # - By convention, the +userId=0+ is the default user.
  # - Results are sorted by (ftype_id, rank)
  #
  # [+userId+]    The genboreeuser_id for whom to get ftypeAttrDisplays records for
  # [+ftypeIds+]  Array of ftype_ids for the tracks to get ftypeAttrDisplays records for
  # [+returns+]   Array of 0+ ftypeAttrDisplay records
  SELECT_FTYPEATTRDISPLAYS_BY_USERID_AND_FTYPEIDS = "select * from ftypeAttrDisplays where genboreeuser_id = '{userId}' and ftype_id in {ftypeIdSet} order by rank "
  def selectFtypeAttrDisplaysByUserIdAndFtypeIds(userId, ftypeIds)
    retVal = sql = resultSet = nil
    unless(ftypeIdList.nil?)
      ftypeIdList = [ ftypeIdList ] unless(ftypeIdList.is_a?(Array))
      begin
        client = getMysql2Client(:userDB)
        ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIds)
        sql = SELECT_FTYPEATTRDISPLAYS_BY_USERID_AND_FTYPEIDS.dup.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
        sql = sql.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Select a FtypeAttrDisplays record using a userId, ftypeId, and ftypeAttrNameId.
  # Generally one would use this to get the single record for its id or rank.
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrNameId+] The ftypeAttrName_id for the ftype (track) attribute to be displayed.
  # [+returns+]         Array of 0 or 1 FtypeAttrDisplays records
  SELECT_FTYPEATTRDISPLAY_BY_USERID_AND_FTYPEID_AND_ATTRID =
    " select * from ftypeAttrDisplays where ftype_id = '{ftypeId}' and genboreeuser_id = '{userId}' and ftypeAttrName_id = '{attrNameId}' "
  def selectFtypeAttrDisplayByUserIdAndFtypeIdAndAttrId(userId, ftypeId, attrNameId)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRDISPLAY_BY_USERID_AND_FTYPEID_AND_ATTRID.dup.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      sql = sql.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{attrNameId\}/, mysql2gsubSafeEsc(attrNameId.to_s_))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select a FtypeAttrDisplays record using a userId, ftypeId, and ftypeAttrName.
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrName+]   The ftypeAttrName for the ftype (track) attribute to be displayed.
  # [+returns+]         Array of 0 or 1 FtypeAttrDisplays records
  SELECT_FTYPEATTRDISPLAY_BY_USERID_AND_FTYPEID_AND_ATTRNAME =
    " select ftypeAttrDisplays.* from ftypeAttrDisplays, ftypeAttrNames
      where ftypeAttrDisplays.ftypeAttrName_id = ftypeAttrNames.id
      and ftypeAttrDisplays.ftype_id = '{ftypeId}'
      and ftypeAttrDisplays.genboreeuser_id = '{userId}'
      and ftypeAttrNames.name = '{attrName}' "
  def selectFtypeAttrDisplayByUserIdAndFtypeIdAndAttrNameText(userId, ftypeId, attrName)
    retVal = sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEATTRDISPLAY_BY_USERID_AND_FTYPEID_AND_ATTRNAME.dup
      sql = sql.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s)).gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(ftypeId.to_s)).gsub(/\{attrName\}/, mysql2gsubSafeEsc(attrName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Insert a new FtypeAttrDisplays record
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrNameId+] The ftypeAttrName_id for the ftype (track) attribute to be displayed.
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+rank+]            An integer indicating the order of this attribute relative to the other for the ftype.
  #                     NO other attribute for this track and user can have the same rank.
  # [+color+]           A +String+ containing the hex color to set (in the format "#RRGGBB").
  # [+flags+]           [optional; default=0] Integer (only unsigned low 8 bits used) with the various option bits set, if any.
  #                     - currently, only supported flag is DISPLAY_FTYPEATTRNAME_AND_VALUE (value = 1) indicating that the
  #                       user wants the ftypeAttrName in addition to the value to be displayed where this is configurable.
  # [+state+]           [optional; default=0] for future use
  # [+returns+]         Number of rows inserted
  def insertFtypeAttrDisplay(ftypeId, ftypeAttrNameId, genboreeuserId, rank, color='#000080', flags=0, state=0)
    raise ArgumentError, "ERROR: 'color' value should look like '#RRGGBB' hex color; instead, received '#{color.inspect}'." unless(color =~ /\A#/)
    data = [ ftypeId, ftypeAttrNameId, genboreeuserId, rank, color, flags, state ]
    return insertFtypeAttrDisplays(data, 1)
  end

  # Insert multiple FtypeAttrDisplaya records using column data.
  # [+data+]        An Array of values to use for ftypeId, ftypeAttrNameId, genboreeuserId, rank, state.
  #                 The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #                 See the +insertFtypeAttrDisplay()+ method for the fields needed for each record.
  # [+numFtypeAttrDisplay+] Number of ftypeAttrDisplays to insert using values in +data+.
  #                         This is required because the data array may be flat and yet
  #                         have the dynamic field values for many FtypeAttrDisplay.
  # [+returns+]     Number of rows inserted
  def insertFtypeAttrDisplays(data, numFtypeAttrDisplay)
    return insertRecords(:userDB, "ftypeAttrDisplays", data, true, numFtypeAttrDisplay, 7, false, "ERROR: [#{File.basename($0)}] DBUtil#insertFtypeAttrDisplay():")
  end

  # Update ALL the fields of a FtypeAttrDisplays record identified by its id
  # [+id+]              FtypeAttrDisplaya.id of the record to update
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrNameId+] The ftypeAttrName_id for the ftype (track) attribute to be displayed.
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+rank+]            An integer indicating the order of this attribute relative to the other for the ftype.
  #                     NO other attribute for this track and user can have the same rank.
  # [+state+]           [optional; default=0] for future use
  # [+returns+]         Number of rows updated.
  def updateFtypeAttrDisplayById(id, ftypeId, ftypeAttrNameId, genboreeuserId, rank, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_FTYPEATTRDISPLAY_BY_ID)
      stmt.execute(name, type, lab, contributors, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateFtypeAttrDisplayById(): ", @err, UPDATE_WHOLE_FTYPEATTRDISPLAY_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the rank of a FtypeAttrDisplays record identified by its id
  # [+id+]              FtypeAttrDisplay.id of the record to update
  # [+rank+]            An integer indicating the order of this attribute relative to the other for the ftype.
  #                     NO other attribute for this track and user can have the same rank.
  # [+returns+]         Number of rows updated.
  def updateFtypeAttrDisplayRankById(id, rank)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_FTYPEATTRDISPLAY_RANK_BY_ID)
      stmt.execute(rank, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateFtypeAttrDisplayRankById(): ", @err, UPDATE_FTYPEATTRDISPLAY_RANK_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the rank of a FtypeAttrDisplays record identified by its genboreeuser_id, ftype_id, and ftypeAttrName_id
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrNameId+] The ftypeAttrName_id for the ftype (track) attribute to be displayed.
  # [+rank+]            An integer indicating the order of this attribute relative to the other for the ftype.
  #                     NO other attribute for this track and user can have the same rank.
  # [+returns+]         Number of rows updated.
  def updateFtypeAttrDisplayRankByUserIdAndFtypeIdAndAttrNameId(genboreeuserId, ftypeId, attrNameId, rank)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_FTYPEATTRDISPLAY_RANK_BY_USERID_AND_FTYPEID_AND_ATTRID)
      stmt.execute(rank, genboreeuserId, ftypeId, attNameId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateFtypeAttrDisplayRankByUserIdAndFtypeIdAndAttrNameId(): ", @err, UPDATE_FTYPEATTRDISPLAY_RANK_BY_USERID_AND_FTYPEID_AND_ATTRID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the color of a FtypeAttrDisplays record identified by its id
  # [+id+]              FtypeAttrDisplay.id of the record to update
  # [+color+]           A +String+ containing the hex color to set (in the format "#RRGGBB").
  # [+returns+]         Number of rows updated.
  def updateFtypeAttrDisplayColorById(id, color)
    raise ArgumentError, "ERROR: 'color' value should look like '#RRGGBB' hex color; instead, received '#{color.inspect}'." unless(color =~ /\A#/)
    return updateByFieldAndValue(:userDB, "ftypeAttrDisplays", {"color" => color}, "id", id, "ERROR: [#{File.basename($0)}] DBUtil#updateFtypeAttrDisplayColorById():")
  end

  # Update the color of a FtypeAttrDisplays record identified by its genboreeuser_id, ftype_id, and ftypeAttrName_id
  # [+genboreeuserId+]  The genboreeuser_id for the user whom this record is for (0 == default user).
  # [+ftypeId+]         The ftype_id the records pertains to (the track)
  # [+ftypeAttrNameId+] The ftypeAttrName_id for the ftype (track) attribute to be displayed.
  # [+color+]           A +String+ containing the hex color to set (in the format "#RRGGBB").
  # [+returns+]         Number of rows updated.
  def updateFtypeAttrDisplayColorByUserIdAndFtypeIdAndAttrNameId(genboreeuserId, ftypeId, attrNameId, color)
    raise ArgumentError, "ERROR: 'color' value should look like '#RRGGBB' hex color; instead, received '#{color.inspect}'." unless(color =~ /\A#/)
    setClauseData = {"color" => color}
    whereClauseData = {"genboreeuser_id" => genboreeuserId, "ftype_id" => ftypeId, "ftypeAttrName_id" => attrNameId}
    return updateByMultipleFieldsAndValues(:userDB, "ftypeAttrDisplays", setColData, whereClauseData, :AND, "ERROR: DBUtil.FtypeAttrDisplaysTableupdateFtypeAttrDisplayColorByUserIdAndFtypeIdAndAttrNameId():")
  end

  # Delete a FtypeAttrDisplays record using its id.
  # [+id+]      The ftypeAttrDisplays.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrDisplayById(id)
    return deleteByFieldAndValue(:userDB, "ftypeAttrDisplays", "id", id, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrDisplayById():")
  end

  # Delete FtypeAttrDisplays records using their ids.
  # [+ids+]     Array of ftypeAttrDisplay.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFtypeAttrDisplayByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, "ftypeAttrDisplays", "id", ids, "ERROR: [#{File.basename($0)}] DBUtil#deleteFtypeAttrDisplayByIds():")
  end

  # --------
  # Table: ftype2gclass
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_GCLASS_BY_FTYPEID = "select gclass from gclass, ftype2gclass where ftype2gclass.ftypeid = ? and ftype2gclass.gid = gclass.gid"
  # ############################################################################
  # METHODS
  # ############################################################################
  # [+ftypeid+]
  SELECT_ALL_FTYPE_CLASSES =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, ftype2gclass.ftypeid, gclass.gid, gclass.gclass
      from ftype2gclass, gclass, ftype where ftype2gclass.gid = gclass.gid and ftype.ftypeid = ftype2gclass.ftypeid "
  def selectAllFtypeClasses(ftypeId=nil)
    retVal = []
    sql = resultSet = nil
    if(!ftypeId.nil?)
      ftypeId = [ ftypeId ] if(!ftypeId.is_a?(Array))
    end
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_FTYPE_CLASSES.dup
      if(ftypeId)
        sql << " and ftype2gclass.ftypeid in "
        sql << DBUtil.makeMysql2SetStr(ftypeId)
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

  SELECT_FTYPEID_BY_GCLASS = "select ftypeid from gclass, ftype2gclass where gclass.gclass = '{gclass}' and ftype2gclass.gid = gclass.gid "
  def selectFtypeIdsByClass(gclass)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPEID_BY_GCLASS.dup.gsub(/\{gclass\}/, mysql2gsubSafeEsc(gclass.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end


  def insertFtype2Gclass(ftypeid, gid)
    data = [ftypeid, gid]
    return insertRecords(:userDB, "ftype2gclass", data, false, 1, 2, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtype2Gclass():")
  end

  def insertFtype2Gclasses(data, numFtype2Gclass)
    return insertRecords(:userDB, "ftype2gclass", data, false, numFtype2Gclass, 2, true, "ERROR: [#{File.basename($0)}] DBUtil#insertFtype2GclassBatch():")
  end

  # --------
  # Table: ftypeAccess
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  GRANT_ACCESS_TO_FTYPEID = "replace into ftypeAccess values "
  USER_CAN_ACCESS = 2
  # ############################################################################
  # METHODS
  # ############################################################################
  def self.testPermissionBits(permBitsNum, conditionToTest=USER_CAN_ACCESS)
    return ((permBitsNum & conditionToTest) == conditionToTest)
  end

  def selectTrackAccessToTrackByUser(trackId, userId)
    # Is trackId a name rather than an id?
    if(trackId.is_a?(String))
      ftypeRec = selectFtypeByTrackName(trackId)
      trackId = ftypeRec.first["ftypeid"]
    end
    return self.selectByMultipleFieldsAndValues(:userDB, "ftypeAccess", {"ftypeid" => trackId, "userId" => userId}, :and, "ERROR: [#{File.basename($0)}] DBUtil#selectTrackAccessToTrackByUser()")
  end

  def selectAllTrackAccessRecords()
    return selectAll(:userDB, 'ftypeAccess', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getTrackAccessForTracks(trackIds)
    return selectByFieldWithMultipleValues(:userDB, 'ftypeAccess', 'ftypeid', trackIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Faster & more efficient to use than selectAllTrackAccessRecords()
  # - Gets just relevant columns, making fetch_all() much cheaper
  # - Contains all info you need to decide if track is accessible or not (including no access info set due to outer join)
  #   . no need to ALSO select everything from ftype and intersect (like other code is doing)
  # - supports "noComponents" boolean like ftype table methods do
  # - result table rows will have these columns:
  #   . ftypeid, fmethod, fsource, userId, permissionBits
  SELECT_ALL_ACCESSES_FAST =
    " select ftype.ftypeid, concat(fmethod, ':', fsource) as trackName, ftypeAccess.userId, ftypeAccess.permissionBits from ftype
      left join ftypeAccess on (ftype.ftypeid = ftypeAccess.ftypeid) "
  def selectAllTrackAccessRecords_fast(noComponents=true, includePartialEntities=false)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_ACCESSES_FAST.dup
      if(noComponents)
        sql << " where (fmethod != 'Component' and fsource != 'Chromosome') and (fmethod != 'Supercomponent' and fsource != 'Sequence') "
      end
      unless(includePartialEntities)
        sql << " and ftype.ftypeid NOT IN (select ftype.ftypeid from ftype, ftype2attributes, ftypeAttrNames,
          ftypeAttrValues where ftypeAttrNames.name = 'gbPartialEntity' and ftypeAttrValues.value = true and
          ftype.ftypeid = ftype2attributes.ftype_id and ftypeAttrNames.id = ftype2attributes.ftypeAttrName_id and
          ftypeAttrValues.id = ftype2attributes.ftypeAttrValue_id) "
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

  def removeAllAccessLimits(trackId)
    return deleteByFieldAndValue(:userDB, 'ftypeAccess', 'ftypeid', trackId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def giveTrackAccess(trackId, userIdsWithAccess)
    retVal = 0
    unless(userIdsWithAccess.empty?)
      begin
        connectToDataDb()
        valStr = ''
        valArray = []
        userIdsWithAccess.each_index { |ii|
          valStr << "(?,?,?,?)"
          valStr << ' , ' unless(ii == (userIdsWithAccess.size - 1))
          valArray.push(nil, userIdsWithAccess[ii], trackId, USER_CAN_ACCESS )
        }
        sql = GRANT_ACCESS_TO_FTYPEID + valStr
        stmt = @dataDbh.prepare(sql)
        stmt.execute(*valArray)
        retVal = stmt.rows
      rescue => @err
        DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#giveTrackAccess():", @err, GRANT_ACCESS_TO_FTYPEID)
      ensure
        stmt.finish() unless(stmt.nil?)
      end
    end
    return retVal
  end

  REVOKE_ACCESS_TO_FTYPEID = "delete from ftypeAccess where ftypeid = '{ftypeId}' and userId in {userIdSet}"
  def revokeTrackAccess(trackId, userIdsWithoutAccess)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = REVOKE_ACCESS_TO_FTYPEID.dup.gsub(/\{ftypeId\}/, mysql2gsubSafeEsc(trackId.to_s))
      userIdSet = DBUtil.makeMysql2SetStr(userIdsWithoutAccess)
      sql = sql.gsub(/\{userIdSet\}/, userIdSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_ALL_BY_FSOURCE_AND_FMETHOD =
    " select * from ftypeAccess, ftype where ftype.fmethod = '{fmethod}' and ftype.fsource = '{fsource}' and ftype.ftypeid = ftypeAccess.ftypeid"
  def selectAllByFmethodAndFsource(fmethod, fsource)
    retVal = []
    sql = resultSet = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_BY_FSOURCE_AND_FMETHOD.dup
      sql = sql.gsub(/\{fmethod\}/, mysql2gsubSafeEsc(fmethod.to_s)).gsub(/\{fsource\}/, mysql2gsubSafeEsc(fsource.to_s))
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
  # Table: ftype2attributeName
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAttributesGroupedByTrack()
    return selectAll(:userDB, 'ftype2attributeName', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectAttributesForTrack(ftypeId)
    return selectByFieldAndValue(:userDB, 'ftype2attributeName', 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Return records from 'ftypeattributeName' table based on a ftypeid list
  # [+ftypeidList+] An array of ftypeids
  # [+returns+] An array of DBI rows from the 'ftype2attributeName' table
  SELECT_FTYPE2ATTRIBUTENAME_BY_FTYPEIDLIST =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, ftype2attributeName.ftypeid, ftype2attributeName.attNameId
      from ftype2attributeName, ftype where ftype.ftypeid = ftype2attributeName.ftypeid and ftype2attributeName.ftypeid in {ftypeIdSet} "
  def selectFtype2AttributeNameByFtypeidList(ftypeIdList)
    retVal = sql = resultSet = nil
    ftypeIdList = [ftypeIdList] unless(ftypeIdList.is_a?(Array))
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_FTYPE2ATTRIBUTENAME_BY_FTYPEIDLIST.dup
      ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
      sql = sql.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # [+ftypeidList+] An array of ftypeids
  # [+returns+] An array of DBI rows from the 'ftype2attributeName' table
  SELECT_TRACKNAMES_TO_ANNO_ATTRIBUTES =
    " select concat(ftype.fmethod, ':', ftype.fsource) as trackName, attNames.name from ftype, attNames, ftype2attributeName
      where ftype.ftypeid = ftype2attributeName.ftypeid
      and attNames.attNameId = ftype2attributeName.attNameId
      and ftype2attributeName.ftypeid in {ftypeIdSet} "
  def selectTrackNameToAnnoAttributes(ftypeIdList)
    retVal = sql = resultSet = nil
    ftypeIdList = [ftypeIdList] unless(ftypeIdList.is_a?(Array))
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_TRACKNAMES_TO_ANNO_ATTRIBUTES.dup
      ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
      sql = sql.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  DELETE_FTYPE2ATTRIBUTENAME_BY_FTYPEIDLIST = "delete from ftype2attributeName where ftypeid in {ftypeIdSet} "
  def deleteFtype2AttributeNameByFtypeidList(ftypeIdList)
    retVal = sql = resultSet = nil
    ftypeIdList = [ftypeIdList] unless(ftypeIdList.is_a?(Array))
    begin
      client = getMysql2Client(:userDB)
      sql = DELETE_FTYPE2ATTRIBUTENAME_BY_FTYPEIDLIST.dup
      ftypeIdSet = DBUtil.makeMysql2SetStr(ftypeIdList)
      sql = sql.gsub(/\{ftypeIdSet\}/, ftypeIdSet)
      client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: ftypeCount
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_FTYPECOUNT_BY_FTYPEID = "update ftypeCount SET numberOfAnnotations = ? where ftypeId = ?"
  SELECT_FTYPECOUNT_BY_FTYPEIDS = 'select concat(ftype.fmethod, ":", ftype.fsource) as trackName, ftypeCount.numberOfAnnotations from ftype, ftypeCount where ftype.ftypeid = ftypeCount.ftypeid and ftype.ftypeid in  '
  # ############################################################################
  # METHODS
  # ############################################################################
  def insertFtypeCount(ftypeid, numOfAnnotations)
    data = [ftypeid, numOfAnnotations]
    return insertRecords(:userDB, "ftypeCount", data, false, 1, 2, false, "ERROR: [#{File.basename($0)}] DBUtil#insertFtypeCount():")
  end

  def selectFtypeCountByFtypeid(ftypeId)
    return selectByFieldAndValue(:userDB, 'ftypeCount', 'ftypeid', ftypeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectFtypeCountByFtypeIds(ftypeIdList)
    retVal = nil
    return retVal if(ftypeIdList.nil?)
    ftypeIdList = [ftypeIdList] if(!ftypeIdList.is_a?(Array))
    begin
      connectToDataDb()             # Lazy connect to data database
      sql = SELECT_FTYPECOUNT_BY_FTYPEIDS.dup()
      sql << DBUtil.makeSqlSetStr(ftypeIdList.size)
      stmt = @dataDbh.prepare(sql)
      stmt.execute(*ftypeIdList)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectFtypeCountByFtypeIds():", @err, SELECT_FTYPECOUNT_BY_FTYPEIDS)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateNumberOfAnnotationsByFtypeid(ftypeid, numberOfAnnotations)
    retVal = nil
    begin
      sql = UPDATE_FTYPECOUNT_BY_FTYPEID
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(numberOfAnnotations, ftypeid)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateNumberOfAnnotationsByFtypeid():", @err, sql, ftypeid, numberOfAnnotations)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Replaces records for ftypeCount table
  # [+data+] array of records to replace
  # [+numRecords+] number of records to replace
  def replaceFtypeCountRecords(data, numRecords)
    return replaceRecords(:userDB, "ftypeCount", data, numRecords, 2, "ERROR: [#{File.basename($0)}] DBUtil#replaceFtypeCountRecords():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
