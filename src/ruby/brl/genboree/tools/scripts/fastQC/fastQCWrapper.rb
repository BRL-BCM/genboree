#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'find'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/sites/redmine'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/wrapperApiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class FastQCWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'fastQC' tool.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # output files created by tool
    FASTQC_OUT_DIR = "sample_fastqc"
    FASTQC_OUT_ARCHIVE = "#{FASTQC_OUT_DIR}.zip"

    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
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
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @casava = @settings['casava']
        # Get the number of available threads from the toolConf
        @num_threads = @toolConf.getSetting('cluster', 'ppn')

        # Find db and redminePrj from @outputs
        dbUri = redminePrjUri = nil
        if(@outputs[0] =~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          dbUri = @outputs[0]
          redminePrjUri = @outputs[1]
        else
          redminePrjUri = @outputs[0]
          dbUri = @outputs[1]
        end

        @dbName = @dbApiHelper.extractName(dbUri)
        @targetUri = URI.parse(dbUri)
        @fullDbUri = dbUri
        @redminePrjUri = redminePrjUri
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
        command = ""
        @user = @pass = nil
        @outFile = @errFile = ""
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
        @outFile = "./fastQC.out"
        @errFile = "./fastQC.err"
        @tmpDir = "fastQC_#{Time.now.to_f}_#{rand(10_000)}"
        `mkdir #{@tmpDir}`
        
        # Download input files from user database
        downloadFiles()
        
        # Prepare fastQC command to run the tool
        begin
          # produces directory sample_fastqc and its archive sample_fastqc.zip in the @tmpDir
          # we upload all output files placed in the output directory @tmpDir to the @outputs Redmine project
          command = "fastqc -t #{@num_threads} -o #{@tmpDir}"
          command << " --casava " if(@casava)
          @inputFiles.each { |file|
            command << " #{file} "
          }
          command << " > #{@outFile} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          exitStatus = system(command)
          if(!exitStatus)
            @errUserMsg = "FastQC failed to run."
            raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
          end
        rescue => err
          @err = err
          # Try to read the out file first:
          @errUserMsg = ""
          outStream = ""
          outStream << File.read(@outFile) if(File.exists?(@outFile))
          # If out file is not there or empty, read the err file
          if(!outStream.empty?)
            @errUserMsg << outStream
          else
            errStream = ""
            errStream = File.read(@errFile) if(File.exists?(@errFile))
            @errUserMsg << errStream if(!errStream.empty?)
          end
          raise @errUserMsg
        end

        # Transfer files to output target database
        transferFiles()

        # Upload FastQC result files to the Genboree project associated with the
        #   job's output Redmine project
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new("", "", @userId)
        @redminePrjApiHelper.apiCaller = @prjApiHelper.apiCaller = apiCaller
        redmineUriObj = @redminePrjApiHelper.getRedminePrjUrl(@redminePrjUri)
        unless(redmineUriObj[:success])
          raise "Cannot retrieve underlying Redmine project url from the Redmine project registered with Genboree at #{@redminePrjUri.inspect}: #{redmineUriObj[:msg]}"
        end
        @redmineUri = redmineUriObj[:obj] # @todo use in mapLinkToLabel
        @jobWikiUrl = @redminePrjApiHelper.getWikiUrlByPrjUrl(@redminePrjUri, @jobId)

        # Upload FastQC outputs to Redmine
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading tool output to Redmine project rawcontent area")
        rawContentDir = @redminePrjApiHelper.class.getJobRawContentDir(@context["toolIdStr"], @jobId)
        localToRemoteMap = @redminePrjApiHelper.uploadRawContentDir(@tmpDir, rawContentDir, @redminePrjUri)
        
        # Identify HTML tool outputs, their URLs at Redmine, and create suitable labels for those URLs
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieving Redmine rawcontent URL")
        linkToLabel = mapLinkToLabel(@redminePrjApiHelper, @redminePrjUri, localToRemoteMap)

        # Prepare textile for Redmine project Wiki for this job
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing wiki content")
        textileStr = writeDefaultTextileReports(linkToLabel)

        # Upload Redmine wiki textile content for this job
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading table of contents wiki for this job")
        @redminePrjApiHelper.putJobWiki(@redminePrjUri, @context["toolIdStr"], @jobId, textileStr)
       
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done...")
      rescue ::BRL::Genboree::REST::Helpers::RedminePrjApiError => err
        @errUserMsg = err.message
        @errInternalMsg = @errUserMsg
        @exitCode = 31
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
        @errUserMsg = "ERROR: FastQC failed (#{err.message.inspect})." if(@errUserMsg.nil? or @errUserMsg.empty?)
        @errInternalMsg = "ERROR: Unexpected error trying to run FastQC." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

    # Transfer output files to the user db
    def transferFiles()
      # Grab target URI by parsing output
      targetUri = URI.parse(@outputs[0])

      rsrcPath = "#{targetUri.path}/file/FastQC/{analysisName}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # :analysisName => @analysisName
      Dir.entries(@tmpDir).each { |file|
        next if(file == '.' or file == '..')
        # upload the zip files - this zip file has the .html file with all plots
        if(file =~ /\.zip/)
          uploadFile(targetUri.host, rsrcPath, @userId, "#{@tmpDir}/#{file}", {:analysisName => @analysisName, :outputFile => "#{@tmpDir}/#{file}"})
        end
        
        if(File.directory?("#{@tmpDir}/#{file}"))
          #next if(file =~ /\.zip/)
          # Required because if there are multiple files with the same base name, the tool creates one output dir
          Dir.entries("#{@tmpDir}/#{file}").each { |txt| 
            if(txt =~ /\.txt/)
              uploadFile(targetUri.host, rsrcPath, @userId, "#{@tmpDir}/#{file}/#{txt}", {:analysisName => @analysisName, :outputFile => "#{@tmpDir}/#{file}/#{txt}"})
            end
          }
        end
      }
    end

    # Upload a given file to Genboree server
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
    end

    # Download input files from user database
    def downloadFiles()
      @inputFiles = []
      @inputs.each { |input|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
        inputUri = URI.parse(input)
        if(inputUri.scheme =~ /file/)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input File #{input} is already available in the local shared scratch space.")
          tmpFile = inputUri.path
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Path of local input file #{tmpFile}")
        else       
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
          fileBase = @fileApiHelper.extractName(input)
          fileBaseName = File.basename(fileBase)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
          if(!retVal)
            @errUserMsg = "Failed to download file: #{fileBase} from server"
            raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
        end
        
        ## Extract the file if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()

        # Sniffer - To check FASTQ format
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        @inFile = exp.uncompressedFileName
        # Check if file is non-empty
        if(File.zero?(@inFile))
          @errUserMsg = "Input file #{@inFile} is empty. Please upload non-empty file and try again."
          raise @errUserMsg
        end
        #Detect if file is in FASTQ format
        sniffer.filePath = @inFile
        unless(sniffer.detect?("fastq"))
          @errUserMsg = "Input file #{@inFile} is not in FASTQ format. Please check the file format."
          raise @errUserMsg
        else
          @inputFiles << @inFile
        end
      }
    end

    # @interface
    def prepSuccessEmail()
      rv = nil
      unless(@suppressEmail)
        folderUrl = @dbApiHelper.getFileUrl(@fullDbUri, "FastQC", @analysisName)
        folderLocationStr = formatFileUrlLocation(folderUrl, nil, true)
        redmineLocationStr = formatRedmineLocation(@jobWikiUrl, @redmineUri)
        emailObj = getEmailerConfTemplate()
        emailObj.additionalInfo = folderLocationStr + "\n" + redmineLocationStr
        emailObj.analysisName = @analysisName
        rv = emailObj
      end
      return rv
    end

    # @interface
    def prepErrorEmail()
      additionalInfo = "     Error message from FastQC:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, @analysisName, inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        return nil
      else
        return errorEmailObject
      end
    end

    # Label reports based on their parent directory
    # @param [BRL::Genboree::REST::Helpers::RedminePrjApiHelper] redmineApiHelper with initialized @apiCaller
    # @param [String] redminePrjUri the URL to the Redmine project
    # @param [String] localToRemoteMap mapping of this tools outputs to their Redmine project counterparts
    # @return [Hash] linkToLabel map of Redmine project file to a label for it
    # @todo redmineApiHelper cache true Redmine (not Genboree version) of url?
    def mapLinkToLabel(redmineApiHelper, redminePrjUri, localToRemoteMap)
      localPaths = localToRemoteMap.keys
      fastqcReportPaths = getLocalReportPaths(localPaths)
      pathToLabel = labelReports(fastqcReportPaths)
      linkToLabel = {}
      pathToLabel.each_key { |path|
        label = pathToLabel[path]
        remotePath = localToRemoteMap[path]
        link = redmineApiHelper.getRedmineRawContentUrl(redminePrjUri, remotePath)
        linkToLabel[link] = label
      }
      return linkToLabel
    end

    # Get HTML index files for each input FASTQ file
    # @see labelReports
    def getLocalReportPaths(localPaths)
      rv = []
      localPaths.each { |localPath|
        if(File.basename(localPath) == "fastqc_report.html")
          rv.push(localPath)
        end
      }
      return rv
    end
    
    # FastQC creates a directory for each input FASTQ file and places the associated HTML report
    #   within it, use the directory name as a label for each FastQC report link
    # @param [Array<String>] localReportPaths @see getLocalReportPaths
    # @return [Hash<String, String>] mapping of local report path to a label
    def labelReports(localReportPaths)
      rv = {}
      localReportPaths.each { |localPath|
        pathTokens = localPath.split(File::SEPARATOR)
        perFastqDir = pathTokens[-2] # parent directory of fastqc_report.html
        rv[localPath] = "Link to #{perFastqDir} report"
      }
      return rv
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::FastQCWrapper)
end
