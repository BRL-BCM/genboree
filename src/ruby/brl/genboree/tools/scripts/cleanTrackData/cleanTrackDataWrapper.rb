#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CleanTrackDataWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES =
    {
      :description  => "This is the wrapper for cleaning all track related data in a given Genboree database for a lits of ftypeids (tracks).",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)", "Sameer Paithankar (paithank@bcm.edu)" ],
      :examples     =>
      [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        # NOTE: already have things like @jobId, @userId, @userEmail, @user*, @toolIdStr,
        #   @scratchDir, etc thanks to parseJobFile() in parent. Similarly we have
        #   @dbrcFile, and such from ToolWrapper#initialize(). DO NOT REPEAT THEM HERE!

        # Get some dbrc info for direct db work
        @dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
        @user = @dbrc.user
        @pass = @dbrc.password
        @host = @dbrc.driver.split(/:/).last

        # Get Genboree URL of datbase to work on
        @targetDb = @outputs[0]
        @ftypeHash = @settings['ftypeHash']
        @groupId = @settings['groupId']
        @refSeqId = @settings['refSeqId']
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = @errUserMsg
        @err = err
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @return [Fixnum] the exit code for this script
    def run()
      logFile = File.open("cleanTrackData.log", "w+")
      begin
        @user = @pass = nil
        @outFile = @errFile = ""
        dbUri = URI.parse(@dbApiHelper.extractPureUri(@targetDb))
        host = dbUri.host
        if(ApiCaller.addressesMatch?(host, @genbConf.machineName))
          logFile.debugPuts(__FILE__, __method__, "STATUS", "Database URL: #{@targetDb.inspect}")
          logFile.debugPuts(__FILE__, __method__, "STATUS", "OK. This database is local.")
        else
          raise "REJECTED: cannot clean track related records if database is remote."
        end
        dbName = @dbApiHelper.extractName(dbUri)
        dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, "")
        # Set new user database dbh using the URI...@dbApiHelper knows how to do this
        @dbApiHelper.dbu = dbu
        @dbApiHelper.setNewDataDb(@targetDb)
        apiCaller = WrapperApiCaller.new(host, '', @context['userId'])
        @ftypeHash.each_key { |trk|
          fTypeId = @ftypeHash[trk]
          dbu.deleteByFieldAndValue(:userDB, 'featuresort', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'featuretostyle', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'featuretolink', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'featuretocolor', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'featureurl', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'featuredisplay', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftype2attributes', 'ftype_id', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftype2attributeName', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftypeAttrDisplays', 'ftype_id', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftypeCount', 'ftypeId', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftype2gclass', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'blockLevelDataInfo', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'ftypeAccess', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'fdata2', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteByFieldAndValue(:userDB, 'zoomLevels', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
          dbu.deleteUnlockedGroupResourceWithParent(@groupId, 'track', fTypeId, 'database', @refSeqId)
          dbu.cleanFid2AttributeOrphans()
          dbu.cleanFidTextOrphans()
          apiCaller.setRsrcPath("#{dbUri.path}/trk/#{CGI.escape(trk)}/removeTrackFiles?ftypeid=#{fTypeId}")
          apiCaller.delete()
          if(!apiCaller.succeeded?)
            logFile.debugPuts(__FILE__, __method__, "ERROR", "Could not delete bin/big* files for trk: #{trk.inspect}.")
          end
        }
        logFile.debugPuts(__FILE__, __method__, "STATUS", "Cleaned up track records.")
        @exitStatus = 0
      rescue => err
        logFile.debugPuts(__FILE__, __method__, "ERROR", "Exception while trying to clean track records. Error class: #{err.class} ; Error message: #{err.message} ; Error backtrace:\n#{err.backtrace.join("\n")}\n\n")
        @errInternalMsg = @errUserMsg = err.message
        @err = err
        @exitCode = 30
      ensure
        logFile.close() rescue nil
      end
      return @exitCode
    end

    # prepSuccessEmail()
    # - Create and return instance of BRL::Genboree::Tools::WrapperEmailer
    # - make sure various fields and info are filled in with job & status info
    # - make sure to set wrapperEmailer.errMessage and possibly exitStatusCode and apiExitCode as well
    # - return configured WrapperEmailer object
    # - note: # supress email by returning nil from prepSuccessEmail()
    def prepSuccessEmail()
      return nil
    end

    # prepErrorEmail()
    # - Create instance of BRL::Genboree::Tools::WrapperEmailer
    # - be careful, error might have happened EARLY on in the process!
    # - make sure various fields and info are filled in with error info
    # - return configured WrapperEmailer object; nil if can't send email (didn't get far enough)
    # - note: supress email by returning nil from prepErrorEmail()
    def prepErrorEmail()
      return nil
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CleanTrackDataWrapper)
end
