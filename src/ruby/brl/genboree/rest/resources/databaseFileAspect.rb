#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/util/checkSumUtil'
require 'brl/util/expander'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/em/deferrableBodies/deferrableFileReaderBody'
require 'brl/genboree/rest/em/deferrableBodies/deferrableFtpFileReaderBody'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/numericEntity'
require 'brl/genboree/rest/data/databaseFileEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/abstract/resources/ucscBigFile'
require 'brl/genboree/storageHelpers/localStorageHelper'
require 'brl/genboree/storageHelpers/ftpStorageHelper'
 
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # DatabaseFileAspect - exposes information about the custom links of a specific database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DatabaseFileEntity
  class DatabaseFileAspect < BRL::REST::Resources::GenboreeResource
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    READ_BUFFER_SIZE = 4 * 1024 * 1024
    RSRC_TYPE = 'databaseFileAspect'
    # Ceiling for number of bytes to grab for user
    MAX_BYTES_CEILING = 5000000
    # Default for number of bytes to grab for user (if no number is specified)
    TOTAL_DEFAULT_BYTES = 1000000 
    # Maximum size for moving files in-place (versus running localFileProcessor job)
    MAX_LOCAL_SIZE = 8000000
    SUPPORTED_DEPENDENT_TOOLS = {
      'kbBulkUpload' => { 'kbBulkUploadKbName' => nil, "kbBulkUploadCollName" => nil, "kbBulkUploadFileFormat" => nil}
    }
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @topLevelProjs.clear() if(@topLevelProjs)
      @databaseObj = @topLevelProjs = @projBaseDir  = @escProjName = @projDir = @projName = @aspect = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/file/([^\?]+)/(data|size|format|sniffedType|adler32|type|compressionType|label|date|archived|autoArchive|hide|description|fileName|name|mimeType|storageType|storageHost)(?:\?.*)?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving databases etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])
        @fileProperty = Rack::Utils.unescape(@uriMatchData[4])
        @fileProperty = @fileProperty.strip.downcase if(@fileProperty)
        forceDynamicIndexing = @nvPairs['forceDynamicIndexing']
        @downloadAsFile = (@nvPairs['downloadAsFile'] =~ /\S/) ? @nvPairs['downloadAsFile'].to_s.strip.downcase() : nil
        @forceDynamicIndexing = if(forceDynamicIndexing and !forceDynamicIndexing.empty? and forceDynamicIndexing =~ /^(?:true|yes)/i) then true else false end
        # Used to extract files after upload. Currently only available for local files
        extract = @nvPairs['extract']
        @extract = if(extract and !extract.empty? and extract =~ /^(?:true|yes)/i) then true else false end
        # Used to suppress emails. Currently only available for local files (and used for processFile email related to extraction of file).
        suppressEmail = @nvPairs['suppressEmail']
        @suppressEmail = if(suppressEmail and !suppressEmail.empty? and suppressEmail =~ /^(?:true|yes)/i) then true else false end
        @maxBytes = @nvPairs['maxBytes'].to_i if @nvPairs['maxBytes']
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
        @dbFilesObj = nil
        @dbFileHash = nil
        # Check that @fileName does not have '^../' or '/../'. That will be a bad request
        # If @fileName has '^./' or '/./', replace it with '' and '/' respectively
        if(@fileName =~ /^\.\.\// or @fileName =~ /\/\.\.\//)
          @statusName, @statusMsg = :"Bad Request", "file names cannot have '../' or '/../'."
          initStatus = :'Bad Request'
        end
        # If @fileName begins with a './ or has a '/./' in the middle replace them appropriately
        @fileName.gsub!(/^\.\//, '')
        @fileName.gsub!(/\/\.\//, '/')
        @relatedJobIds = []
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
        @dbFilesObj = BRL::Genboree::Abstract::Resources::DatabaseFiles.new(@groupName, @dbName, @genbConf)
      end
      @dbFileHash = @dbFilesObj.findFileRecByFileName(@fileName)
    end

    def releaseDbFilesInfo()
      @dbFileHash = nil
    end

    def head()
      begin
        # get the response from get(), performing its same validations
        @resp = get()
        begin
          # Open the remote connection again for the storageHelper
          @storageHelperForHEAD.openRemoteConnection()
          if((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
            # then we need to remove the body from the response according to the http
            # requirements of the HEAD request, headers should be identical between
            # get and head
            @resp.body = []
            @resp['Accept-Ranges'] = 'bytes'
            # Note that @storageHelperForHEAD has been set by the GET call
            fullFilePath = @storageHelperForHEAD.getFullFilePath(@fileName)
            if(!fullFilePath.empty? and @storageHelperForHEAD.exists?(@fileName))
              @resp['Content-Length'] = @storageHelperForHEAD.getFileSize(@fileName).to_s
            else
              msg = "File exists as of the preparation of this response but cannot be found later"
              raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", msg)
            end
          end
        ensure
          @storageHelperForHEAD.closeRemoteConnection()
        end
      rescue Exception => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      # Set @storageHelperForHEAD to nil once we're done with it
      @storageHelperForHEAD = nil
      return @resp
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          # Grab the file record associated with our current file name (for figuring out correct storage helper)
          fileRecs = @dbu.selectFileByDigest(@fileName)
          # If file record doesn't exist, then we can't proceed
          if(fileRecs and !fileRecs.empty?)
            # Grab the specific file record from the fileRecs array (which is always just one record anyway)
            fileRec = fileRecs[0]
            # Create storage helper that will help us GET appropriate information associated with this file
            # We figure out which storage helper we want by consulting the fileRec's "remoteStorageConf_id" field.
            storageHelper = createStorageHelperFromRec(fileRec)
            # Save storageHelper in a temporary instance variable called @storageHelperForHEAD - we use this for any HEAD call (which necessarily calls GET first)
            # We set this to nil at the end of our HEAD call
            @storageHelperForHEAD = storageHelper
            begin
              # Grab full file path - if it's empty or the file doesn't exist, then we can't proceed
              fullFilePath = storageHelper.getFullFilePath(@fileName)
              # Let's check to see if the file even exists (locally or remotely)
              if(!fullFilePath.empty? and storageHelper.exists?(@fileName))
                # If @fileProperty is "data", then we want to download the data associated with a given file
                if(@fileProperty == 'data')
                  # Check to see if file is still being uploaded - we don't want to download a file that hasn't finished uploading
                  fileId = fileRecs.first['id']
                  gbUploadRecs = @dbu.selectFileAttrValueByFileAndAttributeNameText(fileId, 'gbUploadInProgress')
                  uploadInProgress = false
                  if(!gbUploadRecs.nil? and !gbUploadRecs.empty?)
                    uploadInProgress = true if(gbUploadRecs.first['value'] == "1")
                  end
                  unless(uploadInProgress)
                    @resp.status = HTTP_STATUS_NAMES[:OK]
                    @resp['Content-Type'] = 'application/octet-stream'
                    @resp['Content-Disposition'] =  "attachment; filename=\"#{File.basename(@fileName)}\"" if(@downloadAsFile)
                    @resp['Last-Modified'] = storageHelper.mtime(@fileName).rfc822
                    # If we are given an HTTP_RANGE, then we need to process that accordingly.
                    if(@req.env['HTTP_RANGE'])
                      unless(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        @statusName, @statusMsg = :"Bad Request", "Your file is not locally based on Genboree so you cannot process an HTTP range request."
                      else
                        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Saw HTTP_RANGE (#{@req.env['HTTP_RANGE'].inspect})")
                        # support range requests
                        @resp.status = HTTP_STATUS_NAMES[:'Partial Content']
                        rangeData = BRL::Genboree::Abstract::Resources::UCSCBigFile.parseRange(@req.env['HTTP_RANGE'], fullFilePath)
                        length, offset = rangeData[:length], rangeData[:offset]
                        # @todo can we provide this RFC-breaking header only to UCSC and not to others?
                        # UCSC seems to be expecting their Range header echoed back at them via
                        # Content-Range. But they break RFC
                        # by expecting "0-" which is valid for Requests but not for Responses
                        # (last-byte-pos is not optional in Response only Request)
                        # - extract actual range (separate from units)
                        @req.env['HTTP_RANGE'] =~ /^(?:[^=]+)=\s*(.+)$/
                        ucscRangeValue = "bytes #{$1}"
                        @resp['Content-Range'] = "#{ucscRangeValue}"
                        #@resp['Content-Range'] = rangeData[:rangeHeader] # @todo uncomment this
                        $stderr.debugPuts(__FILE__, __method__, "UCSC STATUS", "UCSC wants file data in a given byte range. The byte range they request is '#{@req.env["HTTP_RANGE"]}' (which is a lie)\nUCSC DEBUG: Sending back 'Content-Range: #{ucscRangeValue}' (also a lie, and probably not to RFC)")
                        # If the requested format is preHtml, then we're going to use our prepResp method to grab the text
                        if(@nvPairs['format'] == 'preHtml')
                          prepResp(fullFilePath, length, offset)
                        else
                          deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableUCSCBigFileBody.new(
                            :path   => "#{path}/#{@bwFileName}",
                            :length => length,
                            :offset => offset,
                            :yield  => true
                          )
                          @resp.body = deferrableBody
                        end
                      end
                    # If we are not given an HTTP_RANGE but we are given either a preHtml request or some range of bytes to grab, then we will use the prepResp method to grab the text
                    elsif((@nvPairs['format'] == 'preHtml') or @maxBytes)
                      unless(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        @statusName, @statusMsg = :"Bad Request", "Your file is not locally based on Genboree so you cannot perform this request."
                      else
                        # If the user didn't specify a length, then we set it to a default length of TOTAL_DEFAULT_BYTES
                        length = (@maxBytes or TOTAL_DEFAULT_BYTES)
                        prepResp(fullFilePath, length)
                      end
                    # If we are given the format of "imgHtml", then we know that we are returning an image (in HTML markup) for the user
                    elsif(@nvPairs['format'] == 'imgHtml')
                      unless(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        @statusName, @statusMsg = :"Bad Request", "Your file is not locally based on Genboree so you cannot perform this request."
                      else
                        # First, we unescape the URI template given to us as an argument
                        uriTempValue = CGI.unescape(@nvPairs['uriTemplate'])
                        # Then, we replace the {URI} portion of that template with the escaped path to our image's data
                        escapedImgURI = CGI.escape(@uriMatchData[0])
                        uriTempValue.gsub!("{URI}", escapedImgURI)
                        # Finally, we set @resp.body to its value (within an img src tag)
                        @resp.body = "<img src=\"#{uriTempValue}\">"
                      end
                    else
                      if(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableFileReaderBody.new(:path => fullFilePath, :yield => true)
                        @resp.body = deferrableBody
                      elsif(storageHelper.class == BRL::Genboree::StorageHelpers::FtpStorageHelper)
                        deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableFtpFileReaderBody.new(:path => @fileName, :ftpStorageHelper => createStorageHelperFromRec(fileRec, true), :yield => true)
                        @resp.body = deferrableBody
                      end
                    end
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "final Content-Length: #{@resp['Content-Length'].inspect}")
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "resp.body is a: #{@resp.body.class.inspect}")
                  else
                    @statusName, @statusMsg = :"Bad Request", "The data for the file: #{@fileName} is still being uploaded. You cannot access the data for this file until it has finished uploading."
                  end
                elsif(@fileProperty == 'size')
                  fileSize = storageHelper.getFileSize(@fileName)
                  respEntity = BRL::Genboree::REST::Data::NumericEntity.new(@connect, fileSize)
                elsif(@fileProperty == 'adler32')
                  if(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                    fileAdler32 = File.adler32(fullFilePath)
                    respEntity = BRL::Genboree::REST::Data::NumericEntity.new(@connect, fileAdler32)
                  else
                    @statusName, @statusMsg = :"Bad Request", "You cannot request the Adler-32 checksum for a non-local file"
                  end
                elsif(@fileProperty == 'type' or @fileProperty == 'compressiontype')
                  fileType = storageHelper.getFileType(@fileName)
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, fileType)
                elsif(@fileProperty == 'format' or @fileProperty == 'sniffedtype')
                  fileType = storageHelper.getFileType(@fileName, "sniffer")
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, fileType)
                elsif(@fileProperty == 'storagetype')
                  storageType = fileRecs[0]['storageType']
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, storageType)
                elsif(@fileProperty == 'storagehost')
                  storageHost = fileRecs[0]['storageHost']
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, storageHost)
                elsif(BRL::Genboree::Abstract::Resources::FileManagement::EDITABLE_INDEX_FIELDS.include?(@fileProperty) and @fileProperty != 'archived')
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, fileRecs[0][@fileProperty])
                elsif(@fileProperty == 'mimetype')
                  mimeType = storageHelper.getMimeType(@fileName)
                  mimeType = ( mimeType.nil? ? "application/octet-stream" : mimeType )
                  respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, mimeType)
                else
                  @statusName, @statusMsg = :"Bad Request", "The aspect #{@fileProperty.inspect} is not a valid aspect."
                end
              else
                @statusName = :'Not Found'
                @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect} - file path is either empty or points to file that doesn't exist."
                #$stderr.debugPuts(__FILE__, __method__, "STATUS", "ERROR: File Not Found for url #{@reqURI.inspect}, with file name #{@fileName.inspect} and full path #{fullFilePath.inspect}" )
              end
            ensure
              storageHelper.closeRemoteConnection()
            end
          else # couldn't find file
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect} - file record doesn't exist."
          end
          if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
            #$stderr.debugPuts(__FILE__, __method__, "STATUS", "calling configResponse()...")
            @statusName = configResponse(respEntity)
            #$stderr.debugPuts(__FILE__, __method__, "STATUS", "done with configResponse() with return of #{@statusName.inspect}")
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
        ensure
          releaseDbFilesInfo()
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "done get() ; @statusName = #{@statusName.inspect}")
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          # Check if the file exists
          fileRecs = @dbu.selectFileByDigest(@fileName)
          # If the file does not exist, return Not Found, except for the 'data' aspect as it is used to create files.
          if((fileRecs.nil? or fileRecs.empty?) and @fileProperty != 'data')
            @statusName, @statusMsg = :"Not Found", "The file #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          else
            # First, we will figure out which type of storageHelper we need to create
            storageHelper = nil
            storageID = nil
            # If file exists already, then we just need to check the fileRec for its remoteStorageConf_id
            unless(fileRecs.nil? or fileRecs.empty?)
              fileRec = fileRecs[0]
              storageHelper = createStorageHelperFromRec(fileRec)
            else
              # Otherwise, the file does not exist yet (must be doing a PUT to 'data' aspect), so we need to check the top-level folder's remoteStorageConf_id
              storageHelper = createStorageHelperFromTopRec(@fileName)
            end
            begin
              # Used in some older methods below
              groupRecs = @dbu.selectGroupByName(@groupName)
              groupId = groupRecs.first['groupId']
              refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, groupId)
              if(@fileProperty == 'data')
                if(initStatus == :OK) # If file is large, their upload is accepted pretty quickly but data may not appear right away
                  # @xBodyFile should be set with path to our file. If it's not set, then something went wrong.
                  unless(@xBodyFile)
                    @statusName, @statusMsg = :"Not Found", "Something went wrong, as the HTTP-X-BODY-FILE nginx variable wasn't correctly set for #{@fileName} in database #{@dbName.inspect} and group #{@groupName.inspect}."
                  else
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>>>>>>>> File size of source file #{@xBodyFile.inspect} : #{File.size(@xBodyFile)}")
                    #sleep(2)
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>>>>>>>>> File size of source file after sleep of 2 seconds: #{File.size(@xBodyFile)}")
                    fileType = @nvPairs['fileType']
                    # For special files (like .bb, .bw or .bin the files will just be placed in the correct location. No db record will be inserted)
                    if(fileType and (fileType == 'bigFile' or fileType == 'bin'))
                      unless(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        @statusName, @statusMsg = :"Bad Request", "You can only upload special files of type #{fileType} to local Genboree (not remote services like FTP)."
                        status = :'Bad Request'
                      else
                        status = :OK
                        if(fileType == 'bigFile' and !@nvPairs.key?('trackName'))
                          @statusName, @statusMsg = :"Bad Request", "You need to supply a trackName parameter when uploading bigFiles."
                          status = :'Bad Request'
                        else
                          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Writing a special file with #{@xBodyFile}")   
                          status = writeSpecialFiles(fileType, @xBodyFile, refseqRecs, groupId) # If something goes wrong in this function, @statusName, @statusMsg will be set
                        end
                        if(status == :OK)
                          respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, :Accepted, msg="ACCEPTED: Upload of #{fileType} file to Database #{@dbName.inspect}, file: #{@fileName.inspect}, accepted. Final storage of file may be ongoing.")
                          @statusName = configResponse(respEntity, :Accepted)
                          @statusMsg = respEntity.msg
                        end
                      end
                    else # Regular file upload
                      # New file
                      if(fileRecs.nil? or fileRecs.empty?)
                        rowInserted = @dbu.insertFile(@fileName, @fileName, nil, 0, 0, Time.now(), Time.now(), @userId, storageHelper.storageID)
                        if(rowInserted != 1)
                          @statusMsg = "FATAL: Could not insert record in 'files' table for file: #{@fileName.inspect}. "
                          raise @statusMsg
                        end
                      else # A file with the same name already exists. Just do an update
                        fileRec = fileRecs[0]
                        updateRec = @dbu.updateFileByName(@fileName, fileRec['label'], fileRec['description'], fileRec['autoArchive'], fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
                        if(updateRec == 0)
                          @statusMsg = "FATAL: Could not replace contents of file: #{@fileName.inspect} in Database #{@dbName.inspect} in 'files' table. "
                          raise @statusMsg
                        end
                      end
                      # Mark the file as being uploaded. Once uploaded, it will be reset
                      # Also mark the file as a partial entity
                      @dbu.insertFileAttrName('gbUploadInProgress')
                      @dbu.insertFileAttrName('gbPartialEntity')
                      @dbu.insertFileAttrName('gbDataSha1')
                      gbUploadId = @dbu.selectFileAttrNameByName('gbUploadInProgress').first['id']
                      gbPartialEntityId = @dbu.selectFileAttrNameByName('gbPartialEntity').first['id']
                      @dbu.insertFileAttrValue(true)
                      gbUploadTrueValId = @dbu.selectFileAttrValueByValue(true).first['id']
                      fileId = @dbu.selectFileByDigest(@fileName).first['id']
                      @dbu.insertFile2Attribute(fileId, gbUploadId, gbUploadTrueValId)
                      @dbu.insertFile2Attribute(fileId, gbPartialEntityId, gbUploadTrueValId)
                      @dbu.insertFileAttrValue(false)
                      gbUploadFalseValId = @dbu.selectFileAttrValueByValue(false).first['id']
                      if(storageHelper.class == BRL::Genboree::StorageHelpers::LocalStorageHelper)
                        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading #{@xBodyFile} locally (to #{@fileName} with database #{@dbName.inspect} and group #{@groupName.inspect})")   
                        storageHelper.uploadFile(@fileName, @xBodyFile, true, @extract, false, [refseqRecs.first['databaseName'], fileId, gbUploadId, gbUploadFalseValId, gbPartialEntityId, @rackEnv], @suppressEmail)
                      elsif(storageHelper.class == BRL::Genboree::StorageHelpers::FtpStorageHelper)
                        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading #{@xBodyFile} to FTP (to #{@fileName} with database #{@dbName.inspect} and group #{@groupName.inspect})")  
                        storageHelper.uploadFile(@fileName, @xBodyFile, [refseqRecs.first['databaseName'], fileId, gbUploadId, gbUploadFalseValId, gbPartialEntityId, @rackEnv], true)
                      end
                      respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, :Accepted, msg="ACCEPTED: Upload of raw data to Database #{@dbName.inspect}, file: #{@fileName.inspect}, accepted. Final storage of file may be ongoing.", storageHelper.relatedJobIds)
                      respEntity.relatedJobIds = storageHelper.relatedJobIds
                      @statusName = configResponse(respEntity, :Accepted)
                      @statusMsg = respEntity.msg
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Finished with our PUT call for #{@xBodyFile} - could still be running localFileProcessor / ftpFileProcessor to move file into place, though!")  
                    end
                  end
                else
                  @statusName, @statusMsg = :"Bad Request", "There was a problem uploading the file (status: #{initStatus})"
                end
              elsif(BRL::Genboree::Abstract::Resources::FileManagement::EDITABLE_INDEX_FIELDS.include?(@fileProperty) and @fileProperty != 'archived')
                fileRec = fileRecs[0]
                # Update the aspect specified, parse the reqBody for a TextEntity
                reqEntity = parseRequestBodyForEntity(['TextEntity'])
                if(!reqEntity.nil? and reqEntity != :"Unsupported Media Type")
                  # Do any aspect-specific validations (e.g. what dates look like, true|false for hide, etc)
                  validationStatus = BRL::Genboree::Abstract::Resources::FileManagement.validatePropertyValue(@fileProperty, reqEntity.text)
                  if(validationStatus != :OK)
                    @statusName, @statusMsg = :"Bad Request", "The value for aspect #{@fileProperty.inspect} is invalid (#{validationStatus})."
                  else
                    if(reqEntity.text.nil?)
                      @statusName, @statusMsg = :"Bad Request", "The aspect request body cannot be nil."
                    else
                      # If a renaming is being attempted, another file with the new name should not already exist
                      if((@fileProperty == 'fileName' or @fileProperty == 'name') and ( !@dbu.selectFileByDigest(reqEntity.text).nil? and !@dbu.selectFileByDigest(reqEntity.text).empty?))
                        @statusName, @statusMsg = :"Bad Request", "A file with the name: #{reqEntity.text} already exists."
                      else
                        # Update the record for this file based on @fileProperty
                        renameSuccess = true
                        case @fileProperty
                        when ( 'name' or 'fileName' )
                          # Compare remote storage IDs between top-level folders of old path and new path
                          # If these top-level folders don't have matching remote storage IDs, rename will fail because they MUST match
                          oldTopFolderPath = "#{@fileName.split("/")[0]}/"
                          newTopFolderPath = "#{reqEntity.text.split("/")[0]}/"
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
                            renameSuccess = storageHelper.renameFile(fileRec, reqEntity.text)
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
                          if(renameSuccess)
                            @dbu.updateFileById(fileRec['id'], reqEntity.text, fileRec['label'], fileRec['description'], fileRec['autoArchive'], fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
                            @fileName = reqEntity.text
                          end
                        when 'label'
                          @dbu.updateFileById(fileRec['id'], fileRec['name'], reqEntity.text, fileRec['description'], fileRec['autoArchive'], fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
                        when 'description'
                          @dbu.updateFileById(fileRec['id'], fileRec['name'], fileRec['label'], reqEntity.text, fileRec['autoArchive'], fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
                        when 'autoArchive'
                          autoArchiveValue = ( ( reqEntity.text == 'true' or reqEntity.text == true ) ? 1 : 0 )
                          @dbu.updateFileById(fileRec['id'], reqEntity.text, fileRec['label'], fileRec['description'], autoArchiveValue, fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
                        when 'hide'
                          hideValue = ( ( reqEntity.text == 'true' or reqEntity.text == true ) ? 1 : 0 )
                          @dbu.updateFileById(fileRec['id'], reqEntity.text, fileRec['label'], fileRec['description'], fileRec['autoArchive'], hideValue, Time.now(), @userId, fileRec['remoteStorageConf_id'])
                        when 'attributes'
                          # Collect all the attribute names and values
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
                        if(renameSuccess)
                          respEntity = nil
                          if(@fileProperty != 'attributes')
                            respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, reqEntity.text)
                          else
                            respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, reqEntity.attributes)
                          end
                          if(respEntity != :'Unsupported Media Type')
                            respEntity.setStatus(:OK, "The file property #{@fileProperty.inspect} has been updated.")
                            @statusName = configResponse(respEntity)
                            @statusMsg = respEntity.msg
                          end
                        end
                      end
                    end
                  end
                else
                  @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a TextEntity"
                end
              else
                @statusName, @statusMsg = :"Bad Request", "The aspect #{@fileProperty.inspect} is not a valid aspect."
              end
            ensure
              storageHelper.closeRemoteConnection()
            end     
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
          @statusName = :"Internal Server Error"
          @statusMsg = err
        ensure
          #releaseDbFilesInfo()
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      if(@statusName == :OK or @statusName == :Accepted)
        # We are good.
      else
        @resp = representError()
      end
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          fileRecs = @dbu.selectFileByDigest(@fileName)
          if(!fileRecs.nil? and !fileRecs.empty?)
            # Can only delete description
            deleteableAspects = {'description' => true}
            if(deleteableAspects[@fileProperty])
              fileRec = fileRecs[0]
              @dbu.updateFileById(fileRec['id'], fileRec['name'], fileRec['label'], nil, fileRec['autoArchive'], fileRec['hide'], Time.now(), @userId, fileRec['remoteStorageConf_id'])
              respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, '')
              if(respEntity != :'Unsupported Media Type')
                respEntity.setStatus(:OK, "The file property #{@fileProperty.inspect} has been deleted.")
                @statusName = configResponse(respEntity)
              end
            else
              @statusName = :'Method Not Allowed'
              @statusMsg = "NOT ALLOWED: Delete is not allowed for the aspect #{@fileProperty.inspect}."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
        ensure
          releaseDbFilesInfo()
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Helper method for processing partial responses for get method
    # @param [String] filePath the path of the file
    # @param [Fixnum] length the length of bytes we want to read
    # @param [Fixnum] offset the offset we want to start reading from
    # @return [String] the requested text, successfully read, (sometimes) enclosed in <pre> tags
    def prepResp(filePath, length=MAX_BYTES_CEILING, offset=0)
      fileHdl = File.open(filePath)
      # If the user's specified length is larger than our MAX_BYTES_CEILING, then we just set the length to be MAX_BYTES_CEILING
      length = MAX_BYTES_CEILING if(length > MAX_BYTES_CEILING)
      fileHdl.seek(offset)
      content = fileHdl.read(length)
      # We enclose our content in <pre> tags if the user has requested preHtml format
      if (@nvPairs['format'] == 'preHtml')
        content = "<pre>#{content}</pre>"
      end
      @resp['Content-Range'] = "bytes #{offset}-#{offset+length}"
      @resp.status = HTTP_STATUS_NAMES[:'Partial Content']
      # We will set our resp body to content, our final processed text
      @resp.body = content
    end

    # Helper method for transferring special files like .bb, .bw or .bin files
    # [+fileType+]
    # [+content+]
    # [+returns+] status
    def writeSpecialFiles(fileType, content, refseqRecs, groupId)
      status = :OK
      begin
        destDir = nil
        fullFilePath = nil
        if(fileType == 'bin')
          destDir = "#{@genbConf.ridSequencesDir.chomp("/")}/#{refseqRecs.first['refSeqId']}"
          `mkdir -p #{destDir}`
        else
          trkRecs = @dbu.selectFtypeByTrackName(@nvPairs['trackName'])
          if(trkRecs.nil? or trkRecs.empty?)
            raise "No record found for track: #{@nvPairs['trackName']}"
          else
            ftypeid = trkRecs.first['ftypeid']
            destDir = "#{@genbConf.gbAnnoDataFilesDir.chomp("/")}/grp/#{groupId}/db/#{refseqRecs.first['refSeqId']}/trk/#{ftypeid}"
            `mkdir -p #{destDir}`
          end
        end
        fullFilePath = "#{destDir}/#{@fileName}"
        # If file's size is greater than MAX_LOCAL_SIZE, then we run a localFileProcessor job. Otherwise, we just move the file into place
        if(File.size(content) > MAX_LOCAL_SIZE)
          ` mv -f #{Shellwords.escape(content)} #{Shellwords.escape(content)}_genboree.hideFromthin ; chmod 660 #{Shellwords.escape(content)}_genboree.hideFromthin`
          @doMove = true
          submitLocalFileProcessJob([], "#{content}_genboree.hideFromthin", fullFilePath, false)
        else
          `mv #{Shellwords.escape(content)} #{Shellwords.escape(fullFilePath)}`
          `chmod 660 #{Shellwords.escape(fullFilePath)}`
          # Manually set permissions here to avoid defaults of a Tempfile - no longer necessary?
          FileUtils.chmod( 0664, fullFilePath)
        end
      rescue => err
        @statusName, @statusMsg = :"Internal Server Error", "FATAL: Could not write special file: #{@fileName} of type: #{fileType.inspect} to disk.\nError:\n#{err.message}"
        $stderr.puts err
        $stderr.puts err.backtrace.join("\n")
        status = :"Internal Server Error"
      end
      return status
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # This method creates a storage helper from a storageID (positive integer given in the 'remoteStorageConf_id' column of the files table
    # Note that we have a fileRec available here (file already exists), so we just use that
    # @param [Hash] fileRec File record containing different file attributes of current file
    # @param [boolean] muted indicates whether storage helper (and accompanying helpers) are muted or not - useful for deferrable bodies
    # @return [LocalStorageHelper or FtpStorageHelper] storage helper grabbed from storageID
    def createStorageHelperFromRec(fileRec, muted=false)
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
          storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, storageID, @groupName, @dbName, muted, @userId)
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
    # @param [boolean] muted indicates whether storage helper (and accompanying helpers) are muted or not - useful for deferrable bodies
    # @return [LocalStorageHelper or FtpStorageHelper] storage helper based on top-level file record for current file
    def createStorageHelperFromTopRec(fileName, muted=false)
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
            storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, topStorageID, @groupName, @dbName, muted, @userId)
          end
        end
      end
      # If we're working with a local file, we'll create a local Storage Helper
      if(isLocalFile)
        storageHelper = BRL::Genboree::StorageHelpers::LocalStorageHelper.new(@groupName, @dbName, @userId)
      end
      return storageHelper
    end
  end # class DatabaseFileAspect
end ; end ; end # module BRL ; module REST ; module Resources
