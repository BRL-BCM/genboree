require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# REXPERIMENT RELATED TABLES - DBUtil Extension Methods for dealing with Experiment-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: experiments
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_EXPERIMENT_BY_ID = 'update experiments set name = ?, type = ?, study_id = ?, bioSample_id = ?, state = ? where id = ?'
  UPDATE_WHOLE_EXPERIMENT_BY_NAME = 'update experiments set type = ?, study_id = ?, bioSample_id = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Experiments records
  # [+returns+] Array of 0+ experiments record rows
  def countExperiments()
    return countRecords(:userDB, 'experiments', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Experiments records
  # [+returns+] Array of 0+ experiments record rows
  def selectAllExperiments()
    return selectAll(:userDB, 'experiments', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiment record by its id
  # [+id+]      The ID of the experiment record to return
  # [+returns+] Array of 0 or 1 experiments record rows
  def selectExperimentById(id)
    return selectByFieldAndValue(:userDB, 'experiments', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments records using a list of ids
  # [+ids+]     Array of experiment IDs
  # [+returns+] Array of 0+ boSamples records
  def selectExperimentsByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiment by its unique name
  # [+name+]    The unique name of the experiment record to return
  # [+returns+] Array of 0 or 1 experiments record
  def selectExperimentByName(name)
    return selectByFieldAndValue(:userDB, 'experiments', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments using a list of names
  # [+names+]   Array of unique experiment names
  # [+returns+] Array of 0+ experiments records
  def selectExperimentsByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'names', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments by matching an AVP by ids; get all experiments possessing the attribute
  # indicated by +experimentAttrNameId+ whose value is +experimentAttrValueId+.
  # [+experimentAttrNameId+]   experimentAttrNames.id for the experiment attribute to consider
  # [+experimentAttrValueId+]  experimentAttrValues.id for the experiment attribute value to match
  # [+returns+]                Array of 0+ experiment records
  def selectExperimentsByAttributeNameAndValueIds(experimentAttrNameId, experimentAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'experiments', experimentAttrNameId, experimentAttrValueId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments by matching an AVP by texts; get all experiments possessing the attribute
  # named in +experimentAttrNameText+ whose value is +experimentAttrValueText+.
  # [+experimentAttrNameText+]   Experiment attribute name to consider
  # [+experimentAttrValueText+]  Experiment attribute value to match
  # [+returns+]                  Array of 0+ experiment records
  def selectExperimentByAttributeNameAndValueTexts(experimentAttrNameText, experimentAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'experiments', experimentAttrNameText, experimentAttrValueText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments by their type
  # [+type+]    The type of experiments to select
  # [+returns+] Array of 0+ experiments records
  def selectExperimentsByType(type)
    return selectByFieldAndValue(:userDB, 'experiments', 'type', type, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments using a list of types
  # [+types+]   Array of experiment types
  # [+returns+] Array of 0+ experiments records
  def selectExperimentsByTypes(types)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'type', types, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments by study_id...the experiments associated with a particular study
  # [+studyId+] The studyId of experiments to select
  # [+returns+] Array of 0+ experiments records
  def selectExperimentsByStudyId(studyId)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'study_id', studyId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments by bioSample_id...the experiments associated with [using] a particular bioSample
  # [+bioSampleId+] The bioSampleId of experiments to select
  # [+returns+]     Array of 0+ experiments records
  def selectExperimentsByBioSampleId(bioSampleId)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'bioSample_id', bioSampleId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiments using a list of bioSample_ids...the experiments associated with these bioSamples
  # [+bioSampleIds+]  The bioSampleIds of experiments to select
  # [+returns+]       Array of 0+ experiments records
  def selectExperimentsByBioSampleIds(bioSampleIds)
    return selectByFieldWithMultipleValues(:userDB, 'experiments', 'type', types, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new Experiment record
  # [+name+]        Unique experiment name
  # [+type+]        A String identifying the 'type' (kind) of Experiment
  # [+studyId+]     [optional; default=nil] The studyId associated with this experiment
  # [+bioSampleId+] [optional; default=nil] The bioSample on which the experiment was carried out
  # [+state+]       [optional; default=0] for future use
  # [+returns+]     Number of rows inserted
  def insertExperiment(name, type, studyId=nil, bioSampleId=nil, state=0)
    data = [ name, type, studyId, bioSampleId, state ]
    return insertExperiments(data, 1)
  end

  # Insert multiple Experiment records using column data.
  # [+data+]           An Array of values to use for name, type, studyId, bioSampleId, state.
  #                    The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #                    See the +insertExperiment()+ method for the fields needed for each record. All 5 columns are required.
  # [+numExperiments+] Number of experiments to insert using values in +data+.
  #                    This is required because the data array may be flat and yet
  #                    have the dynamic field values for many Experiments.
  # [+returns+]        Number of rows inserted
  def insertExperiments(data, numExperiments)
    return insertRecords(:userDB, 'experiments', data, true, numExperiments, 5, false, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Update ALL the fields of a Experiment record identified by its id
  # [+id+]          Experiments.id of the record to update
  # [+name+]        Unique experiment name
  # [+type+]        A String identifying the 'type' (kind) of Experiment
  # [+studyId+]     [optional; default=nil] The studyId associated with this experiment
  # [+bioSampleId+] [optional; default=nil] The bioSample on which the experiment was carried out
  # [+state+]       [optional; default=0] for future use
  # [+returns+]     Number of rows inserted
  def updateExperimentById(id, name, type, studyId=nil, bioSampleId=nil, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_EXPERIMENT_BY_ID)
      stmt.execute(name, type, studyId, bioSampleId, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_EXPERIMENT_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identifies by its name.
  # You cannot rename the Experiment using this method.
  # [+name+]        Unique name of Experiments record to update.
  # [+type+]        A String identifying the 'type' (kind) of Experiment
  # [+studyId+]     [optional; default=nil] The studyId associated with this experiment
  # [+bioSampleId+] [optional; default=nil] The bioSample on which the experiment was carried out
  # [+state+]       [optional; default=0] for future use
  # [+returns+]     Number of rows updated.
  def updateExperimentByName(name, type, studyId=nil, bioSampleId=nil, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_EXPERIMENT_BY_NAME)
      stmt.execute(type, studyId, bioSampleId, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_EXPERIMENT_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Experiment record using its id.
  # [+id+]      The experiments.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentById(id)
    return deleteByFieldAndValue(:userDB, 'experiments', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete Experiment records using their ids.
  # [+ids+]     Array of experiments.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentsByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'experiments', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a Experiment record identified by its id as a template by updating its state
  # [+id+]            Experiments.id of the record to update
  # [+returns+]       Number of rows updated.
  def setExperimentStateToTemplate(id)
    return setStateBit(:userDB, 'experiments', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end


  # Mark a Experiment record identified by its id as completed by updating its state
  # [+id+]            Experiments.id of the record to update
  # [+returns+]       Number of rows updated.
  def setExperimentStateToCompleted(id)
    return setStateBit(:userDB, 'experiments', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end


    # Check if  a Experiment record identified by its id is a template
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isExperimentTemplate?(id)
    return checkStateBit(:userDB, 'experiments', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a Experiment record identified by its id is completed
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isExperimentCompleted?(id)
    return checkStateBit(:userDB, 'experiments', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a Experiment record identified by its id is still in progress
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the Experiment record is in progress, false otherwise
  def isExperimentInProgress?(id)
    return (not(isExperimentTemplate?(id) or isExperimentCompleted?(id)))
  end

  # --------
  # Table: experimentAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_EXPERIMENT_ATTRNAME = 'update experimentAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all ExperimentAttrNames records
  # [+returns+] 1 row with count
  def countExperimentAttrNames()
    return countRecords(:userDB, 'experimentAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all ExperimentAttrNames records
  # [+returns+] Array of 0+ experimentAttrNames records
  def selectAllExperimentAttrNames()
    return selectAll(:userDB, 'experimentAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrNames record by its id
  # [+id+]      The ID of the experimentAttrName record to return
  # [+returns+] Array of 0 or 1 experimentAttrNames records
  def selectExperimentAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'experimentAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrNames records using a list of ids
  # [+ids+]     Array of experimentAttrNames IDs
  # [+returns+] Array of 0+ experimentAttrNames records
  def selectExperimentAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'experimentAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrName record by its name
  # [+name+]    The unique name of the experimentAttrName record to return
  # [+returns+] Array of 0 or 1 experimentAttrNames records
  def selectExperimentAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'experimentAttrNames', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrNames using a list of names
  # [+names+]   Array of unique experimentAttrNames names
  # [+returns+] Array of 0+ experimentAttrNames records
  def selectExperimentAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'experimentAttrNames', 'name', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new ExperimentAttrNames record
  # [+name+]    Unique experimentAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertExperimentAttrName(name, state=0)
    data = [ name, state ]
    return insertExperimentAttrNames(data, 1)
  end

  # Insert multiple ExperimentAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numExperimentAttrNames+]  Number of experiment attribute names to insert using values in +data+.
  #                             - This is required because the data array may be flat and yet
  #                               have the dynamic field values for many ExperimentAttrNames.
  # [+returns+]     Number of rows inserted
  def insertExperimentAttrNames(data, numExperimentAttrNames)
    return insertRecords(:userDB, 'experimentAttrNames', data, true, numExperimentAttrNames, 2, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a ExperimentAttrName record using its id.
  # [+id+]      The experimentAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'experimentAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete ExperimentAttrName records using their ids.
  # [+ids+]     Array of experimentAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'experimentAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: experimentAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_EXPERIMENT_ATTRVALUE = 'update experimentAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all ExperimentAttrValues records
  # [+returns+] 1 row with count
  def countExperimentAttrValues()
    return countRecords(:userDB, 'experimentAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all ExperimentAttrValues records
  # [+returns+] Array of 0+ experimentAttrValues records
  def selectAllExperimentAttrValues()
    return selectAll(:userDB, 'experimentAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrValues record by its id
  # [+id+]      The ID of the experimentAttrValues record to return
  # [+returns+] Array of 0 or 1 experimentAttrValues records
  def selectExperimentAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'experimentAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrValues records using a list of ids
  # [+ids+]     Array of experimentAttrValues IDs
  # [+returns+] Array of 0+ experimentAttrValues records
  def selectExperimentAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'experimentAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the experimentAttrValue record to return
  # [+returns+] Array of 0 or 1 experimentAttrValue records
  def selectExperimentAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'experimentAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the experimentAttrValue records to return
  # [+returns+] Array of 0+ experimentAttrNames records
  def selectExperimentAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'experimentAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get ExperimentAttrValues record by the exact value
  # [+value+]   The value of the experimentAttrValue record to return
  # [+returns+] Array of 0 or 1 experimentAttrValue records
  def selectExperimentAttrValueByValue(value)
    return selectExperimentAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get ExperimentAttrValues records using a list of the exact values
  # [+values+]  Array of values of the experimentAttrValue records to return
  # [+returns+] Array of 0+ experimentAttrNames records
  def selectExperimentAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectExperimentAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a experiment, using the attribute id.
  # "what's the value of the ___ attribute for this experiment?"
  #
  # [+experimentId+]   The id of the experiment.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectExperimentAttrValueByExperimentIdAndAttributeNameId(experimentId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'experiments', experimentId, attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select the value record for a particular attribute of a experiment, using the attribute name (text).
  # "what's the value of the ___ attribute for this experiment?"
  #
  # [+experimentId+]   The id of the experiment.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectExperimentAttrValueByExperimentAndAttributeNameText(experimentId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'experiments', experimentId, attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all experiments), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectExperimentAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'experiments', attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all experiments), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectExperimentAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'experiments', attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all experiments), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectExperimentAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'experiments', attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all experiments), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectExperimentAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'experiments', attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular experiment, using attribute ids
  # "what are the current values associated with these attributes for this experiment, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+experimentId+]   The id of the experiment to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectExperimentAttrValueMapByEntityAndAttributeIds(experimentId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'experiments', experimentId, attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular experiment, using attribute names
  # "what are the current values associated with these attributes for this experiment, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+experimentId+]   The id of the experiment to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectExperimentAttrValueMapByEntityAndAttributeTexts(experimentId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'experiments', experimentId, attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new ExperimentAttrValues record
  # [+value+]    Unique experimentAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertExperimentAttrValue(value, state=0)
    data = [value, state ] # insertExperimentAttrValues() will compute SHA1 for us
    return insertExperimentAttrValues(data, 1)
  end

  # Insert multiple ExperimentAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertExperimentAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numExperimentAttrValues+]  Number of experiment attribute values to insert using values in +data+.
  #                              - This is required because the data array may be flat and yet
  #                                have the dynamic field values for many ExperimentAttrValues.
  # [+returns+]     Number of rows inserted
  def insertExperimentAttrValues(data, numExperimentAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'experimentAttrValues', dataCopy, true, numExperimentAttrValues, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a ExperimentAttrValues record using its id.
  # [+id+]      The experimentAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'experimentAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete ExperimentAttrValues records using their ids.
  # [+ids+]     Array of experimentAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'experimentAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a ExperimentAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The experimentAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'experimentAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete ExperimentAttrValues records using their sha1 digests.
  # [+ids+]     Array of experimentAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'experimentAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

    # Delete a ExperimentAttrValues record using the exact value.
  # [+sha1+]    The experimentAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValueByValue(value)
    return deleteExperimentAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete ExperimentAttrValues records using their exact values
  # [+values+]  Array of experimentAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteExperimentAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteExperimentAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: experiment2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_EXPERIMENT2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from experiment2attributes where experimentAttrName_id = ? and experimentAttrValue_id = ?'
  DELETE_EXPERIMENT2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from experiment2attributes where experiment_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all Experiment2Attributes records
  # [+returns+] 1 row with count
  def countExperiment2Attributes()
    return countRecords(:userDB, 'experiment2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Experiment2Attributes records
  # [+returns+] Array of 0+ experiment2attributes records
  def selectAllExperiment2Attributes()
    return selectAll(:userDB, 'experiment2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Experiment2Attributes records by experiment_id ; i.e. get all the AVP mappings (an ID triple) for a experiment
  # [+experimentId+] The experiment_id for the Experiment2Attributes records to return
  # [+returns+] Array of 0+ experiment2attributes records
  def selectExperiment2AttributesByExperimentId(experimentId)
    return selectByFieldAndValue(:userDB, 'experiment2attributes', 'experiment_id', experimentId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new Experiment2Attributes record ; i.e. set a new AVP for a experiment.
  # Note: this does NOT update any existing triple involving the experiment_id and the experimentAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that experiment.
  # [+experimentId+]           experiment_id for whom to associate an AVP
  # [+experimentAttrNameId+]   experimentAttrName_id for the attribute
  # [+experimentAttrValueId+]  experimentAttrValue_id for the attribute value
  # [+returns+]                Number of rows inserted
  def insertExperiment2Attribute(experimentId, experimentAttrNameId, experimentAttrValueId)
    data = [ experimentId, experimentAttrNameId, experimentAttrValueId ]
    return insertExperiment2Attributes(data, 1)
  end

  # Insert multiple Experiment2Attributes records using field data.
  # If a duplicate experiment2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for experiment_id, experimentAttrName_id, and experimentAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numExperiment2Attributes+]  Number of experiment2attributes to insert using values in +data+.
  #                               - This is required because the data array may be flat and yet
  #                                 have the dynamic field values for many Experiment2Attributes.
  # [+returns+]     Number of rows inserted
  def insertExperiment2Attributes(data, numExperiment2Attributes)
    return insertRecords(:userDB, 'experiment2attributes', data, false, numExperiment2Attributes, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all Experiment2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+experimentAttrNameId+]   experimentAttrName_id for tha attribute
  # [+experimentAttrValueId+]  experimentAttrValue_id for the attribute value
  # [+returns+]                Array of 0+ experiment2attributes records
  def selectExperiment2AttributesByAttrNameIdAndAttrValueId(experimentAttrNameId, experimentAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_EXPERIMENT2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(experimentAttrNameId, experimentAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_EXPERIMENT2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular experiment's attribute.
  # All triples associating the experiment to an attribute will have their value replaced.
  # [+experimentId+]           ID of the experiment whose AVP we are updating
  # [+experimentAttrNameId+]   ID of experimentAttrName whose value to update
  # [+experimentAttrValueId+]  ID of the experimentAttrValue to associate with the attribute for a particular experiment
  def updateExperiment2AttributeForExperimentAndAttrName(experimentId, experimentAttrNameId, experimentAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteExperiment2AttributesByExperimentIdAndAttrNameId(experimentId, experimentAttrNameId)
      retVal = insertExperiment2Attribute(experimentId, experimentAttrNameId, experimentAttrValueId)
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Experiment2Attributes records for a given experiment, or for a experiment and attribute name,
  # or for a experiment and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a experiment, or to remove the association of a particular
  # attribute with the experiment, or to remove the association only if a particular value is involved.
  # [+experimentId+]           experiment_id for which to delete some AVP info
  # [+experimentAttrNameId+]   [optional] experimentAttrName_id to disassociate with the experiment
  # [+experimentAttrValueId+]  [optional] experimentAttrValue_id to further restrict which AVPs are disassociate with the experiment
  # [+returns+]           Number of rows deleted
  def deleteExperiment2AttributesByExperimentIdAndAttrNameId(experimentId, experimentAttrNameId=nil, experimentAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_EXPERIMENT2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and experimentAttrName_id = ?' unless(experimentAttrNameId.nil?)
      sql += ' and experimentAttrValue_id = ?' unless(experimentAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(experimentAttrNameId.nil?)
        stmt.execute(experimentId)
      elsif(experimentAttrValueId.nil?)
        stmt.execute(experimentId, experimentAttrNameId)
      else
        stmt.execute(experimentId, experimentAttrNameId, experimentAttrValueId)
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
