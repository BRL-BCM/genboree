require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# USER RELATED TABLES - DBUtil Extension Methods for dealing with User-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: users
  # --------
  # NOTE: the user entity table is called "genboreeusers" and its extensive legacy methods currently live in the core.rb file
  # Methods below are for uniform method consistency and any AVP-related functionality.
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_USER_BY_ID = 'update genboreeuser set name = ?, password = ?, firstName = ?, lastName = ?, institution = ?, email = ?, phone = ? where userId = ?'
  UPDATE_WHOLE_USER_BY_NAME = 'update genboreeuser set password = ?, firstName = ?, lastName = ?, institution = ?, email = ?, phone = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Users records
  # [+returns+] Array of 0+ users record rows
  def countUsers()
    return countRecords(:mainDB, 'genboreeuser', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Users records
  # [+returns+] Array of 0+ users record rows
  def selectAllUsers()
    return selectAll(:mainDB, 'genboreeuser', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get User record by its id
  # [+id+]      The ID of the user record to return
  # [+returns+] Array of 0 or 1 users record rows
  def selectUserById(id)
    return selectByFieldAndValue(:mainDB, 'genboreeuser', 'userId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Users records using a list of ids
  # [+ids+]     Array of user IDs
  # [+returns+] Array of 0+ users records
  def selectUsersByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreeuser', 'userId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get User by its unique name
  # [+name+]    The unique name of the user record to return
  # [+returns+] Array of 0 or 1 users record
  def selectUserByName(name)
    return selectByFieldAndValue(:mainDB, 'genboreeuser', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Users using a list of names
  # [+names+]   Array of unique user names
  # [+returns+] Array of 0+ users records
  def selectUsersByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreeuser', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Users by matching an AVP via ids; get all users possessing the attribute and its value
  # indicated by +userAttrNameId+ whose value is +userAttrValueId+.
  # [+userAttrNameId+]   userAttrNames.id for the user attribute to consider
  # [+userAttrValueId+]  userAttrValues.id for the user attribute value to match
  # [+returns+]         Array of 0+ user records
  def selectUsersByAttributeNameAndValueIds(userAttrNameId, userAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:mainDB, 'users', userAttrNameId, userAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Users by matching an AVP by texts; get all users possessing the attribute and its value
  # named in +userAttrNameText+ whose value is +userAttrValueText+.
  # [+userAttrNameText+]   User attribute name to consider
  # [+userAttrValueText+]  User attribute value to match
  # [+returns+]                 Array of 0+ user records
  def selectUsersByAttributeNameAndValueTexts(userAttrNameText, userAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:mainDB, 'users', userAttrNameText, userAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectUserValueByUserIdAndAttributeName(userId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'users', userId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new User record
  # [+name+]          Unique login / user name
  # [+password+]   Password for user
  # [+firstName+]     User first name.
  # [+lastName+]      User last name.
  # [+institution+]   [optional; default='']  Institution/organization/company user belongs to.
  # [+phone+]         [optional; default='']  User's phone number.
  # [+returns+]       Number of rows inserted
  def insertUser(name, password, firstName, lastName, email, institution='', phone='')
    data = [ name, description, firstName, lastName, email, institution, phone  ]
    return insertUsers(data, 1)
  end

  # Insert multiple User records using column data.
  # [+data+]    An Array of values to use for name, description, student
  #             See the +insertUser()+ method for the fields needed for each record. All 7 columns are required.
  # [+numUsers+] Number of users to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Users.
  # [+returns+] Number of rows inserted
  def insertUsers(data, numUsers)
    return insertRecords(:mainDB, 'genboreeuser', data, true, numUsers, 7, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a User record identified by its id
  # [+id+]            Users.id of the record to update
  # [+name+]          Unique login / user name
  # [+description+]   Password for user
  # [+firstName+]     User first name.
  # [+lastName+]      User last name.
  # [+institution+]   [optional; default='']  Institution/organization/company user belongs to.
  # [+phone+]         [optional; default='']  User's phone number.
  # [+returns+]       Number of rows inserted
  def updateUserById(id, name, password, firstName, lastName, institution='', phone='')
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_USER_BY_ID)
      stmt.execute(name, description, student, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_USER_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the User using this method.
  # [+name+]          Unique login / user name
  # [+description+]   Password for user
  # [+firstName+]     User first name.
  # [+lastName+]      User last name.
  # [+institution+]   [optional; default='']  Institution/organization/company user belongs to.
  # [+phone+]         [optional; default='']  User's phone number.
  # [+returns+]       Number of rows updated.
  def updateUserByName(name, password, firstName, lastName, institution='', phone='')
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_USER_BY_NAME)
      stmt.execute(description, student, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_USER_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a User record using its id.
  # [+id+]      The users.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteUserById(id)
    return deleteByFieldAndValue(:mainDB, 'genboreeuser', 'userId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete User records using their ids.
  # [+ids+]     Array of users.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteUsersByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'genboreeuser', 'userId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: userAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all UserAttrNames records
  # [+returns+] 1 row with count
  def countUserAttrNames()
    return countRecords(:mainDB, 'userAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all UserAttrNames records
  # [+returns+] Array of 0+ userAttrNames records
  def selectAllUserAttrNames()
    return selectAll(:mainDB, 'userAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrNames record by its id
  # [+id+]      The ID of the userAttrName record to return
  # [+returns+] Array of 0 or 1 userAttrNames records
  def selectUserAttrNameById(id)
    return selectByFieldAndValue(:mainDB, 'userAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrNames records using a list of ids
  # [+ids+]     Array of userAttrNames IDs
  # [+returns+] Array of 0+ userAttrNames records
  def selectUserAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'userAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrName record by its name
  # [+name+]    The unique name of the userAttrName record to return
  # [+returns+] Array of 0 or 1 userAttrNames records
  def selectUserAttrNameByName(name)
    return selectByFieldAndValue(:mainDB, 'userAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrNames using a list of names
  # [+names+]   Array of unique userAttrNames names
  # [+returns+] Array of 0+ userAttrNames records
  def selectUserAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'userAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new UserAttrNames record
  # [+name+]    Unique userAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertUserAttrName(name, state=0)
    data = [ name, state ]
    return insertUserAttrNames(data, 1)
  end

  # Insert multiple UserAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numUserAttrNames+]  Number of user attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many UserAttrNames.
  # [+returns+]     Number of rows inserted
  def insertUserAttrNames(data, numUserAttrNames)
    return insertRecords(:mainDB, 'userAttrNames', data, true, numUserAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a UserAttrName record using its id.
  # [+id+]      The userAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrNameById(id)
    return deleteByFieldAndValue(:mainDB, 'userAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete UserAttrName records using their ids.
  # [+ids+]     Array of userAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'userAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: userAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all UserAttrValues records
  # [+returns+] 1 row with count
  def countUserAttrValues()
    return countRecords(:mainDB, 'userAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all UserAttrValues records
  # [+returns+] Array of 0+ userAttrValues records
  def selectAllUserAttrValues()
    return selectAll(:mainDB, 'userAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrValues record by its id
  # [+id+]      The ID of the userAttrValues record to return
  # [+returns+] Array of 0 or 1 userAttrValues records
  def selectUserAttrValueById(id)
    return selectByFieldAndValue(:mainDB, 'userAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrValues records using a list of ids
  # [+ids+]     Array of userAttrValues IDs
  # [+returns+] Array of 0+ userAttrValues records
  def selectUserAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'userAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the userAttrValue record to return
  # [+returns+] Array of 0 or 1 userAttrValue records
  def selectUserAttrValueBySha1(sha1)
    return selectByFieldAndValue(:mainDB, 'userAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the userAttrValue records to return
  # [+returns+] Array of 0+ userAttrNames records
  def selectUserAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:mainDB, 'userAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get UserAttrValues record by the exact value
  # [+value+]   The value of the userAttrValue record to return
  # [+returns+] Array of 0 or 1 userAttrValue records
  def selectUserAttrValueByValue(value)
    return selectUserAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get UserAttrValues records using a list of the exact values
  # [+values+]  Array of values of the userAttrValue records to return
  # [+returns+] Array of 0+ userAttrNames records
  def selectUserAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectUserAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a user, using the attribute id.
  # "what's the value of the ___ attribute for this user?"
  #
  # [+userId+]           The id of the user.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectUserAttrValueByUserIdAndAttributeNameId(userId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:mainDB, 'users', userId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a user, using the attribute name (text).
  # "what's the value of the ___ attribute for this user?"
  #
  # [+userId+]   The id of the user.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectUserAttrValueByUserAndAttributeNameText(userId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'users', userId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all users), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectUserAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:mainDB, 'users', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all users), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectUserAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:mainDB, 'users', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all users), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectUserAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:mainDB, 'users', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all users), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectUserAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:mainDB, 'users', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular user, using attribute ids
  # "what are the current values associated with these attributes for this user, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+userId+]   The id of the user to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectUserAttrValueMapByEntityAndAttributeIds(userId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:mainDB, 'users', userId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectUserAttributesInfo(entityNameList, attributeList=nil, errMsg=nil)
    return selectCoreEntityAttributesInfo('users', entityNameList, attributeList, nil, 'userName', 'userId')
  end

  # Select an attribute->value "map" for the given attributes of particular user, using attribute names
  # "what are the current values associated with these attributes for this user, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+userId+]   The id of the user to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectUserAttrValueMapByEntityAndAttributeTexts(userId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:mainDB, 'users', userId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new UserAttrValues record
  # [+value+]    Unique userAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertUserAttrValue(value, state=0)
    data = [value, state ] # insertUserAttrValues() will compute SHA1 for us
    return insertUserAttrValues(data, 1)
  end

  # Insert multiple UserAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertUserAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numUserAttrValues+]  Number of user attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many UserAttrValues.
  # [+returns+]     Number of rows inserted
  def insertUserAttrValues(data, numUserAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:mainDB, 'userAttrValues', dataCopy, true, numUserAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a UserAttrValues record using its id.
  # [+id+]      The userAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValueById(id)
    return deleteByFieldAndValue(:mainDB, 'userAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete UserAttrValues records using their ids.
  # [+ids+]     Array of userAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'userAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a UserAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The userAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:mainDB, 'userAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete UserAttrValues records using their sha1 digests.
  # [+ids+]     Array of userAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:mainDB, 'userAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a UserAttrValues record using the exact value.
  # [+sha1+]    The userAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValueByValue(value)
    return deleteUserAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete UserAttrValues records using their exact values
  # [+values+]  Array of userAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteUserAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteUserAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: user2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all User2Attributes records
  # [+returns+] 1 row with count
  def countUser2Attributes()
    return countRecords(:mainDB, 'user2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all User2Attributes records
  # [+returns+] Array of 0+ user2attributes records
  def selectAllUser2Attributes()
    return selectAll(:mainDB, 'user2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get User2Attributes records by user_id ; i.e. get all the AVP mappings (an ID triple) for a user
  # [+userId+]   The user_id for the User2Attributes records to return
  # [+returns+] Array of 0+ user2attributes records
  def selectUser2AttributesByUserId(userId)
    return selectByFieldAndValue(:mainDB, 'user2attributes', 'user_id', userId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new User2Attributes record ; i.e. set a new AVP for a user.
  # Note: this does NOT update any existing triple involving the user_id and the userAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that user.
  # [+userId+]             user_id for whom to associate an AVP
  # [+userAttrNameId+]     userAttrName_id for the attribute
  # [+userAttrValueId+]    userAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertUser2Attribute(userId, userAttrNameId, userAttrValueId)
    data = [ userId, userAttrNameId, userAttrValueId ]
    return insertUser2Attributes(data, 1)
  end

  # Insert multiple User2Attributes records using field data.
  # If a duplicate user2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for user_id, userAttrName_id, and userAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numUser2Attributes+]  Number of user2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many User2Attributes.
  # [+returns+]     Number of rows inserted
  def insertUser2Attributes(data, numUser2Attributes)
    return insertRecords(:mainDB, 'user2attributes', data, false, numUser2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all User2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+userAttrNameId+]   userAttrName_id for tha attribute
  # [+userAttrValueId+]  userAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ user2attributes records
  def selectUser2AttributesByAttrNameIdAndAttrValueId(userAttrNameId, userAttrValueId)
    return selectEntity2AttributesByAttrNameIdAndAttrValueId(:mainDB, 'users', userAttrNameId, userAttrValueId)
  end

  # Update the value associated with a particular user's attribute.
  # All triples associating the user to an attribute will have their value replaced.
  # [+userId+]           ID of the user whose AVP we are updating
  # [+userAttrNameId+]   ID of userAttrName whose value to update
  # [+userAttrValueId+]  ID of the userAttrValue to associate with the attribute for a particular user
  def updateUser2AttributeForUserAndAttrName(userId, userAttrNameId, userAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteUser2AttributesByUserIdAndAttrNameId(userId, userAttrNameId)
      retVal = insertUser2Attribute(userId, userAttrNameId, userAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete User2Attributes records for a given user, or for a user and attribute name,
  # or for a user and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a user, or to remove the association of a particular
  # attribute with the user, or to remove the association only if a particular value is involved.
  # [+userId+]           user_id for which to delete some AVP info
  # [+userAttrNameId+]   [optional] userAttrName_id to disassociate with the user
  # [+userAttrValueId+]  [optional] userAttrValue_id to further restrict which AVPs are disassociate with the user
  # [+returns+]         Number of rows deleted
  def deleteUser2AttributesByUserIdAndAttrNameId(userId, userAttrNameId=nil, userAttrValueId=nil)
    return deleteEntity2AttributesByEntityIdAndAttrNameId(:mainDB, 'users', userId, userAttrNameId, userAttrValueId)
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
