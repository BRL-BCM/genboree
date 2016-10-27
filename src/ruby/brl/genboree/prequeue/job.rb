#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'time'
require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/prequeue/batchSystemInfo'
require 'brl/genboree/prequeue/systems/manager'
require 'brl/genboree/prequeue/systems/submitter'
require 'brl/genboree/prequeue/preconditionSet'

module BRL ; module Genboree ; module Prequeue
  # Job class
  # - Create instances of this to insert new jobs into the prequeue, submit prequeued
  #   jobs to the appropriate batch system, and update info for existing prequeued jobs.
  # - MOST FREQUENTLY, Job#new() is NOT used and NOT the way to go. Rather the appropriate class
  #   method for getting a Job instance is used for existing or new Job objects:
  #     - Job.fromName(name)
  #       . Create Job object using the unique name of an existing job
  #     - Job.fromHostTypeAndSystemJobId(host, systemType, systemJobId)
  #       . Create Job object using the batch system host, batch system type, and id assigned
  #         by the batch system for an existing job
  #     - Job.newFromJobConf(jobConf)
  #       . Make Job object for a brand-new job from a jobConf data structure (not JSON string).
  #       . Will still need to be inserted via Job#prequeue() once all finally set up.
  class Job
    #------------------------------------------------------------------
    # CONSTANTS
    #------------------------------------------------------------------
    JOB_STATUSES = BRL::Genboree::DBUtil::JOB_STATUSES
    JOB_TYPES = BRL::Genboree::DBUtil::JOB_TYPES
    JOB_DEFAULT_TIME_STR = BRL::Genboree::DBUtil::JOB_DEFAULT_TIME_STR
    JOB_DEFAULT_TIME = Time.parse(JOB_DEFAULT_TIME_STR)
    MISSING_NAME_PREFIX = 'MISSING_NAME_PREFIX'
    JOB_DEFAULT_SUBMITHOST = 'UNKNOWN'
    # Keys to clean out of context for new jobs. We determine these ourselves and do not use any from user/dev.
    # SHOULD ONLY NEED THIS (clean everything out, reconstruct dynamically when getting job...none of this should ocme from dev/user!):
    # - missing "queue" which should be added once removed from .rhtml files
    JOB_CONTEXT_CLEAN_KEYS_FULL = %w{adminEmails apiDbrcKey gbAdminEmail gbConfFile gbLockFileKey jobId jobIdPrefix jobName jobType scratchDir submitHost systemHost systemType toolIdStr toolScriptPrefix toolTitle user userEmail userFirstName userId userLastName}
    JOB_CONTEXT_CLEAN_KEYS_PREP_FOR_PREQUEUE = %w{queue systemHost systemType user jobType jobId jobName toolIdStr adminEmails userEmail userFirstName userLastName userId gbAdminEmail scratchDir toolTitle jobIdPrefix}

    #------------------------------------------------------------------
    # CLASS VARIABLES
    #------------------------------------------------------------------
    @@globalSaltCounter = 0
    #------------------------------------------------------------------
    # ACCESSORS
    #------------------------------------------------------------------
    # DBUtil instance to use for any DB work. Already configured with appropriate otherDBName and driver, etc, for cluster prequeue database.
    attr_accessor :dbu
    # String containing the prefix to use of the name. Usually some sort of toolId-involved thing.
    attr_accessor :namePrefix

    # Job Info

    # @return [Fixnum,nil] the database record id, if available
    attr_accessor :dbRecId
    # String containing the unique job name or 'ticket' in the prequeue
    attr_accessor :toolId
    # String indicating the user name (login) who is submitting the job
    attr_accessor :user
    # String indicating the type of job (one from JOB_TYPES only)
    attr_accessor :type
    # BatchSystemInfo object with details such as system type, queue, systemId for the job (when available, etc)
    attr_accessor :batchSystemInfo
    # String indicating the Genboree host that submitted the job. Defaults to JOB_DEFAULT_SUBMITHOST constant unless explicitly set by calling code.
    attr_accessor :submitHost
    # [read-only] String containing the unique job name or 'ticket' in the prequeue
    attr_reader :name
    # [read-only] String indicating the job status (one from STATUSES only)
    attr_reader :status
    # [read-only] Time when the job was entered into the prequeue
    attr_reader :entryDate
    # [read-only] Time when the job was submitted to the batch system
    attr_reader :submitDate
    # [read-only] Time when the job started running on the batch system
    attr_reader :execStartDate
    # [read-only] Time when the job finished running on the batch system
    attr_reader :execEndDate
    # @return [PreconditionSet,nil] the preconditions for this job, as a PrecondtionSet instance
    attr_reader :preconditionSet

    # Job Configuration Sections:

    # Array of input resource Strings (URLs usually)
    attr_accessor :inputs
    # Array of output target Strings (URL usually)
    attr_accessor :outputs
    # Hash of tool setting field => value (value correctly typed usually)
    attr_accessor :settings
    # Hash of context field => value (value correctly types usually)
    attr_accessor :context

    # Job Commands

    # Array of job init commands like exports and such.
    attr_accessor :preCommands
    # Array of job clean up and commands and such.
    attr_accessor :postCommands
    # Array of the actual job command(s). Ideally one command.
    attr_accessor :commands

    #------------------------------------------------------------------
    # CLASS METHODS
    #------------------------------------------------------------------
    # Make a new Job object based on the unique job name of an existing job
    def self.fromName(name, dbu=nil)
      job = nil
      dbu = getDBUtil() if(dbu.nil?)
      # Get job detailed job info using the name
      jobFullInfoRows = dbu.selectJobFullInfoByJobName(name)
      if(jobFullInfoRows and !jobFullInfoRows.empty?)
        jobFullInfoRow = jobFullInfoRows.first
        # Create job object from detailed job info row
        job = self.getJobFromJobFullInfoRow(jobFullInfoRow, dbu)
      else
        raise "ERROR: there is no job record with unique name #{name.inspect} in the prequeue."
      end
      return job
    end

    # Make a new Job object based on the unique combination of batch system host,
    # batch system type, and job id assigned by the batch system.
    def self.fromHostTypeAndSystemJobId(systemHost, systemType, systemJobId, dbu=nil)
      job = nil
      dbu = getDBUtil() if(dbu.nil?)
      jobFullInfoRows = dbu.selectJobFullInfoBySystemInfoAndSystemJobId(systemHost, systemType, systemJobId)
      if(jobFullInfoRows and !jobFullInfoRows.empty?)
        jobFullInfoRow = jobFullInfoRows.first
        job = self.getJobFromJobFullInfoRow(jobFullInfoRow, dbu)
      else
        raise "ERROR: there is no job record for the batch system type #{systemType.inspect} on host #{systemHost.inspect} whose batch systemid is #{systemJobId.inspect}."
      end
      return job
    end

    # Make a new Job object for a NON-existing job using the info in the jobConf data structure. Additional
    # info can be provided or it will have to be extracted (and REMOVED [see below]) from the jobConf['context'] Hash.
    #
    # Note that to ensure consistency, the jobConf['context'] after extracting the will be cleaned up and fields stored in the prequeue
    # tables will be removed. Only the table records contain the correct information. Upon creation of a Job object
    # from an existing record, most of these fields will be restored. The fields removed from context are:
    #   'queue', 'systemHost', 'systemType', 'user', 'jobType', 'jobId', 'jobName', 'toolIdStr', 'userEmail', 'userFirstName'
    #   'userLastName', 'userId', 'gbAdminEmail', 'scratchDir'
    #
    # A "jobConf" data structure is any Hash-like object which has certain top-level keys. Analogous to the 'data' section of
    # a BRL::Genboree::REST::Data::WorkbenchJobEntity. The top-level keys are:
    #   - 'inputs'    => Array of Strings typically containing REST API URLs (or some sort of file location path thing)
    #   - 'outputs'   => Array of Strings typically contianing REST API URLs (or some sort of file/dir locations)
    #   - 'settings'  => Hash of tool settings fields mapped to tool-specific values
    #   - 'context'   => Hash of job-related (and batch system related) fields mapped to values. Processed by this method!
    #   - 'preconditionSet' => [optional; rare] a Hash describing a set of preconditions
    def self.newFromJobConf(jobConf, systemHost=nil, systemType=nil, queue=nil, jobType=nil, user=nil, dbu=nil)
      job = nil
      dbu = getDBUtil() if(dbu.nil?)
      # If jobConf a String, assume JSON and parse it. Else, already a proper job conf data structure
      jobConfObj = (jobConf.is_a?(String) ? JSON.parse(jobConf) : jobConf.dup)
      inputs, outputs, context, settings = jobConfObj['inputs'], jobConfObj['outputs'], jobConfObj['context'], jobConfObj['settings']
      preconditionSetSD = jobConfObj['preconditionSet']
      if(context and context.is_a?(Hash))
        # Need to extract some key info from the jobConfObj, if present, or use defaults (or require follow up setup of the Job object).
        # - queue (required somewhere)
        queue = context['queue'] unless(queue)
        raise "ERROR: no 'queue' argument provided to #{self}.#{__method__}() and the 'context' component of the jobConf does not contain a valid 'queue' field. Must specify the intended queue for the job somehow." unless(queue and queue =~ /\S/)
        # - batch system host (required somewhere)
        systemHost = context['systemHost'] unless(systemHost)
        raise "ERROR: no 'systemHost' argument provided to #{self}.#{__method__}() and the 'context' component of the jobConf does not contain a valid  'systemHost' field. Must specify the intended batch system host for the job somehow." unless(systemHost and systemHost =~ /\S/)
        # - batch system type (optional and only if not explicitly provided)
        systemType = context['systemType'] unless(systemType)
        raise "ERROR: no 'systemType' argument provided to #{self}.#{__method__}() and the 'context' component of the jobConf does not contain a valid 'systemType' field. Must specify the intended type of batch system at the host somehow." unless(systemType and systemType =~ /\S/)
        # - user login (optional and only if not explicitly provided)
        user = context['user'] unless(user)
        user = context['userLogin'] unless(user) # fall back on trying older userLogin, still very much in use
        raise "ERROR: no 'user' argument provided to #{self}.#{__method__}() and the 'context' component of the jobConf does not contain a valid 'user' field specifying the user login for whom the job will be run. Must specify the intended type of batch system at the host somehow." unless(user and user =~ /\S/)
        # - job type (optional and only if not explicitly provided)
        jobType = context['jobType'] unless(jobType)
        if(!jobType or jobType !~ /\S/)
          raise "ERROR: no 'jobType' argument provided to #{self}.#{__method__}() and the 'context' component of the jobConf does not contain a valid 'jobType' field. Must specify the type/category of job being submitted somehow."
        elsif(!JOB_TYPES.key?(jobType))
          raise "ERROR: the jobType provided (#{jobType.inspect}) is not one of the acceptable types. Must be one of #{JOB_TYPES.keys.join(', ')}."
        else
          jobType = jobType
        end
        # - toolId (required)
        toolId = context['toolIdStr']
        raise "ERROR: the 'context' component does not contain an entry for the 'toolIdStr' field." unless(toolId and toolId =~ /\S/)
      else
        raise "ERROR: there is no 'context' component in the job configuration or the 'context' component is not a Hash."
      end
      # These key things from the context are REMOVED from the jobConfObj to ensure no conflict between the database tables that store the
      # key things and the jobConf JSON strings. When the jobConf is reconstructed (get via getJobConf()), these will be
      # properly filled in. i.e. NO REDUNDANCY, NO POSSIBLE CONFLICT.
      context = Job.cleanContext(context)
      # Use extracted and validated info to create a Job object
      # - will have appropriate defaults for new (non-queued) job; time stamps, status, etc.
      # - will need commands set, etc, as well
      job = Job.new(toolId, jobType, user, systemHost, systemType, queue, dbu)
      # Set the job conf sections
      job.inputs = inputs
      job.outputs = outputs
      job.context = context
      job.settings = settings
      # Preconditions
      if(preconditionSetSD)
        # Set & initialize specific preconditions; we do this to help prevent
        # malformed prcondition specs from being accepted and stored in the database.
        job.setPreconditions(preconditionSetSD, false)
      else
        job.setPreconditions(nil)
      end
     # Return new Job instance
      return job
    end

    # Make a unique job name (a 'job ticket') based on a prefix.
    # - Rarely, if ever, needs to be used by other code. The Job#prequeue(namePrefix) method
    #  generates a name automatcially.
    # - DO NOT generate your own names via any other method than this one. Better yet, just
    #   let prequeue() handle it for you.
    def self.generateJobName(prefix='')
      probUniqStr = "#{$$}#{prefix}#{@@globalSaltCounter += 1}#{Time.now.to_f}#{rand(64*1024*24)}"
      xorDigest = probUniqStr.xorDigest(6, :alphaNum)
      return "#{prefix}-#{xorDigest}-#{'%04d' % rand(10000)}"
    end

    # Extract the prefix portion of unique job name, assuming it was properly
    # made via the Job.generateJobName() method. Makes a best-attempt, anyway.
    # That job name method is used by infrastructure methods such as Job#prequeue()
    # so as long as things are implemented normally and correctly, using this
    # method should work nicely.
    # [+jobName+] The job name String you want to extract a prefix for, if any.
    # [+returns+] The job name prefix, which could conceivably be the empty String !
    def self.extractJobPrefix(jobName)
      retVal = ''
      if(jobName)
        jobName = jobName.strip
        components = jobName.split('-')
        if(components.size >= 2)              # Try a split based approach
          retVal = components[0, 2].join('-')
        elsif(jobName =~ /[^\-]+-[^\-]+$/)   # Try a careful pattern-based assuming was created by generateJobName()
          retVal = jobName.gsub(/-?[^\-]+-[^\-]+$/, '')
        end
      end
      return retVal
    end

    #------------------------------------------------------------------
    # INSTANCE METHODS
    #------------------------------------------------------------------
    # Create new Job object.
    # - makes a very basic Job object with empty job configuration sections, default time stamps,
    #   no preconditions, no directives, etc.
    # - if making a job object for a job that already exists (has already been entered
    #   into the prequeue table)--DO NOT USE THIS DIRECTLY! THERE ARE BETTER CONVENIENCE METHODS!
    #   . rather, use on the the class methods Job.fromName(), Job.fromHostTypeAndSystemJobId()
    # - even for a brand-new job, it's best to go through  Job.newFromJobConf() rather than
    #   using this manually.
    # [+toolId+]  String containing the identifier string for the "tool" the job runs.
    # [+type+]    Symbol (from BRL::Genboree::DBUtil::JOB_TYPES) indicating the category or type of job.
    # [+user+]    String containing the Genboree login of the user for whom the job will be run.
    # [+systemHost+]  String containing the FQDN of the host machine where the target batch system runs
    # [+systemType+]  String containing the type of batch system running on host where the job should be submitted.
    #                 (There could be more that one kind batch system running on host, in theory.)
    # [+queue+]   String containing the name of the target "queue" (or analogous resource set identifier) for the job
    # [+dbu+]     [optional; default=nil] DBUtil instance already configured and ready to use for :otherDB.
    def initialize(toolId, type, user, systemHost, systemType, queue, dbu=nil)
      # WHY ARE YOU STILL USING THIS? THERE ARE BETTER CONVENIENCE METHODS!
      # Validate
      raise "ERROR: the type argument #{type.inspect} must be one of the supported job types: #{JOB_TYPES.keys.join(', ')}" unless(JOB_TYPES.key?(type))
      @dbu = (dbu || self.class.getDBUtil())
      @dbRecId = nil
      # Core job info fields
      @name = nil
      @namePrefix = MISSING_NAME_PREFIX
      @toolId = toolId
      @user = user
      @type = type
      @status = :entered
      @submitHost = JOB_DEFAULT_SUBMITHOST
      # Job default dates
      @entryDate = Time.now()
      @submitDate = JOB_DEFAULT_TIME
      @execStartDate = JOB_DEFAULT_TIME
      @execEndDate = JOB_DEFAULT_TIME
      # Job default config sections
      @inputs = @outputs = @context = @settings = nil
      # Job default commands
      @preCommands = @postCommands = @commands = nil
      # Job scheduling info
      @preconditionSet = nil
      if(queue != 'none')
        @batchSystemInfo = BatchSystemInfo.new(systemHost, systemType)
        @batchSystemInfo.queue = queue
      else # is either a utillty job or a local job
        @jobHost = systemHost
        @jobQueue = queue
        @jobSystemType = systemType
      end
    end

    # Call this to do a best-attempt clean up of the state of this object, typically
    # to encourage garbage-collection and freeing of memory.
    def clear(clearDbu=true)
      (@dbu.clear(true) rescue false) if(@dbu and clearDbu)
      @name = @namePrefix = @toolId = @user = @type = @status = nil
      @entryDate = @submitDate = @execStartDate = @execEndDate = nil
      @inputs.clear() if(@inputs.is_a?(Array))
      @outputs.clear() if(@outputs.is_a?(Array))
      @settings.clear() if(@settings.is_a?(Hash))
      @context.clear() if(@context.is_a?(Hash))
      @inputs = @outputs = @settings = @context = nil
      @preCommands.clear() if(@preCommands.is_a?(Array))
      @postCommands.clear() if(@postCommands.is_a?(Array))
      @commands.clear() if(@commands.is_a?(Array))
      @preCommands = @postCommands = @commands = nil
      @batchSystemInfo.clear() unless(@batchSystemInfo.nil?)
      @batchSystem = nil
      @preconditionSet.clear() if(@preconditionSet.respond_to?(:clear))
      @preconditionSet = nil
    end

    def hasPreconditions?()
      retVal = false
      if(@preconditionSet and @preconditionSet.is_a?(PreconditionSet) and (@preconditionSet.count() > 0))
        retVal = true
      end
      return retVal
    end

    # Get a suitable manager object for this job. Managers have aspects that are BATCH SYSTEM-specific,
    # so this will be a instance of a sub-class of BRL::Genboree::Prequeue::Manager. If @batchSystemInfo
    # is nil, then something is wrong or has been left in the middle of changes and this will return nil.
    def manager()
      retVal = nil
      if(@batchSystemInfo)
        retVal = @batchSystemInfo.getManagerInstance(self)
      end
      return retVal
    end

    # Get a suitable submitter object for this job. Submitters are largely BATCH SYSTEM-specific,
    # so this will be a instance of a sub-class of BRL::Genboree::Prequeue::Submitter. If @batchSystemInfo
    # is nil, then something is wrong or has been left in the middle of changes and this will return nil.
    def submitter()
      retVal = nil
      if(@batchSystemInfo)
        retVal = @batchSystemInfo.getSubmitterInstance(self)
      end
      return retVal
    end

    # Submit this existing job to the BATCH SYSTEM. The job presumably was previously prequeued() and
    # exists in the prequeue table (and you created this instance using Job.fromName() or
    # using Job.fromHostTypeAndSystemJobId() probably).
    #
    # If you want to prequeue a new job, this is NOT THE RIGHT METHOD. To prequeue() a brand new
    # job, use the Job#prequeue() method!
    def submit()
      submitter = @batchSystemInfo.getSubmitterInstance(self)
      return submitter.submit(self)
    end

    # Cancel this existing job. The job presumable was previously prequeued() and now you
    # want to cancel it. If the job has been submitted to the batch system, the batch system will
    # be used to cancel/kill the job. If hasn't been submitted, it won't be (and its status) will
    # just be shifted directly to 'canceled'). If the job has completed or failed or was previously
    # canceled, this will do nothing.
    def cancel()
      manager = @batchSystemInfo.getManagerInstance(self)
      return manager.cancelJob(self)
    end

    # Insert a new job into the prequeue.
    #
    # Typical usage: job.prequeue('wbJob-someToolIdStr')
    #
    # Typically, namePrefix will be provided at this time, unless you specifically set it
    # via the accessor (job.namePrefix = 'blah...') for some reason.
    # @param [String] namePrefix The prefix that will appear before the unique part of the job ticket/name.
    # @return [String] The unique job name for the job.
    def prequeue(namePrefix=@namePrefix)
      # Validate
      # - is the job type one of the official ones?
      raise "ERROR: the job type #{@type.inspect} must be one of the supported job types: #{JOB_TYPES.keys.join(', ').inspect}" unless(JOB_TYPES.key?(@type))
      # - is the job status one of the official ones?
      raise "ERROR: the job status #{@status.inspect} must be one of the supported statuses: #{JOB_STATUSES.keys.join(', ').inspect}" unless(JOB_STATUSES.key?(@status))
      # - can get a record for the batch system host & type?
      if(@type != 'utilityJob' and @type != 'gbLocalTaskWrapperJob')
        # - have a queue?
        raise "ERROR: the job has no target queue in which to run on the batch system." unless(@batchSystemInfo.queue and @batchSystemInfo.queue =~ /\S/)
        systemRows = @dbu.selectSystemByHost(@batchSystemInfo.host, @batchSystemInfo.type)
        unless(systemRows and systemRows.size == 1)
          raise "ERROR: could not find a target batch system of type #{@batchSystemInfo.type} registered for host #{@batchSystemInfo.host}."
        else
          systemsRecId = systemRows.first['id']
        end
      end
      # - can get a Genboree user record for the @user?
      userRows = @dbu.getUserByName(@user)
      unless(userRows and userRows.size == 1)
        raise "ERROR: could not find a Genboree user record for user login #{@user.inspect}."
      end
      # Make a new job name for it, repeating until find a job name not yet in use?
      nameValid = false
      while(!nameValid)
        # Generate a new probably-unique job name using namePrefix
        self.makeNewName(namePrefix)
        # Check if it is in use
        jobRows = @dbu.selectJobByName(@name)
        nameValid = true if(jobRows.nil? or jobRows.empty?)
      end
      # Clean context hash
      @context = Job.cleanContext(@context)
      # Add submitHost to context as best as possible
      @submitHost = JOB_DEFAULT_SUBMITHOST unless(@submitHost and @submitHost =~ /\S/)
      @context['submitHost'] = @submitHost
      # Insert table records where appropriate, get id (or nil if none for this job)
      # - commands record
      @commands = [ @commands ] if(@commands and @commands.is_a?(String))
      @preCommands = [ @preCommands ] if(@preCommands and @preCommands.is_a?(String))
      @postCommands = [ @postCommands ] if(@postCommands.is_a?(String))
      if(@commands or @preCommands or @postCommands)
        commandsStr = ((@commands and !@commands.empty?) ? @commands.to_json : nil)
        preCommandsStr = ((@preCommands and !@preCommands.empty?) ? @preCommands.to_json : nil)
        postCommandsStr = ((@postCommands  and !@postCommands.empty?) ? @postCommands.to_json : nil)
        numInserted = @dbu.insertCommand(commandsStr, preCommandsStr, postCommandsStr)
        commandsRecId = @dbu.lastInsertId
      else
        commandsRecId = nil
      end
      # - inputConfs record
      @inputs = [ @inputs ] if(@inputs and @inputs.is_a?(String))
      if(@inputs and !@inputs.empty?)
        inputsStr = @inputs.to_json
        numInserted = @dbu.insertInputConf(inputsStr)
        inputConfsRecId = @dbu.lastInsertId
      else
        inputConfsRecId = nil
      end
      # - outputConfs record
      @outputs = [ @outputs ] if(@outputs and @outputs.is_a?(String))
      if(@outputs and !@outputs.empty?)
        outputsStr = @outputs.to_json
        numInserted = @dbu.insertOutputConf(outputsStr)
        outputConfsRecId = @dbu.lastInsertId
      else
        outputConfsRecId = nil
      end
      # - settingsConfs record
      if(@settings and !@settings.empty?)
        settingsStr = @settings.to_json
        numInserted = @dbu.insertSettingsConf(settingsStr)
        settingsConfsRecId = @dbu.lastInsertId
      else
        settingsConfsRecId = nil
      end
      # - contextConfs record
      if(@context and !@context.empty?)
        contextStr = @context.to_json
        numInserted = @dbu.insertContextConf(contextStr)
        contextConfsRecId = @dbu.lastInsertId
      else
        contextConfsRecId = nil
      end
      # - preconditionSet record, get id
      if(@preconditionSet.is_a?(PreconditionSet))
        # Do we already have a db record id for the preconditionSet (i.e. already inserted or something)
        if(@preconditionSet.dbRecId)
          preconditionsRecId = @preconditionSet.dbRecId # use it
        else
          # No database id for the PreconditionSet, insert a new record.
          # - store just the reocrd, do not attempt to autolink to the job record (will probably fail right now)
          numInserted = @preconditionSet.store(@dbu, false)
          preconditionsRecId = @dbu.lastInsertId
        end
      else
        preconditionsRecId = nil
      end
      # - systemInfos
      # For jobs being launched on a cluster (Torque/Maui in our case)
      if(@type != 'utilityJob' and @type != 'gbLocalTaskWrapperJob')
        directives = @batchSystemInfo.getDirectives(self)
        if(directives.nil? or (directives and directives.empty?))
          directivesStr = nil
        else
          directivesStr = directives.to_json
        end
        numInserted = @dbu.insertSystemInfo(@batchSystemInfo.host, @batchSystemInfo.type, @batchSystemInfo.queue, directivesStr, @batchSystemInfo.systemJobId, systemsRecId)
        systemInfosRecId = @dbu.lastInsertId
      else # For utility/local jobs
        numInserted = @dbu.insertSystemInfo(@jobHost, @jobSystemType, @jobQueue, directivesStr, systemJobId=nil)
        systemInfosRecId = @dbu.lastInsertId
      end
      # - jobs record
      numInserted = @dbu.insertJob(@name, @user, @toolId, @type, @status, @entryDate, @submitDate, @execStartDate, @execStartDate)
      jobsRecId = @dbu.lastInsertId
      # Insert final job2config mapping record.
      numInserted = @dbu.insertJob2Config(jobsRecId, systemInfosRecId, commandsRecId, inputConfsRecId, outputConfsRecId, contextConfsRecId, settingsConfsRecId, preconditionsRecId)
      unless(numInserted == 1)
        raise "ERROR: could not insert new job properly. MySQL indicates #{numInserted.inspect} records inserted for the job2config table."
      end
      # Return the job name that was generated
      return @name
    end

    # Generate a "jobConf" Hash object for this job. Typically used for existing jobs that have already
    # been prequeued via prequeue() (and thus this Job object was created via Job.fromName() or
    # Job.fromHostTypeAndSystemJobId()).
    #
    # The top-level keys in the Hash are:
    #   - 'inputs'    => Array of Strings typically containing REST API URLs (or some sort of file location path thing)
    #   - 'outputs'   => Array of Strings typically contianing REST API URLs (or some sort of file/dir locations)
    #   - 'settings'  => Hash of tool settings fields mapped to tool-specific values
    #   - 'context'   => Hash of job-related (and batch system related) fields mapped to values.
    def toJobConf(inclPreconditions=false)
      if(@name)
        jobConf = {}
        # Set conf components
        jobConf['inputs'] = (@inputs || [])
        jobConf['outputs'] = (@outputs || [])
        jobConf['settings'] = (@settings || {})
        jobConf['context'] = context = (@context || {})
        if(inclPreconditions)
          if(@preconditionSet.is_a?(PreconditionSet))
            jobConf['preconditionSet'] = @preconditionSet.toStructuredData()
          else
            jobConf['preconditionSet'] = nil
          end
        end

        # Set specific context fields (inputs, outputs, and settings are for
        # consumption by the job itself not the framework). The job may have some
        # stuff in context as well. But they should not be framework things.
        # - jobId = job name
        context['jobId'] = @name
        # - jobType
        context['jobType'] = @type.to_s
        # - toolIdStr
        context['toolIdStr'] = @toolId
        # - userLogin
        context['userLogin'] = @user
        # - systemHost
        context['systemHost'] = @batchSystemInfo.host
        # - systemType
        context['systemType'] = @batchSystemInfo.type
        # - queue
        context['queue'] = @batchSystemInfo.queue
        # - adminEmails (older tool wrappers only support gbAdminEmail which should be just the first of these)
        adminEmails = @batchSystemInfo.getAdminEmails(self)
        context['adminEmails'] = adminEmails.join(',')
        context['gbAdminEmail'] = adminEmails.first
        # Set other things by filling them in dynamically (deliberately overwrite
        # any of these that were inappropriately in the context section when the
        # job was made)
        # - user name, email, and userId
        userRows = @dbu.getUserByName(@user)
        if(userRows and !userRows.empty?)
          row = userRows.first
          context['userId'] = row['userId']
          context['userEmail'] = row['email']
          context['userFirstName'] = row['firstName']
          context['userLastName'] = row['lastName']
        else
          raise "ERROR: attempted to retrieve Genboree user info for user login #{@user.inspect} but no records retrieved! Jobs must be run on behalf of some Genboree user."
        end
        # Only a SPECIFIC submitter will know what the appropriate context['scratchDir'] should be.
        submitter = self.submitter()
        context['scratchDir'] = submitter.getScratchDir(self)
      else
        raise "ERROR: you have tried to create Job Configuration data structure for a job that has no unique job name yet. Probably it has not been entered into the prequue via the Job#prequeue() method."
      end
      # Return the job conf object. Will be read to do a to_json() on or whatever
      return jobConf
    end

    # Get the name prefix for the job. If known...because Job object was
    # prequeued with prequeue() or something...then we return exactly the prefix.
    # Else, we use the match class method extractJobPrefix() to derive the
    # the [probably] job prefix from the name.
    # [+returns+] The job name prefix, which could conceivably be the empty String !
    def extractJobPrefix()
      retVal = ''
      if(@namePrefix and @namePrefix != MISSING_NAME_PREFIX)
        # Then this Job object was prequeued with prequeue() or something, not made from DB row/jobConf.
        # In this case we KNOW the name prefix
        retVal = @namePrefix
      else
        # This Job object likely made from the DB row or a jobConf or something and
        # we have to DERIVE (guess) the name prefix. There's a class method for exactly that.
        retVal = Job.extractJobPrefix(@name)
      end
      return retVal
    end

    # Check the preconditons, if any, and return @Boolean@ indicating if preconditions
    # all met or not. If there are no preconditions for this job, returns true since inherently all met.
    # @return [Boolean] indicating that all preconditions are met [or none] or some have not [yet] been met.
    def checkPreconditions()
      retVal = false
      if(@preconditionSet.nil? or @preconditionSet.empty?)
        # If none, inherently all met
        retVal = true
      elsif(@preconditionSet.allMet?)
        # All the preconditions are known to be met
        retVal = true
      else
        # Else, update the status of the preconditions and see if all met now.
        retVal = @preconditionSet.update()
      end
      return retVal
    end

    #------------------------------------------------------------------
    # SPECIAL STATE LOADERS
    # - these methods retrieve additional job information from database storage
    #   which is not retirevied by default
    # - often this info is for speicifc job-related tasks: like getting the
    #   commands info to submit the job to an actual batch system, or like
    #   getting the preconditionSet object for assessment by the prequeue scheduler
    #------------------------------------------------------------------

    # Load the commands table values, so we have access to the job pre, post, and
    # regular commands.
    def loadCommands()
      retVal = nil
      rows = @dbu.selectJobCommandsByJobName(@name)
      if(rows and !rows.empty?)
        row = rows.first
        # These are to be JSON-formated Arrays. But also could be nil. Parse carefully.
        @preCommands = row['preCommands'].to_s.strip
        @preCommands = ((@preCommands =~ /\S/) ? JSON.parse(@preCommands) : [])
        @postCommands = row['postCommands'].to_s.strip
        @postCommands = ((@postCommands =~ /\S/) ? JSON.parse(@postCommands) : [])
        @commands = row['commands'].to_s.strip
        @commands = ((@commands =~ /\S/) ? JSON.parse(@commands) : [])
        retVal = true
      else
        @preCommands = @postCommands = @commands = nil
      end
      return retVal
    end

    #------------------------------------------------------------------
    # SPECIAL STATE SETTERS
    # - these methods just affect the object state
    # - they DO NOT update the corresponding rows in the database
    #   (there are matching update*() methods for that)
    # - generally used to set up a new object properly from existing info
    #------------------------------------------------------------------

    # Set the name. Are you sure you want to do this? Normally only done by infrastructure code.
    # The Job#prequeue() method assigns appropriate unique job names.
    def setName(name)
      @name = name
    end

    # Set the queue.
    def setQueue(queue)
      @batchSystemInfo.queue = queue
    end

    # Set the job status. Remember, will not update the status in the jobs table.
    def setStatus(status)
      # Validate
      status = status.to_sym
      raise "ERROR: the status argument #{status.inspect} must be one of the support job types: #{JOB_STATUSES.keys.join(', ').inspect}" unless(JOB_STATUSES.key?(status))
      @status = status
      return @status
    end

    # Set the job systemJobId. Remember, will not update the systemJobId in the prequeue database.
    def setSystemJobId(systemJobId)
      return @batchSystemInfo.setSystemJobId(systemJobId)
    end

    # Set the job prequeue-entry date. Remember, will not set the entryDate in the jobs table.
    def setEntryDate(time=Time.now())
      @entryDate = time
      return @entryDate
    end

    # Set the job batch system submission date. Remember, will not set the submitDate in the jobs table.
    def setSubmitDate(time=Time.now())
      @submitDate = time
      return @submitDate
    end

    # Set the job execution start date. Remember, will not set the execStartDate in the jobs table.
    def setExecStartDate(time=Time.now())
      @execStartDate = time
      return @execStartDate
    end

    # Set the job execution end date. Remember, will not set the execEndDate in the jobs table.
    def setExecEndDate(time=Time.now())
      @execEndDate = time
      return @execEndDate
    end

    # Set the job directives.
    def setDirectives(directives)
      return @batchSystemInfo.setDirectives(directives)
    end

    # Set the job preconditionSet object (or nil)
    # @param [BRL::Genboree::Prequeue::PreconditionSet, String, Hash, nil] preconditionSet the PreconditionSet for this job,
    #   or nil if no preconditions for this job. The preconditions set can be provided as a properly formatted JSON String,
    #   a stuctured data Hash with the required fields, or an already created PreconditionSet instance.
    # @param  [Boolean] lazyInit indicating whether individual precondition objects should be created later nor now.
    # @return [PreconditionSet]
    # @raise [ArgumentError] if the preconditions argument is not a {PreconditionSet} instance.
    def setPreconditions(preconditionSet, lazyInit=true)
      if(preconditionSet.is_a?(String))
        # assume JSON string given
        @preconditionSet = PreconditionSet.from_json(preconditionSet)
      elsif(preconditionSet.is_a?(Hash))
        # assume structured data Hash describing the precondition set
        @preconditionSet = PreconditionSet.fromStructuredData(self, preconditionSet)
      elsif(preconditionSet.is_a?(BRL::Genboree::Prequeue::PreconditionSet))
        @preconditionSet = preconditionSet
      else
        @preconditionSet = nil
      end
      if(@preconditionSet) # not nil and now a PreconditionSet instance for sure
        # link to this job object
        @preconditionSet.job = self
        # Force parsing/initialization of individual preconditions (mainly for validation of newly submitted hash/string preconditions specs)?
        @preconditionSet.initPreconditionObjects() unless(lazyInit)
      end
      return @preconditionSet
    end

    #------------------------------------------------------------------
    # STATE & STORAGE UPDATERS
    # - these methods DO update the corresponding database record
    # - generally used to put new info to the database
    # - NOT appropriate for simply setting object state from existing
    #   job record (there are setter methods for that)
    #------------------------------------------------------------------

    # Update the job's status.
    def updateStatus(status, updateTimeStamp=true)
      retVal = nil
      # Validate
      raise "ERROR: the status argument #{status.inspect} must be one of the support job types: #{JOB_STATUSES.keys.join('. ')}" unless(JOB_STATUSES.key?(status))
      # Set status
      manager = @batchSystemInfo.getManagerInstance(self)
      rowsUpdated = manager.updateStatus(self, status, updateTimeStamp)
      if((@status == status and rowsUpdated == 0) or (@status != status and rowsUpdated== 1)) # Either correctly didn't change or correctly changed
        retVal = status
        @status = retVal
      else  # Change didn't happen as expected or happened when really shouldn't have
        raise "ERROR: The new status #{status.inspect} is #{(@status == status) ? 'the same as' : 'different than'} the old status #{@status.inspect} but #{rowsUpdated.inspect} table rows were changed, which is wrong for that scenario. Probable bug."
      end
      return retVal
    end

    # Used for utility jobs: update only execEndDate and status
    # [+status+]
    def updateStatusForNonQueuedJobs(status)
      jobRecs = @dbu.selectJobByName(@name)
      jobId = jobRecs.first['id']
      @dbu.updateJobExecEndDateById(jobId)
      @dbu.updateJobStatusById(jobId, status)
    end

    # Update the job's batch system specific systemJobId. Usually happens when submitted to the batch system.
    def updateSystemJobId(systemJobId)
      return @batchSystemInfo.updateSystemJobId(self, systemJobId)
    end

    # Update the job's prequeue-entry date.
    def updateEntryDate(time=Time.now())
      retVal = nil
      manager = @batchSystemInfo.getManagerInstance(self)
      retVal = manager.updateEntryDate(job, time)
      @entryDate = retVal
      return retVal
    end

    # Update the job's batch system submission date.
    def updateSubmitDate(time=Time.now())
      manager = @batchSystemInfo.getManagerInstance(self)
      retVal = manager.updateSubmitDate(job, time)
      @submitDate = retVal
      return retVal
    end

    # Update the job's execution start date.
    def updateExecStartDate(time=Time.now())
      manager = @batchSystemInfo.getManagerInstance(self)
      retVal = manager.updateExecStartDate(job, time)
      @execStartDate = retVal
      return retVal
    end

    # Update the job's execustion end date.
    def updateExecEndDate(time=Time.now())
      manager = @batchSystemInfo.getManagerInstance(self)
      retVal = manager.updateExecEndDate(job, time)
      @execEndDate = retVal
      return retVal
    end

    # Update the job's preconditions in the the database.
    # @param [Boolean] doCheck indicating whether we should first call checkPreconditions() before updating
    #   the database store.
    # @param [Boolean] force indicating whether not to forcibly update the precondition table record,
    #   even if heuristics indicate no changes seem to have been made.
    # @return [Fixnum] the number of precondition rows updated (should be 1 if change noted, 0 if no change)
    def updatePreconditions(doCheck=false, force=false)
      retVal = 0
      # Only update database store if we have preconditions in the first place
      unless(@preconditionSet.nil? or @preconditionSet.empty?)
        # Are we suppose to check current state of preconditionSet first?
        self.checkPreconditions() if(doCheck)
        retVal = @preconditionSet.store(@dbu, false, force)
      end
      return retVal
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------

    # Generate a probably unique job name.
    def makeNewName(namePrefix=@namePrefix)
      @namePrefix = namePrefix
      @name = self.class.generateJobName(namePrefix)
      return @name
    end

    # Class method for getting a new Job object using a detailed
    # result set row. For internal use by this class.
    def self.getJobFromJobFullInfoRow(jobFullInfoRow, dbu=nil)
      job = nil
      # Create basic job object (mostly empty). None of these will be NULL
      toolId = jobFullInfoRow['toolId']
      jobType = jobFullInfoRow['type']
      user = jobFullInfoRow['user']
      host = jobFullInfoRow['host']
      systemType = jobFullInfoRow['systemType']
      queue = jobFullInfoRow['queue']
      job = self.new(toolId, jobType, user, host, systemType, queue, dbu)
      job.dbRecId = jobFullInfoRow['id']
      # Set existing name (no need to generate a new one). Will not be NULL.
      job.setName(jobFullInfoRow['name'])
      # Set the status.  Will not be NULL.
      status = jobFullInfoRow['status'].to_sym
      job.setStatus(status)
      # Set the time stamps. Will not be NULL.
      job.setEntryDate(jobFullInfoRow['entryDate'])
      job.setSubmitDate(jobFullInfoRow['submitDate'])
      job.setExecStartDate(jobFullInfoRow['execStartDate'])
      job.setExecEndDate(jobFullInfoRow['execEndDate'])
      # Set the job config sections, after parsing each if appropriate. These may be NULL.
      # - inputs
      inputsConf = jobFullInfoRow['input'].to_s.strip
      job.inputs = ((inputsConf =~ /\S/) ? JSON.parse(inputsConf) : [])
      # - outputs
      outputsConf = jobFullInfoRow['output'].to_s.strip
      job.outputs = ((outputsConf =~ /\S/) ? JSON.parse(outputsConf) : [])
      # - context
      contextConf = jobFullInfoRow['context'].to_s.strip
      job.context = ((contextConf =~ /\S/) ? JSON.parse(contextConf) : {})
      # - settings
      settingsConf = jobFullInfoRow['settings'].to_s.strip
      job.settings = ((settingsConf =~ /\S/) ? JSON.parse(settingsConf) : {})
      # Set non-default BatchSystemInfo object details. May be NULL.
      systemJobId = jobFullInfoRow['systemJobId']
      if(systemJobId) # We can replace lite batchSystemInfo with a fully filled-in BatchSystemInfo
        batchSystemInfo = BatchSystemInfo.fromHostTypeAndSystemJobId(host, systemType, systemJobId, job.dbu)
        job.batchSystemInfo = batchSystemInfo
      end
      # Instantiate Preconditions object if appropriate
      preconditionId = jobFullInfoRow['preconditionId']
      if(preconditionId)
        # Get precondition db record
        preconditionsRows = job.dbu.selectPreconditionsById(preconditionId)
        if(preconditionsRows and !preconditionsRows.empty?)
          preconditionsRow = preconditionsRows.first
          preconditionsSet = BRL::Genboree::Prequeue::PreconditionSet.fromJobPreconditionsRow(job, preconditionsRow)
          job.setPreconditions(preconditionsSet)
        else
          # No preconditions rows matching that id
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "DB CORRUPTION / CODE BUG: Attempted to retrieve preconditions row using an invalid id (#{preconditionId.inspect}. Continuing, but something may be very wrong.")
          job.setPreconditions(nil)
        end
      else
        # There are no preconditions associated with the job.
        job.setPreconditions(nil)
      end
      # Return configured Job object
      return job
    end

    # Clean fields out of a context Hash which are specifically stored by the prequeue tables.
    # Some of these are recognised and processed by the Job#prequeue() method, but before
    # storing the contextConfs record for the job, these special fields are REMOVED so only
    # the prequeue database tables have the info (no redundancy == no potentital conflict)
    # @param [Hash{String=>Object}] context the context that needs cleaning. Will not be modified itself.
    # @param [Boolean] full indicating if the context should be aggressively cleaned (e.g. from user)
    #   or just partially prior to prequeuing and db insertion
    # @return [Hash] the cleaned context, a new object build from context argument
    def self.cleanContext(context, full=false)
      if(context)
        retVal = context.dup
        if(full)
          JOB_CONTEXT_CLEAN_KEYS_FULL.each { |key| retVal.delete(key) }
        else
          JOB_CONTEXT_CLEAN_KEYS_PREP_FOR_PREQUEUE.each { |key| retVal.delete(key) }
        end
        # This should not be saved in context records. Should have been used up by now
        # as part of, say, calling prequeue().
      end
      return retVal
    end

    # Get and activate a suitable DBUtil instance.
    # [+dbrcKey+] [optional] DBRC key to use for prequeue access if one in genboree config file should not be used
    def self.getDBUtil(dbrcKey=nil)
      # First make a dbu using standard Genboree main approach (we need Genboree AND prequeue via otherDB!)
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil)
      # Now connect the other DB handle to the prequeue database
      unless(dbrcKey)
        dbrcKey = genbConf.prequeueDbrcKey
      end
      # Connect to main Genboree database and to Prequeue database
      dbu.connectToMainGenbDb(true)
      dbu.connectToOtherDb(dbrcKey, true)
      return dbu
    end
  end # class Job
end ; end ; end # module BRL ; module Genboree ; module Prequeue
