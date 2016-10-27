#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/extensions/helpers'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/urlEntity'

module BRL ; module REST ; module Extensions ; module Clingen ; module Resources

  # urlLookup - Lookup URL based on prop-val ; redirect to URL
  #
  # Data representation classes used:
  class EhrSendPdf < BRL::REST::Resources::GenboreeResource

    include BRL::Genboree::REST::Extensions::Helpers

    # INTERFACE CONSTANTS

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true }
    API_EXT_CATEGORY = 'clingen'
    RSRC_TYPE = 'ehrSendPdf'

    # Class specific constants
    GB_RSRC_PATH = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?matchProps={props}&matchValues={vals}&matchLogicOp=and&matchMode=exact&detailed=false&format=json_pretty"
    PROPS = [ "EHR URL.Tags.Tag.Name", "EHR URL.Tags.Tag.Value" ]

    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      apiExtConf = self.loadConf(self::API_EXT_CATEGORY, self::RSRC_TYPE)
      rsrcPathBase = (
        (apiExtConf['rsrc'] and apiExtConf['rsrc']['pathBase']) ?
        apiExtConf['rsrc']['pathBase'].strip :
        "/REST-ext/#{CGI.escape(self::API_EXT_CATEGORY)}/#{CGI.escape(self::RSRC_TYPE)}"
      )
      regexp =  %r{^#{Regexp.escape(rsrcPathBase)}/([^/\?]+)/([^/\?]+)$}
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API Ext Class will match: #{regexp.source}")
      return regexp
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 6
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      # Load this extension's config
      @apiExtConf = self.class.loadConf(self.class::API_EXT_CATEGORY, self.class::RSRC_TYPE)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> @apiExtConf:\n\n#{@apiExtConf.inspect}\n\n")
      if(initStatus == :OK and @apiExtConf)
        @gbHost = @apiExtConf['records']['host']
        @groupName = @apiExtConf['records']['grp']
        @kbName = @apiExtConf['records']['kb']
        @kbColl = @apiExtConf['records']['coll']
        @gbRsrcTmpl = GB_RSRC_PATH.dup
        @tagName  = Rack::Utils.unescape(@uriMatchData[1])
        @tagValue = Rack::Utils.unescape(@uriMatchData[2])
        @redirect = (@nvPairs.key?('redirect') ? @nvPairs['redirect'].autoCast(true) : true)
      else
        initStatus = :'Internal Server Error' unless(@apiExtConf)
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      initStatus = initOperation()
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> Init status: #{initStatus.inspect} ; @groupAccessStr: #{@groupAccessStr.inspect} ; @groupName: #{@groupName.inspect} ; @kbName: #{@kbName.inspect} ; @reqMethod: #{@reqMethod.inspect} ; @dbu:\n\n#{@dbu}\n\n")
      if(initStatus == :OK)
        initStatus = initGroupAndKb()
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> initStatus: #{initStatus.inspect} ; @groupAccessStr: #{@groupAccessStr.inspect}")
        # All accesses to this service are non-login; that's the point of this service.
        # Even if they authenticated, access will be "public" mode.
        @groupAccessStr = 'p'
        # Would need to do this conf stuff first and then init...
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> INIT:\n  @tagName:\t#{@tagName.inspect}\n  @tagValue:\t#{@tagValue.inspect}\n  @redirect:\t#{@redirect.inspect}")
          # ApiCaller to search for matchProps based search
          apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(@gbHost, @gbRsrcTmpl, @userId)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get( {
            :grp  => @groupName,
            :kb   => @kbName,
            :coll => @kbColl,
            :props  => PROPS.dup,
            :vals   => [ @tagName, @tagValue ]
          })
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "success? #{apiCaller.succeeded?} ; http code: #{apiCaller.httpResponse.code.inspect}")
          if(apiCaller.succeeded?) # if(apiCaller.success?)
            apiCaller.parseRespBody()
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiDataObj:\n\n#{apiCaller.apiDataObj.inspect}\n\n")
            if(apiCaller.apiDataObj and apiCaller.apiDataObj.size == 1)
              kbDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.apiDataObj.first) rescue nil
              if(kbDoc)
                url = kbDoc.getRootPropVal() rescue nil
                if(url)
                  # If @redirect (default is true) then do a redirect, else return a payload.
                  if(@redirect) # redirect
                    @resp.body = ''
                    @resp['Location'] = url
                    @resp.status = HTTP_STATUS_NAMES[:Found]
                    @statusName = :OK
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> Set 302 response and Location header")
                  else # payload
                    @statusName = :OK
                    @statusMsg = "OK"
                    entity = BRL::Genboree::REST::Data::UrlEntity.new(false, url)
                    entity.setStatus(@statusName, @statusMsg)
                    @statusName = configResponse(entity, @statusName)
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> Set 200 response with URL entity doc payload")
                  end
                else
                  @statusName = :'Internal Server Error'
                  @statusMsg = "FATAL ERROR: The query matched a doc but could not extract the root property value [which has the target url]."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL ERROR: the query appears to have matched a doc but the response payload cannot be converted to an actual KbDoc object. ???"
              end
            else
              if(apiCaller.apiDataObj.size < 1)
                # None matched, this is expected. Convert to 404 not found.
                @statusName = :'Not Found'
                @statusMsg = "NOT_FOUND: No url record matches \"#{@tagName}=#{@tagValue}\"."
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "FATAL ERROR: It appears MORE THAN ONE url record matched \"#{@tagName} == #{@tagValue}\". This service does not support multiple urls per #{@tagName} code (not part of specification of the service features)."
              end
            end
          else # API Error...404 is UNexpected, because it's about the the grp/kb/coll
            # Attempt to parse response
            parsedResp = apiCaller.parseRespBody() rescue nil
            respStatus = (parsedResp ? apiCaller.apiStatusObj['statusCode'] : 'N/A')
            respMsg = (parsedResp ? apiCaller.apiStatusObj['msg'] : 'N/A')
            @statusName = :'Internal Server Error'
            @statusMsg = "ERROR: This service and/or the underlying resources are not configured correctly and the file records in general cannot be searched. Specific internal code was: #{respStatus.inspect} ; internal message was: #{respMsg.inspect}"
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK and @statusName != :Found)
      return @resp
    end
  end # class KbModel < BRL::REST::Resources::GenboreeResource
end ; end ; end ; end ; end # module BRL ; module REST ; module Extensions ; module Clingen ; module Resources
