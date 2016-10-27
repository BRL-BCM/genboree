#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'time'
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Prequeue ; module Preconditions
  class JobPrecondition < BRL::Genboree::Prequeue::Precondition
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    PRECONDITION_TYPE = "job"

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [URI] URI object for the URL of the dependency job upon which this one is dependent
    attr_reader :dependencyJobUrl
    # @return [String] Hash of acceptable statuses (with boolean values) for this dependency job that will allow the dependent job to run.
    attr_accessor :acceptableStatuses

    # ------------------------------------------------------------------
    # GENBOREE INTERFACE METHODS
    # - Methods to be implemented by precondition sub-classes
    # ------------------------------------------------------------------

    # @note GENBOREE INTERFACE METHOD (subclasses _should_ override)
    # Clears the state, stored data, and other info from this object.
    # Should be overridden in any subclass to clear out subclass-specific stuff, but make sure to call super()
    # so parent stuff gets cleaned too.
    # @return [void]
    def clear()
      @acceptableStatuses.clear() rescue false
      @acceptableStatuses = nil
      @dependencyJobUrl = nil
      super()
    end

    # Set the dependencyJobUrl property. If not a URI object, will be converted via URI.parse()
    # @param  [URI, String] url the full URL of the job upon which this one (@job) is dependent.
    # @return [URI]
    def dependencyJobUrl=(url)
      if(url.is_a?(URI))
        @dependencyJobUrl = url
      else
        @dependencyJobUrl = URI.parse(url.to_s)
        # Need to make sure we have a proper URL (easy for weird ~urls to sneak through)
        urlOk = validateDependencyJobUrl(@dependencyJobUrl)
        unless(urlOk)
          @dependencyJobUrl = nil
          raise "#{@feedback.last['info']['message']}."
        end
      end
      return @dependencyJobUrl
    end

    # @note GENBOREE INTERFACE METHOD (subclasses _should_ override)
    # Produce a basic structured Hash containing the core info in this Precondition
    # using Hashes, Arrays, and other core Ruby types and which are easy/fast to format
    # into string representations like JSON, YAML, etc.
    # Should be overridden in any subclass to clear out subclass-specific stuff, but make sure to call super()
    # first and then add sub-class specific stuff to the Hash that the parent method returns.
    # @return [Hash]
    def toStructuredData()
      structuredData = super()
      conditionSD = structuredData["condition"] = {}
      conditionSD["dependencyJobUrl"] = @dependencyJobUrl.to_s
      conditionSD["acceptableStatuses"] = @acceptableStatuses
      return structuredData
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHODD (subclasses _must_ override)
    # Evaluate precondition and update whether precondition met or not.
    # @return [Boolean] indicating if condition met or not
    # @raise StandardError if not connected to a specific job (via {@job}) or cannot get the status of the job upon which this one depends. Rescue, log, and set met==false maybe?
    def evaluate()
      retVal = false
      if(@job)
        if(@dependencyJobUrl)
          # Ensure @dependencyJobUrl is a URI object and that it is valid!
          if(@dependencyJobUrl.is_a?(String))
            @dependencyJobUrl = URI.parse(@dependencyJobUrl) rescue nil
          end
          urlOk = validateDependencyJobUrl(@dependencyJobUrl)
          if(urlOk)
            # Use @dependencyJobUrl to make API call on behalf of user to get Job status
            # - need user and host authmap job which is dependent upon the one in @dependencyJobUrl
            userName = @job.user
            userRows = @job.dbu.getUserByName(userName)
            userId = userRows.first['userId']
            hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId)
            # - use host auth map to get status of job at @dependencyJobUrl
            fullPath = "#{@dependencyJobUrl.path}/status?connect=no"
            apiCaller = BRL::Genboree::REST::ApiCaller.new(@dependencyJobUrl.host, fullPath, hostAuthMap)
            httpResp = apiCaller.get()
            if(apiCaller.succeeded?)
              # parse out and get status
              apiCaller.parseRespBody()
              jobStatus = apiCaller.apiDataObj['text'].to_s.strip
              # is the status one of the acceptable ones? If so, return true.
              retVal = @acceptableStatuses.key?(jobStatus)
            else # call failed
              # Record error in @feedback Hash for trace purposes
              @feedback <<
              {
                'type' => 'apiFailure',
                'info' =>
                {
                  'code'            => httpResp.code,
                  'name'            => httpResp.message,
                  'location'        => "#{self.class}#{__method__}",
                  'message'         => "FAILED: API call to get job status via #{@dependencyJobUrl.inspect}.",
                  'responsePayload' => "#{apiCaller.respBody.inspect}"
                }
              }
              @feedbackSet = true
              raise "#{@feedback.last['info']['message']}. HTTP response type: #{httpResp.code} #{httpResp.message.inspect}. Payload:\n  #{apiCaller.respBody.inspect}"
            end # if(apiCaller.succeeded?)
          else # url not valid
            raise "#{@feedback.last['info']['message']}."
          end # if(dependencyJobUri)
        end # if(@dependencyJobUrl and @dependencyJobUrl =~ /\S/)
      else
        raise "ERROR: There is no job connected to this precondition (@job: #{@job.inspect}), so cannot be asked to evaluate its status. This is the result of code bug that needed fixing."
      end # if(@job)
      return retVal
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHODD (subclasses _must_ override)
    # - Implement initPrecondition(arg) in sub-classes where arg is a condition hash spec
    #   containing keys and values the sub-class can correctly interpret and use to self-configure.
    # @param [Hash] conditionHash with the sub-class condition specification
    # @return [void]
    def initCondition(conditionHash)
      # Must call dependencyJobUrl=() to get validation as well. Don't do @dependencyJobUrl = directly (doesn't use dependencyJobUrl=())
      self.dependencyJobUrl  = conditionHash["dependencyJobUrl"]
      @acceptableStatuses = conditionHash["acceptableStatuses"]
    end

    # ------------------------------------------------------------------
    # SUB-CLASS SPECIFIC METHODS
    # ------------------------------------------------------------------

    def validateDependencyJobUrl(url)
      retVal = true
      if(url.is_a?(String))
        uri = URI.parse(url) rescue nil
      else # must be URI object
        uri = url
      end
      if(uri)
        if(!uri.host or uri.host !~ /\S/)
          retVal = false
          msg    = "no 'host'"
        elsif(!uri.path or uri.path !~ /^\/REST\/v\d+\/\job\/(?:.+)/)
          retVal = false
          msg    = "no 'path' to a job"
        elsif(!uri.scheme or uri.scheme !~ /^http/)
          retVal = false
          msg    = "no http-based 'scheme/protocol'"
        else
          retVal = true
        end
        unless(retVal)
          # @dependencyJobUrl is not a proper URL!
          # Record error in @feedback Hash for trace purposes
          @feedback <<
          {
            'type' => 'badPreconditionSpec',
            'info' =>
            {
              'location'   => "#{self.class}#{__method__}",
              'message'    => "ERROR: the precondition spec is malformed. #{url.to_s.inspect} is not a proper URL pointing to a job (#{msg})"
            }
          }
          @feedbackSet = true
        end
      end
      return retVal
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Preconditions
