
# Predeclare name space & class
module BRL ; module Genboree ; module REST ; module Helpers
  class ApiUriHelper ; end
end ; end ; end ; end

require 'uri'
require 'cgi'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/abstract/resources/user'

module BRL ; module Genboree ; module REST ; module Helpers
  class ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine these:
    NAME_EXTRACTOR_REGEXP = /(.+)/    # To get just the name of the resource from the URL
    EXTRACT_SELF_URI = %r{^(.+)(?:\?.*)?$}     # To get just this resource's portion of the URL, with any suffix stripped off
    # Generic set of regexps that can extract the "type" of entity in the URL
    # - longest/most specific FIRST
    # - used by extractType() in order given in array
    EXTRACT_TYPE_ARRAY =
    [
      %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trks/([^/\?]+)}, # an aspect of trks/ ; maybe count, annos, etc.
      %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trk/[^/]+/([^/\?]+)}, # something within a trk
      %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/([^/\?]+)}, # something within a DB
      %r{^http://[^/]+/REST/v\d+/grp/[^/]+/kb/[^/]+/([^/\?]+)}, # something within a KB
      %r{^http://[^/]+/REST/v\d+/grp/[^/]+/([^/\?]+)},          # something with a group ; maybe kb, maybe db, maybe prj
      %r{^http://[^/]+/REST/v\d+/([^/\?]+)}          # something at the top level. Like usr/ or grp/
    ]
    # List of all reusable component symbols for this class and its subclasses
    # - when initialized, class will look for these in reusableComponents hash

    # Each resource-specific API Uri Helper subclass should redefine this as needed ('groupId', 'refSeqId', 'typeid', etc):
    ID_COLUMN_NAME = 'id'

    # HTTP status codes that download/upload methods should reattempt action if encountered
    REATTEMPT_HTTP_CODES = [502, 503, 504]

    # Cache of various information which has already been retrieved/figured out
    # to avoid rework. Cache is keyed by uri & property key.
    attr_accessor :cache
    attr_accessor :dbu
    attr_accessor :genbConf
    attr_accessor :rackEnv
    attr_accessor :superuserApiDbrc, :superuserDbDbrc
    # Some methods set this to a sensible string (esp if something bad/wrong/not allowed)
    attr_accessor :lastStatusMsg
    # A [BRL::Genboree::REST::ApiCaller] object that has been initialized with login/pass information
    attr_accessor :apiCaller

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @superuserApiDbrc = @superuserDbDbrc = nil
      init(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      # Make sure we have a GenboreeConfig
      @genbConf = genbConf || BRL::Genboree::GenboreeConfig.load()
      # Try to reuse existing components from caller (maybe from other apiUriHelper subclass instances or something)
      extractReusableComponents(reusableComponents)
      # Get superuser API and DB dbrcs for the local Genboree instance (will be used to look up any per-user API credential info)
      @superuserApiDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf) unless(@superuserApiDbrc)
      @superuserDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile, :db) unless(@superuserDbDbrc)
      # Make sure we have a DbUtil instance for the local Genboree instance
      if(dbu.nil?)
        @dbu =  BRL::Genboree::DBUtil.new(@superuserDbDbrc.key, nil, nil)
        @clearDbu = true
      else
        @dbu = dbu
        @clearDbu = false
      end
      # Init cache for this instance (don't want to cache for too long, since things change,
      # but while doing a single task or request this is probably a good idea)
      @cache = Hash.new { |hh, kk| hh[kk] = {} }
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      reusableComponents.each_key { |compType|
        case compType
        when :superuserDbDbrc
          @superuserDbDbrc = reusableComponents[compType]
        when :superuserApiDbrc
          @superuserApiDbrc = reusableComponents[compType]
        when :rackEnv
          @rackEnv = reusableComponents[compType]
        end
      }
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      @dbu.clear() if(@dbu and @clearDbu)
      @cache.clear() if(@cache)
      @cache = nil
    end

    # Get name of host from URI
    def extractHost(uri)
      host = nil
      if(uri)
        # First, try from cache
        host = getCacheEntry(uri, :host)
        if(host.nil?)
          # If not cached, try to extract it. Use constant in SUBCLASS, not this class (!!)
          uri =~ %r{^[^:]+://([^/]+)}
          if($1)
            host = $1
            # Cache name
            setCacheEntry(uri, :host, host)
          end
        end
      end
      return host
    end

    # Get type of entity in URL
    def extractType(uri)
      retVal = nil
      EXTRACT_TYPE_ARRAY.each { |extractRe|
        if(uri =~ extractRe)
          retVal = $1
          break
        end
      }
      return retVal
    end

    # Get name of database from URI
    def extractName(uri)
      name = nil
      if(uri)
        # First, try from cache
        name = getCacheEntry(uri, :name)
        if(name.nil?)
          # If not cached, try to extract it. Use constant in SUBCLASS, not this class (!!)
          uri =~ self.class::NAME_EXTRACTOR_REGEXP
          if($1)
            name = CGI.unescape($1) if($1)
            # Cache name
            setCacheEntry(uri, :name, name)
          end
        end
      end
      return name
    end

    # Get just this resource's portion of the URL, with any suffix stripped off
    def extractPureUri(uri, withGbKey=false)
      retVal = nil
      if(uri)
        # Check cache to see if we've seen this EXACT uri before and extracted
        # this resources portion before. Thus don't use getCacheEntry().
        uriCache = @cache[uri]
        retVal = uriCache[:pureUri]
        if(retVal.nil?) # then have to extract manually
          uri =~ self.class::EXTRACT_SELF_URI
          retVal = $1
          if(retVal)
            uriCache[:pureUri] = retVal
          end
        end
      end
      # Do gbKey if present?
      if(withGbKey)
        gbKey = extractGbKey(uri)
        if(gbKey)
          retVal = "#{retVal}?gbKey=#{gbKey}"
        end
      end
      return retVal
    end

    def extractPath(uri, withGbKey=false)
      retVal = nil
      if(uri)
        pureUri = self.extractPureUri(uri, withGbKey)
        if(pureUri)
          begin
            uriObj = URI.parse(pureUri)
            retVal = uriObj.path
            retVal << "?#{uriObj.query}" if(withGbKey)
          rescue
            # nada, retVal will stay nil
          end
        end
      end
      return retVal
    end

    def extractQuery(uri)
      retVal = nil
      if(uri)
        begin
          uriObj = URI.parse(uri)
          retVal = uriObj.query
        rescue
          # nada, retVal will stay nil
        end
      end
      return retVal
    end

    def extractGbKey(uri)
      retVal = nil
      if(uri)
        begin
          uriObj = URI.parse(uri)
          if(uriObj)
            params = CGI.parse(uriObj.query)
            if(params and params.key?('gbKey'))
              retVal = params['gbKey']
              if(retVal.is_a?(Array))
                retVal = retVal.first
              end
            end
          end
        rescue
          # nada, retVal will stay nil
        end
      end
      return retVal
    end

    def removeQuery(uri)
      retVal = nil
      queryIndex = uri.index("?")
      if(queryIndex)
        retVal = uri[0...queryIndex]
      else
        retVal = uri
      end
      return retVal
    end

    # Is the name of this resource syntactically acceptable
    # - subclasses override if generic test insufficient
    def nameValid?(uri)
      retVal = false
      if(uri)
        # First, try from cache
        nameValid = getCacheEntry(uri, :nameValid)
        if(nameValid.nil?) # then test manually
          name = extractName(uri)
          if( name and name =~ /\S/ and name !~ /[\t\n]/)
            nameValid = true
            setCacheEntry(uri, :nameValid, nameValid)
          else
            nameValid = false
          end
        end
        retVal = nameValid
      end
      return retVal
    end

    # Get MySQL table id number (e.g. groupId, refSeqId, typeid, etc)
    def id(uri)
      id = nil
      if(uri)
        # First, try from cache
        id = getCacheEntry(uri, :id)
        if(id.nil?)
          # If not cached, try to retrieve it
          #
          # Get table row
          row = tableRow(uri)
          if(row and !row.empty?)
            id = row[self.class::ID_COLUMN_NAME]
            # Cache id
            setCacheEntry(uri, :id, id)
          end
        end
      end
      return id
    end

    # Does this resource actually exist?
    def exists?(uri)
      id = id(uri)
      return !id.nil?
    end

    # Looks for duplicate resources.
    def hasDups?(uris)
      retVal = false
      uriHash = Hash.new { |hh,kk| hh[kk] = 0 }
      uris.each { |uri|
        # Strip off everything after the first '?'.
        uri =~ /^([^\?]+)(?:\?.*)?$/
        if($1)
          uriHash[$1] += 1
          if(uriHash[$1] > 1) # found at least 1 dup
            retVal = true
            break
          end
        end
      }
      return retVal
    end

    # Is the URL accessible due to its gbKey parameter?
    # - Intended to be used with an ALREADY extracted gbKey
    # - However, if not available and gbKey param is nil, it will try to extract one
    #   from the query string of the URI.
    #
    # [+uri+] The uri String to check for gbKey based access
    # [+reqMethod+] (Optional; default=:get). One of :get, :head, :options, :put, :post, :delete (only first 3 can be done via gbKey)
    # [+gbKey+] (Optional; default=nil, i.e. extract from uri)
    # [+returns+] Either :OK or :Unauthorized. Regardless, @lastStatusMsg will be set to a useful message.
    def gbKeyAccess(uri, reqMethod=:get, gbKey=nil)
      retVal = :Unauthorized
      @lastStatusMsg = "BAD_API_URL: The requested resource is not available using gbKey. Req. Method: #{reqMethod.inspect} ; gbKey param: #{gbKey.inspect}\n  URI: #{uri}"
      if(reqMethod == :get or reqMethod == :head or reqMethod == :options)
        # Parse uri
        uriObj = URI.parse(uri)
        rsrcPath = uriObj.path
        queryString = uriObj.query
        # Do we have enough to go on?
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "reqMethod=#{reqMethod.inspect} ; gbKey=#{gbKey.inspect} ; uri: #{uri.inspect} ; rsrcPath = #{rsrcPath.inspect}")
        if(!rsrcPath.nil? and !rsrcPath.empty?)
          # Find a gbKey value if one to check was not provided as a param
          if(!gbKey)
            if(queryString and queryString =~ /gbKey=([^&#]+)/) # then try to get one from the uri's query string
              gbKey = $1.to_s.strip
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: found in query string: #{gbKey.inspect}")
            else # try to get ANY public key that covers use for this resource???????
              gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getAnyPublicKey(@dbu, rsrcPath)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: discovered because it is public: #{gbKey.inspect}")
            end
          end

          # Ok, should have gbKey at this point. It MUST be the correct one (no sending wrong/old key and getting access)
          unless(gbKey.nil? or gbKey.empty?)
            # Get any resources in unlockedGroupResources that match the key and test if the resourceUri matches
            unlockRsrcRows = @dbu.selectUnlockedResourcesByKey(gbKey)
            if(!unlockRsrcRows.nil? and !unlockRsrcRows.empty?)
              # Trying to match the resource
              unlockRsrcRows.each { |rsrc|
                if(idx = rsrcPath.index(rsrc['resourceUri']))
                  retVal = :OK
                  @lastStatusMsg = "OK"
                  break
                else
                  retVal = :Unauthorized
                  @lastStatusMsg = "BAD_KEY: The gbKey provided does not match this resource."
                end
              }
            else
              retVal = :Unauthorized
              @lastStatusMsg = "BAD_KEY: The gbKey provided does not match any resources."
            end
          else # no gbKey provided, not gbKey in uri, no go.
            retVal = :'Bad Request'
            @lastStatusMsg = "BAD_API_URL: No gbKey available for checking access."
          end
        end
      end
      return retVal
    end

    # --------------------------------------------------
    # API Request Helpers - {{
    #   Child classes are typically used for providing a specific set of functions
    #   related to an API resource such as a group or a project, etc. that are in
    #   excess of a single API call. For example, the KbApiUriHelper organizes
    #   multiple requests to upload a set of KB documents, and the fileApiUriHelper
    #   provides functions to upload and download files with reattempts do
    #   reduce errors due solely to network instability. Tools have previously implemented
    #   their own versions of these functions, violating the DRY principle. Here and in
    #   child classes we attempt to remove these violations.
    # --------------------------------------------------

    # @see [BRL::Genboree::REST::ApiCaller#initialize]
    def setupApiCallerByLogin(login, pass=nil)
      @apiCaller = BRL::Genboree::REST::ApiCaller.new("", "", login, pass)
    end
  
    # Setup apiCaller to make a request at the @url@
    def prepareRequest(url)
      uriObj = URI.parse(url)
      @apiCaller.setHost(uriObj.host)
      @apiCaller.setRsrcPath("#{uriObj.path}?#{uriObj.query}")
      return @apiCaller
    end

    # Provide a consistent response interface for functions here and in children
    # @return [Hash] with keys
    #   [String] :msg error message to display if request failed
    #   [Hash, Array] the JSON parsed response body if successful
    #   [Net::HTTPResponse] :resp
    #   [Boolean] :success true if request succeeded
    #   [String] :url the url where the request was made
    def getHelperRespObj
      rv = {
        :msg => nil,
        :obj => nil,
        :resp => nil,
        :success => false,
        :url => nil,
      }
    end

    # Provide a consistent (response) interface for methods that make simple HTTP requests
    # @param [Symbol] method an HTTP method as a downcase symbol
    # @param [String] url the url to make the request at
    # @return [Hash] @see #getHelperRespObj
    # @todo expand this to add more flexibility if it is needed wrt headers, non-json payloads, etc.
    # @note most payloads assumed to be json to save work but sometimes this is not possible (uploading files)
    #   as a result design here could be improved
    def makeRequest(method, url, payloadObj=nil, payloadIsJson=true)
      rv = getHelperRespObj
      prepareRequest(url)
      rv[:url] = url

      # check payload
      payload = nil
      unless(payloadObj.nil?)
        if(payloadIsJson)
          payload = JSON(payloadObj) rescue nil
        else
          payload = payloadObj
        end
      end
      if(!payloadObj.nil? and payload.nil?)
        # then payload is set but is not json -- do not make request
        rv[:msg] = "Could not make request to #{rv[:url].inspect} because the provided payload is not JSON!"
      else
        # then payload is ok -- make request
        varMap = nil
        args = [varMap, payload]
        if(method == :put)
          args.reverse!
        end
        rv[:resp] = @apiCaller.send(method, *args)
        rv[:success] = (200..299).include?(rv[:resp].code.to_i)
        if(rv[:success])
          rv[:obj] = JSON.parse(rv[:resp].body)['data'] rescue nil
          if(rv[:obj].nil?)
            rv[:success] = false
            rv[:msg] = "Cannot parse as JSON the response data"
          end
        else
          rv = setErrorMsg(rv)
        end
      end
      return rv
    end

    # Set error message for a helperRespObj
    # @param [Hash] respObj @see #makeRequest
    # @param [Integer] bodyChars number of characters from response body to include in error message;
    #   may be -1 for all characters
    # @return [NilClass]
    def setErrorMsg(helperRespObj, bodyChars=100)
      bodyChars = ( bodyChars > 0 ? bodyChars - 1 : -1 )
      sizeMsg = ( bodyChars > 0 ? "first #{bodyChars+1} characters of response body:" : "full response body:" )
      helperRespObj[:msg] = "Request at #{helperRespObj[:url].inspect} failed with code #{helperRespObj[:resp].code.inspect}; #{sizeMsg} #{helperRespObj[:resp].body[0..bodyChars]}" rescue nil
      helperRespObj[:msg] = "Could not format error message: is helperRespObj the return value from #makeRequest?" if(helperRespObj[:msg].nil?)
      return helperRespObj
    end

    # }} -

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    # Get appropriate database entity table row
    # - SUBCLASSES MUST OVERRIDE
    def tableRow(uri)
      row = nil
      if(uri)
        # First, try from cache
        row = getCacheEntry(uri, :tableRow)
        if(row.nil?)
          raise TypeError, "ERROR: This class (#{self.class}) has not properly overridden the #tableRow() method."
        end
      end
      return row
    end

    # Gets the appropriate cache entry. Generally, we want to cache by
    # the PURE resource uri, not the argument uri (which could be a subordinate resource
    # and/or could have a query string, etc, which would make it a bad cache key in MOST cases).
    def getCacheEntry(uri, key)
      retVal = nil
      if(uri and key)
        # Get this resource's portion of the URL, any suffix stripped off
        pureUri = extractPureUri(uri)
        if(pureUri)
          uriCache = @cache[pureUri]
          retVal = uriCache[key]
        end
      end
      return retVal
    end

    # Sets the appropriate cache's entry. Generally, we want to cache by
    # the PURE resource uri, not the argument uri (which could be a subordinate resource
    # and/or could have a query string, etc, which would make it a bad cache key in MOST cases).
    def setCacheEntry(uri, key, value)
      retVal = nil
      if(uri and key)
        # Get this resource's portion of the URL, any suffix stripped off
        pureUri = extractPureUri(uri)
        if(pureUri)
          uriCache = @cache[pureUri]
          retVal = uriCache[key] = value
        end
      end
      return retVal
    end

    # Associate container/parent uris to child/containee uris (track entity list to tracks, etc.)
    #   Caches results so that a previously seen URI is skipped; updates to underlying containers
    #   (which shouldnt be needed for anticipated Rules Helper usage) can be done by calling #clear first
    # @param containerUris [Array] an array of (track or container) uris
    # @param userId [String] Genboree userId used by WrapperApiCaller
    # @return [Array] an array of track uris
    # @note child classes must implement @typeOrder, @type2Regexp, @type2Method (and associated methods),
    #   @containers2Children (emptied with call to clear)
    # @raise ArgumentError if one of containerUris is not a recognized type for the subclass
    def mapContainersToChildren(containerUris, userId)
      containers2Children = Hash.new([])
      containerUris = [containerUris] unless containerUris.is_a?(Array)
      # process each uri based on its type
      containerUris.each {|uri|
        # cache results from previous runs -- call clear() to empty cache
        if(@containers2Children.key?(uri))
          next
        end

        matchFound = false
        @typeOrder.each{|type|
          regexp = @type2Regexp[type]
          if(regexp =~ uri)
            matchFound = true
            method = @type2Method[type]
            if(method.nil?)
              containers2Children[uri] = [uri]
            else
              childUris = self.send(method, uri, userId)
              containers2Children[uri].push(*childUris)
            end
            break
          end
        }
        unless(matchFound)
          raise ArgumentError, "uri=#{uri.inspect} in containerUris is not recognized as a container type"
        end
      }
      @containers2Children = containers2Children
      return @containers2Children
    end

    # Helper method to classify sample-related URIs to a Hash of meta information about the uri including:
    #   :type a [Symbol] describing their type
    #   :name a [String] of the entity name extracted from the URI
    # This can be used to provide more informative messages in Rules Helpers, for example
    # @param [Array<String>] uris to classify
    # @return [Hash<Symbol>] map uri to its meta information
    # @note the first match group in @type2Regexp MUST be the name of the entity as it appears in the Workbench
    #   see note of mapContainersToChildren for other requirements of child classes to implement this method
    def classifyUris(uris)
      uri2Meta = {}
      uris.each{|uri|
        meta = {}
        @typeOrder.each{|type|
          regexp = @type2Regexp[type]
          if(uri =~ regexp)
            meta[:type] = type
            meta[:name] = $1
            break
          end
        }
        uri2Meta[uri] = meta
      }

      return uri2Meta
    end

    # Convert parent/container uris to child uris
    # The order of items in the returned array will match the order of items in the input array
    # Uniqueness is enforced on the returned array
    #
    # @param containerUris [Array] an array of container uris
    # @param userId [String] Genboree userId used by WrapperApiCaller
    # @return [Array] an array of child uris (items within the containers)
    def expandContainers(containerUris, userId)
      uriArray = []
      containersToChildren = mapContainersToChildren(containerUris, userId)
      containerUris.each{|uri|
        childUris = containersToChildren[uri]
        childUris.each{|childUri|
          unless(uriArray.index(childUri))
            uriArray << childUri
          end
        }
      }
      return uriArray
    end # end expandSampleContainers method

  end # class ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
