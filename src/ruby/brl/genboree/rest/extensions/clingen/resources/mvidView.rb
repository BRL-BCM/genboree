#!/usr/bin/env ruby
require 'timeout'
require 'escape_utils'
require 'uri_template'
require 'erubis'
require 'json'
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
  class MvidView < BRL::REST::Resources::GenboreeResource

    include BRL::Genboree::REST::Extensions::Helpers

    # INTERFACE CONSTANTS

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true }
    API_EXT_CATEGORY = 'clingen'
    RSRC_TYPE = 'mvidView'

    # Class specific constants

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
      regexp =  %r{^#{Regexp.escape(rsrcPathBase)}/([^/\?]+)$}
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API Ext Class will match: #{regexp.source}")
      return regexp
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 8
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      @statusName = super()
      # Load this extension's config
      @apiExtConf = self.class.loadConf(self.class::API_EXT_CATEGORY, self.class::RSRC_TYPE)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", ">>> @apiExtConf:\n\n#{@apiExtConf.inspect}\n\n")
      if(@statusName == :OK and @apiExtConf)
        @remoteUriTmpl    = @apiExtConf['remoteUrl']['template']
        @remoteUriTimeout = @apiExtConf['remoteUrl']['timeout']
        @htmlTemplateFile = @apiExtConf['htmlTemplateFile']
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "uriMatchData: #{@uriMatchData.inspect}")
        @variantID  = Rack::Utils.unescape(@uriMatchData[1]).strip
        begin
          # Read in the template file and make templater from it
          template = File.read( @htmlTemplateFile )
          @templater = Erubis::FastEruby.new( template )
          # Fill URITemplate to get URI
          uriTemplate = URITemplate.new( @remoteUriTmpl )
          @url = uriTemplate.expand(:variant => @variantID)
          @uri = URI.parse(@url)
        rescue Exception => err
          @statusName = :'Internal Server Error'
          @statusMsg = 'Error encountered while setting up handling of your request; likely a configuration error for this API service.'
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "MyVariant Info - View - #{@statusName}: Exception raised trying to set up request handling. Using this config:\n    #{@apiExtConf.inspect}\nAnd have this variantID from the request: #{@variantID.inspect}. Error details:\n    Error Class: #{err.class}\n    Error Message: #{err.message.inspect}\n    Error Trace:\n#{err.backtrace.join("\n")}")
        end
      else
        @statusName = :'Internal Server Error' unless(@apiExtConf)
      end
      return @statusName
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      @statusName = initOperation()
      if(@statusName == :OK)
        begin
          # 1. Make request to @url
          jsonStr = nil
          timeout(@remoteUriTimeout) {
            remoteResp = ::Net::HTTP.start(@uri.host, @uri.port) { |http|
              http.get(@uri.path)
            }
            jsonStr = ( (remoteResp and remoteResp.body) ? (remoteResp.body.respond_to?(:read) ? remoteResp.body.read() : remoteResp.body) : '' )
          }
          # 2. Parse
          jsonObj = JSON.parse( jsonStr )
          # 3. Run it through templater to get response
          html = @templater.evaluate( { :json => jsonObj } )
          # 4. Should set content-type and such
          @statusName = :OK
          @resp.body = html
          @resp.status = HTTP_STATUS_NAMES[@statusName]
          @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:HTML]
          @resp['Content-Length'] = html.size.to_s rescue 0
        rescue Timeout::Error => terr
          @statusName = :'Gateway Timeout'
          @statusMsg = "The remote url #{@url.inspect} timed out after #{@remoteUriTimeout.inspect} seconds."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "MyVariant Info - View - #{@statusName}: Exception raised trying to make remote request. #{@statusMsg}")
          prepErrorResp()
        rescue JSON::ParserError => jperr
          @statusName = :'Bad Gateway'
          @statusMsg = "The remote url #{@url.inspect} gave back bad JSON; this caused an #{jperr.class} with the complaint that #{jperr.message.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "MyVariant Info - View - #{@statusName}: Exception raised trying to parse remote response. #{@statusMsg}.")
          prepErrorResp()
        rescue Exception => err
          @statusName = :'Internal Server Error'
          @statusMsg = "Internal server error. Unexpected error while processing your request."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "MyVariant Info - View - #{@statusName}: Exception raised trying to query & process results from #{@url.inspect}.  Using this config:\n    #{@apiExtConf.inspect}\nAnd have this variantID from the request: #{@variantID.inspect}. Error details::\n    Error Class: #{err.class}\n    Error Message: #{err.message}\n    Error Trace:\n#{err.backtrace.join("\n")}")
          prepErrorResp()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def prepErrorResp()
      @statusName = :OK
      @resp.body = (@statusMsg or '')
      @resp.status = HTTP_STATUS_NAMES[@statusName]
      @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:HTML]
      @resp['Content-Length'] = @statusmsg.size.to_s rescue 0
    end
  end # class MvidView < BRL::REST::Resources::GenboreeResource
end ; end ; end ; end ; end # module BRL ; module REST ; module Extensions ; module Clingen ; module Resources
