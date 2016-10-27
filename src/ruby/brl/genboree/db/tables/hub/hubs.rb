require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Hub-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: hubs
  # --------
  # NOTE: the hubs entity table is called "hubs"
  # Methods below are for uniform method consistency and any AVP-related functionality

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Hubs records
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubs()
    return countRecords(:mainDB, 'hubs', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Count all Hubs within a given group, identified by groupId
  # @param [Fixnum] groupId The id of the group.
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubsByGroupId(groupId)
    return countByFieldAndValue(:mainDB, 'hubs', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Count all Hubs within a given group, identified by groupName
  # @param [String] groupName The name of the group.
  # @return [Array<Hash>] Result set - with a row containing the count.
  COUNT_HUBS_BY_GROUPNAME_SQL = "select count(*) from hubs, genboreegroup where genboreegroup.groupName = '{groupName}' and genboreegroup.groupId = hubs.group_id"
  def countHubsByGroupId(groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = COUNT_HUBS_BY_GROUPNAME_SQL.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # @param [Fixnum] hubId The id of the Hub.
  # @return [Boolean] indicating whether the knowledgebase is public or not.
  def isHubPublic(hubId)
    retVal = false
    rows = selectByMultipleFieldsAndValues(:mainDB, 'hubs', { 'hubId' => hubId, 'public' => 1 }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = !(rows.nil? or rows.empty?)
    return retVal
  end

  # Get all Hubs records
  # @return [Array<Hash>] Result set - Rows with the hub records
  def selectAllHubs()
    return selectAll(:mainDB, 'hubs', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Hub record by its id
  # @param [Fixnum] id ID of the hub record to return
  # @return [Array<Hash>] Result set - 0 or 1 hubs record rows
  def selectHubById(id)
    return selectByFieldAndValue(:mainDB, 'hubs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Hubs records using a list of ids
  # @param [Array<Fixnum>] ids The list of hub record IDs
  # @return [Array<Hash>] Result set - 0+ hubs records
  def selectHubsByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'hubs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Hubs records for a group using the group's ID
  # @param [Fixnum] groupid The id of the group.
  # @return [Array<Hash>] Result set - 0+ hubs record
  def selectHubsByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'hubs', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Hubs using a list of groupIds
  # @param [Array<Fixnum>] Array of groupIds
  # @return [Array<Hash>] Result set - 0+ hubs record
  def selectHubsByGroupIds(groupIds)
    return selectByFieldWithMultipleValues(:mainDB, 'hubs', 'groupId', groupIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  HUBS_BY_GROUPNAME_SQL = "select hubs.* from hubs, genboreegroup where genboreegroup.groupName = '{groupName}' and genboreegroup.groupId = hubs.group_id"
  # Get Hubs records for a group using the group's name.
  # @param [String] groupName The name of the group containing the kb.
  # @return [Array<Hash>] Result set - 0+ hubs record
  def selectHubsByGroupName(groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = HUBS_BY_GROUPNAME_SQL.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Get Hub by its unique name within a group using the group's ID.
  # @param [String] hubName The name of the hub record to return
  # @param [Fixnum] groupId The id of the group containing a hub of that name.
  # @return [Array<Hash>] Result set - 0 or 1 hub records
  def selectHubByNameAndGroupId(hubName, groupId)
    return selectByMultipleFieldsAndValues(:mainDB, 'hubs', { 'name' => hubName, 'group_id' => groupId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  HUB_BY_NAME_AND_GROUPNAME_SQL = "select hubs.* from hubs, genboreegroup where genboreegroup.groupName = '{groupName}' and hubs.name = '{hubName}' and genboreegroup.groupId = hubs.group_id"
  # Get Hub by its unique name with a group using the group's name.
  # @param [String] hubName The name of the hub record to return
  # @param [String] groupName The name of the group containing the kb.
  # @return [Array<Hash>] Result set - 0 or 1 hub records
  def selectHubByNameAndGroupName(hubName, groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = HUB_BY_NAME_AND_GROUPNAME_SQL.gsub(/\{hubName\}/, mysql2gsubSafeEsc(hubName.to_s))
      sql = sql.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  SELECT_FULL_HUB_BY_HUBID_AND_GROUPID = "
  select hubs.name as hub_name, hubGenomes.id as hubGenome_id, hubGenomes.genome as hubGenome_genome, hubTracks.id as hubTrack_id, hubTracks.hubGenome_id as hubTrack_hubGenome_id, hubTracks.trkKey as hubTrack_trkKey, hubTracks.type as hubTrack_type, hubTracks.parent_id as hubTrack_parent_id, hubTracks.aggTrack as hubTrack_aggTrack, hubTracks.trkUrl as hubTrack_trkUrl, hubTracks.dataUrl as hubTrack_dataUrl, hubTracks.shortLabel as hubTrack_shortLabel, hubTracks.longLabel as hubTrack_longLabel,
  from hubs, hubGenomes, hubTracks
  where hub.id = '{hubId}'
  and hub.group_id = {groupId}
  and hubGenomes.hub_id = hubs.id
  and hubTracks.hubGenome_id = hubGenomes.id
  "
  # Get all tracks in all genomes for a given hub using its id and the id of the group it's in.
  # @param [Fixnum] id ID of the hub for which to return full info
  # @param [Fixnum] groupId The id of the group containing that hub
  # @return [Array<Hash>] Result set - 0+ records with columns:
  #   * hub_name, hubGenome_id, hubGenome_genome AND
  #   * all hubTracks.* columns as hubTrack_{colName}
  def selectFullHubGenomeInfoByGenomeAndHubId(id, groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_FULL_HUB_BY_HUBID_AND_GROUPID.gsub(/\{groupId\}/, groupId)
      sql = sql.gsub(/\{hubId\}/, id)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  SELECT_FULL_HUB_BY_HUBNAME_AND_GROUPID = "
  select hubs.id as hub_id, hubGenomes.id as hubGenome_id, hubGenomes.genome as hubGenome_genome, hubTracks.id as hubTrack_id, hubTracks.hubGenome_id as hubTrack_hubGenome_id, hubTracks.trkKey as hubTrack_trkKey, hubTracks.type as hubTrack_type, hubTracks.parent_id as hubTrack_parent_id, hubTracks.aggTrack as hubTrack_aggTrack, hubTracks.trkUrl as hubTrack_trkUrl, hubTracks.dataUrl as hubTrack_dataUrl, hubTracks.shortLabel as hubTrack_shortLabel, hubTracks.longLabel as hubTrack_longLabel,
  from hubs, hubGenomes, hubTracks
  where hub.name = '{name}'
  and hub.group_id = {groupId}
  and hubGenomes.hub_id = hubs.id
  and hubTracks.hubGenome_id = hubGenomes.id
  "
  # Get all tracks in all genomes for a given hub using its name and the id of the group it's in.
  # @param [String] hubName The name of the hub record to return
  # @param [Fixnum] groupId The id of the group containing that hub
  # @return [Array<Hash>] Result set - 0+ records with columns:
  #   * hub_id, hubGenome_id, hubGenome_genome AND
  #   * all hubTracks.* columns as hubTrack_{colName}
  def selectFullHubGenomeInfoByGenomeAndHubId(hubName, groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_FULL_HUB_BY_HUBNAME_AND_GROUPID.gsub(/\{groupId\}/, groupId)
      sql = sql.gsub(/\{hubName\}/, mysql2gsubSafeEsc(hubName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  PUBLIC_HUBS_BY_GROUPID_SQL = "select hubs.* from hubs, genboreegroup where genboreegroup.group_id = '{group_id}' and hubs.public = 1 "
  # Get public hubs within a group identified by its groupId
  # @param [Fixnum] groupId The id of the group containing a hub of that name.
  # @return [Array<Hash>] Result set - 0+ hubs records
  def selectPublicHubsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_HUBS_BY_GROUPID_SQL.gsub(/\{group_id\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  PUBLIC_UNLOCKED_HUBS_BY_GROUPID_SQL = "select hubs.*, unlockedGroupResources.unlockKey from hubs, unlockedGroupResources where hubs.group_id = '{groupId}' and hubs.public = 1 and unlockedGroupResources.group_id = hubs.group_id and unlockedGroupResources.resourceType='kb' and unlockedGroupResources.resource_id=hubs.id"
  def selectPublicUnlockedHubsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_UNLOCKED_HUBS_BY_GROUPID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Insert a new Hub record.
  # @param [Fixnum] groupId The id of the group the hub is in.
  # @param [String] hubName  Hub name within the group. Must be unique within the group.
  # @param [String] shortLabel The hub's shortLabel. No longer than 17 chars. Must be unique within the group.
  # @param [String] longLabel The hub's longLabel or description. Generally 1 sentence/line; 80 chars recommended by UCSC.
  # @param [String] email The main point of contact for the hub.
  # @param [Fixnum] public Flag indicating if hub is publicly accessible or not (0 or 1)
  # @return [Fixnum] Number of rows inserted
  def insertHub(groupId, hubName, shortLabel, longLabel, email, public=0)
    data = [ groupId, hubName, shortLabel, longLabel, email, public ]
    return insertHubs(data, 1)
  end

  # Insert multiple Hub records using column data.
  # @see insertHub
  # @param [Array, Array<Array>] data An Array of values to use for groupId, name, state (in that order!)
  #   The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numHubs Number of hubs to insert using values in @data@.
  #   This is required because the data array may be flat and yet have the dynamic field values for many Hubs.
  # @return [Fixnum] Number of rows inserted
  def insertHubs(data, numHubs)
    return insertRecords(:mainDB, 'hubs', data, true, numHubs, 6, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Hub record using its id.
  # @param [Fixnum] id       The hubs.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubById(id)
    return deleteByFieldAndValue(:mainDB, 'hubs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Hub records using their ids.
  # @param [Array<Fixnum>] ids      Array of hubs.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubsByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'hubs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Hub record using its unique name within the group identified by groupId
  # @param [String] hubName  The unique hub name of the record to delete.
  # @param [Fixnum] groupid  The id of the group in which hubName is a unique hub name.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubByNameAndGroupId(hubName, groupId)
    whereCriteria = { 'name' => hubName, 'group_id' => groupId }
    return deleteByMultipleFieldsAndValues(:mainDB, 'hubs', whereCriteria, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Hub record using its unique name within a group identified by groupName
  # @param [String] hubName  The unique hub name of the record to delete.
  # @param [Fixnum] groupid  The id of the group in which hubName is a unique hub name.
  # @return [Fixnum]  Number of rows deleted
  DELETE_HUB_BY_NAME_AND_GROUPNAME_SQL = "delete from hubs using hubs, genboreegroup where genboreegroup.groupName = '{groupName}' and hubs.name = '{hubName}' and genboreegroup.groupId = hubs.group_id"
  def deleteHubByNameAndGroupName(hubName, groupName)
    retVal = sql = nil
     begin
      client = getMysql2Client(:mainDB)
      sql = DELETE_HUB_BY_NAME_AND_GROUPNAME_SQL.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      sql = sql.gsub(/\{hubName\}/, mysql2gsubSafeEsc(hubName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Delete all the hubs in a group identified by groupId
  # @param [String] hubName  The unique hub name of the record to delete.
  # @param [Fixnum] groupid  The id of the group in which hubName is a unique hub name.
  # @return [Fixnum]  Number of rows deleted
  def deleteAllHubsByGroupId(groupId)
    return deleteByFieldAndValue(:mainDB, 'hubs', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete all the hubs in a group identified by groupName
  # @param [String] hubName  The unique hub name of the record to delete.
  # @param [Fixnum] groupid  The id of the group in which hubName is a unique hub name.
  # @return [Fixnum]  Number of rows deleted
  DELETE_ALL_HUBS_BY_GROUPNAME_SQL = "delete from hubs using hubs, genboreegroup where genboreegroup.groupName = '{groupName}' and genboreegroup.groupId = hubs.group_id"
  def deleteAllHubsByGroupName(groupName)
    retVal = sql = nil
     begin
      client = getMysql2Client(:mainDB)
      sql = DELETE_ALL_HUBS_BY_GROUPNAME_SQL.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Update ALL the fields of a Hub Track record identified by its id
  # @param [Fixnum] id
  # @param [Hash] cols2vals map columns-to-update to their new values identified by id
  #   with the following (optional) fields 
  #   [Fixnum] group_id
  #   [String] name
  #   [String] shortLabel
  #   [String] longLabel
  #   [String] email
  #   [0, 1] public
  # @return [Fixnum] Number of rows updated
  def updateHubById(id, cols2vals)
    return updateColumnsByFieldAndValue(:mainDB, 'hubs', cols2vals, 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
