#!/usr/bin/env ruby

require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/pipeline/ftp/helpers/lftp'
require 'brl/genboree/pipeline/ftp/helpers/rsync'

######################################################################
# FTPToolWrapper - Abstract Parent class for Genboree FTP Tool Job Wrapper scripts.
#
# - FTP Tool wrapper scripts should inherit from this class, and implement the interface methods
# - Core functionality provided by the parent class, BRL::Genboree::Tools::ToolWrapper
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
#     downloadFilesFromFTP() - Extract the info you need from @jobConf hash, typically to instance variables
#                        . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
#                        . Command-line args will already be parsed and checked for missing required values
#                        . Do not send email, that will be done automatically from @err* variables
#                        . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
#                          - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
#                          - ToolWrapper will automatically log @errInternalMsg to stderr.
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
  class FTPToolWrapper < BRL::Genboree::Tools::ToolWrapper
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
      :description  => "This is the parent FTP tool wrapper script class. FTP based tool wrappers should inherit from this.",
      :authors      => [ "Sai Lakshmi Subramanian (sailakss@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # attr_accessors to store the 4 sections from the job file
    attr_accessor :inputs, :outputs, :context, :settings
    # attr_accessor for FTP
    attr_accessor :ftpHelper
    attr_accessor :rsyncHelper

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS
    # ------------------------------------------------------------------
    # downloadFilesFromFTP()
    #  . code to download input files from FTP server
    #  . Command-line args will already be parsed and checked for missing required values
    #  . Do not send email, that will be done automatically from @err* variables
    #  . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
    #    - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
    #    - ToolWrapper will automatically log @errInternalMsg to stderr.
    def downloadFilesFromFTP()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    def uploadFilesToFTP()
      raise NotImplementedError, "BUG: The wrapper has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # ------------------------------------------------------------------
    # PROTECTED CONSTRUCTOR
    # ------------------------------------------------------------------
    # new() - Constructor
    # - If subclass overrides, first call super(optsHash) at the beginning
    def initialize()
      super()
      dbrc = BRL::DB::DBRC.new(@dbrcFile)
      @ftpDbrcKey = @genbConf.ftpDbrcKey
      ii = @ftpDbrcKey.index(":")
      ftpHost = @ftpDbrcKey[ii+1..-1]
      ftpKey = @ftpDbrcKey[0...ii].downcase.to_sym
      dbrcRec = dbrc.getRecordByHost(ftpHost, ftpKey)
      noOfAttempts = 6
      attempt = 1
      # Attempt to create @ftpHelper object (using LFTP helper)
      while (@ftpHelper.nil? and attempt <= noOfAttempts)
        begin
          @ftpHelper = BRL::Genboree::Pipeline::FTP::Helpers::Lftp.new(dbrcRec[:host], dbrcRec[:user], dbrcRec[:password])
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "FTP", "Error encountered while opening @ftpHelper on attempt=#{attempt}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.message=#{err.message.inspect}")
          $stderr.debugPuts(__FILE__, __method__, "FTP", "err.backtrace:\n#{err.backtrace.join("\n")}")
          if(attempt == noOfAttempts)
            raise err
          else
            sleepTime = 2 ** (attempt - 1) * 60
            $stderr.debugPuts(__FILE__, __method__, "FTP", "sleeping for #{sleepTime} seconds") unless(sleepTime == 0)
            sleep(sleepTime)
            attempt += 1
          end
        end
      end
      @pollerDbrcKey = @genbConf.pollerDbrcKey
      ii = @pollerDbrcKey.index(":")
      pollerHost = @pollerDbrcKey[ii+1..-1]
      pollerKey = @pollerDbrcKey[0...ii].downcase.to_sym
      dbrcRec = dbrc.getRecordByHost(pollerHost, pollerKey)
      # @todo config with "clusterUser" information? using default for rsync helper
      @rsyncHelper = BRL::Genboree::Pipeline::FTP::Helpers::Rsync.new(dbrcRec[:host])
      @rsyncHelper.debug = true
    end

    # parseJobFile()
    # - ToolWrapper reads and parses the JSON job file  
    # - This method will parse FTP specific fields from the JobFile  
    def parseJobFile()
      super()
      begin
        # Admin Emails
        @adminEmail = @context['adminEmail']
      
      rescue Exception => err
        BRL::Script::displayError("ERROR: could not parse the Job File provided (#{@jobFile.inspect}).", err, true)
        @exitCode = EXIT_BAD_JOB_FILE
      end
      return @exitCode
    end
  end # class FTPToolWrapper < BRL::Genboree::Tools::ToolWrapper
end ; end ; end # module BRL ; module Genboree ; module Tools

########################################################################
# MAIN - Provided in the scripts that implement ToolWrapper sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::FTPToolWrapper)
end
