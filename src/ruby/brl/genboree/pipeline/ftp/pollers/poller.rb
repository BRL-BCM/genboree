require 'json'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/net/netUtil'
require 'brl/script/scriptDriver'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/genboreeUtil'

############################################################
# Poller - Abstract parent class for Genboree pollers
# A poller reads directories for files matching a certain pattern and launches jobs
# on files that match the pattern. To protect against jobs be launched on files with
# the same name and content, it moves files from an "inbox" area to a "working" area.
# These locations are defined in a location configuration file. Because the polled location
# may be remote, a location may be of a particular type (ftp, http, rsync, etc.), and a helper
# of that type must implement methods that allow for files to be moved from inbox to working.
#
# Interface - sub-classes must implement:
#   VERSION
#   COMMAND_LINE_ARGS
#   DESC_AND_EXAMPLES
#   ENV_VAR_LOCK_FILE
#   makeHelper
#   ... # @todo
#   
# 
############################################################
module BRL ; module Genboree ; module Pipeline ; module FTP ; module Pollers

# @todo Lay out drive() method
# @todo Implement methods mentioned in README, in context of knowing program
#   flow from drive()
# @todo Implement empty jobConf settings config method.
# @todo Implement empty jobConf context config method.
# @todo Implement default run(), keeping in mind sub-classes may override
class Poller < BRL::Script::ScriptDriver

  # @todo fill these with generic poller info
  VERSION = "1.0"
  COMMAND_LINE_ARGS = {
    "--confFile" => [:REQUIRED_ARGUMENT, "-c", "location of poller configuration file"],
    "--waitTimeForPendingUploads" => [:OPTIONAL_ARGUMENT, "-w", "amount of time to wait for pending uploads"]
  }
  DESC_AND_EXAMPLES = {
    :description => "Polls FTP locations for newly deposited files to be processed",
    :authors     => [ "Aaron Baker (ab4@bcm.edu)", "Andrew R Jackson (andrewj@bcm.edu)" ],
    :examples    => [
      "#{File.basename(__FILE__)} --confFile=ftpPoller.conf",
      "#{File.basename(__FILE__)} --waitTimeForPendingUploads=600",
      "#{File.basename(__FILE__)} --help"
    ]
  }

  # Load Genboree config
  genbConf = BRL::Genboree::GenboreeConfig.load()

  # Set modification time constraints for poller
  # We assume a file is still being uploaded if it has been modified in the past hour 
  # We assume a file group is incomplete if all files have not been modified for three days
  TIME_UPLOAD_IN_PROGRESS = 3600 # 60 second / min * 60 min / hr
  TIME_MISSING_GROUP = 259200 # 60 second / min * 60 min / hr * 24 hr / day * 3 days

  # We import poller.conf as a hash into a variable named pollerConf.
  # The variables below are keys for that hash.
  POLLER_MAX_LOCATIONS = "maxNumLocsProcessed"
  POLLER_LOC_PATTERN = "locationConfsPattern"
  POLLER_JOB_TEMPLATE_DIR = "jobTemplateDir"

  # We import location confs (*.locConf.json), one at a time, as hashes as we traverse all polled directories.
  # The variables below are keys for those hashes.
  LOC_HOST = "host"  # ftp host to connect to
  LOC_TYPE = "type" # recType for dbrc
  LOC_INCOMING_DIR = "incoming.dir" # the actual location directory
  LOC_INCOMING_FILE_GROUPS = "incoming.fileGroups" # patterns to check for files in that directory
  LOC_WORKING_DIR = "working.dir" # working directory where files are moved while they're being processed
  LOC_FINISHED_DIR = "finished.dir" # finished directory where files are moved when they're done being processed (if job is successful)
  LOC_FAILED_DIR = "failed.dir" # not used
  LOC_OUTPUT_DIR = "output.dir" # same as finished directory (not outbox directory, which also exists - that's confusing!)
  LOC_JOB_SUCCESS_ID = "job.successToolId" # tool ID used for submitting successful, complete file groups (FTPexceRptPipeline)
  LOC_JOB_FAILURE_ID = "job.failureToolId" # tool ID used for submitting unsuccessful, incomplete file groups (could be different than success job, but is the same right now)
  LOC_JOB_HOST = "job.submitHost" # FTPexceRpt job will be submitted using this host

  # The variables below are keys for the jobFile.json hash
  INPUTS, OUTPUTS, SETTINGS, CONTEXT = "inputs", "outputs", "context", "settings"

  attr_accessor :remoteHelper # helper object to perform ftp operations
  attr_accessor :context, :settings # hashes to incorporate into jobHash
  attr_accessor :contextSym, :settingsSym # how to incorporate into jobHash -- :merge or :replace 

  # makeHelper method is implemented in children classes (ftpPoller and rsyncPoller)
  # This method creates the helper that connects to the FTP server and performs all FTP-based operations
  def makeHelper(host=nil, user=nil)
    raise NotImplementedError, "BUG: The script has a bug. The author did not implement the required '#{__method__}(host, user, password)' method."
  end

  def initialize()
    super()
    # Clean up various instance variables used in poller
    clean()
    # @debug tells us whether we want to print lots of extra debug statements in case something goes wrong
    @debug = false
    # @remoteHelper is set by #makeHelper to be the particular helper that connects to the FTP server and performs all FTP-based operations
    @remoteHelper = nil
    # @helperType keeps track of whether our helper is rsync or Net::FTP based
    @helperType = nil
    # Grab file path to lock file from GenboreeConfig - raise error if we can't find it
    lockFileConfig = 'remotePollerLockFile'
    genbConf = BRL::Genboree::GenboreeConfig.new()
    genbConf.loadConfigFile()
    @lockFile = genbConf.propTable[lockFileConfig]
    if(@lockFile.nil?)
      raise PollerError.new("@lockFile is nil, is #{lockFileConfig} set in the config file?")
    end
  end

  # Clears @jobTemplateDir (path to where we can find template jobFile.json for submitting FTPexceRpt jobs)
  def cleanPoller()
    @jobTemplateDir = ""
  end
  
  # Clears all information gathered from location conf
  def cleanLocation()
    @finishedDir = @incomingDir = @patternGroups = @workingDir = nil
    @outputDir = @successToolId = @apiCaller = nil
    @successToolId = @failureToolId = nil
    @completeFileGroups = @incompleteFileGroups = nil
  end

  # Cleans up jobFile.json hash and all of its related instance variables. Resets @contextSym and @settingsSym
  def cleanJob()
    @jobHash = {}
    @inputs = @outputs = []
    @settings = @context = {}
    @contextSym = @settingsSym = :merge
  end

  # Cleans all information used by poller to submit a given FTPexceRpt job
  def clean()
    cleanPoller()
    cleanLocation()
    cleanJob()
  end

  # Provide interface to run the script from ScriptDriver
  # @note if any sub class wishes to override, move this function to override parent drive()
  #   following conventions from parent ScriptDriver
  # @todo what to do with jobIds? email?
  # @todo file paths are matched on patterns twice
  # @todo catch errors for each location, one location can error and other location will be fine
  # @return [Fixnum] exitCode indicating success or failure of script
  def run()
    lockFh = nil
    begin
     # Lock pollerLockFile
      lockFh = lockFile()
      # Grab a list of all location conf files specified by poller conf (and grab directory where job template is located)
      locations = parsePollerConf()
      # We'll traverse each location and see if we need to submit a job
      locations.each{|location|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "\n\nProcessing location: #{location.inspect}\n\n")
        # Parse location conf and set up variables for processing this job
        parseLocationConf(location)
        # Grab all files in inbox that are ready for processing (and also report files that are still being uploaded)
        if(@optsHash['--waitTimeForPendingUploads'])
          waitTime = @optsHash['--waitTimeForPendingUploads'].to_i
        else
          waitTime = TIME_UPLOAD_IN_PROGRESS
        end
        incoming = waitForPendingUploads(location, waitTime)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "incoming=#{incoming.inspect}") if(@debug)
        # Figure out which file groups are complete - those are the ones we're going to process first
        completeFileGroups = groupFiles(incoming)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "completeFileGroups=#{completeFileGroups.inspect}") if(@debug)
        # Move each complete file group to its respective working directory
        workingMap = moveToWorking(completeFileGroups) 
        # Update file paths for each file (from being inside inbox to being inside working directory)
        completeFileGroups.each{|fileGroup| fileGroup.map!{|file| workingMap[file]}}
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "working=#{completeFileGroups.inspect}") if(@debug)
        jobIds = submitJobs(completeFileGroups)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitted jobs: #{jobIds.inspect}")
        # After submitting working, full file groups, we'll submit failed, incomplete file groups
        incompleteFiles = @incompleteFileGroups.flatten
        mtimesMap = @remoteHelper.mtimes(incompleteFiles)
        timeNow = Time.now
        oldGroups = []
        @incompleteFileGroups.each{|group|
          oldGroup = true
          group.each{|path|
            mtime = mtimesMap[path]
            # If any file in a given incomplete file group has NOT been sitting around for longer than or equal to TIME_MISSING_GROUP (3 days),
            # then we won't submit the job. This is to prevent us from spamming the user with reminder emails (you need to upload your files!).
            if((timeNow - mtime) < TIME_MISSING_GROUP)
              oldGroup = false
              break
            end
          }
          # If all the files in the incomplete file group are old, then we push the current group onto oldGroups.
          # These old groups will be processed
          if(oldGroup)
            oldGroups.push(group)
          end
        }
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "oldGroups=#{oldGroups.inspect}") if(@debug)
        # Move files in old groups to their respective working directories
        oldWorkingMap = moveToWorking(oldGroups)
        # Update file paths in these groups to be the working directory paths
        oldGroups.each{|fileGroup| fileGroup.map!{|file| oldWorkingMap[file]}}
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "oldGroups=#{oldGroups.inspect}") if(@debug)
        # Submit these groups as failure jobs (which is really pretty much the same as normal jobs, since the tool ID is the same in both cases)
        failedJobIds = submitFailureJobs(oldGroups)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Submitted failure jobs: #{failedJobIds.inspect}")

        # @todo either files are submitted to success job, failure job, or we are still waiting; we have printed
        # the first 2 already, print status on the third
        # Clean up instance variables associated with current location
        cleanLocation()
      }
      # Clean up instance variables associated with poller (since we're done traversing all locations)
      cleanPoller()
    rescue => err
      prepGbError(err, __method__, 21, "An error occurred while running the job!")
    ensure
      @remoteHelper.ftpObj.close() rescue nil
      @remoteHelper = nil
    end
    begin
      if(lockFh)
        # if we obtained a lock, try to unlock
        unlocked = unlockFile(lockFh)
        raise "Failed unlocking file" unless(unlocked)
      end
    rescue => err
      prepGbError(err, __method__, 22, "An error occurred while trying to unlock the lock file")
    end
    return @exitCode
  end

  # partition paths into sets of complete or incomplete groups
  # with the eventual goal of moving complete groups to the working area, leave incomplete 
  #   groups for a later polling cycle
  # @param [Array<String>] the file paths to group
  # @return [Array<Array<String>>] sets of file paths
  # @note @patternGroups must be set by parseLocationConf (or some other way)
  # @note modifies paths in place
  # @set @completeFileGroups, @incompleteFileGroups
  def groupFiles(paths)
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "paths for groupFiles method: #{paths.inspect}")
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@patternGroups for groupFiles method: #{@patternGroups.inspect}")
    # We're going to split up our files into complete file groups and incomplete file groups
    @completeFileGroups = []
    @incompleteFileGroups = []
    # map path to group information:
    #   :type [:complete, :incomplete]
    #   :group [Fixnum] complete or incomplete group number the path belongs to
    template = { :type => nil, :group => nil }
    path2CompGroup = Hash.new { |hh, kk| hh[kk] = -1 }
    path2IncompGroup = Hash.new { |hh, kk| hh[kk] = -1 }
    completeNum = 0
    incompleteNum = 0
    @patternGroups.each{|groupPatterns|
      groupedHash = Poller::groupStrings(paths, groupPatterns)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "groupedHash for groupFiles method: #{groupedHash.inspect}")
      complete, incomplete = groupedHash[:complete], groupedHash[:incomplete]
      complete.each{|fileGroup|
        completePaths = fileGroup.collect{|kk, vv| vv}
        completePaths.each{|path|
          path2CompGroup[path] = completeNum
          # remove any newly formed complete group from old incomplete groups
          path2IncompGroup.delete(path)
        }
        completeNum += 1
        # don't consider these paths for any later groups, its a complete group now
        paths -= completePaths
      }
      incomplete.each{|fileGroup|
        incompletePaths = fileGroup.collect{|kk, vv| vv}
        incompletePaths.each{|path|
          path2IncompGroup[path] = incompleteNum
        }
        incompleteNum += 1
      }
    }
      
    # aggregate complete and incomplete groups into [Array<Array<String]] by inverting 
    #   the maps path2CompGroup and path2IncompGroup
    compGroup2Paths = path2CompGroup.invertDups()
    incompGroup2Paths = path2IncompGroup.invertDups()
    @completeFileGroups = compGroup2Paths.values
    @incompleteFileGroups = incompGroup2Paths.values
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@completeFileGroups=#{@completeFileGroups.inspect}") if(@debug)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "@incompleteFileGroups (e.g. an archive without an associated manifest)=#{@incompleteFileGroups.inspect}")
    return @completeFileGroups
  end

  # Parse configuration file, setting relevant instance variables
  # @param [String] file the configuration file to parse
  # @return [Array<String>] locations to process
  # @note sub classes overriding this function should call super() first
  # @todo if Dir.glob is stable we will always process the same locations
  def parsePollerConf(file=@optsHash['--confFile'])
    locations = []
    begin 
      # Open poller configuration file and parse it into pollerConf (it's JSON)
      pollerConf = {}
      File.open(file){|ff|
        pollerConf = JSON.parse(ff.read())
      }
      # Grab all locConf files specified by poller conf settings
      maxLocations = pollerConf[POLLER_MAX_LOCATIONS]
      locationConfPattern = pollerConf[POLLER_LOC_PATTERN]
      locations = Dir.glob(locationConfPattern)[0...maxLocations]
      # Also grab job template directory specified by poller conf
      @jobTemplateDir = pollerConf[POLLER_JOB_TEMPLATE_DIR]
    rescue => err
      prepGbError(err, __method__, 27, "An error occurred while parsing the poller configuration file")
      raise @err
    end
    return locations
  end

  # Parse .locConf.json location configuration file
  # @param [String] location absolute path to location configuration files
  # @return [Hash] location configuration hash
  # @todo new helper factory method?
  def parseLocationConf(location)
    retVal = nil
    begin
      # Grab location conf and save it in locationConf hash (it's JSON)
      locationConf = {}
      File.open(location){|ff|
        locationConf = JSON.parse(ff.read())
      }
      # Set up our different location paths associated with the current location
      @incomingDir = Poller.getMongoValue(locationConf, LOC_INCOMING_DIR)
      @patternGroups = Poller.getMongoValue(locationConf, LOC_INCOMING_FILE_GROUPS)
      @workingDir = Poller.getMongoValue(locationConf, LOC_WORKING_DIR)
      @finishedDir = Poller.getMongoValue(locationConf, LOC_FINISHED_DIR)
      @failedDir = Poller.getMongoValue(locationConf, LOC_FAILED_DIR)
      @outputDir =  Poller.getMongoValue(locationConf, LOC_OUTPUT_DIR)
      # Figure out what kind of remote helper we want to create (rsync or Net::FTP) via the location conf
      locationType = Poller.getMongoValue(locationConf, LOC_TYPE).to_s.downcase.to_sym
      if(locationType == :poller)
        @helperType = "RSYNC"
      elsif(locationType == :ftp)
        @helperType = "LFTP"
      end
      # Grab host from location conf and then create our remote helper
      host = Poller.getMongoValue(locationConf, LOC_HOST)
      dbrc = BRL::DB::DBRC.new()
      dbrcRec = dbrc.getRecordByHost(host, locationType)
      @remoteHelper = makeHelper(host)
      @remoteHelper.debug = true if(@debug)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "host is: #{host}")
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "user is: #{dbrcRec[:user]}")
      # Create @netUtil helper - only used for figuring out time on remote server with rsync helper   
      @netUtil = ::BRL::Net::NetUtil.new(host, dbrcRec[:user])
      # Grab tool ID for successful (complete file group) job and unsuccessful (incomplete file group) job.
      # Right now, they're the same tool ID (ftpExceRptPipeline)
      @successToolId = Poller.getMongoValue(locationConf, LOC_JOB_SUCCESS_ID)
      @failureToolId = Poller.getMongoValue(locationConf, LOC_JOB_FAILURE_ID)
      # Job will be submitted through jobHost
      jobHost = Poller.getMongoValue(locationConf, LOC_JOB_HOST)
      # Create rsrcPath for submitting job
      rsrcPath = getRsrcPath(@successToolId)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rsrcPath=#{rsrcPath.inspect}") if(@debug)
      # Create apiCaller object to submit job
      dbrcRec = dbrc.getRecordByHost(jobHost, :api)
      @apiCaller = BRL::Genboree::REST::ApiCaller.new(jobHost, rsrcPath, dbrcRec[:user], dbrcRec[:password])
    rescue => err
      prepGbError(err, __method__, 26, "An error occurred while parsing the location configuration file")
      raise @err
    end
    retVal = locationConf
    return retVal
  end

  # Parse {toolId}.jobFile.json files
  # @param [String] jobTemplateDir the directory location for job configuration files
  # @param [String] templateBasename the file name (in jobTemplateDir) of the job configuration to parse
  # @return [Hash] hash with inputs, outputs, context, settings keys to submit to the cluster
  def parseJobConf(jobTemplateDir, toolId, confVars={})
    retVal = nil
    templateBasename = "#{toolId}.jobFile.json"
    begin
      jobTemplateFile = File.join(jobTemplateDir, templateBasename)
      File.open(jobTemplateFile){|ff|
        @jobHash = JSON.parse(ff.read())
      }
    rescue => err
      prepGbError(err, __method__, 25, "An error occurred while parsing the job configuration file")
      raise @err
    end
    retVal = @jobHash
    return retVal
  end

  # Prepare a Genboree job based on template file assumes the following are set
  #   @jobHash, @inputs, @outputs, @context, @settings, @inputsSym, @outputsSym, 
  #   @contextSym, @settingsSym
  # @param [Array<String>] inputs a list of Genboree or FTP input file locations
  # @param [Array<String>] outputs a list of Genboree or FTP output file locations
  def prepJob(inputs, outputs)
    begin
      # these are not currently overridable (validations handled by poller)
      @inputs = inputs
      @jobHash[INPUTS] = @inputs

      # outputs may include an Array of Genboree file locations, add FTP info to it
      @outputs = outputs
      if(@jobHash[OUTPUTS].is_a?(Array))
        @jobHash[OUTPUTS] += outputs
      else
        @jobHash[OUTPUTS] = [outputs]
      end
 
      # context and settings are overridable by children
      prepContext()
      if(@contextSym == :replace)
        @jobHash[CONTEXT] = @context
      else
        @jobHash[CONTEXT].merge!(@context)
      end
      prepSettings()
      if(@settingsSym == :replace)
        @jobHash[SETTINGS] = @settings
      else
        @jobHash[SETTINGS].merge!(@settings)
      end
    rescue => err
      prepGbError(err, __method__, 24, "An error occurred while preparing the worker job")
      raise @err
    end
    return @jobHash
  end

  # Generate settings to incorporate into @jobHash
  # @note subclasses may override
  # @todo include finished, failed areas in settings so job can act accordingly?
  #   or perhaps another poller?
  def prepSettings()
    @settingsSym = :merge
    @settings = {}
  end

  # Generate context to incorporate into @jobHash
  # @note subclasses may override
  def prepContext()
    @contextSym = :merge
    @context = {}
  end

  # Submit job to cluster
  # @param [Hash] jobHash the job to submit
  # @return [String, nil] the job id from the submitted job or nil if submission failed
  def submitJob(jobHash, toolId)
    jobId = nil
    # apiCaller has been prepared when parsing the location conf
    rsrcPath = getRsrcPath(toolId)
    @apiCaller.setRsrcPath(rsrcPath)
    resp = @apiCaller.put(JSON(jobHash))
    if(@apiCaller.succeeded?)
      respBody = @apiCaller.parseRespBody()
      jobId = respBody['data']['text']
    else
      $stderr.debugPuts(__FILE__, __method__, "POLLER", "Failed submitting #{toolId.inspect} job: \n#{JSON.pretty_generate(jobHash)}\nResponse body: #{@apiCaller.respBody}")
    end
    return jobId
  end

  # Submit a job for each file group in the working area
  # @param [Array<String>] working file paths
  # @return [Array<String>] job ids of the submitted jobs
  # @todo return instead mapping of location to file to job id?
  # @raise [BRL::Genboree::GenboreeError] if anything goes wrong
  # @note assumes parseLocationConf has been called and the associated state variables set
  # @todo what if fileGroup nil?
  def submitJobs(workingFileGroups)
    jobIds = []
    begin
      # outputs will initially contain the finished dir and failed dir (full paths) 
      outputs = [@outputDir, @failedDir]
      # Traverse each file group that has been moved to its respective working dir
      workingFileGroups.each{|fileGroup|
        # inputs consists of the files in the current file group
        inputs = fileGroup
        # Our original output folders don't include any identifier for THIS particular job
        # We will use the same identifier we used in our working directory to separate different jobs
        outputs.map!{|output| File.join(output, getParentDir(inputs.first) + "/")}
        # Parse job conf and save it in jobConf hash
        jobConf = parseJobConf(@jobTemplateDir, @successToolId, confVars={}) 
        # Load inputs and outputs into job conf
        jobHash = prepJob(inputs, outputs)
        # Submit job conf via API as a tool job
        jobId = submitJob(jobHash, @successToolId)
        # Add current job ID to jobIDs array
        jobIds.push(jobId)
        # Clean up all instance variables that were set by this particular job submission
        cleanJob()
      }
    rescue => err
      prepGbError(err, __method__, 31, "An error occurred while submitting jobs")
      raise @err
    end
    return jobIds
  end

  # Submit a job for incomplete file groups in the incoming area
  # @see submitJobs
  # @todo allow for different settings and context?
  def submitFailureJobs(fileGroups)
    jobIds = []
    begin
      # prepare a job to process working files
      outputs = [@failedDir]
      fileGroups.each{|fileGroup|
        inputs = fileGroup
        outputs.map!{|output| File.join(output, getParentDir(inputs.first) + "/")} #terminal slash for directory
        jobConf = parseJobConf(@jobTemplateDir, @failureToolId, confVars={})
        jobHash = prepJob(inputs, outputs)
        jobId = submitJob(jobHash, @failureToolId)
        jobIds.push(jobId)
        cleanJob()
      }
    rescue => err
      prepGbError(err, __method__, 32, "An error occurred while submitting failure jobs")
      raise @err
    end
    return jobIds
  end

  # Make note of files at each location first, check again after some time for any recently modified files
  # @param [Array<String>] locations the locations that the poller is handling
  # @param [Fixnum] sleepTime the number of seconds (perhaps with fractional seconds) to wait before considering files finished uploading
  # @return [Array<String>] incoming files in the inbox that should have jobs launched
  # @raise [BRL::Genboree::GenboreeError] if anything errors
  # @note assumes parseLocationConf has been called and the associated state variables set
  def waitForPendingUploads(location, sleepTime=TIME_UPLOAD_IN_PROGRESS)
    retVal = []
    uploadInProgress = []
    if(@debug)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "location=#{location.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "patterns=#{@patternGroups}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@remoteHelper=#{@remoteHelper.inspect}")
    end
    begin
      # patterns is an array that will hold all patterns grabbed from the locConf
      patterns = []
      @patternGroups.each{|group|
        group.each{|pattern|
          patterns.push(pattern)
        }
      }
      # List full paths of all files in the user's inbox that match the patterns grabbed above
      if(@helperType == "RSYNC")
        fullFtpPaths = @remoteHelper.ls(@incomingDir, patterns)
      elsif(@helperType == "LFTP")
        fullFtpPaths = @remoteHelper.ls(@incomingDir, 10, patterns)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Files at #{location}: #{fullFtpPaths.inspect}")
      # Grab modification times of all files grabbed above
      mtimes = @remoteHelper.mtimes(fullFtpPaths)
      # We want to figure out the current time on the FTP server
      # If our @helperType is rsync, we can just use @netUtil to figure out the system time
      # If our @helperType is Net::FTP, then we create a temp directory, look at its time stamp, then delete the temp directory
      # Can't we just use @netUtil even if our @helperType is Net::FTP?
      if(@helperType == "RSYNC")
        remoteTimeNow = @netUtil.systemTime()
      elsif(@helperType == "LFTP")
        @remoteHelper.mkdir("#{@incomingDir}temp_dir_for_checking_current_time_aardvark")
        modTimes = @remoteHelper.ftpObj.ls(@incomingDir)
        modTimes.each { |currentFile|
          if(currentFile.split()[-1] == "temp_dir_for_checking_current_time_aardvark")
            remoteTimeStr = "#{currentFile.split()[5]} #{currentFile.split()[6]} #{currentFile.split()[7]} UTC"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "remoteTimeStr is #{Time.parse(remoteTimeStr)}")
            remoteTimeNow = Time.parse(remoteTimeStr).to_i
            break
          end
        }
        @remoteHelper.rmdir("#{@incomingDir}temp_dir_for_checking_current_time_aardvark")
      end
      # If we couldn't figure out current time on FTP server, we raise an error
      raise PollerError.new("Could not determine if file uploads were still in progress. Cowardly refusing to process any files") if(remoteTimeNow.nil?)
      # Check each file to see whether it has been modified in the past hour (sleepTime)
      # If it hasn't been modified, push it onto retVal (we can process it)
      # If it has been modified, push it onto uploadInProgress (we can't process it)
      mtimes.each_key{|path|
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "mtime (before conversion to integer) is #{mtimes[path]}")
        mtime = mtimes[path].to_i
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "mtime is #{mtime} and remoteTimeNow is #{remoteTimeNow}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "remoteTimeNow - mtime is #{remoteTimeNow - mtime}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "sleepTime is #{sleepTime}")
        if(remoteTimeNow - mtime >= sleepTime)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We pass the test and will process the files!")
          retVal.push(path)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "File is still in progress!")
          uploadInProgress.push(path)
        end
      }
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "incomingFiles=#{retVal.inspect}") if(@debug)
      # We don't actually save the uploadInProgress files for anything - all we do is report them here
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Waiting for the following files to finish uploading: #{uploadInProgress.join(", ")}") if(!uploadInProgress.empty?)
    rescue => err
      prepGbError(err, __method__, 29, "An error occurred while waiting for pending uploads!")
      raise @err
    end
    return retVal
  end

  # Move incoming files to the working area to prevent duplicate job submissions
  # @param [Array<Array<String>>] groups of incoming file paths
  # @return [Hash<String, String>] mapping of incoming location to working location
  # @raise [BRL::Genboree::GenboreeError] if anything goes wrong
  # @note assumes parseLocationConf has been called and the associated state variables set
  def moveToWorking(incomingGroups)
    workingFiles = {}
    begin
      # move files to working area of ftp server
      incomingGroups.each{|incomingFiles|
        # move into uniquely named subdirectory based on original file name for a file in the group
        basename = File.basename(incomingFiles.first)
        uniqueDirname = basename[0...8] + basename.generateUniqueString.xorDigest(8)
        subDir = File.join(@workingDir, uniqueDirname)
        $stderr.debugPuts(__FILE__, __method__, "POLLER", "Subdir is currently #{subDir}")
        # Create working directory
        subDir = @remoteHelper.mkdir(subDir)
        if(subDir.nil?)
          $stderr.debugPuts(__FILE__, __method__, "POLLER", "Unable to process incomingFiles=#{incomingFiles.inspect} because we could not safely create a uniquely named sub-working directory=#{subDir} for processing")
        else
          $stderr.debugPuts(__FILE__, __method__, "POLLER", "Created working directory #{subDir.inspect}")
          # Move each file in group from inbox to working directory
          incomingFiles.each{|file|
            basename = File.basename(file)
            dest = File.join(subDir, basename)
            renamedFile = @remoteHelper.rename(file, dest) rescue nil
            if(renamedFile.nil?)
              $stderr.debugPuts(__FILE__, __method__, "POLLER", "refusing to process file=#{file.inspect} because we could not safely move it to the working area #{subDir.inspect}")
            else
              # Once we've moved the file, we want to touch the file so that the timestamp is updated (measures like this prevent us from submitting the same stale files every 30 minutes)
              # UNSURE AS TO WHETHER THIS IS WORKING PERFECTLY - SEEMS MESSED UP FOR CERTAIN LAB DIRECTORIES
              @remoteHelper.touch(renamedFile)
              # workingFiles hash will hold previous full file path as key and new full file path (in working directory) as value
              workingFiles[file] = renamedFile
            end
          }
        end
      }
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "workingFiles=#{workingFiles.inspect}") if(@debug)
    rescue => err
      prepGbError(err, __method__, 30, "An error occurred while waiting for moving incoming files to the working area")
      raise @err
    end
    return workingFiles
  end

  # Lock pollerLockFile to prevent multiple processes launched by cron from running the same tasks
  # @param [String] file the file to lock
  # @return [IO] file handle object, opened for writing and locked on file
  # @todo use BRL::Util approach
  def lockFile(file=@lockFile)
    retVal = nil
    begin
      ff = File.open(file, 'w+')
      # Attempts an exclusive lock and returns immediately. Returns false if
      # an exclusive lock was not obtained.
      ff.flock(File::LOCK_NB | File::LOCK_EX)
      retVal = ff
    rescue => err
      prepGbError(err, __method__, 28, "Unable to obtain a lock for file #{file}")
      raise @err
    end
    return retVal
  end

  # Unlock pollerLockFile to allow next polling cycle
  # @param [String] fileHandle the file to unlock
  # @return [Boolean] indication if file is closed (and unlocked) or not
  def unlockFile(fileHandle)
    retVal = nil
    # Unlock pollerLockFile, close File object, and then return whether File was succesfully closed
    fileHandle.flock(File::LOCK_UN)
    fileHandle.close()
    retVal = fileHandle.closed?()
    return retVal
  end
  
  # Simple method to get the immediate parent directory for a given folder / file 
  def getParentDir(filepath)
    return File.basename(File.dirname(filepath))
  end

  # Simple helper for getting a tool job resource path
  def getRsrcPath(toolId)
    return "/REST/v1/genboree/tool/#{toolId}/job"
  end
 
  # Set default error message for unhandled exceptions (those that aren't GenboreeError class)
  # @param [Error] err any error object
  def prepGbError(err, method, code, userMsg)
    unless(err.is_a?(::BRL::Genboree::GenboreeError))
      @exitCode = code
      @errInternalMsg = err.message  
      @errUserMsg = userMsg
      @err = ::BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
      @err.set_backtrace(err.backtrace)
    else
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "caught GenboreeError: err=#{@err.inspect}, errInternalMsg=#{@errInternalMsg}") if(@debug)
    end
    # otherwise the previous instance variables are already set
  end

  # Accept Mongo-style dot delimited strings specifying nested attributes for hashes
  # @param [Hash] hash the hash to get attribute specified in dotStr from
  # @param [String] dotStr a string specifying a nested attribute in hash
  # @return [Object] the item specified in dotStr
  # @raises [ArgumentError] if the item is not found
  def self.getMongoValue(hash, dotStr)
    retVal = nil
    delim = "."
    keyArray = dotStr.split(delim)
    # init loop
    item = hash[keyArray[0]]
    for ii in (1...keyArray.length) do
      raise ArgumentError, "no child item \"#{keyArray[ii]}\" for current item \"#{item.inspect}\"" unless(item and item.key?(keyArray[ii]))
      item = item[keyArray[ii]]
    end
    retVal = item
    return retVal
  end

  # Associate strings into groups based on a set of patterns; could be useful elsewhere.
  # @param [Array<String>] strings the strings to group according to patterns
  # @param [Array<String>] patterns mutually exclusive Perl style regular expressions as Strings;
  #   behavior is undefined if the patterns are not mutually exclusive
  # @param [1..9] nGroups the number of match groups to compare
  # @param [Hash<Symbol, Object>] opts additional options to apply to the grouping
  # @return [Hash<Symbol, Hash>] a hash with the keys
  #   :complete mapped to an Array<Hash<String, String>> associating a pattern to a string
  #     for each pattern in a complete string group
  #   :incomplete mapped to an Array<Hash<String, String>> for those groups
  # If patterns are not mutually exclusive, string matches will belong to
  #   the first pattern in patterns
  # A string cannot belong to more than one group, groups will be formed according
  #   to the order set in strings
  def self.groupStrings(strings, patterns, nGroups=9, opts={})
    retVal = {:complete => [], :incomplete => []}

    # group is a subset of matchData = matchData[1..9]
    # members is a mapping of a pattern to a string
    group2Members = Hash.new{ |hh, kk| hh[kk] = Hash.new{ |hh2, kk2| hh2[kk2] = [] } }
    # don't modify input strings, don't allow same strings to be used in multiple patterns
    strings = Marshal.load(Marshal.dump(strings))
    patterns.each { |patternStr| 
      pattern = Regexp.new(patternStr)
      foundStrings = []
      strings.each { |string|
        matchData = pattern.match(string)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "pattern=#{pattern.inspect}, string=#{string.inspect}")
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "matchData=#{matchData.inspect}")
        if(matchData.nil?)
        else
          group2Members[matchData[1..9]][pattern].push(string)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "strings=#{strings.inspect}")
          foundStrings << string
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "foundStrings=#{foundStrings.inspect}")
        end
      }
      foundStrings.each { |currentString|
        strings.delete(currentString)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "strings=#{strings.inspect}")
      }
    }
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "group2Members=#{group2Members.inspect}")

    maxIter = 10
    group2Members.each_key { |group|
      ii = 0
      allEmpty = false
      until(allEmpty or ii > maxIter)
        # add strings matching pattern to groups
        # if multiple strings match the same pattern, put them in a new group
        # continue until all strings have a group
        groupHash = {}
        pattern2Str = group2Members[group] 
        pattern2Empty = {}
        pattern2Str.each_key { |pattern|
          strings = pattern2Str[pattern]
          if(!strings.empty?)
            string = strings.pop()
            groupHash[pattern] = string
            pattern2Empty[pattern] = false
          else
            pattern2Empty[pattern] = true
          end
        }
        unless(groupHash.empty?)
          if(groupHash.size == patterns.size)
            retVal[:complete].push(groupHash)
          else
            retVal[:incomplete].push(groupHash)
          end
        end

        # update loop condition
        emptys = pattern2Empty.collect{ |kk, vv| vv }
        allEmpty = true
        emptys.each { |empty|
          allEmpty = (allEmpty and empty)
        }
        ii += 1
      end
    }
    return retVal
  end

end
class PollerError < RuntimeError; end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module Pipeline ; module FTP ; module Pollers

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__))
  BRL::Script::main(BRL::Genboree::Pipeline::FTP::Pollers::Poller)
end
