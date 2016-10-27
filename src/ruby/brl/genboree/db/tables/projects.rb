require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Project-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: projects
  # --------
  # NOTE: the projects entity table is called "projects" and its extensive legacy methods currently live in the core.rb file
  # Methods below are for uniform method consistency and any AVP-related functionality
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
# TODO: need equivalent of this:
  UPDATE_WHOLE_PROJECT_BY_ID = 'update projects set name = ?, groupId = ?, state = ? where id = ?'
# TODO: need equivalent of this:
  UPDATE_WHOLE_PROJECT_BY_NAME = 'update projects set groupId = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Projects records
  # [+returns+] Array of 0+ projects record rows
  def countProjects()
    return countRecords(:mainDB, 'projects', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Projects records
  # [+returns+] Array of 0+ projects record rows
  def selectAllProjects()
    return selectAll(:mainDB, 'projects', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Project record by its id
  # [+id+]      The ID of the project record to return
  # [+returns+] Array of 0 or 1 projects record rows
  def selectProjectById(id)
    return selectByFieldAndValue(:mainDB, 'projects', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects records using a list of ids
  # [+ids+]     Array of project IDs
  # [+returns+] Array of 0+ projects records
  def selectProjectsByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'projects', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Project by its unique name
  # [+name+]    The unique name of the project record to return
  # [+returns+] Array of 0 or 1 projects record
  def selectProjectByName(name)
    return selectByFieldAndValue(:mainDB, 'projects', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects using a list of names
  # [+names+]   Array of unique project names
  # [+returns+] Array of 0+ projects records
  def selectProjectsByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'projects', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects by matching an AVP via ids; get all projects possessing the attribute and its value
  # indicated by +projectAttrNameId+ whose value is +projectAttrValueId+.
  # [+projectAttrNameId+]   projectAttrNames.id for the project attribute to consider
  # [+projectAttrValueId+]  projectAttrValues.id for the project attribute value to match
  # [+returns+]         Array of 0+ project records
  def selectProjectsByAttributeNameAndValueIds(projectAttrNameId, projectAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:mainDB, 'projects', projectAttrNameId, projectAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects by matching an AVP by texts; get all projects possessing the attribute and its value
  # named in +projectAttrNameText+ whose value is +projectAttrValueText+.
  # [+projectAttrNameText+]   Project attribute name to consider
  # [+projectAttrValueText+]  Project attribute value to match
  # [+returns+]                 Array of 0+ project records
  def selectProjectsByAttributeNameAndValueTexts(projectAttrNameText, projectAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:mainDB, 'projects', projectAttrNameText, projectAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects by their type
  # [+groupId+]    The id of the group containing the projects to select
  # [+returns+] Array of 0+ projects records
  def selectProjectsByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'projects', 'groupId', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Projects using a list of types
  # [+types+]   Array of project types
  # [+returns+] Array of 0+ projects records
  def selectProjectsByGroupIds(groupIds)
    return selectByFieldWithMultipleValues(:mainDB, 'projects', 'groupId', groupIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Project record
  # [+groupId+]       A Fixnum with the id of the group the project is in
  # [+name+]          Unique experimental project name
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def insertProject(groupId, name, state=0)
    data = [ name, groupId, state ]
    return insertProjects(data, 1)
  end

  # Insert multiple Project records using column data.
  # [+data+]    An Array of values to use for groupId, name, state (in that order!)
  #             The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #             See the +insertProject()+ method for the fields needed for each record. All 5 columns are required.
  # [+numProjects+] Number of projects to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Projects.
  # [+returns+] Number of rows inserted
  def insertProjects(data, numProjects)
    return insertRecords(:mainDB, 'projects', data, true, numProjects, 3, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a Project record identified by its id
  # [+id+]            Projects.id of the record to update
  # [+groupId+]       A Fixnum with the id of the group the project is in
  # [+name+]          Unique project name
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def updateProjectById(id, groupId, name, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_PROJECT_BY_ID)
      stmt.execute(name, groupId, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_PROJECT_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the Project using this method.
  # [+name+]          Unique name of Projects record to update.
  # [+groupId+]       A Fixnum with the id of the group the project is in
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows updated.
  def updateProjectByName(name, groupId, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_PROJECT_BY_NAME)
      stmt.execute(groupId, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_PROJECT_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Project record using its id.
  # [+id+]      The projects.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectById(id)
    return deleteByFieldAndValue(:mainDB, 'projects', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Project records using their ids.
  # [+ids+]     Array of projects.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectsByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'projects', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: projectAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_DATABASE_ATTRNAME = 'update projectAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all ProjectAttrNames records
  # [+returns+] 1 row with count
  def countProjectAttrNames()
    return countRecords(:mainDB, 'projectAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all ProjectAttrNames records
  # [+returns+] Array of 0+ projectAttrNames records
  def selectAllProjectAttrNames()
    return selectAll(:mainDB, 'projectAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrNames record by its id
  # [+id+]      The ID of the projectAttrName record to return
  # [+returns+] Array of 0 or 1 projectAttrNames records
  def selectProjectAttrNameById(id)
    return selectByFieldAndValue(:mainDB, 'projectAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrNames records using a list of ids
  # [+ids+]     Array of projectAttrNames IDs
  # [+returns+] Array of 0+ projectAttrNames records
  def selectProjectAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'projectAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrName record by its name
  # [+name+]    The unique name of the projectAttrName record to return
  # [+returns+] Array of 0 or 1 projectAttrNames records
  def selectProjectAttrNameByName(name)
    return selectByFieldAndValue(:mainDB, 'projectAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrNames using a list of names
  # [+names+]   Array of unique projectAttrNames names
  # [+returns+] Array of 0+ projectAttrNames records
  def selectProjectAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'projectAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new ProjectAttrNames record
  # [+name+]    Unique projectAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertProjectAttrName(name, state=0)
    data = [ name, state ]
    return insertProjectAttrNames(data, 1)
  end

  # Insert multiple ProjectAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numProjectAttrNames+]  Number of project attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many ProjectAttrNames.
  # [+returns+]     Number of rows inserted
  def insertProjectAttrNames(data, numProjectAttrNames)
    return insertRecords(:mainDB, 'projectAttrNames', data, true, numProjectAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a ProjectAttrName record using its id.
  # [+id+]      The projectAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrNameById(id)
    return deleteByFieldAndValue(:mainDB, 'projectAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete ProjectAttrName records using their ids.
  # [+ids+]     Array of projectAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'projectAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: projectAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all ProjectAttrValues records
  # [+returns+] 1 row with count
  def countProjectAttrValues()
    return countRecords(:mainDB, 'projectAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all ProjectAttrValues records
  # [+returns+] Array of 0+ projectAttrValues records
  def selectAllProjectAttrValues()
    return selectAll(:mainDB, 'projectAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrValues record by its id
  # [+id+]      The ID of the projectAttrValues record to return
  # [+returns+] Array of 0 or 1 projectAttrValues records
  def selectProjectAttrValueById(id)
    return selectByFieldAndValue(:mainDB, 'projectAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrValues records using a list of ids
  # [+ids+]     Array of projectAttrValues IDs
  # [+returns+] Array of 0+ projectAttrValues records
  def selectProjectAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'projectAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the projectAttrValue record to return
  # [+returns+] Array of 0 or 1 projectAttrValue records
  def selectProjectAttrValueBySha1(sha1)
    return selectByFieldAndValue(:mainDB, 'projectAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the projectAttrValue records to return
  # [+returns+] Array of 0+ projectAttrNames records
  def selectProjectAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:mainDB, 'projectAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ProjectAttrValues record by the exact value
  # [+value+]   The value of the projectAttrValue record to return
  # [+returns+] Array of 0 or 1 projectAttrValue records
  def selectProjectAttrValueByValue(value)
    return selectProjectAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get ProjectAttrValues records using a list of the exact values
  # [+values+]  Array of values of the projectAttrValue records to return
  # [+returns+] Array of 0+ projectAttrNames records
  def selectProjectAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectProjectAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a project, using the attribute id.
  # "what's the value of the ___ attribute for this project?"
  #
  # [+projectId+]           The id of the project.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectProjectAttrValueByProjectIdAndAttributeNameId(projectId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:mainDB, 'projects', projectId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a project, using the attribute name (text).
  # "what's the value of the ___ attribute for this project?"
  #
  # [+projectId+]   The id of the project.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectProjectAttrValueByProjectAndAttributeNameText(projectId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'projects', projectId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all projects), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectProjectAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:mainDB, 'projects', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all projects), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectProjectAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:mainDB, 'projects', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all projects), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectProjectAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:mainDB, 'projects', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all projects), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectProjectAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:mainDB, 'projects', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular project, using attribute ids
  # "what are the current values associated with these attributes for this project, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+projectId+]   The id of the project to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectProjectAttrValueMapByEntityAndAttributeIds(projectId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:mainDB, 'projects', projectId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular project, using attribute names
  # "what are the current values associated with these attributes for this project, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+projectId+]   The id of the project to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectProjectAttrValueMapByEntityAndAttributeTexts(projectId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:mainDB, 'projects', projectId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new ProjectAttrValues record
  # [+value+]    Unique projectAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertProjectAttrValue(value, state=0)
    data = [value, state ] # insertProjectAttrValues() will compute SHA1 for us
    return insertProjectAttrValues(data, 1)
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Insert multiple ProjectAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertProjectAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numProjectAttrValues+]  Number of project attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many ProjectAttrValues.
  # [+returns+]     Number of rows inserted
  def insertProjectAttrValues(data, numProjectAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:mainDB, 'projectAttrValues', dataCopy, true, numProjectAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a ProjectAttrValues record using its id.
  # [+id+]      The projectAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValueById(id)
    return deleteByFieldAndValue(:mainDB, 'projectAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete ProjectAttrValues records using their ids.
  # [+ids+]     Array of projectAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'projectAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a ProjectAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The projectAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:mainDB, 'projectAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete ProjectAttrValues records using their sha1 digests.
  # [+ids+]     Array of projectAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:mainDB, 'projectAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a ProjectAttrValues record using the exact value.
  # [+sha1+]    The projectAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValueByValue(value)
    return deleteProjectAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete ProjectAttrValues records using their exact values
  # [+values+]  Array of projectAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteProjectAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteProjectAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: project2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Project2Attributes records
  # [+returns+] 1 row with count
  def countProject2Attributes()
    return countRecords(:mainDB, 'project2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Project2Attributes records
  # [+returns+] Array of 0+ project2attributes records
  def selectAllProject2Attributes()
    return selectAll(:mainDB, 'project2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Project2Attributes records by project_id ; i.e. get all the AVP mappings (an ID triple) for a project
  # [+projectId+]   The project_id for the Project2Attributes records to return
  # [+returns+] Array of 0+ project2attributes records
  def selectProject2AttributesByProjectId(projectId)
    return selectByFieldAndValue(:mainDB, 'project2attributes', 'project_id', projectId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Project2Attributes record ; i.e. set a new AVP for a project.
  # Note: this does NOT update any existing triple involving the project_id and the projectAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that project.
  # [+projectId+]             project_id for whom to associate an AVP
  # [+projectAttrNameId+]     projectAttrName_id for the attribute
  # [+projectAttrValueId+]    projectAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertProject2Attribute(projectId, projectAttrNameId, projectAttrValueId)
    data = [ projectId, projectAttrNameId, projectAttrValueId ]
    return insertProject2Attributes(data, 1)
  end

  # Insert multiple Project2Attributes records using field data.
  # If a duplicate project2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for project_id, projectAttrName_id, and projectAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numProject2Attributes+]  Number of project2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Project2Attributes.
  # [+returns+]     Number of rows inserted
  def insertProject2Attributes(data, numProject2Attributes)
    return insertRecords(:mainDB, 'project2attributes', data, false, numProject2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Project2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+projectAttrNameId+]   projectAttrName_id for tha attribute
  # [+projectAttrValueId+]  projectAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ project2attributes records
  def selectProject2AttributesByAttrNameIdAndAttrValueId(projectAttrNameId, projectAttrValueId)
    return selectEntity2AttributesByAttrNameIdAndAttrValueId(:mainDB, 'projects', projectAttrNameId, projectAttrValueId)
  end

  # Update the value associated with a particular project's attribute.
  # All triples associating the project to an attribute will have their value replaced.
  # [+projectId+]           ID of the project whose AVP we are updating
  # [+projectAttrNameId+]   ID of projectAttrName whose value to update
  # [+projectAttrValueId+]  ID of the projectAttrValue to associate with the attribute for a particular project
  def updateProject2AttributeForProjectAndAttrName(projectId, projectAttrNameId, projectAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteProject2AttributesByProjectIdAndAttrNameId(projectId, projectAttrNameId)
      retVal = insertProject2Attribute(projectId, projectAttrNameId, projectAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Project2Attributes records for a given project, or for a project and attribute name,
  # or for a project and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a project, or to remove the association of a particular
  # attribute with the project, or to remove the association only if a particular value is involved.
  # [+projectId+]           project_id for which to delete some AVP info
  # [+projectAttrNameId+]   [optional] projectAttrName_id to disassociate with the project
  # [+projectAttrValueId+]  [optional] projectAttrValue_id to further restrict which AVPs are disassociate with the project
  # [+returns+]         Number of rows deleted
  def deleteProject2AttributesByProjectIdAndAttrNameId(projectId, projectAttrNameId=nil, projectAttrValueId=nil)
    return deleteEntity2AttributesByEntityIdAndAttrNameId(:mainDB, 'projects', projectId, projectAttrNameId, projectAttrValueId)
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
