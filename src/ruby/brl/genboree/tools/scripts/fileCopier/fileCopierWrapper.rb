#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'

module BRL; module Genboree; module Tools; module Scripts
  class FileCopierWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for the fileCopier.rb script. This tool is intended to be called via the Genboree Workbench",
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
        @targetDb = @dbApiHelper.extractPureUri(@outputs[0])
        subdir = @fileApiHelper.subdir(@outputs[0])
        if(subdir == '/')
          @targetUri = @targetDb
        else
          @targetUri = "#{@targetDb}/files#{subdir}?"
        end
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = ( @settings['deleteSourceFilesRadio'] == 'copy' ? false : true )
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
      rescue => err
        @errUserMsg = "Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n #{err}\n\nBacktrace:\n #{err.backtrace.join("\n")}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the fileCopier script
    # [+returns+] nil
    def run()
      begin
        errFile = "#{@scratchDir}/#{Time.now.to_f}.err"
        inputsArr = []
        @inputs.each { |input|
          inputsArr << CGI.escape(input)
        }
        inputsStr = inputsArr.join(',')
        cmd = "fileCopier.rb -i #{inputsStr} -o #{CGI.escape(@targetUri)} -k #{CGI.escape(@dbrcKey)} -u #{@userId} -s #{@scratchDir}"
        cmd << " -d " if(@deleteSourceFiles)
        cmd << " 2> #{errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching cmd: #{cmd.inspect}...")
        exitStatus = system(cmd)
        # Check if the sub script ran successfully
        if(!exitStatus)
          @exitCode = 25
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n #{err}\n\nBacktrace:\n #{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end


    def prepSuccessEmail()
      additionalInfo = "The following files have been successfully "
      additionalInfo << (@deleteSourceFiles == true ? "moved.\n\n" : "copied.\n\n")
      additionalInfo << "Please note that you may not be able to see the files immediately in the workbench since the data may be in the middle of being transferred over to the workbench.\n\n"
      @inputs.each { |input|
        additionalInfo << "\t#{CGI.unescape(File.basename(input.chomp("?")))}\n\n"
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end


    def prepErrorEmail()
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo=nil, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::FileCopierWrapper)
end
