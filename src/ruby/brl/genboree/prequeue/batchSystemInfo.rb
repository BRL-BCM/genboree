#!/usr/bin/env ruby
$VERBOSE = nil


# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/prequeue/systems/submitter'
require 'brl/genboree/prequeue/systems/manager'

module BRL ; module Genboree ; module Prequeue
  # Batch system information class
  # - Used to represent batch system information for a job
  # - e.g. queue name, system type, system host, system id for job (if available), etc
  # - Can also get the system-specific Submitter instance and Manager instance that can
  #   handle this job.
  class BatchSystemInfo
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES and ONE-TIME RESOURCE DISCOVERY
    #------------------------------------------------------------------
    class << self
      # Set up class instance variables
      attr_accessor :resourcesLoaded, :submitters, :managers, :submittersByJobName, :managersByJobName
      BatchSystemInfo.resourcesLoaded = false
      BatchSystemInfo.submitters = {}
      BatchSystemInfo.managers = {}
      BatchSystemInfo.submittersByJobName = {}
      BatchSystemInfo.managersByJobName = {}
    end

    # Resource discovery: Find submitter & manager classes
    unless(BatchSystemInfo.resourcesLoaded or ((GenboreeRESTRackup rescue nil) and GenboreeRESTRackup.classDiscoveryDone[self]))
      # Mark resources as loaded (so doesn't try again)
      BatchSystemInfo.resourcesLoaded = true
      # Record that we've done this class's discovery. Must do before start requiring.
      # - Must use already-defined global store of this info to prevent dependency requires while trying to define this class
      #   re-entering this discovery block over and over and over.
      (GenboreeRESTRackup.classDiscoveryDone[self] = true) if(GenboreeRESTRackup rescue nil)
      # Try to lazy-load (require) each file found in the resourcePaths.
      $LOAD_PATH.sort.each { |topLevel|
        if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
          [ "brl/genboree/prequeue/systems/" ].each { |rsrcPath|
            rsrcFiles = Dir["#{topLevel}/#{rsrcPath}/*/*.rb"]
            rsrcFiles.sort.each { |rsrcFile|
              begin
                require rsrcFile
              rescue Exception => err # just log error and try more files
                BRL::Genboree::GenboreeUtil.logError("ERROR: #{__FILE__} => failed to auto-require file '#{rsrcFile.inspect}'.", err)
              end
            }
          }
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "found batch system class files")
      # Find all the classes in BRL::Genboree::Prequeue::Systems and
      # identify those that inherit from BRL::Genboree::Prequeue::Systems::Submitter
      # or from BRL::Genboree::Prequeue::Systems::Manager
      BRL::Genboree::Prequeue::Systems.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::Genboree::Prequeue::Systems.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::Genboree::Prequeue::Systems::Submitter
        if(const.is_a?(Class))
          # Is const a SUB-class we are interested in?
          if(const.ancestors.include?(BRL::Genboree::Prequeue::Systems::Submitter) and const != BRL::Genboree::Prequeue::Systems::Submitter)
            BatchSystemInfo.submitters[const::SYSTEM_TYPE] = const
          elsif(const.ancestors.include?(BRL::Genboree::Prequeue::Systems::Manager) and const != BRL::Genboree::Prequeue::Systems::Manager)
            BatchSystemInfo.managers[const::SYSTEM_TYPE] = const
          end
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered batch system classes")
    end

    #------------------------------------------------------------------
    # ACCESSORS
    #------------------------------------------------------------------
    # String containing the batch system type
    attr_accessor :type
    # String containing the host name where the batch system lives (where jobs are submitted and the scheduler runs etc)
    attr_accessor :host
    # String containing the queue name to use at the specified batch system
    attr_accessor :queue
    # [read-only] String ocntaining the id used by the batch system to identify the job
    attr_reader :systemJobId

    #------------------------------------------------------------------
    # CLASS METHODS
    #------------------------------------------------------------------
    #------------------------------------------------------------------
    # INSTANCE METHODS
    #------------------------------------------------------------------
    # Create new BatchSystemInfo object for specified system type running
    # on host and the batch queue to use on that batch system. Mostly for internal use.
    # - this creates the basic object
    # - usually NOT used directly be code, and even the prequeue infrastructure uses
    #   preferentially uses the class methods BatchSystemInfo.fromSystemInfoDbId() or BatchSystemInfo.fromHostTypeAndSystemJobId()
    # - if creating from scratch, follow up calls to the setter methods and perhaps the updater methods
    #   will be necessary to provide queue, directives, etc.
    def initialize(host, type)
      unless(BatchSystemInfo.submitters.key?(type))
        raise "ERROR: invalid batch system type #{type.inspect}. Must be one of: #{BatchSystemInfo.submitters.keys.join(', ')}."
      end
      @adminEmails = nil
      @systemInfoDbId = @systemJobId = @queue = @directives = nil
      @host, @type = host, type
    end

    # Best-effort clearing of this object's state, to assist garbage collection.
    def clear(clearDbhCaches=true)
      @adminEmails.clear() if(@adminEmails.is_a?(Array))
      @directives.clear() if (@directives.is_a?(Hash))
      @queue = @type = @host = @jobId = @adminEmails = @directives = @systemInfoDbId = nil
    end

    # Get an appropriate Submitter sub-class object for job.
    def getSubmitterInstance(job)
      # Try cache
      submitter = BatchSystemInfo.submittersByJobName[job.name]
      unless(submitter)  # Create a new submitter instance if we don't have one yet
        submitterClass = BatchSystemInfo.submitters[@type]
        submitter = submitterClass.new(job)
        # Put in cache
        BatchSystemInfo.submittersByJobName[job.name] = submitter
      end
      return submitter
    end

    # Get an appropriate Manager sub-class object for job.
    def getManagerInstance(job)
      # Try cache
      manager = BatchSystemInfo.managersByJobName[job.name]
      unless(manager)  # Create a new manager instance if we don't have one yet
        managerClass = BatchSystemInfo.managers[@type]
        manager = managerClass.new(job)
        # Put in cache
        BatchSystemInfo.managersByJobName[job.name] = manager
      end
      return manager
    end

    # Get the directives object for job, loading from prequeue database if not loaded yet (it isn't by default)
    def getDirectives(job)
      directives = nil
      unless(@directives)  # Retrieve if not retrieved yet
        rows = job.dbu.selectFullSystemInfoByJobName(job.name)
        if(rows and !rows.empty?)
          row = rows.first
          directivesStr = row['directives'].to_s.strip
          if(directivesStr =~ /\S/)
            directives = JSON.parse(directivesStr)
            @directives = directives
          end
        end
      end
      return @directives
    end

    # Get the adminEmails Array for job, loading from prequeue database if not loaded yet (likely not)
    def getAdminEmails(job)
      unless(@adminEmails)  # Retrieve if not retrieved yet
        rows = job.dbu.selectSystemByHost(@host, @type)
        if(rows and !rows.empty?)
          row = rows.first
          @adminEmails = row['adminEmails'].split(/, */)
        else  # No matching row for type & host? error
          raise "ERROR: there is no batch system configured of type #{@type.inspect} at #{@host.inspect}. Are you missing configuration rows in the 'systems' table or perhaps have provided the wrong type or host?"
        end
      end
      return @adminEmails
    end

    #------------------------------------------------------------------
    # STATE SETTERS
    # - these methods just affect the object state
    # - they DO NO update the corresponding rows in the database
    #   (there are matching update*() methods for that)
    # - generally used to set up a new object properly from existing info
    #------------------------------------------------------------------

    # Set the directives object. Remember, does not update prequeue database tables.
    # @param [Hash] directives A {Hash} of job directives, mainly for the batch system to process.
    #                - e.g. :nodes and :ppn and :walltime are supported by TorqueMaui systems.
    def setDirectives(directives)
      @directives = directives
      return @directives
    end

    # Set the systemJobId. Remember, does not update the prequeue database tables.
    def setSystemJobId(systemJobId)
      @systemJobId = systemJobId
      return @systemJobId
    end

    # Set the adminEmails instance variable. Used internally to create object. To get the adminEmails Array,
    # use getAdminEmails(). There is no accessor.
    def setAdminEmails(adminEmails)
      @adminEmails = adminEmails
      return @adminEmails
    end

    #------------------------------------------------------------------
    # STATE & STORAGE INSERTERS
    # - these methods insert new database reocrds
    # - generally used to create new records for add new jobs and such
    #------------------------------------------------------------------
    # Inserts a new systemInfos reocrd for job and returns the table record id of the inserted record.
    def insertNewSystemInfo(job)
      retVal = nil
      raise "ERROR: a queue has not been specified using setQueue(), cannot insert a new record without knowing the queue." unless(@queue)
      if(@directives)
        directivesStr = @directivesStr.to_json
      else
        directivesStr = 'NULL'
      end
      rowsInserted = job.dbu.insertSystemInfo(@host, @type, @queue, directivesStr, @systemJobId)
      @systemInfoDbId = job.dbu.lastInsertId
      retVal = @systemInfoDbId
      return retVal
    end

    #------------------------------------------------------------------
    # STATE & STORAGE UPDATERS
    # - these methods update the corresponding database record
    # - generally used to put new info to the database
    # - NOT appropriate for simply setting object state from existing
    #   job record (there are setter methods for that)
    #------------------------------------------------------------------
    # Updates the systemJobId for job in the approrpriate systemInfo table record.
    def updateSystemJobId(job, systemJobId)
      retVal = nil
      manager = getManagerInstance(job)
      rowsUpdated = manager.updateSystemJobId(job, systemJobId)
      if((@systemJobId == systemJobId and rowsUpdated == 0) or (@systemJobId != systemJobId and rowsUpdated== 1)) # Either correctly didn't change or correctly changed
        retVal = systemJobId
        @systemJobId = retVal
      else  # Change didn't happen as expected or happened when really shouldn't have
        raise "ERROR: The new systemJobId #{systemJobId.inspect} is #{(@systemJobId == systemJobId) ? 'the same' : 'different'} than the old systemJobId #{@systemJobId.inspect} but #{rowsUpdated.inspect} table rows were changed, which is wrong for that scenario. Probable bug."
      end
      return retVal
    end

    #------------------------------------------------------------------
    # HELPER METHODS (mainly for internal use)
    #------------------------------------------------------------------
    # Create BatchSystemInfo object using a systemInfos table record id. Mostly for internal use.
    def self.fromSystemInfoDbId(systemInfoDbId, dbu=nil)
      retVal = nil
      dbu = Job.getDBUtil() if(dbu.nil?)
      # Get detailed system info using the systemInfoDbId
      fullInfoRows = dbu.selectFullSystemInfoById(systemInfoDbId)
      if(fullInfoRows and !fullInfoRows.empty?)
        # Create BatchSystemInfo from detailed system info result set
        retVal = self.fromFullInfoRow(fullInfoRows.first)
      else
        raise "ERROR: there is no systemInfos record with the id of #{systemInfoDbId.inspect}."
      end
      return retVal
    end

    # Create BatchSystemInfo object using the unique combination of batch system host, batch system type,
    # and batch system-assigned systemJobId. Mostly for internal use.
    def self.fromHostTypeAndSystemJobId(host, type, systemJobId, dbu=nil)
      batchSystemInfo = nil
      dbu = Job.getDBUtil() if(dbu.nil?)
      # Get detailed system info using the systemInfoDbId
      fullInfoRows = dbu.selectFullSystemInfoByHostTypeAndSystemJobId(host, type, systemJobId)
      if(fullInfoRows and !fullInfoRows.empty?)
        # Create BatchSystemInfo from detailed system info result set
        batchSystemInfo = self.fromFullInfoRow(fullInfoRows.first)
      else
        raise "ERROR: there is no systemInfos record with a systemJobId of #{systemJobId.inspect} associated with a system of type #{type.inspect} on host #{host.inspect}."
      end
      return batchSystemInfo
    end

    # Class method for getting a new BatchSystemInfo object using a detailed
    # result set row. For internal use by this class.
    def self.fromFullInfoRow(batchSystemFullInfoRow)
      batchSystemInfo = nil
      # Create basic object
      host = batchSystemFullInfoRow['host']
      type = batchSystemFullInfoRow['type']
      batchSystemInfo = BatchSystemInfo.new(host, type)
      # Add the queue, since that should be available in the row
      batchSystemInfo.queue = batchSystemFullInfoRow['queue']
      # Add the admin emails
      batchSystemInfo.setAdminEmails(batchSystemFullInfoRow['adminEmails'].split(/,/))
      # Add the directives, parsing if appropriate
      directivesStr = batchSystemFullInfoRow['directives'].to_s.strip
      if(directivesStr =~ /\S/)
        directives = JSON.parse(directivesStr)
        batchSystemInfo.setDirectives(directives)
      end
      # Add the systemJobId if available
      systemJobId = batchSystemFullInfoRow['systemJobId']
      if(systemJobId)
        batchSystemInfo.setSystemJobId(systemJobId)
      end
      # Done configuring object
      return batchSystemInfo
    end
  end # class BatchSystemInfo
end ; end ; end # module BRL ; module Genboree ; module Prequeue
