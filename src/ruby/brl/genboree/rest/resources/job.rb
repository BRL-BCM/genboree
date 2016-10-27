#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/workbenchJobEntity'
require 'brl/genboree/rest/data/preconditionSetEntity'
require 'brl/genboree/rest/data/strArrayEntity'
require 'brl/genboree/rest/data/jobSummaryEntity'
require 'brl/genboree/tools/toolHelperClassLoader'
require 'brl/genboree/prequeue/job'
include BRL::Genboree::REST::Data

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  # Job - exposes information about a specific job.
  #
  # @see BRL::Genboree::REST::Data::DetailedJobEntity
  class Job < BRL::REST::Resources::GenboreeResource # <- resource classes must inherit and implement this interface

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    SUPPORTED_ASPECTS = {
                          "settings"      => true,
                          "context"       => true,
                          "inputs"        => true,
                          "outputs"       => true,
                          "status"        => true,
                          "user"          => true,
                          "toolId"        => true,
                          "type"          => true,
                          "entryDate"     => true,
                          "submitDate"    => true,
                          "execStartDate" => true,
                          "execEndDate"   => true,
                          "preconditions" => true
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
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/job/([^/\?]+)</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/job/([^/\?]+)(?:/([^/\?]+))?$}      # Look for /REST/v1/job/{job}/[aspect] URIs
    end

    def self.getPath(jobName)
      path = "/REST/#{VER_STR}/job/#{Rack::Utils.escape(jobName)}"
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 9
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @jobName = Rack::Utils.unescape(@uriMatchData[1])
        @aspect = (@uriMatchData[2].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[2])  # Could be nil or any of the SUPPORTED_ASPECTS keys
        @detailed = (@nvPairs['detailed'] or 'config')
        if(!@aspect.nil? and !SUPPORTED_ASPECTS.key?(@aspect))
          initStatus = :'Bad Request'
          @statusName = :'Bad Request'
          @statusMsg = "Unkown aspect: #{@aspect.inspect}. Supported aspects include: #{SUPPORTED_ASPECTS.keys.join(",")}"
        end
        @preconditionsCheck = ((@nvPairs.key?('preconditionsCheck') and (@nvPairs['preconditionsCheck'] =~ /^true|yes$/i)) ? true : false)
        @inclPreconditions = ((@nvPairs.key?('inclPreconditions') and (@nvPairs['inclPreconditions'] =~ /^true|yes$/i)) ? true : false)
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      @statusName = initOperation()
      if(@statusName == :OK)
        @dbu.setNewOtherDb(@genbConf.prequeueDbrcKey)

        begin
          jobRecs = @dbu.selectJobFullInfoByJobName(@jobName)
          if(!jobRecs.nil? and !jobRecs.empty?)
            jobRec = jobRecs.first
            # Is this your job and/or are you an auditor?
            if((jobRec['user'] == @gbLogin) or (@gbAudit and @isGbAuditor))
              jobEntity = nil
              if(@aspect.nil?) # get the entire config
                if(@detailed != 'summary' and @detailed != 'false' and @detailed != 'no')
                  jobRec['input']    = "[]" unless(jobRec['input'])
                  jobRec['output']   = "[]" unless(jobRec['output'])
                  jobRec['settings'] = "{}" unless(jobRec['settings'])
                  jobRec['context']  = "{}" unless(jobRec['context'])
                  jobEntity = BRL::Genboree::REST::Data::WorkbenchJobEntity.new(@connect, JSON.parse(jobRec['input']), JSON.parse(jobRec['output']), JSON.parse(jobRec['context']), JSON.parse(jobRec['settings']))
                  # Must ask explicitly for preconditions
                  if(@inclPreconditions)
                    jobEntity.preconditionSet = preconditionSetSDFromId(jobRec['preconditionId'])
                  else
                    jobEntity.preconditionSet = nil
                  end
                else # assume summary
                  jobNameRecs = @dbu.selectJobByName(@jobName)
                  jobNameRec = jobNameRecs.first
                  jobEntity = BRL::Genboree::REST::Data::JobSummaryEntity.new( @connect, @jobName, JSON.parse(jobRec['context'])['toolTitle'], jobNameRec['entryDate'], jobNameRec['execEndDate'], jobNameRec['status'] )
                end
              elsif(@aspect == 'settings')
                aHash = jobRec['settings']
                aHash = (aHash ? JSON.parse(aHash) : "{}")
                jobEntity = BRL::Genboree::REST::Data::HashEntity.new( @connect, aHash)
              elsif(@aspect == 'context')
                aHash = jobRec['context']
                aHash = (aHash ? JSON.parse(aHash) : "{}")
                jobEntity = BRL::Genboree::REST::Data::HashEntity.new( @connect, aHash )
              elsif(@aspect == 'inputs')
                anArray = jobRec['input']
                anArray = (anArray ? JSON.parse(anArray) : "[]")
                jobEntity = BRL::Genboree::REST::Data::StrArrayEntity.new( @connect, anArray )
              elsif(@aspect == 'outputs')
                anArray = jobRec['output']
                anArray = (anArray ? JSON.parse(anArray) : "[]")
                jobEntity = BRL::Genboree::REST::Data::StrArrayEntity.new( @connect, anArray )
              elsif(@aspect == 'status')
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, jobRec['status'] )
              elsif(@aspect == 'toolId')
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, jobRec['toolId'] )
              elsif(@aspect == 'type')
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, jobRec['type'] )
              elsif(@aspect == 'user')
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, jobRec['user'] )
              elsif(@aspect == 'entryDate')
                aDate = jobRec['entryDate']
                aDate = (aDate.respond_to?(:to_rfc822) ? aDate.to_rfc822 : aDate)
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, aDate )
              elsif(@aspect == 'submitDate')
                aDate = jobRec['submitDate']
                aDate = (aDate.respond_to?(:to_rfc822) ? aDate.to_rfc822 : aDate)
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, aDate )
              elsif(@aspect == 'execStartDate')
                aDate = jobRec['execStartDate']
                aDate = (aDate.respond_to?(:to_rfc822) ? aDate.to_rfc822 : aDate)
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, aDate )
              elsif(@aspect == 'execEndDate')
                aDate = jobRec['execEndDate']
                aDate = (aDate.respond_to?(:to_rfc822) ? aDate.to_rfc822 : aDate)
                jobEntity = BRL::Genboree::REST::Data::TextEntity.new( @connect, aDate )
              elsif(@aspect == 'preconditions')
                precondSetSD = {}
                # Do we even have a precondition row id in the jobRec?
                if(jobRec['preconditionId'])
                  # Get the precondition row and use to instantiate a PreconditionSet instance
                  preconditionRows = @dbu.selectPreconditionsById(jobRec['preconditionId'])
                  if(preconditionRows and !preconditionRows.empty?)
                    precondSet = BRL::Genboree::Prequeue::PreconditionSet.fromJobPreconditionsRow(nil, preconditionRows.first)
                    # Were we asked to update the the preconditions status before retrieving?
                    if(@preconditionsCheck)
                      precondSet.update()
                      precondSet.store()
                    end
                    # Get as structured data
                    precondSetSD = precondSet.toStructuredData()
                  end
                end
                jobEntity = BRL::Genboree::REST::Data::PreconditionSetEntity.new(@connect, precondSetSD)
              end
              @statusName = configResponse(jobEntity) if(!jobEntity.nil?)
            else # not your job and you not auditor, forbidden
              @statusName = :Forbidden
              @statusMsg = "FORBIDDEN: You do not have auditor permissions in Genboree and/or did not indicate you were doing an audit, so you can't see other people's jobs."
              $stderr.debugPuts(__FILE__, __method__, "FORBIDDEN", "User #{@gbLogin.inspect} attempted to access another user's job, but is not a Genboree Audtior and/or did not specify they were doing an audit (audit? #{@gbAudit}).")
              status = @statusName
            end # if((jobRec['user'] == @gbLogin) ) or (@gbAudit and @isGbAuditor))
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_JOB: The job #{@jobName.inspect} was not found."
          end # if(!jobRecs.nil? and !jobRecs.empty?)
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

    # If rulesSatisfied failed, there should be error information added to the context
    def setResponse(msgType, payload, defaultRespName, defaultMsg)
      # Set context ErrorName to the default if it hasn't been set
      payload.context['wbErrorName'] = defaultRespName if(!payload.context['wbErrorName'])
      # Use this for @statusName so that the response get the appropriate HTTP response code
      @statusName = payload.context['wbErrorName']
      # Set context ErrorMsg to a default if it hasn't been set
      payload.context['wbErrorMsg'] = defaultMsg if(!payload.context['wbErrorMsg'])
      # Use this for @statusName so that the response get the appropriate HTTP response code
      @statusMsg = payload.context['wbErrorMsg']
      # Set the body to html text
      respBody = @jobHelper.getMessage(msgType, payload)
      if(@responseFormat == :HTML)
        #$stderr.puts "response format is HTML"
        @resp.body = respBody
        @resp.status = HTTP_STATUS_NAMES[@statusName]
        unless(@resp.status)
          $stderr.puts "WARNING: Invalid status code being set by tool helper. POTENTIAL bug in the code."
          $stderr.puts "   - @statusName class & value: #{@statusName.class}, #{@statusName.inspect}"
          $stderr.puts "   - Original response payload:\n#{respBody.inspect}"
          # Try to convert to symbol
          @resp.status = HTTP_STATUS_NAMES[@statusName.to_sym]
          # Did it work as a symbol?
          unless(@resp.status)
            # no :(
            @resp.status = HTTP_STATUS_NAMES[:"Internal Server Error"]
            @resp.body = "FATAL ERROR: Invalid status code being set by tool helper. This is a bug in the code."
            $stderr.puts @resp.body
          end
        end
        @resp['Content-Type'] = (BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@responseFormat] || BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:HTML])
        if(@resp.body.respond_to?(:size))
          @resp['Content-Length'] = @resp.body.size.to_s
        end
        #$stderr.puts "@resp['Content-Length']: #{@resp['Content-Length'].inspect}\n@resp.status: #{@resp.status.inspect}\n@resp['Content-Type']: #{@resp['Content-Type'].inspect}"
      else
        #$stderr.puts "response format is NOT HTML"
        textEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, respBody)
        textEntity.setStatus(@statusName, @statusMsg)
        configResponse(textEntity, @statusName)
      end
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # ------------------------------------------------------------------

    def preconditionSetSDFromId(precondId)
      retVal = nil
      if(precondId)
        # Get the precondition row and use to instantiate a PreconditionSet instance
        preconditionRows = @dbu.selectPreconditionsById(precondId)
        if(preconditionRows and !preconditionRows.empty?)
          precondSet = BRL::Genboree::Prequeue::PreconditionSet.fromJobPreconditionsRow(nil, preconditionRows.first)
          # Get it to check itself (and store results, might as well) if asked
          if(@preconditionsCheck)
            updateStatus = precondSet.update()
            storeStatus = precondSet.store(@dbu)
          end
          # Get as structured data, tell it to
          retVal = precondSet.toStructuredData()
        end
      end
      return retVal
    end
  end # class Job
end ; end ; end # module BRL ; module REST ; module Resources
