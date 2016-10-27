require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'uri'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/storageHelpers/ftpStorageHelper'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CreateRemoteStorageAreaJobHelper < WorkbenchJobHelper

    TOOL_ID = 'createRemoteStorageArea'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def runInProcess()
      success = true
      # Create new @dbu object
      @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
      # Grab requested remote area name
      remoteStorageAreaName = @workbenchJobObj.settings['remoteStorageAreaName'].strip
      remoteStorageType = @workbenchJobObj.settings['remoteStorageType']
      # Set up output host / rsrcPath
      output = @workbenchJobObj.outputs[0]
      uri = URI.parse(output)
      host = uri.host
      rsrcPath = uri.path
      # Grab @groupName and @dbName for setting up @dbu
      @groupName = CGI.unescape(rsrcPath.split("/")[-3])
      @dbName = CGI.unescape(rsrcPath.split("/")[-1])
      # Find formal mysql database name associated with group / db above and then set @dbu to use that database
      databaseName =  @dbu.selectRefseqByNameAndGroupName(@dbName, @groupName)[0]["databaseName"]
      @dbu.setNewDataDb(databaseName)
      # Insert the appropriate remoteStorageConf in the user's 'remoteStorageConfs' mysql table (if it's not already in there)
      remoteStorageConfs = JSON.parse(File.read(@genbConf.gbRemoteStorageConfs))
      conf = remoteStorageConfs[remoteStorageType]
      alreadyExists = false
      allRemoteConfs = @dbu.selectAllRemoteStorageConfs()
      allRemoteConfs.each { |individualConf|
        details = individualConf["conf"]
        alreadyExists = true if(details == conf)
      }
      @dbu.insertRemoteStorageConf(conf) unless(alreadyExists)
      # Grab important info from conf 
      conf = JSON.parse(conf)
      dbrcHost = conf["dbrcHost"]
      dbrcPrefix = conf["dbrcPrefix"]
      # Now, we want to grab the ID associated with the conf we just inserted
      currentID = nil
      # Grab all remote confs in user's database. One of the entries will match the dbrcHost / dbrcPrefix grabbed above (since we just inserted our conf)
      # Save the ID associated with that conf in currentID
      allRemoteConfs = @dbu.selectAllRemoteStorageConfs()
      allRemoteConfs.each { |individualConf|
        details = JSON.parse(individualConf["conf"]) 
        if(details["dbrcHost"] == dbrcHost and details["dbrcPrefix"] == dbrcPrefix)
          currentID = individualConf["id"]
        end
      }
      # Insert entry for remote storage area into files table
      @dbu.insertFile("#{remoteStorageAreaName}/", "#{remoteStorageAreaName}/", nil, 0, 0, Time.now(), Time.now(), @userId, currentID)
      # Create remote storage area on remote server through storage helper
      if(conf["storageType"] == "FTP")
        storageHelper = BRL::Genboree::StorageHelpers::FtpStorageHelper.new(dbrcHost, dbrcPrefix, conf["baseDir"], currentID, @groupName, @dbName)
        begin
          storageHelper.uploadFile("#{remoteStorageAreaName}/", nil)
        ensure
          storageHelper.closeRemoteConnection()
        end
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
