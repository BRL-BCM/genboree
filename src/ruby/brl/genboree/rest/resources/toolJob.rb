#!/usr/bin/env ruby
require 'erubis'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/workbenchJobEntity'
require 'brl/genboree/rest/data/rawDataEntity'
require 'brl/genboree/tools/toolHelperClassLoader'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  class ToolJobResources < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Tools::ToolHelperClassLoader

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :put => true }
    RSRC_TYPE = 'toolJobRsrcs'

    #
    #def initialize(req, resp, uriMatchData)
    #  super(req, resp, uriMatchData)
    #  # Default format for all API resources is :JSON but for this resource it should be :LFF
    #  @repFormat = :HTML
    #end

    def initialize(req, resp, uriMatchData)
      super(req, resp, uriMatchData)
    end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/genboree/tool/([^/\?]+)/job$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      @toolIdStr = Rack::Utils.unescape(@uriMatchData[1])
      # From toolHelperClassLoader mix-in:
      self.getHelper(:Rules)  # <- Sets @rulesHelper instance var
      self.getHelper(:Job)    # <- Sets @jobHelper instance var
      return @statusName
    end

    # Confirm that user info in job config is (a) self-consistent and
    # (b) appropriate/matches who is making this tool job API request.
    # If no user info is in the job config's context [ideal!], it will be
    # added using info about user making this API request.
    # @note Sets {@statusName} and {@statusMsg} if it finds problems with user and will return false.
    #   Else just returns true, allowing API request to proceed.
    # @param [WorkbenchJobEntity] wbJobEntity The job config object to check
    # @return [Boolean] indicating if everything checks out or if there is a problem
    def confirmUserInfo(wbJobEntity)
      retVal = false
      localUserDbRec = nil # needed during validations [some] and at very end [all]
      # Is there user info in the context section of the job config?
      # NOTE: There SHOULD NOT BE. User context COMES FROM THE SERVER, not the SUBMITTER.
      # - However, we will check that it is sensible. Maybe jobs coming from old code or is
      #   based on the config for a previous job (say, due to a pipeline or something.)
      # NOTE: It is STRIPPED before the tool config info is stored in the DATABASE! So we know for sure it shouldn't be here...
      jobConfUserId = wbJobEntity.context['userId']
      jobConfUserLogin = wbJobEntity.context['userLogin']
      if(jobConfUserId or jobConfUserLogin)
        jobConfUserId = jobConfUserId.to_i if(jobConfUserId)
        # We need to local user db rec for validations. Get via userId or userLogin from the job config:
        if(jobConfUserId)
          localUserDbRecs = @dbu.getUserByUserId(jobConfUserId)
        else # must have login [only] then
          localUserDbRecs = @dbu.getUserByName(jobConfUserLogin)
        end

        if(localUserDbRecs.nil? or localUserDbRecs.empty?)
          @statusName = :'Bad Request'
          @statusMsg  = "Cannot find a Genboree user matching the user information provided in the job context section. Probably you should not be providing user information in the context section anyway? Why are you doing that? Typically the context section should be EMPTY."
          retVal = false
        else # found the user via userId or userLogin from context
          localUserDbRec = localUserDbRecs.first

          # 1. If have BOTH in job context, they need to agree, else error
          if(jobConfUserId and jobConfUserLogin)
            if(jobConfUserId != localUserDbRec['userId'])  # check they agree via the userIds
              @statusName = :'Bad Request'
              @statusMsg = "The job was not accepted. The context section of the job configuration contains mismatched info about the user for whom the job will be run. Probably you should not be providing user information in the context section anyway? Why are you doing that? Typically the context section should be EMPTY."
              retVal = false
            else
              retVal = true
            end
          else
            retVal = true
          end

          # 2. If either/both present in job context, must match user making this API request UNLESS that user is superuser
          if(retVal) # job config user info is self-consistent at least...do some more validations to avoid attacks
            unless(@isSuperuser)
              if(jobConfUserId and (jobConfUserId != @userId))
                @statusName = :'Bad Request'
                @statusMsg = "The job was not accepted. The user submitting this job is not the user mentioned in context section of the job config. Maybe you have an inappropriate job context section; consider providing an EMPTY context section, which is better anyway."
                retVal = false
              elsif(jobConfUserLogin and (jobConfUserLogin != @gbLogin))
                @statusName = :'Bad Request'
                @statusMsg = "The job was not accepted. The user submitting this job is not the user mentioned in context section of the job config. Maybe you have an inappropriate job context section; consider providing an EMPTY context section, which is better anyway."
                retVal = false
              else # job config user info is self-consistent and matches user submitting the tool job
                # Just o be explicit...use our values, not what is in job config sent to us
                wbJobEntity.context['userId'] = @userId
                wbJobEntity.context['userLogin'] = @gbLogin
                retVal = true
              end
            else # job config user info is self-consistent but different than user submitting the tool job...but that is superuser so it's ok
              retVal = true
              wbJobEntity.context['userId'] = localUserDbRec['userId'] unless(wbJobEntity.context['userId'])
              wbJobEntity.context['userLogin'] = localUserDbRec['name'] unless(wbJobEntity.context['userLogin'])
            end
          end # if(retVal)
        end # if(localUserDbRecs.nil? or localUserDbRecs.empty?)
      else # NEITHER userId or userLogin are in the context
        # This is ideal, because the user making this API request SHOULD be the one for whom the job will run!!
        # This means we should add those fields to the context though so some downstream stuff can use that info.
        # Unless it's the special Public or superuser fake users of course. They can't run jobs.
        if(@isSuperuser or @userId == 0)
          @statusName = :'Bad Request'
          @statusMsg = "The job was not accepted. The job would be run as the special public user or the administrative user, and this is not allowed. Probably a job configuration/submission bug."
          retVal = false
        else
          wbJobEntity.context['userId'] = @userId
          wbJobEntity.context['userLogin'] = @gbLogin
          retVal = true
        end
      end # if(jobConfUserId or jobConfUserLogin)
      return retVal
    end

    def put()
      begin
        initStatus = initOperation()
        # If something wasn't right, represent as error
        if(initStatus == :OK)
          # Request body must be a WorkbenchJob
          payload = parseRequestBodyForEntity('WorkbenchJobEntity')
          if(payload.is_a?(BRL::Genboree::REST::Data::WorkbenchJobEntity))
            # Ensure payload has user info in it and any existing user info
            # agrees with user who is submitting this job...
            userInfoConfirmed = confirmUserInfo(payload)
            if(userInfoConfirmed)
              @resp.body = ''
              # Ensure the context section of the job entity contains the *correct* toolIdStr
              # - i.e. the one from the API request URL path
              payload.context['toolIdStr'] = @toolIdStr
              # Check that the required settings are present
              if(@rulesHelper.rulesSatisfied?(payload))
                if(@rulesHelper.warningsExist?(payload))
                  setResponse(:Warnings, payload, :"Expectation Failed", "")
                else
                  executionCallback = @jobHelper.executionCallback()
                  # executionCallback returns true if accepted or completed successfully
                  # or false if there was a problem
                  if(executionCallback.call(payload))
                    # Note that context['jobId'] will be filled in with the jobId if available.
                    setResponse(:Accepted, payload, :Accepted, "")
                  else
                    $stderr.puts "TOOL ERROR: The jobHelper instance reported an error. Ideally the 'wbErrorName' and 'wbErrorMsg' have been set in the payload's context (which follows):\n\n#{payload.context.inspect}\n\n"
                    # If callback failed, there should be error information added to the context already
                    statusCode = :'Internal Server Error'
                    # do we have a better one we can extract from the the payload?
                    # ideally yes, the executionCallback set one there upone error...
                    if(payload and payload.context)
                      wbErrorName = payload.context['wbErrorName']
                      if(wbErrorName and wbErrorName =~ /\S/ and BRL::Genboree::REST::ApiCaller::HTTP_STATUS_NAMES.key?(wbErrorName.to_sym))
                        statusCode = wbErrorName.to_sym
                      end
                    end
                    setResponse(:Failure, payload, statusCode, "Error accepting job. The job helper class for this tool returned a failure.")
                  end
                end
              else
                msg = "The job was not accepted. "
                msg << "The job was not accepted. '#{@rulesHelper.rejectionMsg}'. " if(@rulesHelper.rejectionMsg)
                msg << "Review the instructions and make sure you have the right number of items of each type."
                setResponse(:Rejected, payload, :"Not Acceptable", msg)
              end
            else
              @resp = representError()
            end
          else
            @statusName = :"Unsupported Media Type"
            @statusMsg = "The request body must be a valid WorkbenchJobEntity"
            @resp = representError()
          end
        else
          @statusName = initStatus
          @resp = representError()
        end
      rescue => err
        unless(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = :"Internal Server Error"
          @statusMsg = "Unhandled exception"
        end
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Unhandled exception! Message: #{err.message} ; Backtrace:\n#{err.backtrace.join("\n")}\n")
        @resp = representError()
      end
      return @resp
    end

    # If rulesSatisfied failed, there should be error information added to the context
    def setResponse(msgType, payload, defaultRespName, defaultMsg)
      jobName = (payload.context['jobId'] || "NONE")
      # Set context ErrorName to the default if it hasn't been set
      payload.context['wbErrorName'] = defaultRespName if(!payload.context['wbErrorName'] or !HTTP_STATUS_NAMES.key?(payload.context['wbErrorName']))
      # Use this for @statusName so that the response get the appropriate HTTP response code
      @statusName = payload.context['wbErrorName']
      # Set context ErrorMsg to a default if it hasn't been set
      payload.context['wbErrorMsg'] = defaultMsg if(!payload.context['wbErrorMsg'])
      # Use this for @statusName so that the response get the appropriate HTTP response code
      @statusMsg = payload.context['wbErrorMsg']
      if(@responseFormat == :HTML)
        # Set the body to html text
        respBody = @jobHelper.getMessage(msgType, payload)
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
      else
        if(payload.results)
          entity = BRL::Genboree::REST::Data::RawDataEntity.new(false, payload.results)
        else
          entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, jobName)
        end
        entity.setStatus(@statusName, @statusMsg)
        status = configResponse(entity, @statusName)
      end
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
