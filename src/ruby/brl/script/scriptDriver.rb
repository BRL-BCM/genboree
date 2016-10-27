#!/usr/bin/env ruby
#$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Ruby-version: #{RUBY_VERSION}\nload_path: #{$LOAD_PATH.inspect}")
require 'pathname'
require 'brl/util/util'

########################################################################
# ScriptDriver - Abstract parent class for scripts. Provides generic core
#                functionality for sub-classes to inherit. Implemented
#                with a standard interface. Adheres to coding standards
#                and promotes well-written drivers with less copy-and-paste
#                of boilerplate components.
#
# - Do not parse command line arguments, that will be done for you using info you provide.
# - Do not implement usage(), that will be done for you by info you provide.
########################################################################
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
#     run() - No-arg method that causes driver to run application.
#             . MUST return a numerical exitCode (0-126). Program will exit with that code. 0 means success.
#             . Command-line args will already be parsed and checked for missing required values
#             . @optsHash contains the command-line args
#             . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
#               - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
# ------------------------------------------------------------------
# "MAIN" section
# ------------------------------------------------------------------
# The only other piece that is required is the usual "MAIN" section at the end our
# your script. It will [ALWAYS] look like this:
#
#    if($0 and File.exist?($0) and Script.runningThisFile?(true))
#      Script::main(Script::MyCoolScriptClass)
#    end
########################################################################

