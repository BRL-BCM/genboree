#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'open4'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/script/scriptDriver'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/prequeue/job'
require 'brl/genboree/tools/toolWrapper'

# == Overview
# This ruby scipt serves as a command line tool that can be invoked in order to run commands
# for a job. The commands are listed in a .commands file given via the --inputFile argument.
#
# A jobFile.json will also be downloaded so it can be available to commands listed in the .commands file.
#
# An email will be sent to the emails listed in --email (CSV, typical the admins) when all the commands are finished.
#
module BRL ; module Genboree ; module Prequeue ; module Scripts
  class CommandsRunner < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "0.1"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--inputFile"         =>  [ :REQUIRED_ARGUMENT, "-i", "The path to the .commands file with the commands to run (~1 per line)." ],
      "--adminEmails"       =>  [ :REQUIRED_ARGUMENT, "-e", "CSV list of admin email addresses who will receive status emails about this job."],
      "--jobName"           =>  [ :REQUIRED_ARGUMENT, "-j", "The jobName, mainly used to obtain the corresponding jobFile.json file." ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Runs the commands listed in the.commands file corresponding to a job. Mainly for use in a TorqueMaui batch system, but the functionality is generic. Assumed to have direct database access to the prequeue database which can be contacted for job information.\n\n (This script is part of the job-running framework and is not run 'on behalf' of a user...it sets up the stuff that will happen 'on behalf' of the user; in fact, it has no idea who the user may be!).",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} -i /cluster.spool/spool/jobs/wbJob-ffofofo-111/scripts/wbJob-ffofofo-111.commands -e andrewj@bcm.edu -j wbJob-ffofofofo-111",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      @exitCode = EXIT_OK
      @errMsg = ""
      # First process args and init and stuff
      validateAndProcessArgs()
      begin
        # Obtain the jobFile.json file and place in current directory.
        job = BRL::Genboree::Prequeue::Job.fromName(@jobName)
        jobConfObj = job.toJobConf()
        jobFile = File.open("./jobFile.json", "w+")
        jobFile.puts JSON.pretty_generate(jobConfObj)
        jobFile.close()
        genbConf = BRL::Genboree::GenboreeConfig.load
        suppressEmail = genbConf.gbSuppressEmailForCommandsRunner
        if(suppressEmail and suppressEmail =~ /true/i)
          suppressEmail = true 
        else
          suppressEmail = false
        end
        # Open the .commands file
        fh = File.open(@inputFile)
        # Execute each command
        fh.each_line { |cmd|
          cmd.strip!
          # First, have to ensure our in-memory io streams for stdout and stderr have been cleared.
          # Else they'll have stuff from previous command.
          initStdStreams()
          # Run command, capturing output
          status = Open4::spawn(cmd, :stdout => @so, :stderr => @se, :quiet => true, :raise => false)
          # We want to keep the stdout and stderr of all commands
          # - we'll divide each command's streams with -----
          @outLog = "\n#{('-'*50)}\n" unless(fh.lineno <= 1)
          @outLog << @so.string
          @errLog = "\n#{('-'*50)}\n" unless(fh.lineno <= 1)
          @errLog << @se.string
          if(status.nil?)
            @errNo = -1 # No valid errNo in this case
            @exitCode = BRL::Genboree::Tools::ToolWrapper::EXIT_NO_JOB_STATUS
            @errInternalMsg = "ERROR: CommandsRunner: Command not found or similar error trying to spawn() this command:\n  #{cmd.inspect}\n\n"
            $stderr.puts @errInternalMsg
            @errLog << @errInternalMsg
            break
          elsif(status.exitstatus == BRL::Genboree::Tools::ToolWrapper::EXIT_CANCELLED_JOB)
            @errNo = status.exitstatus
            @exitCode = BRL::Genboree::Tools::ToolWrapper::EXIT_CANCELLED_JOB
            @errInternalMsg = "ERROR: CommandsRunner: CANCELLED JOB! The following command failed with a non-zero exitstatus of #{status.exitstatus.inspect}:\n    #{cmd.inspect}\n\n"
            $stderr.puts @errInternalMsg
            @errLog << @errInternalMsg
            break
          elsif(status.exitstatus != 0)
            @errNo = status.exitstatus
            @exitCode = BRL::Genboree::Tools::ToolWrapper::EXIT_GENERAL_JOB_FAILURE
            @errInternalMsg = "ERROR: CommandsRunner: The following command failed with a non-zero exitstatus of #{status.exitstatus.inspect}:\n    #{cmd.inspect}\n\n"
            $stderr.puts @errInternalMsg
            @errLog << @errInternalMsg
            break
          else
            @errNo = status.exitstatus
            $stderr.puts "STATUS: CommandsRunner: Following command ran OK with exit status #{@errNo.inspect}:\n    #{cmd.inspect}\n\n"
          end
          # Dump the output log for this command by appending to output log file
          ofh = File.open("#{@jobName}.out", "a")
          ofh.puts @outLog
          ofh.close
          # Dump the error log for this command by appending to error log file
          efh = File.open("#{@jobName}.error", "a")
          efh.puts @errLog
          efh.close
        }
        fh.close
        sendEmail() unless(suppressEmail)
      rescue Exception => @err
        @errUserMsg = @err.message
        @errInternalMsg = @errUserMsg
        @exitCode = BRL::Genboree::Tools::ToolWrapper::EXIT_EXCEPTION_RAISED_FOR_COMMANDSRUNNER
      ensure
        if(fh)
          #fh.flock(File::LOCK_UN) rescue $stderr.puts("ERROR: could not release lock on #{genbConf.prequeueLockFile.inspect}!!")
        end
      end
      # Must return a suitable exit code number
      return @exitCode
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    def validateAndProcessArgs()
      @inputFile = @optsHash['--inputFile']
      @emails = @optsHash['--adminEmails'].to_s.strip.split(/,/)
      @jobName = @optsHash['--jobName']
      @outLog = ""
      @errLog = ""
      initStdStreams()
      return true
    end

    def initStdStreams()
      # Close & promote gc
      @si = nil
      @so.close if(@so.respond_to?(:close))
      @so = nil
      @se.close if(@se.respond_to?(:close))
      # Create as in-memory io streams:
      @so = StringIO.new()
      @se = StringIO.new()
    end

    # Send status emails to admins
    def sendEmail()
      emailer = BRL::Util::Emailer.new()
      subjectTxt = ""
      bodyTxt = ""
      if(@exitCode != 0)
        subjectTxt = "BRL Cluster: #{@jobName} did not finish succesfully"
      else
        subjectTxt = "BRL Cluster: #{@jobName} completed succesfully"
      end
      genbConf = BRL::Genboree::GenboreeConfig.load
      emailer.setHeaders(genbConf.gbFromAddress, @emails.join(", "), subjectTxt)
      emailer.setMailFrom(genbConf.gbSendEmailAs)
      @emails.each { |email|
        emailer.addRecipient(email)
      }
      if((@exitCode != 0))
        bodyTxt = "The job #{@jobName} did not finish succesfully\n\n"
        bodyTxt += "The job errored out with the following message:\n"
        bodyTxt += @errMsg
        bodyTxt += "\n"
      else
        bodyTxt += "The job #{@jobName} completed succesfully!\n"
      end
      bodyTxt += "\nThe standard output stream of the job was:\n"
      bodyTxt += @outLog
      bodyTxt += "\n"
      bodyTxt += "\nThe standard error stream of the job was:\n"
      bodyTxt += @errLog
      emailer.setBody(bodyTxt)
      sendStatus = emailer.send()
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Scripts
########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Prequeue::Scripts::CommandsRunner)
end
