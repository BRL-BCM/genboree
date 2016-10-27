require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: groups
  # --------
  # NOTE: the group entity table is called "genboreegroups" and its extensive legacy methods currently live in the core.rb file
  # Methods below are for uniform method consistency and any AVP-related functionality.
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_GROUP_BY_ID = 'update genboreegroup set groupName = ?, description = ?, student = ? where groupId = ?'
  UPDATE_WHOLE_GROUP_BY_NAME = 'update genboreegroup set description = ?, student = ? where groupName = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Groups records
  # [+returns+] Array of 0+ groups record rows
  def countGroups()
    return countRecords(:mainDB, 'genboreegroup', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Groups records
  # [+returns+] Array of 0+ groups record rows
  def selectAllGroups()
    return selectAll(:mainDB, 'genboreegroup', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Group record by its id
  # [+id+]      The ID of the group record to return
  # [+returns+] Array of 0 or 1 groups record rows
  def selectGroupById(id)
    return selectByFieldAndValue(:mainDB, 'genboreegroup', 'groupId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups records using a list of ids
  # [+ids+]     Array of group IDs
  # [+returns+] Array of 0+ groups records
  def selectGroupsByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreegroup', 'groupId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Group by its unique name
  # [+name+]    The unique name of the group record to return
  # [+returns+] Array of 0 or 1 groups record
  def selectGroupByName(name)
    return selectByFieldAndValue(:mainDB, 'genboreegroup', 'groupName', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups using a list of names
  # [+names+]   Array of unique group names
  # [+returns+] Array of 0+ groups records
  def selectGroupsByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreegroup', 'groupName', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups by matching an AVP via ids; get all groups possessing the attribute and its value
  # indicated by +groupAttrNameId+ whose value is +groupAttrValueId+.
  # [+groupAttrNameId+]   groupAttrNames.id for the group attribute to consider
  # [+groupAttrValueId+]  groupAttrValues.id for the group attribute value to match
  # [+returns+]         Array of 0+ group records
  def selectGroupsByAttributeNameAndValueIds(groupAttrNameId, groupAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:mainDB, 'groups', groupAttrNameId, groupAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups by matching an AVP by texts; get all groups possessing the attribute and its value
  # named in +groupAttrNameText+ whose value is +groupAttrValueText+.
  # [+groupAttrNameText+]   Group attribute name to consider
  # [+groupAttrValueText+]  Group attribute value to match
  # [+returns+]                 Array of 0+ group records
  def selectGroupsByAttributeNameAndValueTexts(groupAttrNameText, groupAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:mainDB, 'groups', groupAttrNameText, groupAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups by their student flag (OBSOLETE COLUMN)
  # [+type+]    The type of groups to select
  # [+returns+] Array of 0+ groups records
  def selectGroupsByStudent(student)
    return selectByFieldAndValue(:mainDB, 'genboreegroup', 'student', student, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Groups using a list of types
  # [+types+]   Array of group types
  # [+returns+] Array of 0+ groups records
  def selectGroupsByStudents(students)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreegroup', 'student', students, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Group record
  # - the student colume is OBSOLETE and should be left at default
  # [+name+]          Unique experimental group name
  # [+description+]   [optional; default=''] A description of the group
  # [+student+]       [optional; default=0] OBSOLETE, leave as default
  # [+returns+]       Number of rows inserted
  def insertGroup(name, description='', student=0)
    data = [ name, description, student ]
    return insertGroups(data, 1)
  end

  # Insert multiple Group records using column data.
  # [+data+]    An Array of values to use for name, description, student
  #             See the +insertGroup()+ method for the fields needed for each record. All 5 columns are required.
  # [+numGroups+] Number of groups to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Groups.
  # [+returns+] Number of rows inserted
  def insertGroups(data, numGroups)
    return insertRecords(:mainDB, 'genboreegroup', data, true, numGroups, 3, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a Group record identified by its id
  # [+id+]            Groups.id of the record to update
  # [+name+]          Unique group name
  # [+description+]   [optional; default=''] A description of the group
  # [+student+]       [optional; default=0] OBSOLETE, leave as default
  # [+returns+]       Number of rows inserted
  def updateGroupById(id, name, description='', student=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_GROUP_BY_ID)
      stmt.execute(name, description, student, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_GROUP_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the Group using this method.
  # [+name+]          Name of group to update
  # [+description+]   [optional; default=''] A description of the group
  # [+student+]       [optional; default=0] OBSOLETE, leave as default
  # [+returns+]       Number of rows updated.
  def updateGroupByName(name, description='', student=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_GROUP_BY_NAME)
      stmt.execute(description, student, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_GROUP_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Group record using its id.
  # [+id+]      The groups.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupById(id)
    return deleteByFieldAndValue(:mainDB, 'genboreegroup', 'groupId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Group records using their ids.
  # [+ids+]     Array of groups.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupsByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'genboreegroup', 'groupId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: groupAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all GroupAttrNames records
  # [+returns+] 1 row with count
  def countGroupAttrNames()
    return countRecords(:mainDB, 'groupAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all GroupAttrNames records
  # [+returns+] Array of 0+ groupAttrNames records
  def selectAllGroupAttrNames()
    return selectAll(:mainDB, 'groupAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrNames record by its id
  # [+id+]      The ID of the groupAttrName record to return
  # [+returns+] Array of 0 or 1 groupAttrNames records
  def selectGroupAttrNameById(id)
    return selectByFieldAndValue(:mainDB, 'groupAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrNames records using a list of ids
  # [+ids+]     Array of groupAttrNames IDs
  # [+returns+] Array of 0+ groupAttrNames records
  def selectGroupAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'groupAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrName record by its name
  # [+name+]    The unique name of the groupAttrName record to return
  # [+returns+] Array of 0 or 1 groupAttrNames records
  def selectGroupAttrNameByName(name)
    return selectByFieldAndValue(:mainDB, 'groupAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrNames using a list of names
  # [+names+]   Array of unique groupAttrNames names
  # [+returns+] Array of 0+ groupAttrNames records
  def selectGroupAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'groupAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new GroupAttrNames record
  # [+name+]    Unique groupAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertGroupAttrName(name, state=0)
    data = [ name, state ]
    return insertGroupAttrNames(data, 1)
  end

  # Insert multiple GroupAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numGroupAttrNames+]  Number of group attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many GroupAttrNames.
  # [+returns+]     Number of rows inserted
  def insertGroupAttrNames(data, numGroupAttrNames)
    return insertRecords(:mainDB, 'groupAttrNames', data, true, numGroupAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a GroupAttrName record using its id.
  # [+id+]      The groupAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrNameById(id)
    return deleteByFieldAndValue(:mainDB, 'groupAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete GroupAttrName records using their ids.
  # [+ids+]     Array of groupAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'groupAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: groupAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all GroupAttrValues records
  # [+returns+] 1 row with count
  def countGroupAttrValues()
    return countRecords(:mainDB, 'groupAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all GroupAttrValues records
  # [+returns+] Array of 0+ groupAttrValues records
  def selectAllGroupAttrValues()
    return selectAll(:mainDB, 'groupAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrValues record by its id
  # [+id+]      The ID of the groupAttrValues record to return
  # [+returns+] Array of 0 or 1 groupAttrValues records
  def selectGroupAttrValueById(id)
    return selectByFieldAndValue(:mainDB, 'groupAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrValues records using a list of ids
  # [+ids+]     Array of groupAttrValues IDs
  # [+returns+] Array of 0+ groupAttrValues records
  def selectGroupAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'groupAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the groupAttrValue record to return
  # [+returns+] Array of 0 or 1 groupAttrValue records
  def selectGroupAttrValueBySha1(sha1)
    return selectByFieldAndValue(:mainDB, 'groupAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the groupAttrValue records to return
  # [+returns+] Array of 0+ groupAttrNames records
  def selectGroupAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:mainDB, 'groupAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get GroupAttrValues record by the exact value
  # [+value+]   The value of the groupAttrValue record to return
  # [+returns+] Array of 0 or 1 groupAttrValue records
  def selectGroupAttrValueByValue(value)
    return selectGroupAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get GroupAttrValues records using a list of the exact values
  # [+values+]  Array of values of the groupAttrValue records to return
  # [+returns+] Array of 0+ groupAttrNames records
  def selectGroupAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectGroupAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a group, using the attribute id.
  # "what's the value of the ___ attribute for this group?"
  #
  # [+groupId+]           The id of the group.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectGroupAttrValueByGroupIdAndAttributeNameId(groupId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:mainDB, 'groups', groupId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a group, using the attribute name (text).
  # "what's the value of the ___ attribute for this group?"
  #
  # [+groupId+]   The id of the group.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectGroupAttrValueByGroupAndAttributeNameText(groupId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'groups', groupId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all groups), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectGroupAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:mainDB, 'groups', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all groups), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectGroupAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:mainDB, 'groups', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all groups), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectGroupAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:mainDB, 'groups', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all groups), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectGroupAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:mainDB, 'groups', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular group, using attribute ids
  # "what are the current values associated with these attributes for this group, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+groupId+]   The id of the group to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectGroupAttrValueMapByEntityAndAttributeIds(groupId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:mainDB, 'groups', groupId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGroupAttributesInfo(entityNameList, attributeList=nil, errMsg=nil)
    return selectCoreEntityAttributesInfo('groups', entityNameList, attributeList, nil, 'groupName', 'groupId')
  end

  # Select an attribute->value "map" for the given attributes of particular group, using attribute names
  # "what are the current values associated with these attributes for this group, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+groupId+]   The id of the group to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectGroupAttrValueMapByEntityAndAttributeTexts(groupId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:mainDB, 'groups', groupId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new GroupAttrValues record
  # [+value+]    Unique groupAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertGroupAttrValue(value, state=0)
    data = [value, state ] # insertGroupAttrValues() will compute SHA1 for us
    return insertGroupAttrValues(data, 1)
  end

  # Insert multiple GroupAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertGroupAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numGroupAttrValues+]  Number of group attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many GroupAttrValues.
  # [+returns+]     Number of rows inserted
  def insertGroupAttrValues(data, numGroupAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:mainDB, 'groupAttrValues', dataCopy, true, numGroupAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a GroupAttrValues record using its id.
  # [+id+]      The groupAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValueById(id)
    return deleteByFieldAndValue(:mainDB, 'groupAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete GroupAttrValues records using their ids.
  # [+ids+]     Array of groupAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'groupAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a GroupAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The groupAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:mainDB, 'groupAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete GroupAttrValues records using their sha1 digests.
  # [+ids+]     Array of groupAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:mainDB, 'groupAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a GroupAttrValues record using the exact value.
  # [+sha1+]    The groupAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValueByValue(value)
    return deleteGroupAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete GroupAttrValues records using their exact values
  # [+values+]  Array of groupAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteGroupAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteGroupAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: group2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Group2Attributes records
  # [+returns+] 1 row with count
  def countGroup2Attributes()
    return countRecords(:mainDB, 'group2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Group2Attributes records
  # [+returns+] Array of 0+ group2attributes records
  def selectAllGroup2Attributes()
    return selectAll(:mainDB, 'group2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Group2Attributes records by group_id ; i.e. get all the AVP mappings (an ID triple) for a group
  # [+groupId+]   The group_id for the Group2Attributes records to return
  # [+returns+] Array of 0+ group2attributes records
  def selectGroup2AttributesByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'group2attributes', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Group2Attributes record ; i.e. set a new AVP for a group.
  # Note: this does NOT update any existing triple involving the group_id and the groupAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that group.
  # [+groupId+]             group_id for whom to associate an AVP
  # [+groupAttrNameId+]     groupAttrName_id for the attribute
  # [+groupAttrValueId+]    groupAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertGroup2Attribute(groupId, groupAttrNameId, groupAttrValueId)
    data = [ groupId, groupAttrNameId, groupAttrValueId ]
    return insertGroup2Attributes(data, 1)
  end

  # Insert multiple Group2Attributes records using field data.
  # If a duplicate group2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for group_id, groupAttrName_id, and groupAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numGroup2Attributes+]  Number of group2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Group2Attributes.
  # [+returns+]     Number of rows inserted
  def insertGroup2Attributes(data, numGroup2Attributes)
    return insertRecords(:mainDB, 'group2attributes', data, false, numGroup2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Group2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+groupAttrNameId+]   groupAttrName_id for tha attribute
  # [+groupAttrValueId+]  groupAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ group2attributes records
  def selectGroup2AttributesByAttrNameIdAndAttrValueId(groupAttrNameId, groupAttrValueId)
    return selectEntity2AttributesByAttrNameIdAndAttrValueId(:mainDB, 'groups', groupAttrNameId, groupAttrValueId)
  end

  # Update the value associated with a particular group's attribute.
  # All triples associating the group to an attribute will have their value replaced.
  # [+groupId+]           ID of the group whose AVP we are updating
  # [+groupAttrNameId+]   ID of groupAttrName whose value to update
  # [+groupAttrValueId+]  ID of the groupAttrValue to associate with the attribute for a particular group
  def updateGroup2AttributeForGroupAndAttrName(groupId, groupAttrNameId, groupAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteGroup2AttributesByGroupIdAndAttrNameId(groupId, groupAttrNameId)
      retVal = insertGroup2Attribute(groupId, groupAttrNameId, groupAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Group2Attributes records for a given group, or for a group and attribute name,
  # or for a group and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a group, or to remove the association of a particular
  # attribute with the group, or to remove the association only if a particular value is involved.
  # [+groupId+]           group_id for which to delete some AVP info
  # [+groupAttrNameId+]   [optional] groupAttrName_id to disassociate with the group
  # [+groupAttrValueId+]  [optional] groupAttrValue_id to further restrict which AVPs are disassociate with the group
  # [+returns+]         Number of rows deleted
  def deleteGroup2AttributesByGroupIdAndAttrNameId(groupId, groupAttrNameId=nil, groupAttrValueId=nil)
    return deleteEntity2AttributesByEntityIdAndAttrNameId(:mainDB, 'groups', groupId, groupAttrNameId, groupAttrValueId)
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