module BRL ; module Script
  class ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "0.1"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type as Symbol, short argument, argument description.
    COMMAND_LINE_ARGS = {
      "--longName" => [ :REQUIRED_ARGUMENT, "-l", "Example script-specific argument." ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Parent class for scripts. Does nothing.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --longName=placeholder",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . code to run the script
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args
    #  . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
    #    - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
    #  . ScriptDriver will automatically log @errInternalMsg to stderr.
    def run()
      raise NotImplementedError, "BUG: The script has a bug. The author did not implement the required '#{__method__}()' method."
      # Must return a suitable exit code number
      return 126
    end

    # ------------------------------------------------------------------
    # PROTECTED CONSTANTS AND METHODS
    # - used by this ScriptDriver class to provide standard functionality
    # - do not override
    # ------------------------------------------------------------------
    # Convenience constant for sub-classes to use when building USAGE_INFO
    HELP_AND_VERSION_ARGS = {
      "--version" =>  [ :NO_ARGUMENT, "-v", "Display version information." ],
      "--verbose" =>  [ :NO_ARGUMENT, "-V", "Toggle verbose flag."],
      "--help"    =>  [ :NO_ARGUMENT, "-h", "Display this help." ]
    }

    # Some pre-defined exit codes
    EXIT_OK = 0
    EXIT_UNEXPECTED_ERROR = 1
    EXIT_ARGS_ISSUE = 2
    EXIT_HELP_USAGE = 3
    EXIT_UNHANDLED_ERROR = 4
    EXIT_LAST_RESERVED = 19

    # The exitCode to report via exit() at the end of the script
    attr_accessor :exitCode
    # The command-line options Hash
    attr_accessor :optsHash
    # Holder of any exception that was caught.
    attr_accessor :err
    # Holder of any suitable message for the USER to see when problem found. (May or may not imply !@err.nil?)
    attr_accessor :errUserMsg
    # Holder of any more detailed internal error message for logging when problem found. (May or may not imply an actual Exception was raised)
    attr_accessor :errInternalMsg

    # ------------------------------------------------------------------
    # PROTECTED CONSTRUCTOR
    # ------------------------------------------------------------------
    # - Constructor
    # - If subclass overrides, first call super(optsHash) at the beginning
    def initialize()
      @exitCode = EXIT_OK
      @commandLineArgInfo = ScriptDriver::HELP_AND_VERSION_ARGS.merge(self.class::COMMAND_LINE_ARGS)
      @optsHash = nil
      @err = @errUserMsg = @errInternalMsg = nil
    end

    # ------------------------------------------------------------------
    # PROTECTED METHODS - do not alter or override
    # ------------------------------------------------------------------
    # Print suitable usage information plus any specific message
    def printUsage(additionalInfo=nil, err=nil, displayErrDetails=false)
      # Print custom message if present (e.g. if need to tell user  something specific in addition to printing usage info)
      $stderr.puts "\nMESSAGE:\n  #{additionalInfo}" unless(additionalInfo.nil?)
      # Error details, if available & desired
      if(err and displayErrDetails)
        $stderr.puts "\nERROR DETAILS:"
        BRL::Script::displayError(nil, err, displayErrDetails)
      end
      # Description
      $stderr.puts "\nPROGRAM DESCRIPTION:\n  #{self.class::DESC_AND_EXAMPLES[:description]}\n\n"
      # Command line argument info
      $stderr.puts "COMMAND LINE ARGUMENTS:"
      # - first, what's the longest "longName, so we can print nicely?
      largestSize = 0
      @commandLineArgInfo.each_key { |longName| largestSize = longName.size if(longName.size > largestSize) }
      # - ok, now print out each arg
      @commandLineArgInfo.keys.sort.each { |longName|
        # spacing after the long name:
        spacingStr = " " * ((largestSize - longName.size) + 1)
        argRec = @commandLineArgInfo[longName]
        $stderr.puts "  #{longName}#{spacingStr}| #{argRec[1]}  => #{argRec[2]}"
      }
      # Authors:
      $stderr.puts "\nAUTHORS:"
      self.class::DESC_AND_EXAMPLES[:authors].each { |author|
        $stderr.puts "  #{author}"
      }

      # Examples:
      $stderr.puts "\nUSAGE:"
      self.class::DESC_AND_EXAMPLES[:examples].each { |example|
        $stderr.puts "  #{example}"
      }
      $stderr.puts "\n"
    end

    # Print the version info.
    def printVersion()
      $stderr.puts "\nVERSION: #{self.class::VERSION}\n\n"
    end

    # Parse command line arguments. Look for help/version request, look
    # for properly called script, return options Hash to use making driver instance.
    # Returns nil if can't parse args properly.
    def parseArgs()
      begin
        # First, build an optsArray from @commandLineArgInfo
        optsArray = []
        @commandLineArgInfo.each_key { |longName|
          argRec = @commandLineArgInfo[longName]
          optsArray << [ longName, argRec[1], GetoptLong.const_get(argRec[0]) ]
        }
        # Process args using GetoptLong
        progOpts = GetoptLong.new(*optsArray)
        # Get as convenient hash and check for certain key issues/cases
        if(progOpts)
          @optsHash = progOpts.to_hash
          if(@optsHash.key?('--help'))
            printUsage()
            @exitCode = EXIT_HELP_USAGE
          elsif(@optsHash.key?('--version'))
            printVersion()
            @exitCode = EXIT_HELP_USAGE
          elsif(!progOpts.getMissingOptions().empty?)
            errMsgStr = "USAGE ERROR: Could not run program. Missing some required arguments:\n"
            progOpts.getMissingOptions().each { |arg|
              errMsgStr << "    #{arg}\n"
            }
            printUsage(errMsgStr)
            @optsHash = nil
            @exitCode = EXIT_ARGS_ISSUE
          end
          @verbose = (@optsHash and @optsHash.key?("--verbose") ? true : false)
        end
      rescue => err
        errMsgStr = "Command-line arguments do not appear be correct. Message: #{err.message.inspect}"
        displayDetails = (!err.is_a?(GetoptLong::Error) and (@optsHash.nil? or @optsHash['--verbose']))
        printUsage(errMsgStr, err, displayDetails)
        @optsHash = nil
        @exitCode = EXIT_ARGS_ISSUE
      end
      return @optsHash
    end

    # Drive the application. This involves:
    # - parse command line args
    # - notice standard problems with command line args
    # - run script, noticing any problems
    # - return suitable exit code
    def drive()
      begin
        # Run application if parse args succeeds; else parseArgs() will complain about any issues it finds.
        @optsHash = parseArgs()
        # Can we run? Not just asking for Help info and we have arguments hash available?
        if(@exitCode == EXIT_OK and @optsHash.is_a?(Hash))
          @exitCode = run()
          if(@exitCode != EXIT_OK) # then something went wrong
            if(@exitCode <= EXIT_LAST_RESERVED or @exitCode > 126) # Dev mistake, kill outright
              raise RuntimeError, "ERROR: Script author is using reserved exit code and not following directions."
            else(@exitCode != EXIT_OK)
              @errInternalMsg = "ERROR: The driver class failed to run the application correctly.\n#{@errInternalMsg}\n\n"
              handleError()
            end
          end
        end
      rescue Exception => err
        $stderr.puts "ERROR: (exitCode currently: #{@exitCode.inspect}). Internal error message:\n#{@errInternalMsg}"
        BRL::Script::displayError("FATAL: an unexpected error prevented the script from completing.", err, true)
        @exitCode = EXIT_UNEXPECTED_ERROR
      end
      return @exitCode
    end

    # Do standard things when errors are reported during methods called by drive(). Robustly do:
    # - call method which prepares an error email
    # - send the error email
    # - ensure @err, @errInternalMsg are nicely logged if set (should be!!).
    def handleError()
      # Log available error details via @errInternalMsg or, if not available, @err.
      self.logErrorDetails()
    end

    # Writes out @errInternalMsg or @err (if @errInternalMsg not set...but it should be, using formatException ideally) to log.
    # - If both @errInternalMsg and @err nil, correctly does nothing.
    # - Used automatically from drive() when errors are encounted.
    # - Devs should be setting @errInternalMsg using Script::formatException when error encountered (may or may not mean an actual Exception)
    # - If there was an exception, devs also should be saving that exception in @err.
    def logErrorDetails()
      begin
        if(@errUserMsg and @errUserMsg =~ /\S/)
          $stdout.puts "\n#{@errUserMsg}\n"
        end
        if(@errInternalMsg and @errInternalMsg =~ /\S/)
          $stderr.puts "\n#{@errInternalMsg}\n"
        end
        if(@err)
          $stderr.puts Script::formatException(@err, "", "", "An error ocurred while running the job.")
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "Can't log available error details in @errInternalMsg or @err. Something went wrong!\n#{err.message}\n#{err.backtrace.join("\n")}")
      end
    end
  end # class ScriptDriver

  # ------------------------------------------------------------------
  # PROTECTED BRL::Script MODULE METHODS
  # - do not change or override
  # ------------------------------------------------------------------
  # Make a pretty unique tmp file name base without going through TmpFile class and its auto-cleanup etc.
  def Script::makeTmpFileBase()
    return "#{Time.now.to_f}_#{$$}_#{rand(64*1024)}"
  end

  # Format the exception as string with standard info.
  # +[err]+ - The Exception to format
  # +[srcFile]+ - The .rb where the exception was caught/rescued (may not be where error occurred!)
  # +[srcMethod]+ - The method where the exception was caught/rescued (may not be where error occurred!)
  # +[devMsg]+ - Some message from dev saying what was being attempted or what went wrong.
  # +[indent]+ - (Optional; default "  ") String used to indent each line in the formatted result string
  # +[returns]+ -
  # - will indent every line using string in "indent
  def Script::formatException(err, srcFile, srcMethod, devMsg, indent="  ")
    # Collect info
    retVal = "#{indent}#{Time.now.strftime("[%d %b %Y %H:%M:%S]")} ERROR rescued "
    retVal << "in #{srcFile}:#{srcMethod}()" if((srcFile and !srcFile.empty?) or (srcMethod and !srcMethod.empty?))
    retVal << "\n"
    retVal << "- #{devMsg}:\n"
    retVal << "Error Class: #{err.class}\n"
    retVal << "Error Message: #{err.message}\n"
    retVal << "Error Backtrace:\n#{err.backtrace.join("\n")}\n\n"
    # Shim in missing indents:
    retVal.gsub!(/\n(?!$)/, "\n#{indent}")
    return retVal
  end

  def Script::displayError(msg, err, displayDetails=true)
    # Process error, capture info:
    if(msg and !msg.empty?)
      @errUserMsg = "\nERROR: #{msg}"
      $stderr.puts @errUserMsg
    end
    if(err)
      @errInternalMsg = "  Error class: #{err.class}\n  Error Message: #{err.message}"
      @errBacktrace = "  Error Backtrace:\n#{err.backtrace.join("\n")}"
      if(displayDetails)
        $stderr.puts @errInternalMsg
        $stderr.puts @errBacktrace
      end
    end
    $stderr.puts "\n"
  end

  def Script::runningThisFile?(fileBeingRun, thisFile, requireBrlTree=(ENV['NO_CHECK_SCRIPT_VS_BRL_LIB'] ? false : true))
    retVal = true
    # In case symlink chain, get ultimate file paths
    fileBeingRun = Pathname.new(fileBeingRun).realpath.to_s
    thisFile = Pathname.new(thisFile).realpath.to_s
    if(requireBrlTree and !fileBeingRun.rindex('brl').nil?)
      fileBeingRun = fileBeingRun[fileBeingRun.rindex('brl'), fileBeingRun.size]
    end
    if(requireBrlTree)
      if(!(thisFile.rindex('brl').nil?)) # on the server
        thisFile = thisFile[thisFile.rindex('brl'),  thisFile.size]
      else
        raise "SERVER MISCONFIGURED! (#{thisFile} should by properly linked to $RUBYLIB area."
      end
    end
    return (fileBeingRun == thisFile)
  end

  # Script::main(driverClass) - MODULE METHOD
  # - Cannot be a class method since it won't be inherited by sub-classes
  # - that's ok, this makes more sense anyway
  # - provide the *Class* name as argument (must inherit from ScriptDriver)
  def Script::main(scriptDriverClass)
    # Instantiate script using specific driver
    driver = scriptDriverClass.new()
    # Run the application, etc.
    exitCode = driver.drive()
    # Exit with appropriate code
    exit(driver.exitCode)
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::ScriptDriver)
end
