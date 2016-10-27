require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Database-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: databases
  # --------
  # NOTE: the database entity table is called "refseq" and its extensive legacy methods currently live in the core.rb file
  # Methods below are for uniform method consistency and any AVP-related functionality
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_DATABASE_BY_ID = "update refseq set userId = ?, refseqName = ?, refseq_species = ?, refseq_version = ?, description = ?, FK_genomeTemplate_id = ?, mapmaster = 'http://localhost/java-bin/das', databaseName = ?, fastaDir = ?, merged = 'y', useValuePairs = 'y', public = ? where refSeqId = ?"
  UPDATE_WHOLE_DATABASE_BY_NAME = "update refseq set userId = ?, refseq_species = ?, refseq_version = ?, description = ?, FK_genomeTemplate_id = ?, mapmaster = 'http://localhost/java-bin/das', databaseName = ?, fastaDir = NULL, merged = 'y', useValuePairs = 'y', public = ? where refseqName = ?"
  UPDATE_DATABASE_EXPOSED_FIELDS_BY_ID = "update refseq set refseqName = ?, refseq_species = ?, refseq_version = ?, description = ?, public = ? where refSeqId = ?"
  UPDATE_DATABASE_EXPOSED_FIELDS_BY_NAME = "update refseq set refseq_species = ?, refseq_version = ?, description = ?, public = ? where refseqName = ?"
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Databases records
  # [+returns+] Array of 0+ databases record rows
  def countDatabases()
    return countRecords(:mainDB, 'refseq', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Databases records
  # [+returns+] Array of 0+ databases record rows
  def selectAllDatabases()
    return selectAll(:mainDB, 'refseq', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Database record by its id
  # [+id+]      The ID of the database record to return
  # [+returns+] Array of 0 or 1 databases record rows
  def selectDatabaseById(id)
    return selectByFieldAndValue(:mainDB, 'refseq', 'refSeqId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases records using a list of ids
  # [+ids+]     Array of database IDs
  # [+returns+] Array of 0+ databases records
  def selectDatabasesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'refseq', 'refSeqId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Database by its unique name
  # [+name+]    The unique name of the database record to return
  # [+returns+] Array of 0 or 1 databases record
  def selectDatabaseByName(name)
    return selectByFieldAndValue(:mainDB, 'refseq', 'refseqName', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases using a list of names
  # [+names+]   Array of unique database names
  # [+returns+] Array of 0+ databases records
  def selectDatabasesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'refseq', 'refseqName', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases by matching an AVP via ids; get all databases possessing the attribute and its value
  # indicated by +databaseAttrNameId+ whose value is +databaseAttrValueId+.
  # [+databaseAttrNameId+]   databaseAttrNames.id for the database attribute to consider
  # [+databaseAttrValueId+]  databaseAttrValues.id for the database attribute value to match
  # [+returns+]         Array of 0+ database records
  def selectDatabasesByAttributeNameAndValueIds(databaseAttrNameId, databaseAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:mainDB, 'refseq', databaseAttrNameId, databaseAttrValueId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases by matching an AVP by texts; get all databases possessing the attribute and its value
  # named in +databaseAttrNameText+ whose value is +databaseAttrValueText+.
  # [+databaseAttrNameText+]   Database attribute name to consider
  # [+databaseAttrValueText+]  Database attribute value to match
  # [+returns+]                 Array of 0+ database records
  def selectDatabasesByAttributeNameAndValueTexts(databaseAttrNameText, databaseAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:mainDB, 'refseq', databaseAttrNameText, databaseAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases by their assembly version
  # [+version+]    The version of databases to select (String)
  # [+returns+] Array of 0+ databases records
  def selectDatabasesByVersion(version)
    return selectByFieldAndValue(:mainDB, 'refseq', 'refseq_version', version, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Databases using a list of types
  # [+types+]   Array of database types
  # [+returns+] Array of 0+ databases records
  def selectDatabasesByVersions(versions)
    return selectByFieldWithMultipleValues(:mainDB, 'refseq', 'refseq_version', types, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Database record
  # [+name+]          Unique experimental database name
  # [+type+]          A String identifying the 'type' (kind) of Database
  # [+dataLevel+]     The dataLevel of this database
  # [+experimentId+]  [optional; default=nil] The experiment_id for the experiment associated with this database
  # [+state+]         [optional; default=0] for future use
  # [+returns+]       Number of rows inserted
  def insertDatabase()
    raise "ERROR: The insertDatabase() method is not implemented."
  end

  # Insert multiple Database records using column data.
  # [+data+]    An Array of values to use for name, type, dataLevel, experimentId, state.
  #             The Array may be 2-D (i.e. N rows of 5 columns or simply a flat array with appropriate values)
  #             See the +insertDatabase()+ method for the fields needed for each record. All 5 columns are required.
  # [+numDatabases+] Number of databases to insert using values in +data+.
  #             This is required because the data array may be flat and yet
  #             have the dynamic field values for many Databases.
  # [+returns+] Number of rows inserted
  def insertDatabases(data, numDatabases)
    raise "ERROR: The insertDatabases() method is not implemented."
  end

  # Update ALL the fields of a Database record identified by its id
  # [+databaseId+]    Databases.id of the record to update
  # [+name+]          Unique database name
  # [+species+]       A String indicating the species the database is for
  # [+version+]       A String containing the assembly version of the genome
  # [+description+]   Database description String.
  # [+public+]        Boolean flag indicating whether database is public or not.
  # [+userId+]        User ID who created the database
  # [+templateId+]    Id of the recrod in genomeTemplate table (if any; if not, nil)
  # [+databaseName+]  MySQL database name
  # [+returns+]       Number of rows inserted
  def updateDatabaseById(databaseId, name, species, version, description, public, userId, templateId, databaseName)
    retVal = nil
    begin
      publicVal = ((public == true or (public.is_a?(Numeric) and public != 0) or public.strip =~ /^(?:true|yes)$/i) ? 1 : 0)
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_DATABASE_BY_ID)
      stmt.execute(userId, name, species, version, description, templateId, databaseName, publicVal, databaseId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_DATABASE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ONLY EXPOSED [to user] fields of a Database record identified by its id
  # [+databaseId+]    Databases.id of the record to update
  # [+name+]          Unique database name
  # [+species+]       A String indicating the species the database is for
  # [+version+]       A String containing the assembly version of the genome
  # [+description+]   Database description String.
  # [+public+]        Boolean flag indicating whether database is public or not.
  # [+returns+]       Number of rows inserted
  def updateDatabaseExposedFieldsById(databaseId, name, species, version, description, public)
    retVal = nil
    begin
      publicVal = ((public == true or (public.is_a?(Numeric) and public != 0) or public.strip =~ /^(?:true|yes)$/i) ? 1 : 0)
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_DATABASE_EXPOSED_FIELDS_BY_ID)
      stmt.execute(name, species, version, description, publicVal, databaseId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_DATABASE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the Database using this method.
  # [+name+]          Unique database name
  # [+species+]       A String indicating the species the database is for
  # [+version+]       A String containing the assembly version of the genome
  # [+description+]   Database description String.
  # [+public+]        Boolean flag indicating whether database is public or not.
  # [+userId+]        User ID who created the database
  # [+templateId+]    Id of the recrod in genomeTemplate table (if any; if not, nil)
  # [+databaseName+]  MySQL database name
  # [+returns+]       Number of rows updated.
  def updateDatabaseByName(name, species, version, description, public, userId, templateId, databaseName)
    retVal = nil
    begin
      publicVal = ((public == true or (public.is_a?(Numeric) and public != 0) or public.strip =~ /^(?:true|yes)$/i) ? 1 : 0)
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_WHOLE_DATABASE_BY_NAME)
      stmt.execute(userId, species, version, description, templateId, databaseName, publicVal, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_DATABASE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ONLY EXPOSED [to user] fields of a Database record identified by its name
  # [+name+]          User's name for database to update
  # [+species+]       A String indicating the species the database is for
  # [+version+]       A String containing the assembly version of the genome
  # [+description+]   Database description String.
  # [+public+]        Boolean flag indicating whether database is public or not.
  # [+returns+]       Number of rows inserted
  def updateDatabaseExposedFieldsByName(name, species, version, description, public)
    retVal = nil
    begin
      publicVal = ((public == true or (public.is_a?(Numeric) and public != 0) or public.strip =~ /^(?:true|yes)$/i) ? 1 : 0)
      connectToDataDb()
      stmt = @genbDbh.prepare(UPDATE_DATABASE_EXPOSED_FIELDS_BY_NAME)
      stmt.execute(species, version, description, publicVal, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_DATABASE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Database record using its id.
  # [+id+]      The databases.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseById(id)
    return deleteByFieldAndValue(:mainDB, 'refseq', 'refSeqId', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Database records using their ids.
  # [+ids+]     Array of databases.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabasesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'refseq', 'refSeqId', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: databaseAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all DatabaseAttrNames records
  # [+returns+] 1 row with count
  def countDatabaseAttrNames()
    return countRecords(:mainDB, 'databaseAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all DatabaseAttrNames records
  # [+returns+] Array of 0+ databaseAttrNames records
  def selectAllDatabaseAttrNames()
    return selectAll(:mainDB, 'databaseAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrNames record by its id
  # [+id+]      The ID of the databaseAttrName record to return
  # [+returns+] Array of 0 or 1 databaseAttrNames records
  def selectDatabaseAttrNameById(id)
    return selectByFieldAndValue(:mainDB, 'databaseAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrNames records using a list of ids
  # [+ids+]     Array of databaseAttrNames IDs
  # [+returns+] Array of 0+ databaseAttrNames records
  def selectDatabaseAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'databaseAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrName record by its name
  # [+name+]    The unique name of the databaseAttrName record to return
  # [+returns+] Array of 0 or 1 databaseAttrNames records
  def selectDatabaseAttrNameByName(name)
    return selectByFieldAndValue(:mainDB, 'databaseAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrNames using a list of names
  # [+names+]   Array of unique databaseAttrNames names
  # [+returns+] Array of 0+ databaseAttrNames records
  def selectDatabaseAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:mainDB, 'databaseAttrNames', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new DatabaseAttrNames record
  # [+name+]    Unique databaseAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertDatabaseAttrName(name, state=0)
    data = [ name, state ]
    return insertDatabaseAttrNames(data, 1)
  end

  # Insert multiple DatabaseAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numDatabaseAttrNames+]  Number of database attribute names to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many DatabaseAttrNames.
  # [+returns+]     Number of rows inserted
  def insertDatabaseAttrNames(data, numDatabaseAttrNames)
    return insertRecords(:mainDB, 'databaseAttrNames', data, true, numDatabaseAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a DatabaseAttrName record using its id.
  # [+id+]      The databaseAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrNameById(id)
    return deleteByFieldAndValue(:mainDB, 'databaseAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete DatabaseAttrName records using their ids.
  # [+ids+]     Array of databaseAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'databaseAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: databaseAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all DatabaseAttrValues records
  # [+returns+] 1 row with count
  def countDatabaseAttrValues()
    return countRecords(:mainDB, 'databaseAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all DatabaseAttrValues records
  # [+returns+] Array of 0+ databaseAttrValues records
  def selectAllDatabaseAttrValues()
    return selectAll(:mainDB, 'databaseAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrValues record by its id
  # [+id+]      The ID of the databaseAttrValues record to return
  # [+returns+] Array of 0 or 1 databaseAttrValues records
  def selectDatabaseAttrValueById(id)
    return selectByFieldAndValue(:mainDB, 'databaseAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrValues records using a list of ids
  # [+ids+]     Array of databaseAttrValues IDs
  # [+returns+] Array of 0+ databaseAttrValues records
  def selectDatabaseAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'databaseAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the databaseAttrValue record to return
  # [+returns+] Array of 0 or 1 databaseAttrValue records
  def selectDatabaseAttrValueBySha1(sha1)
    return selectByFieldAndValue(:mainDB, 'databaseAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the databaseAttrValue records to return
  # [+returns+] Array of 0+ databaseAttrNames records
  def selectDatabaseAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:mainDB, 'databaseAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get DatabaseAttrValues record by the exact value
  # [+value+]   The value of the databaseAttrValue record to return
  # [+returns+] Array of 0 or 1 databaseAttrValue records
  def selectDatabaseAttrValueByValue(value)
    return selectDatabaseAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get DatabaseAttrValues records using a list of the exact values
  # [+values+]  Array of values of the databaseAttrValue records to return
  # [+returns+] Array of 0+ databaseAttrNames records
  def selectDatabaseAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectDatabaseAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a database, using the attribute id.
  # "what's the value of the ___ attribute for this database?"
  #
  # [+databaseId+]           The id of the database.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectDatabaseAttrValueByDatabaseIdAndAttributeNameId(databaseId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:mainDB, 'databases', databaseId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a database, using the attribute name (text).
  # "what's the value of the ___ attribute for this database?"
  #
  # [+databaseId+]   The id of the database.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectDatabaseAttrValueByDatabaseAndAttributeNameText(databaseId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:mainDB, 'databases', databaseId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all databases), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectDatabaseAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:mainDB, 'databases', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all databases), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectDatabaseAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:mainDB, 'databases', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all databases), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectDatabaseAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:mainDB, 'databases', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all databases), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectDatabaseAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:mainDB, 'databases', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular database, using attribute ids
  # "what are the current values associated with these attributes for this database, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+databaseId+]   The id of the database to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectDatabaseAttrValueMapByEntityAndAttributeIds(databaseId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:mainDB, 'databases', databaseId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular database, using attribute names
  # "what are the current values associated with these attributes for this database, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+databaseId+]   The id of the database to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectDatabaseAttrValueMapByEntityAndAttributeTexts(databaseId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:mainDB, 'databases', databaseId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new DatabaseAttrValues record
  # [+value+]    Unique databaseAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertDatabaseAttrValue(value, state=0)
    data = [value, state ] # insertDatabaseAttrValues() will compute SHA1 for us
    return insertDatabaseAttrValues(data, 1)
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Insert multiple DatabaseAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertDatabaseAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numDatabaseAttrValues+]  Number of database attribute values to insert using values in +data+.
  #                       - This is required because the data array may be flat and yet
  #                         have the dynamic field values for many DatabaseAttrValues.
  # [+returns+]     Number of rows inserted
  def insertDatabaseAttrValues(data, numDatabaseAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:mainDB, 'databaseAttrValues', dataCopy, true, numDatabaseAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a DatabaseAttrValues record using its id.
  # [+id+]      The databaseAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValueById(id)
    return deleteByFieldAndValue(:mainDB, 'databaseAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete DatabaseAttrValues records using their ids.
  # [+ids+]     Array of databaseAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'databaseAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a DatabaseAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The databaseAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:mainDB, 'databaseAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete DatabaseAttrValues records using their sha1 digests.
  # [+ids+]     Array of databaseAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:mainDB, 'databaseAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

    # Delete a DatabaseAttrValues record using the exact value.
  # [+sha1+]    The databaseAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValueByValue(value)
    return deleteDatabaseAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete DatabaseAttrValues records using their exact values
  # [+values+]  Array of databaseAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteDatabaseAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteDatabaseAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: database2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # TODO: why are these not generic? Have no business being implemented here.
  SELECT_DATABASE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from database2attributes where databaseAttrName_id = ? and databaseAttrValue_id = ?'
  DELETE_DATABASE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from database2attributes where database_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Database2Attributes records
  # [+returns+] 1 row with count
  def countDatabase2Attributes()
    return countRecords(:mainDB, 'database2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Database2Attributes records
  # [+returns+] Array of 0+ database2attributes records
  def selectAllDatabase2Attributes()
    return selectAll(:mainDB, 'database2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Database2Attributes records by database_id ; i.e. get all the AVP mappings (an ID triple) for a database
  # [+databaseId+]   The database_id for the Database2Attributes records to return
  # [+returns+] Array of 0+ database2attributes records
  def selectDatabase2AttributesByDatabaseId(databaseId)
    return selectByFieldAndValue(:mainDB, 'database2attributes', 'database_id', databaseId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Insert a new Database2Attributes record ; i.e. set a new AVP for a database.
  # Note: this does NOT update any existing triple involving the database_id and the databaseAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that database.
  # [+databaseId+]             database_id for whom to associate an AVP
  # [+databaseAttrNameId+]     databaseAttrName_id for the attribute
  # [+databaseAttrValueId+]    databaseAttrValue_id for the attribute value
  # [+returns+]           Number of rows inserted
  def insertDatabase2Attribute(databaseId, databaseAttrNameId, databaseAttrValueId)
    data = [ databaseId, databaseAttrNameId, databaseAttrValueId ]
    return insertDatabase2Attributes(data, 1)
  end

  # Insert multiple Database2Attributes records using field data.
  # If a duplicate database2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for database_id, databaseAttrName_id, and databaseAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numDatabase2Attributes+]  Number of database2attributes to insert using values in +data+.
  #                        - This is required because the data array may be flat and yet
  #                          have the dynamic field values for many Database2Attributes.
  # [+returns+]     Number of rows inserted
  def insertDatabase2Attributes(data, numDatabase2Attributes)
    return insertRecords(:mainDB, 'database2attributes', data, false, numDatabase2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Database2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+databaseAttrNameId+]   databaseAttrName_id for tha attribute
  # [+databaseAttrValueId+]  databaseAttrValue_id for the attribute value
  # [+returns+]         Array of 0+ database2attributes records
  def selectDatabase2AttributesByAttrNameIdAndAttrValueId(databaseAttrNameId, databaseAttrValueId)
    return selectEntity2AttributesByAttrNameIdAndAttrValueId(:mainDB, 'databases', databaseAttrNameId, databaseAttrValueId)
  end

  def selectDatabaseAttributesInfo(entityNameList, attributeList=nil, errMsg=nil)
    return selectCoreEntityAttributesInfo('databases', entityNameList, attributeList, nil, 'refseqName', 'refSeqId')
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Update the value associated with a particular database's attribute.
  # All triples associating the database to an attribute will have their value replaced.
  # [+databaseId+]           ID of the database whose AVP we are updating
  # [+databaseAttrNameId+]   ID of databaseAttrName whose value to update
  # [+databaseAttrValueId+]  ID of the databaseAttrValue to associate with the attribute for a particular database
  def updateDatabase2AttributeForDatabaseAndAttrName(databaseId, databaseAttrNameId, databaseAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteDatabase2AttributesByDatabaseIdAndAttrNameId(databaseId, databaseAttrNameId)
      retVal = insertDatabase2Attribute(databaseId, databaseAttrNameId, databaseAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # TODO: why is this not generic? Have no business being implemented here.
  # Delete Database2Attributes records for a given database, or for a database and attribute name,
  # or for a database and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a database, or to remove the association of a particular
  # attribute with the database, or to remove the association only if a particular value is involved.
  # [+databaseId+]           database_id for which to delete some AVP info
  # [+databaseAttrNameId+]   [optional] databaseAttrName_id to disassociate with the database
  # [+databaseAttrValueId+]  [optional] databaseAttrValue_id to further restrict which AVPs are disassociate with the database
  # [+returns+]         Number of rows deleted
  def deleteDatabase2AttributesByDatabaseIdAndAttrNameId(databaseId, databaseAttrNameId=nil, databaseAttrValueId=nil)
    return deleteEntity2AttributesByEntityIdAndAttrNameId(:mainDB, 'databases', databaseId, databaseAttrNameId, databaseAttrValueId)
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
