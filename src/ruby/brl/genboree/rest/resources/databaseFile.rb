#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/util/expander'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/databaseFileEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/data/fileEntity'
require 'brl/genboree/abstract/resources/staticFileHandler'
require 'brl/genboree/storageHelpers/localStorageHelper'
require 'brl/genboree/storageHelpers/ftpStorageHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # DatabaseFile - exposes information about the custom links of a specific database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DatabaseFileEntity
  class DatabaseFile < BRL::REST::Resources::GenboreeResource
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }


    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/file/{file}"

    RESOURCE_DISPLAY_NAME = "DatabaseFile"
    RSRC_TYPE = 'file'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/</tt>
    def self.pattern()
      return %r{(?!.*/queryable$)^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/file/([^\?]+)}       # Look for /REST/v1/group/{grp}/db/{db} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving databases etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])
        @subDirs = Rack::Utils.unescape(@uriMatchData[3])[0..-1]
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
        @dbFilesObj = nil
        @dbFileHash = nil
        @tempArea = ENV['TMPDIR']
      end
      return initStatus
    end
    
    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      status = nil
      fileRecs = @dbu.selectFileByDigest(@fileName, true)
      if(fileRecs.nil? or fileRecs.empty?)
        status = :'Not Found'
      else
        status = :'OK'
      end
      return status
    end

    def setDbFilesInfo()
      if(@dbFilesObj.nil?)
        @dbFilesObj = BRL::Genboree::Abstract::Resources::DatabaseFiles.new(@groupName, @dbName)
      end
      @dbFileHash = @dbFilesObj.findFileRecByFileName(@fileName)
    end

    def releaseDbFilesInfo()
      @dbFileHash = nil
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      # Do initOperation to grab @groupName / @dbName / @fileName (FULL file name), etc.
      initStatus = initOperation()
      # If initOperation is successful, we proceed.
      if(initStatus == :OK)
        begin
          # Grab the file record associated with our current @fileName (according to its SHA digest)
          fileRecs = @dbu.selectFileByDigest(@fileName, true)
          # If the file record exists, then we proceed
          if(!fileRecs.nil? and !fileRecs.empty?)
            # Grab the specific file record from the fileRecs array (which is always just one record anyway)
            fileRec = fileRecs[0]
            # Create storage helper that will help us GET appropriate information associated with this file
            # We figure out which storage helper we want by consulting the fileRec's "remoteStorageConf_id" field.
            storageHelper = createStorageHelperFromRec(fileRec)
            begin
              # Grab custom attributes associated with the current file
              attributes = {}
              attributeRecs = @dbu.selectFileAttrNamesAndValuesByFileId(fileRec['id'])
              if(!attributeRecs.nil? and !attributeRecs.empty?)
                attributeRecs.each { |rec|
                  attributes[rec['name']] = rec['value']
                }
              end
              # Save those custom attributes in the "attributes" field
              fileRec['attributes'] = attributes
              # Replace userId with user login - gbSuperuser doesn't have a user login so we just make the "modifiedBy" field blank in that case.
              modifiedBy = fileRec['modifiedBy']
              if(modifiedBy.to_i == @genbConf.gbSuperuserId.to_i)
                fileRec['modifiedBy'] = ""
              else
                userRecs = @dbu.getUserByUserId(modifiedBy)
                fileRec['modifiedBy'] = userRecs.first['name']
              end
              # Check file's type and size and save that information in fileRec's "type" and "size" fields, respectively.
              fileRec['type'] = storageHelper.getFileType(@fileName)
              fileRec['size'] = storageHelper.getFileSize(@fileName)
              mimeType = storageHelper.getMimeType(@fileName)
              fileRec['mimeType'] = ( mimeType.nil? ? "application/octet-stream" : mimeType )
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "fileRec:\n\n    #{fileRec.inspect}\n\nfileRec.to_json:\n\n#{fileRec.to_json}\n\n")
              respEntity = BRL::Genboree::REST::Data::FileEntity.deserialize(fileRec.to_json, :JSON)
              # Fix date fields. JSON can bugger them up the way this was created.
              respEntity.createdDate = fileRec['createdDate'].rfc822
              respEntity.lastModified = fileRec['lastModified'].rfc822
              # If respEntity is fine, then we configure our response based on the information gathered above.
              if(respEntity != :'Unsupported Media Type')
                @statusName = configResponse(respEntity)
              else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL: Could not get records for database #{@databaseName.inspect} in user group #{@groupName.inspect} for file: #{@fileName.inspect}."
              end
            ensure
              storageHelper.closeRemoteConnection()
            end
          # If the file record doesn't exist or is empty, we return a "Not Found" error.
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          @statusMsg = "FATAL: could not get records for file: #{@fileName.inspect}. Message: #{err}\n#{err.backtrace.join("\n")}"
          @statusName = :'Internal Server Error'
          $stderr.puts @statusMsg
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          fileRecs = @dbu.selectFileByDigest(@fileName.chomp('/'), true)
          if(!fileRecs.nil? and !fileRecs.empty? and @req.body.is_a?(StringIO) and @req.body.string.empty?)
            @statusName, @statusMsg = :'Bad Request', "The file/folder already exists so it can not be created and the request body is empty so it can not be updated."
          else
            reqEntity = parseRequestBodyForEntity(['FileEntity'])
            if(reqEntity == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = 'Unacceptable format.  Request body must be a FileEntity.  If you are trying to upload the file, PUT to the API resource /grp/<grp>/db/<db>/file/<fileName>/data'
            else
              # 'Touch' the file if it doesn't exist yet and insert a record for it in the database
              if(fileRecs.nil? or fileRecs.empty?)
                # Create storage helper from top-level file record
                storageHelper = createStorageHelperFromTopRec(@fileName)
                begin
                  # Next, we will have to "touch" the file.
                  # For local files, we just figure out our directory structure and then touch the file.
                  # This is currently redundant with FileManagement's writeOnDisk method.
                  if(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                    if(@fileName !~ /\/$/) # Not a folder
                      filesDir = storageHelper.filesDir
                      targetDirForDbRec = ""
                      subDirs = File.dirname(@fileName)
                      if(subDirs == '.') # Then just a file name, no subdirs involved
                        actualFileName = @fileName
                        fullEscSubDirs = filesDir.path
                      else # We have some subdirs telling us where to put the file (they may need to be created)
                        targetDirForDbRec = subDirs
                        actualFileName = File.basename(@fileName)
                        # Create escaped version of the subdirs if they don't exist. (user may like dirs with ' " * : or whatever...so we make them safe)
                        escSubDirs = subDirs.split('/').map { |xx| CGI.escape(xx) }.join('/')
                        fullEscSubDirs = "#{filesDir.path}/#{escSubDirs}"
                        `mkdir -p #{fullEscSubDirs}`
                      end
                      escActualFileName = CGI.escape(actualFileName)
                      fullFilePath = "#{fullEscSubDirs}/#{escActualFileName}"
                      unless(fullFilePath[0].chr == '/')
                        $stderr.debugPuts(__FILE__, __method__, "FATAL RELATIVE DIR ERROR!!", "Ended up creating a full path of #{fullFilePath.inspect} which does not appear to be a full path to actual disk location for #{@fileName.inspect} content. Probably a bug! Probably can lose data & pollute storage! Check code using following backtrace:")
                        begin
                          raise
                        rescue => noErr
                          $stderr.puts noErr.backtrace.join("\n")
                        end
                        $stderr.puts "\n"
                      end
                      # Remove the existing file if it's there on disk
                      FileUtils.rm(fullFilePath) if(File.exists?(fullFilePath))
                      # Create the file by touching it
                      `touch #{fullFilePath}`
                    else
                      # Otherwise, we're creating a folder
                      `mkdir -p #{storageHelper.fileBase}/#{File.makeSafePath(@fileName)}`
                    end
                  else                    
                    storageHelper.uploadFile(@fileName, StringIO.new(''))
                  end
                  # Add record to files table in user's mysql database - note that remoteStorageConf_id is the top-level storageID (storageHelper.storageID)
                  @dbu.insertFile(@fileName, @fileName, nil, 0, 0, Time.now(), Time.now(), @userId, storageHelper.storageID)
                  fileRecs = @dbu.selectFileByDigest(@fileName)
                ensure
                  storageHelper.closeRemoteConnection()
                end
              end
              # If we are going to try to rename the file below, we need to keep track of whether the rename was successful 
              renameSuccess = true
              if(!reqEntity.nil?)
                fileRec = fileRecs[0]
                if(@fileName != reqEntity.name) # Rename is necessary
                  # Create storage helper (for renaming purposes)
                  storageHelper = createStorageHelperFromRec(fileRec)
                  begin
                    # Compare remote storage IDs between top-level folders of old path and new path
                    # If these top-level folders don't have matching remote storage IDs, rename will fail because they MUST match
                    oldTopFolderPath = "#{@fileName.split("/")[0]}/"
                    newTopFolderPath = "#{reqEntity.name.split("/")[0]}/"
                    oldRecs = @dbu.selectFileByDigest(oldTopFolderPath, false)
                    newRecs = @dbu.selectFileByDigest(newTopFolderPath, false)
                    oldRemoteID = (!oldRecs.empty? ? oldRecs[0]['remoteStorageConf_id'] : nil)
                    newRemoteID = (!newRecs.empty? ? newRecs[0]['remoteStorageConf_id'] : nil)
                    unless(oldRemoteID == newRemoteID)
                      renameSuccess = false
                      @statusName, @statusMsg = :'Bad Request', "You were unable to rename your file because you are trying to rename your file from local to remote (or remote to local). This is not permitted."
                    end
                    if(renameSuccess)
                      # Rename file using storageHelper's renameFile method
                      renameSuccess = storageHelper.renameFile(fileRec, reqEntity.name)
                      # Rename will fail if file already exists at new path or if fatal error occurs when renaming
                      if(renameSuccess == :ALREADY_EXISTS)
                        renameSuccess = false
                        @statusName, @statusMsg = :'Bad Request', "You were unable to rename your file because the new name (found in your FileEntity's 'name' field) is already being used."
                      elsif(renameSuccess == :FATAL)
                        renameSuccess = false
                        @statusName, @statusMsg = :'Bad Request', "You were unable to rename your file because there was a fatal error."
                      else
                        renameSuccess = true
                      end
                    end
                    # Update @fileName if rename was successful
                    @fileName = reqEntity.name if(renameSuccess)
                  ensure
                    storageHelper.closeRemoteConnection()
                  end
                end
                # We want to skip the rest of this PUT call if renameSuccess is false
                unless(renameSuccess)
                else
                  #We will not allow users to update the remoteStorageConf_id associated with a file - FTP files remain FTP, and local files remain local
                  @dbu.updateFileById(fileRec['id'], reqEntity.name, reqEntity.label, reqEntity.description, reqEntity.autoArchive, reqEntity.hide, Time.now(), @userId, fileRec['remoteStorageConf_id'])
                  # Update attributes
                  if(!reqEntity.attributes.nil? and !reqEntity.attributes.empty?)
                    attrNameRecs = []
                    attrValueRecs = []
                    attrValueArray = []
                    attributes = reqEntity.attributes
                    attributes.each_key { |attrName|
                      attrNameRecs << [attrName, 0]
                      attrValueRecs << [attributes[attrName], 0]
                      attrValueArray << attributes[attrName]
                    }
                    # Insert on duplicate is enabled
                    @dbu.insertFileAttrNames(attrNameRecs, attrNameRecs.size)
                    @dbu.insertFileAttrValues(attrValueRecs, attrValueRecs.size)
                    # Get the list of attr names and values which we just inserted
                    attrNames = @dbu.selectFileAttrNamesByNames(attributes.keys)
                    attrValues = @dbu.selectFileAttrValueByValues(attrValueArray)
                    attrNameIdHash = {}
                    attrNames.each { |rec|
                      attrNameIdHash[rec['name']] = rec['id']
                    }
                    attrValueIdHash = {}
                    attrValues.each { |rec|
                      attrValueIdHash[rec['value']] = rec['id']
                    }
                    fileUpdateRecs = []
                    fileId = fileRec['id']
                    attributes.each_key { |attrName|
                      attrValue = attributes[attrName]
                      fileUpdateRecs << [fileId, attrNameIdHash[attrName], attrValueIdHash[attrValue]]
                    }
                    @dbu.insertFile2Attributes(fileUpdateRecs, fileUpdateRecs.size, dupKeyUpdateCol='fileAttrValue_id')
                  end
                end
              end
              if(renameSuccess)
                # Build the response body using the updated data
                fileRecs = @dbu.selectFileByDigest(@fileName)
                fileRec = fileRecs[0]
                attributes = {}
                attributeRecs = @dbu.selectFileAttrNamesAndValuesByFileId(fileRec['id'])
                if(!attributeRecs.nil? and !attributeRecs.empty?)
                  attributeRecs.each { |rec|
                    attributes[rec['name']] = rec['value']
                  }
                end
                fileRec['attributes'] = attributes
                fileRec['type'] = ""
                fileRec['size'] = ""
                fileRec['mimeType'] = ""
                # Find storageType / storageHost
                if(fileRec['remoteStorageConf_id'] == nil or fileRec['remoteStorageConf_id'] == 0)
                  fileRec['storageType'] = "local"
                  fileRec['storageHost'] = "local"
                else
                  conf = @dbu.selectRemoteStorageConfById(fileRec['remoteStorageConf_id'])
                  conf = JSON.parse(conf[0]["conf"])
                  fileRec['storageType'] = conf["type"]
                  fileRec['storageHost'] = conf["dbrcHost"]
                end
                respEntity = BRL::Genboree::REST::Data::FileEntity.deserialize(fileRec.to_json, :JSON)
                if(respEntity != :'Unsupported Media Type')
                  respEntity.setStatus(:OK, "UPDATED: Database #{@dbName.inspect}, file: #{@fileName.inspect} successfully updated.")
                  @statusName = configResponse(respEntity)
                end
              end
            end
          end
        rescue Exception => err
          $stderr.puts "FATAL ERROR: #{err}"
          $stderr.puts err.backtrace.join("\n")
          @statusName = :'Internal Server Error'
          @statusMsg = "FATAL ERROR: could not put your file on the server due to an internal processing error. The error was logged; please contact #{@genbConf.gbTechEmail} with this information."
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          # NOTE: we no longer support deleting folders using databaseFile - leads to bad results (deleting folder but not any file records of its children)
          fileRecs = @dbu.selectFileByDigest(@fileName, false)
          if(!fileRecs.nil? and !fileRecs.empty?)
            fileRec = fileRecs[0]
            filePath = fileRec['name']
            # We only allow users to delete individual files (not folders) in databaseFile.rb - you should head to databaseFiles.rb if you want to delete a folder
            if(filePath !~ /\/$/)
              # Create storage helper that will help us GET appropriate information associated with this file
              # We figure out which storage helper we want by consulting the fileRec's "remoteStorageConf_id" field.
              storageHelper = createStorageHelperFromRec(fileRec)
              begin
                parentDir = "#{File.dirname(@subDirs)}/"
                # Delete the file on disk
                storageHelper.deleteFile(filePath)
                # Delete the file record from the database
                recsDeleted = @dbu.deleteFileById(fileRec['id'])
                @dbu.deleteFile2AttributesByFileIdAndAttrNameId(fileRec['id'])
                # Insert the parent dir if it does not exist (default behavior)
                insertMissingParent = true
                if(@nvPairs.key?('insertMissingParent') and @nvPairs['insertMissingParent'] =~ /false/)
                  insertMissingParent = false
                end
                if(parentDir != './' and insertMissingParent) # Not the top level folder
                  parentDirRecord = @dbu.selectFileByName(parentDir)
                  if(parentDirRecord.empty?)
                    @dbu.insertFile(parentDir, parentDir, nil, 0, 0, Time.now(), Time.now(), @userId, storageHelper.storageID)
                    storageHelper.uploadFile("#{File.makeSafePath(parentDir)}/", "")
                  end
                end
                if(recsDeleted != 0)
                  fileRec['attributes'] = {}
                  fileRec['type'] = ""
                  fileRec['size'] = ""
                  fileRec['mimeType'] = ""
                  respEntity = BRL::Genboree::REST::Data::FileEntity.deserialize(fileRec.to_json, :JSON)
                  if(respEntity != :'Unsupported Media Type')
                    respEntity.setStatus(:OK, "DELETED: #{@fileName.inspect} for database #{@databaseName.inspect} in user group #{@groupName.inspect}.")
                    @statusName = configResponse(respEntity)
                  end
                else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
                  @statusName = :'Internal Server Error'
                  @statusMsg = "FATAL: Could not delete file: #{@fileName.inspect} for database #{@databaseName.inspect} in user group #{@groupName.inspect}."
                end
              ensure
                storageHelper.closeRemoteConnection()
              end
            else
              @statusName = :'Bad Request'
              @statusMsg = "BAD REQUEST: You cannot use this resource to DELETE a folder. You can only delete files using this resource. Please use databaseFiles (/files/...) in order to delete a folder (and all subfiles / subfolders)."
            end 
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          $stderr.puts "ERROR: #{File.basename(__FILE__)}##{__method__} => #{err}\n#{err.backtrace.join("\n")}"
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------
    # This helper method will return the attributes with display names via several techniques, depending on the file.
    # If the path indicates an LFF formatted file, it will return the LFF columns that exist in the header. If the
    # file's header indicates a resource type, this method will grab that resource's display names constant and
    # check the header for avps.  Barring either of these, this method will split the header and construct a proper
    # display names hash.
    # [+dbu+] Not used in this method
    # [+path+] A full path to the file on the disk
    # [+returns+] A hash mapping attribute names to display names
    def self.getAllAttributesWithDisplayNames(dbu=nil, path=nil)
      retVal = []
      allAttrs = []
      if(path)
        file = File.open(path, 'r')
        if(path.split(".").last == "lff")
          lffMap =  {
                      'class'=>'gclass',
                      'name'=>'gname',
                      'type'=>'fmethod',
                      'subtype'=>'fsource',
                      'Entry Point'=>'refname',
                      'start'=>'fstart',
                      'stop'=>'fstop',
                      'strand'=>'fstrand',
                      'phase'=>'fphase',
                      'score'=>'fscore',
                      'qStart'=>'ftarget_start',
                      'qStop'=>'ftarget_stop',
                      'attribute comments'=>'attribute Comments',
                      'sequence'=>'sequence',
                      'freestyle comments'=>'freestyle comments'
                    }
          lffHeader = lffMap.keys
        end
        file.each_line{|line|
          if(line.index("##") == 0)
            # Get the resource type, if available
            # Some of this string transformation code might need to change once the 'Apply Query' tool is in place
            rsrc = line.match(/##(\w+)/)[1]
            rsrc += "Builder"
            const = BRL::Genboree::REST::Data::Builders::const_get(rsrc.to_sym)
            displayNames = const::DISPLAY_NAMES
            displayNames.each{|item|
              retVal << item
              allAttrs << item.keys[0]
            }
          elsif(line.index("#") == 0)
            attrStr = line.slice(1, line.length)
            attrStr.gsub!("\n","")
            attrs = attrStr.split(/\t/)
            if(lffMap.nil?)
              attrs.each{|item|
                # Add each item from the header, so long as it was not retrieved previously
                if(!allAttrs.include?(item))
                  allAttrs << item
                  retVal << { item => item}
                end
              }
            else
              # Check lff core and optional fields, only return what is present.
              lffHeader.each{|field|
                if(attrs.include?(field))
                  retVal << { lffMap[field] => field}
                end
              }
            end
          else
            # Make sure to break after headers are read
            break
          end
        }
      else
        retVal = []
      end
      #retVal = displayNames
      return retVal
    end

    # Right now this helper method simply checks if there is a file extension of .lff;
    # if there is, the response format returned is "lff", else the response format is
    # tabbed.
    # [+path+] File path to check
    # [+returns+] Proper response format.
    def self.getRespFormat(path=nil)
      unless(path.nil?)
        if(path.split(".").last == "lff")
          return "lff"
        else
          return "tabbed"
        end
      else
        return ''
      end
    end

    # This method creates a storage helper from a storageID (positive integer given in the 'remoteStorageConf_id' column of the files table
    # Note that we have a fileRec available here (file already exists), so we just use that 
    # @param [Hash] fileRec File record containing different file attributes of current file 
    # @return [LocalStorageHelper or FtpStorageHelper] storage helper grabbed from storageID
    def createStorageHelperFromRec(fileRec)
      storageID = fileRec['remoteStorageConf_id']
      storageHelper = nil
      # If storageID is nil or 0, then that means that we're dealing with a local file.
      if(storageID == nil or storageID == 0)
        # We create a local storage helper object (no conf file necessary) and then set the "storageType" field in fileRec to be "local".
        storageHelper = BRL::Genboree::StorageHelpers::LocalStorageHelper.new(@groupName, @dbName, @userId)
        fileRec['storageType'] = "local"
        fileRec['storageHost'] = "local"
      # Otherwise, we're dealing with a remote file
      else
        # Grab conf file associated with current storage ID 
        conf = @dbu.selectRemoteStorageConfById(storageID)
        conf = JSON.parse(conf[0]["conf"])
        storageType = conf["storageType"]
        # If our storage type is FTP, then we will create an FTP Storage Helper
        if(storageType == "FTP")
          # Grab the Genboree FTP DBRC host / key from that storage conf.
          ftpDbrcHost = conf["dbrcHost"]
          ftpDbrcPrefix = conf["dbrcPrefix"]
          ftpBaseDir = conf["baseDir"]
          # Create the Genboree FTP storage helper using that information.
          # Here, since we're creating a Genboree-based FTP Storage Helper, we give @groupName and @dbName as parameters.
          # These are used to build the file base for the current user's files.
          storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, storageID, @groupName, @dbName)
          # Remember to set the "storageType" and "storageHost" fields in fileRec to let users know that this file is Genboree FTP-based
          fileRec['storageType'] = storageType
          fileRec['storageHost'] = ftpDbrcHost
        end
      end
      return storageHelper  
    end

    # This method creates a storage helper from a file's top-level file record.
    # This method is used when the current file does not have its own file record yet (PUT calls, for instance).
    # In this case, the top-level folder will either not exist (which means it's local) or it will exist (and can be local or remote).
    # A workbench tool will create this top-level folder when a user creates his/her remote area in his/her database.
    # This means that the to-level folder is a reliable way of checking whether the CURRENT file is going to be local or remote.
    # @param [String] fileName file name for current file
    # @return [LocalStorageHelper or FtpStorageHelper] storage helper based on top-level file record for current file
    def createStorageHelperFromTopRec(fileName)
      # isLocalFile will keep track of whether the file we're inserting is local or remote
      isLocalFile = false
      # Grab file record associated with top-level folder - all remote files will have a top-level folder with the appropriate remoteStorageConf_id 
      topFolderPath = "#{fileName.split("/")[0]}/"
      topFolderRecs = @dbu.selectFileByDigest(topFolderPath, true)
      topStorageID = nil
      # If this top folder doesn't exist yet, then we should be dealing with a local file (since all remote files are required to have their top-level directory created by the workbench)
      if(topFolderRecs.nil? or topFolderRecs.empty?)
        isLocalFile = true
      else
        # Grab remote storage ID associated with top-level folder
        topFolderRec = topFolderRecs[0]
        topStorageID = topFolderRec["remoteStorageConf_id"]
        # If top-level storage ID is 0 or nil, then we are dealing with a local file 
        if(topStorageID == nil or topStorageID == 0)
          isLocalFile = true 
        else
          # Grab conf file associated with current storage ID 
          conf = @dbu.selectRemoteStorageConfById(topStorageID)
          conf = JSON.parse(conf[0]["conf"])
          storageType = conf["storageType"]
          # If our storage type is FTP, then we will create an FTP Storage Helper
          if(storageType == "FTP")
            # Grab the Genboree FTP DBRC host / prefix from that storage conf.
            ftpDbrcHost = conf["dbrcHost"]
            ftpDbrcPrefix = conf["dbrcPrefix"]
            ftpBaseDir = conf["baseDir"]
            # Create the Genboree FTP storage helper using that information.
            # Here, since we're creating a Genboree-based FTP Storage Helper, we give @groupName and @dbName as parameters.
            # These are used to build the file base for the current user's files.
            storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, topStorageID, @groupName, @dbName)
          end
        end
      end
      # If we're working with a local file, we'll create a local Storage Helper
      if(isLocalFile)
        storageHelper = BRL::Genboree::StorageHelpers::LocalStorageHelper.new(@groupName, @dbName, @userId)
      end
      return storageHelper  
    end

  end # class DatabaseFile
end ; end ; end # module BRL ; module REST ; module Resources
