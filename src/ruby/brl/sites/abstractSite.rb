#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'brl/util/util'
require 'brl/extensions/http'

module BRL; module Sites
  # functions shared by bioOntology, pubmed, etc.
  class AbstractSite
    
    attr_reader :proxyHost, :proxyPort, :proxyPathRoot
    attr_accessor :tryProtos

    def initialize(opts={})
      raise NotImplementedError.new("Subclass #{self.class.to_s} does not define class constant HOST as required") unless(self.class.const_defined?(:HOST))
      if(opts[:proxyHost] and opts[:proxyPort])
        # :proxyPathRoot is optional
        setProxy(opts[:proxyHost], opts[:proxyPort], opts[:proxyPathRoot])
      end
      # Init the list of protocols using overridable method:
      @tryProtos = self.class.protocols()
    end

    # Construct URL, handling escaping of String and Array query string components
    # @param [String] host the URL host
    # @param [String] path the URL path
    # @param [Hash<String, String>] query hash to use for query string components
    # @param [Boolean] proxy if true, modify url to proxy location instead if the proxy instance
    #   variables have been set: @proxyHost, @proxyPort, @proxyPathRoot, otherwise the argument
    #   is overridden to false and no proxy attempt is made
    # @param [Hash<Symbol, Object>] Optional. Options hash.
    # @return [String] url a properly formed URL from given components
    def buildUrl(host, path, query={}, proxy=true, opts={ :proto => self.class.protocols().first } )
      retVal = nil
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "opts:\n\n#{opts.inspect}\n\n")
      raise ArgumentError, "query=#{query.inspect} must respond to :each_key" unless(query.respond_to?(:each_key))
      # override value of proxy if it isnt setup
      if(@proxyHost.nil? or @proxyPort.nil? or @proxyPathRoot.nil?)
        proxy = false
      end

      # setup query string components (ordered to help with proxying, if it is being done)
      queryArray = []
      queryKeys = query.keys().sort!()
      queryKeys.each{|kk|
        escapedValue = nil
        value = query[kk]
        unless(value.nil?)
          if(value.is_a?(Array))
            escapedValue = value.collect{|ii| CGI.escape(ii)}.join(",")
          else
            escapedValue = CGI.escape(value)
          end
          unless(escapedValue.empty?)
            queryArray.push("#{CGI.escape(kk)}=#{escapedValue}")
          end
        end
      }
      if(proxy) # proxy is http, but can handle a redirection to https seamlessly for us.
        if(host == @proxyHost)
          retVal = "http://#{@proxyHost}:#{@proxyPort}#{path}?#{queryArray.join("&")}"
        else
          # nginx unescapes path, double escape it
          path = path.gsub(/%/, "%25")
          retVal = "http://#{@proxyHost}:#{@proxyPort}#{@proxyPathRoot}#{path}?#{queryArray.join("&")}"
        end
      else
        # What proto
        proto = ( opts[:proto] or self.class.protocols().first )
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Trying remote site via #{proto.inspect} ...")
        retVal = "#{proto}://#{host}#{path}?#{queryArray.join("&")}"
      end
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "SITE => Built url:\n\n#{retVal.inspect}\n\n")
      return retVal
    end

    # @return [Array<Symbols>] OPTIONAL OVERRIDE. List of preferred protocol to use and any fallbacks. Currently only
    #   :http and :https supported. Defaults to [ :http ]
    def self.protocols()
      [ :http ]
    end

    # Configure proxy server mainly used to cache responses from HOST
    # @param [String] proxyHost the proxy host domain e.g. "10.15.5.109"
    # @param [Fixnum, String] proxyPort the proxy port e.g. 15505
    # @param [nil, String] proxyPathRoot the mount point for the proxy, defaults to "/#{HOST}"
    #   and MUST include initial slash
    # @note changes to argument names should be accompanied with changes to the associated
    #   symbols in intialize and fromUrl
    # @note only tested on an nginx proxy server with the assumption that nginx has been 
    #   either configured or defaults to resolve any URL encodings in (i.e. unescape) the 
    #   URL path provided to it -- this assumption is hard coded in buildUrl()
    # @note use of the proxy also assumes that the proxy server responds to PURGE requests,
    #   an extension of GET, and that the headers set in class constants beginning with
    #   "PROXY_" may be used to bypass the proxy cache or to "dont" cache
    def setProxy(proxyHost, proxyPort, proxyPathRoot=nil)
      proxyPathRoot = (proxyPathRoot.nil? ? "/#{self.class::HOST}" : proxyPathRoot)
      @proxyHost = proxyHost
      @proxyPort = proxyPort
      @proxyPathRoot = proxyPathRoot
    end

    # Purge Genboree nginx cache at the url path and query string given by a url
    # @param [String] url a parsable url with path and query components; query components produced
    #   by this library are sorted alphabetically on the parameter names
    # @return [Boolean] true if cache has been purged, false if it hasn't, and nil if
    #   the proxy variables have not been set up, @see setProxy
    def purgeCache(url)
      retVal = nil
      if(@proxyHost.nil? or @proxyPort.nil?)
        retVal = nil
      else
        # Caching proxy is http-based (not https)
        uriObj = URI.parse(url)
        http = ::Net::HTTP.new(@proxyHost, @proxyPort)
        req = ::Net::HTTP::Purge.new("#{uriObj.path}?#{uriObj.query}")
        resp = http.request(req)
        if(@debug)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", resp.class)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", JSON.pretty_generate(resp.each_header{|hh| }))
        end
        if(resp.is_a?(::Net::HTTPOK))
          retVal = true
        elsif(resp.is_a?(::Net::HTTPNotFound))
          retVal = false
        end
      end
      return retVal
    end

    # Log errors that may occur while making requests to HOST
    # @param [Object] err
    # @return [NilClass]
    def logError(err)
      $stderr.debugPuts(__FILE__, __method__, "#{self.class}_ERROR", "err.class=#{err.class}")
      $stderr.debugPuts(__FILE__, __method__, "#{self.class}_ERROR", "message=#{err.message}")
      $stderr.debugPuts(__FILE__, __method__, "#{self.class}_ERROR", "backtrace=\n#{err.backtrace.join("\n")}")
      return nil
    end
  end
end; end
