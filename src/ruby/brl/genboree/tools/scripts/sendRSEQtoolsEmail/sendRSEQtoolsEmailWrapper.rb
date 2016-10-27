#!/usr/bin/env ruby
#########################################################
############ Send RSEQtools Batch Job Completion Email #################
## This wrapper sends a job completion email after individual
# RSEQtools jobs are completed for each sample in a batch submission
# of long RNA-seq samples.
#########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class SendRSeqToolsEmailWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for sending an email to the user on completion of individual 'RSEQtools' jobs.
                        This tool is intended to be called internally by the RSEQtools batch processing tool wrapper.",
      :authors      => [ "Sai Lakshmi Subramanian(sailakss@bcm.edu)" ],
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
        
        ## Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
  
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. \n"
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
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])

        ## Get the tool version from toolConf
        @toolVersion = @toolConf.getSetting('info', 'version')
        @settings['toolVersion'] = @toolVersion
        
        $stderr.debugPuts(__FILE__, __method__, "INPUTS", "#{@inputs.inspect}")
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Send RSEQtools Batch Processing Completion Email tool failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Send RSEQtools Batch Processing Completion Email tool." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

############ END of methods specific to this RSEQtools wrapper

    def prepSuccessEmail()      
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      #inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = nil
      #outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = nil
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "All the samples from the RSEQtools batch submission have been processed and the results were uploaded to your Genboree Database.\n" +
                        "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----RSEQtools\n\n" +
                        "==================================================================\n"
      additionalInfo << "The status of your RSEQtools jobs is summarized below:\n" 
                              
      # get the status of the job to display in the email
      apiCaller = WrapperApiCaller.new(@host, "/REST/v1/job/{jobId}?detailed=summary", @userId)
      @inputs.each { |jobId|
        apiCaller.get( { "jobId" => jobId})
        $stderr.debugPuts(__FILE__, __method__, "RESP", "#{apiCaller.parseRespBody.inspect}")
        status = apiCaller.parseRespBody['data']['status']
        additionalInfo << "Job ID: #{jobId} - #{status}\n"
      }
      additionalInfo << "==================================================================\n"
      additionalInfo << "\nIf there are any jobs with \'failed\' status in the list above,\nplease look at the email from the job to identify the cause of failure.\n\n"
      #projHost = URI.parse(@projectUri).host
      #emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@projectUri))}"
      emailObject.additionalInfo = additionalInfo
      return emailObject
    end

    def prepErrorEmail()
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errUserMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::SendRSeqToolsEmailWrapper)
end

