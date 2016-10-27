require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'net/ftp'
require 'brl/genboree/helpers/sniffer'
require 'brl/util/expander'
require 'time'

module BRL ; module Genboree ; module Pipeline ; module FTP ; module Helpers
class Lftp

  # when handling errors of these classes, attempt reconnect
  # Errno::ECONNRESET -- connection reset by peer
  # Errno::EPIPE -- previous FTP error (ECONNRESET) ignored (but it couldnt be ignored)
  # SocketError -- server didnt respond to our connection attempt, could be bad host name 
  #   but could just be temporarily down
  RECONNECT_ERRORS = [::Errno::ECONNRESET, ::Errno::EPIPE, ::SocketError, ::Net::FTPTempError]
  # mixin that allows us to map given host (ftp.genboree.org, for example) to domain alias (phenylalanine.brl.bcmd.bcm.edu, for example)
  include BRL::Cache::Helpers::DomainAliasCacheHelper::CacheClassMethods
  # [Net::FTP] ftp object to use to perform ftp operations
  attr_accessor :ftpObj
  attr_reader :host # changing host will disrupt any reconnection attempts
  attr_reader :originalHost # stores the original host (before conversion via domainAliases) 
                            # This is useful for type? method since we have to grab dbrc record again
  attr_accessor :lsFiles # Used for recursive ls calls 
  attr_accessor :muted   # Used to mute debug statements (by default, they're on, but if we want to turn them off, we use this flag).
                         # Thought about doing muting on a by-method basis, but it seems ugly - you can always turn muted off if you want to re-enable messages!

  # @todo user ignored, pulled from dbrc, unlike rsyncHelper
  # @todo method signature needs to be updated
  def initialize(host=nil, user=nil, password=nil, prefix=nil, muted=false)
    # Get login info (host and DBRC file for user / password)
    genbConf = BRL::Genboree::GenboreeConfig.load()
    host = genbConf.send(:rsyncHelperHost) if(host.nil? or host.empty?)
    raise ArgumentError.new("host argument not provided and none is set in the configuration file!") if(host.nil? or host.empty?)
    @host = host
    @originalHost = host
    @dbrc = BRL::DB::DBRC.new()
    @prefix = (prefix ? prefix : :ftp)
    @muted = muted
    dbrcRec = @dbrc.getRecordByHost(@originalHost, @prefix) # it is not safe to store this as an instance variable because it contains passwords
    raise ArgumentError.new("Unable to extract user login information from dbrc file for original host #{@originalHost.inspect} and record type #{@prefix}") if(dbrcRec.nil?)
    if(@host != getDomainAlias(@originalHost))
      $stderr.debugPuts(__FILE__, __method__, "UPDATE", "Host changed from #{@host} to #{getDomainAlias(@host)} on basis of domainAliases file") unless(@muted)
      @host = getDomainAlias(@host)
    end
    @ftpObj = connectToFtp(@host, dbrcRec[:user], dbrcRec[:password])
    # Grab sniffer format file and create sniffer object
    @snifferFormatFile = JSON.parse(File.read(genbConf.gbSnifferFormatConf))
    @sniffer = BRL::Genboree::Helpers::Sniffer.new()
    # Set number of bytes grabbed for checking type (taken from head and tail of file using curl)
    @bytesGrabbedForType = 128000
    # Temp area used for type command (curl needs to download somewhere)
    @tempArea = ENV['TMPDIR']
    # Used for ls calls
    @lsFiles = []
    # Used for longls calls
    @longlsFiles = []
  end

  # Provide a wrapper around Net::FTP.new() to reattempt a connection if temporarily unsuccessful
  # @param [String] host the ftp host to connect to
  # @param [String] user the user name to use at ftp host
  # @param [String] passwd the user password to use at ftp host
  # @param [nil, TrueClass] acct flag if FTP ACCT command should be sent following successful login
  # @param [Fixnum] noOfAttempts number of attempts to make connecting to FTP server
  # @return [Net::FTP] object to use to make ftp commands
  def connectToFtp(host, user=nil, passwd=nil, acct=nil, noOfAttempts=3)
    ftpObj = nil
    attempt = 1
    while(ftpObj.nil? and attempt <= noOfAttempts)
      begin
        ftpObj = ::Net::FTP.open(host, user, passwd, acct)
        ftpObj.passive = true
      rescue *RECONNECT_ERRORS => err
        unless(@muted)
          $stderr.debugPuts(__FILE__, __method__, "FTP", "Error encountered while connecting to ftp on attempt=#{attempt.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.message=#{err.message.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.backtrace:\n#{err.backtrace.join("\n")}")
        end
        if(attempt == noOfAttempts)
          # Make sure we forcefully close the connection if we exceed the maximum number of attempts
          ftpObj.close() rescue nil
          ftpObj = nil
          raise err
        else
          sleepTime = 2 ** (attempt - 1) - 1
          $stderr.debugPuts(__FILE__, __method__, "FTP", "sleeping for #{sleepTime} seconds") unless(sleepTime == 0 or @muted)
          sleep(sleepTime)
        end
      rescue Exception => err
        # If we encounter some other, non-connection based issue, we'll also forcefully close the connection
        ftpObj.close() rescue nil
        ftpObj = nil
        raise err
      end
      attempt += 1
    end
    @ftpObj = ftpObj
    return @ftpObj
  end

  # Provide wrapper around arbitrary Net::FTP methods to reattempt if connection is lost
  # @param [Symbol] methodSym method to send to @ftpObj
  # @param [Array] args arguments to provide with method call methodSym
  # @param [Array<Class>] error classes unique to methodSym that we should be reattempting in case of
  # @param [Fixnum] noOfAttempts the number of times to attempt the operation
  def execWithReattempt(methodSym, args, errorClasses=[], noOfAttempts=3, &block)
    retVal = nil
    errorClasses = [] unless(errorClasses.is_a?(Array))
    attempt = 1
    while(retVal.nil? and attempt <= noOfAttempts)
      err = nil
      begin
        retVal = @ftpObj.send(methodSym, *args, &block)
        retVal = (retVal.nil? ? true : retVal) # @todo TODO some ftp methods return nil on success, distinguish between this method failure (nil) with response nil
      rescue *RECONNECT_ERRORS => err
        dbrcRec = @dbrc.getRecordByHost(@originalHost, :ftp)
        @ftpObj = connectToFtp(@host, dbrcRec[:user], dbrcRec[:password], 1)
      rescue *errorClasses => err
        # if errorClasses=[], behaves as if no rescue clause
      end
      unless(err.nil?)
        unless(@muted)
          $stderr.debugPuts(__FILE__, __method__, "FTP", "Error encountered while executing methodSym=#{methodSym.inspect} on attempt=#{attempt.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.message=#{err.message.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.backtrace:\n#{err.backtrace.join("\n")}")
        end
        if(attempt == noOfAttempts)
          raise err
        end
      end
      sleepTime = 2 ** (attempt - 1) - 1
      $stderr.debugPuts(__FILE__, __method__, "FTP", "sleeping for #{sleepTime} seconds") unless(sleepTime == 0 or @muted)
      sleep(sleepTime)
      attempt += 1
    end
    return retVal
  end

  # Get file size for a remote file
  # @param [String] file the remote file to get the size of
  # @param [Fixnum] noOfAttempts number of attempts to make to get file size
  # @return [Fixnum, NilClass] nil if error occurred, 0 if file is a directory, otherwise 
  #   the file size
  # @note most Unix directories have size of 4096 (excluding their contents)
  # @todo return 4096 if directory? get from ftpObj.ls?
  def size(file, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking size of #{file} on FTP") unless(@muted)
    begin
      requireAbsolutePaths(file)
      method = :size
      errorClasses = []
      retVal = execWithReattempt(method, [file], errorClasses, noOfAttempts)
    rescue ::Net::FTPPermError => err
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Size check failed - let's see if #{file} is directory") unless(@muted)
      fileIsDir = directory?(file, noOfAttempts)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{file} directory? #{fileIsDir}") unless(@muted)
      retVal = 0 if(fileIsDir)
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end
  
  # Get mime type for a remote file
  # @param [String] file the remote file to get the size of
  # @param [Fixnum] noOfAttempts number of attempts to make to get file size
  # @return [String, NilClass] mime type of the file. Nil otherwise
  def mimeType(file, noOfAttempts=10)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking the mime type of #{file} via cURL on FTP") unless(@muted)
    # Grab dbrcRec again because we don't want to store password - we use original host for grabbing correct dbrc record
    # Note that curl commands below use @host instead of dbrcRec[:host]
    dbrcRec = @dbrc.getRecordByHost(@originalHost, @prefix) 
    # Figure out file name for first part of file (@bytesGrabbedForType) for head command (used in sniffer)
    firstPartOfFile = "#{@tempArea}/#{File.basename(file)}-#{"".generateUniqueString}"
    # Grab first part of file using curl - we subtract 1 from @bytesGrabbedForType for the range parameter of curl (0 to 499 is 500 bytes, for example)
    sizeOfFirstPart = @bytesGrabbedForType - 1
    ftpProtocol = "ftp://"
    response = `curl -u #{dbrcRec[:user]}:#{dbrcRec[:password]} #{ftpProtocol}#{@host}#{file} -r 0-#{sizeOfFirstPart} -o #{firstPartOfFile} 2>/dev/null`
    # Figure out file name for second part of file (@bytesGrabbedForType) for tail command (used in sniffer)
    secondPartOfFile = ""
    if(size(file) and size(file) >= @bytesGrabbedForType)
      secondPartOfFile = "#{@tempArea}/#{File.basename(file)}-#{"".generateUniqueString}"
      # Grab second part of file using curl
      `curl -u #{dbrcRec[:user]}:#{dbrcRec[:password]} #{ftpProtocol}#{@host}#{file} -r -#{@bytesGrabbedForType} -o #{secondPartOfFile} 2>/dev/null`
    end
    # Append second part of file to first part of file (if it exists)
    unless(secondPartOfFile.empty?)
      secondPartOfFileContents = File.read(secondPartOfFile)
      File.open(firstPartOfFile, 'a') { |file2| file2.write(secondPartOfFileContents) }
      `rm #{secondPartOfFile}`
    end
    # OK, now we have a chunk of our file that we can use to check for file type
    fullFilePath = firstPartOfFile
    # If we don't have a file at this point, something went wrong above 
    unless(File.exist?(fullFilePath))
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error occurred when trying to retrieve file. It is likely that file is empty or does not exist. Will return application/x-empty") unless(@muted)
      fileType = "application/x-empty"
    else
      # Check file type using sniffer
      @sniffer.filePath = fullFilePath
      fileType = @sniffer.mimeType()
      # Remove temp file grabbed for sniffing and then report file type in response
    end
    `rm -f #{firstPartOfFile}`
    return fileType
  end

  # Determine if file (or directory) exists on ftp server by checking its size
  # @param [String] file the file to check existence of
  # @return [true, false] indicator if file exists
  # @todo use ls and check if file is in results instead?
  def exists?(file, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking whether #{file} exists on FTP") unless(@muted)
    begin
      fileSize = size(file)
      retVal = (fileSize.nil? ? false : true)
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end

  # Determine type of file present on FTP server by using sniffer
  # TODO: Include support for Expander sniffed file types?
  #   Note that we use cURL here and NOT OUR LFTP HELPER
  #   Net::FTP helper doesn't have capacity to grab byte ranges so we need to use cURL
  #   SIZE extension must be enabled by the FTP server in order for cURL range to work
  #   Thus, this is fine for OUR FTP server, but might not work for other FTP servers
  # @param [String] file path to file
  # @return [String] file type ("Unknown" if sniffer doesn't recognize it)
  def type?(file)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking the file type of #{file} via cURL on FTP") unless(@muted)
    # Grab dbrcRec again because we don't want to store password - we use original host for grabbing correct dbrc record
    # Note that curl commands below use @host instead of dbrcRec[:host]
    dbrcRec = @dbrc.getRecordByHost(@originalHost, @prefix) 
    # Figure out file name for first part of file (@bytesGrabbedForType) for head command (used in sniffer)
    firstPartOfFile = "#{@tempArea}/#{File.basename(file)}-#{"".generateUniqueString}"
    # Grab first part of file using curl - we subtract 1 from @bytesGrabbedForType for the range parameter of curl (0 to 499 is 500 bytes, for example)
    sizeOfFirstPart = @bytesGrabbedForType - 1
    ftpProtocol = "ftp://"
    response = `curl -u #{dbrcRec[:user]}:#{dbrcRec[:password]} #{ftpProtocol}#{@host}#{file} -r 0-#{sizeOfFirstPart} -o #{firstPartOfFile} 2>/dev/null`
    # Figure out file name for second part of file (@bytesGrabbedForType) for tail command (used in sniffer)
    secondPartOfFile = ""
    if(size(file) and size(file) >= @bytesGrabbedForType)
      secondPartOfFile = "#{@tempArea}/#{File.basename(file)}-#{"".generateUniqueString}"
      # Grab second part of file using curl
      `curl -u #{dbrcRec[:user]}:#{dbrcRec[:password]} #{ftpProtocol}#{@host}#{file} -r -#{@bytesGrabbedForType} -o #{secondPartOfFile} 2>/dev/null`
    end
    # Append second part of file to first part of file (if it exists)
    unless(secondPartOfFile.empty?)
      secondPartOfFileContents = File.read(secondPartOfFile)
      File.open(firstPartOfFile, 'a') { |file2| file2.write(secondPartOfFileContents) }
      `rm #{secondPartOfFile}`
    end
    # OK, now we have a chunk of our file that we can use to check for file type
    fullFilePath = firstPartOfFile
    # If we don't have a file at this point, something went wrong above 
    unless(File.exist?(fullFilePath))
      raise "Error occurred when trying to retrieve file. It is likely that file is empty, a folder, or does not exist."
    end
    # Check file type using sniffer
    @sniffer.filePath = fullFilePath
    fileType = @sniffer.autoDetect()
    fileType = "Unknown" unless(fileType)
    # Remove temp file grabbed for sniffing and then report file type in response
    `rm #{firstPartOfFile}`
    return fileType
  end

  # File.directory? like support for remote ftp server
  # @param [String] ftpLoc
  # @return [NilClass, FalseClass, TrueClass] true if ftpLoc is a directory, false otherwise
  def directory?(ftpLoc, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking whether #{ftpLoc} is a directory on FTP") unless(@muted)
    begin
      requireAbsolutePaths(ftpLoc)
      method = :nlst
      errorClasses = []
      lsOut = execWithReattempt(method, [ftpLoc], errorClasses, noOfAttempts)
      if(lsOut.length > 1)
        retVal = true
      elsif(lsOut.length == 1)
        # if file name is different from what we gave, that file is actually a singleton entry in
        # this directory
        if(lsOut.first == ftpLoc)
          retVal = false
        else
          retVal = true
        end
      else
        # empty so either not a directory or an empty directory
        method = :nlst
        errorClasses = []
        listOut = execWithReattempt(method, ["#{ftpLoc}/.."], errorClasses, noOfAttempts)
        if(listOut.respond_to?(:empty?))
          retVal = (listOut.empty? ? false : true)
        end
        # else something went wrong, leave retVal nil
      end
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end

  # Provide a wrapper around ftp.rename to reattempt after temporary network/connection failure
  # @param [String] src ftp file location to rename from (current name)
  # @param [String] dest ftp file location (directory or file name) to move/rename to
  # @param [Fixnum] noOfAttempts number of attempts to make if connection fails
  # @return [String, nil] ftp file location of renamed file, or nil if unsuccessful
  def renameOnFtp(src, dest, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Renaming #{src} to #{dest} on FTP") unless(@muted)
    begin
      requireAbsolutePaths([src, dest])
      unless(exists?(dest))
        method = :rename
        errorClasses = []
        success = execWithReattempt(method, [src, dest], errorClasses, noOfAttempts)
        retVal = dest if(success)
      end
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end
  alias :rename :renameOnFtp

  # Use some heuristics to determine if a local file has the same contents as a remote file
  # @param [String] localFile
  # @param [String] ftpFile
  # @return [NilClass, FalseClass, TrueClass] 
  def filesMatch?(localFile, ftpFile, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking whether local file #{localFile} and FTP file #{ftpFile} have the same contents") unless(@muted)
    begin
      # (1) check file sizes or that each is a directory
      if(directory?(ftpFile))
        retVal = (File.directory?(localFile) ? true : false)
      else
        localSize = File.size(localFile)
        remoteSize = size(ftpFile, noOfAttempts)
        retVal = (localSize == remoteSize ? true : false)
      end
      # @todo add more heuristics for robustness if needed
      # (2) ...
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end

  # Download file from ftp src location to local dest location
  # @param [String] src ftp location to download from
  # @param [String] dest local location to download to
  # @param [Fixnum] noOfAttempts number of times to attempt to download from ftp
  # @param [TrueClass, FalseClass] safe boolean flag, if true, refuse to overwrite local files
  # @return [String] filepath of downloaded file
  # @note this method will always make at least 1 attempt to download the file even if
  #   the local dest size matches the remote src size
  def downloadFromFtp(src, dest, noOfAttempts=10, safe=false)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Downloading FTP file #{src} to local location #{dest}") unless(@muted)
    begin
      if(File.directory?(dest))
        basename = File.basename(src)
        dest = File.join(dest, basename)
      elsif(File.exist?(dest))
        if(safe)
          raise LftpError.new("Refusing to download to #{dest} because the file already exists")
        end
      end
      requireAbsolutePaths(src)
      if(directory?(src))
        raise ArgumentError.new("Cannot download directory #{src}")
      end
      method = :getbinaryfile
      errorClasses = []
      attempt = 0
      filesMatch = false
      while(!filesMatch and attempt < noOfAttempts)
        $stderr.debugPuts(__FILE__, __method__, "FTP", "download attempt #{attempt} failed; reattempting") if(attempt >= 1) unless(@muted)
        reattemptsInLoop = 2
        resp = execWithReattempt(method, [src, dest], errorClasses, reattemptsInLoop)
        filesMatch = filesMatch?(dest, src, noOfAttempts)
        attempt += 1
      end
      retVal = dest if(filesMatch)
    rescue ::Net::FTPPermError => err
      # raises FTPPermError if file doesnt exist
      retVal = nil
    rescue ::Net::FTPError => err
      logError(err)
      retVal = nil
    end
    return retVal
  end
  alias :downloadFileFromFtp :downloadFromFtp 

  # Download multiple files (srcList) from ftp src location to local destDir location
  # @param [Array<String>] srcList src ftp file locations to download from
  # @param [String] destDir directory location to download to
  # @return [Array<String>] local file locations for downloaded files
  # @todo continue if only 1 file from srcList fails (even after reattempts?)
  # @todo name collision if 2 files in srcList have same base name
  def downloadFilesFromFtp(srcList, destDir, noOfAttempts=10)
    retVal = []
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Downloading multiple files #{srcList.inspect} from FTP to local directory #{destDir}") unless(@muted)
    srcList.each{|src|
      basename = File.basename(src)
      dest = File.join(src, basename)
      localPath = downloadFromFtp(src, dest, noOfAttempts)
      retVal.push(localPath) unless(localPath.nil?)
    }
    return retVal
  end
  
  # Upload src to ftp location given by dest
  # @param [Array<String>, String] src list of files; if directory, upload subtree rooted at that directory
  # @param [String] dest ftp server folder to put results to
  # @param [Fixnum] noOfAttempts
  # @param [Boolean] safe if true and file src already exists at dest, no upload is attempted
  # @return [Array<String>] list of ftp filepaths
  def uploadToFtp(src, dest, noOfAttempts=10, safe=false)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Uploading local file #{src} to remote FTP location #{dest}") unless(@muted)
    # handle input polymorphism
    src = Marshal.load(Marshal.dump(src))
    argErrMsg = "first parameter src=#{src} must be an Array of files (or directories) or a single file (or directory)" unless(src.is_a?(Array))
    if(src.is_a?(String))
      if(File.directory?(src))
        src = Dir.glob(src)
      else
        src = [src]
      end
    elsif(src.respond_to?(:each))
      tmp = []
      src.each{|file|
        if(File.directory?(file))
          tmp += Dir.glob(file)
        else
          tmp.push(file)
        end
      }
      src = tmp
    else
      raise ArgumentError, argErrMsg
    end
    raise ArgumentError, argErrMsg unless(src.is_a?(Array))
    requireAbsolutePaths(dest)
    # Make destination directory 
    mkdir(dest)
    raise ArgumentError, "second parameter dest=#{dest} must be a directory at the ftp server" unless(directory?(dest))
    # upload src list to ftp server
    ftpPaths = []
    method = :putbinaryfile # responds with nil if success, error otherwise
    errorClasses = []
    src.each{|file|
      basename = File.basename(file)
      begin
        ftpPath = File.join(dest, basename)
        if(safe)
          lsOut = ls(ftpPath)
          raise LftpError, "ftp file #{ftpPath} already exists" unless(lsOut.empty?)
        end
        # try to upload file to FTP until we have indication of success
        filesMatch = false
        attempt = 0
        while(!filesMatch and attempt < noOfAttempts)
          $stderr.debugPuts(__FILE__, __method__, "FTP", "upload attempt #{attempt} for #{file} failed; reattempting") if(attempt >= 1) unless(@muted)
          reattemptsInLoop = 2
          resp = execWithReattempt(method, [file, ftpPath], errorClasses, reattemptsInLoop)
          filesMatch = filesMatch?(file, ftpPath)
          attempt += 1
        end
        # if successful, add file to ftpPaths
        ftpPaths.push(ftpPath) if(filesMatch)
      rescue ::Net::FTPPermError => err
        msg = "Unable to upload to ftpPath=#{ftpPath}, maybe because this path points to a directory?"
        $stderr.debugPuts(__FILE__, __method__, "FTP", msg) unless(@muted)
        logError(err)
      rescue LftpError => err
        $stderr.debugPuts(__FILE__, __method__, "FTP", "Unable to upload to ftpPath=#{ftpPath} because the file already exists and safe mode = #{safe}") unless(@muted)
      rescue ::Net::FTPError => err
        logError(err)
        ftpPaths = []
      end
    }
    return ftpPaths
  end

  # Provide wrapper around ftp.storbinary to make reattempts if necessary
  # @param [StringIO or Tempfile or File] src the StringIO object (or Tempfile or File object) that contains the data we're going to stream to the FTP server
  # @param [String] dest the destination file name (including directories)
  # @param [Fixnum] noOfAttempts number of attempts to try the storbinary uploading command (default of 10)
  # @return [Array] info about whether attempt succeeded or failed, and hexdigest if input was StringIO
  def uploadStreamToFtp(src, dest, noOfAttempts=10)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Streaming data to #{dest} on FTP via Net::FTP helper") unless(@muted)
    retVals = []
    # Destination dir has to be absolute path 
    requireAbsolutePaths(dest)
    # Create destination directory if it doesn't already exist
    mkdir(File.dirname(dest))
    # Upload file using storbinary method and STOR command 
    method = :storbinary
    storCall = "STOR #{dest}"
    errorClasses = []
    # contents will hold the contents of our string (so we can perform a SHA on it) - only done when incoming object is StringIO
    contents = ""
    # Rewind StringIO / Tempfile / File 
    src.rewind()
    begin
      # Pass chunks to contents if src class is StringIO (so we can compute SHA) - otherwise, we don't need to do this since Tempfile / File are on disk and SHA1 can be computed from that entity
      if(src.class == StringIO)
        retVal = execWithReattempt(method, [storCall, src, 4096, nil], errorClasses, noOfAttempts) { |chunk| contents << chunk }
      else
        retVal = execWithReattempt(method, [storCall, src, 4096, nil], errorClasses, noOfAttempts)
      end
    rescue ::Net::FTPPermError => err
      retVal = nil
    end
    # First, retVal will either be true, false, or nil (failure) depending on whether execWithReattempt call above succeeds or fails
    retVals << retVal
    # Then, if input is StringIO, we want to push the SHA1 of its contents (string) onto retVals as well
    retVals << Digest::SHA1.hexdigest(contents) unless(contents.empty?)
    return retVals
  end

  # Provide wrapper around ftp.nlst to make reattempts if necessary
  # @param [String] dir the ftp dir name
  # @param [Fixnum] noOfAttempts number of attempts to try the ls command (default of 10)
  # @param [Array] patterns different file patterns to look for (used in poller)
  # @param [Fixnum] currentDepth current depth being explored
  # @param [Fixnum or String] maxDepth indicates the depth to which we want to recursively ls (default of 0 will check immediate depth, depth=infinity will check all depths)
  # @return [Array] list of file base names in dir (empty if dir doesn't exist)
  # @note This method (ftp.nlst) is like simple ls while #longls (ftp.ls) is like ls -l
  def ls(dir, noOfAttempts=10, patterns=nil, currentDepth=0, maxDepth=0)
    # Raise error if current depth is higher than max depth (which is impossible if maxDepth is infinity)
    raise "Your current depth is higher than your max depth - this is not permitted!" if(maxDepth != "infinity" and currentDepth > maxDepth)
    # Reset @lsFiles if currentDepth is 0 (we're doing a new ls call, so we want a new list for our files)
    if(!@lsFiles.empty? and currentDepth == 0)
      @lsFiles = []
    end
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Listing files in #{dir} on FTP (output format similar to ls -l, FTP command nlst)") unless(@muted)
    requireAbsolutePaths(dir)
    method = :nlst
    errorClasses = []
    # Do the Net::FTP nlst command
    retVal = execWithReattempt(method, [dir], errorClasses, noOfAttempts)
    # If we're searching for particular patterns within the list returned by nlst, then we only save those paths that meet the patterns
    if(!patterns.nil? and !patterns.empty? and patterns.respond_to?(:each))
      if(patterns.is_a?(String))
        patterns = [patterns]
      end
      matchingPaths = []
      retVal.each{|path|
        basename = File.basename(path)
        patterns.each{|pattern|
          regexp = Regexp.compile(pattern)
          matchData = regexp.match(basename)
          unless(matchData.nil?)
            matchingPaths.push(path) 
            break
          end
        }
      }
      retVal = matchingPaths
    end
    # We put each entry from nlst into @lsFiles and then do a recursive ls call on each entry (if it's a directory) to explore the next level of depth 
    retVal.each { |currentEntry|
      @lsFiles << currentEntry
      if(maxDepth == "infinity")
        continueExploring = directory?(currentEntry)
      else
        continueExploring = (currentDepth < maxDepth and directory?(currentEntry))
      end
      if(continueExploring)
        ls(currentEntry, noOfAttempts, patterns, currentDepth + 1, maxDepth)
      end
    }
    # by the end, @lsFiles will contain all files through the specified maxDepth - we set retVal to that list and return it
    retVal = @lsFiles.clone()
    return retVal
  end

  # Provide wrapper around ftp.ls to make reattempts if necessary
  # @param [String] dir the ftp dir name
  # @param [Fixnum] noOfAttempts number of attempts to try the longls command (default of 10)
  # @param [Fixnum] currentDepth current depth being explored
  # @param [Fixnum or String] maxDepth indicates the depth to which we want to recursively ls (default of 0 will check immediate depth, depth=infinity will check all depths)
  # @return [Array] listing of every directory (with BYTE FILE SIZES OF EACH FILE) (empty if dir doesn't exist)
  # @note This method (ftp.ls) is like ls -l while #ls (ftp.nlst) is like simple ls
  def longls(dir, noOfAttempts=10, currentDepth=0, maxDepth=0)
    # Add / to end of dir if it's not at the end for consistency's sake (makes our life easier when doing recursive calls below)
    dir << "/" if(dir[-1].chr != "/")
    # Raise error if current depth is higher than max depth (which is impossible if maxDepth is infinity)
    raise "Your current depth is higher than your max depth - this is not permitted!" if(maxDepth != "infinity" and currentDepth > maxDepth)
    # Reset @longlsFiles if currentDepth is 0 (we're doing a new ls call, so we want a new list for our files)
    if(!@longlsFiles.empty? and currentDepth == 0)
      @longlsFiles = []
    end
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Listing files in #{dir} on FTP (output format similar to ls -l, FTP command ls)") unless(@muted)
    requireAbsolutePaths(dir)
    method = :ls
    errorClasses = []
    # Do the Net::FTP ls command
    retVal = execWithReattempt(method, [dir], errorClasses, noOfAttempts)
    # We put each entry from ls into @longlsFiles and then do a recursive ls call on each entry (if it's a directory) to explore the next level of depth 
    retVal.each { |currentEntry|
      # Add dir as prefix to current entry (because we want full paths in our ls listing, and we also need full paths for recursive exploration)
      newCurrentEntry = currentEntry.clone()
      newCurrentEntry = newCurrentEntry.split("\s")
      newCurrentEntry[-1] = "#{dir}#{newCurrentEntry[-1]}"
      newCurrentEntry = newCurrentEntry.join("\s")
      # Update currentEntry to be the new version (with dir prefix)
      retVal[retVal.index(currentEntry)] = newCurrentEntry
      currentEntry = newCurrentEntry
      # Add currentEntry to our final array of files (@longlsFiles)
      @longlsFiles << currentEntry
      # If maxDepth is infinity, then we don't care about whether currentDepth is less than maxDepth - it always is!
      # Otherwise, we need to make sure that currentDepth is less than maxDepth
      # We'll only continue exploring down the currentEntry directory tree if currentEntry is, in fact, a directory
      if(maxDepth == "infinity")
        continueExploring = directory?(currentEntry.split("\s")[-1])
      else
        continueExploring = (currentDepth < maxDepth and directory?(currentEntry.split("\s")[-1]))
      end
      # If currentEntry is a directory, and we're not yet at max depth, then we'll recursively call the longls method to continue exploring
      if(continueExploring)
        longls(currentEntry.split("\s")[-1], noOfAttempts, currentDepth + 1, maxDepth)
      end
    }
    # by the end, @longlsFiles will contain all files through the specified maxDepth - we set retVal to that list and return it
    retVal = @longlsFiles.clone()
    return retVal
  end

  # Provide wrapper around ftp.mtime to make reattempts if necessary
  # @param [String] file the file to check mtime for
  # @return [NilClass, Time] mtime of file or nil if it doesn't exist (or cant otherwise get time)
  def mtime(file, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking modification time of #{file} on FTP") unless(@muted)
    requireAbsolutePaths(file)
    method = :mtime
    errorClasses = []
    begin
      retVal = execWithReattempt(method, [file], errorClasses, noOfAttempts)
    rescue ::Net::FTPPermError => err
      # raises FTPPermError if file doesnt exist
      retVal = nil
    end
    return retVal
  end

  # Get last modification time for multiple files
  # @param [Array<String>] files file paths to get mtimes for
  # @return [Hash<String, Time>] map of absolute ftp path to mod time as Time object
  def mtimes(files, noOfAttempts=3)
    retVal = {}
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Checking modification times of #{files.inspect} on FTP") unless(@muted)
    requireAbsolutePaths(files)
    files.each{|file|
      retVal[file] = mtime(file, noOfAttempts) 
    }
    return retVal
  end

  # Provide wrapper around ftp.mkdir to make reattempts if necessary (supports recursive directory creation)
  # @param [String] dir the remote directory to create
  # @return [NilClass, String] the ftp filepath to the remote directory created or nil if failure
  def mkdir(dir, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Creating FTP directory #{dir}") unless(@muted)
    requireAbsolutePaths(dir)
    # Cut up directory into individual components so that we can recursively create directories (if we need to)
    splitDir = dir.split("/")
    finalDir = ""
    noError = true
    splitDir.each { |currentSubDir|
      finalDir << "#{currentSubDir}/"
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Current directory: #{finalDir}") unless(@muted)
      unless(exists?(finalDir) and noError)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Directory does not exist, so creating it") unless(@muted)
        method = :mkdir
        errorClasses = []
        begin
          retVal = execWithReattempt(method, [finalDir], errorClasses, noOfAttempts)
        rescue ::Net::FTPPermError => err
          # raises FTPPermError if file/directory already exists
          # raises FTPPermError if no permission to create directory
          # NOTE use :directory? if you want to know if the directory already exists
          retVal = nil
          noError = false
        end
      end
    }
    return retVal
  end

  # Provide wrapper around ftp.rmdir to make reattempts if necessary
  # @param [String] dir the remote directory to remove
  # @param [Fixnum] noOfAttempts number of attempts to try rmdir command
  # @param [Boolean] recursive boolean flag that tells us whether to delete all children (subfolders / files) in remote directory
  # @return [Boolean] true if directory was removed, nil otherwise
  def rmdir(dir, noOfAttempts=10, recursive=false)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Removing FTP directory #{dir} on FTP") unless(@muted)
    requireAbsolutePaths(dir)
    # If recursive is true, we'll delete all children in remote directory
    if(recursive)
      # Grab all files in directory
      listOfFiles = ls(dir)
      # If the directory is empty, then we can go ahead and delete it using rmdir (no recursion)
      if(listOfFiles.empty?)
        rmdir(dir)
      else
        # Otherwise, we traverse all files / folders in the directory
        listOfFiles.each { |currentFile|
          # If current entry is a directory, then we run rmdir recursively
          if(directory?(currentFile))
            rmdir(currentFile, 10, true)
          else
            # Otherwise, if current entry is a file, then we just delete it using rm 
            rm(currentFile)
          end
        }
      end
    end
    method = :rmdir
    errorClasses = []
    begin
      retVal = execWithReattempt(method, [dir], errorClasses, noOfAttempts)
    rescue ::Net::FTPPermError => err
      # raises FTPPermError if dir is actually a file
      # raises FTPPermError if no permission to remove file
      retVal = nil
    end
    return retVal
  end

  # Provide wrapper around ftp.delete to make reattempts if necessary
  # @param [String] file the remote file to remove
  # @return [Boolean] true if file was removed, nil otherwise
  def rm(file, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Removing #{file} on FTP") unless(@muted)
    requireAbsolutePaths(file)
    method = :delete
    errorClasses = []
    begin
      retVal = execWithReattempt(method, [file], errorClasses, noOfAttempts)
    rescue ::Net::FTPPermError => err
      retVal = nil
    end
    return retVal
  end
 
  # Provide wrapper around ftp.sendcmd("MDTM [TIME] [FILENAME]") to make reattempts if necessary
  # @param [String] file the remote file to touch
  # @return [NilClass, String] the ftp filepath to the remote file touched or nil if failure
  def touch(file, noOfAttempts=10)
    retVal = nil
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Touching #{file} on FTP") unless(@muted)
    requireAbsolutePaths(file)
    method = :sendcmd
    baseDir = ""
    if(file.include?("/"))
      baseDir = file[0..file.rindex("/")]
    end
    tempDir = "#{baseDir}temp_dir_for_checking_current_time_aardvark"
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to create temp directory") unless(@muted)
    mkdir(tempDir)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Temp directory created") unless(@muted)
    modTimes = longls(baseDir)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Modification times grabbed") unless(@muted)
    remoteTimeNow = nil
    modTimes.each { |currentFile|
      if(currentFile.split()[-1] == "#{baseDir}temp_dir_for_checking_current_time_aardvark")
        remoteTimeStr = "#{currentFile.split()[5]} #{currentFile.split()[6]} #{currentFile.split()[7]}"
        remoteTimeNow = Time.parse(remoteTimeStr)
        break
      end
    }
    rmdir(tempDir)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Temp directory deleted") unless(@muted)
    timeString = remoteTimeNow.strftime("%Y%m%d%H%M00")
    command = "MDTM #{timeString} #{file}"
    errorClasses = []
    begin
      retVal = execWithReattempt(method, command, errorClasses, noOfAttempts)
    rescue ::Net::FTPPermError => err
      # raises FTPPermError if file/directory already exists
      # raises FTPPermError if no permission to create directory
      # NOTE use :directory? if you want to know if the directory already exists
      retVal = nil
    end
    return retVal
  end

  # Require absolute filepath when dealing with ftp server
  # @param [String] path - the filepath to validate as absolute or not
  # @return nil
  # @todo more stringent validation?
  def requireAbsolutePaths(paths)
    retVal = nil
    if(paths.is_a?(String))
      paths = [paths]
    end
    raise ArgumentError, "paths=#{paths.inspect} is not an array" unless(paths.is_a?(Array))
    paths.each{|path|
      if(!path.is_a?(String) or path[0..0] != "/")
        raise ArgumentError, "path=#{path.inspect} is not an absolute ftp path; please provide one."
      end
    }
    return retVal
  end

  def logError(err)
    begin 
      unless(@muted)
        $stderr.debugPuts(__FILE__, __method__, "FTP", "generic ftp error caught")
        $stderr.debugPuts(__FILE__, __method__, "FTP", err.class)
        $stderr.debugPuts(__FILE__, __method__, "FTP", err.message)
        $stderr.debugPuts(__FILE__, __method__, "FTP", "\n#{err.backtrace.join("\n")}")
      end
    rescue => err2
      $stderr.debugPuts(__FILE__, __method__, "FTP" "error occurred while logging #{err.inspect}") unless(@muted)
    end
    return nil
  end
end

class LftpError < RuntimeError; end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module Pipeline ; module FTP ; module Helpers
