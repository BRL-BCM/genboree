#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'time'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/prequeue/precondition'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/data/textEntity'

module BRL ; module Genboree ; module Prequeue
  # @api BRL Ruby - prequeue
  # @api BRL RUby - preconditions
  class PreconditionSet

    # ----------------------------------------------------------------
    # CONSTANTS
    # ----------------------------------------------------------------
    JOB_STATUS_API_PATH = "/REST/v1/jobs/status?format=json_pretty"

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [Fixnum, nil] the db record id of the preconditions table record _if known_
    attr_accessor :dbRecId
    # @return [Hash] the prconditions table row this object initially created from (if any)
    attr_accessor :row
    # @return [BRL::Genboree::Prequeue::Job] the job having this PreconditionSet
    attr_accessor :job
    # @return [Boolean] indicating whether, by design, if it's expected the precoditions may never all be matched
    attr_accessor :willNeverMatch
    # @return [Boolean] indicating if some or all the preconditions expired before being met (if they ever would be)
    attr_accessor :someExpired
    # @return [Fixnum]  the number of preconditions met so far
    attr_accessor :numMet
    # @return [String] JSON text containiing the specific precondition object specifications
    attr_accessor :preconditionsSpec
    # @return [Array<BRL::Genboree::Prequeue::Precondition>] containing specific precondtition objects.
    #   Created via initPreconditionObjects() usually, and only on demand (lazily)
    attr_accessor :preconditions
    # @return [Array<URI>] containing URI objects corresponding to jobs upon which this job is dependent (if any). This can be used
    #   to pre-fetch or do other preparation work prior to evaluating each [possibly-dependency-job-related] condition's
    #   status.
    attr_accessor :dependencyJobUrls

    # ------------------------------------------------------------------
    # CLASS METHODS
    # ------------------------------------------------------------------

    # Instantiate using a row from the preconditions DB table
    # @note For performance reasons, individual preconditions are not parsed
    #   and not instantiated from the 'preconditions' column by default. If all
    #   specific preconditions have been met (count == numMet) then no need to
    #   instantiate bunch of unneeded precondition objects. Similarly, if preconditions
    #   not being examined and part of Job object for some other goal, why create
    #   precondition objects unnecessarily. You can force it to happen now using the
    #   @lazyInit@ parameter.
    # @note To init precondition objects from the JSON in the 'preconditions' column
    #   call PreconditionSet#initPreconditionObjects().
    # @param  [BRL::Genboree::Prequeue::Job] job the job having this PreconditionSet
    # @param  [Hash]    row the preconditions table row
    # @param  [Boolean] lazyInit indicating whether individual precondition objects should be created later nor now.
    # @return [PreconditionSet] instance of this class
    def self.fromJobPreconditionsRow(job, row, lazyInit=true)
      dbRecId = row['id']
      count   = row['count']
      numMet  = row['numMet']
      willNeverMatch = row['willNeverMatch']
      willNeverMatch = (willNeverMatch.is_a?(Fixnum) ? (willNeverMatch == 0 ? false : true) : willNeverMatch)
      someExpired = row['someExpired']
      someExpired = (someExpired.is_a?(Fixnum) ? (someExpired == 0 ? false : true) : someExpired)
      preconditionsStr = row['preconditions']
      # create object
      precondSet = self.new(job, preconditionsStr, willNeverMatch, someExpired, numMet)
      # forced to initialize all specific preconditions objects now?
      precondSet.initPreconditionObjects() unless(lazyInit)
      # Save the row and the row id specifically, since available and useful for store(), etc
      precondSet.dbRecId = dbRecId
      precondSet.row = row
      return precondSet
    end

    def self.from_json(jsonStr, lazyInit=true)
      jsonObj = JSON.parse(jsonStr)
      return fromStructuredData(jsonObj)
    end

    def self.fromStructuredData(job, hashSD, lazyInit=true)
      count   = (hashSD['count'] or 0)
      numMet  = (hashSD['numMet'] or 0)
      willNeverMatch = hashSD['willNeverMatch']
      willNeverMatch = false if(willNeverMatch.nil?)
      someExpired = hashSD['someExpired']
      someExpired = false if(someExpired.nil?)
      preconditionsSpec = hashSD['preconditions']
      # create object
      precondSet = self.new(job, preconditionsSpec, willNeverMatch, someExpired, numMet)
      precondSet.dbRecId = nil
      precondSet.row = nil
      # forced to initialize all specific preconditions objects now?
      precondSet.initPreconditionObjects() unless(lazyInit)
      return precondSet
    end

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    # @note For performance reasons, individual preconditions are not parsed
    #   and not instantiated from the 'preconditions' column by default. If all
    #   specific preconditions have been met (count == numMet) then no need to
    #   instantiate bunch of unneeded precondition objects. Similarly, if preconditions
    #   not being examined and part of Job object for some other goal, why create
    #   precondition objects unnecessarily. You can force it to happen now using the
    #   @lazyInit@ parameter.
    # @note To init precondition objects from the JSON in the 'preconditions' column
    #   call PreconditionSet#initPreconditionObjects().
    # @param [BRL::Genboree::Prequeue::Job] job the job having this PreconditionSet
    # @param [Array,String,nil] preconditionsSpec Either an Array of precondition Hash specs, or a JSON String containiing the specific precondition object spec Hashes. If nil, there are no preconditions (and all this is done unnecessarily).
    # @param [Boolean] willNeverMatch indicating whether, by design, if it's expected the precoditions may never all be matched
    # @param [Boolean] someExpired indicating if some or all the preconditions expired before being met (if they ever would be)
    # @param [Fixnum] numMet the number of preconditions met so far
    def initialize(job, preconditionsSpec, willNeverMatch=false, someExpired=false, numMet=0)
      @job = job
      @preconditions = @dbRecId = @row = nil
      @dependencyJobUrls = []
      @willNeverMatch, @someExpired, @numMet = willNeverMatch, someExpired, numMet
      if(preconditionsSpec.nil?)
        @preconditionsSpec = []
      elsif(preconditionsSpec.is_a?(String))
        @preconditionsSpec = JSON.parse(preconditionsSpec)
      elsif(preconditionsSpec.is_a?(Array))
        @preconditionsSpec = preconditionsSpec
      else
        raise ArgumentError, "ERROR: the preconditionsSpec must be either an Array of precondition Hash specs or a JSON encoding such. Instead it is a: #{preconditionsSpec.class}"
      end

      # Set the job's preconditions property to this instance of PreconditionSet
      @job.setPreconditions(self) if(@job)
    end

    # Clear as much of the stored state and data as possible, encouraging freeing of memory, etc.
    # @return [void]
    def clear()
      # Don't clear() the job linked to this PreconditionSet, as it may be in-use elsewhere. Just set to nil to encourage GC.
      @job = nil
      # Iterate over the specific precondition objects (if any)
      if(@preconditions and @preconditions.is_a?(Array))
        @preconditions.each { |precondition|
          precondition.clear() rescue false
        }
      end
      @preconditions.clear() rescue false
      @preconditions = nil
      @preconditionsSpec.clear() if(@preconditionsSpec.respond_to?(:clear))
      @row = nil
      @dbRecId = nil
    end

    # Get the number of preconditions in this set
    # @param [Boolean] forceInit indicating that the Array of Precondition objects should be forcibly
    #   initialized from the {@preconditionsSpec} if it has not been already. Generally not necessary, as
    #   the count can be found from the {@preconditionsSpec} used to instantiate this class if the {@preconditions}
    #   Array has not been initialized yet. Setting to @true@ is more certain, but far slower than it should be.
    # @return [Fixnum] the number of preconditions in this set
    def count(forceInit=false)
      retVal = 0
      initPreconditionObjects() if(forceInit and @preconditions.nil?)
      # If available (i.e. specific Preconditions object initialized), prefer to count the @preconditions Array
      if(@preconditions and @preconditions.is_a?(Array))
        retVal = @preconditions.size
      elsif(@preconditionsSpec and @preconditionsSpec.is_a?(Array))
        # Else use the @preconditionsSpec used to instantiate this class (e.g. perhaps prior to any initPreconditionObjects() call)
        retVal = @preconditionsSpec.size
      end
      return retVal
    end
    alias_method(:size, :count)

    # Is the preconditions set empty?
    # @param (see #count)
    # @return [Boolean] indicating whether there is at least 1 precondition in the set
    def empty?(forceInit=false)
      return (self.count(forceInit) > 0)
    end

    # Check if all conditions are known to be met. Does not call update() to determine dynamically.
    #
    # @note If NOT all met--i.e. this method returns false--make sure to call update()
    # so any un-met conditions can be evaluated!
    #
    # @return [Boolean] indicating if all conditions have been met so far. Either previously or recently.
    #   i.e. count() == @numMet. Useful to avoid unnecessary evaluations of specific preconditions if
    #   already done in the past and recorded in persistent storage.
    def allMet?()
      return (@numMet == self.count())
    end

    # Produce a basic structured Hash containing the info in this PreconditionSet
    # using Hashes, Arrays, and other core Ruby types and which are easy/fast to format
    # into string representations like JSON, YAML, etc.
    # @param [Boolean] forceInit indicating that the Array of Precondition objects should be forcibly
    #   initialized from the {@preconditionsSpec} if it has not been already. Generally not necessary, as
    #   the count can be found from the {@preconditionsSpec} used to instantiate this class if the {@preconditions}
    #   Array has not been initialized yet. Setting to @true@ is more certain, but far slower than it should be.
    # @return [Hash]
    def toStructuredData(forceInit=false)
      structuredData = {}
      # Basic information:
      structuredData["numMet"]        = @numMet.to_i
      structuredData["count"]         = self.count()
      structuredData["willNeverMatch"] = @willNeverMatch
      structuredData["someExpired"]   = @someExpired
      # Preconditions
      structuredData["preconditions"] = makePreconditionsStructuredData(forceInit)
      return structuredData
    end

    # Produce a JSON representation of this PreconditionSet; i.e. as a structured data representation
    # @return [String] in JSON format, reprenting this PreconditionSet
    def to_json()
      structuredData = self.toStructuredData()
      return structuredData.to_json()
    end

    # Update status of preconditions heretofore unmet, etc. Update state of numMet, someExpired, etc.
    # @return [Boolean] indicating if all preconditions in the set have been met
    def update()
      retVal = false
      # All met already? then nothing to check/update, don't waste time
      if(self.allMet?)
        retVal = true
      # Else some expired? if so, no point checking rest and job will never run because its preconditions were not all met in time.
      elsif(@someExpired)
        retVal = false
      # Else check() each specific precondition in @preconditions, especially ones as yet unmet
      else
        # First must initialize the Array of Precondition objects if it hasn't been yet
        initPreconditionObjects() unless(@preconditions.is_a?(Array))
        # Next, can we do any pre-check work, like pre-fetching etc?
        @preCheckInfo = preCheck()
        # Now can check each Precondition object
        numMet = 0
        @preconditions.each { |precondition|
          # Give Precondition access to any preCheckInfo we've gathered via batch pre-fetching etc.
          precondition.preCheckInfo = @preCheckInfo
          numMet += 1 if(precondition.check())
          @someExpired = true if(precondition.expired)
        }
        @numMet = numMet
        retVal = (!@someExpired and (@numMet == self.count()))
      end
      return retVal
    end

    def preCheck()
      @preCheckInfo = {}
      # One preCheck that could be done is to pre-fetch any dependency jobs' statuses.
      preFetchJobStatuses()
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Done all pre-checks. @preCheckInfo:\n\n#{@preCheckInfo.inspect}\n\n")
      return @preCheckInfo
    end

    def preFetchJobStatuses()
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Beginning pre-fetch of dependency job statuses. There are #{@dependencyJobUrls.size} dependency jobs. with these urls:\n\n#{@dependencyJobUrls.inspect}\n\n")
      @preCheckInfo[:jobStatusMap] = {}
      if( @dependencyJobUrls and !@dependencyJobUrls.empty? )
        jobNamesByHost = Hash.new { |hh, kk| hh[kk] = [] }
        # Collect the job names
        @dependencyJobUrls.each { |jobUri|
          jobName = @job.class.jobInfoFromUrl( jobUri.path, :jobName )
          jobHost = jobUri.host
          if(jobHost and jobName and jobHost.to_s =~ /\S/ and jobName.to_s =~ /\S/)
            jobNamesByHost[jobHost] << jobName.to_s.strip
          end
        }
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Gathered dependency jobs by host. The hosts involved are: #{jobNamesByHost.keys.join(',')}.")
        # If have 1+, we'll pre-fetch their status (and possibly other info, later) via a batch request
        jobNamesByHost.each_key { |host|
          jobNames = jobNamesByHost[host]
          $stderr.debugPuts(__FILE__, __method__, 'STATUS', "For #{job.name.inspect rescue 'ERR<No job.name>'}, host #{host.inspect} has #{jobNames.nil? ? 'NULL' : jobNames.size} dependency jobs.")
          unless( jobNames.nil? or jobNames.empty? )
            # Prep a TextEntityList payload for the jobs of interest at host
            jobNamesTextEntityList = BRL::Genboree::REST::Data::TextEntityList.new(
              false,
              jobNames.map { |jobName| BRL::Genboree::REST::Data::TextEntity.new( false, jobName ) }
            )
            jobNamesTextEntityList.serialize( :JSON_PRETTY )
            # Pre-fetch statuses of these jobs
            #  - Do a single batch request on behalf of user
            # - need user and host authmap job which is dependent upon the one in @dependencyJobUrl
            userName = @job.user
            userRows = @job.dbu.getUserByName(userName)
            userId = userRows.first['userId']
            hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
            # - use host auth map to get status of job at @dependencyJobUrl
            apiCaller = BRL::Genboree::REST::ApiCaller.new(host, JOB_STATUS_API_PATH, hostAuthMap)
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Request payload will be:\n\n#{jobNamesTextEntityList.serialized}\n\n")
            httpResp = apiCaller.get( {}, jobNamesTextEntityList.serialized )
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "The API call DID#{' NOT' unless(apiCaller.succeeded?)} succeed ; fullApiUri was:\n\n#{apiCaller.fullApiUri.inspect}\n\n-- resp body was:\n\n#{apiCaller.respBody}\n\n")
            if(apiCaller.succeeded?)
              # parse data and get request status
              apiCaller.parseRespBody()
              # Add the status of these jobs to the jobStatusMap.
              if( apiCaller.apiDataObj and apiCaller.apiDataObj['hash'] )
                respHash = apiCaller.apiDataObj['hash']
                respHash.each_key { |jobName|
                  jobStatus = respHash[jobName]
                  # We'll save the job status unless it's something weird. Weird statuses should end up getting
                  #   individually checked in the specific Precondition#check() implementation.
                  @preCheckInfo[:jobStatusMap][jobName] = jobStatus unless(jobStatus == 'JOB NOT FOUND' or jobStatus == 'STATUS MISSING')
                }
              end
            else # call failed
              # Record response in logs, but don't fail. Hopefully individual per-job requests will all work!
              $stderr.debugPuts(__FILE__, __method__, 'API REQUEST FAILED', "FAILED: A pre-check request to batch-retrieve the status of jobs mentioned in individual conditions did not return a successful response.\n--- The HTTP response code was #{httpResp.code.inspect}. The request payload was to be this TextEntityList:\n\n#{jobNamesTextEntityList.serialized}\n\n--- The HTTPResponse object was:\n\n#{httpResp}\n\n")
            end # if(apiCaller.succeeded?)
          end
        }
      end

      return true
    end

    # Store the current state of this PreconditionSet (including all preconditions) back into
    # the database table.
    # @note If an existing table row is available in @row, then that record will be updated in the database; but _only_
    #   if this object seems changed/modified. The force argument can make it update the existing record [if present]
    #   no matter what.
    # @param [BRL::Genboree::DBUtil] dbu a @DBUtil@ instance already connected and ready for working on a prequeue MySQL database
    # @param [Boolean] linkToJob indicating that the {Job} object in {@job} should be linked to any NEW
    #   preconditions table record that is created. Note: has no effect if updating an existing table record.
    # @param [Boolean] force indicating whether not to forcibly update the precondition table record,
    #   even if heuristics indicate no changes seem to have been made.
    # @return [Fixnum] the number of rows actually updated. Should be 1 if there are changes to post, else 0.
    # @raise [DBI:DatabaseError, StandardError] If insert/updated doesn't go properly.
    def store(dbu=nil, linkToJob=true, force=false)
      numRowsUpdated = 0
      # Get DBUtil object connected to prequeue if not given one
      unless(dbu and dbu.is_a?(BRL::Genboree::DBUtil))
        # Use the one from @job if available
        if(@job and @job.dbu.is_a?(BRL::Genboree::DBUtil))
          dbu = @job.dbu
        else # create new DBUtil object
          dbu = BRL::Genboree::Prequeue::Job.getDBUtil()
        end
      end
      # Need the preconditions array as JSON
      # - call makePreconditionsStructuredData() to force creation of
      #   Array of Precondition object from @preconditionsSpec if not already done
      preconditionsSD = makePreconditionsStructuredData(true)
      preconditionsJSON = preconditionsSD.to_json().strip
      # Does it look like this is based on an existing record or not?
      if(@dbRecId)
        newRecord = false
        # We have a preconditions table record id aparently. Get @row if we don't already have it
        unless(@row and !@row.empty?)
          precondRows = dbu.selectPreconditionsById(@dbRecId)
          if(precondRows and !precondRows.empty?)
            @row = precondRows.first
          end
        end
      end

      # Did we already have or were we able to get [using @dbRecId] the preconditions table row?
      # - if so, we can heuristically compare the state of this object against row contents
      #   to see if changes are needed; key to this working is stable JSON representation of
      #   the preconditions Array.
      if(@row and !@row.empty?)
        # Not new, but does it need an update or does it look unchanged?
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Preconditions state change check:\n  - force update? #{force.inspect}\n  - (@row['count']         == self.count()) => #{(@row['count']         == self.count())}\n  - (@row['numMet']        == @numMet) => #{(@row['numMet']        == @numMet)}\n  -  (@row['willNeverMatch'] == @willNeverMatch) => #{(@row['willNeverMatch'] == @willNeverMatch)}\n  - (@row['someExpired']   == @someExpired) => #{(@row['someExpired']   == @someExpired)}\n  - (@row['preconditions']  == preconditionsJSON) => #{(@row['preconditions']  == preconditionsJSON)}")
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "JSON not same??\n  @row['preconditions']:\n     => #{@row['preconditions'].inspect}\n  preconditionsJSON =>\n    => #{preconditionsJSON.inspect}") unless((@row['preconditions']  == preconditionsJSON))
        if( !force                                    and
            (@row['count']         == self.count())   and
            (@row['numMet']        == @numMet)        and
            (@row['willNeverMatch'] == @willNeverMatch) and
            (@row['someExpired']   == @someExpired)   and
            (@row['preconditions']  == preconditionsJSON)) # then looks unchanged, do nothing
          # nothing needs to be done
          numRowsUpdated = 0
        else
          # Something changed or update forced, so update record
          numRowsUpdated =
            dbu.updatePreconditionsById(@dbRecId, preconditionsJSON, self.count(), @numMet, @willNeverMatch, @someExpired)
          # Clear out obsolete @row if update succeeded...it holds old info and should be nullified.
          @row = nil if(numRowsUpdated == 1)
        end
      else # Insert new record
        # - do record insert
        numRowsUpdated =
          dbu.insertPreconditions(preconditionsJSON, self.count(), @numMet, @willNeverMatch, @someExpired)
        raise dbu.err if(dbu.err and numRowsUpdated.nil?)
        # - need last insert id
        precondId = dbu.lastInsertId
        @dbRecId = precondId if(precondId)
        # - should we update job2config (link @job to this new precondition record in the database?)
        if(linkToJob and @job)
          if(@job.dbRecId)
            if(precondId and numRowsUpdated == 1)
              numRowsUpdated = dbu.setJob2ConfigPreconditionIdById(@job.dbRecId, precondId)
            else
              raise "ERROR: Tried to insert new precondition record (# rows updated was: #{numRowsUpdated.inspect}), but couldn't get id of last record inserted (last insert id was: #{precondId.inspect})."
            end
          else
            raise "ERROR: told to link the new precondition record to the associated Job record, but the Job object doesn't have a db record id [yet]. Its table record id is: #{@job.dbRecId.inspect}. (If the job itself is new and not inserted into the database yet, linking should not be attempted until after the job is actually in the database...)"
          end
        end
      end
      return numRowsUpdated
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # -------------------------------------------------------------------

    # Use the provided JSON string containing the Array of Hashes to create specific Precondition sub-class instances.
    # @note Does not re-init if @preconditions already set up via previous call _unless_ a different
    #   preconditionsSpec is provided (different than what is in @preconditionsSpec). In that case, it replaces
    #   @preconditionsSpec and @preconditions.
    # @param  [String] preconditionsSpec JSON string containing the list of precondition spec hashes
    # @return [Array<Precondition>, nil] containing the array of Precondition sub-class objects or @nil@ if
    #   couldn't parse the JSON string (corrupt, missing), etc.
    # @raise [JSON::ParseError] if the preconditionsSpec argument is a String but not a JSON Array of precondition specs of one or more precondition Hash specs
    #   do not have the required 'type' and/or 'condition' keys; or the value for the 'type' key is not a known
    #   precondition type for which there is a subclass.
    def initPreconditionObjects(preconditionsSpec=@preconditionsSpec)
      if(!@preconditions.is_a?(Array) or (preconditionsSpec != @preconditionsSpec))
        # need to init first time or re-init with different content
        retVal = nil
        @preconditionsSpec = preconditionsSpec
        if(@preconditionsSpec)
         # parse preconditionsSpec if needed
          @preconditionsSpec = JSON.parse(@preconditionsSpec) if(@preconditionsSpec.is_a?(String))
          @preconditions = []
          begin
            @preconditionsSpec.each { |precondHash|
              precondType = precondHash['type']
              condition   = precondHash['condition']
              feedback    = precondHash['feedback'] || []
              met         = (precondHash['met'] || false)
              expires     = (precondHash['expires'] || (Time.now + Time::WEEK_SECS))
              if(precondType and condition)
                # Get subclass based on type
                subclass = BRL::Genboree::Prequeue::Precondition.preconditionClasses[precondType]
                if(subclass)
                  preconditionObj = subclass.new(@job, precondType, condition, expires, met, feedback)
                  @preconditions << preconditionObj
                  # Is there dependency job info we should collect for any pre-fetch work etc?
                  if( preconditionObj.respond_to?(:dependencyJobUrl) and preconditionObj.dependencyJobUrl.to_s =~ /\S/ )
                    #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Adding this dependencyJobUrl to list: #{preconditionObj.dependencyJobUrl.inspect}")
                    # We'll want to note this dependency job, unless the attached condition has expired of course.
                    @dependencyJobUrls << preconditionObj.dependencyJobUrl unless(preconditionObj.expired)
                  end
                else
                  @preconditions = nil
                  raise ArgumentError, "ERROR: the precondition hash spec does not have a known value for the 'type' key. #{precondType.inspect} is not a known precondition type."
                end
              else
                @preconditions = nil
                raise ArgumentError, "ERROR: the precondition hash spec is incomplete and does not contain the required 'type' and/or 'condition' keys and appropriate values:\n\n#{precondHash.inspect}\n\n"
              end
            }
          rescue => err
            # Failed at some point during Precondition instantiations. Reset @preconditions to nil.
            @preconditions = nil
            # Re-raise error
            raise err
          end
          retVal = @preconditions
        end
      else # already init and not being asked to replace
        retVal = @preconditions
      end
