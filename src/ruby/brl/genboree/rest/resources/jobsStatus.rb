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
  # Jobs Statuses - Gets the status for one or more provided job names
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedJobEntity
  class JobsStatus < BRL::REST::Resources::GenboreeResource # <- resource classes must inherit and implement this interface

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'jobsStatus'

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
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "CONSIDERING: #{self.inspect}")
      return %r{^/REST/#{VER_STR}/jobs/status$}      # Look for /REST/v1/jobs/status URIs
    end

    def self.getPath()
      path = "/REST/#{VER_STR}/jobs/status"
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 8
    end

    def initOperation()
      initStatus = super()
      @jobStatuses = {}
      @anyUnknown = false
      @anyMissing = false
      if(initStatus == :OK)
        @jobNames = @nvPairs['jobNames']
        if(@jobNames.to_s =~ /\S/)
          @jobNames = @jobNames.split(',')
        else # there had better be some jobs in payload then
          @jobNames = []
        end
      end

      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      t1 = t2 = Time.now
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "ENTERED: #{__method__.inspect}")
      @statusName = initOperation()
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "initOperation returned: #{@statusName.inspect}")
      if(@statusName == :OK)
        begin
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "@jobNames from query string:\n\n#{@jobNames.inspect}\n\n")
          # Parse payload for more jobs and add to list
          payload = parseRequestBodyForEntity('TextEntityList')
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "parsed payload obj:\n\n#{payload.inspect}\n\n")
          if(payload and payload.array.is_a?(Array))
            payload.array.each { |obj|
              @jobNames.push( obj.text )
            }
          end

          # Must have 1+ job names from query string param and/or payload, else problem.
          if(@jobNames.is_a?(Array) and !@jobNames.empty?)
            # Prep job name=>status hash
            @jobNames.each { |jobName|
              jobName.strip!
              @jobStatuses[jobName] = nil # so we only store which ones we're looking for
            }

            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "full list of job names (from @jobStatuses):\n\n#{@jobStatuses.keys.sort.join("\n")}\n\n")

            # Get the status of each job name via database
            @dbu.setNewOtherDb(@genbConf.prequeueDbrcKey)
            rows = @dbu.selectJobStatusesByNames( @jobNames )

            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "status rows for jobs:\n\n#{rows.inspect}\n\n")

            # Populate hash, with conservative checking
            rows.each { |row|
              jobName = row['name'].strip
              status = row['status']
              if( @jobStatuses.key?( jobName ) ) # Good, matches one of jobs we asked for. We ONLY store ones we asked for.
                @jobStatuses[jobName] = status
              else # wth? some other job name?? Bug in db code or above prep work
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL_ERROR: Request handler retrieved status for a job (#{jobName.inspect}) that is NOT one that was requested. That suggests a serious db or prep work coding error. Please contact a Genboree Admin to have this verified and fixed."
                break
              end
            }

            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "jobStatuses from database:\n\n#{JSON.pretty_generate(@jobStatuses)}\n\n")

            if(@statusName == :OK) # then everything fine so far
              # Did we get a status for all jobs? Warn with 206 if not.
              @anyUnknown = @jobStatuses.any? { |key, val| val.nil? }
              @anyMissing = @jobStatuses.any? { |key, val| val.to_s !~ /\S/ }
              if(@anyMissing or @anyUnknown)
                @jobStatuses.each_key { |jobName|
                  if( @jobStatuses[jobName].nil? )
                    @jobStatuses[jobName] = 'JOB NOT FOUND'
                  elsif( @jobStatuses[jobName].to_s !~ /\S/ )
                    @jobStatuses[jobName] = 'STATUS MISSING'
                  end
                }
              end
              # Prep a suitable response.
              entity = BRL::Genboree::REST::Data::HashEntity.new( false, @jobStatuses )
              if( @anyUnknown or @anyMissing )
                @statusName = :'Partial Content'
                @statusMsg = ''
                if( @anyUnknown )
                  @statusMsg << "Some job names are invalid/unknown and thus no status information was found; these have the explicit status of 'JOB NOT FOUND' in the response. "
                end
                if( @anyMissing )
                  @statusMsg << "Some jobs were found that have missing status information, which indicates something has gone wrong and to contact a Genboree Admin. These jobs have the explicit status of 'STATUS MISSING' in the response. "
                end
              else
                @statusName = :OK
                @statusMsg = 'OK'
              end

              #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "status info and payload: #{@statusName.inspect} / #{@statusMsg.inspect}\n\n#{JSON.pretty_generate(entity)}\n\n")
              entity.msg = @statusMsg
              entity.statusCode = @statusName
              @statusName = configResponse(entity, @statusName)
            end
          else # no job names!
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "FOUND no-jobs client error")
            @statusName = :'Bad Request'
            @statusMsg = "NO_JOB_NAMES: You must provide a non-empty list of job names you want the status for either via the jobNames parameter or as a TextEntityList payload."
          end
        rescue => err
          @statusName = :'Internal Server Error'
          @statusMsg = "Internal_Server_Error: #{err.message}."
          $stderr.debugPuts(__FILE__, __method__, "Internal Server Error", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() unless( successCode?(@statusName) )
      return @resp
    end
  end # class JobsStatus
end ; end ; end # module BRL ; module REST ; module Resources
