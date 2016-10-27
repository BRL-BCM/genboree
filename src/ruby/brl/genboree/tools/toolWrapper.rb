#!/usr/bin/env ruby

require 'uri'
require 'shellwords'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/script/scriptDriver'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/rest/helpers/sampleSetApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/kbApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'brl/genboree/rest/helpers/fileEntityListApiUriHelper'
require 'brl/genboree/rest/helpers/redminePrjApiUriHelper'

######################################################################
# ToolWrapper - Abstract Parent class for Genboree Tool Job Wrapper scripts.
#
# - Tool wrapper scripts should inherit from this class, and implement the interface methods
# - Core functionality provided by the parent class, BRL::Script::ScriptDriver
# - Will parse command line args, read & parse job file, send appropriate emails
# - Email sending uses BRL::Genboree::Tools::WrapperEmailer
######################################################################
# INTERFACE:
# ------------------------------------------------------------------
# Sub-classes MUST implement the following interface, which
# the inherited methods will use:
#
#   Constants:
#     VERSION           - String containing version number.
#     COMMAND_LINE_ARGS - Hash mapping "--longName" style argument name to
#                         an Array of:
#                         (0) the type of argument (REQUIRED_ARGUMENT, OPTIONAL_ARGUMENT, NO_ARGUMENT)
#                         (1) the short one-character argument
#                         (2) a meaningful sentence describing what the argument is for
#                         Note: --help and --verbose are already provided. --help will do the right thing.
#     DESC_AND_EXAMPLES - A hash with 2 specific keys:
#                         :description - Text describing what the program is for. Will be output in help.
#                         :examples - Array of strings, each showing an example of using the script. Will be output in the help.
#   Methods:
#     processJobConf() - Extract the info you need from @jobConf hash, typically to instance variables
#                        . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
#                        . Command-line args will already be parsed and checked for missing required values
#                        . Do not send email, that will be done automatically from @err* variables
#                        . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
#                          - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
#                          - ToolWrapper will automatically log @errInternalMsg to stderr.
#     run() - No-arg method that causes driver to run application.
#             . MUST return a numerical exitCode (0-126). Program will exit with that code. 0 means success.
#             . MUST provide the "-C" argument to any child ToolWrapper-inheriting sub-processes
#             . MAY set @keepPatterns or @removeFiles to keep files matching given patterns around and to specifically remove unneeded (e.g. inputs) files
#               regardless of tool success/failure; patterns operate on the basename of the file
#               that are launched to support correct automatic cleanUp() behavior (leaving cleanUp to ancestor)
#             . Command-line args will already be parsed and checked for missing required values
#             . @optsHash contains the command-line args
#             . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
#               - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
#               - ToolWrapper will automatically log @errInternalMsg to stderr.
#    prepSuccessEmail() - Must return a WrapperEmail object to send a "success" email.
#                         . Fill in the required and optional fields so a sensible email can be constructed.
#    prepErrorEmail() - Must return a WrapperEmail object to send a "success" email.
#                       . Fill in the required and optional fields so a sensible email can be constructed.
# ------------------------------------------------------------------
# "MAIN" section
# ------------------------------------------------------------------
# The only other piece that is required is the usual "MAIN" section at the end our
# your script. It will [ALWAYS] look like this:
#
#    if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
#      # Argument to main() is your specific class:
#      BRL::Script::main(BRL::Script::ScriptDriver)
#    end
########################################################################
module BRL ; module Genboree ; module Tools
  class ToolWrapper < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - generally empty, since -j or --inputFile required by default
    COMMAND_LINE_ARGS = { }
    # INTERFACE: Provide general program description and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description  => "This is the parent tool wrapper script class. Tool wrappers should inherit from this.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # attr_accessors to store the 4 sections from the job file
    attr_accessor :inputs, :outputs, :context, :settings
    # @return [Array<String>] list of local files that can be removed by cleanUp
    attr_accessor :removeFiles
    # Errors
    #attr_accessor :errUserMsg, :errInternalMsg, :errBacktrace
    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS
    # ------------------------------------------------------------------
    # processJobConf()
    #  . code to extract needed information from the @jobConf Hash, typically to instance variables
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . Do not send email, that will be done automatically from @err* variables
    #  . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
    #    - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
    #    - ToolWrapper will automatically log @errInternalMsg to stderr.
    def processJobConf()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # run()
    #  . code run the tool, examine exit code(s) and outputs, prep suitable user messages
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    #  . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
    #    - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
    #    - ToolWrapper will automatically log @errInternalMsg to stderr.
    def run()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # prepSuccessEmail()
    # - Create and return instance of BRL::Genboree::Tools::WrapperEmailer
    # - make sure various fields and info are filled in with job & status info
    # - make sure to set wrapperEmailer.errMessage and possibly exitStatusCode and apiExitCode as well
    # - return configured WrapperEmailer object
    # - note: # supress email by returning nil from prepSuccessEmail()
    def prepSuccessEmail()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # Fill in as much email information as can be gleaned from the jobConf
    # Devs must fill additionalInfo and resultFileLocations
    # @return [BRL::Genboree::Tools::WrapperEmailer] emailer with some variables filled in
    def getEmailerConfTemplate()
      emailObj = WrapperEmailer.new(@toolTitle, @userEmail, @jobId)
      emailObj.userFirst = @userFirstName
      emailObj.userLast = @userLastName
      emailObj.inputsText = buildSectionEmailSummary(@inputs)
      emailObj.outputsText = buildSectionEmailSummary(@outputs)
      emailObj.settings = @settings
      # emailObj.analysisName is in the settings if it is set
      # emailObj.additionalInfo = {set this}
      # emailObj.resultFileLocations = {set this}
      return emailObj
    end

    # prepErrorEmail()
    # - Create instance of BRL::Genboree::Tools::WrapperEmailer
    # - be careful, error might have happened EARLY on in the process!
    # - make sure various fields and info are filled in with error info
    # - return configured WrapperEmailer object; nil if can't send email (didn't get far enough)
    # - note: supress email by returning nil from prepErrorEmail()
    def prepErrorEmail()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # ------------------------------------------------------------------
    # PROTECTED CONSTANTS AND METHODS
    # - used by this ToolWrapper class to provide standard functionality
    # - do not override
    # - see also what BRL::Script::ScriptDriver provides to this class
    # ------------------------------------------------------------------
    # Convenience constant for sub-classes to use when building USAGE_INFO
    JOB_FILE_ARGS = {
      "--inputFile" =>  [ :REQUIRED_ARGUMENT, "-j", "Path to the tool Job File, in json format." ],
      "--noClean" => [ :NO_ARGUMENT, "-C", "Flag to skip cleanUp after run" ]
    }

    # Some pre-defined exit codes - 12-15 are used in CommandsRunner
    EXIT_BAD_JOB_FILE = 11
    EXIT_NO_JOB_STATUS = 12
    EXIT_GENERAL_JOB_FAILURE = 13
    EXIT_EXCEPTION_RAISED_FOR_COMMANDSRUNNER = 14
    EXIT_CANCELLED_JOB = 15

    # The path to the job file
    attr_accessor :jobFile
    # The parsed Job Configuration (Hash form JSON in jobFile)
    attr_accessor :jobConf
    # Path to a suitable .dbrc file to use, if needed
    attr_accessor :dbrcFile
    # GenboreeConfig instance, already loaded, if needed
    attr_accessor :genbConf
    # @return [Fixnum] Total core count (as requested by Genboree)
    attr_accessor :numCores
    # @return [Fixnum] Total nodes count (as requested by Genboree)
    attr_accessor :numNodes
    # For storing exit code as different methods called
    attr_accessor :exitCode
    # attr_accessors for toolIdStr, toolTitle and toolShortTitle
    attr_accessor :toolIdStr, :toolTitle, :toolShortTitle
    # @return [BRL::Genboree::Tools::ToolConf] the tool conf object for the current tool involved (i.e. for {#toolIdStr})
    attr_accessor :toolConf
    # to suppressEmail when tools are called internally by other tool wrappers
    # default value is false - email is sent by all tools called from workbench
    attr_accessor :suppressEmail


    # ------------------------------------------------------------------
    # PROTECTED CONSTRUCTOR
    # ------------------------------------------------------------------
    # new() - Constructor
    # - If subclass overrides, first call super(optsHash) at the beginning
    def initialize()
      super()
      @commandLineArgInfo.merge!(self.class::JOB_FILE_ARGS)
      @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
      @dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      @dbrcKey = @genbConf.dbrcKey
      @suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
      @jobFile = @jobConf = nil
      #@errUserMsg = @errInternalMsg = @errBacktrace = nil
      # Initialize all API Uri Helpers
      @grpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
      @prjApiHelper = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new()
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      @trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
      @classApiHelper = BRL::Genboree::REST::Helpers::ClassApiUriHelper.new()
      @fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      @kbApiHelper = BRL::Genboree::REST::Helpers::KbApiUriHelper.new()
      @sampleApiHelper = BRL::Genboree::REST::Helpers::SampleApiUriHelper.new()
      @sampleSetApiHelper = BRL::Genboree::REST::Helpers::SampleSetApiUriHelper.new()
      @trkListApiHelper = BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper.new()
      @fileListApiHelper = BRL::Genboree::REST::Helpers::FileEntityListApiUriHelper.new()
      @redminePrjApiHelper = BRL::Genboree::REST::Helpers::RedminePrjApiUriHelper.new()
      # Get num available cores
      envNumCores = ENV["GB_NUM_CORES"]
      if(envNumCores and envNumCores =~ /^\d+$/)
        @numCores = envNumCores.to_i
      else
        @numCores = 1
      end
      envNumNodes = ENV["GB_NUM_NODES"]
      if(envNumNodes and envNumNodes =~ /^\d+$/)
        @numNodes = envNumNodes.to_i
      else
        @numNodes = 1
      end
      # clean up variables defaults
      @maxUncompBytes = 1*1024*1024
      @maxCompBytes = 100*1024*1024
      @maxJobBytes = 300*1024*1024
    end

    # buildSectionEmailSummary()
    # -use @inputs or @outputs (array)
    # -ex. buildSectionEmailSummary(@inputs) or buildSectionEmailSummary(@outputs)
    # -returns hash which should be provided in inputsText or outputTexts
    def buildSectionEmailSummary(section)
      returnHash = {}
      ##Only display 10 input items as max
      countDisplay = 1
      resrH = BRL::Genboree::REST::Helpers::ApiUriHelper.new(@gbConfig)
      section.each { |file|
        fileUri = URI.parse(file)
        returnHash["#{countDisplay}. #{resrH.extractType(file).capitalize}"] = File.basename(fileUri.path)
         # We want to display on 9 files and keep record if there are more than 9,
         # which would be shown by "...."
         if(countDisplay == 9 and section.size > 9)
           returnHash["99"] = "....."
           break
         end
         countDisplay += 1
         }
      return returnHash
    end

    # Represent a URL as a hierarchical string showing where in the Genboree Workbench the
    #   file in the url can be found
    # @param [String] fileUrl a Genboree Workbench file url
    # @param [String, NilClass] header a header for the location string, if nil a generic one will be used
    #   and the location string will NOT contain the name of the specific file (caller should be telling
    #   the user what the file is)
    # @param [Boolean] folder if true, fileUrl is a URL to a Genboree file folder
    # @return [String] a neatly formatted string explaining where the file at fileUrl can be found
    def formatFileUrlLocation(fileUrl, header=nil, folder=false)
      self.class.formatFileUrlLocation(fileUrl, {:header => header, :folder => folder, :grpApiHelper => @grpApiHelper, :dbApiHelper => @dbApiHelper, :fileApiHelper => @fileApiHelper})
    end

    # @see formatFileUrlLocation
    def self.formatFileUrlLocation(fileUrl, opts={:header => nil, :folder => false, :grpApiHelper => nil, :dbApiHelper => nil, :fileApiHelper => nil})
      retVal = ""
      if(!opts[:grpApiHelper].is_a?(BRL::Genboree::REST::Helpers::GroupApiUriHelper) or 
         !opts[:dbApiHelper].is_a?(BRL::Genboree::REST::Helpers::DatabaseApiUriHelper) or 
         !opts[:fileApiHelper].is_a?(BRL::Genboree::REST::Helpers::FileApiUriHelper))
        raise ArgumentError.new("Please provide the correct helpers as named arguments for :grpApiHelper, :dbApiHelper, and :fileApiHelper; :grpApiHelper is a #{opts[:grpApiHelper].class}, :dbApiHelper is a #{opts[:dbApiHelper].class}, and :fileApiHelper is a #{opts[:fileApiHelper].class}")
      end
      prefixChar = "|"
      depthChar = "-"
      nilHeader = opts[:header].nil? ? true : false
      opts[:header] = "You can download result files from this location:\n" if(nilHeader)
      opts[:header] << "\n" unless(opts[:header][-1..-1] == "\n")
      groupName = opts[:grpApiHelper].extractName(fileUrl)
      dbName = opts[:dbApiHelper].extractName(fileUrl)
      filePath = opts[:fileApiHelper].extractName(fileUrl)

      fileTokens = CGI.unescape(filePath).split("/")
      folderTokens = []
      (fileTokens.size > 1) ? fileTokens[0...-1] : []
      if(fileTokens.size > 1)
        if(opts[:folder])
          # then provided fileUrl is to a file folder, include all path elements in location report
          folderTokens = fileTokens
        else
          # then provided fileUrl is to a file, exclude last path element (file name) in location report
          folderTokens = fileTokens[0...-1]
        end
      end
      folderDepth = 4 # folders start at 4
      folderString = ""
      folderTokens.each { |folder|
        folderString += "#{prefixChar}#{depthChar * folderDepth}#{folder}\n"
        folderDepth += 1
      }
      fileString = "#{prefixChar}#{depthChar * folderDepth}#{fileTokens[-1]}"
      fileString = nilHeader ? folderString : (folderString + fileString)
      retVal << opts[:header] +
                "|-Group: '#{groupName}'\n" +
                "|--Database: '#{dbName}'\n" +
                "|---Files\n" +
                fileString
                "\n"
      return retVal
    end

    # For tool wrappers using Redmine projects, provide details for emails about how to access
    #   files uploaded to the Redmine project
    # @param [String] gbWikiUrl to the wiki page for this job
    # @param [String] redmineUrl to the configured Redmine at the time of this job run
    def formatRedmineLocation(gbWikiUrl, redmineUrl)
      self.class.formatRedmineLocation(gbWikiUrl, redmineUrl, {:redminePrjApiHelper => @redminePrjApiHelper})
    end
    def self.formatRedmineLocation(gbWikiUrl, redmineUrl, opts={})
      if(!opts[:redminePrjApiHelper].is_a?(BRL::Genboree::REST::Helpers::RedminePrjApiUriHelper))
        raise ArgumentError.new("Please provide the correct helpers as named arguments for :redminePrjApiHelper; :redminePrjApiHelper is a #{opts[:redminePrjApiHelper].class}")
      end
      redminePrjId = opts[:redminePrjApiHelper].extractName(gbWikiUrl)
      wikiUrl = opts[:redminePrjApiHelper].getRawWikiUrl(gbWikiUrl, redmineUrl)
      rv = "This tool produces HTML reports for you to view and visualize the results of the run. You may access these reports in the Genboree Workbench by clicking the Redmine Project #{redminePrjId} and then clicking the \"Link to Job Output\" in the Details panel. Or, you may use this link directly #{wikiUrl} ."
      return rv
    end

    # Tool "wrappers" often have the task of running some command/tool that they "wrap". In the 
    #   event the wrapped command fails, this function provides the near-universally desired behavior of:
    #   (1) uploading the redirected error stream to Genboree
    #   (2) reporting the Genboree location of that error stream file
    # @param [String] errPath the local file containing redirected tool stderr to upload
    # @param [String] fileUrl the location to upload the file to
    # @param [Hash] opts additional named parameters
    #   [Fixnum] :nLines the number of lines to include from the error file in the email message
    # @return [String] an "additionalInfo" string that can be used for the emailer object
    # @note @grpApiHelper, @dbApiHelper, @fileApiHelper, and @userId must be set
    def reportToolError(errPath, fileUrl, opts={})
      retVal = ""
      defaultOpts = {
        :nLines => 10
      }
      opts = defaultOpts.merge(opts)

      # format the email message
      header = nil
      if(opts[:nLines] > 0)
        # then read the last nLines from stderr and include them in the "additionalInfo"
        stderrLines = ""
        cmd = "tail -n #{opts[:nLines]} #{errPath}"
        stderrLines = `#{cmd}` # `cmd` gives stdout of tail, which gives the stderr from the tool
        header = "The stderr from the tool reports:\n#{stderrLines}\nThe remaining stderr may be found on the Genboree Workbench at:\n"
      else
        header = "The stderr from the tool may be found on the Genboree Workbench at:\n"
      end
      retVal = formatFileUrlLocation(fileUrl, header)

      # upload the stderr file the email message mentions
      uriObj = URI.parse("#{fileUrl}/data")
      success = @fileApiHelper.uploadFile(uriObj.host, uriObj.path, @userId, errPath)
      unless(success)
        retVal = "Unfortunately, we could not upload the stderr from the tool to #{fileUrl.inspect}, please try running the tool again."
      end

      return retVal
    end

    # --------------------------------------------------
    # Redmine Project functions - {{
    # --------------------------------------------------

    # Get the filepath of the HTML output produced by some tools, see fastQC for an example
    def getReportPaths(*args)
      raise NotImplementedError.new()
    end

    # Prepare a default textile string that can be used for Redmine wiki text for tool reports
    # @param [String] rawContentLink a full URL to a Redmine rawcontent page that is the
    #   index.html file generated by the tool
    # @todo instance variables used here are typically setup by copy-paste processJobConf()
    def writeDefaultTextileReport(rawContentLink)
      avps = {
        :toolId => @context["toolIdStr"],
        :jobId => @jobId,
        :analysisName => @analysisName,
        :user => @userLogin,
        :rawContentLink => rawContentLink
      }
      textileStr = @redminePrjApiHelper.class.writeTextileToc(avps)
    end

    # Prepare default textile string for Redmine wiki with multiple HTML report links 
    #   (alternative to writeDefaultTextileReport's single link)
    # @param [Hash<String, String>] map of hyperlink to its display label
    # @see writeDefaultTextileReport
    def writeDefaultTextileReports(linkToLabel)
      avps = {
        :toolId => @context["toolIdStr"],
        :jobId => @jobId,
        :analysisName => @analysisName,
        :user => @userLogin
      }
      textileStr = @redminePrjApiHelper.class.writeTextileTocWithLinks(avps, linkToLabel)
    end

    # }} -

    # parseJobFile()
    # - Reads and parses the JSON job file
    def parseJobFile()
      begin
        @jobFile = File.expand_path(@optsHash['--inputFile'])
        @jobConf = JSON.parse(File.read(@jobFile))
        @inputs = @jobConf['inputs']
        @outputs = @jobConf['outputs']
        @settings = @jobConf['settings']
        @context = @jobConf['context']
        # Get some key context fields
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName'].to_s
        @userLastName = @context['userLastName'].to_s
        @userId = @context['userId']
        @userLogin = @context['userLogin']
        @jobId = @context['jobId']
        @toolIdStr = @context['toolIdStr']
        # Set the toolTitle and the toolShortTitle
        @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
        @toolTitle = @toolConf.getSetting('ui', 'label')
        @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
        @shortToolTitle = @toolTitle if(@shortToolTitle == "[NOT SET]")

        # If JSON job file explicitly sets this value to true, which is done
        # when a tool is called internally by another tool wrapper, email is not sent
        # Default: false, since email should be sent by all tools
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)

      rescue Exception => err
        BRL::Script::displayError("ERROR: could not parse the Job File provided (#{@jobFile.inspect}).", err, true)
        @exitCode = EXIT_BAD_JOB_FILE
      end
      return @exitCode
    end

    # Drive the wrapper. This involves:
    # - parse command line args
    # - notice standard problems with command line args
    # - process the job file
    # - run script, noticing any problems
    # - return suitable exit code
    def drive()
      begin
        # Run application if parse args succeeds; else parseArgs() will complain about any issues it finds.
        @optsHash = parseArgs()
        # Can we run? Not just asking for Help info and we have arguments hash available?
        if(@exitCode == EXIT_OK and @optsHash.is_a?(Hash))
          # Parse job file
          @exitCode = parseJobFile()
          if(@exitCode == EXIT_OK)
            # Process job config
            @exitCode = processJobConf()
            if(@exitCode == EXIT_OK)
              # Run wrapper
              begin
                $stderr.puts ""
                @exitCode = run()
                $stderr.puts ""
              rescue => runErr
                # An exception was raised in the Wrapper subclass and not caught. No @exitCode, etc.
                @exitCode = EXIT_UNHANDLED_ERROR
                @err = runErr
                @errInternalMsg = @errUserMsg = "FATAL: an unexpected error prevented the script from completing. (Error type: #{@err.class}, #{@err.message.inspect})."
              end
              if(@exitCode != EXIT_OK) # then something went wrong
                if((@exitCode <= EXIT_LAST_RESERVED or @exitCode > 126) and @exitCode != EXIT_UNHANDLED_ERROR)
                  err = RuntimeError.new("ERROR: Script author is using reserved exit code and not following directions.")
                else
                  handleError()
                end
              else # YAY. seemed to run fine
                if(!@suppressEmail)
                  wrapperEmailer = prepSuccessEmail()
                end
                wrapperEmailer.sendSuccessEmail() if(wrapperEmailer) # Can suppress email by returning nil from prepSuccessEmail()
              end
              cleanUp() unless(@optsHash.key?("--noClean"))
            else # processJobConf() error
              handleError()
            end
          else # parseJobFile() error
            handleError()
          end
        end
      rescue Exception => err # Very nasty error. Don't even try well-behaved info collection.
        BRL::Script::displayError("FATAL: an unexpected error prevented the script from completing.", err, true)
        @exitCode = EXIT_UNEXPECTED_ERROR
      end
      return @exitCode
    end

    # Remove local files when a tool is finished running, keep others, and compress some large to-be-kept files
    # @param [Array<Regexp>] keepPatterns regexps where file basenames of files in a subdirectory of the job's
    #   scratch directory that match any of the patterns will NOT be deleted
    # @param [Array<String>] removeFiles which files specifically should be removed,
    #   typically at least the local download of @inputs, given as absolute filepaths or
    #   relative filepaths to the @scratchDir
    # @param [String] scratchDir the directory to remove files from typically /scratch/{jobId}
    # @param [Integer] exitCode if ==0 then aggressive cleanup (dont need files if success)
    # @param [Fixnum] maxBytes largest file size before compression, default 10MB
    # @return [Hash]
    #   :removed [Array<String>] filepaths relative to scratchDir that were removed
    #   :compressed [Hash<String, String>] map of uncompress filepath to newly compressed filepath
    #   :failed [Hash<String, String>] map of uncompress filepath to error message
    #   :kept [Array<String>] files that matched keepPatterns
    # @note keepPatterns has precedence over removeFiles
    # @todo rename maxCompBytes -- files in range maxUncompBytes...maxCompBytes will be compressed
    # @todo how much does this assume maxUncompBytes < maxCompBytes < maxJobBytes?
    def cleanUp(keepPatterns=@keepPatterns, removeFiles=@removeFiles, scratchDir=@scratchDir, exitCode=@exitCode, maxUncompBytes=@maxUncompBytes, maxCompBytes=@maxCompBytes, maxJobBytes=@maxJobBytes)
      # we will only ever remove files in the subtree of /scratch/{jobId}
      raise ArgumentError.new("Scratch directory must be prefixed by /scratch/{jobId} or /cluster.shared.scratch/clusterUser/{jobId}") unless(scratchDir =~ /^\/scratch\/\S+(?:$|\/)/ or scratchDir =~ /^\/cluster\.shared\.scratch\/clusterUser\/\S+(?:$|\/)/)
      keepPatterns ||= []
      removeFiles ||= []
      # normalize removeFiles to paths
      removeFiles.map! { |filepath|
        unless(filepath.index(scratchDir))
          # then filepath is relative to scratchDir
          File.join(scratchDir, filepath)
        else
          # then filepath is already absolute and contains scratchDir
          filepath
        end
      }
      retVal = { :kept => [], :removed => [], :compressed => {}, :failed => {} }

      # @todo does this need to be parameterized?
      maxCoreSize = 53687091200 # 50 * 1024 ** 3 = 50 GiB
      # like @keepPatterns@ but also will not be compressed but instead will be truncated to maxCoreSize
      corePatterns = [/.+?\.out$/, /.+?\.log$/, /.+?\.err$/, /.+?\.error$/, /[jJ]obFile\.json/]

      # enumerate the current files in the scratchDir subtree
      jobFiles = []
      Find.find(scratchDir) { |path|
        if(File.symlink?(path))
          Find.prune()
        else
          unless(File.directory?(path))
            jobFiles << path
          end
        end
      }
      jobFiles.delete(scratchDir)

      # note the core job files to exempt them from removal, compression, but possibly schedule them
      #   for truncation
      coreFilesHash = {}
      jobFiles.each { |path|
        if(anyMatch?(corePatterns, path))
          coreFilesHash[path] = nil
        end
      }

      # exempt core files from removal even if requested via removeFiles
      removeFiles -= coreFilesHash.keys

      if(exitCode == 0)
        # if job success, we can remove all but log files and explicitly kept files
        prevRemoveFiles = {}
        removeFiles.each {|file| prevRemoveFiles[file] = nil }
        jobFiles.each { |path|
          if(!coreFilesHash.key?(path) and !prevRemoveFiles.key?(path))
            removeFiles << path
          end
        }
      end # else job failure, keep everything except the files we are specifically told to remove

      # note which files we are keeping
      retVal[:kept] = coreFilesHash.keys()
      # keepPatterns has priority over removeFiles
      retVal[:kept] += subsetByPatterns!(keepPatterns, removeFiles) 

      # --------------------------------------------------
      # Removal step -{{
      # --------------------------------------------------
      # remove scheduled files and schedule directories for removal
      removeDirs = []
      removeFiles.each { |removeFile|
        if(File.exists?(removeFile))
          # ensure that any files that are removed are in the scratchDir tree
          raise ArgumentError.new("Files to be removed must be prefixed by /scratch/{jobId} or /cluster.shared.scratch/clusterUser/{jobId}") unless(removeFile =~ /^#{Regexp.escape(scratchDir)}/)
          if(!File.directory?(removeFile))
            File.delete(removeFile)
            if(File.exists?(removeFile))
              retVal[:failed][removeFile] = "Call to File.delete(removeFile) did not remove the file!"
            else
              retVal[:removed] << removeFile
            end
          else
            # then file is a directory
            removeDirs << removeFile
          end
        end
      }

      # remove scheduled directories
      removeDirs.delete(scratchDir) # dont remove scratchDir
      removeDirs.sort! {|xx, yy| yy.length <=> xx.length } # largest directory names first
      removeDirs.each { |removeDir|
        if(File.exists?(removeDir))
          raise ArgumentError.new("Files to be removed must be prefixed by /scratch/{jobId} or /cluster.shared.scratch/clusterUser/{jobId}") unless(removeDir =~ /^#{Regexp.escape(scratchDir)}/)
          begin
            Dir.rmdir(removeDir)
            retVal[:removed] << removeDir
          rescue SystemCallError => err
            retVal[:failed][removeDir] = "Call to Dir.rmdir(removeDir) failed: #{err.message}"
          end
        end
      }
      # }}-

      # --------------------------------------------------
      # Compression step -{{
      # --------------------------------------------------
      # truncate core files if needed
      coreFilesHash.each_key { |path|
        trunc = truncateFile(path, maxCoreSize)
        if(trunc)
          retVal[:compressed][path] = path
        end
      }

      # compress large files that remain
      compressPaths = []
      Find.find(scratchDir) { |path|
        if(File.symlink?(path))
          Find.prune
        else
          if(!File.directory?(path) and !coreFilesHash.key?(path))
            compressPaths << path
          end
        end
      }
      compHash = compressFilesByLimits(compressPaths, maxUncompBytes, maxCompBytes, maxJobBytes)
      retVal.merge!(compHash)
      # }}-

      # report results
      $stderr.puts("-" * 20 + " CLEANUP REPORT FOR #{scratchDir}" + "-" * 20)
      $stderr.debugPuts(__FILE__, __method__, "CLEANUP-REPORT", "Based on the keepPatterns and core job files we have kept the following files:")
      $stderr.puts(retVal[:kept])
      $stderr.puts("\n")
      $stderr.debugPuts(__FILE__, __method__, "CLEANUP-REPORT", "Based on removeFiles and the success/failure of the job we removed:")
      $stderr.puts(retVal[:removed])
      $stderr.puts("\n")
      $stderr.debugPuts(__FILE__, __method__, "CLEANUP-REPORT", "We have compressed some of the remaining files (uncompressed_filepath => compressed_filepath):")
      retVal[:compressed].each_key { |uncompPath|
        compPath = retVal[:compressed][uncompPath]
        $stderr.puts("#{uncompPath} => #{compPath}")
      }
      $stderr.puts("\n")
      $stderr.debugPuts(__FILE__, __method__, "CLEANUP-REPORT", "Some files we have failed to remove or compress (filepath => reason_for_failure):")
      retVal[:failed].each_key { |path|
        failureStr = retVal[:failed][path]
        $stderr.puts("#{path} => #{failureStr}")
      }
      $stderr.puts("-" * 20 + " CLEANUP REPORT FOR #{scratchDir}" + "-" * 20)

      return retVal
    end

    # @todo move these functions to a mixin -- {{
    # Return true if @str@ matches any Regexp in @patterns@
    def anyMatch?(patterns, str)
      rv = false
      patterns = patterns.select{ |xx| xx.is_a?(Regexp) }
      patterns.each { |pattern|
        if(pattern.match(str))
          rv = true
          break
        end
      }
      return rv
    end

    # Helper to cleanUp
    # @param [Array<Regexp>] keepPatterns list of patterns defining which elements should be removed from removeFiles
    # @param [Array<String>] removeFiles list of strings that may be matched by keepPatterns
    #   some which may be deleted from original object
    # @return [Array<String>] subset of removeFiles that are to be kept
    # @todo use anyMatch? instead
    def subsetByPatterns!(keepPatterns, removeFiles)
      keptFiles = []
      keepPatterns.delete_if { |keepPattern| !keepPattern.is_a?(Regexp) }
      removeFiles.delete_if { |removeFile|
        keepMatch = nil
        keepPatterns.each { |pattern|
          keepMatch = pattern.match(removeFile)
          break if(keepMatch)
        }
        keptFiles << removeFile if(keepMatch)
        keepMatch
      }
      return keptFiles
    end

    # Helper to cleanUp: compress a file in its current directory with some protection
    #   against file name collisions and against compressing a compressed file
    # @param [String] path the filepath to compress
    # @return [NilClass, String] nil if failure, otherwise the compressed path
    #   errors are written to stderr
    def compressFileSafe(path)
      rv = nil

      # suppress verbose Expander stderr
      prevStderr = $stderr
      $stderr = File.open("/dev/null", "w")
      exp = BRL::Util::Expander.new(path)
      $stderr.close
      $stderr = prevStderr

      isCompressed = false
      begin
        isCompressed = exp.isCompressed?(path)
      rescue IOError, ArgumentError => err
        isCompressed = nil
      end
      if(isCompressed)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Refusing to compress an already compressed file #{path.inspect}")
      elsif(isCompressed.nil?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to check if file #{path.inspect} is compressed or not, refusing to compress it")
      else
        # try to assign a unique name to target compressed file
        compressedPath = "#{path}.gz"
        ii = 0
        n_reattempts = 5
        while(File.exists?(compressedPath) and ii < n_reattempts)
          uniqStr = compressedPath.generateUniqueString.xorDigest(6)
          compressedPath = "#{path}.#{uniqStr}.gz"
          ii += 1
        end
  
        if(File.exists?(compressedPath))
          # then we could not come up with a unique name
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not come up with a safe compression name for #{path.inspect}; after #{n_reattempts} we are left with #{compressedPath.inspect}, which exists")
          rv = nil
        else
          # then we found a unique name, compress
          # following cmd remains synchronous but does not prompt with popen4Wrapper's running in background
          cmd = "gzip -c #{Shellwords.escape(path)} > #{Shellwords.escape(compressedPath)}"
          status, out, err = BRL::Util::popen4Wrapper(cmd, :log => false)
          if(status.exitstatus == 0)
            rv = compressedPath
  
            # if success, clean up
            begin
              File.delete(path)
            rescue SystemCallError => err
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not delete #{path}:\n#{err.class}\n#{err.message}#{err.backtrace.join("\n")}")
            end
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compression command #{cmd.inspect} failed; head of error: #{err[0..500]}")
            rv = nil
          end
        end
      end

      return rv
    end

    # If the file at @path@ exceeds @size@ bytes then truncate bytes over @size@
    # @param [String] path the file to truncate
    # @param [Fixnum] size the number of bytes to truncate to
    # @return [TrueClass, NilClass] true if truncated or nil if could not 
    #   truncate file or access its size
    def truncateFile(path, size)
      rv = nil
      begin
        if(File.size(path) > size)
          File.truncate(path, size)
          rv = true
        end
      rescue SystemCallError => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not truncate file #{path.inspect} to size #{size.inspect}")
        rv = nil
      end
      return rv
    end

    # Helper to cleanUp: delete the contents of the file at path and provide a new name to 
    #   indicate that this has happened
    # @param [String] path the file path whose contents should be deleted and who should be renamed
    # @param [String] newBasename the basename for the renamed file
    # @return [String, NilClass] the new filepath or nil if error (no rename/delete performed)
    def renameAndRemoveContents(path, newBasename)
      retVal = nil
      if(File.exists?(path) and !File.directory?(path))
        renamePath = File.join(File.dirname(path), newBasename)
        if(File.exists?(renamePath))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Refusing to overwrite #{renamePath.inspect}")
        else
          File.open(renamePath, "w"){|fh| }
          retVal = renamePath
          begin
            File.delete(path)
          rescue SystemCallError => err
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not delete #{path}:\n#{err.class}\n#{err.message}#{err.backtrace.join("\n")}")
          end
        end
      end
      return retVal
    end

    # Helper to cleanup: compress files in a list by imposing limits on the maximum uncompressed
    #   size of a file, the maximum size of a file that compression will be attempted on, and the 
    #   maximum result size upon completion of this method
    # @param [Array<String>] paths the files to be compressed
    # @param [Integer] maxUncompBytes the maximum size of a file (after which it will be compressed)
    # @param [Integer] maxCompBytes the maximum size of a file to have compression attempted 
    #   (after which its contents are removed)
    # @param [Integer] maxJobBytes the maximum size of resulting files (after which file contents are removed)
    # @return [Hash]
    #   [Hash] :compressed mapping original, uncompressed file to its final compressed name
    #   [Hash] :failed mapping original, uncompressed file to a reason for compression failure
    def compressFilesByLimits(paths, maxUncompBytes, maxCompBytes, maxJobBytes)
      rv = { :compressed => {}, :failed => {} }
      jobExcessExt = ".EXCEEDED.JOB.MAX.BYTES"
      fileExcessExt = ".EXCEEDED.FILE.MAX.BYTES"
      compressFailExt = ".FAILED.COMPRESSION"

      # partition files into 3 sets: 
      # (1) those which are tooSmall and will not be compressed,
      # (2) those which are justRight and will be compressed,
      # (3) those which are tooBig to be compressed
      sizes = {}
      noSizes = []
      paths.each{ |path|
        size = File.size(path) rescue nil
        if(size)
          sizes[path] = size
        else
          noSizes << path
        end
      }
      restPairs, tooBigPairs = sizes.partition {|path, size| size < maxCompBytes }
      restPairs.sort! { |pair1, pair2| pair1[1] <=> pair2[1] }
      tooSmallPairs, justRightPairs = restPairs.partition {|path, size| size < maxUncompBytes }

      # remove contents of files which are too large to be compressed
      tooBigPairs.each { |path, size|
        # then file is too large for compression to be attempted
        #@todo deletedPath = retVal[:kept].delete(path) # @todo change :kept to hash?
        renamePath = renameAndRemoveContents(path, File.basename(path)+fileExcessExt)
        rv[:compressed][path] = renamePath if(!renamePath.nil?) # a lossy compression indeed!
      }

      # Count the small files that we will not compress towards the group's max byte limit
      jobBytes = 0
      excessOfJobMaxIndex = nil # @todo replace occurrences of excessOfJobMaxBytes
      tooSmallPairs.each_index { |ii|
        path, size = tooSmallPairs[ii]
        result = jobBytes + size
        if(result > maxJobBytes)
          excessOfJobMaxIndex = ii
          break
        else
          jobBytes = result
        end
      }

      # Delete the contents of small files in excess of the byte limit
      if(excessOfJobMaxIndex)
        tooSmallPairs[excessOfJobMaxIndex..-1].each { |path, size|
          renamePath = renameAndRemoveContents(path, File.basename(path)+jobExcessExt)
          rv[:compressed][path] = renamePath if(!renamePath.nil?)
        }
      end

      # Compress and count the compressed size of files towards the group's max byte limit
      unless(excessOfJobMaxIndex)
        # then the small files were not sufficient to put us over the group limit
        justRightPairs.each_index { |ii|
          # compress the file
          path, size = justRightPairs[ii]
          compressedPath = compressFileSafe(path)
          if(compressedPath.nil?)
            rv[:failed][path] = "Failed to compress #{path.inspect}"
          else
            result = jobBytes + File.size(compressedPath)
            rv[:compressed][path] = compressedPath

            # verify that the compression has not put us over our limit
            #   if it has, remove the file we just compressed
            if(result > maxJobBytes)
              excessOfJobMaxIndex = tooSmallPairs.length + ii
              renamePath = renameAndRemoveContents(compressedPath, File.basename(compressedPath)+jobExcessExt)
              rv[:compressed][compressedPath] = renamePath if(!renamePath.nil?)
              break
            else
              jobBytes = result
            end
          end
        }
      end

      return rv
    end
    # -- }}

    # Do standard things when errors are reported during methods called by drive(). Robustly do:
    # - call method which prepares an error email
    # - send the error email
    # - ensure @err, @errInternalMsg are nicely logged if set (should be!!).
    def handleError()
      super()
      # Send email
      begin
        if(!@suppressEmail)
          wrapperEmailer = prepErrorEmail()
        end
        wrapperEmailer.sendErrorEmail() if(wrapperEmailer) # Can suppress email by returning nil from prepErrorEmail()
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "Trying to send error email and something went wrong!\n#{err.message}\n#{err.backtrace.join("\n")}")
      end
    end

    # ------------------------------------------------------------------
    # HELPER CLASS METHODS (do not override)
    # ------------------------------------------------------------------
    # The jar must be in or linked in the $SITE_JARS dir env variable
    def self.buildJarPath(jar)
      siteJarsDir = ENV['SITE_JARS']
      return "#{siteJarsDir}/#{jar}"
    end

    def self.networkScratchDir(subDir="")
      return "#{ENV['NETWORK_SCRATCH']}/#{ENV['USER']}/#{subDir}"
    end
  end # class ToolWrapper < BRL::Script::ScriptDriver

  # ------------------------------------------------------------------
  # PROTECTED MODULE METHODS
  # - do not change or override
  # ------------------------------------------------------------------
  # BRL::GenboreeConfig::Tools::main(driverClass) - MODULE METHOD
  # - Similar to BRL::Script::main() but does a little more
  # - Cannot be a class method since it won't be inherited by sub-classes
  # - that's ok, this makes more sense anyway
  # - provide the *Class* name as argument (must inherit from ScriptDriver)
  def Tools::main(wrapperClass)
    begin
      # Instantiate script using specific driver
      driver = wrapperClass.new()
      # Run the application, etc.
      exitCode = driver.drive()
      # Exit with appropriate code
      exit(driver.exitCode)
    rescue => err
      # Try to send out an error email
      if(driver)
        begin
          if(!@suppressEmail)
            emailer = driver.prepErrorEmail()
          end
          if(emailer.is_a?(BRL::Genboree::Tools::WrapperEmailer))
            emailer.sendEmail()
          end
        rescue => err2
          # nothing to do at this point
        end
      end
      # Regardless, log error:
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Problem trying to run tool.")
      Script::displayError("Exception raised:", err, true)
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools

########################################################################
# MAIN - Provided in the scripts that implement ToolWrapper sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::ToolWrapper)
end
