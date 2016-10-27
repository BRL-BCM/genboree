#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'pathname'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
# Require toolWrapper.rb
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include BRL::Genboree::REST
# Write sub-class of BRL::Genboree::Tools::ToolWrapper
module BRL ; module Genboree; module Tools
  class WrapperEpigenomicSlice < ToolWrapper

    VERSION = "1.0"

    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run EpigenomicSlice tool, which generates matrix",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }


    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
      exitStatus = EXIT_OK
      @errMsg = ""
      cmd ="driverStressEpigenomicSlice.rb "
      @entityBuffer = ""
      @inputs.each{|ii|
        @entityBuffer << "#{CGI.escape(ii)},"
      }
     
      if(@removeNoData == "on")
        @removeNoData = "true"
      else
        @removeNoData = "false"
      end
      @entityBuffer.chomp!(",")
      cmd << " -t #{@entityBuffer}"
      cmd << " -S #{@scratch}  -A #{@aggF}  "
      cmd << " -a #{@apiDBRCkey}  -u #{@userId} -R #{@removeNoData} -o #{CGI.escape(@outputs[0])} -j #{CGI.escape(@jobId)}"
      ## Here comes the ROI
      cmd << " -r #{CGI.escape(@roiTrack)}"
      $stderr.debugPuts(__FILE__, __method__, "DRIVER COMMAND", "#{cmd}")
      system(cmd)
      if($?.exitstatus== 113)
        exitStatus = 113
        @errMsg = "Matrix couldn't be built"
      elsif($?.exitstatus == 120)
        exitStatus = 120
        @errMsg = "Some of the tracks in entityList are either removed or not accessible by user"
      elsif($?.exitstatus== 114)
        exitStatus = 114
        @errMsg = "Limma tool didn't run properly"
      elsif($?.exitstatus == 116)
        exitStatus = 116
        @errMsg = "Compression failed"
      elsif($?.exitstatus == 0)
        $stderr.debugPuts(__FILE__, __method__, "Done", "Driver completed")
        #uploadData
        if($?.exitstatus == 118)
          @exitCode = exitStatus
          exitStatus = 118
          @errMsg = "Upload failes"
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Wrapper completed with #{exitStatus}")
      return exitStatus
    end

     # . Upload files. should be a interface method. Will put it in parent class soon
     def uploadUsingAPI(jobName,fileName,filePath)
      @exitCode = 0
      restPath = @outPath
      path = restPath +"/file/EpigenomeSlice/#{CGI.escape(jobName)}/#{fileName}/data"
      path << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      @apicaller.setRsrcPath(path)
      infile = File.open("#{filePath}","r")
      @apicaller.put(infile)
      if @apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Upload file", "#{fileName} done")
        @exitCode = 0
      else
        @errMsg = "Failed to upload the file #{fileName}"
        $stderr.debugPuts(__FILE__, __method__, "Upload Failure", @apicaller.parseRespBody())
        @exitCode = @apicaller.apiStatusObj['statusCode']
      end
      return @exitCode
    end

    def uploadData
      exitStatus = 0
      @apicaller = WrapperApiCaller.new(@outHost,"",@userId)
      restPath = @outPath
      uploadUsingAPI(@analysis,"matrix.xls.gz","#{@scratch}/matrix/matrix.xls.gz")
      if($?.exitstatus != 0)
        exitStatus = 118
      end
     return exitStatus
    end

    # . Prepare successmail
    def prepSuccessEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode

      return emailObject
    end

    # . Prepare Failure mail
    def prepErrorEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def processJobConf()
      @inputs       = @jobConf['inputs']
      @outputs      = @jobConf['outputs']
      @roiTrack     = @jobConf['settings']['roiTrack']
      @span         = @jobConf['settings']['spanAggFunction']
      @analysis     = @jobConf['settings']['analysisName']
      @aggF         = @jobConf['settings']['spanAggFunction']
      @removeNoData = @jobConf['settings']['removeNoDataRegions']
      @gbConfig     = @jobConf['context']['gbConfFile']
      @userEmail    = @jobConf['context']['userEmail']
      @adminEmail   = @jobConf['context']['gbAdminEmail']
      @firstName    = @jobConf['context']['userFirstName']
      @lastName     = @jobConf['context']['userLastName']
      @scratch      = @jobConf['context']['scratchDir']
      @apiDBRCkey   = @jobConf["context"]["apiDbrcKey"]
      @jobId        = @jobConf["context"]["jobId"]
      @userId       = @jobConf["context"]["userId"]

      @analysisNameEsc = CGI.escape(@analysis)

      ##Retreiving group and database information from the input trkSet
      @grph 	    = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfig)
      @dbhelper     = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfig)
      @trkhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfig)
      dbrc 	    = BRL::DB::DBRC.new(nil, @apiDBRCkey)
      @pass 	    = dbrc.password
      @user 	    = dbrc.user

      ## Output database information to upload the heatmap in file area
      uri         = URI.parse(@outputs[0])
      @outHost    = uri.host
      @outPath    = uri.path

       case @jobConf["settings"]["resolution"]
			when "high"
				@resolution = 1000
			when "medium"
				@resolution = 10000
			when "low"
				@resolution = 100000
			else
				@resolution = 10000
                        end

      return EXIT_OK
    end
  end
end ; end; end; # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
puts __FILE__
if($0 and File.exist?($0) )
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::WrapperEpigenomicSlice)
end
