require 'uri'
require 'parallel'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module REST ; module Helpers
  class FileApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/file/([^\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/file/[^\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off

    attr_accessor :dbApiUriHelper
    # uploadFailureStr will hold any upload failure message for a given failed upload
    attr_accessor :uploadFailureStr
    # uploadJobId will store the ID (localFileProcessor or ftpFileProcessor) associated with the most recent successful upload
    attr_accessor :uploadJobId
    attr_accessor :containers2Children
    attr_accessor :sleepBase

    alias expandFileContainers expandContainers

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @dbApiUriHelper = nil
      @uploadFailureStr = ""
      @uploadJobId = ""
      @attemptNumber = 0
      @sleepBase = 10

      # provide a set of REGEXP to identify sample and sample-containing URIs
      @FILE_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/([^/]+)/db/([^/]+)/file/([^\?]+)}
      @FILE_ENTITY_LIST_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/files/entityList/([^/\?]+)}
      @FOLDER_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/files(?!/entityList)}
      @DB_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/([^/\?]+)(?!/)}

      # set the order these regexp should be matched in (generally most-specific to least-specific)
      @typeOrder = [:file, :file_list, :file_folder, :database]

      # associate type symbols to their associated regexps
      @type2Regexp = {
        :file => @FILE_REGEXP,
        :file_list => @FILE_ENTITY_LIST_REGEXP,
        :file_folder => @FOLDER_REGEXP,
        :database => @DB_REGEXP
      }

      # associate type symbols to a method that can be used to extract samples from that type
      # if type doesnt have a key, nothing to do -- just use the uri (case of track uri)
      @type2Method = {
        :file_list => :getFilesInList,
        :file_folder => :getFilesInFolder,
        :database => :getFilesInDb
      }

      # provide a cache for an association between container uris and their contents/children
      @containers2Children = Hash.new([])

      super(dbu, genbConf, reusableComponents)
      @initialFileSize = nil
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @dbApiUriHelper = DatabaseApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@dbApiUriHelper)
      @grpApiUriHelper = @dbApiUriHelper.grpApiUriHelper unless(@grpApiUriHelper)
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      super()
      @dbApiUriHelper.clear() if(@dbApiUriHelper)
      @dbApiUriHelper = nil
      @containers2Children = Hash.new([])
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      super(reusableComponents)
      reusableComponents.each_key { |compType|
        case compType
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        when :dbApiUriHelper
          @dbApiUriHelper = reusableComponents[compType]
        end
      }
    end

    # Does this resource actually exist? For files to exist, they just need to be findable.
    def exists?(uri, hostAuthMap=nil)
      exists = false
      if(uri)
        # First, try from cache
        exists = getCacheEntry(uri, :exists)
        if(exists.nil?) # then test manually
          unless(hostAuthMap)
            name = extractName(uri)
            if(name)
              path = diskPath(uri)
              exists = File.exists?(path)
            end
          else
            uriObj = URI.parse(uri)
            apiCaller = ApiCaller.new(uriObj.host, uriObj.path, hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            if(apiCaller.succeeded?)
              exists = true
            end
          end
        end
      end
      return exists
    end

    def diskPath(uri)
      retVal = nil
      if(uri)
        # First, try from cache
        retVal = getCacheEntry(uri, :diskPath)
        if(retVal.nil?) # then do manually
          name = extractName(uri)
          if(name)
            dbName = @dbApiUriHelper.extractName(uri)
            if(dbName)
              grpName = @dbApiUriHelper.grpApiUriHelper.extractName(uri)
              if(grpName)
                names = name.split(/\//)
                names.map!{ |xx| CGI.escape(xx) }
                diskPath = "#{@genbConf.gbDataFileRoot}/grp/#{CGI.escape(grpName)}/db/#{CGI.escape(dbName)}/#{names.join('/')}"
                retVal = diskPath
              end
            end
          end
        end
      end
      return retVal
    end


    # Downloads a database file to the client machine
    # @param uri [String] Genboree file URI possibly with gbKey and without an aspect
    # @param userId [Fixnum] genboree user id of the user
    # @param outputFile [String] full path of the file on the client machine where data is to be saved
    # @param hostAuthMap [Hash<String, Array>] mapping of host to user login, password, hostType
    # @param noOfAttempts [Fixnum] number of times to try to download the file
    # @param mode ['w', 'w+', 'a', 'a+] Ruby IO open mode i.e. write/append
    # @return [Boolean] if file was downloaded successfully
    def downloadFile(uri, userId, outputFile, hostAuthMap=nil, noOfAttempts=15, mode='w', opts={ :attemptNumber => 0, :initialFileSize => @initialFileSize})
      # Boolean which keeps track of whether our download succeeded or not
      retVal = true
      # Set up host auth map and grab host / resource path
      hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
      gbKey = extractGbKey(uri)
      uriObj = URI.parse(uri)
      host = uriObj.host
      rsrcPath = uriObj.path
      zeroAttempts = 4
      fileName = ''
      # Set up attempt number and initial file size (of output file - used for appending?), and sleep for the appropriate amount of time (dependent upon attempt number)
      attemptNumber = ( opts[:attemptNumber] || 0 )
      initialFileSize = ( opts[:initialFileSize] || nil )
      sleepFor = @sleepBase * attemptNumber**2
      sleep(sleepFor)
      # If we're downloading from the same host that we're running the job on (prod to prod, dev to dev, etc.), then we can avoid using the API for remote-backed files.
      # If the files we want to download are located on a remote host, then we must use the API, even for remote-backed files.
      if(host == @genbConf.machineName or host == @genbConf.machineNameAlias)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Because we're downloading from the same host that we're running the job on (#{host}), we can avoid using the API for remote-backed files.")
        # Break file URI into its individual components using the @FILE_REGEXP above
        individualComponents = uri.match(@FILE_REGEXP)
        groupName = CGI.unescape(individualComponents[1])
        dbName = CGI.unescape(individualComponents[2])
        fileName = CGI.unescape(individualComponents[3])
        fileName.slice!("/data")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Group name #{groupName} ; dbName #{dbName} ; fileName #{fileName}.")
        # Set up dbu to be associated with the user's database
        dbuForDownloads = BRL::Genboree::DBUtil.new(@superuserDbDbrc.key, nil, nil)
        databaseMySQLName = dbuForDownloads.selectRefseqByNameAndGroupName(dbName, groupName)[0]["databaseName"]
        dbuForDownloads.setNewDataDb(databaseMySQLName)
        # Create storage helper (local or FTP) to help us download our file
        storageHelper = createStorageHelperFromTopRec(fileName, groupName, dbName, userId, dbuForDownloads)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Storage helper is class #{storageHelper.class.inspect}.")
        # We don't currently support modes other than w or w+ for remote-backed files
        raise "The mode #{mode} is not currently supported for remote-backed files!" if(storageHelper != "Local file" and mode != 'w' and mode != 'w+')
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Because the files we want to download are located on a remote host, we must use the API, even for remote-backed files.")
      end
      begin
        # store initial size of file if it exists to check download success (esp in case of mode='a')
        prevLocalSize = 0
        # Next, download the file itself
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading file at: #{uri}.")
        # If storage helper doesn't exist (due to inputs being remote, most likely) or the file is local, then we'll do an API GET call on the file's data aspect to download the file
        if(!storageHelper or storageHelper == "Local file")
          # Print message about what we're doing
          if(storageHelper)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're downloading a file stored locally on a local host.")
          else 
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're downloading a file stored on some remote host. We don't know if the file is stored locally on that Genboree instance or if the file is remote-backed. We need to use the API regardless.")
          end
          # Open output file
          ff = File.open(outputFile, mode)
          # If initial file size is nil (likely because this is our first download attempt), then we'll grab the size of the file we just opened (which is most likely 0)
          if(initialFileSize.nil?)
            initialFileSize = File.size(ff.path)
          else
            # Otherwise, if initialFileSize is not nil (it's most likely 0), then we'll truncate it to initialFileSize length (which will most likely mean completely clearing it, bringing it back to 0 bytes)
            ff.truncate(initialFileSize)
          end
          # If outputFile exists (which it should, since we just opened it), then prevLocalSize will be set to its size (most likely 0)
          if(File.exists?(outputFile))
            prevLocalSize = File.size(outputFile)
          end
          # Download file using API GET call
          apiCaller = ApiCaller.new(host, "#{rsrcPath}/data?", hostAuthMap)
          apiCaller.get() { |chunk| ff.print(chunk) }
          # Close File object
          ff.close()
          # If the API call didn't succeed, we'll raise an error
          unless(apiCaller.succeeded?)
            raise "Failed to download file. HTTP Response: #{apiCaller.httpResponse.code.inspect}"
          end
        else
          # Otherwise, we'll use the storage helper directly to download the file
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're downloading our file from a remote-backed location, and its Genboree instance is local. This means we can use the Net::FTP helper to download the file (and avoid using the API).")
          storageHelper.downloadFile(fileName, outputFile)
        end
        # Get file size after download has completed
        postLocalSize = File.size(outputFile)
        if(postLocalSize == 0)
          if(attemptNumber < zeroAttempts)
            raise "Potential issue with downloading file (0 byte file). Will try to download the file again (#{zeroAttempts} attempts in total) just to make sure that the file we're trying to download is really 0 bytes (and not still being put in place)."
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloaded file is 0 bytes, and we already tried #{zeroAttempts} times to re-download it (to make sure that it's supposed to be 0 bytes). Since it's still 0 bytes, we're going to proceed and assume the file is supposed to be 0 bytes.")
          end
        end
        # Calculate size difference between after-download and before-download
        sizeDifference = postLocalSize - prevLocalSize
        #  Get the size of the file on Genboree for comparing against our size difference
        apiCaller = ApiCaller.new(host, "#{rsrcPath}/size?", hostAuthMap)
        apiCaller.get()
        fileSize = JSON.parse(apiCaller.respBody)['data']['number'].to_i
        # Make sure the size obtained via the API call matches the size of the downloaded file
        if(sizeDifference != fileSize)
          if(attemptNumber <= noOfAttempts)
            attemptNumber += 1
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to download file #{uri} completely after attempt number: #{attemptNumber}. Size of downloaded file: #{sizeDifference}. Size obtained via API call: #{fileSize}. Trying again...")
            ff.close() if(ff and !ff.closed?)
            if(storageHelper and storageHelper != "Local file")
              storageHelper.closeRemoteConnection()
            end
            retVal = downloadFile(uri, userId, outputFile, hostAuthMap, noOfAttempts, mode, {:attemptNumber => attemptNumber, :initialFileSize => initialFileSize})
          else
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to download file #{uri} after trying #{noOfAttempts} time(s). Quitting.\n")
            ff.close() if(ff and !ff.closed?)
            if(storageHelper and storageHelper != "Local file")
              storageHelper.closeRemoteConnection()
            end
            retVal = false
            attemptNumber = 0
            initialFileSize = nil
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "SUCCESS", "File #{uri} downloaded successfully.")
        end
        if(retVal)
          attemptNumber = 0
          initialFileSize = nil
        end
      rescue => err
        if(attemptNumber <= noOfAttempts)
          attemptNumber += 1
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to download file #{uri} after attempt number: #{attemptNumber} . Trying again...\nError:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
          ff.close() if(ff and !ff.closed?)
          if(storageHelper and storageHelper != "Local file")
            storageHelper.closeRemoteConnection()
          end
          retVal = downloadFile(uri, userId, outputFile, hostAuthMap, noOfAttempts, mode, {:attemptNumber => attemptNumber, :initialFileSize => initialFileSize})
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to download file #{uri} after trying #{noOfAttempts} time(s). Quitting.\n Error:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
          ff.close() if(ff and !ff.closed?)
          if(storageHelper and storageHelper != "Local file")
            storageHelper.closeRemoteConnection()
          end
          retVal = false
          initialFileSize = nil
          attemptNumber = 0
        end
      end
      return retVal
    end

    # Threaded wrapper around downloadFile
    # @param [Array<String>] uris file uris to download
    # @param [Hash] opts parameters in excess of downloadFile
    #   [Fixnum] :n_threads the number of threads to use for the download
    # @return [Hash] map of uris partitioned by
    #   [Hash] :success map uri to local path
    #   [Hash] :fail map uri to error object explaining failure
    #   object explaining why the file could not be downloaded
    # @see downloadFile
    # @todo expandContainers?
    def downloadFilesInThreads(uris, userId, outputDir, hostAuthMap=nil, noOfAttempts=15, mode='w', opts={})
      supOpts = {:n_threads => 6}
      opts.merge!(supOpts)

      # come up with a safe local name (without race conditions) in case of conflicting uris
      basename2Count = Hash.new(0)
      uri2Local = {}
      uris.each { |uri|
        basename = File.basename(uri).chomp("?")
        safename = basename2Count.key?(basename) ? "#{basename}_#{basename2Count[basename]}" : basename
        basename2Count[basename] += 1
        uri2Local[uri] = safename
      }

      # download files in threads
      outputFiles = Parallel.map(uris, :in_threads => opts[:n_threads]) { |uri|
        yieldVal = nil
        begin
          localName = uri2Local[uri]
          outputFile = File.join(outputDir, localName)
          success = downloadFile(uri, userId, outputFile, hostAuthMap, noOfAttempts, mode)
          if(success)
            yieldVal = outputFile
          else
            yieldVal = RuntimeError.new("Could not download file after #{noOfAttempts} attempts")
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to download file #{uri} due to error.\nError:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
          yieldVal = err
        end
        yieldVal
      }

      # record file download success/failure
      retVal = {}
      retVal[:success] = {}
      retVal[:fail] = {}
      outputFiles.each_index { |ii|
        uri = uris[ii]
        file = outputFiles[ii]
        if(file.is_a?(Exception))
          retVal[:fail][uri] = file
        else
          retVal[:success][uri] = file
        end
      }
      return retVal
    end

    # Uploads a database file to the Genboree server
    # @param host [String] host that user wants to upload to
    # @param rsrcPath [String] resource path that user wants to upload to
    # @param userId [Fixnum] genboree user id of the user
    # @param inputFile [String] full path of the file on the client machine where data is to be pulled
    # @param templateHash [Hash<Symbol, String>] hash that contains (potential) arguments to fill in URI for API put command
    # @param plainText [Boolean] tells us whether we're passing an actual file (plainText = false) or just a string of text (plainText = true) with our put command
    # @param noOfAttempts [Fixnum] number of times to try to download the file
    # @return [Boolean] if file was uploaded successfully
    def uploadFile(host, rsrcPath, userId, inputFile, templateHash={}, plainText=false, noOfAttempts=15)
      # Reset @uploadFailureStr before we try to upload a file (it will hold any upload failure message)
      @uploadFailureStr = ""
      # Reset @uploadJob before we try to upload a file (it will hold any localFileProcessor or ftpFileProcessor job IDs associated with our uploads)
      @uploadJobId = ""
      # retVal will be the boolean we return to see whether the upload was successful (true) or not (false)
      retVal = true
      # gotConn will keep track of whether we've successfully uploaded the file within our while loop
      gotConn = false
      # sleepTime will be used to keep track of how long our upload job should wait before trying to upload again
      sleepTime = 0
      # connectionAttempt will keep track of how many attempted connections we've made
      connectionAttempt = 0
      # The rsrcPath variable above may not be fully filled in, relying on templateHash to fill in missing values for group, db, analysis name, file name, etc.
      # Our remote storage helper (FTP, for now) doesn't support this kind of templateHash approach, so let's just fix a copy of that rsrcPath so that it has full, correct path
      rsrcPathForStorageHelper = rsrcPath.clone()
      templateHash.each_key { |currentKey|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "We are replacing {#{currentKey}} with #{CGI.escape(templateHash[currentKey])}")
        rsrcPathForStorageHelper.gsub!("{#{currentKey}}", CGI.escape(templateHash[currentKey]))
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Resource path for storage helper is: #{rsrcPathForStorageHelper}.")
      # Break file URI into its individual components using the @FILE_REGEXP above
      uri = "http://#{host}#{rsrcPathForStorageHelper}"
      individualComponents = uri.match(@FILE_REGEXP)
      groupName = CGI.unescape(individualComponents[1])
      dbName = CGI.unescape(individualComponents[2])
      fileName = CGI.unescape(individualComponents[3])
      fileName.slice!("/data")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Group name is: #{groupName} ; dbName is #{dbName} ; fileName is #{fileName}")
      # First thing we should check: does the input file actually exist? If it doesn't, then we won't try to upload it!
      unless(File.exist?(inputFile))
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Input file doesn't exist! Full file path is: #{inputFile}")
        @uploadFailureStr = "The local file #{File.basename(inputFile)} does not exist,\nso it cannot be uploaded. Please ensure that the local file\nis present and then try again."
        retVal = false
      else
        # If we're uploading to the same host that we're running the job on (prod to prod, dev to dev, etc.), then we can avoid using the API for remote-backed files.
        # If we want to upload to a remote host, then we must use the API, even for remote-backed files.
        fileName = ''
        databaseMySQLName = ''
        while(connectionAttempt < noOfAttempts and !gotConn and retVal)
          # Setting up sleep time for each connection attempt (gets bigger as connection attempts go up in number)
          # We add rand(10 * connectionAttempt) to add some randomness after our first request in case of multiple requests given very closely together
          sleepTime = (@sleepBase * connectionAttempt**2)
          sleepTime += rand(10 * connectionAttempt) if(sleepTime > 0)
          # Prints message on reattempts only
          $stderr.debugPuts(__FILE__, __method__, "SLEEP", "Going to sleep for #{sleepTime.inspect} seconds") if(sleepTime > 0)
          # Sleeping for a total of sleepTime
          sleep(sleepTime)
          if(host == @genbConf.machineName or host == @genbConf.machineNameAlias)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Because we're uploading to the same host that we're running the job on (#{host}), we can avoid using the API for remote-backed files.")
            # Set up dbu to be associated with the user's database
            dbuForUploads = BRL::Genboree::DBUtil.new(@superuserDbDbrc.key, nil, nil)
            databaseMySQLName = dbuForUploads.selectRefseqByNameAndGroupName(dbName, groupName)[0]["databaseName"] rescue nil
            dbuForUploads.setNewDataDb(databaseMySQLName)
            # Create storage helper (local or FTP) to help us upload our file
            storageHelper = createStorageHelperFromTopRec(fileName, groupName, dbName, userId, dbuForUploads)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Storage helper is class #{storageHelper.class.inspect}.")
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Because we want to upload our files to a remote host, we must use the API, even for remote-backed files.")
          end
          begin
            # If the file is going to a remote host, or the file is being uploaded locally (as a local file), then we'll do it via an API PUT call
            if(!storageHelper or storageHelper == "Local file")
              if(storageHelper)
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're uploading a file to a local host.")
              else 
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're uploading a file to some remote host. We don't know if the file will be stored locally on that Genboree instance or if the file will be remote-backed. We need to use the API regardless.")
              end
              # Create apiCaller on Genboree server
              apiCaller = WrapperApiCaller.new(host, rsrcPath, userId)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now attempting to upload file #{inputFile} to #{apiCaller.fillApiUriTemplate()}")
              # Put file on Genboree server using API put call.  If plainText is true, then we are placing a string of text (as opposed to an entire file) with our put command.
              resp = nil
              if(plainText)
                resp = apiCaller.put(templateHash, inputFile)
              else
                resp = apiCaller.put(templateHash, File.open(inputFile))
              end
              # Check to make sure that desired location is actually present (group exists, database exists, etc.)
              apiCaller.parseRespBody()
              statusCode = apiCaller.apiStatusObj["statusCode"] rescue nil
              statusMsg = apiCaller.apiStatusObj["msg"] rescue nil
              # If it isn't, then we don't want to continue - let's set @uploadCheck to 3 and end things immediately
              if(statusCode == "Not Found")
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file because output location no longer exists. Please ensure that output group / database are still present with the same names as when job was submitted.")
                @uploadFailureStr = "Failed to upload file because output location no longer exists.\nPlease ensure that output group (\"#{groupName}\") and database (\"#{dbName}\")\nare still present with the same names as when you submitted the job."
                retVal = false
              elsif(statusCode == "Forbidden")
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file because user is forbidden to upload to output location. Please ensure that user has permission to upload to output group / database.")
                @uploadFailureStr = "We could not upload your file because you are forbidden to upload to the output location.\nPlease ensure that you have permission to upload to the output group (\"#{groupName}\") and database (\"#{dbName}\")."
                retVal = false
              end
              # If apiCaller did not succeed, then we know the file was not uploaded successfully.
              # If retVal is still true, we want to increment connectionAttempt and try again if we're still below our total allowed attempts (and the issue wasn't one of the above issues).
              # If retVal is false, we should just skip the if/elsif below and give up trying to upload the file.
              if(!apiCaller.succeeded? and retVal)
                if(connectionAttempt < noOfAttempts - 1)
                  connectionAttempt += 1
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file after attempt number: #{connectionAttempt}. Status code: #{statusCode} (if empty, means there was an error getting status code); Status message: #{statusMsg} (if empty, means there was an error getting status message); Trying again...\n")
                # Otherwise, we quit and tell the user that we could not upload the file.
                else
                  connectionAttempt += 1
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file #{inputFile} after trying #{connectionAttempt} time(s). Status code: #{statusCode} (if empty, means there was an error getting status code); Status message: #{statusMsg} (if empty, means there was an error getting status message); Quitting.")
                  @uploadFailureStr = "Failed to upload file #{File.basename(inputFile)} after trying #{connectionAttempt} time(s). Status code: #{statusCode} (if empty, means there was an error getting status code); Status message: #{statusMsg} (if empty, means there was an error getting status message); Quitting."
                  retVal = false
                end
              # If apiCaller succeeded, we know (hope?) that the file was uploaded successfully.
              elsif(apiCaller.succeeded?)
                # Set gotConn to true since we successfully put the file on the Genboree server
                gotConn = true
                # Grab job ID associated with upload and save it in @uploadJobId
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiCaller resp body: #{apiCaller.respBody.inspect}.")
                @uploadJobId = apiCaller.parseRespBody["status"]["relatedJobIds"][0]
              end
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "We're uploading our file to a remote-backed location, and its Genboree instance is local. This means we can use the Net::FTP helper to upload the file (and avoid using the API).")
              # We need to create a file record for our file. It'll either be a brand new file (no file record exists yet), or we'll be replacing an old file (file record already exists).
              fileRecs = dbuForUploads.selectFileByDigest(fileName)
              # New file
              if(fileRecs.nil? or fileRecs.empty?)
                rowInserted = dbuForUploads.insertFile(fileName, fileName, nil, 0, 0, Time.now(), Time.now(), userId, storageHelper.storageID)
                if(rowInserted != 1)
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "FATAL: Could not insert record in 'files' table for file: #{fileName.inspect}.")
                  @uploadFailureStr = "FATAL: There was a database issue.\nCould not insert record in 'files' table for file: #{File.basename(fileName)}."
                  retVal = false
                end
              else # A file with the same name already exists. Just do an update
                fileRec = fileRecs[0]
                updateRec = dbuForUploads.updateFileByName(fileName, fileRec['label'], fileRec['description'], fileRec['autoArchive'], fileRec['hide'], Time.now(), userId, fileRec['remoteStorageConf_id'])
                if(updateRec == 0)
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "FATAL: Could not replace contents of file: #{fileName.inspect} in Database #{dbName.inspect} in 'files' table.")
                  @uploadFailureStr = "FATAL: There was a database issue.\nCould not replace contents of file: #{File.basename(fileName)} in Database #{dbName.inspect} in 'files' table."
                  retVal = false
                end
              end
              if(retVal)
                # Mark the file as being uploaded. Once uploaded, it will be reset
                # Also mark the file as a partial entity
                dbuForUploads.insertFileAttrName('gbUploadInProgress')
                dbuForUploads.insertFileAttrName('gbPartialEntity')
                dbuForUploads.insertFileAttrName('gbDataSha1')
                gbUploadId = dbuForUploads.selectFileAttrNameByName('gbUploadInProgress').first['id']
                gbPartialEntityId = dbuForUploads.selectFileAttrNameByName('gbPartialEntity').first['id']
                dbuForUploads.insertFileAttrValue(true)
                gbUploadTrueValId = dbuForUploads.selectFileAttrValueByValue(true).first['id']
                fileId = dbuForUploads.selectFileByDigest(fileName).first['id']
                dbuForUploads.insertFile2Attribute(fileId, gbUploadId, gbUploadTrueValId)
                dbuForUploads.insertFile2Attribute(fileId, gbPartialEntityId, gbUploadTrueValId)
                dbuForUploads.insertFileAttrValue(false)
                gbUploadFalseValId = dbuForUploads.selectFileAttrValueByValue(false).first['id']
                # Upload file
                storageHelper.uploadFile(fileName, File.open(inputFile, 'r'), [databaseMySQLName, fileId, gbUploadId, gbUploadFalseValId, gbPartialEntityId, @rackEnv])
                gotConn = true
              end
            end
          rescue => err
            # If something goes really wrong and we're still below our limit of connection attempts, then we'll try again.
            if(connectionAttempt < noOfAttempts - 1)
              connectionAttempt += 1
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file after attempt number: #{connectionAttempt}. Trying again...\nError:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
            # Otherwise, we quit and tell the user that we could not upload the file.
            else
              connectionAttempt += 1
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload file after trying #{connectionAttempt} time(s). Quitting.\n Error:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
              @uploadFailureStr = "Failed to upload file after trying #{connectionAttempt} time(s). Quitting."
              retVal = false
            end
          ensure
            if(storageHelper and storageHelper != "Local file")
              storageHelper.closeRemoteConnection()
            end
          end
        end
      end
      # At the end, we return retVal, which will be true if the file was successfully uploaded and false otherwise.
      return retVal
    end

    def filesDirForDb(uri)
      retVal = nil
      if(uri)
        # First, try from cache
        retVal = getCacheEntry(uri, :filesDirForDb)
        if(retVal.nil?) # then do manually
          dbUri = @dbApiUriHelper.extractPureUri(uri)
          if(dbUri)
            retVal = dbUri.gsub(%r{/REST/v\d+}, @genbConf.gbDataFileRoot)
          end
        end
      end
      return retVal
    end

    def subdir(uri)
      retVal = nil
      if(uri)
        # First, try from cache
        retVal = getCacheEntry(uri, :subdir)
        if(retVal.nil?) # then do manually
          uri = "http://#{URI.parse(uri).host}#{URI.parse(uri).path}"
          if(uri =~ /\/db\/[^\/]+\/file(?:s)?\/[^\?]+/)
            if(uri =~ %r{/files/})
              retVal = uri.gsub(/#{Regexp.escape(@dbApiUriHelper.extractPureUri(uri))}\/files/, '')
            else
              retVal = File.dirname(uri).gsub(/#{Regexp.escape(@dbApiUriHelper.extractPureUri(uri))}\/file/, '')
            end
          elsif(uri =~ /\/db\/[^\/]+\/files/)
            retVal = "/"
          elsif(uri =~ /\/db\/[^\?\/]+(?:\?.*)?$/)
            retVal = "/"
          else
            retVal = nil
          end
        end
      end
      return retVal
    end

    # Expand a folder uri to its child file uris
    # @param [String] folderUri uri to class to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] file uris whose parent is folderUri
    # @raise [RuntimeError] if API server is down
    def getFilesInFolder(folderUri, userId)
      fileUris = []
      uriObj = URI.parse(folderUri)
      trimmedPath = uriObj.path.chomp('?')
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{trimmedPath}?detailed=true&depth=full", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |fileDetail|
          unless(fileDetail['name'] =~ /\/$/)
            # ignore empty folders
            fileUri = fileDetail['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
            fileUris << fileUri
          end
        }
      else
        raise "URI: #{folderUri.inspect} was inaccessible to the API caller."
      end
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Child files in folder::\n\n#{fileUris.inspect}\n\n<<DONE")
      return fileUris
    end

    # Expand a file entity list uri to its child file uris
    # @param [String] listUri uri to class to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] file uris whose parent is listUri
    # @raise [RuntimeError] if API server is down
    def getFilesInList(listUri, userId)
      fileUris = []
      uriObj = URI.parse(listUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |fileDetail|
          fileUri = fileDetail['url']
          fileUris << fileUri
        }
      else
        raise "URI: #{listUri.inspect} was inaccessible to the API caller."
      end
      return fileUris
    end

    # Expand a database uri to its child file uris
    # @param [String] dbUri uri to class to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] file uris whose parent is dbUri
    # @raise [RuntimeError] if API server is down
    def getFilesInDb(dbUri, userId)
      fileUris = []
      uriObj = URI.parse(dbUri)
      trimmedPath = uriObj.path.chomp('?')
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{trimmedPath}/files?detailed=true&depth=full", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |fileDetail|
          # ignore empty folders
          #unless(fileDetail['name'] =~ /\/$/)
          #  newUriObj = uriObj.dup
          #  newUriObj.path = "#{trimmedPath}/file/#{fileDetail['name']}"
          #  fileUris << newUriObj.to_s
          #end
          unless(fileDetail['name'] =~ /\/$/)          # ignore empty folders
            fileUri = fileDetail['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY]
            fileUris << fileUri
          end
        }
      else
        raise "URI: #{dbUri.inspect} was inaccessible to the API caller."
      end
      return fileUris
    end

    # ------------------------------------------------------------------
    # Feedback helpers
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    # This method creates a storage helper from a file name by looking at its top-level file record.
    # The top-level folder will either not exist (which means it's local) or it will exist (and can be local or remote).
    # A workbench tool will create this top-level folder when a user creates his/her remote area in his/her database.
    # This means that the to-level folder is a reliable way of checking whether the CURRENT file is going to be local or remote.
    # @param [String] fileName file name for current file 
    # @param [String] groupName group name associated with current file 
    # @param [String] dbName database name associated with current file
    # @param [Fixnum] userId current user's ID 
    # @param [BRL::Genboree::DBUtil] dbu used for finding file record info for current file
    # @param [boolean] muted indicates whether storage helper (and accompanying helpers) are muted or not - useful for deferrable bodies
    # @return [FtpStorageHelper or String] storage helper (or dummy string variable) based on top-level file record for current file
    def createStorageHelperFromTopRec(fileName, groupName, dbName, userId, dbu, muted=false)
      # isLocalFile will keep track of whether the file we're inserting is local or remote
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking whether file is local or remote.")
      isLocalFile = false
      # Grab file record associated with top-level folder - all remote files will have a top-level folder with the appropriate remoteStorageConf_id
      topFolderPath = "#{fileName.split("/")[0]}/"
      topFolderRecs = dbu.selectFileByDigest(topFolderPath, true)
      topStorageID = nil
      # If this top folder doesn't exist yet, then we should be dealing with a local file (since all remote files are required to have their top-level directory created by the workbench)
      if(topFolderRecs.nil? or topFolderRecs.empty?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "No top-level folder file record exists. File is local.")
        isLocalFile = true
      else
        # Grab remote storage ID associated with top-level folder
        topFolderRec = topFolderRecs[0]
        topStorageID = topFolderRec["remoteStorageConf_id"]
        # If top-level storage ID is 0 or nil, then we are dealing with a local file
        if(topStorageID == nil or topStorageID == 0)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Top-level folder file record exists and is local.")
          isLocalFile = true
        else
          # Grab conf file associated with current storage ID
          conf = dbu.selectRemoteStorageConfById(topStorageID)
          conf = JSON.parse(conf[0]["conf"])
          storageType = conf["storageType"]
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Top-level folder file record exists and is remote.")
          # If our storage type is FTP, then we will create an FTP Storage Helper
          if(storageType == "FTP")
            # Grab the Genboree FTP DBRC host / prefix from that storage conf.
            ftpDbrcHost = conf["dbrcHost"]
            ftpDbrcPrefix = conf["dbrcPrefix"]
            ftpBaseDir = conf["baseDir"]
            # Create the Genboree FTP storage helper using that information.
            # Here, since we're creating a Genboree-based FTP Storage Helper, we give @groupName and @dbName as parameters.
            # These are used to build the file base for the current user's files.
            storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(ftpDbrcHost, ftpDbrcPrefix, ftpBaseDir, topStorageID, groupName, dbName, muted)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created storage helper for FTP-backed storage.")
          end
        end
      end
      # If we're working with a local file, we'll set storageHelper to be "Local file".
      # We don't actually have to create the local storage helper because we deal with local files via API, not the storage helper.
      # We don't create the local storage helper because it has at least one method (#setFilesDir) in its initialize method that will not work in the cluster tool context
      if(isLocalFile)
        storageHelper = "Local file"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Set storage helper variable to be 'Local file' - not a real storage helper because it's not needed (we will use API).")
      end
      return storageHelper
    end
  end # class DatabaseApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
