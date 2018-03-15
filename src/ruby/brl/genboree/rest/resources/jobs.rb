#!/usr/bin/env ruby

require 'time'
require 'json'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/workbenchJobEntity'
require 'brl/genboree/rest/data/workbenchJobAuditEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/rest/data/strArrayEntity'
require 'brl/genboree/rest/data/jobSummaryEntity'
require 'brl/genboree/tools/toolConfHelper'
require 'brl/genboree/tools/toolHelperClassLoader'

include BRL::Genboree::REST::Data

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++
  # Jobs - exposes information about one or more or all jobs for a user.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedJobEntity
  class Jobs < BRL::REST::Resources::GenboreeResource # <- resource classes must inherit and implement this interface

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    FILTERS = {
                'users' => nil,
                'toolTypes' => nil,
                'systemTypes' => nil,
                'toolIdStrs' => nil,
                'statuses' => nil,
                'submitDateRange' => nil,
                'entryDateRange' => nil,
                'execStartDateRange' => nil,
                'execStopDateRange' => nil, # Same as better named (same as MySQL col) "execEndDateRange"
                'execEndDateRange' => nil,
                'sortByCols' => nil
              }
    OUTPUT_PARAMS = {
                      'grouping' => 'none',
                      'sortBy' => 'newestFirst'
                    }
    RSRC_TYPE = 'jobs'
    SUMMARY_SPECIFIC_FILTERS = {
            'matchOutputRsrc' => nil
    }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/jobs</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/jobs(?:$|/([^/\?]+)$)}      # Look for /REST/v1/jobs or /REST/v1/jobs/{aspect} URIs
    end

    def self.getPath(jobName)
      path = "/REST/#{VER_STR}/jobs"
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 7
    end

    def initOperation()
      initStatus = super()
      @aspect = (@uriMatchData[1].nil? ? nil : Rack::Utils.unescape(@uriMatchData[1].strip))
      @detailed = @nvPairs['detailed']
      @detailed = 'config' unless(@detailed)
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      t1 = t2 = Time.now
      @statusName = initOperation()
      if(@statusName == :OK)
        paramsHash = {} # Hash for collecting all params provided
        begin
          # Identify filters in query string
          @filters = FILTERS.dup()
          @filters.each_key { |key|
            @filters[key] = @nvPairs[key] if(@nvPairs.key?(key))
          }
          # Identify output params in query string
          @outputParams = OUTPUT_PARAMS.dup()
          @outputParams.each_key { |key|
            @outputParams[key] = @nvPairs[key] if(@nvPairs.key?(key))
          }
          # Identify summary specific filters in query string
          @summarySpecificFilters = SUMMARY_SPECIFIC_FILTERS.dup()
          @summarySpecificFilters.each_key { |key|
            @summarySpecificFilters[key] = CGI.escape(@nvPairs[key]) if(@nvPairs.key?(key))
          }
          jobRecs = nil
          # Configure filters hash, noting if any problems occur.
          status = setUpFiltersAndParams()
          if(status == :OK) # No problems, can continue
            # Ensure GenboreeRESTRackup has dynamically loaded tool class info by instantiating throw-away rackup.
            throwAwayRackup = GenboreeRESTRackup.new()
            throwAwayRackup = nil
            # Get job ids
            @dbu.setNewOtherDb(@genbConf.prequeueDbrcKey)
            t2 = Time.now
            jobIdRecs = @dbu.selectJobIdsByFilters( @filters, @outputParams, :and )
            # Get info for response
            if(@aspect and @aspect == 'count')
              jobCount = (jobIdRecs ? jobIdRecs.size : 0)
              entity = BRL::Genboree::REST::Data::CountEntity.new(@connect, jobCount)
            elsif(@detailed != 'audit')  # Then summary or so-called "full" or something
              # Store job summary entities (if any) in a list
              if(@detailed != 'summary' and @detailed != 'false' and @detailed != 'no')
                jobEntityList = BRL::Genboree::REST::Data::WorkbenchJobEntityList.new()
              else
                jobEntityList = BRL::Genboree::REST::Data::JobSummaryEntityList.new()
              end
              if(jobIdRecs and !jobIdRecs.empty?) # Only retrieve and store if there are some!
                # Extract jobIds from recs so we can get summary info for them
                jobIds = jobIdRecs.map { |jobRec| jobRec['id'] }
                # Get summary info for the jobs
                jobRecs = @dbu.selectJobFullInfosByJobIds(jobIds, @outputParams, @filters)
                
                # Populate entity fields
                if(!jobRecs.nil? and !jobRecs.empty?)
                  if(@detailed != 'summary' and @detailed != 'false' and @detailed != 'no') # For full detailed
                    # We need to grab audit job recs for a few fields below in our full report
                    auditJobRecs = @dbu.selectJobAuditInfosByJobIds(jobIds, @outputParams, @filters)
                    # Set up hash for easily accessing job audit records by job ID ('name')
                    auditJobRecsByJobId = {}
                    auditJobRecs.each { |jobRec|
                      auditJobRecsByJobId[jobRec['name']] = jobRec
                    }
                    # Now, we actually fill out the job records we'll be reporting back to user
                    jobRecs.each { |jobRec|
                      # Grab inputs, outputs, and context from job record
                      input = (jobRec['input'] ? (JSON.parse(jobRec['input']) rescue "[ 'ERROR (corrupted)' ]") : [])
                      output = (jobRec['output'] ? (JSON.parse(jobRec['output']) rescue "[ 'ERROR (corrupted)' ]") : [])
                      context = (jobRec['context'] ? (JSON.parse(jobRec['context']) rescue "{ 'ERROR' : '(corrupted)' }") : {})
                      # Certain information isn't in context JSON (even though a number of these fields ARE saved in context JSON for jobFile.json uploaded for users),
                      # so let's grab them via other means and save them in context
                      # Fields immediately available via jobRec
                      context['name'] = jobRec['name']
                      context['entryDate'] = jobRec['entryDate']
                      context['submitDate'] = jobRec['submitDate']
                      context['execStartDate'] = jobRec['execStartDate']
                      context['execEndDate'] = jobRec['execEndDate']
                      context['status'] = jobRec['status']
                      # Fields available via audit record associated with job ID
                      context['user'] = auditJobRecsByJobId[jobRec['name']]['user']
                      context['systemHost'] = auditJobRecsByJobId[jobRec['name']]['systemHost']
                      context['systemType'] = auditJobRecsByJobId[jobRec['name']]['systemType']
                      context['queue'] = auditJobRecsByJobId[jobRec['name']]['queue']
                      context['systemJobId'] = (auditJobRecsByJobId[jobRec['name']]['systemJobId'] || "none")
                      context['toolType'] = auditJobRecsByJobId[jobRec['name']]['toolType']
                      context['toolId'] = auditJobRecsByJobId[jobRec['name']]['toolId']
                      context['directives'] = auditJobRecsByJobId[jobRec['name']]['directives']
                      # Grab tool label and save it in context
                      label = BRL::Genboree::Tools::ToolConfHelper.getUiConfigValue('label', jobRec['toolId'])
                      context['label'] = label
                      # Grab settings from job record and then add WorkbenchJobEntity to jobEntityList
                      settings = (jobRec['settings'] ? (JSON.parse(jobRec['settings']) rescue "{ 'ERROR' : '(corrupted)' }") : {})
                      jobEntityList << BRL::Genboree::REST::Data::WorkbenchJobEntity.new( @connect, input, output, context, settings)
                    }
                  else
                    jobRecs.each { |jobRec|
                      rulesSatisfied = applySummarySpecificRules(jobRec)
                      next if(!rulesSatisfied)
                      # Get tool label
                      toolId = jobRec['toolId']
                      label = BRL::Genboree::Tools::ToolConfHelper.getUiConfigValue('label', toolId)
                      context = (jobRec['context'] ? JSON.parse(jobRec['context']) : {})
                      status = jobRec['status']
                      timeInCurrentStatus = nil
                      if(status == 'entered' or status == 'wait4deps')
                        timeInCurrentStatus = Time.now() - jobRec['entryDate']
                      elsif(status == 'submitted')
                        timeInCurrentStatus = Time.now() - jobRec['submitDate']
                      elsif(status == 'running')
                        timeInCurrentStatus = Time.now() - jobRec['execStartDate']
                      elsif(status == 'completed')
                        timeInCurrentStatus = jobRec['execEndDate'] - jobRec['execStartDate']
                      else
                        timeInCurrentStatus = "N/A"
                      end
                      jobEntityList << BRL::Genboree::REST::Data::JobSummaryEntity.new( @connect, jobRec['name'], label, jobRec['entryDate'], jobRec['execEndDate'], jobRec['status'], timeInCurrentStatus )
                    }
                  end
                end
              end
              entity = jobEntityList
            else  # 'audit' level of detail requested
              # Get job audit info from database
              # Store job audit entities (if any) in a list
              jobEntityList = BRL::Genboree::REST::Data::WorkbenchJobAuditEntityList.new()
              if(jobIdRecs and !jobIdRecs.empty?) # Only retrieve and store if there are some!
                # Extract jobIds from recs so we can get summary info for them
                jobIds = jobIdRecs.map { |jobRec| jobRec['id'] }
                # Get audit info for the jobs
                jobRecs = @dbu.selectJobAuditInfosByJobIds(jobIds, @outputParams, @filters)
                jobRecs.each { |jobRec|
                  # Get info from audit db rec
                  user = jobRec['user']
                  systemHost = jobRec['systemHost']
                  systemType = jobRec['systemType']
                  queue = jobRec['queue']
                  systemJobId = (jobRec['systemJobId'] || "none")
                  toolType = jobRec['toolType']
                  toolId = jobRec['toolId']
                  label = jobRec['label']
                  name = jobRec['name']
                  entryDate = jobRec['entryDate']
                  submitDate = jobRec['submitDate']
                  execStartDate = jobRec['execStartDate']
                  execEndDate = jobRec['execEndDate']
                  status = jobRec['status']
                  directives = jobRec['directives']
                  # submitHost is in the context JSON right now (and missing for older jobs...need to be very careful extracting)
                  submitHost = 'UNKNOWN'
                  context = jobRec['context']
                  if(context and context =~ /"submitHost"/) # should we even bother with full JSON.parse() call (expensive)?
                    contextObj = JSON.parse(context) rescue false
                    if(contextObj and contextObj.is_a?(Hash))  # then successful JSON.parse to Hash
                      sHost = contextObj['submitHost']
                      submitHost = sHost if(sHost and sHost =~ /\S/)
                    end
                  end
                  # Get tool label
                  label = BRL::Genboree::Tools::ToolConfHelper.getUiConfigValue('label', toolId)
                  # Create individual job entity
                  jobEntityList << BRL::Genboree::REST::Data::WorkbenchJobAuditEntity.new(@connect, user, submitHost, systemHost, systemType, queue, systemJobId, toolType, toolId, label, name, entryDate, submitDate, execStartDate, execEndDate, status, directives)
                }
              end
              entity = jobEntityList
            end
            @statusName = configResponse(entity)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\nSTATUS: --> PREPARED RESPONSE PAYLOAD FROM OBJECT LIST (#{Time.now - t2} secs)\n") ; t2 = Time.now
          end
        rescue => err
          @statusName = :'Internal Server Error'
          @statusMsg = "Internal_Server_Error: #{err.message}."
          $stderr.debugPuts(__FILE__, __method__, "Internal Server Error", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    def applySummarySpecificRules(jobRec)
      retVal = true
      if(!@summarySpecificFilters['matchOutputRsrc'].nil?)
        if(jobRec and jobRec['output'])
          outputs = JSON.parse(jobRec['output'])
          matchStr = @summarySpecificFilters['matchOutputRsrc']
          outputs.each {|output|
            if(output !~ /#{matchStr}/)
              retVal = false
              break
            end
          }
        end
      end
      return retVal
    end

     # Adjust the values in the hashes to make them compatible with the dbu method we will call
    def setUpFiltersAndParams()
      status = :OK
      t1 = t2 = Time.now
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Examine 'user' filter for /jobs/ request done by #{@gbLogin.inspect}:\n\t'users' param: #{@filters['users'].inspect}\n\tis an audit? #{@gbAudit.inspect}\n\tuser is an auditor? #{@isGbAuditor.inspect}")
      # Is this an anonymous access? They are not allowed to do this jobs/ listing stuff.
      if( @gbLogin.nil? )
        status = :Forbidden
        @statusMsg = "FORBIDDEN: You must provide authentication credentials to see job listings. You will only be able to see your own jobs, in most cases."
      else # have a @gbLogin
        # Has the 'users' filter parameter been provided?
        usersFilter = @filters['users'].to_s.split(',').map { |xx| xx.strip }.uniq

        # Auditors doing audits can have 0, 1, N 'users' filter values and no restrictions.
        if( @gbAudit and @isGbAuditor )
           # If empty, set to nil to mean "all" (for audits only)
          usersFilter = nil if( usersFilter.empty? )
        else # Not an auditor doing an audit. Apply restrictions.
          if( usersFilter.empty? )
            # No 'users' filter provided. Force it to have @gbLogin.
            usersFilter = [ @gbLogin ]  # Default if no user list.
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "No 'users' filter given. Set to: #{usersFilter.inspect}")
          else  # A user list was provided. Must have ONLY @gbLogin in this case.
            if( usersFilter.size > 1 or usersFilter.first != @gbLogin )
              status = :Forbidden
              @statusMsg = "FORBIDDEN: You are not an auditor doing an audit, so you can't see other people's jobs."
            #else # There is correctly 1 'users' filter value and it's @gbLogin.
            end
          end
        end
      end

      # Passed the user check?
      if( status != :OK )
        $stderr.debugPuts(__FILE__, __method__, "FORBIDDEN", "User #{@gbLogin.inspect}, who is not an auditor doing an audit, attempted an access of these users' jobs: #{@filters['users'].nil? ? '[[All users]]' : @filters['users'].inspect}")
      else
        @filters['users'] = usersFilter
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "User-check status: #{status.inspect} ; Final users filter: #{@filters['users'].inspect}")

        # Continue with other filters if everything ok with user list.
        if(status == :OK)
          if(!@filters['toolIdStrs'].nil?)
            @filters['toolIdStrs'] = @filters['toolIdStrs'].to_s.split(',').map { |xx| xx.strip }
          end
          if(!@filters['statuses'].nil?)
            @filters['statuses'] = @filters['statuses'].to_s.split(',').map { |xx| xx.strip }
            @filters['statuses'].map! { |currentVal| currentVal.to_sym }
          end
          if(!@filters['toolTypes'].nil?)
            @filters['toolTypes'] = @filters['toolTypes'].to_s.split(',').map { |xx| xx.strip }
            end
          if(!@filters['systemTypes'].nil?)
            @filters['systemTypes'] = @filters['systemTypes'].split(',').map { |xx| xx.strip }
            end
          # Handle all date ranges
          FILTERS.each_key { |key|
            if(key.to_s =~ /DateRange$/ and !@filters[key].nil? and !@filters[key].empty?)
              ##$stderr.puts("key: #{key}\n\n@filters[key]: #{@filters[key].inspect}")
              dateRange = @filters[key]
              startDate = dateRange.split(',', 2)[0]
              endDate = dateRange.split(',', 2)[1]
              if(!startDate.nil? and startDate =~ /\S/)
                startDate = ( startDate =~ /^-?\d+(?:\.\d+)?$/ ? Time.at(startDate.to_f) : Time.parse(startDate) )
              else
                startDate = nil
              end
              if(!endDate.nil? and endDate =~ /\S/)
                endDate = ( endDate =~ /^-?\d+(?:\.\d+)?$/ ? Time.at(endDate.to_f) : Time.parse(endDate))
              else
                endDate = nil
              end
              # Normalize order such that startDate <= endDate
              startDate, endDate = endDate, startDate if(!startDate.nil? and !endDate.nil? and (startDate >= endDate))
              @filters[key] = [startDate, endDate]
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "     Date filter: #{@filters[key].inspect}")
            end
          }
        end
      end
      @statusName = status
      return status
    end
  end # class Job
end ; end ; end # module BRL ; module REST ; module Resources
