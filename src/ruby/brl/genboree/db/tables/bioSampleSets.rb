require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# BIOSAMPLE RELATED TABLES - DBUtil Extension Methods for dealing with BioSampleSet-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # TABLE: bioSampleSets
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:
  UPDATE_WHOLE_BIOSAMPLESET_BY_ID = 'update bioSampleSets set name = ?,  state = ? where id = ?'
  UPDATE_WHOLE_BIOSAMPLESET_BY_NAME = 'update bioSampleSets set state = ? where name = ?'
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleSets records
  # [+returns+] 1 row with count
  def countBioSampleSets()
    return countRecords(:userDB, 'bioSampleSets', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all BioSampleSets records
  # [+returns+] Array of 0+ bioSampleSets record rows
  def selectAllBioSampleSets()
    return selectAll(:userDB, 'bioSampleSets', "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSet record by its id
  # [+id+]      The ID of the bioSampleSet record to return
  # [+returns+] Array of 0 or 1 bioSampleSets record rows
  def selectBioSampleSetById(id)
    return selectByFieldAndValue(:userDB, 'bioSampleSets', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSets records using a list of ids
  # [+ids+]     Array of bioSampleSet IDs
  # [+returns+] Array of 0+ boSamples records
  def selectBioSampleSetsByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSets', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSet by its unique name
  # [+name+]    The unique name of the bioSampleSet record to return
  # [+returns+] Array of 0 or 1 bioSampleSets record
  def selectBioSampleSetByName(name)
    return selectByFieldAndValue(:userDB, 'bioSampleSets', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSets using a list of names
  # [+names+]   Array of unique bioSampleSet names
  # [+returns+] Array of 0+ bioSampleSets records
  def selectBioSampleSetsByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSets', 'names', names, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSets by matching an AVP by ids; get all bioSampleSets possessing the attribute and its value
  # indicated by +bioSampleSetAttrNameId+ whose value is +bioSampleSetAttrValueId+.
  # [+bioSampleSetAttrNameId+]   bioSampleSetAttrNames.id for the bioSampleSet attribute to consider
  # [+bioSampleSetAttrValueId+]  bioSampleSetAttrValues.id for the bioSampleSet attribute value to match
  # [+returns+]               Array of 0+ bioSampleSet records
  def selectBioSampleSetsByAttributeNameAndValueIds(bioSampleSetAttrNameId, bioSampleSetAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'bioSampleSets', bioSampleSetAttrNameId, bioSampleSetAttrValueId, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSets by matching an AVP by texts; get all bioSampleSets possessing the attribute and its value
  # named in +bioSampleSetAttrNameText+ whose value is +bioSampleSetAttrValueText+.
  # [+bioSampleSetAttrNameText+]   BioSampleSet attribute name to consider
  # [+bioSampleSetAttrValueText+]  BioSampleSet attribute value to match
  # [+returns+]                 Array of 0+ bioSampleSet records
  def selectBioSampleSetByAttributeNameAndValueTexts(bioSampleSetAttrNameText, bioSampleSetAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'bioSampleSets', bioSampleSetAttrNameText, bioSampleSetAttrValueText, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new BioSampleSet record
  # [+name+]                Unique bioSampleSet name
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows inserted
  def insertBioSampleSet(name, state=0)
    data = [ name, state ]
    return insertBioSampleSets(data, 1)
  end

  # Insert multiple BioSampleSet records using column data.
  # [+data+]           An Array of values to use for name, state.
  #                    The Array may be 2-D (i.e. N rows of 6 columns or simply a flat array with appropriate values)
  #                    See the +insertBioSampleSet()+ method for the fields needed for each record.
  # [+numBioSampleSets+]  Number of bioSampleSets to insert using values in +data+.
  #                    This is required because the data array may be flat and yet
  #                    have the dynamic field values for many BioSampleSets.
  # [+returns+]        Number of rows inserted
  def insertBioSampleSets(data, numBioSampleSets)
    return insertRecords(:userDB, 'bioSampleSets', data, true, numBioSampleSets, 2, false,  "ERROR: #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a BioSampleSet record identified by its id
  # [+id+]                  BioSampleSets.id of the record to update
  # [+name+]                Unique bioSampleSet name
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows inserted
  def updateBioSampleSetById(id, name, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_BIOSAMPLESET_BY_ID)
      stmt.execute(name, state, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, UPDATE_WHOLE_BIOSAMPLESET_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identifies by its name.
  # You cannot rename the BioSampleSet using this method.
  # [+name+]                Unique name of BioSampleSets record to update.
  # [+type+]                A String identifying the 'type' (kind) of BioSampleSet
  # [+biomaterialState+]    A String indicating the state of the material (e.g. healthy, diseased, etc etc)
  # [+biomaterialProvider+] A String indicating the provider of the material (e.g. a lab, person, institution, etc etc)
  # [+biomaterialSource+]   A String inidicating the source of the material (e.g. cell line, cell line name, tissue, other identifying strings, etc etc)
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows updated.
  def updateBioSampleSetByName(name, state=0)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_BIOSAMPLESET_BY_NAME)
      stmt.execute(state, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, UPDATE_WHOLE_BIOSAMPLESET_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a BioSampleSet record using its id.
  # [+id+]      The bioSampleSets.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetById(id)
    return deleteByFieldAndValue(:userDB, 'bioSampleSets', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete BioSampleSet records using their ids.
  # [+ids+]     Array of bioSampleSets.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetsByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleSets', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a BioSampleSet record using its name.
  # [+name+]      The bioSampleSets.name of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetByName(name)
    return deleteByFieldAndValue(:userDB, 'bioSampleSets', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Mark a bioSampleSet record identified by its id as a template by updating its state
  # [+id+]            BioSampleSets.id of the record to update
  # [+returns+]       Number of rows updated.
  def setBioSampleSetStateToTemplate(id)
    return setStateBit(:userDB, 'bioSampleSets', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Mark a bioSampleSet record identified by its id as completed by updating its state
  # [+id+]            BioSampleSets.id of the record to update
  # [+returns+]       Number of rows updated.
  def setBioSampleSetStateToCompleted(id)
    return setStateBit(:userDB, 'bioSampleSets', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a bioSampleSet record identified by its id is a template
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isBioSampleSetTemplate?(id)
    return checkStateBit(:userDB, 'bioSampleSets', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a bioSampleSet record identified by its id is completed
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isBioSampleSetCompleted?(id)
    return checkStateBit(:userDB, 'bioSampleSets', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a bioSampleSet record identified by its id is still in progress
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the bioSampleSet record is in progress, false otherwise
  def isBioSampleSetInProgress?(id)
    return (not(isBioSampleSetTemplate?(id) or isBioSampleSetCompleted?(id)))
  end

  # --------
  # Table: bioSampleSetAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_BIOSAMPLESET_ATTRNAME = 'insert into bioSampleSetAttrNames values (null,?,?)'
  UPDATE_WHOLE_BIOSAMPLESET_ATTRNAME = 'update bioSampleSetAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleSetAttrNames records
  # [+returns+] 1 row with count
  def countBioSampleSetAttrNames()
    return countRecords(:userDB, 'bioSampleSetAttrNames', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all BioSampleSetAttrNames records
  # [+returns+] Array of 0+ bioSampleSetAttrNames records
  def selectAllBioSampleSetAttrNames()
    return selectAll(:userDB, 'bioSampleSetAttrNames', "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrNames record by its id
  # [+id+]      The ID of the bioSampleSetAttrName record to return
  # [+returns+] Array of 0 or 1 bioSampleSetAttrNames records
  def selectBioSampleSetAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'bioSampleSetAttrNames', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrNames records using a list of ids
  # [+ids+]     Array of bioSampleSetAttrNames IDs
  # [+returns+] Array of 0+ bioSampleSetAttrNames records
  def selectBioSampleSetAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrNames', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrName record by its name
  # [+name+]    The unique name of the bioSampleSetAttrName record to return
  # [+returns+] Array of 0 or 1 bioSampleSetAttrNames records
  def selectBioSampleSetAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'bioSampleSetAttrNames', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrNames using a list of names
  # [+names+]   Array of unique bioSampleSetAttrNames names
  # [+returns+] Array of 0+ bioSampleSetAttrNames records
  def selectBioSampleSetAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrNames', 'name', names, "ERROR: #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a bioSampleSet, using the attribute id.
  # "what's the value of the ___ attribute for this bioSampleSet?"
  #
  # [+bioSampleSetId+]   The id of the bioSampleSet.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectBioSampleSetAttrValueByBioSampleSetIdAndAttributeNameId(bioSampleSetId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'bioSampleSets', bioSampleSetId, attrNameId, "ERROR: #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a bioSampleSet, using the attribute name (text).
  # "what's the value of the ___ attribute for this bioSampleSet?"
  #
  # [+bioSampleSetId+]   The id of the bioSampleSet.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectBioSampleSetAttrValueByBioSampleSetAndAttributeNameText(bioSampleSetId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'bioSampleSets', bioSampleSetId, attrNameText, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all bioSampleSets), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectBioSampleSetAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'bioSampleSets', attrNameId, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all bioSampleSets), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectBioSampleSetAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'bioSampleSets', attrNameText, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all bioSampleSets), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectBioSampleSetAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'bioSampleSets', attrNameIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all bioSampleSets), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectBioSampleSetAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'bioSampleSets', attrNameTexts, "ERROR: #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular bioSampleSet, using attribute ids
  # "what are the current values associated with these attributes for this bioSampleSet, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+bioSampleSetId+]   The id of the bioSampleSet to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectBioSampleSetAttrValueMapByEntityAndAttributeIds(bioSampleSetId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'bioSampleSets', bioSampleSetId, attrNameIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular bioSampleSet, using attribute names
  # "what are the current values associated with these attributes for this bioSampleSet, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+bioSampleSetId+]   The id of the bioSampleSet to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectBioSampleSetAttrValueMapByEntityAndAttributeTexts(bioSampleSetId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'bioSampleSets', bioSampleSetId, attrNameTexts, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new BioSampleSetAttrNames record
  # [+name+]    Unique bioSampleSetAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertBioSampleSetAttrName(name, state=0)
    data = [ name, state ]
    return insertBioSampleSetAttrNames(data, 1)
  end

  # Insert multiple BioSampleSetAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numBioSampleSetAttrNames+] Number of bioSampleSet attribute names to insert using values in +data+.
  #                           - This is required because the data array may be flat
  #                             and yet have the dynamic field values for many BioSampleSetAttrNames.
  # [+returns+]     Number of rows inserted
  def insertBioSampleSetAttrNames(data, numBioSampleSetAttrNames)
    return insertRecords(:userDB, 'bioSampleSetAttrNames', data, true, numBioSampleSetAttrNames, 2, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a BioSampleSetAttrName record using its id.
  # [+id+]      The bioSampleSetAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'bioSampleSetAttrNames', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete BioSampleSetAttrName records using their ids.
  # [+ids+]     Array of bioSampleSetAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrNames', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # --------
  # Table: bioSampleSetAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_BIOSAMPLESET_ATTRVALUE = 'update bioSampleSetAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleSetAttrValues records
  # [+returns+] 1 row with count
  def countBioSampleSetAttrValues()
    return countRecords(:userDB, 'bioSampleSetAttrValues', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all BioSampleSetAttrValues records
  # [+returns+] Array of 0+ bioSampleSetAttrValues records
  def selectAllBioSampleSetAttrValues()
    return selectAll(:userDB, 'bioSampleSetAttrValues', "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrValues record by its id
  # [+id+]      The ID of the bioSampleSetAttrValues record to return
  # [+returns+] Array of 0 or 1 bioSampleSetAttrValues records
  def selectBioSampleSetAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'bioSampleSetAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrValues records using a list of ids
  # [+ids+]     Array of bioSampleSetAttrValues IDs
  # [+returns+] Array of 0+ bioSampleSetAttrValues records
  def selectBioSampleSetAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrValues', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the bioSampleSetAttrValue record to return
  # [+returns+] Array of 0 or 1 bioSampleSetAttrValue records
  def selectBioSampleSetAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'bioSampleSetAttrValues', 'sha1', sha1, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the bioSampleSetAttrValue records to return
  # [+returns+] Array of 0+ bioSampleSetAttrNames records
  def selectBioSampleSetAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrValues', 'sha1', sha1s, "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSetAttrValues record by the exact value
  # [+value+]   The value of the bioSampleSetAttrValue record to return
  # [+returns+] Array of 0 or 1 bioSampleSetAttrValue records
  def selectBioSampleSetAttrValueByValue(value)
    return selectBioSampleSetAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get BioSampleSetAttrValues records using a list of the exact values
  # [+values+]  Array of values of the bioSampleSetAttrValue records to return
  # [+returns+] Array of 0+ bioSampleSetAttrNames records
  def selectBioSampleSetAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectBioSampleSetAttrValueBySha1s(sha1s)
  end

  # Insert a new BioSampleSetAttrValues record
  # [+value+]   Unique bioSampleSetAttrValues value
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertBioSampleSetAttrValue(value, state=0)
    data = [value, state ] # insertBioSampleSetAttrValues() will compute SHA1 for us
    return insertBioSampleSetAttrValues(data, 1)
  end

  # Insert multiple BioSampleSetAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertBioSampleSetAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numBioSampleSetAttrValues+]  Number of bioSampleSet attribute values to insert using values in +data+.
  #                             This is required because the data array may be flat and yet
  #                             have the dynamic field values for many BioSampleSetAttrValues.
  # [+returns+]     Number of rows inserted
  def insertBioSampleSetAttrValues(data, numBioSampleSetAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'bioSampleSetAttrValues', dataCopy, true, numBioSampleSetAttrValues, 3, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a BioSampleSetAttrValues record using its id.
  # [+id+]      The bioSampleSetAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'bioSampleSetAttrValues', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete BioSampleSetAttrValues records using their ids.
  # [+ids+]     Array of bioSampleSetAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrValues', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a BioSampleSetAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The bioSampleSetAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'bioSampleSetAttrValues', 'sha1', sha1, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete BioSampleSetAttrValues records using their sha1 digests.
  # [+ids+]     Array of bioSampleSetAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSampleSetAttrValues', 'sha1', sha1s, "ERROR: #{self.class}##{__method__}():")
  end

    # Delete a BioSampleSetAttrValues record using the exact value.
  # [+sha1+]    The bioSampleSetAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValueByValue(value)
    return deleteBioSampleSetAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete BioSampleSetAttrValues records using their exact values
  # [+values+]  Array of bioSampleSetAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSampleSetAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteBioSampleSetAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: bioSampleSet2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_BIOSAMPLESET2ATTRIBUTE = 'insert into bioSampleSet2attributes values (?,?,?)'
  SELECT_BIOSAMPLESET2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from bioSampleSet2attributes where bioSampleSetAttrName_id = ? and bioSampleSetAttrValue_id = ?'
  DELETE_BIOSAMPLESET2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from bioSampleSet2attributes where bioSampleSet_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all BioSampleSet2Attributes records
  # [+returns+] 1 row with count
  def countBioSampleSet2Attributes()
    return countRecords(:userDB, 'bioSampleSet2attributes', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all BioSampleSet2Attributes records
  # [+returns+] Array of 0+ bioSampleSet2attributes records
  def selectAllBioSampleSet2Attributes()
    return selectAll(:userDB, 'bioSampleSet2attributes', "ERROR: #{self.class}##{__method__}():")
  end

  # Get BioSampleSet2Attributes records by bioSampleSet_id ; i.e. get all the AVP mappings (an ID triple) for a bioSampleSet
  # [+bioSampleSetId+] The bioSampleSet_id for the BioSampleSet2Attributes records to return
  # [+returns+] Array of 0+ bioSampleSet2attributes records
  def selectBioSampleSet2AttributesByBioSampleSetId(bioSampleSetId)
    return selectByFieldAndValue(:userDB, 'bioSampleSet2attributes', 'bioSampleSet_id', bioSampleSetId, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new BioSampleSet2Attributes record ; i.e. set a new AVP for a bioSampleSet.
  # Note: this does NOT update any existing triple involving the bioSampleSet_id and the bioSampleSetAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that bioSampleSet.
  # [+bioSampleSetId+]           bioSampleSet_id for whom to associate an AVP
  # [+bioSampleSetAttrNameId+]   bioSampleSetAttrName_id for the attribute
  # [+bioSampleSetAttrValueId+]  bioSampleSetAttrValue_id for the attribute value
  # [+returns+]               Number of rows inserted
  def insertBioSampleSet2Attribute(bioSampleSetId, bioSampleSetAttrNameId, bioSampleSetAttrValueId)
    data = [ bioSampleSetId, bioSampleSetAttrNameId, bioSampleSetAttrValueId ]
    return insertBioSampleSet2Attributes(data, 1)
  end

  # Insert multiple BioSampleSet2Attributes records using field data.
  # If a duplicate bioSampleSet2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for bioSampleSet_id, bioSampleSetAttrName_id, and bioSampleSetAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numBioSampleSet2Attributes+]  Number of bioSampleSet2attributes to insert using values in +data+.
  #                              - This is required because the data array may be flat and yet
  #                                have the dynamic field values for many BioSampleSet2Attributes.
  # [+returns+]     Number of rows inserted
  def insertBioSampleSet2Attributes(data, numBioSampleSet2Attributes)
    return insertRecords(:userDB, 'bioSampleSet2attributes', data, false, numBioSampleSet2Attributes, 3, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all BioSampleSet2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+bioSampleSetAttrNameId+]   bioSampleSetAttrName_id for tha attribute
  # [+bioSampleSetAttrValueId+]  bioSampleSetAttrValue_id for the attribute value
  # [+returns+]               Array of 0+ bioSampleSet2attributes records
  def selectBioSampleSet2AttributesByAttrNameIdAndAttrValueId(bioSampleSetAttrNameId, bioSampleSetAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_BIOSAMPLESET2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(bioSampleSetAttrNameId, bioSampleSetAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, SELECT_BIOSAMPLESET2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular bioSampleSet's attribute.
  # All triples associating the bioSampleSet to an attribute will have their value replaced.
  # [+bioSampleSetId+]           ID of the bioSampleSet whose AVP we are updating
  # [+bioSampleSetAttrNameId+]   ID of bioSampleSetAttrName whose value to update
  # [+bioSampleSetAttrValueId+]  ID of the bioSampleSetAttrValue to associate with the attribute for a particular bioSampleSet
  def updateBioSampleSet2AttributeForBioSampleSetAndAttrName(bioSampleSetId, bioSampleSetAttrNameId, bioSampleSetAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteBioSampleSet2AttributesByBioSampleSetIdAndAttrNameId(bioSampleSetId, bioSampleSetAttrNameId)
      retVal = insertBioSampleSet2Attribute(bioSampleSetId, bioSampleSetAttrNameId, bioSampleSetAttrValueId)
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete BioSampleSet2Attributes records for a given bioSampleSet, or for a bioSampleSet and attribute name,
  # or for a bioSampleSet and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a bioSampleSet, or to remove the association of a particular
  # attribute with the bioSampleSet, or to remove the association only if a particular value is involved.
  # [+bioSampleSetId+]           bioSampleSet_id for which to delete some AVP info
  # [+bioSampleSetAttrNameId+]   [optional] bioSampleSetAttrName_id to disassociate with the bioSampleSet
  # [+bioSampleSetAttrValueId+]  [optional] bioSampleSetAttrValue_id to further restrict which AVPs are disassociate with the bioSampleSet
  # [+returns+]               Number of rows deleted
  def deleteBioSampleSet2AttributesByBioSampleSetIdAndAttrNameId(bioSampleSetId, bioSampleSetAttrNameId=nil, bioSampleSetAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_BIOSAMPLESET2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and bioSampleSetAttrName_id = ?' unless(bioSampleSetAttrNameId.nil?)
      sql += ' and bioSampleSetAttrValue_id = ?' unless(bioSampleSetAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(bioSampleSetAttrNameId.nil?)
        stmt.execute(bioSampleSetId)
      elsif(bioSampleSetAttrValueId.nil?)
        stmt.execute(bioSampleSetId, bioSampleSetAttrNameId)
      else
        stmt.execute(bioSampleSetId, bioSampleSetAttrNameId, bioSampleSetAttrValueId)
      end
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: bioSample2bioSampleSet
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:
  SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID = ' select bioSampleSets.id, bioSampleSets.name, bioSampleSets.state from bioSampleSets, bioSample2bioSampleSet
                                              where bioSample2bioSampleSet.bioSample_id = ? and bioSample2bioSampleSet.bioSampleSet_id = bioSampleSets.id
                                            '

  SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID = ' select bioSamples.id, bioSamples.name, bioSamples.type, bioSamples.biomaterialState, bioSamples.biomaterialProvider, bioSamples.biomaterialSource,
                                               bioSamples.state from bioSamples, bioSample2bioSampleSet where bioSample2bioSampleSet.bioSampleSet_id = ? and
                                               bioSample2bioSampleSet.bioSample_id = bioSamples.id
                                            '

  DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME = '
                                                      delete from bioSample2bioSampleSet using bioSamples where bioSamples.name = ? and bioSamples.id = bioSample2bioSampleSet.bioSample_id
                                                    '
  DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME = '
                                                          delete from bioSample2bioSampleSet using bioSampleSets where bioSampleSets.name = ? and bioSampleSets.id = bioSample2bioSampleSet.bioSampleSet_id
                                                        '
  DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLE_ID_AND_BIOSAMPLESET_ID = ' delete from bioSample2bioSampleSet where bioSample_id = ? and bioSampleSet_id = ?'
  # ############################################################################
  # METHODS
  # ############################################################################
  # Get all BioSampleSets records for a given bioSample by bioSampleId
  # [+bioSampleId+]
  # [+returns+] Array of 0+ bioSampleSets records
  def selectAllBioSampleSetsByBioSampleId(bioSampleId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID)
      stmt.execute(bioSampleId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get all BioSamples records for a given bioSampleSet by bioSampleSetId
  # [+bioSampleSetId+]
  # [+returns+] Array of 0+ bioSamples records
  def selectAllBioSamplesByBioSampleSetId(bioSampleSetId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID)
      stmt.execute(bioSampleSetId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get all BioSamples records for a given bioSampleSet by bioSampleSetName
  # @param [String] bioSampleSetName the name of the bioSampleSet
  # @return [Array<Hash>] of bioSamples records
    SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_NAME =
      "select bioSamples.*
      from bioSamples, bioSample2bioSampleSet, bioSampleSets
      where bioSampleSets.name = '{setName}'
      and   bioSamples.id = bioSample2bioSampleSet.bioSample_id
      and   bioSample2bioSampleSet.bioSampleSet_id = bioSampleSets.id"
  def selectAllBioSamplesByBioSampleSetName(bioSampleSetName)
    retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_BIOSAMPLESETS_BY_BIOSAMPLESET_NAME.dup
      sql.gsub!(/\{setName\}/, mysql2gsubSafeEsc(bioSampleSetName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Delete a bioSample2bioSampleSet record using its bioSample_id.
  # [+bioSampleId+]  The bioSample2bioSampleSet.bioSample_id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetByBioSampleId(bioSampleId)
    return deleteByFieldAndValue(:userDB, 'bioSample2bioSampleSet', 'bioSample_id', bioSampleId, "ERROR: #{self.class}##{__method__}():")
  end

  def deleteBioSample2BioSampleSetByBioSampleIdAndBioSampleSetId(bioSampleId, bioSampleSetId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLE_ID_AND_BIOSAMPLESET_ID)
      stmt.execute(bioSampleId, bioSampleSetId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLE_ID_AND_BIOSAMPLESET_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete bioSample2bioSampleSet records using their bioSample_ids.
  # [+bioSampleIds+]  Array of bioSample2bioSampleSet.bioSample_id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetsByBioSampleIds(bioSampleIds)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSample2bioSampleSet', 'bioSample_id', bioSampleIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a bioSample2bioSampleSet record using bioSamples.name.
  # [+bioSampleName+]
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetByBioSampleName(bioSampleName)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME)
      stmt.execute(bioSampleName)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete bioSample2bioSampleSet records using their bioSample.names.
  # [+bioSampleNames+]  Array of bioSamples.name of the records to delete in bioSample2bioSampleSet.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetsByBioSampleNames(bioSampleNames)
    retVal = nil
    begin
      sql = 'delete from bioSample2bioSampleSet using bioSamples where bioSamples.name in ('
      bioSampleNames.size.times { |ii|
        sql << ii == 0 ? '?' : ',?'
      }
      sql << ") and bioSamples.id = bioSample2bioSampleSet.bioSample_id"
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(*bioSampleNames)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end


  # Delete a bioSample2bioSampleSet record using its bioSampleSet_id.
  # [+bioSampleSetId+]  The bioSample2bioSampleSet.bioSampleSet_id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetByBioSampleSetId(bioSampleSetId)
    return deleteByFieldAndValue(:userDB, 'bioSample2bioSampleSet', 'bioSampleSet_id', bioSampleSetId, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete bioSample2bioSampleSet records using their bioSampleSet_ids.
  # [+bioSampleSetIds+]  Array of bioSample2bioSampleSet.bioSampleSet_id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetsByBioSampleSetIds(bioSampleSetIds)
    return deleteByFieldWithMultipleValues(:userDB, 'bioSample2bioSampleSet', 'bioSampleSet_id', bioSampleSetIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a bioSample2bioSampleSet record using bioSamplesSets.name.
  # [+bioSampleSetName+]
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetByBioSampleSetName(bioSampleSetName)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME)
      stmt.execute(bioSampleSetName)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, DELETE_BIOSAMPLESET2BIOSAMPLESET_BY_BIOSAMPLESET_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete bioSample2bioSampleSet records using their bioSampleSets.name.
  # [+bioSampleSetNames+]  Array of bioSampleSets.name of the records to delete in bioSample2bioSampleSet.
  # [+returns+] Number of rows deleted
  def deleteBioSample2BioSampleSetsByBioSampleSetNames(bioSampleSetNames)
    retVal = nil
    begin
      sql = 'delete from bioSample2bioSampleSet using bioSampleSets where bioSampleSets.name in ('
      bioSampleSetNames.size.times { |ii|
        sql << ii == 0 ? '?' : ',?'
      }
      sql << ") and bioSampleSets.id = bioSample2bioSampleSet.bioSampleSet_id"
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(*bioSampleSetNames)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new bioSample2bioSampleSet record
  # [+bioSample_id+]        sample id coming from bioSample table
  # [+bioSampleSet_id+]     sample set id coming from bioSampleSet table
  # [+returns+]             Number of rows inserted
  def insertBioSample2BioSampleSet(bioSample_id, bioSampleSet_id)
    data = [ bioSample_id, bioSampleSet_id ]
    return insertBioSample2BioSampleSets(data, 1)
  end

  # Insert multiple bioSample2bioSampleSet records using column data.
  # [+data+]           An Array of values to use for bioSample_id and bioSampleSet_id.
  #                    The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numBioSample2BioSampleSets+]  Number of bioSample2bioSampleSets to insert using values in +data+.
  #                    This is required because the data array may be flat and yet
  #                    have the dynamic field values for many bioSample2bioSampleSets.
  # [+returns+]        Number of rows inserted
  def insertBioSample2BioSampleSets(data, numBioSample2BioSampleSets)
    return insertRecords(:userDB, 'bioSample2bioSampleSet', data, false, numBioSample2BioSampleSets, 2, true,  "ERROR: #{self.class}##{__method__}():")
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
