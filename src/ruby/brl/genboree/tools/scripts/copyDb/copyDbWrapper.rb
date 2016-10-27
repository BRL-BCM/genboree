#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class PostProcessFiles < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used copying/cloning all contents of a database to a new database.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
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
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        # We will need the mysql user and pass to create mysqldump files
        host = URI.parse(ApiCaller.applyDomainAliases(@outputs[0])).host
        dbrc = BRL::DB::DBRC.new(dbrcFile, "DB:#{host}")
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "dbrc.user: #{dbrc.user.inspect}")
        @user = dbrc.user
        @pass = dbrc.password
        @host = URI.parse(ApiCaller.applyDomainAliases(@targetUri)).host
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Set up format options coming from the UI
        @newName = @settings['newName']
        @shallowCopy = @settings['shallowCopy']
        @shallowCopy = ((@shallowCopy and @shallowCopy.strip =~ /^(?:on)|(?:yes)|(?:true)$/i) ? true : false)
        @srcDatabaseName = @settings['srcDatabaseName']
        @tgtDatabaseName = @settings['tgtDatabaseName']
        @srcRefSeqId = @settings['srcRefSeqId']
        @tgtRefSeqId = @settings['tgtRefSeqId']
        @srcGroupId = @settings['srcGroupId']
        @tgtGroupId = @settings['tgtGroupId']
        @tgtRefseqName = @settings['tgtRefseqName']
        @srcRefseqName = @settings['srcRefseqName']
        @mysqlHost = @settings['mysqlHost']
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@inputs[0])
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # First create a dump file from the source db
        mysqldumpCmd = "mysqldump -h #{@mysqlHost} -u #{@user} --password=#{@pass} #{@srcDatabaseName} > #{@tgtDatabaseName}.sql 2> mysqldump.err "
        `#{mysqldumpCmd}`
        if($?.dup.exitstatus != 0)
          raise "Could not generate mysql dump file from source database. Check mysqldump.err for more information."
        end
        # Next, use the dump file to add the sql into the target db
        mysqlAddCmd = "mysql -h #{@mysqlHost} -u #{@user} --password=#{@pass} #{@tgtDatabaseName} < #{@tgtDatabaseName}.sql 2> mysqladd.err"
        `#{mysqlAddCmd}`
        if($?.dup.exitstatus != 0)
          raise "Could not add mysqldump file to target database. Check mysqladd.err for more information."
        end
        unless(@shallowCopy) # Softlinks were used on the server to the seq and bin files
          # Copy over the seq and bin files (To-do: Implement API support to get and put bin and seq files)
          # - This could be done 2x faster with scp and then a chown/chmod command via ssh
          `rsync -avz #{@host}:/usr/local/brl/data/genboree/ridSequences/#{@srcRefSeqId} . > rsync_src.out 2> rsync_src.err`
          `rsync -avz  #{@srcRefSeqId}/ #{@host}:/usr/local/brl/data/genboree/ridSequences/#{@tgtRefSeqId} > rsync_tgt.out 2> rsync_tgt.err`
        end
        # Copy over the files from the workbench files area
        `mkdir workbenchFiles`
        cmd = "rsync -avz #{@host}:/usr/local/brl/data/genboree/files/grp/#{@srcGroupId}/db/#{@srcRefSeqId}/ workbenchFiles/ > rsync_wbFiles_src.out 2> rsync_wbFiles_src.err"
        $stderr.debugPuts(__FILE__, __method__, "CMD", "#{cmd}")        
        `#{cmd}`
        `rsync -avz workbenchFiles/ #{@host}:/usr/local/brl/data/genboree/files/grp/#{@tgtGroupId}/db/#{@tgtRefSeqId}/ > rsync_wbFiles_tgt.out 2> rsync_wbFiles_tgt.err`
        # Change RID_SEQUENCE_DIR value in fmeta since it will point to the src db
        dbu = BRL::Genboree::DBUtil.new("DB:#{URI.parse(@outputs[0]).host}", nil, nil)
        dbu.setNewDataDb(@tgtDatabaseName)
        dbu.updateFmetaEntry('RID_SEQUENCE_DIR', "/usr/local/brl/data/genboree/ridSequences/#{@tgtRefSeqId}")
        `rm -f #{@tgtDatabaseName}.sql`
        `rm -rf #{@srcRefSeqId} workbenchFiles`
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end


    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "New database: #{@tgtRefseqName} has been cloned using source database: #{@srcRefseqName} under group: #{@groupName}"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::PostProcessFiles)
end
