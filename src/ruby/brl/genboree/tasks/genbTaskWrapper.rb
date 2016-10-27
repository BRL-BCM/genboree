#!/usr/bin/env ruby

require 'cgi'
require 'daemons'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/lockFiles/genericDbLockFile'

module BRL ; module Genboree ; module Tasks
  class GenbTaskWrapper

    attr_accessor :cmd, :taskId
    attr_accessor :cmdSupportsTasksTable
    attr_accessor :pwd, :bkgrndErrFile, :bkgrndOutFile
    attr_accessor :verbose

    # optsHash supports these options (see usage below):
    # --cmd
    # --cmdSupportsTasksTable     [optional flag]
    # --genbConf                  [optional]
    # --dbrcKey                   [optional]
    # --bkgrndOutFile             [optional]
    # --bkgrndErrFile             [optional]
    # --verbose                   [optional]
    def initialize(optsHash)
      @optsHash = optsHash
      @verbose = optsHash.key?('--verbose')
      @cmd = optsHash['--cmd']
      @taskId = @errorLevel = nil
      @cmdSupportsTasksTable = optsHash.key?('--cmdSupportsTasksTable')
      @genbConf = optsHash['--genbConf'] || ENV['GENB_CONFIG']
      @dbrcKey = optsHash['--dbrcKey']
      @genbConfig = @dbu = nil
    end

    def daemonize()
      # First, let's try saving some stuff
      @bkgrndId = "#{$$}-#{rand(65535)}"
      @pwd = FileUtils.pwd()
      @bkgrndErrFile = @optsHash['--bkgrndErrFile'] || "#{@pwd}/bkgrndTask_#{@bkgrndId}.err"
      @bkgrndOutFile = @optsHash['--bkgrndOutFile'] || "#{@pwd}/bkgrndTask_#{@bkgrndId}.out"
      $stderr.puts "CHILD (#{$$}) => ABOUT TO daemonize this process\n      (see bkgrnd err stream file for more feedback after this, assuming you have verbose turned on)p;" if(@verbose)
      Daemons.daemonize
      # Now let's restore some things the daemonization process destroyed/reset for
      # proper detachment and/or safety
      File.umask(0002)
      FileUtils.cd(@pwd)
      $stderr = File.new(@bkgrndErrFile, "w+")
      $stdout = File.new(@bkgrndOutFile, "w+")
      # For some reason I don't know, these need to be auto-flushed (no buffering) after daemonizing else they don't write anything
      $stderr.sync = true
      $stdout.sync = true
    end

    def clean()
      @dbLock.releasePermission()     if(@dbLock and @dbLock.respond_to?(:releasePermission))
      @genbConfig.clear() if(@genbConfig)
      @dbu.clear()        if(@dbu)
      @dbu.clearCaches()  if(@dbu)
      $stdout.close()
      $stderr.close()
    end

    def registerFatal() # well, try to, using stuff set up during first parts of run()
      @dbu.setTaskStateBit(@taskId, BRL::Genboree::DBUtil::FAIL_STATE)
    end

    # This method returns immediately after the daemonize() call in the parent process
    # AND continues with the rest of the method in the daemonized child process
    def run()
      childPid = Process.fork()
      unless(childPid) # no pid, then we are the child process...daemonize that, etc
        daemonize()
        $stderr.puts "CHILD (#{$$}) => DAEMONIZED forked child process #{$$}. " if(@verbose)
        # Make a DbUtil instance
        # Get Genboree configuration
        @genbConfig = GenboreeConfig.load(@genbConf)
        dbrcKey = @dbrcKey || @genbConfig.dbrcKey
        # MUST do all this within the best begin-rescue we can, to try to ensure that if something goes wrong, we release the file lock!
        begin
          # First, need permission to do command-line DB ops on main Genboree database (BLOCKS):
          @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:mainGenbDb)
          @dbLock.getPermission()
          # Now that have permission, make a DbUtil instance to use
          @dbu = BRL::Genboree::DBUtil.new(dbrcKey, nil, @genbConfig.dbrcFile)
          # Create a PENDING task (pending is default, as is Time.now for timestamp)
          @taskId = @dbu.insertNewTask_returnTaskId(@cmd)
          $stderr.puts "CHILD (#{$$}) => NEW TASK ID: #{@taskId}" if(@verbose)
          # Update the cmd to include the special '-y' arg if the command supports it
          if(@cmdSupportsTasksTable)
            if(@cmd =~ /\{taskId\}/)    # Preferred way is for @cmd to have a placeholder "{taskId}" we can use
              @cmd.gsub!(/\{taskId\}/, @taskId.to_s)
            else                        # Obsolete way is to blindly tack on " -y <taskId> " ... bad if have own redirects, multiple commands or god-knows-what on end
              @cmd << " -y #{@taskId} "
            end
            # Update the cmd in the tasks table
            @dbu.updateCmdByTaskId(@cmd, @taskId)
          end
          # About to execute cmd; update status unless command knows to do that itself.
          unless(@cmdSupportsTasksTable) # update the state unless the cmd will be doing that
            @dbu.clearTaskStateBit(@taskId, BRL::Genboree::DBUtil::PENDING_STATE)
            @dbu.setTaskStateBit(@taskId, BRL::Genboree::DBUtil::RUNNING_STATE)
          end
          # Clean up database connections while subprocess runs
          @dbu.clear()
          @dbu.clearCaches()
          @dbu = nil
          @dbLock.releasePermission()   # This will also release permission unless released already.
          # Execute command
          $stderr.puts "CHILD (#{$$}) => COMMAND TO RUN: #{@cmd.inspect}" if(@verbose)
          cmdOut = `#{@cmd}`
          # Check exit status
          @exitStatus = ($? ? $?.exitstatus : nil)
          $stderr.puts "CHILD (#{$$}) => COMMAND DONE (exit code if available: #{@exitStatus.inspect})" if(@verbose)
          $stderr.puts "CHILD (#{$$}) => **ERROR** COMMAND **DIED** or something!! exit status object is #{@exitStatus.inspect}, which is BAD." if(@exitStatus != 0)
          # Need to connect to genboree database again to update tasks table (probably), Get permission
          @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:mainGenbDb)
          @dbLock.getPermission()
          # Reconnect to database, to update task status, etc:
          @dbu = BRL::Genboree::DBUtil.new(dbrcKey, nil, @genbConfig.dbrcFile)
          # Update state in tasks table based on exit status
          if(@exitStatus and @exitStatus == 0) # everything seems ok, clear running bit
            @dbu.clearTaskStateBit(@taskId, BRL::Genboree::DBUtil::RUNNING_STATE) unless(@cmdSupportsTasksTable)
          else
            @dbu.setTaskStateBit(@taskId, BRL::Genboree::DBUtil::FAIL_STATE)
          end
          @dbLock.releasePermission()
          $stderr.puts "CHILD (#{$$}) => TASK TABLE UPDATED (or was command slated to do that? #{@cmdSupportsTasksTable})" if(@verbose)
          # exit clean; don't let exit handlers from defunct parent run.
          $stderr.puts "CHILD (#{$$}) => ABOUT TO DO CLEANUP (closing all streams, DB handles, etc)" if(@verbose)
          self.clean()
        rescue Exception => ex  # aggressive rescue
          $stderr.puts "CHILD (#{$$}) => ***ERROR***: threw an nasty exception. About to try to clean up.\n    Ex msg: #{ex.message}\n    " + ex.backtrace.join("\n")
        ensure
          self.clean()
        end
        Process.exit!(BRL::Genboree::OK)
      else # have a pid, thus we are the parent
        $stderr.puts "PARENT (#{$$}) => FORKED A CHILD PROCESS (#{childPid}) THAT WILL DAEMONIZE.\n       (parent will now detach from child & then exit, leaving child to do its work)"
        # register disinterest in the child process
        Process.detach(childPid)
      end
      return childPid
    end

    # --------------------------------------------------------------------------
    # HELPERS
    # --------------------------------------------------------------------------
    def GenbTaskWrapper.processArguments()
      optsArray = [
                    ['--cmd', '-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--cmdSupportsTasksTable', '-y', GetoptLong::NO_ARGUMENT],
                    ['--genbConf', '-g', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--dbrcKey', '-d', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--bkgrndOutFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--bkgrndErrFile', '-e', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      GenbTaskWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      GenbTaskWrapper.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    def GenbTaskWrapper.usage(msg='')
      puts "\n#{msg}\n" unless(msg.empty?)
      puts "

    PROGRAM DESCRIPTION:
      Runs a command (or, potentially, a series of commands) via a detached process.
      Like a daemon, but one that exits when the command it is overseeing is done.
      Because it should run detached, it should out live the launching parent process.
      Meant to be run at the command prompt or in a sub-shell. Also, it will
      register the task in the genboree tasks table.

      'cmd' should be fully URL escaped when provided to this program. Will be
      run via a sub-shell.

      If [when unescaped] the cmd contains the placeholder '{taskId}' and the -y
      option is provided, then the newly created task's taskId will be substituted
      so the cmd knows the taskId to modify. -y is optional: by default it is
      assumed the cmd knows nothing about the genboree tasks table.

      A note about safely calling the program with arguments whose values may
      contain special shell characters, etc. For example, user names, dirs based
      on user database names (users can use spaces, '-marks, etc, for names of
      things):
        - you can URL escape the full argument value
        - the program will detect this and automatically unescape it
        - note that this means that if the value has an escape sequence in it
          (%20 or %2E for example ; /%[0-9A-Fa-f][0-9A-Fa-f]/) already, then
          you MUST escape it. So that the argument 'Demo%20123' becomes
          'Demo%25%20123'.

      A note about the Genboree config file to use. If you don't specify one,
      then the one specified by GENB_CONFIG environmental variable will be used.
      The minimum config file must have these properties set to sensible things:
        dbHost      # Main Genboree DB host
        userName    # A username who can modify Genboree tables
        passwd      # That user's MySQL password
        dbrcFile    # .dbrc file to use
        dbrcKey     # Key matching the driver entry to use in the dbrcFile
        jsVer       # A number (doesn't matter what for this)

      The background task wrapper will have its own '.out' and '.err' files in the
      current working directory to which stdout and stderr content for the -wrapper-
      will go (since there is no parent console process when running detached, the
      regular stdout/stderr are closed). These will have the base name 'bkgrndTask_'
      followed by some random numbers followed by '.out' or '.err'. You can OVERRIDE
      these files by providing full paths to --bkgrndOutFile and/or --bkgrndErrFile.

      These files are independent of output of your command(s). Probably you should
      redirect those to some file, right?

      COMMAND LINE ARGUMENTS:
        --cmd                   |   -c    => URL escaped command(s).
        --cmdSupportsTaskTable  |   -y    => [optional flag] The command supports
                                             the tasks table, so replace all
                                             {taskId} placeholders with the
                                             appropriate taskId.
        --genbConf              |   -g    => [optional] Name of Genboree config file to use.
                                             Defaults to GENB_CONFIG environmental
                                             variable. But -some- config file must
                                             be found!
        --dbrcKey               |   -d    => [optional] Override the dbrcKey in the
                                             config file and use this key instead.
                                             Will still look in the .dbrc file listed
                                             under the dbrcFile in the config file.
        --bkgrndOutFile         |   -o    => [optional] Override the background task
                                             wrapper's stdout file. Full path.
        --bkgrndErrFile         |   -e    => [optional] Override the background task
                                             wrapper's stderr file. Full path.
        --verbose               |   -v    => [optional flag] More verbose on stderr.
        --help                  |   -h    => [optional flag] Output usage info and exit.

      USAGE:
      genbTaskWrapper.rb -c date
    "
      exit(BRL::Genboree::USAGE_ERROR)
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tasks

# --------------------------------------------------------------------------
# MAIN (command line execution begins here)
# --------------------------------------------------------------------------
begin
  # process args
  optsHash = BRL::Genboree::Tasks::GenbTaskWrapper::processArguments()
  # instantiate
  taskWrapper = BRL::Genboree::Tasks::GenbTaskWrapper.new(optsHash)
  $stderr.puts "PARENT (#{$$}) => TASK WRAPPER instantiated" if(optsHash.key?('--verbose'))
  # call
  taskWrapper.run()
  exitVal = BRL::Genboree::OK
rescue => err
	errTitle =  "(#{$$}) #{Time.now()} GenbTaskWrapper - FATAL ERROR: Couldn't launch task properly for some reason. Exception listed below."
	errTitle << " Will try to register the failure with Genboree tasks tablle, but may also fail if datbase related.\n\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
	begin
    taskWrapper.registerFatal()
	rescue => err2
    $stderr.puts "( couldn't register the failure with Genboree tasks table either )"
	end
end

exit(exitVal)
