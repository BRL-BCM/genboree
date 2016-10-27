require 'brl/genboree/storageHelpers/abstractStorageHelper'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/util/expander'
require 'brl/genboree/helpers/sniffer'

module BRL ; module Genboree ; module StorageHelpers
  class LocalStorageHelper < AbstractStorageHelper

    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement

    # Variables for building paths to user's files (group name and database name) and file base generated from group / db
    attr_accessor :groupName, :dbName, :fileBase
     
    # Variable for using FileManagement's writeFile method
    attr_accessor :filesDir

    # Variable that keeps track of which storageID is associated with the current instance of this helper
    attr_accessor :storageID

    # Array which keeps track of which types of sniffing we allow (via sniffer or expander)
    SNIFFER_FORMATS = ["sniffer", "expander"]

    # muted keeps track of whether we want to mute debug statements or not (set to false by default) 
    attr_accessor :muted

    # Initialize localStorageHelper - dbrcHost and dbrcKey not necessary for local files
    def initialize(groupName, dbName, userId, muted=false)
      super()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Group name is #{groupName} ; dbName is #{dbName} ; userId is: #{userId} ; muted is #{muted}") unless(@muted)
      # Set groupName and dbName according to parameters given in constructor
      @groupName = groupName
      @dbName = dbName
      # @userId is used for submitting a local file processor job when uploading large files (via FileManagement)
      @userId = userId
      @filesDir = nil
      # Set base for all files by running buildFileBase() method
      @fileBase = buildFileBase()
      # Set @filesDir
      @filesDir = setFilesDir()
      @storageID = nil
      @muted = muted
    end

    # Method to check whether a local file exists
    # @param [String] filePath path to file on disk
    # @return [Boolean] boolean that tells us whether local file exists (or nil if method fails)
    def exists?(filePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking whether local file #{filePath} exists") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty?)
        retVal = File.exist?(filePath)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local file #{filePath} exists: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to check modification time of local file
    # @param [String] filePath path to file on disk
    # @return [Time] modification time of local file (or nil if method fails)
    def mtime(filePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking modification time of local file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty? or !File.exist?(filePath))
        retVal = File.mtime(filePath)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Modification time of local file #{filePath}: #{retVal}") unless(@muted)
      return retVal
    end

    # Method to retrieve file type for local file using expander
    # @param [String] filePath path to file on disk
    # @param [String] snifferFormats parameter which indicates which sniffer formats we want to use (expander or sniffer)
    # @return [String] type of file as identified by expander or sniffer (or nil if method fails)
    def getFileType(filePath, snifferFormats="expander")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting file type (using the #{snifferFormats} formats) of local file #{filePath}") unless(@muted)
      unless(SNIFFER_FORMATS.include?(snifferFormats))
        raise "You have entered an invalid value for the snifferFormats parameter. Please enter one of the values in this array: #{SNIFFER_FORMATS.inspect}"
      end
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      fileType = nil
      unless(filePath.empty? or !File.exist?(filePath))
        # If we are using the expander convention for file types, then we will grab the fileType using expander's getFileType() method 
        if(snifferFormats == "expander")
          exp = BRL::Util::Expander.new(filePath)
          begin
            fileType = exp.getFileType()
          rescue => err
            fileType = 'Unknown'
          end
        # Otherwise, if we are using the sniffer's set of formats (larger), then we will grab the fileType using the sniffer
        elsif(snifferFormats == "sniffer")
          sniffer = BRL::Genboree::Helpers::Sniffer.new()
          sniffer.filePath = filePath
          fileType = sniffer.autoDetect
          fileType = 'Unknown' unless(fileType)
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File type of local file #{filePath} (using #{snifferFormats} formats): #{fileType}") unless(@muted)
      return fileType
    end

    # Method to retrieve file size for local file
    # @param [String] filePath path to file on disk 
    # @return [Fixnum] Size of file (or nil if method fails)
    def getFileSize(filePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking file size of local file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty? or !File.exist?(filePath))
        retVal = File.size(filePath)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of local file #{filePath}: #{retVal}") unless(@muted)
      return retVal
    end
    
    # Method to retrieve mime type for local file
    # @param [String] filePath path to file on disk 
    # @return [String, NilClass] Mime Type of file. Nil Otherwise 
    def getMimeType(filePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking mime type of local file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      #retVal = "application/octet-stream"
      sniffer = BRL::Genboree::Helpers::Sniffer.new()
      sniffer.filePath = filePath
      return sniffer.mimeType()
    end
  
    # Method to write file (here, locally)
    # @param [String] fileName path to where the file will eventually be deposited (in non-escaped form - path will eventually be escaped)
    # @param [String] fileContent path to where uploaded file is originally located (some random string of numbers in the thin temp area)
    # @param [Boolean] allowOverwrite determines whether we can overwrite file or not
    # @param [Boolean] extract determines whether we extract file after moving
    # @param [Boolean] processIndexFile determines whether we process index file 
    # @param [Array] fileUpdateArray An array with required variables to update the temp update status of a file once it has been copied to the 'real' location
    # @param [Boolean] suppressEmail determines whether we suppress e-mail to user for processFile job
    # @return [nil]
    def uploadFile(fileName, fileContent, allowOverwrite=false, extract=false, processIndexFile=false, fileUpdateArray=[], suppressEmail=false)
      setFilesDir()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Moving file #{fileContent} to new path #{fileName} either via localFileProcessor job or via direct move") unless(@muted)
      if(fileName !~ /\/$/) # Not a folder
        # Used in FileManagement mixin
        @fileName = fileName
        @suppressEmail = suppressEmail
        @localFileStorageHelperUpload = true
        writeFile(fileName, fileContent, allowOverwrite, extract, processIndexFile, fileUpdateArray)
      else
        `mkdir -p #{@fileBase}/#{File.makeSafePath(fileName)}`
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "localFileProcessor has completed its part with respect to moving #{fileContent} to #{fileName} - either a localFileProcessor job has been submitted, or the file has been directly moved") unless(@muted)
      return
    end

    # Method to download file (not used for localStorageHelper since the file is ALREADY local - no nee to download it!)
    # @param [String] fileName file name
    def downloadFile(fileName)
      raise "Since the file is local, you don't need to download it!"
    end

    # Method to delete file (from disk)
    # @param [String] filePath file path to local file
    # @return [Boolean] boolean that tells us whether remove file call succeeded or failed
    def deleteFile(filePath)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting local file #{filePath}") unless(@muted)
      # Create full file path (with base directory / group / database)
      filePath = getFullFilePath(filePath)
      retVal = nil
      unless(filePath.empty? or !File.exist?(filePath))
        unless(File.directory?(filePath)) # Not a folder (file)
          retVal = File.delete(filePath) rescue false
        else # Folder
          retVal = FileUtils.remove_dir(filePath) rescue false
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Local file #{filePath} successfully deleted: #{retVal}") unless(@muted)
      return retVal
    end

    # Method which will check the disk space used by the user's Genboree Database
    # @return [Fixnum] number of bytes being used by the user's Genboree Database
    def checkDiskSpaceForDb()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking disk space used by Genboree Database associated with current localStorageHelper instance") unless(@muted)
      # We will use du -sb to check the total number of bytes taken up by the Genboree Database directory on disk
      totalDiskSpace = `du -sb #{@fileBase}/`.split("\s")[0].to_i
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Disk space used by Genboree Database associated with current localStorageHelper instance is: #{totalDiskSpace}") unless(@muted)
      return totalDiskSpace
    end

    # Method which will check the disk space used by the user's Genboree Group
    # @return [Fixnum] number of bytes being used by the user's Genboree Group
    def checkDiskSpaceForGroup()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking disk space used by Genboree Group associated with current localStorageHelper instance") unless(@muted)
      # We will use du -sb to check the total number of bytes taken up by the Genboree Group directory on disk
      # Note that we use File.dirname twice to transform the path from Database (.../grp/[some number]/db/[some number]) to Group (.../grp/[some number])
      totalDiskSpace = `du -sb #{File.dirname(File.dirname(@fileBase))}/`.split("\s")[0].to_i
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Disk space used by Genboree Group associated with current localStorageHelper instance is: #{totalDiskSpace}") unless(@muted)
      return totalDiskSpace
    end

    # Method to open remote connection - since this is the local storage helper (and not remote), this method does nothing
    # @return [nil]
    def openRemoteConnection()
      return
    end

    # Method to close remote connection - since this is the local storage helper (and not remote), this method does nothing
    # @return [nil]
    def closeRemoteConnection()
      return
    end
 
    ### HELPER METHODS ###

    # Method to build file base for local files (group / refSeqID)
    # @return [String] file base (includes group / database)
    def buildFileBase()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Building Genboree file base for current user") unless(@muted)
      retVal = ""
      # Get the base dir for the file
      groupRecs = @dbu.selectGroupByName(@groupName)
      groupId = groupRecs.first['groupId']
      refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, groupId)
      retVal = Abstraction::DatabaseFiles.buildFileBase(groupId, refseqRecs.first['refSeqId'], false, @genbConf)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Genboree file base for current user: #{retVal}") unless(@muted)
      return retVal
    end
  
    # Helper method which sets @filesDir (for FileManagement)
    # @return [Dir] Dir object for files dir 
    def setFilesDir()
      fileDir = buildFileBase()
      FileUtils.mkdir_p(fileDir)
      return Dir.new(fileDir)
    end

    # Method to get file path for grabbing files locally (group/refseqID/file name)
    # @param [String] fileName file name
    # @return [String] full file path (includes group / database / file name)
    def getFullFilePath(fileName)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting full file path for #{fileName}") unless(@muted)
      retVal = ""
      # Make path to file
      safeFileName = File.makeSafePath(fileName)
      if(safeFileName and !safeFileName.empty?)
        retVal = "#{@fileBase}/#{safeFileName}"
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Full file path for #{fileName} is: #{retVal}") unless(@muted)
      return retVal
    end

    # Note that renameFile method is inherited from FileManagement mixin (so we don't need to override that method here)

  end # class LocalStorageHelper < AbstractStorageHelper
end ; end ; end #module BRL ; module Genboree ; module StorageHelpers
