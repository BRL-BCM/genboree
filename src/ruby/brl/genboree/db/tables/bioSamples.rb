require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# BIOSAMPLE RELATED TABLES - DBUtil Extension Methods for dealing with BioSample-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # TABLE: bioSamples
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_BIOSAMPLES_BY_SOURCE_AND_STATE = 'select * from bioSamples where biomaterialSource = ? and biomaterialState = ? '
  UPDATE_WHOLE_BIOSAMPLE_BY_ID = 'update bioSamples set name = ?, type = ?, biomaterialState = ?, biomaterialProvider = ?, biomaterialSource = ?, state = ? where id = ?'
  UPDATE_WHOLE_BIOSAMPLE_BY_NAME = 'update bioSamples set type = ?, biomaterialState = ?, biomaterialProvider = ?, biomaterialSource = ?, state = ? where name = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSamples records
  # [+returns+] 1 row with count
  def countBioSamples()
    return countRecords(:userDB, 'bioSamples', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all distinct BioSample names
  # [+returns+] Array of 0+ bioSmaple name rows
  def selectDistinctBioSampleNames()
    return selectDistinctValues(:userDB, 'bioSamples', 'name', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all BioSamples records
  # [+returns+] Array of 0+ bioSamples record rows
  def selectAllBioSamples()
    return selectAll(:userDB, 'bioSamples', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSample record by its id
  # [+id+]      The ID of the bioSample record to return
  # [+returns+] Array of 0 or 1 bioSamples record rows
  def selectBioSampleById(id)
    return selectByFieldAndValue(:userDB, 'bioSamples', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples records using a list of ids
  # [+ids+]     Array of bioSample IDs
  # [+returns+] Array of 0+ boSamples records
  def selectBioSamplesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSamples', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSample by its unique name
  # [+name+]    The unique name of the bioSample record to return
  # [+returns+] Array of 0 or 1 bioSamples record
  def selectBioSampleByName(name)
    return selectByFieldAndValue(:userDB, 'bioSamples', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples using a list of names
  # [+names+]   Array of unique bioSample names
  # [+returns+] Array of 0+ bioSamples records
  def selectBioSamplesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'bioSamples', 'name', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples using a pattern for their names
  # [+pattern+] String to match sample names to
  # [+returns+] Array of 0+ bioSamples records
  def selectBioSamplesByNameLike(pattern)
    return selectByFieldAndKeyword(:userDB, 'bioSamples', 'name', pattern, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  SQL_PATTERN_selectBioSamplesByNameRegexp = 'select * from {tableName} where {fieldName} regexp '
  def selectBioSamplesByNameRegexp(pattern)
    retVal = sql = nil

    tableType = :userDB
    tableName = "bioSamples"
    fieldName = "name"
    # pattern = pattern
    errMsg = "#{File.basename(__FILE__)} => #{__method__}{}: "
    extraOpts = nil

    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectBioSamplesByNameRegexp.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << "'#{DBUtil.mysql2gsubSafeEsc(pattern)}'"
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)

      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Get BioSamples by matching an AVP by ids; get all bioSamples possessing the attribute and its value
  # indicated by +bioSampleAttrNameId+ whose value is +bioSampleAttrValueId+.
  # [+bioSampleAttrNameId+]   bioSampleAttrNames.id for the bioSample attribute to consider
  # [+bioSampleAttrValueId+]  bioSampleAttrValues.id for the bioSample attribute value to match
  # [+returns+]               Array of 0+ bioSample records
  def selectBioSamplesByAttributeNameAndValueIds(bioSampleAttrNameId, bioSampleAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'bioSamples', bioSampleAttrNameId, bioSampleAttrValueId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples by matching an AVP by texts; get all bioSamples possessing the attribute and its value
  # named in +bioSampleAttrNameText+ whose value is +bioSampleAttrValueText+.
  # [+bioSampleAttrNameText+]   BioSample attribute name to consider
  # [+bioSampleAttrValueText+]  BioSample attribute value to match
  # [+returns+]                 Array of 0+ bioSample records
  def selectBioSampleByAttributeNameAndValueTexts(bioSampleAttrNameText, bioSampleAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'bioSamples', bioSampleAttrNameText, bioSampleAttrValueText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples by their biomaterialSource
  # [+biomaterialSource+] The biomaterialSource of bioSamples to select
  # [+returns+]           Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialSource(biomaterialSource)
    return selectByFieldAndValue(:userDB, 'bioSamples', 'biomaterialSource', biomaterialSource, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples using a list of biomaterialSources
  # [+biomaterialSources+]  Array of bioSample biomaterialSources
  # [+returns+]             Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialSources(biomaterialSources)
    return selectByFieldWithMultipleValues(:userDB, 'bioSamples', 'biomaterialSource', biomaterialSources, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples by their biomaterialState
  # [+biomaterialState+]  The biomaterialState of bioSamples to select
  # [+returns+]           Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialState(biomaterialState)
    return selectByFieldAndValue(:userDB, 'bioSamples', 'biomaterialState', biomaterialState, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples using a list of biomaterialStates
  # [+biomaterialStates+] Array of bioSample biomaterialStates
  # [+returns+]           Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialStates(biomaterialStates)
    return selectByFieldWithMultipleValues(:userDB, 'bioSamples', 'biomaterialState', biomaterialStates, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples by their biomaterialProvider
  # [+biomaterialProvider+] The biomaterialProvider of bioSamples to select
  # [+returns+]             Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialProvider(biomaterialProvider)
    return selectByFieldAndValue(:userDB, 'bioSamples', 'biomaterialProvider', biomaterialProvider, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples using a list of biomaterialProviders
  # [+biomaterialProviders+]  Array of bioSample biomaterialProviders
  # [+returns+]               Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialProviders(biomaterialProviders)
    return selectByFieldWithMultipleValues(:userDB, 'bioSamples', 'biomaterialProvider', biomaterialProviders, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSamples by their biomaterialSource AND biomaterialState
  # [+biomaterialSource+] The biomaterialSource of bioSamples to select
  # [+biomaterialState+]  The biomaterialState of bioSamples to select
  # [+returns+]           Array of 0+ bioSamples records
  def selectBioSamplesByBiomaterialSourceAndState(biomaterialSource, biomaterialState)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_BIOSAMPLES_BY_SOURCE_AND_STATE)
      stmt.execute(biomaterialSource, biomaterialState)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_BIOSAMPLES_BY_SOURCE_AND_STATE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new BioSample record
  # [+name+]                Unique bioSample name
  # [+type+]                A String identifying the 'type' (kind) of BioSample
  # [+biomaterialState+]    A String indicating the state of the material (e.g. healthy, diseased, etc etc)
  # [+biomaterialProvider+] A String indicating the provider of the material (e.g. a lab, person, institution, etc etc)
  # [+biomaterialSource+]   A String inidicating the source of the material (e.g. cell line, cell line name, tissue, other identifying strings, etc etc)
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows inserted
  def insertBioSample(name, type, biomaterialState, biomaterialProvider, biomaterialSource, state=0)
    data = [ name, type, biomaterialState, biomaterialProvider, biomaterialSource, state ]
    return insertBioSamples(data, 1)
  end

  # Insert multiple BioSample records using column data.
  # [+data+]           An Array of values to use for name, type, biomaterialState, biomaterialProvider, biomaterialSource, state.
  #                    The Array may be 2-D (i.e. N rows of 6 columns or simply a flat array with appropriate values)
  #                    See the +insertBioSample()+ method for the fields needed for each record.
  # [+numBioSamples+]  Number of bioSamples to insert using values in +data+.
  #                    This is required because the data array may be flat and yet
  #                    have the dynamic field values for many BioSamples.
  # [+returns+]        Number of rows inserted
  def insertBioSamples(data, numBioSamples)
    return insertRecords(:userDB, 'bioSamples', data, true, numBioSamples, 6, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Update ALL the fields of a BioSample record identified by its id
  # [+id+]                  BioSamples.id of the record to update
  # [+name+]                Unique bioSample name
  # [+type+]                A String identifying the 'type' (kind) of BioSample
  # [+biomaterialState+]    A String indicating the state of the material (e.g. healthy, diseased, etc etc)
  # [+biomaterialProvider+] A String indicating the provider of the material (e.g. a lab, person, institution, etc etc)
  # [+biomaterialSource+]   A String inidicating the source of the material (e.g. cell line, cell line name, tissue, other identifying strings, etc etc)
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows inserted
  def updateBioSampleById(id, name, type, biomaterialState, biomaterialProvider, biomaterialSource, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_BIOSAMPLE_BY_ID)
      stmt.execute(name, type, biomaterialState, biomaterialProvider, biomaterialSource, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_BIOSAMPLE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identifies by its name.
  # You cannot rename the BioSample using this method.
  # [+name+]                Unique name of BioSamples record to update.
  # [+type+]                A String identifying the 'type' (kind) of BioSample
  # [+biomaterialState+]    A String indicating the state of the material (e.g. healthy, diseased, etc etc)
  # [+biomaterialProvider+] A String indicating the provider of the material (e.g. a lab, person, institution, etc etc)
  # [+biomaterialSource+]   A String inidicating the source of the material (e.g. cell line, cell line name, tissue, other identifying strings, etc etc)
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows updated.
  def updateBioSampleByName(name, type, biomaterialState, biomaterialProvider, biomaterialSource, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_BIOSAMPLE_BY_NAME)
      stmt.execute(type, biomaterialState, biomaterialProvider, biomaterialSource, state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, UPDATE_WHOLE_BIOSAMPLE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a BioSample record using its id.
  # [+id+]      The bioSamples.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleById(id)
    return deleteByFieldAndValue(:userDB, 'bioSamples', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete BioSample records using their ids.
  # [+ids+]     Array of bioSamples.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSamplesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSamples', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a BioSample record using its name.
  # [+name+]      The bioSamples.name of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleByName(id)
    return deleteByFieldAndValue(:userDB, 'bioSamples', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a bioSample record identified by its id as a template by updating its state
  # [+id+]            BioSamples.id of the record to update
  # [+returns+]       Number of rows updated.
  def setBioSampleStateToTemplate(id)
    return setStateBit(:userDB, 'bioSamples', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Mark a bioSample record identified by its id as completed by updating its state
  # [+id+]            BioSamples.id of the record to update
  # [+returns+]       Number of rows updated.
  def setBioSampleStateToCompleted(id)
    return setStateBit(:userDB, 'bioSamples', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a bioSample record identified by its id is a template
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isBioSampleTemplate?(id)
    return checkStateBit(:userDB, 'bioSamples', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a bioSample record identified by its id is completed
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isBioSampleCompleted?(id)
    return checkStateBit(:userDB, 'bioSamples', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Check if  a bioSample record identified by its id is still in progress
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the bioSample record is in progress, false otherwise
  def isBioSampleInProgress?(id)
    return (not(isBioSampleTemplate?(id) or isBioSampleCompleted?(id)))
  end

  # --------
  # Table: bioSampleAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_BIOSAMPLE_ATTRNAME = 'insert into bioSampleAttrNames values (null,?,?)'
  UPDATE_WHOLE_BIOSAMPLE_ATTRNAME = 'update bioSampleAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleAttrNames records
  # [+returns+] 1 row with count
  def countBioSampleAttrNames()
    return countRecords(:userDB, 'bioSampleAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all BioSampleAttrNames records
  # [+returns+] Array of 0+ bioSampleAttrNames records
  def selectAllBioSampleAttrNames()
    return selectAll(:userDB, 'bioSampleAttrNames', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrNames record by its id
  # [+id+]      The ID of the bioSampleAttrName record to return
  # [+returns+] Array of 0 or 1 bioSampleAttrNames records
  def selectBioSampleAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'bioSampleAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrNames records using a list of ids
  # [+ids+]     Array of bioSampleAttrNames IDs
  # [+returns+] Array of 0+ bioSampleAttrNames records
  def selectBioSampleAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrName record by its name
  # [+name+]    The unique name of the bioSampleAttrName record to return
  # [+returns+] Array of 0 or 1 bioSampleAttrNames records
  def selectBioSampleAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'bioSampleAttrNames', 'name', name, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrNames using a list of names
  # [+names+]   Array of unique bioSampleAttrNames names
  # [+returns+] Array of 0+ bioSampleAttrNames records
  def selectBioSampleAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleAttrNames', 'name', names, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select the value record for a particular attribute of a bioSample, using the attribute id.
  # "what's the value of the ___ attribute for this bioSample?"
  #
  # [+bioSampleId+]   The id of the bioSample.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectBioSampleAttrValueByBioSampleIdAndAttributeNameId(bioSampleId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'bioSamples', bioSampleId, attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select the value record for a particular attribute of a bioSample, using the attribute name (text).
  # "what's the value of the ___ attribute for this bioSample?"
  #
  # [+bioSampleId+]   The id of the bioSample.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectBioSampleAttrValueByBioSampleAndAttributeNameText(bioSampleId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'bioSamples', bioSampleId, attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all bioSamples), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectBioSampleAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'bioSamples', attrNameId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a particular attribute (i.e. across all bioSamples), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectBioSampleAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'bioSamples', attrNameText, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all bioSamples), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectBioSampleAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'bioSamples', attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all bioSamples), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectBioSampleAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'bioSamples', attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular bioSample, using attribute ids
  # "what are the current values associated with these attributes for this bioSample, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+bioSampleId+]   The id of the bioSample to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectBioSampleAttrValueMapByEntityAndAttributeIds(bioSampleId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'bioSamples', bioSampleId, attrNameIds, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Select an attribute->value "map" for the given attributes of particular bioSample, using attribute names
  # "what are the current values associated with these attributes for this bioSample, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+bioSampleId+]   The id of the bioSample to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectBioSampleAttrValueMapByEntityAndAttributeTexts(bioSampleId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'bioSamples', bioSampleId, attrNameTexts, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Insert a new BioSampleAttrNames record
  # [+name+]    Unique bioSampleAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertBioSampleAttrName(name, state=0)
    data = [ name, state ]
    return insertBioSampleAttrNames(data, 1)
  end

  # Insert multiple BioSampleAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numBioSampleAttrNames+] Number of bioSample attribute names to insert using values in +data+.
  #                           - This is required because the data array may be flat
  #                             and yet have the dynamic field values for many BioSampleAttrNames.
  # [+returns+]     Number of rows inserted
  def insertBioSampleAttrNames(data, numBioSampleAttrNames)
    return insertRecords(:userDB, 'bioSampleAttrNames', data, true, numBioSampleAttrNames, 2, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a BioSampleAttrName record using its id.
  # [+id+]      The bioSampleAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'bioSampleAttrNames', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete BioSampleAttrName records using their ids.
  # [+ids+]     Array of bioSampleAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleAttrNames', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # --------
  # Table: bioSampleAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_BIOSAMPLE_ATTRVALUE = 'update bioSampleAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleAttrValues records
  # [+returns+] 1 row with count
  def countBioSampleAttrValues()
    return countRecords(:userDB, 'bioSampleAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all BioSampleAttrValues records
  # [+returns+] Array of 0+ bioSampleAttrValues records
  def selectAllBioSampleAttrValues()
    return selectAll(:userDB, 'bioSampleAttrValues', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrValues record by its id
  # [+id+]      The ID of the bioSampleAttrValues record to return
  # [+returns+] Array of 0 or 1 bioSampleAttrValues records
  def selectBioSampleAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'bioSampleAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrValues records using a list of ids
  # [+ids+]     Array of bioSampleAttrValues IDs
  # [+returns+] Array of 0+ bioSampleAttrValues records
  def selectBioSampleAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the bioSampleAttrValue record to return
  # [+returns+] Array of 0 or 1 bioSampleAttrValue records
  def selectBioSampleAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'bioSampleAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the bioSampleAttrValue records to return
  # [+returns+] Array of 0+ bioSampleAttrNames records
  def selectBioSampleAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSampleAttrValues record by the exact value
  # [+value+]   The value of the bioSampleAttrValue record to return
  # [+returns+] Array of 0 or 1 bioSampleAttrValue records
  def selectBioSampleAttrValueByValue(value)
    return selectBioSampleAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get BioSampleAttrValues records using a list of the exact values
  # [+values+]  Array of values of the bioSampleAttrValue records to return
  # [+returns+] Array of 0+ bioSampleAttrNames records
  def selectBioSampleAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectBioSampleAttrValueBySha1s(sha1s)
  end

  # Insert a new BioSampleAttrValues record
  # [+value+]   Unique bioSampleAttrValues value
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertBioSampleAttrValue(value, state=0)
    data = [value, state ] # insertBioSampleAttrValues() will compute SHA1 for us
    return insertBioSampleAttrValues(data, 1)
  end

  # Insert multiple BioSampleAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertBioSampleAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numBioSampleAttrValues+]  Number of bioSample attribute values to insert using values in +data+.
  #                             This is required because the data array may be flat and yet
  #                             have the dynamic field values for many BioSampleAttrValues.
  # [+returns+]     Number of rows inserted
  def insertBioSampleAttrValues(data, numBioSampleAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'bioSampleAttrValues', dataCopy, true, numBioSampleAttrValues, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a BioSampleAttrValues record using its id.
  # [+id+]      The bioSampleAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'bioSampleAttrValues', 'id', id, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete BioSampleAttrValues records using their ids.
  # [+ids+]     Array of bioSampleAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleAttrValues', 'id', ids, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete a BioSampleAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The bioSampleAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'bioSampleAttrValues', 'sha1', sha1, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Delete BioSampleAttrValues records using their sha1 digests.
  # [+ids+]     Array of bioSampleAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleAttrValues', 'sha1', sha1s, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

    # Delete a BioSampleAttrValues record using the exact value.
  # [+sha1+]    The bioSampleAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValueByValue(value)
    return deleteBioSampleAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete BioSampleAttrValues records using their exact values
  # [+values+]  Array of bioSampleAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteBioSampleAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: bioSample2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_BIOSAMPLE2ATTRIBUTE = 'insert into bioSample2attributes values (?,?,?)'
  SELECT_BIOSAMPLE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from bioSample2attributes where bioSampleAttrName_id = ? and bioSampleAttrValue_id = ?'
  DELETE_BIOSAMPLE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from bioSample2attributes where bioSample_id = ? '
  SELECT_ATTRNAME_ATTRVALUE_BY_BIOSAMPLENAME = "select bioSampleAttrNames.name, bioSampleAttrValues.value from bioSamples, bioSampleAttrNames,
                                                bioSampleAttrValues, bioSample2attributes where bioSample2attributes.bioSample_id = bioSamples.id and
                                                bioSampleAttrNames.id = bioSample2attributes.bioSampleAttrName_id and bioSampleAttrValues.id = bioSample2attributes.bioSampleAttrValue_id and
                                                bioSamples.name = ?"
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSample2Attributes records
  # [+returns+] 1 row with count
  def countBioSample2Attributes()
    return countRecords(:userDB, 'bioSample2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get all BioSample2Attributes records
  # [+returns+] Array of 0+ bioSample2attributes records
  def selectAllBioSample2Attributes()
    return selectAll(:userDB, 'bioSample2attributes', "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get BioSample2Attributes records by bioSample_id ; i.e. get all the AVP mappings (an ID triple) for a bioSample
  # [+bioSampleId+] The bioSample_id for the BioSample2Attributes records to return
  # [+returns+] Array of 0+ bioSample2attributes records
  def selectBioSample2AttributesByBioSampleId(bioSampleId)
    return selectByFieldAndValue(:userDB, 'bioSample2attributes', 'bioSample_id', bioSampleId, "#{File.basename(__FILE__)} => #{__method__}(): ")
  end

  # Get records of attribute names and values based on bioSample name
  # [+name+]
  # [+returns+] Array of 0+ DBI::Rows
  def selectAttrNamesAndValuesByBioSampleName(name)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_ATTRNAME_ATTRVALUE_BY_BIOSAMPLENAME)
      stmt.execute(name)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_ATTRNAME_ATTRVALUE_BY_BIOSAMPLENAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get detailed bioSample records (including AVPs) for those bioSamples in bioSampleSet with given name
  # @param [String] the BioSampleSet name
  # @return [Array<Hash>] of detailed BioSample info resulting from multi-table join
  SELECT_DETAILED_BIOASAMPLES_BY_BIOSAMPLESETNAME =
    "select bioSamples.id as id, bioSamples.name as name, bioSampleAttrNames.name as attribute, bioSampleAttrValues.value as value
     from bioSamples, bioSampleSets, bioSample2bioSampleSet, bioSampleAttrNames, bioSampleAttrValues, bioSample2attributes
     where bioSampleSets.name = '{setName}'
     and   bioSamples.id = bioSample2bioSampleSet.bioSample_id
     and   bioSampleSets.id = bioSample2bioSampleSet.bioSampleSet_id
     and   bioSample2attributes.bioSample_id = bioSamples.id
     and   bioSampleAttrNames.id = bioSample2attributes.bioSampleAttrName_id
     and   bioSampleAttrValues.id = bioSample2attributes.bioSampleAttrValue_id "
  def selectBioSamplesAVPsByBioSampleSetName(setName)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_DETAILED_BIOASAMPLES_BY_BIOSAMPLESETNAME.dup
      sql.gsub!(/\{setName\}/, mysql2gsubSafeEsc(setName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Insert a new BioSample2Attributes record ; i.e. set a new AVP for a bioSample.
  # Note: this does NOT update any existing triple involving the bioSample_id and the bioSampleAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that bioSample.
  # [+bioSampleId+]           bioSample_id for whom to associate an AVP
  # [+bioSampleAttrNameId+]   bioSampleAttrName_id for the attribute
  # [+bioSampleAttrValueId+]  bioSampleAttrValue_id for the attribute value
  # [+returns+]               Number of rows inserted
  def insertBioSample2Attribute(bioSampleId, bioSampleAttrNameId, bioSampleAttrValueId)
    data = [ bioSampleId, bioSampleAttrNameId, bioSampleAttrValueId ]
    return insertBioSample2Attributes(data, 1)
  end

  # Insert multiple BioSample2Attributes records using field data.
  # If a duplicate bioSample2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for bioSample_id, bioSampleAttrName_id, and bioSampleAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numBioSample2Attributes+]  Number of bioSample2attributes to insert using values in +data+.
  #                              - This is required because the data array may be flat and yet
  #                                have the dynamic field values for many BioSample2Attributes.
  # [+returns+]     Number of rows inserted
  def insertBioSample2Attributes(data, numBioSample2Attributes, dupKeyUpdateCol=false, flatten=true)
    return insertRecords(:userDB, 'bioSample2attributes', data, false, numBioSample2Attributes, 3, true, "#{File.basename(__FILE__)} => #{__method__}(): ", dupKeyUpdateCol, flatten)
  end

  # Select all BioSample2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+bioSampleAttrNameId+]   bioSampleAttrName_id for tha attribute
  # [+bioSampleAttrValueId+]  bioSampleAttrValue_id for the attribute value
  # [+returns+]               Array of 0+ bioSample2attributes records
  def selectBioSample2AttributesByAttrNameIdAndAttrValueId(bioSampleAttrNameId, bioSampleAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_BIOSAMPLE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(bioSampleAttrNameId, bioSampleAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, SELECT_BIOSAMPLE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular bioSample's attribute.
  # All triples associating the bioSample to an attribute will have their value replaced.
  # [+bioSampleId+]           ID of the bioSample whose AVP we are updating
  # [+bioSampleAttrNameId+]   ID of bioSampleAttrName whose value to update
  # [+bioSampleAttrValueId+]  ID of the bioSampleAttrValue to associate with the attribute for a particular bioSample
  def updateBioSample2AttributeForBioSampleAndAttrName(bioSampleId, bioSampleAttrNameId, bioSampleAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteBioSample2AttributesByBioSampleIdAndAttrNameId(bioSampleId, bioSampleAttrNameId)
      retVal = insertBioSample2Attribute(bioSampleId, bioSampleAttrNameId, bioSampleAttrValueId)
    rescue => @err
      DBUtil.logDbError("#{File.basename(__FILE__)} => #{__method__}(): ", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete BioSample2Attributes records for a given bioSample, or for a bioSample and attribute name,
  # or for a bioSample and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a bioSample, or to remove the association of a particular
  # attribute with the bioSample, or to remove the association only if a particular value is involved.
  # [+bioSampleId+]           bioSample_id for which to delete some AVP info
  # [+bioSampleAttrNameId+]   [optional] bioSampleAttrName_id to disassociate with the bioSample
  # [+bioSampleAttrValueId+]  [optional] bioSampleAttrValue_id to further restrict which AVPs are disassociate with the bioSample
  # [+returns+]               Number of rows deleted
  def deleteBioSample2AttributesByBioSampleIdAndAttrNameId(bioSampleId, bioSampleAttrNameId=nil, bioSampleAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_BIOSAMPLE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and bioSampleAttrName_id = ?' unless(bioSampleAttrNameId.nil?)
      sql += ' and bioSampleAttrValue_id = ?' unless(bioSampleAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(bioSampleAttrNameId.nil?)
        stmt.execute(bioSampleId)
      elsif(bioSampleAttrValueId.nil?)
        stmt.execute(bioSampleId, bioSampleAttrNameId)
      else
        stmt.execute(bioSampleId, bioSampleAttrNameId, bioSampleAttrValueId)
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
