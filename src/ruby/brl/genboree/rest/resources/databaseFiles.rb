#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/databaseFileEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/rest/data/fileEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  class DatabaseFiles < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :delete => true }
    RSRC_TYPE = 'files'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/files(/[^\?]+)?}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @dbFilesObj = nil
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @subDirs = Rack::Utils.unescape(@uriMatchData[3])[1..-1] if(!@uriMatchData[3].nil?) # remove the leading '/'
        detailed = @nvPairs['detailed']
        @detailed = if(detailed and !detailed.empty? and detailed =~ /false|no/i) then false else true end
        @depth = @nvPairs['depth']
        @depth = 'full' unless(@depth)
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      # Initial operation (grab group name / db name / subdirs, set up depth and detailed parameters, etc.)
      initStatus = initOperation()
      begin
        # If initialization went OK, then we proceed
        if(initStatus == :OK)
          begin
            # Need storage helper to check whether @subDirs actually exists on disk (or FTP, etc.) 
            storageHelper = nil
            # Unless @subDirs is nil (we want to grab ALL files), then we need to create a storage helper
            unless(@subDirs.nil?)
              storageHelper = createStorageHelperFromTopRec(@subDirs)
            end
            # allFiles will hold all of the files we want to grab
            allFiles = nil
            # If @subDirs is nil and @depth is full, then that means we want to grab ALL of the files
            if(@subDirs.nil? and @depth == 'full')
              allFiles = @dbu.selectAllFiles()
            # Otherwise, we grab certain files / folders according to @subDirs and @depth (@detailed changes what we get as a response - all fields or only names)
            else
              allFiles = @dbu.selectChildrenFilesAndFolders(@subDirs, @depth, @detailed)
            end
            # entityList will hold all of the file-related entities. These entities will be FileEntities if @detailed is true and TextEntities if @detailed is false
            entityList = @detailed == true ? BRL::Genboree::REST::Data::FileEntityList.new() : BRL::Genboree::REST::Data::TextEntityList.new()
            # If allFiles is nil or empty, then we didn't grab any subfolders / files above
            if(allFiles.nil? or allFiles.empty?)
              # notFound will keep track of whether @subDirs exists or not (on disk / FTP, NOT in files table)
              notFound = false
              # If @subDirs is nil, that just means that allFiles was empty because the entire database was empty of files - we will not raise an error in that case 
              unless(@subDirs.nil?)
                # Check to see whether @subDirs exists on local / remote
                unless(storageHelper.exists?(@subDirs))
                  notFound = true
                end
              end
              # If we could not find our folder, then we raise an error
              if(notFound)
                @statusName = :'Not Found'
                @statusMsg = "NOT FOUND: The folder #{@subDirs.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
              else # Otherwise, @subDirs is an empty folder, so we can just return an empty TextEntityList
                entityList = BRL::Genboree::REST::Data::TextEntityList.new()
                @statusName = configResponse(entityList)
              end
            # Otherwise, allFiles is not nil or empty
            else
              # fileAttrHash (three-dimensional) will keep track of the different attribute value pairs associated with the files we grabbed above
              fileAttrHash = Hash.new { |hh,kk|
                hh[kk] = {}
              }
              # If @detailed is true, we already have the attribute value pairs present in the file records
              # If @detailed is false, then we need to grab the attribute value pairs and save those guys
              unless(@detailed)
                attrValuePairs = @dbu.selectAllAttrValuePairsForAllFiles()
                # We will save fileName (name of the file, unique) and name (attribute name) as keys and value (value of the attribute) as value
                # fileName is the name of the file (unique), name is the name of the attribute, and value is the value of the attribute 
                attrValuePairs.each { |fileAVP|
                  fileAttrHash[fileAVP['fileName']][fileAVP['name']] = fileAVP['value']
                }
              end
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "allFiles=#{allFiles.inspect}")
              # Sort allFiles alphabetically by file name
              allFiles.sort! {|aa,bb| aa['name'].downcase <=> bb['name'].downcase }
              # Traverse all file records
              # @todo Replace the current approach with a streamed response. That way we can compute the size/type for each file without blocking the server instance.
              allFiles.each { |file|
                # attributes hash will save attribute value pairs for current file
                attributes = {}
                # If @detailed is true, then we want to grab attribute name / value pairs 
                if(@detailed)
                  attributeRecs = @dbu.selectFileAttrNamesAndValuesByFileId(file['id'])
                  if(!attributeRecs.nil? and !attributeRecs.empty?)
                    attributeRecs.each { |rec|
                      attributes[rec['name']] = rec['value']
                    }
                  end
                  # Set "storageType" and "storageHost" for response
                  storageID = file['remoteStorageConf_id']
                  if(storageID == nil or storageID == 0)
                    file['storageType'] = "local"
                    file['storageHost'] = "local"
                  else
                    conf = @dbu.selectRemoteStorageConfById(storageID)
                    conf = JSON.parse(conf[0]["conf"])
                    file['storageType'] = conf["storageType"]
                    file['storageHost'] = conf["dbrcHost"]
                  end
                  # Replace userId with user login - gbSuperuserId doesn't have a user login, so we set it to empty string in that case
                  modifiedBy = file['modifiedBy']
                  if(modifiedBy.to_i == @genbConf.gbSuperuserId.to_i)
                    file['modifiedBy'] = ""
                  else
                    userRecs = @dbu.getUserByUserId(modifiedBy)
                    file['modifiedBy'] = userRecs.first['name']
                  end
                  # Create fileEntity with current file's info
                  fileEntity = BRL::Genboree::REST::Data::FileEntity.new(@connect, file['label'], file['autoArchive'], file['createdDate'], file['lastModified'], file['description'], file['name'], file['hide'], file['modifiedBy'], "[Not available]", "[Not available]", file['storageType'], file['storageHost'], "[Not available]", attributes)
                  if(@connect)
                    refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/file")
                    fileEntity.setRefs({})
                    fileName = fileEntity.name
                    encFileName = fileName.split('/').map { |xx| CGI.escape(xx) }.join('/')
                    fileEntity.makeRefsHash("#{refBase}/#{encFileName}")
                  end
                  # Only add in response if 'gbUploadInProgress' is not true
                  gbUploadInProgress = attributes['gbUploadInProgress']
                  entityList << fileEntity if(!gbUploadInProgress or gbUploadInProgress == '0')
                else
                  # If @detailed is not true, then we just need to grab file name, create textEntity with that name, and then add to response
                  fileName = file['name']
                  textEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, fileName)
                  if(@connect)
                    refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/file")
                    encFileName = fileName.split('/').map { |xx| CGI.escape(xx) }.join('/')
                    textEntity.makeRefsHash("#{refBase}/#{encFileName}")
                  end
                  # Only add in response if 'gbUploadInProgress' is not true - this is where we use fileAttrHash
                  gbUploadInProgress = fileAttrHash[file['name']]['gbUploadInProgress']
                  entityList << textEntity if(!gbUploadInProgress or gbUploadInProgress == '0')
                end
              }
              # If fileList is given as a parameter for the API GET call, then we only return files that fall within that list 
              unless(@nvPairs['fileList'].nil?)
                fileList = @nvPairs['fileList'].split(",")
                fileList = fileList.to_set.to_a
                fileList.sort!
                tmpEntityList = []
                entityList.each{|fileEntity|
                  if(fileList.include?(fileEntity.name))
                    tmpEntityList.push(fileEntity)
                  end
                }
                entityList = BRL::Genboree::REST::Data::FileEntityList.new(@connect, tmpEntityList)
              end
              # Set status after gathering file information
              @statusName = configResponse(entityList)
            end 
          ensure
            storageHelper.closeRemoteConnection() if(storageHelper)
          end
        else
          # If initialization fails, then we set @statusName to be that failed status message
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get records for files. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Deletes folders (removes all entries of files for a folder from the db and removes folder from disk)
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          # Get the parent dir of the folder being deleted. We will need to do an insert of the parent folder if it's not already there
          parentDir = nil
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@subDirs=#{@subDirs}")
          if(@subDirs)
            parentDir = "#{File.dirname(@subDirs)}/"
          end
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "parentDir=#{parentDir}")
          fileRecs = @dbu.selectChildrenFilesAndFolders(@subDirs, 'full', true)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "fileRecs=#{fileRecs.inspect}")
          # Also add the folder itself
          folderRecs = @dbu.selectFileByName("#{@subDirs}/")
          if(fileRecs.empty?)
            fileRecs = folderRecs
          else
            fileRecs << folderRecs.first if(!folderRecs.empty?)
          end
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "fileRecs (after adding folder)=#{fileRecs.inspect}")
          if(!fileRecs.nil? and !fileRecs.empty?)
            fileRec = fileRecs[0]
            # Create storage helper that will help us GET appropriate information associated with this file
            # We figure out which storage helper we want by consulting the fileRec's "remoteStorageConf_id" field.
            storageHelper = createStorageHelperFromRec(fileRec)
            begin
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Current file being deleted: #{@uriMatchData[3]}")
              deletionSuccessful = storageHelper.deleteFile(CGI.unescape(@uriMatchData[3]))
              if(deletionSuccessful.nil? or deletionSuccessful == false)
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL: Could not delete file #{@uriMatchData[3]} while deleting #{@subDirs.inspect} for database #{@databaseName.inspect} in user group #{@groupName.inspect}."                
              else
                # Delete the file records from the database
                fileList = []
                fileRecs.each { |fileObj|
                  fileList << fileObj['name']
                }
                recsDeleted = @dbu.deleteFilesByName(fileList)
                if(parentDir and parentDir != './')
                  parentDirRecord = @dbu.selectFileByName(parentDir)
                  if(parentDirRecord.empty?)
                    @dbu.insertFile(parentDir, parentDir, nil, 0, 0, Time.now(), Time.now(), @userId, fileRec['remoteStorageConf_id'])
                    storageHelper.uploadFile("#{File.makeSafePath(parentDir)}/", "")
                  end
                end
                if(recsDeleted != 0)
                  # Hack-in some of the attributes
                  fileRec['attributes'] = {}
                  fileRec['type'] = 'text'
                  fileRec['size'] = 0
                  fileRec['mimeType'] = ""
                  respEntity = BRL::Genboree::REST::Data::FileEntity.deserialize(fileRec.to_json, :JSON)
                  if(respEntity != :'Unsupported Media Type')
                    respEntity.setStatus(:OK, "DELETED: #{@subDirs.inspect} for database #{@databaseName.inspect} in user group #{@groupName.inspect}.")
                    @statusName = configResponse(respEntity)
                  end
                else
                  @statusName = :'Internal Server Error'
                  @statusMsg = "FATAL: Could not delete folder: #{@subDirs.inspect} for database #{@databaseName.inspect} in user group #{@groupName.inspect}."
                end
              end
            ensure
              storageHelper.closeRemoteConnection()
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The folder #{@subDirs.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
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

  end # class DatabaseFiles
end ; end ; end # module BRL ; module REST ; module Resources#!/usr/bin/env ruby
