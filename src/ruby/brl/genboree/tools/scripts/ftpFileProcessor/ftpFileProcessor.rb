#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/expander'
require 'brl/util/emailer'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class FtpFileProcessor < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for uploading files to an FTP server via the web server. The script runs as part of a 'local cluster' job and moves the uploaded file from the nginx tmp area to the final target area (on the FTP server). Also computes SHA1 of the uploaded file and sets some of the attributes required to 'expose' the file.",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting tool specific settings...")
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @dbName = @settings['dbName']
        @fileId = @settings['fileId']
        @gbUploadId = @settings['gbUploadId']
        @remoteFilePath = @settings['remoteFilePath']
        @source = @settings['source']
        @gbUploadFalseValueId = @settings['gbUploadFalseValueId']
        @gbPartialEntityId = @settings['gbPartialEntityId']
        @groupName = @settings['groupName']
        @refseqName = @settings['refseqName']
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "ERROR: #{@errUserMsg}.\nTrace:\n#{@errBacktrace}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Create dbu object for storage helper
        gc = BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
        dbu.setNewDataDb(@dbName)
        # Create storage helper (should be FTP - if not, we'll raise an error)
        storageHelper = createStorageHelperFromTopRec(@remoteFilePath, @groupName, @refseqName, @userId, dbu)
        # Do some checking to make sure that file size of source file is not still 0 (because of nginx bug).
        # We do allow the job to finish eventually - in that case, the file size is probably actually 0!
        maxIterations = 10
        currentIteration = 0
        fileSizeOfSource = File.size(@source)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of source file #{@source} is #{File.size(@source)} (before any sleeping is done).")   
        while(currentIteration < maxIterations and fileSizeOfSource == 0)
          fileSizeOfSource = File.size(@source)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File size of source file #{@source} is #{File.size(@source)} (on sleep iteration #{currentIteration+1}).")
          sleep(2)
          currentIteration += 1
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Final file size of source file #{@source} is #{File.size(@source)} (after any sleeping is done).")
        # Upload file to FTP server using storage helper
        storageHelper.uploadFile(@remoteFilePath, File.open(@source, 'r'), [@dbName, @fileId, @gbUploadId, @gbUploadFalseValId, @gbPartialEntityId, @rackEnv])
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done.")
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      ensure
        # We want to make sure that we delete the source file after we're done uploading it (or if an error occurs, we still want to delete it!)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Our job finished (either success or failure), so let's delete the source file #{@source}.")     
        `rm -f #{Shellwords.escape(@source)}`
      end
      return @exitCode
    end

    # Send success email
    # [+returns+] emailObj or nil
    def prepSuccessEmail()
      return nil
    end

    # Send failure/error email
    # [+returns+] emailObj or nil
    def prepErrorEmail()
      return nil
    end

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
      topFolderRecs = dbu.selectFileByDigest(topFolderPath)
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
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error! File was found to be local, even though this job was launched from the ftpStorageHelper's uploadFile method. Shouldn't happen!")
        errMsg = "Error! File was found to be local, even though this job\n was launched from the ftpStorageHelper's uploadFile method.\nShouldn't happen!"
        raise errMsg
      end
      return storageHelper
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::FtpFileProcessor)
end
