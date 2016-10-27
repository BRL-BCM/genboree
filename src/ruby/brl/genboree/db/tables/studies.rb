require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# STUDY RELATED TABLES - DBUtil Extension Methods for dealing with Study-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil

  # --------
  # Table: studies
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_STUDY_BY_ID = 'update studies set name = ?, type = ?, lab = ?, contributors = ?, state = ? where id = ?'
  UPDATE_WHOLE_STUDY_BY_NAME = 'update studies set type = ?, lab = ?, contributors = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Studies records
  # [+returns+] 1 row with count
  def countStudies()
    return countRecords(:userDB, 'studies', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Studies records
  # [+returns+] Array of 0+ studies record rows
  def selectAllStudies()
    return selectAll(:userDB, 'studies', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Study record by its id
  # [+id+]      The ID of the study record to return
  # [+returns+] Array of 0 or 1 studies record rows
  def selectStudyById(id)
    return selectByFieldAndValue(:userDB, 'studies', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies records using a list of ids
  # [+ids+]     Array of study IDs
  # [+returns+] Array of 0+ studies records
  def selectStudiesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'studies', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Study by its unique name
  # [+name+]    The unique name of the study record to return
  # [+returns+] Array of 0 or 1 studies record
  def selectStudyByName(name)
    return selectByFieldAndValue(:userDB, 'studies', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies using a list of names
  # [+names+]   Array of unique study names
  # [+returns+] Array of 0+ studies records
  def selectStudiesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'studies', 'names', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies by their type
  # [+type+]    The type of studies to select
  # [+returns+] Array of 0+ studies records
  def selectStudiesByType(type)
    return selectByFieldAndValue(:userDB, 'studies', 'type', type, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies using a list of types
  # [+types+]   Array of study types
  # [+returns+] Array of 0+ studies records
  def selectStudiesByTypes(types)
    return selectByFieldWithMultipleValues(:userDB, 'studies', 'type', types, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies by the lab that did them
  # [+type+]    The lab for studies to select
  # [+returns+] Array of 0+ studies records
  def selectStudiesByLab(lab)
    return selectByFieldAndValue(:userDB, 'studies', 'lab', lab, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies using a keyword in their contributors list (e.g. an author last name)
  # [+keyword+] The contributor keyword with which to select studies
  # [+returns+] Array of 0+ studies records
  def selectStudiesByContributorsKeyword(keyword)
    return selectByFieldAndKeyword(:userDB, 'studies', 'contributors', keyword, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies whose contributors match ALL or ANY of a list of keywords (e.g. some author last names, etc)
  # [+keywords+]  Array of contibutor keywords
  # [+booleanOp+] Flag indicating if ALL or ANY of the keywords must be matched in the contributors field
  # [+returns+]   Array of 0+ studies records
  def selectStudiesByContributorsKeywords(keywords, booleanOp=:and)
    return selectByFieldWithMultipleKeywords(:userDB, 'studies', 'contributors', keywords, booleanOp, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies by matching an AVP by ids; get all studies possessing the attribute and its value
  # indicated by +studyAttrNameId+ whose value is +studyAttrValueId+.
  # [+studyAttrNameId+]   studyAttrNames.id for the study attribute to consider
  # [+studyAttrValueId+]  studyAttrValues.id for the study attribute value to match
  # [+returns+]           Array of 0+ study records
  def selectStudiesByAttributeNameAndValueIds(studyAttrNameId, studyAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'studies', studyAttrNameId, studyAttrValueId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Studies by matching an AVP by text; get all studies possessing the attribute and its value
  # named in +studyAttrNameText+ whose value is +studyAttrValueText+.
  # [+studyAttrNameText+]   Study attribute name to consider
  # [+studyAttrValueText+]  Study attribute value to match
  # [+returns+]             Array of 0+ study records
  def selectStudyByAttributeNameAndValueTexts(studyAttrNameText, studyAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'studies', studyAttrNameText, studyAttrValueText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new Study record
  # [+name+]          Unique study name
  # [+type+]          A String identifying the 'type' (kind) of Study
  # [+lab+]           A String with the name of the lab doing the Study
  # [+contributors+]  A String with a list of the contibutores.
  #                   HIGHLY RECOMMEND: a CSV list of the form: "<1stNameA> <2ndNameA> <lastNameA>, <1stnameB> <lastNameB>, ...
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def insertStudy(name, type, lab, contributors, state=0)
    data = [ name, type, lab, contributors, state ]
    return insertStudies(data, 1)
  end

  # Insert multiple Study records using column data.
  # [+data+]        An Array of values to use for name, type, lab, contributors, and state.
  #                 The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #                 See the +insertStudy()+ method for the fields needed for each record.
  # [+numStudies+]  Number of studies to insert using values in +data+.
  #                 - This is required because the data array may be flat and yet
  #                   have the dynamic field values for many Studies.
  # [+returns+]     Number of rows inserted
  def insertStudies(data, numStudies)
    return insertRecords(:userDB, 'studies', data, true, numStudies, 5, false, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Update ALL the fields of a Study record identified by its id
  # [+id+]            Studies.id of the record to update
  # [+name+]          The unique name for the updated record
  # [+type+]          A String identifying the 'type' (kind) of Study for the updated record
  # [+lab+]           A String with the name of the lab doing the Study in the updated record
  # [+contributors+]  A String with a list of the contibutores for the updated record
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows updated.
  def updateStudyById(id, name, type, lab, contributors, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_STUDY_BY_ID)
      stmt.execute(name, type, lab, contributors, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_STUDY_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Mark a study record identified by its id as a template by updating its state
  # [+id+]            Studies.id of the record to update
  # [+returns+]       Number of rows updated.
  def setStudyStateToTemplate(id)
    return setStateBit(:userDB, 'studies', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a study record identified by its id as completed by updating its state
  # [+id+]            Studies.id of the record to update
  # [+returns+]       Number of rows updated.
  def setStudyStateToCompleted(id)
    return setStateBit(:userDB, 'studies', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a study record identified by its id is a template
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isStudyTemplate?(id)
    return checkStateBit(:userDB, 'studies', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a study record identified by its id is completed
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isStudyCompleted?(id)
    return checkStateBit(:userDB, 'studies', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a study record identified by its id is still in progress
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the study record is in progress, false otherwise
  def isStudyInProgress?(id)
    return (not(isStudyTemplate?(id) or isStudyCompleted?(id)))
  end

  # Update ALL the fields of a record identifies by its name.
  # You cannot rename the Study using this method.
  # [+name+]          Unique name of Studies record to update.
  # [+type+]          A String identifying the 'type' (kind) of Study for the updated record
  # [+lab+]           A String with the name of the lab doing the Study in the updated record
  # [+contributors+]  A String with a list of the contibutores for the updated record
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows updated.
  def updateStudyByName(name, type, lab, contributors, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_STUDY_BY_NAME)
      stmt.execute(type, lab, contributors, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_STUDY_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Study record using its id.
  # [+id+]      The studies.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyById(id)
    return deleteByFieldAndValue(:userDB, 'studies', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete Study records using their ids.
  # [+ids+]     Array of studies.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteStudiesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'studies', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: studyAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_STUDY_ATTRNAME = 'update studyAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all StudyAttrNames records
  # [+returns+] 1 row with count
  def countStudyAttrNames()
    return countRecords(:userDB, 'studyAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all StudyAttrNames records
  # [+returns+] Array of 0+ studyAttrNames records
  def selectAllStudyAttrNames()
    return selectAll(:userDB, 'studyAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrNames record by its id
  # [+id+]      The ID of the studyAttrName record to return
  # [+returns+] Array of 0 or 1 studyAttrNames records
  def selectStudyAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'studyAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrNames records using a list of ids
  # [+ids+]     Array of studyAttrNames IDs
  # [+returns+] Array of 0+ studyAttrNames records
  def selectStudyAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'studyAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrName record by its name
  # [+name+]    The unique name of the studyAttrName record to return
  # [+returns+] Array of 0 or 1 studyAttrNames records
  def selectStudyAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'studyAttrNames', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrNames using a list of names
  # [+names+]   Array of unique studyAttrNames names
  # [+returns+] Array of 0+ studyAttrNames records
  def selectStudyAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'studyAttrNames', 'name', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new StudyAttrNames record
  # [+name+]    Unique studyAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertStudyAttrName(name, state=0)
    data = [ name, state ]
    return insertStudyAttrNames(data, 1)
  end

  # Insert multiple StudyAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numStudyAttrNames+]  Number of study attribute names to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many StudyAttrNames.
  # [+returns+]     Number of rows inserted
  def insertStudyAttrNames(data, numStudyAttrNames)
    return insertRecords(:userDB, 'studyAttrNames', data, true, numStudyAttrNames, 2, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a StudyAttrName record using its id.
  # [+id+]      The studyAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'studyAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete StudyAttrName records using their ids.
  # [+ids+]     Array of studyAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'studyAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: studyAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_STUDY_ATTRVALUE = 'update studyAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all StudyAttrValues records
  # [+returns+] 1 row with count
  def countStudyAttrValues()
    return countRecords(:userDB, 'studyAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all StudyAttrValues records
  # [+returns+] Array of 0+ studyAttrValues records
  def selectAllStudyAttrValues()
    return selectAll(:userDB, 'studyAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrValues record by its id
  # [+id+]      The ID of the studyAttrValues record to return
  # [+returns+] Array of 0 or 1 studyAttrValues records
  def selectStudyAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'studyAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrValues records using a list of ids
  # [+ids+]     Array of studyAttrValues IDs
  # [+returns+] Array of 0+ studyAttrValues records
  def selectStudyAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'studyAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the studyAttrValue record to return
  # [+returns+] Array of 0 or 1 studyAttrValue records
  def selectStudyAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'studyAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the studyAttrValue records to return
  # [+returns+] Array of 0+ studyAttrNames records
  def selectStudyAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'studyAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get StudyAttrValues record by the exact value
  # [+value+]   The value of the studyAttrValue record to return
  # [+returns+] Array of 0 or 1 studyAttrValue records
  def selectStudyAttrValueByValue(value)
    return selectStudyAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get StudyAttrValues records using a list of the exact values
  # [+values+]  Array of values of the studyAttrValue records to return
  # [+returns+] Array of 0+ studyAttrNames records
  def selectStudyAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectStudyAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a study, using the attribute id.
  # "what's the value of the ___ attribute for this study?"
  #
  # [+studyId+]     The id of the study.
  # [+attrNameId+]  The id of the attribute we want the value for.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]     Array of 0-1 attribute value record
  def selectStudyAttrValueByStudyIdAndAttributeNameId(studyId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'studies', studyId, attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select the value record for a particular attribute of a study, using the attribute name (text).
  # "what's the value of the ___ attribute for this study?"
  #
  # [+studyId+]       The id of the study.
  # [+attrNameText+]  The name of the attribute we want the value for.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       Array of 0-1 attribute value record
  def selectStudyAttrValueByStudyAndAttributeNameText(studyId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'studies', studyId, attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all studies), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectStudyAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'studies', attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all studies), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]  The name of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectStudyAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'studies', attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all studies), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectStudyAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'studies', attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all studies), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectStudyAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'studies', attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular study, using attribute ids
  # "what are the current values associated with these attributes for this study, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+studyId+]       The id of the study to get attribute->value map info for
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       Array of 0+ records with the 4 columns mentioned above.
  def selectStudyAttrValueMapByEntityAndAttributeIds(studyId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'studies', studyId, attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular study, using attribute names
  # "what are the current values associated with these attributes for this study, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+studyId+]         The id of the study to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectStudyAttrValueMapByEntityAndAttributeTexts(studyId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'studies', studyId, attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new StudyAttrValues record
  # [+value+]    Unique studyAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertStudyAttrValue(value, state=0)
    data = [value, state ] # insertStudyAttrValues() will compute SHA1 for us
    return insertStudyAttrValues(data, 1)
  end

  # Insert multiple StudyAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertStudyAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numStudyAttrValues+]  Number of study attribute values to insert using values in +data+.
  #                         - This is required because the data array may be flat and yet
  #                           have the dynamic field values for many StudyAttrValues.
  # [+returns+]     Number of rows inserted
  def insertStudyAttrValues(data, numStudyAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'studyAttrValues', dataCopy, true, numStudyAttrValues, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a StudyAttrValues record using its id.
  # [+id+]      The studyAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'studyAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete StudyAttrValues records using their ids.
  # [+ids+]     Array of studyAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'studyAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a StudyAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The studyAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'studyAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete StudyAttrValues records using their sha1 digests.
  # [+ids+]     Array of studyAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'studyAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

    # Delete a StudyAttrValues record using the exact value.
  # [+sha1+]    The studyAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValueByValue(value)
    return deleteStudyAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete StudyAttrValues records using their exact values
  # [+values+]  Array of studyAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteStudyAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteStudyAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: study2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_STUDY2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from study2attributes where studyAttrName_id = ? and studyAttrValue_id = ?'
  DELETE_STUDY2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from study2attributes where study_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all Study2Attributes records
  # [+returns+] 1 row with count
  def countStudy2Attributes()
    return countRecords(:userDB, 'study2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Study2Attributes records
  # [+returns+] Array of 0+ study2attributes records
  def selectAllStudy2Attributes()
    return selectAll(:userDB, 'study2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Study2Attributes records by study_id ; i.e. get all the AVP mappings (an ID triple) for a study
  # [+studyId+] The study_id for the Study2Attributes records to return
  # [+returns+] Array of 0+ study2attributes records
  def selectStudy2AttributesByStudyId(studyId)
    return selectByFieldAndValue(:userDB, 'study2attributes', 'study_id', studyId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new Study2Attributes record ; i.e. set a new AVP for a study.
  # Note: this does NOT update any existing triple involving the study_id and the studyAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that study.
  # [+studyId+]           study_id for whom to associate an AVP
  # [+studyAttrNameId+]   studyAttrName_id for the attribute
  # [+studyAttrValueId+]  studyAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertStudy2Attribute(studyId, studyAttrNameId, studyAttrValueId)
    data = [ studyId, studyAttrNameId, studyAttrValueId ]
    return insertStudy2Attributes(data, 1)
  end

  # Insert multiple Study2Attributes records using field data.
  # If a duplicate study2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for study_id, studyAttrName_id, and studyAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numStudy2Attributes+]  Number of study2attributes to insert using values in +data+.
  #                          - This is required because the data array may be flat and yet
  #                            have the dynamic field values for many Study2Attributes.
  # [+returns+]     Number of rows inserted
  def insertStudy2Attributes(data, numStudy2Attributes)
    return insertRecords(:userDB, 'study2attributes', data, false, numStudy2Attributes, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all Study2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+studyAttrNameId+]   studyAttrName_id for tha attribute
  # [+studyAttrValueId+]  studyAttrValue_id for the attribute value
  # [+returns+]           Array of 0+ study2attributes records
  def selectStudy2AttributesByAttrNameIdAndAttrValueId(studyAttrNameId, studyAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_STUDY2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(studyAttrNameId, studyAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_STUDY2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular study's attribute.
  # All triples associating the study to an attribute will have their value replaced.
  # [+studyId+]           ID of the study whose AVP we are updating
  # [+studyAttrNameId+]   ID of studyAttrName whose value to update
  # [+studyAttrValueId+]  ID of the studyAttrValue to associate with the attribute for a particular study
  def updateStudy2AttributeForStudyAndAttrName(studyId, studyAttrNameId, studyAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteStudy2AttributesByStudyIdAndAttrNameId(studyId, studyAttrNameId)
      retVal = insertStudy2Attribute(studyId, studyAttrNameId, studyAttrValueId)
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Study2Attributes records for a given study, or for a study and attribute name,
  # or for a study and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a study, or to remove the association of a particular
  # attribute with the study, or to remove the association only if a particular value is involved.
  # [+studyId+]           study_id for which to delete some AVP info
  # [+studyAttrNameId+]   [optional] studyAttrName_id to disassociate with the study
  # [+studyAttrValueId+]  [optional] studyAttrValue_id to further restrict which AVPs are disassociate with the study
  # [+returns+]           Number of rows deleted
  def deleteStudy2AttributesByStudyIdAndAttrNameId(studyId, studyAttrNameId=nil, studyAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_STUDY2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and studyAttrName_id = ?' unless(studyAttrNameId.nil?)
      sql += ' and studyAttrValue_id = ?' unless(studyAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(studyAttrNameId.nil?)
        stmt.execute(studyId)
      elsif(studyAttrValueId.nil?)
        stmt.execute(studyId, studyAttrNameId)
      else
        stmt.execute(studyId, studyAttrNameId, studyAttrValueId)
      end
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
