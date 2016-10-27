#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/vcfParser'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class UploadEpWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for uploading entrypoints in Genboree.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
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
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @format = @settings['inputFormat']
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the application
    # [+returns+] nil
    def run()
      begin
        # Download the input file
        uriObj = URI.parse(@inputs[0])
        apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/data?", @userId)
        fileName = File.basename(@fileApiHelper.extractName(@inputs[0]))
        @origFileName = fileName.dup()
        ff = File.open(CGI.escape(fileName), 'w')
        apiCaller.get() { |chunk| ff.print(chunk) }
        ff.close()
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to download entrypoint file: #{fileName.inspect} from host: #{uriObj.host}; rsrcPath: #{apiCaller.rsrcPath}."
          $stderr.debugPuts(__FILE__, __method__, "API ERROR", "#{apiCaller.respBody.inspect}")
          raise @errUserMsg
        end
        # Now upload the eps depending on the input format provided (FASTA/3colLFF)
        uriObj = URI.parse(@outputs[0])
        exp = BRL::Genboree::Helpers::Expander.new(CGI.escape(fileName))
        exp.extract('text')
        extractedFile = exp.uncompressedFileName
        apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/eps?format=#{@format}&suppressEmail=true", @userId)
        apiCaller.put({}, File.open(extractedFile))
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to upload entrypoint file to host: #{uriObj.host}; rsrcPath: #{apiCaller.rsrcPath}."
          $stderr.debugPuts(__FILE__, __method__, "API ERROR", "#{apiCaller.respBody.inspect}")
          raise @errUserMsg
        else
          @apiMsg = apiCaller.parseRespBody['status']['msg']
        end
      rescue => err
        @err = err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @errUserMsg = err.message if(@errUserMsg.nil? or @errUserMsg.empty?)
        @exitCode = 30
      end
      return @exitCode
    end



    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "     Group: '#{@groupName}'\n"
      additionalInfo << "     Database: '#{@dbName}'\n"
      additionalInfo << "     File: '#{@origFileName}'\n"
      additionalInfo << "Your entrypoints have been uploaded. Note that if your input file was very large, it may take a few minutes for the new entrypoints to show up in the database.\n\n"
      additionalInfo << "\n\n#{@apiMsg}"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end

    def prepErrorEmail()
      additionalInfo = ""
      additionalInfo << "     Group: '#{@groupName}'\n" if(@groupName)
      additionalInfo << "     Database: '#{@dbName}'\n" if(@dbName)
      additionalInfo << "     File: '#{@origFileName}'\n" if(@origFileName)
      additionalInfo << "     Error message from upload tool:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      errorEmailObject.exitStatusCode = @exitCode
      return errorEmailObject
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::UploadEpWrapper)
end
