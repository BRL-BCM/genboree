#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'pathname'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'

include BRL::Genboree::REST

module BRL ; module Genboree; module Tools

  class ChromHMMBinarizeSignalWrapper < ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run ChromHMM BinarizeSignal tool",
      :authors      => [ "Tim Charnecki (charneck@bcm.edu) and Neethu Shah (neethus@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # Set variables and set up the job
    def processJobConf()
      begin
        # Context vars
        @adminEmail         = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']

        # BinarizeSignal specific settings
        # Settings from the UI
        @analysisName       = @settings['analysisName']
        @pseudoCountControl = @settings['pseudoCountControl']
        @flankWidth         = @settings['flankWidth']
        @foldThresh         = @settings['foldThresh']
        @poissonThresh      = @settings['poissonThresh']
        @strictThresh       = @settings['strictThresh']
       

        ##Checking db and proj irrespective of their order
        if(@outputs.first !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          prjDb = @outputs.first
          outputDb = @outputs.last
        else
          outputDb = @outputs.first
          prjDb = @outputs.last
        end
        
        @targetUri = outputDb
        @targetGroupName = @grpApiHelper.extractName(outputDb)
        @targetDbName = @dbApiHelper.extractName(outputDb)
        
        # If inputs are local - called in from another wrapper
        @inputLocal = @settings['inputLocal'] if(@settings.key?('inputLocal'))
        @suppressEmail  = @settings['suppressEmail'] if(@settings.key?('suppressEmail'))     
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        exitStatus = EXIT_OK
        @errMsg = ""
        #@outputDir = CGI.escape(@analysisName)
        @outputBinaryDir = "#{@scratchDir}/binarizedData" 
        @inputSignalDir = File.expand_path("#{@scratchDir}/inputSignalDir/")
        #@outputBinaryDir = File.expand_path(@outputBinaryDir)
        system("mkdir -p #{@inputSignalDir}")
        system("mkdir -p #{@outputBinaryDir}")

        # make dir for control data
        if(@inputs.size == 2)
          @inputControlDir = File.expand_path("#{@scratchDir}/inputControlFiles")
          system("mkdir -p #{@inputControlDir}")
        end

        # Download data
        # The first input resource is always the signal dir and the second is control.
        # Rules helper takes in input without order and replaces @inputs accordingly after
        # checking for the required strings "_signal" and "_controlsignal" for the respective files.
        # The wrapper gets the input in order.
        if(@inputLocal)
          @inputSignalDir = @inputs.first
          @inputControlDir = @inputs.last if(@inputs.size ==2)
        else
          downloadFiles(@inputs.first, @inputSignalDir)
          downloadFiles(@inputs.last, @inputControlDir) if(@inputs.size == 2)
        end
        # Build the command
        # BinarizeSignal [-c controldir][-f foldthresh][-p poissonthresh]
        # [-strictthresh][-u pseudocountcontrol][-w flankdwidth] signaldir outputdir
        @outFile = "./chromHMMBinarizeSignal.out"
        @errFile = "./chromHMMBinarizeSignal.err"
        command = "ChromHMM BinarizeSignal" 
        # Optional params
        command << " -c #{@inputControlDir} " if(@inputs.size == 2)
        command << " -f #{@foldThresh} " 
        command << " -p #{@poissonThresh} " 
        command << " -strictthresh " if(@strictThresh)
        command << " -u #{@pseudoCountControl} "
        command << " -w #{@flankWidth} " if(@inputs.size == 2)
        # Required params
        command << " #{@inputSignalDir} "
        command << " #{@outputBinaryDir} "

        # Run the command
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "ChromHMM - BinarizeSignal failed to run"
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
        end
        uploadData()
      rescue => err
        @errMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
        @exitCode = exitStatus
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Wrapper completed with #{@exitCode}")
      return @exitCode 
    end

    def downloadFiles(filesUri, dest)
      # Input should be a folder
      @inputFiles = @fileApiHelper.expandFileContainers(filesUri, @userId)
      # download files 
      @inputFiles.each { |fileUri|
        uriObj = URI.parse(fileUri)
        fileName = File.basename(uriObj.path.chomp('?'))
        rsrcPath = "#{uriObj.path.chomp('?')}/data"
        apiCallerSrc = WrapperApiCaller.new(uriObj.host, rsrcPath, @userId)
        fullFileName = "#{dest}/#{fileName}"
        File.open(fullFileName, 'wb') { |file|
          apiCallerSrc.get() { |chunk|
            file.write(chunk)
          }
        }
        if(apiCallerSrc.succeeded?) 
          $stderr.debugPuts(__FILE__, __method__, "Status", "Downloading #{rsrcPath}")
        else
         @errMsg = "Apicaller failed to download file with a response:\n\n#{apiCallerSrc.respBody}\n\n"
         raise "ERROR: Apicaller failed to download file #{fileName}\n, with the response:\n\n#{apiCallerSrc.respBody}\n"
        end
      }
    end

    def uploadData()
      retVal = nil
      # Compress ChromHMM results tree
      @archiveName = "binarizedData.zip"
      Dir.chdir(@scratchDir)
      zipCmd = "zip -9 -r #{@archiveName} binarizedData/* > zip.out"
      $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Zip ChromHMM results dir with this command:\n    #{zipCmd}")
      system(zipCmd)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload results zip to target Genboree database...")
      # Get just path part to database
      rcscNew = @dbApiHelper.extractPath(@targetUri)
      rcscNew << "/file/ChromHMM%20-%20BinarizeSignal%20-%20Results/#{@analysisName}/binarizedData.zip/data?extract=true"
      apiCaller = WrapperApiCaller.new(@dbApiHelper.extractHost(@targetUri), rcscNew, @userId)
      #@archiveUrl = apiCaller.fillApiUriTemplate({ :file => File.basename(@archiveName) })
      fileObj = File.open("#{@archiveName}")
      apiCaller.put(fileObj)
      fileObj.close unless(fileObj.closed?)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Api Call put() of results zip replied with:\n\n#{apiCaller.respBody}\n\n")
     
      if(apiCaller.succeeded?)
        retVal = EXIT_OK
      else
        @errMsg = "Apicaller Failed.\n Failed to upload data to the target database."
        raise "ERROR: could not upload Zip archive of results to output database. Tried to upload #{File.basename(@archiveName) unless(fileObj.nil?)} using this resource path: #{rcscNew.inspect}."
      end
      # Clean up intermediate files. Keep it if the inputs are being called from another wrapper.
      # The wrapper (might) use these results files .
      unless(@inputLocal)
        `rm -rf #{@inputSignalDir}`
        `rm -rf #{@inputControlDir}`
      end
      return retVal
    end

    # . Prepare successmail
    def prepSuccessEmail
      if(@suppressEmail)
        emailObject = nil
      else
        emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
        emailObject.userFirst     = @userFirstName
        emailObject.userLast      = @userLastName
        emailObject.analysisName  = @analysisName
        unless(@inputLocal)
          inputsText                = buildSectionEmailSummary(@inputs)
          emailObject.inputsText    = inputsText
        end
        outputsText               = buildSectionEmailSummary(@outputs)
        emailObject.outputsText   = outputsText
        emailObject.settings      = @jobConf['settings']
        emailObject.exitStatusCode = @exitCode
      end
      return emailObject
    end

    # . Prepare Failure mail
    def prepErrorEmail
      if(@suppressEmail)
        emailObject = nil
      else
        emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
        emailObject.userFirst     = @userFirstName
        emailObject.userLast      = @userLastName
        emailObject.analysisName  = @analysisName
        unless(@inputLocal)
          inputsText                = buildSectionEmailSummary(@inputs)
          emailObject.inputsText    = inputsText
        end
        outputsText               = buildSectionEmailSummary(@outputs)
        emailObject.outputsText   = outputsText
        #emailObject.settings      = @jobConf['settings']
        emailObject.errMessage    = @errMsg
        emailObject.exitStatusCode = @exitCode
      end
      return emailObject
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::ChromHMMBinarizeSignalWrapper)
end
