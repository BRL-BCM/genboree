#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/apiCaller' # for ApiCaller.applyDomainAliases()
require 'brl/genboree/rest/em/deferrableBodies/deferrableDelegateBody'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/urlEntity'
require 'brl/genboree/abstract/resources/textDigest'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class ShortUrlResource < BRL::REST::Resources::GenboreeResource
    Abstraction = BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'shortUrl'

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
      return %r{^/REST/#{VER_STR}/shortUrl/([^/\?]+)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      if(@statusName == :OK)
        @digest = Rack::Utils.unescape(@uriMatchData[1])
      end
      return @statusName
    end

    # Process a GET operation on this resource. Depending on @repFormat, either:
    # - returns a simple UrlEntity for the url matching this digest
    # - OR returns the actual contents of the URL matching this digest
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Try to get URL for this digest
        url = Abstraction::TextDigest.getTextByDigest(@dbu, @digest)
        # If there is one, then does it look like a url?
        if(url)
          # Must be parsable
          begin
            uri = URI.parse(url)
          rescue URI::InvalidURIError => iuerr
            @statusName = :'Precondition Failed'
            @statusMsg = "NOT_VALID_URL: The content whose digested value is '#{@digest}' is not a valid URL. That is not allowed for /shortUrl/ resources. Failed URL validating check."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "NOT_VALID_URL: The content whose digested value is '#{@digest}' is not a valid URL. That is not allowed for /shortUrl/ resources. Failed URL validating check for #{url.inspect}. Error: #{iuerr.message}. Backtrace:\n#{iuerr.backtrace.join("\n")}")
          end
          # But could still be a relative url (no schema and host), which is not allowed
          unless(uri.relative?)
            @resp = setResponse(url)
          else # is relative
            @statusName = :'Precondition Failed'
            @statusMsg = "NOT_ABSOLUTE_URL: The content whose digested value '#{@digest}' seems to indicate a relative URL (or cannot be parsed an absolute URL). That is not allowed for /shortUrl/ resources. MUST be an absolute URL."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", @statusMsg)
          end
        else # nothing stored for that digest
          @statusName = :'Not Found'
          @statusMsg = "NO_SHORT_URL: The digest value '#{@digest}' has not been used to store any URL."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", @statusMsg)
        end
      end
      # If something else wasn't right along the way, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(url)
      if(@repFormat != :URLCONTENT and @repFormat != :REDIRECT)  # assume format is one of usual ones (JSON, XML, YAML)
        entity = BRL::Genboree::REST::Data::UrlEntity.new(@connect, url)
        entity.setStatus(@statusName, @statusMsg)
        @statusName = configResponse(entity, @statusName)
        $stderr.puts(__FILE__, __method__, "STATUS", "not urlcontent, with @statusName = #{@statusName}")
      elsif(@repFormat == :REDIRECT)
        # Not appropriate
        #url = ApiCaller.applyDomainAliases(url) # if we have a better domain name, use that for the open() instead
        @resp.body = ''
        @resp['Location'] = url
        @resp.status = HTTP_STATUS_NAMES[:Found]
      else # @repFormat is URLCONTENT and we need to provide contents of URL not the URL itself
        begin
          url = ApiCaller.applyDomainAliases(url) # if we have a better domain name, use that for the open() instead
          ioObj = open(url)
          deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableDelegateBody.new(:delegate => ioObj, :yield => true)
          @resp.body = deferrableBody
          @resp['Content-Type'] = 'text/html'
          @resp.status = HTTP_STATUS_NAMES[:OK]
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "not urlcontent, with ioObj = #{ioObj.inspect}")
        rescue SocketError => serr
          @statusName = :'Expectation Failed'
          @statusMsg = "BAD HOSTNAME: Cannot access the server specified by the url stored using digest '#{@digest}'. A socket error occurred, seemingly during host-name resolution."
          $stderr.puts "BAD HOSTNAME: Cannot access the server specified by the url stored using digest '#{@digest}'. A socket error occurred, seemingly during host-name resolution.\n    URL: #{url.inspect}\n    Exception Message: #{serr.message}\n    Exception Trace: #{serr.backtrace.join("\n")}"
        rescue => err
          @statusName = :'Expectation Failed'
          if(err.is_a?(RuntimeError) and err.message =~ /^redirection forbidden/)
            @statusMsg = "PROXY ERROR: Could not open the url stored using digest '#{@digest}'. It appears the URL target actually issues a redirect that cannot be handled (e.g. http->ftp, http->https, etc). There is no actual content to retrieve, only this cross-protocol redirect meta-instruction. Please use 'format=urlcontent' for only regular http-based URLs."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{@statusMsg}.\nException type: #{err.class}\nException msg: #{err.message}\nException trace:\n#{err.backtrace.join("\n")}")
          else
            @statusMsg = "PROXY ERROR: Could not open the url stored using digest '#{@digest}'. It appears the URL may not be a valid absolute URL for a working site."

          end
          $stderr.debugPuts(__FILE__, __method__, "ERROR",  "Could not open the url stored using digest '#{@digest}'. It appears the URL may not be a valid absolute URL for a working site.\n    @statusMsg: #{@statusMsg.inspect}\n    URL: #{url.inspect}\n    Exception Message: #{err.message}\n    Exception Trace: #{err.backtrace.join("\n")}")
        rescue Timeout::Error => toe
          @statusName = :'Expectation Failed'
          @statusMsg = "TIMEOUT: The connection to the remote host timed out while trying to retrieve the content, so retrieval failed."
          $stderr.puts "TIMEOUT: The connection to the remote host timed out while trying to retrieve the content, so retrieval failed. Timeout::Error trying to open URL (had to wait too long for the URL contents to come back).\n    URL: #{url.inspect}\n    Exception Message: #{toe.message}\n    Exception Trace: #{toe.backtrace.join("\n")}"
        end
      end
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
