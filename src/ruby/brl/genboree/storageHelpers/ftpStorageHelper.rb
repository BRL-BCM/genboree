require 'brl/genboree/storageHelpers/abstractStorageHelper'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/pipeline/ftp/helpers/lftp'
require 'brl/util/expander'

module BRL ; module Genboree ; module StorageHelpers
  class FtpStorageHelper < AbstractStorageHelper

    # ftpHelper holds our FTP helper that allows us to do FTP-specific storage functions (get size, upload file, download file, etc.).
    attr_accessor :ftpHelper
    # groupName and dbName hold the user's group and database, respectively.
    # The FTP Genboree file structure mirrors our local file structure, so we need a groupName and dbName to construct any file base.
    # In the future, we might support other FTP servers, and they might not follow the same file structure - thus, groupName and dbName are optional.
    attr_accessor :groupName, :dbName
    # baseDir is supplied from an entry in a given database's remoteStorageConfs table. It helps us construct the proper file base.
    attr_accessor :baseDir
    # fileBase contains the full file base associated with any given file on remote storage.
    # Currently, we only support FTP Genboree files (hence the method buildFileBaseForGenboree), but other file bases may be added in the future.
    attr_accessor :fileBase
    # storageID holds the remote storage ID associated with our storage helper
    attr_accessor :storageID
    # updatedHost holds the host after it is transformed via domainAliases.json mapping (ftp.genboree.org -> phenylalanine.brl.bcmd.bcm.edu, for example)
    attr_accessor :updatedHost
    # Array which keeps track of which types of sniffing we allow (via sniffer or expander)
    SNIFFER_FORMATS = ["sniffer", "expander"]
    # muted keeps track of whether we want to mute debug statements or not (set to false by default) 
    attr_accessor :muted

    # Initialize ftpStorageHelper
    def initialize(dbrcHost, dbrcPrefix, baseDir, storageID, groupName=nil, dbName=nil, muted=false, userId=nil)
      super(dbrcHost, dbrcPrefix)
      # Set up @ftpHelper object
      @dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      dbrc = BRL::DB::DBRC.new(@dbrcFile)
      dbrcRec = dbrc.getRecordByHost(dbrcHost, dbrcPrefix)
      @muted = muted
      @ftpHelper = BRL::Genboree::Pipeline::FTP::Helpers::Lftp.new(dbrcRec[:host], dbrcRec[:user], dbrcRec[:password], dbrcPrefix, muted)
      @updatedHost = @ftpHelper.host
      # Set up other important variables
      @baseDir = baseDir
      @groupName = groupName
      @dbName = dbName
      # Only create @fileBase if we have groupName and dbName supplied above (for now, we only support FTP Genboree files)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Group name is #{groupName} and dbName is #{dbName}") unless(@muted)
      @fileBase = buildFileBaseForGenboree() if(groupName and dbName)
      @storageID = storageID
      @userId = userId
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully initialized FTP storage helper with dbrc host #{dbrcHost} and dbrc prefix #{dbrcPrefix}") unless(@muted)
    end

    # Method to check whether an FTP file exists
    # @param [String] filePath path to file on FTP
    # @return [Boolean] boolean that tells us whether FTP file exists (or nil if filePath is empty)
    def exists?(filePath, noOfAttempts=10)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking whether FTP file #{filePath} exists") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        retVal = @ftpHelper.exists?(filePath, noOfAttempts)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "FTP file #{filePath} exists: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to check modification time of FTP file
    # @param [String] filePath path to file on FTP
    # @return [Time] modification time of FTP file (or nil if file path is empty or there is an error getting mtime)
    def mtime(filePath, noOfAttempts=10)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking modification time of FTP file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        retVal = @ftpHelper.mtime(filePath, noOfAttempts)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Modification time of FTP file #{filePath}: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to grab file type of an FTP file
    # @param [String] filePath path to file
    # @param [String] snifferFormats parameter which indicates which sniffer formats we want to use (expander or sniffer)
    # @return [String] type of file as identified by expander or sniffer (or nil if file path is empty)
    def getFileType(filePath, snifferFormats="expander")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting file type (using the #{snifferFormats} formats) of FTP file #{filePath}") unless(@muted)
      # Must choose "expander" or "sniffer" for snifferFormats
      unless(SNIFFER_FORMATS.include?(snifferFormats))
        raise "You have entered an invalid value for the snifferFormats parameter. Please enter one of the values in this array: #{SNIFFER_FORMATS.inspect}"
      end
      originalFilePath = filePath
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      # We have to do this again because curl (@ftpHelper.type?) needs our input to be double-escaped
      filePath = File.makeSafePath(filePath)
      fileType = nil
      unless(filePath.empty?)
        # Grab file type using type? method in ftp helper (uses sniffer)
        begin
          fileType = @ftpHelper.type?(filePath)
        rescue => err
          unless(@muted)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", err.backtrace.join("\n"))
          end
        end
        # If we're following the expander convention for file types, then we might need to alter our fileType
        if(snifferFormats == "expander" and fileType != nil)
          # Grab expander's file extensions hash, then convert format grabbed by type? to expander's version of that format
          expanderFileExtensions = BRL::Util::Expander::FILE_EXTS
          fileType = expanderFileExtensions.index(fileType)
          fileType = "Zip" if(fileType == "zip")
          # If expander doesn't have the format (fastq, fasta, etc.), then fileType will be nil and the ternary operator below will set fileType to be "text"
          fileType = (BRL::Util::Expander::FILE_TYPES.include?(fileType) ? fileType : "text")
        elsif(fileType == nil)
          fileType = "Unknown" if(getFileSize(originalFilePath) == 0)
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type of FTP file #{filePath} (using #{snifferFormats} formats): #{fileType}") unless(@muted)
      return fileType
    end

    # Method to grab file size of an FTP file
    # @param [String] filePath path to file
    # @param [Fixnum] noOfAttempts Maximum number of attempts
    # @return [Fixnum] size of file (or nil if filePath is empty or error occurs with size)
    def getFileSize(filePath, noOfAttempts=10)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking file size of FTP file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        retVal = @ftpHelper.size(filePath, noOfAttempts)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of FTP file #{filePath}: #{retVal}") unless(@muted)
      return retVal
    end
    
    # Method to grab mime type of the file. This is useful for presenting files in a web browser
    # @param [String] filePath path to file
    # @param [Fixnum] noOfAttempts Maximum number of attempts
    # @return [String, NilClass] mime type of the file. Nil Otherwise
    def getMimeType(filePath, noOfAttempts=10)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking mime type of FTP file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      # We have to do this again because curl (@ftpHelper.type?) needs our input to be double-escaped
      filePath = File.makeSafePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        retVal = @ftpHelper.mimeType(filePath)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Mime Type of FTP file #{filePath}: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to write file (to ftp server)
    # @param [String] remoteFilePath remote file path (on FTP server) 
    # @param [StringIO / Tempfile / File] localFileStream local file stream that is being written to FTP server
    # @param [Array] fileUpdateArray Array that contains info about updating file
    # @param [Boolean] webServerRequest Boolean that keeps track of whether we're uploading our file from web server or not.
    #                                   If we are uploading via web server, then we will launch ftpFileProcessor cluster job to upload the current file.
    #                                   If we are NOT uploading via web server, then we will just upload the file directly via our Net::FTP helper.
    #                                   We don't want to do this on web server because it's blocking!
    # @return [nil]
    def uploadFile(remoteFilePath, localFileStream, fileUpdateArray=[], webServerRequest=false)
      begin
        unless(@muted)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading local file stream to FTP file path #{remoteFilePath}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local file stream is class #{localFileStream.class}")
          if(localFileStream.class == Tempfile)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local (temp) file is located at: #{localFileStream.path}")  
          elsif(localFileStream.class == File)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local file is located at: #{localFileStream.path}")
          end 
        end
        # Save original file path (in order to distinguish between folders and files - getFullFilePath cuts off ending '/')
        originalRemoteFilePath = remoteFilePath
        # Create full file path (with base directory / group / database)
        remoteFilePath = getFullFilePath(remoteFilePath)
        # Create file base directory
        @ftpHelper.mkdir(@fileBase)
        if(originalRemoteFilePath !~ /\/$/) # Not a folder
          # Unless webServerRequest is true, we'll upload the file directly using @ftpHelper
          unless(webServerRequest)
            retVal = @ftpHelper.uploadStreamToFtp(localFileStream, remoteFilePath)
          else
            `chmod 660 #{Shellwords.escape(localFileStream)}`
            submitFtpFileProcessJob(fileUpdateArray, localFileStream, originalRemoteFilePath)
          end
        else # Folder
          @ftpHelper.mkdir(remoteFilePath)
        end
        unless(webServerRequest)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File successfully uploaded to #{remoteFilePath}.") unless(@muted)
          # Post processing for file upload (update flags for upload-in-progress, compute SHA1 sum, etc.).
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Doing post-processing for #{remoteFilePath} (update flags for upload-in-progress, compute SHA1 sum, etc.)") unless(@muted)
          postProcessingForUploads(fileUpdateArray, localFileStream, retVal)
        end
      ensure
        # Regardless of whether our upload succeeds or fails, we want to make sure that we close / unlink our Tempfile 
        if(localFileStream.class == Tempfile and !webServerRequest)
          localPath = localFileStream.path
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Closing and unlinking local copy of file found at #{localPath}.") unless(@muted)
          localFileStream.close!()
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Was #{localFileStream.path} successfully closed / unlinked? #{!File.exist?(localPath)}") unless(@muted)
        end
      end
      return
    end

    # Method to download file (from ftp server)
    # @param [String] filePath file path being grabbed from FTP server
    # @param [String] localFilePath path of local file that is being written to locally
    # @return [nil]
    def downloadFile(filePath, localFilePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading FTP file path #{filePath} to local file path #{localFilePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)  
      if(filePath !~ /\/$/) # Not a folder
        @ftpHelper.downloadFromFtp(filePath, localFilePath)
      else
        raise "You can't download a folder - please target a file!"
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File successfully downloaded from FTP file path #{filePath} to local file path #{localFilePath}") unless(@muted)
      return
    end

    # Method to delete file (from FTP)
    # @param [String] filePath file path to local file
    # @return [Boolean] true if remove was successful, false if it wasn't (and nil if filePath is empty)
    def deleteFile(filePath, noOfAttempts=10)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting FTP file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        unless(@ftpHelper.directory?(filePath)) # Not a folder (file)
          retVal = @ftpHelper.rm(filePath, noOfAttempts)
        else # Folder - does recursive deletion of all subfiles / subfolders
          retVal = @ftpHelper.rmdir(filePath, noOfAttempts, true) 
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "FTP file #{filePath} successfully deleted: #{retVal}") unless(@muted)
      return retVal
    end

    # Method which will check the disk space used by the user's Genboree Database on the FTP server
    # @return [Fixnum] number of bytes being used by the user's Genboree Database on the FTP server 
    def checkDiskSpaceForDb()
      # Provide a clone because this method actually edits the first parameter (thus changing the instance variable @fileBase if not cloned)
      listOfFiles = @ftpHelper.longls(@fileBase.clone(), 10, 0, "infinity")
      totalDiskSpace = 0
      listOfFiles.each { |currentFile|
        totalDiskSpace += currentFile.split("\s")[4].to_i
      }  
      return totalDiskSpace
    end

    # Method which will check the disk space used by the user's Genboree Group
    # @return [Fixnum] number of bytes being used by the user's Genboree Group
    def checkDiskSpaceForGroup()
      # Provide a clone because this method actually edits the first parameter (thus changing the instance variable @fileBase if not cloned)
      listOfFiles = @ftpHelper.longls(File.dirname(File.dirname(@fileBase.clone())), 10, 0, "infinity")
      totalDiskSpace = 0
      listOfFiles.each { |currentFile|
        totalDiskSpace += currentFile.split("\s")[4].to_i
      }  
      return totalDiskSpace
    end

    # Method to open remote connection to FTP server
    # @return [nil]
    def openRemoteConnection()
      @dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      dbrc = BRL::DB::DBRC.new(@dbrcFile)
      dbrcRec = dbrc.getRecordByHost(dbrcHost, dbrcPrefix)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Opening remote connection to FTP server #{dbrcRec[:host]}") unless(@muted)
      @ftpHelper.ftpObj = @ftpHelper.connectToFtp(dbrcRec[:host], dbrcRec[:user], dbrcRec[:password])
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully opened remote connection to FTP server #{dbrcRec[:host]}") unless(@muted)
      return
    end

    # Method to close remote connection to FTP server
    # @return [nil]
    def closeRemoteConnection()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Closing remote connection to FTP server #{@ftpHelper.originalHost}") unless(@muted)
      @ftpHelper.ftpObj.close() rescue nil
      @ftpHelper.ftpObj = nil
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully closed remote connection to FTP server #{@ftpHelper.originalHost}") unless(@muted)
      return
    end

    ### HELPER METHODS ###

    # Method to grab full file path associated with a given file
    # @param [String] fileName name of file that we want to grab the full file path for
    # @return [String] full file path for file 
    def getFullFilePath(fileName)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting full file path for #{fileName}") unless(@muted)     
      retVal = ""
      unless(@fileBase)
        raise "Error: you cannot create a full file path without @fileBase being set!"
      end
      # Make path to file
      safeFileName = File.makeSafePath(fileName)
      if(safeFileName and !safeFileName.empty?)
        retVal = "#{@fileBase}/#{safeFileName}"
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Full file path for #{fileName} is: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to build file base for Genboree FTP files (group / refSeqID)
    # @return [String] file base (includes group / database)
    def buildFileBaseForGenboree()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Building Genboree file base for current user") unless(@muted)
      retVal = ""
      unless(@groupName and @dbName)
        raise "Error: you cannot create a file base for FTP Genboree files without @groupName and @dbName being set!"
      end
      # Get the base dir for the file
      groupRecs = @dbu.selectGroupByName(@groupName)
      groupId = groupRecs.first['groupId']
      refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, groupId)
      retVal = Abstraction::DatabaseFiles.buildFileBase(groupId, refseqRecs.first['refSeqId'], false, @genbConf, @baseDir)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Genboree file base for current user: #{retVal}") unless(@muted)
      return retVal
    end

    # Renames the file referred to in the fileRec object to have the new
    # file name provided. The file will not change directories, only its name
    # will change. This method also updates the 'fileName' value for the given record
    # if the operation succeeds.
    #
    # @param [Array] fileRec The file index record for the file to be renamed. The original
    #                        name will be retrieved from here and this object will be
    #                        updated with the new name (if successful)
    # @param [String] newFileName The new name for the file.
    # @return [Symbol] :OK, :ALREADY_EXISTS, or :FATAL if an error occurred. Not an HTTP response code though.
    def renameFile(fileRec, newFileName)
      retVal = nil
      origName = fileRec['fileName'] || fileRec['name']
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Renaming FTP file #{origName} to #{newFileName}") unless(@muted)
      origFullPath = origName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      origFullPath = "#{@fileBase}/#{origFullPath}"
      newFullPath = newFileName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      newFullPath = "#{@fileBase}/#{newFullPath}"
      begin
        fileExists = @ftpHelper.exists?(newFullPath)
        if(fileExists)
          retVal = :ALREADY_EXISTS
        else
          @ftpHelper.rename(origFullPath, newFullPath)
          fileRec['fileName'] = newFileName
          # If the label is the same as the file name, change the label too.
          fileRec['label'] = newFileName if(fileRec['label'] == origName)
          retVal = :OK
        end 
      rescue => err
        unless(@muted)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error with FtpStorageHelper's renameFile method. See error message and backtrace below:")  
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.backtrace.join("\n"))
        end
        retVal = :FATAL
      end
      return retVal
    end

    # Method which is used for post-processing steps after file is uploaded to FTP server - reset upload-in-progress flags and compute SHA1 sum
    # @param [Array] fileUpdateArray Array that contains info about updating file
    # @param [String] localInput local file input (could be StringIO object, could be Tempfile object, or could potentially be File object)
    # @param [Array] infoAboutUpload information about upload to FTP - includes whether job failed or succeeded as well as whether hexdigest for StringIO input
    # @return [nil]
    def postProcessingForUploads(fileUpdateArray, localInput, infoAboutUpload)
      # File is a database file. Expose it and compute sha1
      if(!fileUpdateArray.empty?)
        dbName = fileUpdateArray[0]
        fileId = fileUpdateArray[1]
        gbUploadId = fileUpdateArray[2]
        gbUploadFalseValueId = fileUpdateArray[3]
        gbPartialEntityId = fileUpdateArray[4]        
        gc = BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
        dbu.setNewDataDb(dbName)
        dbu.updateFile2AttributeForFileAndAttrName(fileId, gbUploadId, gbUploadFalseValueId)
        dbu.updateFile2AttributeForFileAndAttrName(fileId, gbPartialEntityId, gbUploadFalseValueId)
        # If localInput is StringIO, then SHA1 was computed earlier when uploading
        if(localInput.class == StringIO)
          sha1sum = infoAboutUpload[1]
        else
          # Otherwise, we need to compute the SHA1 now
          stdin, stdout, stderr = Open3.popen3("sha1sum #{Shellwords.escape(localInput.path)}") 
          sha1sum = stdout.readlines[0].split(' ')[0]
        end
        dbu.insertFileAttrValue(sha1sum)
        gbSha1AttrId = dbu.selectFileAttrNameByName('gbDataSha1').first['id']
        gbSha1ValueId = dbu.selectFileAttrValueByValue(sha1sum).first['id']
        dbu.insertFile2Attribute(fileId, gbSha1AttrId, gbSha1ValueId)
        dbu.clear()
      else # File is a project file or non database file   
        # This file does not require any 'exposing' nor does it require sha1
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Finished with post-processing") unless(@muted)
      return
    end

    # Submits a job to upload file to FTP server
    # Job also computes SHA1 of the file to store in database
    # @param [Array] fileUpdateArray contains information about file for post-processing
    # @param [String] localFilePath source path to file on local disk
    # @param [String] remoteFilePath destination path to file on FTP server
    # @return [nil]
    def submitFtpFileProcessJob(fileUpdateArray, localFilePath, remoteFilePath)
      gc = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
      userRec = dbu.selectUserById(@userId).first
      unless(userRec)
        raise "Error: no user record exists for user ID #{@userId} - are you trying to upload a file as gbSuperUser? This is not allowed!"
      end
      settings = {}
      if(!fileUpdateArray.empty?)
        settings = {
          'dbName' => fileUpdateArray[0],
          'fileId' => fileUpdateArray[1],
          'gbUploadId' => fileUpdateArray[2],
          'gbUploadFalseValueId' => fileUpdateArray[3],
          'gbPartialEntityId' => fileUpdateArray[4],
          'source' => localFilePath,
          'remoteFilePath' => remoteFilePath,
          'groupName' => @groupName,
          'refseqName' => @dbName
        }
      else
        settings = {
          'source' => localFilePath,
          'fullFilePath' => remoteFilePath
        }
      end
      settings['gbPrequeueHost'] = @genbConf.internalHostnameForCluster
      payload = {
        'inputs' => [],
        'outputs' => [],
        'context' => {
          'toolIdStr' => 'ftpFileProcessor',
          'queue' => 'gb',
          'userId' => @userId,
          'toolTitle' => 'Process Ftp File',
          'userLogin' => userRec['name'],
          'userLastName' => userRec['lastName'],
          'userFirstName' => userRec['firstName'],
          'userEmail' => userRec['email'],
          'gbAdminEmail' => gc.gbAdminEmail
        },
        'settings' => settings
      }
      apiCaller = WrapperApiCaller.new(@genbConf.machineName, '/REST/v1/genboree/tool/ftpFileProcessor/job?', @userId)
      # Need to make sure rackEnv is set since we are going to make internal API call to submit ftpFileProcessor job
      rackEnv = fileUpdateArray[5] rescue nil
      apiCaller.initInternalRequest(rackEnv, @genbConf.machineNameAlias) if(rackEnv)
      apiCaller.put(payload.to_json)
      unless(apiCaller.succeeded?)
        raise apiCaller.respBody
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "API response body: #{apiCaller.respBody()}") unless(@muted)
        ftpFileProcessorJobId = JSON.parse(apiCaller.respBody)['data']['text']
        @relatedJobIds = [] unless(@relatedJobIds)
        @relatedJobIds << ftpFileProcessorJobId
      end
      return
    end
    
  end # class FtpStorageHelper < AbstractStorageHelper
end ; end ; end #module BRL ; module Genboree ; module StorageHelpers
