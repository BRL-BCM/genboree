require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# RUN RELATED TABLES - DBUtil Extension Methods for dealing with Run-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: runs
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_RUNS_BY_TIME_RANGE = 'select * from runs where time between ? and ? '
  UPDATE_WHOLE_RUN_BY_ID = 'update runs set name = ?, type = ?, time = ?, performer = ?, location = ?, experiment_id = ?, state = ? where id = ?'
  UPDATE_WHOLE_RUN_BY_NAME = 'update runs set type = ?, time = ?, performer = ?, location = ?, experiment_id = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Runs records
  # [+returns+] Array of 0+ runs record rows
  def countRuns()
    return countRecords(:userDB, 'runs', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Runs records
  # [+returns+] Array of 0+ runs record rows
  def selectAllRuns()
    return selectAll(:userDB, 'runs', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Run record by its id
  # [+id+]      The ID of the run record to return
  # [+returns+] Array of 0 or 1 runs record rows
  def selectRunById(id)
    return selectByFieldAndValue(:userDB, 'runs', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs records using a list of ids
  # [+ids+]     Array of run IDs
  # [+returns+] Array of 0+ boSamples records
  def selectRunsByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'runs', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a run record identified by its id as a template by updating its state
  # [+id+]            Runs.id of the record to update
  # [+returns+]       Number of rows updated.
  def setRunStateToTemplate(id)
    return setStateBit(:userDB, 'runs', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a run record identified by its id as completed by updating its state
  # [+id+]            Runs.id of the record to update
  # [+returns+]       Number of rows updated.
  def setRunStateToCompleted(id)
    return setStateBit(:userDB, 'runs', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a run record identified by its id is a template
  # [+id+]            Runs.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isRunTemplate?(id)
    return checkStateBit(:userDB, 'runs', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a run record identified by its id is completed
  # [+id+]            Runs.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isRunCompleted?(id)
    return checkStateBit(:userDB, 'runs', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a run record identified by its id is still in progress
  # [+id+]            Runs.id of the record to check
  # [+returns+]       true if the run record is in progress, false otherwise
  def isRunInProgress?(id)
    return (not(isRunTemplate?(id) or isRunCompleted?(id)))
  end

  # Get Run by its unique name
  # [+name+]    The unique name of the run record to return
  # [+returns+] Array of 0 or 1 runs record
  def selectRunByName(name)
    return selectByFieldAndValue(:userDB, 'runs', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs using a list of names
  # [+names+]   Array of unique run names
  # [+returns+] Array of 0+ runs records
  def selectRunsByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'runs', 'names', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by matching an AVP via ids; get all runs possessing the attribute and its value
  # indicated by +runAttrNameId+ whose value is +runAttrValueId+.
  # [+runAttrNameId+]   runAttrNames.id for the run attribute to consider
  # [+runAttrValueId+]  runAttrValues.id for the run attribute value to match
  # [+returns+]         Array of 0+ run records
  def selectRunsByAttributeNameAndValueIds(runAttrNameId, runAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'runs', runAttrNameId, runAttrValueId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by matching an AVP by texts; get all runs possessing the attribute and its value
  # named in +runAttrNameText+ whose value is +runAttrValueText+.
  # [+runAttrNameText+]   Run attribute name to consider
  # [+runAttrValueText+]  Stdu attribute value to match
  # [+returns+]                 Array of 0+ run records
  def selectRunByAttributeNameAndValueTexts(runAttrNameText, runAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'runs', runAttrNameText, runAttrValueText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by their type
  # [+type+]    The type of runs to select
  # [+returns+] Array of 0+ runs records
  def selectRunsByType(type)
    return selectByFieldAndValue(:userDB, 'runs', 'type', type, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs using a list of types
  # [+types+]   Array of run types
  # [+returns+] Array of 0+ runs records
  def selectRunsByTypes(types)
    return selectByFieldWithMultipleValues(:userDB, 'runs', 'type', types, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by exact performer
  # [+performer+] The performer of the experimental runs to select
  # [+returns+]   Array of 0+ runs records
  def selectRunsByPerformer(performer)
    return selectByFieldAndValue(:userDB, 'runs', 'performer', performer, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by the location where it was performed
  # [+location+]  The location of the experimental runs to select
  # [+returns+]   Array of 0+ runs records
  def selectRunsByLocation(location)
    return selectByFieldAndValue(:userDB, 'runs', 'location', location, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs by their experiment_id (i.e. the runs associated with a particular experiment)
  # [+experimentId+]  The experimentId for runs to select
  # [+returns+]       Array of 0+ runs records
  def selectRunsByExperimentId(experimentId)
    return selectByFieldAndValue(:userDB, 'runs', 'experiment_id', experimentId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs using a list of experiment_ids (i.e. the runs for these experiments)
  # [+experimentIds+] Array of experiment_ids
  # [+returns+]       Array of 0+ runs records
  def selectRunsByExperimentIds(experimentIds)
    return selectByFieldWithMultipleValues(:userDB, 'runs', 'experiment_id', experimentIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Runs falling between two Times. E.g. for reports.
  # The time range is fully closed, so runs with times falled exactly on
  # the +startTime+ or +endTime+ will be returned
  #
  # +startTime+ and +endTime+ are best as Ruby Time objects,
  # or strings like YYYY-MM-DD or strings like YYYY-MM-DD HH:MM
  #
  # [+startTime+] Start time for the range.
  # [+endTime+]   End time for the range
  # [+returns+]   Array of 0+ runs records
  def selectRunsByTimeRange(startTime, endTime)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_RUNS_BY_TIME_RANGE)
      stmt.execute(startTime, endTime)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_RUNS_BY_TIME_RANGE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new Run record
  # [+name+]          Unique experimental run name
  # [+type+]          A String identifying the 'type' (kind) of Run
  # [+time+]          When the experimental run was performed. (Ruby Time object best, or string like YYYY-MM-DD, or string like YYYY-MM-DD HH:MM:SS)
  # [+performer+]     Who performed the experimental run.
  # [+location+]      Where the experimental run was performed.
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this run
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def insertRun(name, type, time, performer, location, experimentId=nil, state=0)
    data = [ name, type, time, performer, location, experimentId, state ]
    return insertRuns(data, 1)
  end

  # Insert multiple Run records using column data.
  # [+data+]    An Array of values to use for name, type, studyId, bioSampleId, state.
  #             The Array may be 2-D (i.e. N rows of 7 columns or simply a flat array with appropriate values)
  #             See the +insertRun()+ method for the fields needed for each record. All 7 columns are required.
  # [+numRuns+] Number of runs to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Runs.
  # [+returns+] Number of rows inserted
  def insertRuns(data, numRuns)
    return insertRecords(:userDB, 'runs', data, true, numRuns, 7, false, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Update ALL the fields of a Run record identified by its id
  # [+id+]            Runs.id of the record to update
  # [+name+]          Unique run name
  # [+type+]          A String identifying the 'type' (kind) of Run
  # [+time+]          When the experimental run was performed. (Ruby Time object best, or string like YYYY-MM-DD)
  # [+performer+]     Who performed the experimental run.
  # [+location+]      Where the experimental run was performed.
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this run
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def updateRunById(id, name, type, time, performer, location, experimentId=nil, state=0)
    retVal = nil
    if(time.is_a?(Time))
      time = time.strftime("%Y-%m-%d %H:%M:%S")
    end
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_RUN_BY_ID)
      stmt.execute(name, type, time, performer, location, experimentId, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_RUN_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identifies by its name.
  # You cannot rename the Run using this method.
  # [+name+]          Unique name of Runs record to update.
  # [+type+]          A String identifying the 'type' (kind) of Run
  # [+time+]          When the experimental run was performed. (Ruby Time object best, or string like YYYY-MM-DD)
  # [+performer+]     Who performed the experimental run.
  # [+location+]      Where the experimental run was performed.
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this run
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows updated.
  def updateRunByName(name, type, time, performer, location, experimentId=nil, state=0)
    retVal = nil
    if(time.is_a?(Time))
      time = time.strftime("%Y-%m-%d %H:%M:%S")
    end
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_RUN_BY_NAME)
      stmt.execute(type, time, performer, location, experimentId, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_RUN_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Run record using its id.
  # [+id+]      The runs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteRunById(id)
    return deleteByFieldAndValue(:userDB, 'runs', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete Run records using their ids.
  # [+ids+]     Array of runs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteRunsByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'runs', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: runAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_RUN_ATTRNAME = 'update runAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all RunAttrNames records
  # [+returns+] 1 row with count
  def countRunAttrNames()
    return countRecords(:userDB, 'runAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all RunAttrNames records
  # [+returns+] Array of 0+ runAttrNames records
  def selectAllRunAttrNames()
    return selectAll(:userDB, 'runAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrNames record by its id
  # [+id+]      The ID of the runAttrName record to return
  # [+returns+] Array of 0 or 1 runAttrNames records
  def selectRunAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'runAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrNames records using a list of ids
  # [+ids+]     Array of runAttrNames IDs
  # [+returns+] Array of 0+ runAttrNames records
  def selectRunAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'runAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrName record by its name
  # [+name+]    The unique name of the runAttrName record to return
  # [+returns+] Array of 0 or 1 runAttrNames records
  def selectRunAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'runAttrNames', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrNames using a list of names
  # [+names+]   Array of unique runAttrNames names
  # [+returns+] Array of 0+ runAttrNames records
  def selectRunAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'runAttrNames', 'name', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new RunAttrNames record
  # [+name+]    Unique runAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertRunAttrName(name, state=0)
    data = [ name, state ]
    return insertRunAttrNames(data, 1)
  end

  # Insert multiple RunAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numRunAttrNames+]  Number of run attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many RunAttrNames.
  # [+returns+]     Number of rows inserted
  def insertRunAttrNames(data, numRunAttrNames)
    return insertRecords(:userDB, 'runAttrNames', data, true, numRunAttrNames, 2, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a RunAttrName record using its id.
  # [+id+]      The runAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'runAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete RunAttrName records using their ids.
  # [+ids+]     Array of runAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'runAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: runAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_RUN_ATTRVALUE = 'update runAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all RunAttrValues records
  # [+returns+] 1 row with count
  def countRunAttrValues()
    return countRecords(:userDB, 'runAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all RunAttrValues records
  # [+returns+] Array of 0+ runAttrValues records
  def selectAllRunAttrValues()
    return selectAll(:userDB, 'runAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrValues record by its id
  # [+id+]      The ID of the runAttrValues record to return
  # [+returns+] Array of 0 or 1 runAttrValues records
  def selectRunAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'runAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrValues records using a list of ids
  # [+ids+]     Array of runAttrValues IDs
  # [+returns+] Array of 0+ runAttrValues records
  def selectRunAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'runAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the runAttrValue record to return
  # [+returns+] Array of 0 or 1 runAttrValue records
  def selectRunAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'runAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the runAttrValue records to return
  # [+returns+] Array of 0+ runAttrNames records
  def selectRunAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'runAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get RunAttrValues record by the exact value
  # [+value+]   The value of the runAttrValue record to return
  # [+returns+] Array of 0 or 1 runAttrValue records
  def selectRunAttrValueByValue(value)
    return selectRunAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get RunAttrValues records using a list of the exact values
  # [+values+]  Array of values of the runAttrValue records to return
  # [+returns+] Array of 0+ runAttrNames records
  def selectRunAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectRunAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a run, using the attribute id.
  # "what's the value of the ___ attribute for this run?"
  #
  # [+runId+]           The id of the run.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectRunAttrValueByRunIdAndAttributeNameId(runId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'runs', runId, attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select the value record for a particular attribute of a run, using the attribute name (text).
  # "what's the value of the ___ attribute for this run?"
  #
  # [+runId+]   The id of the run.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectRunAttrValueByRunAndAttributeNameText(runId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'runs', runId, attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all runs), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectRunAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'runs', attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all runs), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectRunAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'runs', attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all runs), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectRunAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'runs', attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all runs), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectRunAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'runs', attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular run, using attribute ids
  # "what are the current values associated with these attributes for this run, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+runId+]   The id of the run to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectRunAttrValueMapByEntityAndAttributeIds(runId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'runs', runId, attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular run, using attribute names
  # "what are the current values associated with these attributes for this run, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+runId+]   The id of the run to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectRunAttrValueMapByEntityAndAttributeTexts(runId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'runs', runId, attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new RunAttrValues record
  # [+value+]    Unique runAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertRunAttrValue(value, state=0)
    data = [value, state ] # insertRunAttrValues() will compute SHA1 for us
    return insertRunAttrValues(data, 1)
  end

  # Insert multiple RunAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertRunAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numRunAttrValues+]  Number of run attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many RunAttrValues.
  # [+returns+]     Number of rows inserted
  def insertRunAttrValues(data, numRunAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'runAttrValues', dataCopy, true, numRunAttrValues, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a RunAttrValues record using its id.
  # [+id+]      The runAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'runAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete RunAttrValues records using their ids.
  # [+ids+]     Array of runAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'runAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a RunAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The runAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'runAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete RunAttrValues records using their sha1 digests.
  # [+ids+]     Array of runAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'runAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

    # Delete a RunAttrValues record using the exact value.
  # [+sha1+]    The runAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValueByValue(value)
    return deleteRunAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete RunAttrValues records using their exact values
  # [+values+]  Array of runAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteRunAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteRunAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: run2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_RUN2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from run2attributes where runAttrName_id = ? and runAttrValue_id = ?'
  DELETE_RUN2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from run2attributes where run_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Run2Attributes records
  # [+returns+] 1 row with count
  def countRun2Attributes()
    return countRecords(:userDB, 'run2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all Run2Attributes records
  # [+returns+] Array of 0+ run2attributes records
  def selectAllRun2Attributes()
    return selectAll(:userDB, 'run2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get Run2Attributes records by run_id ; i.e. get all the AVP mappings (an ID triple) for a run
  # [+runId+]   The run_id for the Run2Attributes records to return
  # [+returns+] Array of 0+ run2attributes records
  def selectRun2AttributesByRunId(runId)
    return selectByFieldAndValue(:userDB, 'run2attributes', 'run_id', runId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new Run2Attributes record ; i.e. set a new AVP for a run.
  # Note: this does NOT update any existing triple involving the run_id and the runAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that run.
  # [+runId+]             run_id for whom to associate an AVP
  # [+runAttrNameId+]     runAttrName_id for the attribute
  # [+runAttrValueId+]    runAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertRun2Attribute(runId, runAttrNameId, runAttrValueId)
    data = [ runId, runAttrNameId, runAttrValueId ]
    return insertRun2Attributes(data, 1)
  end

  # Insert multiple Run2Attributes records using field data.
  # If a duplicate run2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for run_id, runAttrName_id, and runAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numRun2Attributes+]  Number of run2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Run2Attributes.
  # [+returns+]     Number of rows inserted
  def insertRun2Attributes(data, numRun2Attributes)
    return insertRecords(:userDB, 'run2attributes', data, false, numRun2Attributes, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all Run2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+runAttrNameId+]   runAttrName_id for tha attribute
  # [+runAttrValueId+]  runAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ run2attributes records
  def selectRun2AttributesByAttrNameIdAndAttrValueId(runAttrNameId, runAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_RUN2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(runAttrNameId, runAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_RUN2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular run's attribute.
  # All triples associating the run to an attribute will have their value replaced.
  # [+runId+]           ID of the run whose AVP we are updating
  # [+runAttrNameId+]   ID of runAttrName whose value to update
  # [+runAttrValueId+]  ID of the runAttrValue to associate with the attribute for a particular run
  def updateRun2AttributeForRunAndAttrName(runId, runAttrNameId, runAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteRun2AttributesByRunIdAndAttrNameId(runId, runAttrNameId)
      retVal = insertRun2Attribute(runId, runAttrNameId, runAttrValueId)
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Run2Attributes records for a given run, or for a run and attribute name,
  # or for a run and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a run, or to remove the association of a particular
  # attribute with the run, or to remove the association only if a particular value is involved.
  # [+runId+]           run_id for which to delete some AVP info
  # [+runAttrNameId+]   [optional] runAttrName_id to disassociate with the run
  # [+runAttrValueId+]  [optional] runAttrValue_id to further restrict which AVPs are disassociate with the run
  # [+returns+]         Number of rows deleted
  def deleteRun2AttributesByRunIdAndAttrNameId(runId, runAttrNameId=nil, runAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_RUN2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and runAttrName_id = ?' unless(runAttrNameId.nil?)
      sql += ' and runAttrValue_id = ?' unless(runAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(runAttrNameId.nil?)
        stmt.execute(runId)
      elsif(runAttrValueId.nil?)
        stmt.execute(runId, runAttrNameId)
      else
        stmt.execute(runId, runAttrNameId, runAttrValueId)
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
