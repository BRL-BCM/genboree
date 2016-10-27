require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Kb-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: kbs
  # --------
  # NOTE: the kbs entity table is called "kbs"
  # Methods below are for uniform method consistency and any AVP-related functionality

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Kbs records
  # @return [Array<Array>] Result set - with a row containing the count.
  def countKbs()
    return countRecords(:mainDB, 'kbs', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # @param [Fixnum] kbId The id of the Kb.
  # @return [Boolean] indicating whether the knowledgebase is public or not.
  def isKbPublic(kbId)
    retVal = false
    rows = selectByMultipleFieldsAndValues(:mainDB, 'kbs', { 'id' => kbId, 'public' => 1 }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = !(rows.nil? or rows.empty?)
    return retVal
  end

  # Get all Kbs records
  # @return [Array<Array>] Result set - Rows with the kb records
  def selectAllKbs()
    return selectAll(:mainDB, 'kbs', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kb record by its id
  # @param [Fixnum] id ID of the kb record to return
  # @return [Array<Array>] Result set - 0 or 1 kbs record rows
  def selectKbById(id)
    return selectByFieldAndValue(:mainDB, 'kbs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kbs records using a list of ids
  # @param [Array<Fixnum>] ids The list of kb record IDs
  # @return [Array<Array>] Result set - 0+ kbs records
  def selectKbsByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'kbs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kbs records for a group using the group's ID
  # @param [Fixnum] groupid The id of the group.
  # @return [Array<Array>] Result set - 0+ kbs record
  def selectKbsByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'kbs', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kbs using a list of groupIds
  # @param [Array<Fixnum>] Array of groupIds
  # @return [Array<Array>] Result set - 0+ kbs record
  def selectKbsByGroupIds(groupIds)
    return selectByFieldWithMultipleValues(:mainDB, 'kbs', 'groupId', groupIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  KBS_BY_GROUPNAME_SQL = "select kbs.* from kbs, genboreegroup where genboreegroup.groupName = '{groupName}' and genboreegroup.groupId = kbs.group_id"
  # Get Kbs records for a group using the group's name.
  # @param [String] groupName The name of the group containing the kb.
  # @return [Array<Array>] Result set - 0+ kbs record
  def selectKbsByGroupName(groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = KBS_BY_GROUPNAME_SQL.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Get Kb by its unique name within a group using the group's ID.
  # @param [String] kbName The name of the kb record to return
  # @param [Fixnum] groupId The id of the group containing a kb of that name.
  # @return [Array<Array>] Result set - 0 or 1 kb records
  def selectKbByNameAndGroupId(kbName, groupId)
    return selectByMultipleFieldsAndValues(:mainDB, 'kbs', { 'name' => kbName, 'group_id' => groupId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kb by its mongodb name.
  # @param [String] mongoDbName The name of the actual database in the underlying persistant store (probably MongoDB)
  #   As a rule, created using the group name and the user's kb name
  # @return [Array<Array>] Result set - 0 or 1 kb records
  def selectKbByRawDatabaseName(mongoDbName)
    return selectByFieldAndValue(:mainDB, 'kbs', 'databaseName', mongoDbName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  KB_BY_NAME_AND_GROUPNAME_SQL = "select kbs.* from kbs, genboreegroup where genboreegroup.groupName = '{groupName}' and kbs.name = '{kbName}' and genboreegroup.groupId = kbs.group_id"
  # Get Kb by its unique name with a group using the group's name.
  # @param [String] kbName The name of the kb record to return
  # @param [String] groupName The name of the group containing the kb.
  # @return [Array<Array>] Result set - 0 or 1 kb records
  def selectKbByNameAndGroupName(kbName, groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = KB_BY_NAME_AND_GROUPNAME_SQL.gsub(/\{kbName\}/, mysql2gsubSafeEsc(kbName.to_s))
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

  PUBLIC_KBS_BY_GROUPID_SQL = "select kbs.* from kbs, genboreegroup where genboreegroup.group_id = '{group_id}' and kbs.public = 1 "
  # Get public kbs within a group identified by its groupId
  # @param [Fixnum] groupId The id of the group containing a kb of that name.
  # @return [Array<Array>] Result set - 0+ kbs records
  def selectPublicKbsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_KBS_BY_GROUPID_SQL.gsub(/\{group_id\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  PUBLIC_UNLOCKED_KBS_BY_GROUPID_SQL = "select kbs.*, unlockedGroupResources.unlockKey from kbs, unlockedGroupResources where kbs.group_id = '{groupId}' and kbs.public = 1 and unlockedGroupResources.group_id = kbs.group_id and unlockedGroupResources.resourceType='kb' and unlockedGroupResources.resource_id=kbs.id"
  def selectPublicUnlockedKbsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_UNLOCKED_KBS_BY_GROUPID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Get Kbs by matching an AVP via ids; get all kbs possessing the attribute and its value
  # indicated by +kbAttrNameId+ whose value is +kbAttrValueId+.
  # @todo This probably should also have groupId param.
  # @param [Fixnum] kbAttrNameId kbAttrNames.id for the kb attribute to consider
  # @param [Fixnum] kbAttrValueId  kbAttrValues.id for the kb attribute value to match
  # @return [Array<Array>] Result set - 0+ kbs record
  def selectKbsByAttributeNameAndValueIds(kbAttrNameId, kbAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:mainDB, 'kbs', kbAttrNameId, kbAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kbs by matching an AVP by texts; get all kbs possessing the attribute and its value
  # named in @kbAttrNameText@ whose value is @kbAttrValueText@
  # @todo This probably should also have groupId param.
  # @param [String] kbAttrNameText  Kb attribute name to consider
  # @param [String] kbAttrValueText  Kb attribute value to match
  # @return [Array<Array>] Result set - 0+ kbs record
  def selectKbsByAttributeNameAndValueTexts(kbAttrNameText, kbAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:mainDB, 'kbs', kbAttrNameText, kbAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Kb record. Used when creating new knowledge base MongoDBs.
  # @note Actual MongoDB name will have to incorporate both the group name & desired KB name from user
  #   in order to be unique. Use {BRL::Genboree:KB::MongoKbDatabase.constructMongoDbName}.
  # @param [Fixnum] groupId The id of the group the kb is in.
  # @param [String] refseqName The name of the database in @groupId@ to be paired with the kb.
  #   MUST already exist [in @groupId@] and should have a name in the form "KB:#{mongoDbName}"
  # @param [String] kbName  Kb name within the group. Must be unique within the group.
  # @param [Fixnum] state For future use
  # @return [Fixnum] Number of rows inserted
  def insertKb(groupId, refseqName, kbName, mongoDbName, desc=nil, public=0, state=0)
    data = [ groupId, kbName, desc, mongoDbName, refseqName, state, public ]
    return insertKbs(data, 1)
  end

  # Insert multiple Kb records using column data.
  # @see insertKb
  # @param [Array, Array<Array>] data An Array of values to use for groupId, name, state (in that order!)
  #   The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numKbs Number of kbs to insert using values in @data@.
  #   This is required because the data array may be flat and yet have the dynamic field values for many Kbs.
  # @return [Fixnum] Number of rows inserted
  def insertKbs(data, numKbs)
    return insertRecords(:mainDB, 'kbs', data, true, numKbs, 7, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
  
  # Updates one or more fields by primary key (id)
  # @param [Fixnum] id of the record
  # @param [Hash] cols2vals hash with field names and the new value to set for that field  
  def updateKbById(id, cols2vals, raiseErr=false)
    return updateColumnsByFieldAndValue(:mainDB, 'kbs', cols2vals, 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", raiseErr )
  end

  # Delete a Kb record using its id.
  # @param [Fixnum] id       The kbs.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbById(id)
    return deleteByFieldAndValue(:mainDB, 'kbs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Kb records using their ids.
  # @param [Array<Fixnum>] ids      Array of kbs.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbsByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'kbs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: kbAttrNames
  # --------

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all KbAttrNames records
  # @return [Array<Array>]  Result set - 1 row with count
  def countKbAttrNames()
    return countRecords(:mainDB, 'kbAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all KbAttrNames records (i.e. in use by any Kb)
  # @return [Array<Array>]  Array of 0+ kbAttrNames records
  def selectAllKbAttrNames()
    return selectAll(:mainDB, 'kbAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrNames record by its id
  # @param [Fixnum] id       The ID of the kbAttrName record to return
  # @return [Array<Array>]  Result set - Array of 0 or 1 kbAttrNames records
  def selectKbAttrNameById(id)
    return selectByFieldAndValue(:mainDB, 'kbAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrNames records using a list of ids
  # @param [Array<Fixnum>] ids      Array of kbAttrNames IDs
  # @return [Array<Array>]  Result set - Array of 0+ kbAttrNames records
  def selectKbAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'kbAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrName record by its name
  # @param [String] name     The unique name of the kbAttrName record to return
  # @return [Array<Array>] Result set - Array of 0 or 1 kbAttrNames records
  def selectKbAttrNameByName(name)
    return selectByFieldAndValue(:mainDB, 'kbAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrNames using a list of names
  # @param [Array<String>] names    Array of unique kbAttrNames names
  # @return [Array<Array>] Restult set - Array of 0+ kbAttrNames records
  def selectKbAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'kbAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new KbAttrNames record
  # @param [String] name     Unique kbAttrNames name
  # @param [Fixnum] state    For future use
  # @return [Fixnum]  Number of rows inserted
  def insertKbAttrName(name, state=0)
    data = [ name, state ]
    return insertKbAttrNames(data, 1)
  end

  # Insert multiple KbAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # @param [Array, Array<Array>] data  An Array of values to use for name and state columns
  #   The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numKbAttrNames   Number of kb attribute names to insert using values in +data+.
  #   This is required because the data array may be flat and yet have the dynamic field values for many KbAttrNames.
  # @return [Fixnum]      Number of rows inserted
  def insertKbAttrNames(data, numKbAttrNames)
    return insertRecords(:mainDB, 'kbAttrNames', data, true, numKbAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a KbAttrName record using its id.
  # @param [Fixnum] id       The kbAttrNames.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrNameById(id)
    return deleteByFieldAndValue(:mainDB, 'kbAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete KbAttrName records using their ids.
  # @param [Array<Fixnum>] ids      Array of kbAttrNames.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'kbAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: kbAttrValues
  # --------

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all KbAttrValues records
  # @return [Array<Array>] Result set - 1 row with count
  def countKbAttrValues()
    return countRecords(:mainDB, 'kbAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all KbAttrValues records
  # @return [Array<Array>] Result set - Array of 0+ kbAttrValues records
  def selectAllKbAttrValues()
    return selectAll(:mainDB, 'kbAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrValues record by its id
  # @param [Fixnum] id       The ID of the kbAttrValues record to return
  # @return [Array<Array>] Result set - Array of 0 or 1 kbAttrValues records
  def selectKbAttrValueById(id)
    return selectByFieldAndValue(:mainDB, 'kbAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrValues records using a list of ids
  # @param [Array<Fixnum>] ids      Array of kbAttrValues IDs
  # @return [Array<Array>] Result set - Array of 0+ kbAttrValues records
  def selectKbAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'kbAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrValues record by the sha1 digest of the value
  # @param [String] sha1   The sha1 of the kbAttrValue record to return
  # @return [Array<Array>] Result set -  Array of 0 or 1 kbAttrValue records
  def selectKbAttrValueBySha1(sha1)
    return selectByFieldAndValue(:mainDB, 'kbAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrValues records using a list of sha1 digests
  # @param [Array<String>] sha1s    Array of sha1 digests of the kbAttrValue records to return
  # @return [Array<Array>] Result set - Array of 0+ kbAttrNames records
  def selectKbAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:mainDB, 'kbAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get KbAttrValues record by the exact value
  # @param [String] value    The value of the kbAttrValue record to return
  # @return [Array<Array>] Result set - Array of 0 or 1 kbAttrValue records
  def selectKbAttrValueByValue(value)
    return selectKbAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get KbAttrValues records using a list of the exact values
  # @param [Array<String>] values   Array of values of the kbAttrValue records to return
  # @return [Array<String>] Result set - Array of 0+ kbAttrNames records
  def selectKbAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectKbAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a kb, using the attribute id.
  # "what's the value of the ___ attribute for this kb?"
  #
  # @param [Fixnum] kbId            The id of the kb.
  # @param [Fixnum] attrNameId       The id of the attribute we want the value for.
  # @return [Array<Array>] Result set - Array of 0-1 attribute value record
  def selectKbAttrValueByKbIdAndAttributeNameId(kbId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:mainDB, 'kbs', kbId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a kb, using the attribute name (text).
  # "what's the value of the ___ attribute for this kb?"
  #
  # @param [Fixnum] kbId    The id of the kb.
  # @param [String] attrNameText     The name of the attribute we want the value for.
  # @return [Array<Array>] Result set - Array of 0-1 attribute value record
  def selectKbAttrValueByKbAndAttributeNameText(kbId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'kbs', kbId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all kbs), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # @param [Fixnum] attrNameId     The ids of the attribute we want the values for.
  # @return [Array<Array>] Result set - Array of 0+ attribute value record
  def selectKbAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:mainDB, 'kbs', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all kbs), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # @param [String] attrNameText    The name of the attribute we want the values for.
  # @return [Array<Array>]          Result set - Array of 0+ attribute value record
  def selectKbAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:mainDB, 'kbs', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all kbs), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # @param [Array<Fixnum>] attrNameIds    Array of ids of the attributes we want the values for.
  # @return [Array<Array>] Result set - Array of 0+ attribute value record
  def selectKbAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:mainDB, 'kbs', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all kbs), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # @param [Array<String>] attrNameTexts    Array of texts of the attributes we want the values for.
  # @return [Array<Array>] Result set -     Array of 0+ attribute value record
  def selectKbAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:mainDB, 'kbs', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular kb, using attribute ids
  # "what are the current values associated with these attributes for this kb, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # @param [Fixnum] kbId    The id of the kb to get attribute->value map info for
  # @param [Array<Fixnum>] attrNameIds      Array of ids of the attributes we want the values for.
  # @return [Array<Array>] Result set -     Array of 0+ records with the 4 columns mentioned above.
  def selectKbAttrValueMapByEntityAndAttributeIds(kbId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:mainDB, 'kbs', kbId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular kb, using attribute names
  # "what are the current values associated with these attributes for this kb, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # @param [Fixnum] kbId    The id of the kb to get attribute->value map info for
  # @param [Array<String>] attrNameTexts    Array of names of the attributes we want the values for.
  # @return [Array<Array>] Result set -     Array of 0+ records with the 4 columns mentioned above.
  def selectKbAttrValueMapByEntityAndAttributeTexts(kbId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:mainDB, 'kbs', kbId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new KbAttrValues record
  # @param [String] value     Unique kbAttrValues value
  # @param [Fixnum] state     For future use
  # @return [Fixnum]   Number of rows inserted
  def insertKbAttrValue(value, state=0)
    data = [value, state ] # insertKbAttrValues() will compute SHA1 for us
    return insertKbAttrValues(data, 1)
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Insert multiple KbAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertKbAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # @param [Array, Array<Array>] data         An Array of values to use for value and state columns
  #   The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numKbAttrValues   Number of kb attribute values to insert using values in +data+.
  #   This is required because the data array may be flat and yet have the dynamic field values for many KbAttrValues.
  # @return [Fixnum]      Number of rows inserted
  def insertKbAttrValues(data, numKbAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:mainDB, 'kbAttrValues', dataCopy, true, numKbAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a KbAttrValues record using its id.
  # @param [Fixnum] id       The kbAttrValues.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValueById(id)
    return deleteByFieldAndValue(:mainDB, 'kbAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete KbAttrValues records using their ids.
  # @param [Array<Fixnum>] ids      Array of kbAttrValues.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'kbAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a KbAttrValues record using the sha1 digest of the value.
  # @param [String] sha1     The kbAttrValues.sha1 digest of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:mainDB, 'kbAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete KbAttrValues records using their sha1 digests.
  # @param [Array<String] ids      Array of kbAttrValues.sha1 values of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:mainDB, 'kbAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a KbAttrValues record using the exact value.
  # @param [String] sha1     The kbAttrValues.sha1 digest of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValueByValue(value)
    return deleteKbAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete KbAttrValues records using their exact values
  # @param [Array<String>] values   Array of kbAttrValues values of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteKbAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteKbAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: kb2attributes
  # --------

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all Kb2Attributes records
  # @return [Array<Fixnum>]  1 row with count
  def countKb2Attributes()
    return countRecords(:mainDB, 'kb2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Kb2Attributes records
  # @return [Array<Array>] Result set - Array of 0+ kb2attributes records
  def selectAllKb2Attributes()
    return selectAll(:mainDB, 'kb2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Kb2Attributes records by kb_id ; i.e. get all the AVP mappings (an ID triple) for a kb
  # @param [Fixnum] kbId    The kb_id for the Kb2Attributes records to return
  # @return [Array<Array>]  Array of 0+ kb2attributes records
  def selectKb2AttributesByKbId(kbId)
    return selectByFieldAndValue(:mainDB, 'kb2attributes', 'kb_id', kbId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Kb2Attributes record ; i.e. set a new AVP for a kb.
  # Note: this does NOT update any existing triple involving the kb_id and the kbAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that kb.
  # @param [Fixnum] kbId              kb_id for whom to associate an AVP
  # @param [Fixnum] kbAttrNameId      kbAttrName_id for the attribute
  # @param [Fixnum] kbAttrValueId     kbAttrValue_id for the attribute value
  # @return [Fixnum]            Number of rows inserted
  def insertKb2Attribute(kbId, kbAttrNameId, kbAttrValueId)
    data = [ kbId, kbAttrNameId, kbAttrValueId ]
    return insertKb2Attributes(data, 1)
  end

  # Insert multiple Kb2Attributes records using field data.
  # If a duplicate kb2attributes record is inserted, it will be skipped
  # @param [Array, Array<Array>] data         An Array of values to use for kb_id, kbAttrName_id, and kbAttrValue_id columns
  #   The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numKb2Attributes   Number of kb2attributes to insert using values in +data+.
  #   This is required because the data array may be flat and yet have the dynamic field values for many Kb2Attributes.
  # @return [Fixnum]      Number of rows inserted
  def insertKb2Attributes(data, numKb2Attributes)
    return insertRecords(:mainDB, 'kb2attributes', data, false, numKb2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Kb2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # @param [Fixnum] kbAttrNameId    kbAttrName_id for tha attribute
  # @param [Fixnum] kbAttrValueId   kbAttrValue_id for the attribute value
  # @return [Array<Array>] Result set - Array of 0+ kb2attributes records
  def selectKb2AttributesByAttrNameIdAndAttrValueId(kbAttrNameId, kbAttrValueId)
    return selectEntity2AttributesByAttrNameIdAndAttrValueId(:mainDB, 'kbs', kbAttrNameId, kbAttrValueId)
  end

  # Update the value associated with a particular kb's attribute.
  # All triples associating the kb to an attribute will have their value replaced.
  # @param [Fixnum] kbId            ID of the kb whose AVP we are updating
  # @param [Fixnum] kbAttrNameId    ID of kbAttrName whose value to update
  # @param [Fixnum] kbAttrValueId   ID of the kbAttrValue to associate with the attribute for a particular kb
  # @return [Array<Array>] Result set - Array of 0+ kb2attributes records
  def updateKb2AttributeForKbAndAttrName(kbId, kbAttrNameId, kbAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteKb2AttributesByKbIdAndAttrNameId(kbId, kbAttrNameId)
      retVal = insertKb2Attribute(kbId, kbAttrNameId, kbAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Kb2Attributes records for a given kb, or for a kb and attribute name,
  # or for a kb and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a kb, or to remove the association of a particular
  # attribute with the kb, or to remove the association only if a particular value is involved.
  # @param [Fixnum] kbId            kb_id for which to delete some AVP info
  # @param [Fixnum] kbAttrNameId    [optional] kbAttrName_id to disassociate with the kb
  # @param [Fixnum] kbAttrValueId   [optional] kbAttrValue_id to further restrict which AVPs are disassociate with the kb
  # @return [Fixnum]          Number of rows deleted
  def deleteKb2AttributesByKbIdAndAttrNameId(kbId, kbAttrNameId=nil, kbAttrValueId=nil)
    return deleteEntity2AttributesByEntityIdAndAttrNameId(:mainDB, 'kbs', kbId, kbAttrNameId, kbAttrValueId)
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
