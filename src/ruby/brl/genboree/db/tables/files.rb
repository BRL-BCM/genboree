require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# FILE RELATED TABLES - DBUtil Extension Methods for dealing with File-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # TABLE: files
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  #:startdoc:
  UPDATE_WHOLE_FILE_BY_ID = "update files set name = ?, label = ?, description = ?, autoArchive = ?, hide = ?,  lastModified = ?, modifiedBy = ?, remoteStorageConf_id = ?"
  UPDATE_WHOLE_FILE_BY_NAME = "update files set label = ?, description = ?, autoArchive = ?, hide = ?, lastModified = ?, modifiedBy = ?, remoteStorageConf_id = ?"
  SELECT_CHILDREN = "select name from files where name like ?/"
  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Files records
  # [+returns+] 1 row with count
  def countFiles()
    return countRecords(:userDB, 'files', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all Files records
  # [+returns+] Array of 0+ files record rows
  def selectAllFiles(includePartialEntities=false)
    return selectAll(:userDB, 'files', "ERROR: #{self.class}##{__method__}():", nil, includePartialEntities)
  end

  # Get File record by its id
  # [+id+]      The ID of the file record to return
  # [+returns+] Array of 0 or 1 files record rows
  def selectFileById(id)
    return selectByFieldAndValue(:userDB, 'files', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Get Files records using a list of ids
  # [+ids+]     Array of file IDs
  # [+returns+] Array of 0+ bioSamples records
  def selectFilesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'files', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get File by its unique name
  # [+name+]    The unique name of the file record to return
  # [+returns+] Array of 0 or 1 files record
  def selectFileByName(name)
    return selectByFieldAndValue(:userDB, 'files', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Gets a file record by using sha digest (of file name)
  # [+name+]
  # [+returns+] Array of 0 or 1 records
  def selectFileByDigest(name, checkWithSlash=false)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)
      escName = Mysql2::Client.escape(name.to_s)   # Must escape any incoming argument going into actual SQL for safety
      sql = "select * from files where digest = sha1('#{escName}')"
      if(checkWithSlash)
        escNameWithSlash = Mysql2::Client.escape("#{name}/")
        sql << " or digest = sha1('#{escNameWithSlash}') "
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "about to issue sql: #{sql.inspect}")
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Deletes list of files by names
  # [+fileList+] An array of files (paths) to be deleted
  # [returns+] Number of deleted records
  def deleteFilesByName(fileList)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = "delete from files where name in ("
      escFileList = []
      fileList.each { |fileName|
        escFileList << "'#{Mysql2::Client.escape(fileName)}'"
      }
      sql << escFileList.join(",")
      sql << ")"
      #$stderr.puts(sql)
      recs = client.query(sql)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get Files using a list of names
  # [+names+]   Array of unique file names
  # [+returns+] Array of 0+ files records
  def selectFilesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'files', 'names', names, "ERROR: #{self.class}##{__method__}():")
  end

  # Get the children files/folder of a folder.
  # [+path+] path of the folder
  # [+depth+] full (recursive) or immediate (only tier 1 files/folders)
  # [+detailed+] if true then return all fields, if false return only names
  # [+returns+] Array of 0+ records (returned folders will end with a '/')
  def selectChildrenFilesAndFolders(path, depth='immediate', detailed=false, includePartialEntities=false)
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)
      escPath = Mysql2::Client.escape(path) if(!path.nil? and !path.empty?)   # Must escape any incoming argument going into actual SQL for safety
      sql = nil
      if(path.nil? or path.empty?)
        sql = ( detailed == true ? "select * from files " : "select name from files " )
      else
        sql = ( detailed == true ? "select * from files where name like '#{escPath}/%'" : "select name from files where name like '#{escPath}/%'" )
      end
      unless(includePartialEntities)
        if(path.nil? or path.empty?)
          sql << " where "
        else
          sql << " and "
        end
        sql << " files.id NOT IN (select files.id from files, file2attributes, fileAttrNames,
          fileAttrValues where fileAttrNames.name = 'gbPartialEntity' and fileAttrValues.value = true and
          files.id = file2attributes.file_id and fileAttrNames.id = file2attributes.fileAttrName_id and
          fileAttrValues.id = file2attributes.fileAttrValue_id) " 
      end
      recs = client.query(sql)
      # Filter out the records that are 2 or more tiers level deep and keep only the immediate children
      if(depth == 'immediate')
        t1 = Time.now
        immediateChildren = {}
        allFields = []
        re = nil
        if(path.nil? or path.empty?)
          re = /^([^\/]+\/?)/
        else
          re = /^#{Regexp.quote(path)}\/([^\/]+\/?)/
        end
        fileHash = {}
        recs.each { |row|
          row['name'] =~ re
          baseFileName = $1
          fileName = path.nil? ? baseFileName : "#{path}/#{baseFileName}"
          next if(!path.nil? and "#{path}/" == fileName) # Required when there is a record for an empty folder. The query will return the folder name with a '/'
          if(!detailed)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "row: #{row}; fileName: #{fileName.inspect}")
            if(!fileHash.has_key?(fileName))
              allFields << {'name' => fileName}
              fileHash[fileName] = nil
            end
          else
            if(!fileHash.has_key?(fileName))
              row['name'] = fileName
              allFields << row
              fileHash[fileName] = nil
            end
          end
        }
        retVal = allFields
      elsif(depth == 'full')
        retVal = []
        unless(detailed)
          recs.each { |rec|
            next if(!path.nil? and "#{path}/" == rec['name']) # Required when there is a record for an empty folder. The query will return the folder name with a '/'
            retVal << { 'name' => rec['name'] }
          }
        else
          recs.each { |rec|
            next if(!path.nil? and "#{path}/" == rec['name']) # Required when there is a record for an empty folder. The query will return the folder name with a '/'
            retVal << rec
          }
        end
      else
        raise "Unrecognized value for 'depth': #{depth.inspect}"
      end
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get Files by matching an AVP by ids; get all files possessing the attribute and its value
  # indicated by +fileAttrNameId+ whose value is +fileAttrValueId+.
  # [+fileAttrNameId+]   fileAttrNames.id for the file attribute to consider
  # [+fileAttrValueId+]  fileAttrValues.id for the file attribute value to match
  # [+returns+]               Array of 0+ file records
  def selectFilesByAttributeNameAndValueIds(fileAttrNameId, fileAttrValueId)
    return selectEntitiesByAttributeNameAndValueIds(:userDB, 'files', fileAttrNameId, fileAttrValueId, "ERROR: #{self.class}##{__method__}():")
  end

  # Get Files by matching an AVP by texts; get all files possessing the attribute and its value
  # named in +fileAttrNameText+ whose value is +fileAttrValueText+.
  # [+fileAttrNameText+]   File attribute name to consider
  # [+fileAttrValueText+]  File attribute value to match
  # [+returns+]                 Array of 0+ file records
  def selectFileByAttributeNameAndValueTexts(fileAttrNameText, fileAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'files', fileAttrNameText, fileAttrValueText, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new File record
  # [+name+]                Unique file name
  # [+state+]               [optional; default=0] for future use
  # [+returns+]             Number of rows inserted
  def insertFile(name, label, description, autoArchive, hide, createdDate, lastModified, modifiedBy, remoteStorageConf_id=nil)
    data = [ name, label, description, autoArchive, hide, createdDate, lastModified, modifiedBy, remoteStorageConf_id ]
    return insertFiles(data, 1)
  end

  # Insert multiple File records using column data.
  # [+data+]           An Array of values to use for name, state.
  #                    The Array may be 2-D (i.e. N rows of 6 columns or simply a flat array with appropriate values)
  #                    See the +insertFile()+ method for the fields needed for each record.
  # [+numFiles+]  Number of files to insert using values in +data+.
  #                    This is required because the data array may be flat and yet
  #                    have the dynamic field values for many Files.
  # [+returns+]        Number of rows inserted
  def insertFiles(data, numFiles, addHexDigest=true)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    if(addHexDigest)
      while(ii < dataCopy.size)
        dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
        ii += 10
      end
    end
    return insertRecords(:userDB, 'files', dataCopy, true, numFiles, 10, true,  "ERROR: #{self.class}##{__method__}():", false, false)
  end

  # Update ALL the fields of a File record identified by its id
  # [+id+]                  Files.id of the record to update
  # [+name+]                Unique file name
  # [+label+]
  # [+description+]
  # [+autoArchive+]
  # [+hide+]
  # [+lastModified+]        MUST be a Time object
  # [+returns+]             Number of rows inserted
  def updateFileById(id, name, label, description, autoArchive, hide, lastModified, modifiedBy, remoteStorageConf_id=nil)
    retVal = sql = nil
    begin
      connectToDataDb()
      sql = UPDATE_WHOLE_FILE_BY_ID.dup()
      sql << ", digest = '#{SHA1.hexdigest(name)}' where id = ?"
      stmt = @dataDbh.prepare(sql)
      stmt.execute(name, label, description, autoArchive, hide, prepTimeStamp(lastModified), modifiedBy, remoteStorageConf_id, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql ? sql : UPDATE_WHOLE_FILE_BY_ID)
      retVal = -1
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a record identified by its name.
  # You cannot rename the File using this method.
  # [+name+]                Unique file name
  # [+label+]
  # [+description+]
  # [+autoArchive+]
  # [+hide+]
  # [+lastModified+]        MUST be a Time object
  # [+returns+]             Number of rows inserted
  def updateFileByName(name, label, description, autoArchive, hide, lastModified, modifiedBy, remoteStorageConf_id=nil)
    retVal = nil
    begin
      connectToDataDb()
      sql = UPDATE_WHOLE_FILE_BY_NAME.dup()
      sql << ", digest = '#{SHA1.hexdigest(name)}' where name = ?"
      stmt = @dataDbh.prepare(sql)
      stmt.execute(label, description, autoArchive, hide, prepTimeStamp(lastModified), modifiedBy, remoteStorageConf_id, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, UPDATE_WHOLE_FILE_BY_NAME)
      retVal = -1
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a File record using its id.
  # [+id+]      The files.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileById(id)
    return deleteByFieldAndValue(:userDB, 'files', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete File records using their ids.
  # [+ids+]     Array of files.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFilesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'files', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a File record using its name.
  # [+name+]      The files.name of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileByName(name)
    return deleteByFieldAndValue(:userDB, 'files', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Mark a file record identified by its id as a template by updating its state
  # [+id+]            Files.id of the record to update
  # [+returns+]       Number of rows updated.
  def setFileStateToTemplate(id)
    return setStateBit(:userDB, 'files', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Mark a file record identified by its id as completed by updating its state
  # [+id+]            Files.id of the record to update
  # [+returns+]       Number of rows updated.
  def setFileStateToCompleted(id)
    return setStateBit(:userDB, 'files', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a file record identified by its id is a template
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is a template false otherwise
  def isFileTemplate?(id)
    return checkStateBit(:userDB, 'files', BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a file record identified by its id is completed
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the record is in a completed state, false otherwise
  def isFileCompleted?(id)
    return checkStateBit(:userDB, 'files', BRL::Genboree::Constants::IS_COMPLETED_STATE, 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Check if  a file record identified by its id is still in progress
  # [+id+]            Studies.id of the record to check
  # [+returns+]       true if the file record is in progress, false otherwise
  def isFileInProgress?(id)
    return (not(isFileTemplate?(id) or isFileCompleted?(id)))
  end

  # --------
  # Table: fileAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_FILE_ATTRNAME = 'insert into fileAttrNames values (null,?,?)'
  UPDATE_WHOLE_FILE_ATTRNAME = 'update fileAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all FileAttrNames records
  # [+returns+] 1 row with count
  def countFileAttrNames()
    return countRecords(:userDB, 'fileAttrNames', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all FileAttrNames records
  # [+returns+] Array of 0+ fileAttrNames records
  def selectAllFileAttrNames()
    return selectAll(:userDB, 'fileAttrNames', "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrNames record by its id
  # [+id+]      The ID of the fileAttrName record to return
  # [+returns+] Array of 0 or 1 fileAttrNames records
  def selectFileAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'fileAttrNames', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrNames records using a list of ids
  # [+ids+]     Array of fileAttrNames IDs
  # [+returns+] Array of 0+ fileAttrNames records
  def selectFileAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'fileAttrNames', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrName record by its name
  # [+name+]    The unique name of the fileAttrName record to return
  # [+returns+] Array of 0 or 1 fileAttrNames records
  def selectFileAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'fileAttrNames', 'name', name, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrNames using a list of names
  # [+names+]   Array of unique fileAttrNames names
  # [+returns+] Array of 0+ fileAttrNames records
  def selectFileAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'fileAttrNames', 'name', names, "ERROR: #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a file, using the attribute id.
  # "what's the value of the ___ attribute for this file?"
  #
  # [+fileId+]   The id of the file.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectFileAttrValueByFileIdAndAttributeNameId(fileId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'files', fileId, attrNameId, "ERROR: #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a file, using the attribute name (text).
  # "what's the value of the ___ attribute for this file?"
  #
  # [+fileId+]   The id of the file.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+returns+]         Array of 0-1 attribute value record
  def selectFileAttrValueByFileAndAttributeNameText(fileId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'files', fileId, attrNameText, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all files), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectFileAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'files', attrNameId, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all files), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectFileAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'files', attrNameText, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all files), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectFileAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'files', attrNameIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all files), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectFileAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'files', attrNameTexts, "ERROR: #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular file, using attribute ids
  # "what are the current values associated with these attributes for this file, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+fileId+]   The id of the file to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectFileAttrValueMapByEntityAndAttributeIds(fileId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'files', fileId, attrNameIds, "ERROR: #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular file, using attribute names
  # "what are the current values associated with these attributes for this file, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+fileId+]   The id of the file to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectFileAttrValueMapByEntityAndAttributeTexts(fileId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'files', fileId, attrNameTexts, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new FileAttrNames record
  # [+name+]    Unique fileAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertFileAttrName(name, state=0)
    data = [ name, state ]
    return insertFileAttrNames(data, 1)
  end

  # Insert multiple FileAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numFileAttrNames+] Number of file attribute names to insert using values in +data+.
  #                           - This is required because the data array may be flat
  #                             and yet have the dynamic field values for many FileAttrNames.
  # [+returns+]     Number of rows inserted
  def insertFileAttrNames(data, numFileAttrNames)
    return insertRecords(:userDB, 'fileAttrNames', data, true, numFileAttrNames, 2, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a FileAttrName record using its id.
  # [+id+]      The fileAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'fileAttrNames', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete FileAttrName records using their ids.
  # [+ids+]     Array of fileAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'fileAttrNames', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # --------
  # Table: fileAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_FILE_ATTRVALUE = 'update fileAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all FileAttrValues records
  # [+returns+] 1 row with count
  def countFileAttrValues()
    return countRecords(:userDB, 'fileAttrValues', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all FileAttrValues records
  # [+returns+] Array of 0+ fileAttrValues records
  def selectAllFileAttrValues()
    return selectAll(:userDB, 'fileAttrValues', "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrValues record by its id
  # [+id+]      The ID of the fileAttrValues record to return
  # [+returns+] Array of 0 or 1 fileAttrValues records
  def selectFileAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'fileAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get FileAttrValues records using a list of ids
  # [+ids+]     Array of fileAttrValues IDs
  # [+returns+] Array of 0+ fileAttrValues records
  def selectFileAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'fileAttrValues', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the fileAttrValue record to return
  # [+returns+] Array of 0 or 1 fileAttrValue records
  def selectFileAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'fileAttrValues', 'sha1', sha1, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the fileAttrValue records to return
  # [+returns+] Array of 0+ fileAttrValues records
  def selectFileAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'fileAttrValues', 'sha1', sha1s, "ERROR: #{self.class}##{__method__}():")
  end

  # Get FileAttrValues record by the exact value
  # [+value+]   The value of the fileAttrValue record to return
  # [+returns+] Array of 0 or 1 fileAttrValue records
  def selectFileAttrValueByValue(value)
    return selectFileAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get FileAttrValues records using a list of the exact values
  # [+values+]  Array of values of the fileAttrValue records to return
  # [+returns+] Array of 0+ fileAttrValues records
  def selectFileAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectFileAttrValueBySha1s(sha1s)
  end

  # Get the attr value for an attribute for a file
  # [+fileId+] file id
  # [+attrName+] name of attribute
  # [+returns+] Array of 0+ fileAttrValues records
  def getAttrValueByAttrNameAndFileId(fileId, attrName)
    retVal = nil
    begin
      connectToDataDb()
      sql = "select fileAttrValues.value from file2attributes, fileAttrValues, fileAttrNames where file2attributes.file_id = ? "
      sql << "and file2attributes.fileAttrValue_id = fileAttrValues.id and file2attributes.fileAttrName_id = fileAttrNames.id and fileAttrNames.name = ? "
      stmt = @dataDbh.prepare(sql)
      stmt.execute(fileId, attrName)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new FileAttrValues record
  # [+value+]   Unique fileAttrValues value
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertFileAttrValue(value, state=0)
    data = [value, state ] # insertFileAttrValues() will compute SHA1 for us
    return insertFileAttrValues(data, 1)
  end

  # Insert multiple FileAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertFileAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numFileAttrValues+]  Number of file attribute values to insert using values in +data+.
  #                             This is required because the data array may be flat and yet
  #                             have the dynamic field values for many FileAttrValues.
  # [+returns+]     Number of rows inserted
  def insertFileAttrValues(data, numFileAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'fileAttrValues', dataCopy, true, numFileAttrValues, 3, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a FileAttrValues record using its id.
  # [+id+]      The fileAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'fileAttrValues', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete FileAttrValues records using their ids.
  # [+ids+]     Array of fileAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'fileAttrValues', 'id', ids, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete a FileAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The fileAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'fileAttrValues', 'sha1', sha1, "ERROR: #{self.class}##{__method__}():")
  end

  # Delete FileAttrValues records using their sha1 digests.
  # [+ids+]     Array of fileAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'fileAttrValues', 'sha1', sha1s, "ERROR: #{self.class}##{__method__}():")
  end

    # Delete a FileAttrValues record using the exact value.
  # [+sha1+]    The fileAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValueByValue(value)
    return deleteFileAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete FileAttrValues records using their exact values
  # [+values+]  Array of fileAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteFileAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deleteFileAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: file2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_FILE2ATTRIBUTE = 'insert into file2attributes values (?,?,?)'
  SELECT_FILE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from file2attributes where fileAttrName_id = ? and fileAttrValue_id = ?'
  DELETE_FILE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from file2attributes where file_id = ? '
  SELECT_FILE_ATTRNAMES_AND_FILE_ATTRVALUES_BY_FILEID = 'select fileAttrNames.name, fileAttrValues.value from fileAttrNames, fileAttrValues, file2attributes ' +
                                                        'where fileAttrNames.id = file2attributes.fileAttrName_id and fileAttrValues.id = file2attributes.fileAttrValue_id and file2attributes.file_id = ?'
  SELECT_ALL_ATTRIBUTE_VALUE_PAIRS_FOR_ALL_FILES = "select files.name AS fileName, fileAttrNames.name, fileAttrValues.value from file2attributes, files, fileAttrNames, fileAttrValues
                                                    where file2attributes.fileAttrName_id = fileAttrNames.id and file2attributes.fileAttrValue_id = fileAttrValues.id  and files.id = file2attributes.file_id"
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all File2Attributes records
  # [+returns+] 1 row with count
  def countFile2Attributes()
    return countRecords(:userDB, 'file2attributes', "ERROR: #{self.class}##{__method__}():")
  end

  # Get all File2Attributes records
  # [+returns+] Array of 0+ file2attributes records
  def selectAllFile2Attributes()
    return selectAll(:userDB, 'file2attributes', "ERROR: #{self.class}##{__method__}():")
  end

  # Get File2Attributes records by file_id ; i.e. get all the AVP mappings (an ID triple) for a file
  # [+fileId+] The file_id for the File2Attributes records to return
  # [+returns+] Array of 0+ file2attributes records
  def selectFile2AttributesByFileId(fileId)
    return selectByFieldAndValue(:userDB, 'file2attributes', 'file_id', fileId, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new File2Attributes record ; i.e. set a new AVP for a file.
  # Note: this does NOT update any existing triple involving the file_id and the fileAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that file.
  # [+fileId+]           file_id for whom to associate an AVP
  # [+fileAttrNameId+]   fileAttrName_id for the attribute
  # [+fileAttrValueId+]  fileAttrValue_id for the attribute value
  # [+returns+]               Number of rows inserted
  def insertFile2Attribute(fileId, fileAttrNameId, fileAttrValueId)
    data = [ fileId, fileAttrNameId, fileAttrValueId ]
    return insertFile2Attributes(data, 1)
  end

  # Insert multiple File2Attributes records using field data.
  # If a duplicate file2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for file_id, fileAttrName_id, and fileAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numFile2Attributes+]  Number of file2attributes to insert using values in +data+.
  #                              - This is required because the data array may be flat and yet
  #                                have the dynamic field values for many File2Attributes.
  # [+returns+]     Number of rows inserted
  def insertFile2Attributes(data, numFile2Attributes, dupKeyUpdateCol='fileAttrValue_id')
    return insertRecords(:userDB, 'file2attributes', data, false, numFile2Attributes, 3, true, "ERROR: #{self.class}##{__method__}():", dupKeyUpdateCol)
  end

  # [+returns+] Array of 0 or 1 records
  def selectAllAttrValuePairsForAllFiles()
    client = retVal = nil
    begin
      client = getMysql2Client(:userDB)
      sql = SELECT_ALL_ATTRIBUTE_VALUE_PAIRS_FOR_ALL_FILES.dup()
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Select all File2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+fileAttrNameId+]   fileAttrName_id for tha attribute
  # [+fileAttrValueId+]  fileAttrValue_id for the attribute value
  # [+returns+]               Array of 0+ file2attributes records
  def selectFile2AttributesByAttrNameIdAndAttrValueId(fileAttrNameId, fileAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_FILE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(fileAttrNameId, fileAttrValueId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, SELECT_FILE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Return Attr names and values based on file id
  # [+fileId+]
  # [+returns+] Array of 0+ records
  def selectFileAttrNamesAndValuesByFileId(fileId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_FILE_ATTRNAMES_AND_FILE_ATTRVALUES_BY_FILEID.dup())
      stmt.execute(fileId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, SELECT_FILE_ATTRNAMES_AND_FILE_ATTRVALUES_BY_FILEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular file's attribute.
  # All triples associating the file to an attribute will have their value replaced.
  # [+fileId+]           ID of the file whose AVP we are updating
  # [+fileAttrNameId+]   ID of fileAttrName whose value to update
  # [+fileAttrValueId+]  ID of the fileAttrValue to associate with the attribute for a particular file
  def updateFile2AttributeForFileAndAttrName(fileId, fileAttrNameId, fileAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deleteFile2AttributesByFileIdAndAttrNameId(fileId, fileAttrNameId)
      retVal = insertFile2Attribute(fileId, fileAttrNameId, fileAttrValueId)
    rescue => @err
      DBUtil.logDbError( "ERROR: #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete File2Attributes records for a given file, or for a file and attribute name,
  # or for a file and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a file, or to remove the association of a particular
  # attribute with the file, or to remove the association only if a particular value is involved.
  # [+fileId+]           file_id for which to delete some AVP info
  # [+fileAttrNameId+]   [optional] fileAttrName_id to disassociate with the file
  # [+fileAttrValueId+]  [optional] fileAttrValue_id to further restrict which AVPs are disassociate with the file
  # [+returns+]               Number of rows deleted
  def deleteFile2AttributesByFileIdAndAttrNameId(fileId, fileAttrNameId=nil, fileAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_FILE2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and fileAttrName_id = ?' unless(fileAttrNameId.nil?)
      sql += ' and fileAttrValue_id = ?' unless(fileAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(fileAttrNameId.nil?)
        stmt.execute(fileId)
      elsif(fileAttrValueId.nil?)
        stmt.execute(fileId, fileAttrNameId)
      else
        stmt.execute(fileId, fileAttrNameId, fileAttrValueId)
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
  # TABLE: remoteStorageConfs
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
 
  # Get all remoteStorageConfs records
  # [+returns+] Array of 0+ files record rows
  def selectAllRemoteStorageConfs(includePartialEntities=false)
    return selectAll(:userDB, 'remoteStorageConfs', "ERROR: #{self.class}##{__method__}():", nil, includePartialEntities)
  end

  # Get remoteStorageConf record by its id
  # [+id+]      The ID of the remoteStorageConf record to return
  # [+returns+] Array of 0 or 1 remoteStorageConfs record rows
  def selectRemoteStorageConfById(id)
    return selectByFieldAndValue(:userDB, 'remoteStorageConfs', 'id', id, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert multiple remoteStorageConfs records using column data.
  # If an existing remoteStorageConf is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of confs 
  # [+numFileAttrNames+] Number of confs to insert using values in +data+.
  #                           - This is required because the data array may be flat
  #                             and yet have the dynamic field values for many FileAttrNames.
  # [+returns+]     Number of rows inserted
  def insertRemoteStorageConfs(data, numConfs)
    return insertRecords(:userDB, 'remoteStorageConfs', data, true, numConfs, 1, true, "ERROR: #{self.class}##{__method__}():")
  end

  # Insert a new remoteStorageConfs record
  # [+conf+]    Unique conf 
  # [+returns+] Number of rows inserted
  def insertRemoteStorageConf(conf)
    data = [ conf ]
    return insertRemoteStorageConfs(data, 1)
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
