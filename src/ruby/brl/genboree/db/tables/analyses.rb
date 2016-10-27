require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# ANALYSIS RELATED TABLES - DBUtil Extension Methods for dealing with Analysis-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: analyses
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_ANALYSIS_BY_ID = 'update analyses set name = ?, type = ?, dataLevel = ?, experiment_id = ?, state = ? where id = ?'
  UPDATE_WHOLE_ANALYSIS_BY_NAME = 'update analyses set type = ?, dataLevel = ?, experiment_id = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Analyses records
  # [+returns+] Array of 0+ analyses record rows
  def countAnalyses()
    return countRecords(:userDB, 'analyses', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Analyses records
  # [+returns+] Array of 0+ analyses record rows
  def selectAllAnalyses()
    return selectAll(:userDB, 'analyses', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analysis record by its id
  # [+id+]      The ID of the analysis record to return
  # [+returns+] Array of 0 or 1 analyses record rows
  def selectAnalysisById(id)
    return selectByFieldAndValue(:userDB, 'analyses', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses records using a list of ids
  # [+ids+]     Array of analysis IDs
  # [+returns+] Array of 0+ analyses records
  def selectAnalysesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'analyses', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analysis by its unique name
  # [+name+]    The unique name of the analysis record to return
  # [+returns+] Array of 0 or 1 analyses record
  def selectAnalysisByName(name)
    return selectByFieldAndValue(:userDB, 'analyses', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses using a list of names
  # [+names+]   Array of unique analysis names
  # [+returns+] Array of 0+ analyses records
  def selectAnalysesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'analyses', 'names', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses by matching an AVP via ids; get all analyses possessing the attribute and its value
  # indicated by +analysisAttrNameId+ whose value is +analysisAttrValueId+.
  # [+analysisAttrNameId+]   analysisAttrNames.id for the analysis attribute to consider
  # [+analysisAttrValueId+]  analysisAttrValues.id for the analysis attribute value to match
  # [+returns+]         Array of 0+ analysis records
  def selectAnalysesByAttributeNameAndValueIds(analysisAttrNameId, analysisAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'analyses', analysisAttrNameId, analysisAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses by matching an AVP by texts; get all analyses possessing the attribute and its value
  # named in +analysisAttrNameText+ whose value is +analysisAttrValueText+.
  # [+analysisAttrNameText+]   Analysis attribute name to consider
  # [+analysisAttrValueText+]  Analysis attribute value to match
  # [+returns+]                 Array of 0+ analysis records
  def selectAnalysesByAttributeNameAndValueTexts(analysisAttrNameText, analysisAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'analyses', analysisAttrNameText, analysisAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses by their type
  # [+type+]    The type of analyses to select
  # [+returns+] Array of 0+ analyses records
  def selectAnalysesByType(type)
    return selectByFieldAndValue(:userDB, 'analyses', 'type', type, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses using a list of types
  # [+types+]   Array of analysis types
  # [+returns+] Array of 0+ analyses records
  def selectAnalysesByTypes(types)
    return selectByFieldWithMultipleValues(:userDB, 'analyses', 'type', types, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses by their dataLevel
  # [+dataLevel+] The dataLevel of the experimental analyses to select
  # [+returns+]   Array of 0+ analyses records
  def selectAnalysesByDataLevel(dataLevel)
    return selectByFieldAndValue(:userDB, 'analyses', 'dataLevel', dataLevel, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses using a list of dataLevels
  # [+dataLevels+] Array of dataLevels
  # [+returns+]   Array of 0+ analyses records
  def selectAnalysesByDataLevels(dataLevels)
    return selectByFieldWithMultipleValues(:userDB, 'analyses', 'dataLevel', dataLevels, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses by their experiment_id (i.e. the analyses associated with a particular experiment)
  # [+experimentId+]  The experimentId for analyses to select
  # [+returns+]       Array of 0+ analyses records
  def selectAnalysesByExperimentId(experimentId)
    return selectByFieldAndValue(:userDB, 'analyses', 'experiment_id', experimentId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analyses using a list of experiment_ids (i.e. the analyses for these experiments)
  # [+experimentIds+] Array of experiment_ids
  # [+returns+]       Array of 0+ analyses records
  def selectAnalysesByExperimentIds(experimentIds)
    return selectByFieldWithMultipleValues(:userDB, 'analyses', 'experiment_id', experimentIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Analysis record
  # [+name+]          Unique experimental analysis name
  # [+type+]          A String identifying the 'type' (kind) of Analysis
  # [+dataLevel+]     The dataLevel of this analysis
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this analysis
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def insertAnalysis(name, type, dataLevel, experimentId=nil, state=0)
    data = [ name, type, dataLevel, experimentId, state ]
    return insertAnalyses(data, 1)
  end

  # Insert multiple Analysis records using column data.
  # [+data+]    An Array of values to use for name, type, dataLevel, experimentId, state.
  #             The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #             See the +insertAnalysis()+ method for the fields needed for each record. All 5 columns are required.
  # [+numAnalyses+] Number of analyses to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Analyses.
  # [+returns+] Number of rows inserted
  def insertAnalyses(data, numAnalyses)
    return insertRecords(:userDB, 'analyses', data, true, numAnalyses, 5, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a Analysis record identified by its id
  # [+id+]            Analyses.id of the record to update
  # [+name+]          Unique analysis name
  # [+type+]          A String identifying the 'type' (kind) of Analysis
  # [+dataLevel+]     The dataLevel of this analysis
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this analysis
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def updateAnalysisById(id, name, type, dataLevel, experimentId=nil, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_ANALYSIS_BY_ID)
      stmt.execute(name, type, dataLevel, experimentId, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_ANALYSIS_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the Analysis using this method.
  # [+name+]          Unique name of Analyses record to update.
  # [+type+]          A String identifying the 'type' (kind) of Analysis
  # [+dataLevel+]     The dataLevel of this analysis
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this analysis
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows updated.
  def updateAnalysisByName(name, type, dataLevel, experimentId=nil, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_ANALYSIS_BY_NAME)
      stmt.execute(type, dataLevel, experimentId, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_ANALYSIS_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Analysis record using its id.
  # [+id+]      The analyses.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisById(id)
    return deleteByFieldAndValue(:userDB, 'analyses', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Analysis records using their ids.
  # [+ids+]     Array of analyses.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'analyses', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: analysisAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_ANALYSIS_ATTRNAME = 'update analysisAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all AnalysisAttrNames records
  # [+returns+] 1 row with count
  def countAnalysisAttrNames()
    return countRecords(:userDB, 'analysisAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all AnalysisAttrNames records
  # [+returns+] Array of 0+ analysisAttrNames records
  def selectAllAnalysisAttrNames()
    return selectAll(:userDB, 'analysisAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrNames record by its id
  # [+id+]      The ID of the analysisAttrName record to return
  # [+returns+] Array of 0 or 1 analysisAttrNames records
  def selectAnalysisAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'analysisAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrNames records using a list of ids
  # [+ids+]     Array of analysisAttrNames IDs
  # [+returns+] Array of 0+ analysisAttrNames records
  def selectAnalysisAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'analysisAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrName record by its name
  # [+name+]    The unique name of the analysisAttrName record to return
  # [+returns+] Array of 0 or 1 analysisAttrNames records
  def selectAnalysisAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'analysisAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrNames using a list of names
  # [+names+]   Array of unique analysisAttrNames names
  # [+returns+] Array of 0+ analysisAttrNames records
  def selectAnalysisAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'analysisAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new AnalysisAttrNames record
  # [+name+]    Unique analysisAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertAnalysisAttrName(name, state=0)
    data = [ name, state ]
    return insertAnalysisAttrNames(data, 1)
  end

  # Insert multiple AnalysisAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numAnalysisAttrNames+]  Number of analysis attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many AnalysisAttrNames.
  # [+returns+]     Number of rows inserted
  def insertAnalysisAttrNames(data, numAnalysisAttrNames)
    return insertRecords(:userDB, 'analysisAttrNames', data, true, numAnalysisAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a AnalysisAttrName record using its id.
  # [+id+]      The analysisAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'analysisAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete AnalysisAttrName records using their ids.
  # [+ids+]     Array of analysisAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'analysisAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: analysisAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_ANALYSIS_ATTRVALUE = 'update analysisAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all AnalysisAttrValues records
  # [+returns+] 1 row with count
  def countAnalysisAttrValues()
    return countRecords(:userDB, 'analysisAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all AnalysisAttrValues records
  # [+returns+] Array of 0+ analysisAttrValues records
  def selectAllAnalysisAttrValues()
    return selectAll(:userDB, 'analysisAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrValues record by its id
  # [+id+]      The ID of the analysisAttrValues record to return
  # [+returns+] Array of 0 or 1 analysisAttrValues records
  def selectAnalysisAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'analysisAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrValues records using a list of ids
  # [+ids+]     Array of analysisAttrValues IDs
  # [+returns+] Array of 0+ analysisAttrValues records
  def selectAnalysisAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'analysisAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the analysisAttrValue record to return
  # [+returns+] Array of 0 or 1 analysisAttrValue records
  def selectAnalysisAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'analysisAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the analysisAttrValue records to return
  # [+returns+] Array of 0+ analysisAttrNames records
  def selectAnalysisAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'analysisAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get AnalysisAttrValues record by the exact value
  # [+value+]   The value of the analysisAttrValue record to return
  # [+returns+] Array of 0 or 1 analysisAttrValue records
  def selectAnalysisAttrValueByValue(value)
    return selectAnalysisAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get AnalysisAttrValues records using a list of the exact values
  # [+values+]  Array of values of the analysisAttrValue records to return
  # [+returns+] Array of 0+ analysisAttrNames records
  def selectAnalysisAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectAnalysisAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a analysis, using the attribute id.
  # "what's the value of the ___ attribute for this analysis?"
  #
  # [+analysisId+]           The id of the analysis.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectAnalysisAttrValueByAnalysisIdAndAttributeNameId(analysisId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'analyses', analysisId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a analysis, using the attribute name (text).
  # "what's the value of the ___ attribute for this analysis?"
  #
  # [+analysisId+]   The id of the analysis.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectAnalysisAttrValueByAnalysisAndAttributeNameText(analysisId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'analyses', analysisId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all analyses), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectAnalysisAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'analyses', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all analyses), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectAnalysisAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'analyses', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all analyses), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectAnalysisAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'analyses', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all analyses), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectAnalysisAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'analyses', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular analysis, using attribute ids
  # "what are the current values associated with these attributes for this analysis, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+analysisId+]   The id of the analysis to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectAnalysisAttrValueMapByEntityAndAttributeIds(analysisId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'analyses', analysisId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular analysis, using attribute names
  # "what are the current values associated with these attributes for this analysis, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+analysisId+]   The id of the analysis to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectAnalysisAttrValueMapByEntityAndAttributeTexts(analysisId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'analyses', analysisId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new AnalysisAttrValues record
  # [+value+]    Unique analysisAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertAnalysisAttrValue(value, state=0)
    data = [value, state ] # insertAnalysisAttrValues() will compute SHA1 for us
    return insertAnalysisAttrValues(data, 1)
  end

  # Insert multiple AnalysisAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertAnalysisAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numAnalysisAttrValues+]  Number of analysis attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many AnalysisAttrValues.
  # [+returns+]     Number of rows inserted
  def insertAnalysisAttrValues(data, numAnalysisAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'analysisAttrValues', dataCopy, true, numAnalysisAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a AnalysisAttrValues record using its id.
  # [+id+]      The analysisAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'analysisAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete AnalysisAttrValues records using their ids.
  # [+ids+]     Array of analysisAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'analysisAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a AnalysisAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The analysisAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'analysisAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete AnalysisAttrValues records using their sha1 digests.
  # [+ids+]     Array of analysisAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'analysisAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a AnalysisAttrValues record using the exact value.
  # [+sha1+]    The analysisAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValueByValue(value)
    return deleteAnalysisAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete AnalysisAttrValues records using their exact values
  # [+values+]  Array of analysisAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteAnalysisAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteAnalysisAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: analysis2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_ANALYSIS2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from analysis2attributes where analysisAttrName_id = ? and analysisAttrValue_id = ?'
  DELETE_ANALYSIS2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from analysis2attributes where analysis_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Analysis2Attributes records
  # [+returns+] 1 row with count
  def countAnalysis2Attributes()
    return countRecords(:userDB, 'analysis2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Analysis2Attributes records
  # [+returns+] Array of 0+ analysis2attributes records
  def selectAllAnalysis2Attributes()
    return selectAll(:userDB, 'analysis2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Analysis2Attributes records by analysis_id ; i.e. get all the AVP mappings (an ID triple) for a analysis
  # [+analysisId+]   The analysis_id for the Analysis2Attributes records to return
  # [+returns+] Array of 0+ analysis2attributes records
  def selectAnalysis2AttributesByAnalysisId(analysisId)
    return selectByFieldAndValue(:userDB, 'analysis2attributes', 'analysis_id', analysisId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Analysis2Attributes record ; i.e. set a new AVP for a analysis.
  # Note: this does NOT update any existing triple involving the analysis_id and the analysisAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that analysis.
  # [+analysisId+]             analysis_id for whom to associate an AVP
  # [+analysisAttrNameId+]     analysisAttrName_id for the attribute
  # [+analysisAttrValueId+]    analysisAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertAnalysis2Attribute(analysisId, analysisAttrNameId, analysisAttrValueId)
    data = [ analysisId, analysisAttrNameId, analysisAttrValueId ]
    return insertAnalysis2Attributes(data, 1)
  end

  # Insert multiple Analysis2Attributes records using field data.
  # If a duplicate analysis2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for analysis_id, analysisAttrName_id, and analysisAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numAnalysis2Attributes+]  Number of analysis2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Analysis2Attributes.
  # [+returns+]     Number of rows inserted
  def insertAnalysis2Attributes(data, numAnalysis2Attributes)
    return insertRecords(:userDB, 'analysis2attributes', data, false, numAnalysis2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Analysis2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+analysisAttrNameId+]   analysisAttrName_id for tha attribute
  # [+analysisAttrValueId+]  analysisAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ analysis2attributes records
  def selectAnalysis2AttributesByAttrNameIdAndAttrValueId(analysisAttrNameId, analysisAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_ANALYSIS2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(analysisAttrNameId, analysisAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_ANALYSIS2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular analysis's attribute.
  # All triples associating the analysis to an attribute will have their value replaced.
  # [+analysisId+]           ID of the analysis whose AVP we are updating
  # [+analysisAttrNameId+]   ID of analysisAttrName whose value to update
  # [+analysisAttrValueId+]  ID of the analysisAttrValue to associate with the attribute for a particular analysis
  def updateAnalysis2AttributeForAnalysisAndAttrName(analysisId, analysisAttrNameId, analysisAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteAnalysis2AttributesByAnalysisIdAndAttrNameId(analysisId, analysisAttrNameId)
      retVal = insertAnalysis2Attribute(analysisId, analysisAttrNameId, analysisAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Analysis2Attributes records for a given analysis, or for a analysis and attribute name,
  # or for a analysis and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a analysis, or to remove the association of a particular
  # attribute with the analysis, or to remove the association only if a particular value is involved.
  # [+analysisId+]           analysis_id for which to delete some AVP info
  # [+analysisAttrNameId+]   [optional] analysisAttrName_id to disassociate with the analysis
  # [+analysisAttrValueId+]  [optional] analysisAttrValue_id to further restrict which AVPs are disassociate with the analysis
  # [+returns+]         Number of rows deleted
  def deleteAnalysis2AttributesByAnalysisIdAndAttrNameId(analysisId, analysisAttrNameId=nil, analysisAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_ANALYSIS2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and analysisAttrName_id = ?' unless(analysisAttrNameId.nil?)
      sql += ' and analysisAttrValue_id = ?' unless(analysisAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(analysisAttrNameId.nil?)
        stmt.execute(analysisId)
      elsif(analysisAttrValueId.nil?)
        stmt.execute(analysisId, analysisAttrNameId)
      else
        stmt.execute(analysisId, analysisAttrNameId, analysisAttrValueId)
      end
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