#      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "After init, retVal is #{retVal.inspect}\n--- @dependencyJobUrls is:\n        #{@dependencyJobUrls.inspect}\n--- And @preconditions is:\n\n#{@preconditions.inspect}\n\n")
      return retVal
    end

    # Transform @preconditions array to structured and formattable data structure
    # @param [Boolean] forceInit indicating that the Array of Precondition objects should be forcibly
    #   initialized from the {@preconditionsSpec} if it has not been already. Generally not necessary, as
    #   the count can be found from the {@preconditionsSpec} used to instantiate this class if the {@preconditions}
    #   Array has not been initialized yet. Setting to @true@ is more certain, but far slower than it should be.
    # @return [Array<Hash>] the preconditions objects array as Array of Hash spec objects
    def makePreconditionsStructuredData(forceInit=false)
      preconditionsSD = []
      initPreconditionObjects() if(forceInit and !@preconditions.is_a?(Array))
      # If available (initialized), prefer to properly constuct structured data from @preconditions Array of Precondition objects
      if(@preconditions and @preconditions.is_a?(Array))
        @preconditions.each { |precondition|
          preconditionsSD << precondition.toStructuredData()
        }
      elsif(@preconditionsSpec and @preconditionsSpec.is_a?(Array))
        # Else, fall back on the @preconditionsSpec used to instantiate this class
        preconditionsSD = @preconditionsSpec
      end
      return preconditionsSD
    end
  end # class PreconditionSet
end ; end ; end # module BRL ; module Genboree ; module Prequeue
