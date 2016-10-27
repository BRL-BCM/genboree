require 'open-uri'
require 'thread'
require 'parallel'
require 'brl/sites/abstractSite'

module BRL; module Sites

  # @todo streaming when response body is large?
  # @todo reattempt http request if failure?
  # @todo catch ::Timeout::Error and redo request with small page size
  class BioOntology < AbstractSite
    API_KEY_ENV_VAR = 'BIOPORTAL_API_KEY'
    DEFAULT_API_KEY = ENV[API_KEY_ENV_VAR]
    HOST = "data.bioontology.org"
    PATH = "/search" # @todo DEPRECATED
    ONT_REGEX = /\/ontologies\/([^\/\?]+)(?:$|\/|\?)/
    CLASS_REGEX = /\/classes\/([^\/\?]+)\/[^\/\?]+/
    BODY_SIZE = 1024

    # proxy settings
    # @return [Fixnum] the number of seconds an entry in the cache is allowed before it is 
    #   forcibly updated
    PROXY_CACHE_LIFE = 1209600 # 2 * 7 * 24 * 60 * 60
    PROXY_BYPASS_CACHE = "X-GB-Bypass-Cache"
    PROXY_DONT_CACHE = "X-GB-Dont-Cache"
    PROXY_CACHE_STATUS = "x-gb-cache-status"
    PROXY_CACHE_HIT = "HIT"
    DATE_RESP_HEADER = "date"

    # query string parameter names
    QUERY_PARAM = "q"
    API_KEY_PARAM = "apikey"
    ONTOLOGY_PARAM = "ontology"
    ONTOLOGIES_PARAM = "ontologies"
    EXACT_MATCH_PARAM = "exact_match"
    SUBTREE_PARAM = "subtree_root"
    # @todo above are DEPRECATED
    PAGE_PARAM = "page"
    INCLUDE_PARAM = "include"
    INCLUDE_LINKS_PARAM = "include_links"
    INCLUDE_CONTEXT_PARAM = "include_context"
    FORMAT_PARAM = "format"
    SUGGEST_PARAM = "suggest"
    PAGE_SIZE_PARAM = "pagesize"

    # paging constants
    FIRST_PAGE = 1
    MAX_PAGES = 20 # @todo DEPRECATED
    MAX_PAGE_SIZE = 5000 #{"errors": ["Page size limit is 5000. Page size in request is 5001"],"status": 400}
    PRIME_PAGE_SIZES = [4993, 4987, 4973]
    PREF_PAGE_SIZE = 4999 # 5000 has been observed to have issues, this number is prime

    # json response keys
    COLLECTION_KEY = "collection"
    LINKS_KEY = "links"
    LINKS_NEXT_PAGE_KEY = "nextPage"
    LINKS_DESCENDANTS_KEY = "descendants"
    PAGE_KEY = "page"
    NEXT_PAGE_KEY = "nextPage"
    PAGE_COUNT_KEY = "pageCount"
    PREF_LABEL_KEY = "prefLabel"
    DEFINITION_KEY = "definition"
    SYNONYM_KEY = "synonym"
    ERROR_KEY = "error"
    STATUS_KEY = "status"
    ERRORS_KEY = "errors"

    attr_accessor :debug, :lastError, :prefLabelForTerm
    attr_reader :ontologies, :subtree, :subtrees, :apiKey, :timeData, :errors, :collectErrors

    # define our own setter methods (ruby forces built-in setter e.g. x=(val) to ALWAYS return val,
    # probably to enforce clarity in assignment chains like y = x = 3 where it would be weird if
    # y didnt store the value 3 because of some overwritten x= setter)
    
    # @see setOntologies
    # @see setSubtrees
    def setOntologiesAndSubtrees(ontologies, subtrees)
      @ontologies = @subtrees = nil
      setOntologies(ontologies)
      setSubtrees(subtrees)
      return @ontologies, @subtrees
    end

    # set the ontologies to use; must be
    #   nil or parallel with @subtrees; you may set to nil to fix parallelism with @subtrees
    #   after instantiation or use the #setOntologiesAndSubtrees method
    # @param [NilClass, String, Array<String>] ontologies the ontologies to set, if a string, 
    #   multiple ontologies will be split on a comma
    # @return [Array<String>]
    def setOntologies(ontologies)
      if(ontologies.nil?)
        @ontologies = ontologies
      elsif(ontologies.is_a?(String))
        @ontologies = ontologies.split(",")
      elsif(!ontologies.is_a?(Array))
        @ontologies = [ontologies]
      else
        @ontologies = ontologies
      end
      raise ArgumentError, "ontologies must be an array" unless(@ontologies.nil? or @ontologies.is_a?(Array))
      if(@ontologies.is_a?(Array))
        # we further require that we have been given at least something for the ontology
        @ontologies.each_index{ |ii| 
          ont = @ontologies[ii]
          if(ont.nil? or ont.empty?)
            raise ArgumentError, "The ontology you provided at index #{ii.inspect} is nil or empty, please provide an ontology acronym instead"
          end
        }
      end
      raise ArgumentError, "ontologies must be parallel to subtrees; it must have #{@subtrees.size} items" if(!@subtrees.nil? and !@ontologies.nil? and @subtrees.size != @ontologies.size)
      return @ontologies
    end

    # set the subtrees to use; must be nil or be parallel with @ontologies; you may set to 
    #   nil to fix parallelism with @ontologies after instantiation or use the #setOntologiesAndSubtrees 
    #   method; to use a mix of ontologies with a subtree and a full ontology, provide nil 
    #   or "" in place of a specific subtree
    # @param [NilClass, String, Array<String>] subtrees the subtrees to use
    # @return [NilClass, Array<String>] the updated value of @subtrees
    def setSubtrees(subtrees)
      if(subtrees.nil? or subtrees.empty?)
        @subtrees = nil
      elsif(!subtrees.is_a?(Array))
        subtrees = [subtrees]
        @subtrees = subtrees.map{|ss| CGI.unescape(ss)}
      else
        @subtrees = subtrees.map{|ss| ss.nil? ? nil : CGI.unescape(ss)}
      end
      raise ArgumentError, "subtrees must be an array" unless(@subtrees.nil? or @subtrees.is_a?(Array))
      raise ArgumentError, "subtrees must be parallel to ontologies; it must have #{@ontologies.size} items" if(!@ontologies.nil? and !@subtrees.nil? and @subtrees.size != @ontologies.size)
      return @subtrees
    end

    def setApiKey(apiKey)
      apiKey = (apiKey.nil? ? DEFAULT_API_KEY : apiKey)
      raise ArgumentError, "an apiKey must be provided via instantiation methods or locatable in the #{API_KEY_ENV_VAR} "\
                           "environment variable" if(apiKey.nil?)
      return @apiKey = apiKey
    end

    # setup object
    # @param [String, Array] ontologies the ontology or ontologies to use in requests to HOST
    # @param [String] subtree the url/id of the node to use as a subtree for queries to HOST
    # @param [String] apiKey the authentication key for using HOST API
    # @param [Hash<Symbol, String>] opts named arguments used to:
    #   setup proxy @see setProxy in parent
    # @return [BRL::Sites::BioOntology] object
    def initialize(ontologies, subtrees="", apiKey=nil, opts={})
      super(opts)
      @ontologies = setOntologies(ontologies)
      @subtrees = setSubtrees(subtrees)
      @apiKey = setApiKey(apiKey)
      @debug = false
      @errors = {} # map url to error information, thread safe
      @collectErrors = {}
      @timeData = {}
      @requestTimeData = []
      @prefLabelForTerm = nil
    end

    # Alternative instantiation method
    # @param [String] url a url with ontolog(y|ies), apikey, and subtree in url somewhere, 
    #   but intended be present as in the /search style URLs or the /classes style URLs
    # @param [Hash<Symbol, String>] opts named arguments used to setup proxy @see setProxy and
    #   @see initialize
    # @return [BRL::Sites::BioOntology] object from new()
    def self.fromUrl(url, opts={})
      obj = nil
      begin
        validationErrors = []

        # get ontologies
        ontologies = nil
        if(url =~ /ontolog(?:y|ies)=(.*?)(?:$|&)/)
          matchData = $1
          ontologies = matchData.split(",")
        elsif(url =~ ONT_REGEX)
          matchData = $1
          ontologies = [matchData]
        end
        if(ontologies.nil?)
          validationErrors << "ERROR: url missing query string parameter \"ontology\" or \"ontologies\"" if(ontologies.nil?)
        end

        # get subtree
        subtree = ""
        if(url =~ /subtree_root=(.*?)(?:$|&)/)
          matchData = $1
          subtree = CGI.unescape(matchData)
        elsif(url =~ CLASS_REGEX)
          matchData = $1
          # double unescape in case of proxy
          subtree = CGI.unescape(CGI.unescape(matchData))
        end

        # get apikey
        apiKey = nil
        if(url =~ /apikey=(.*?)(?:$|&)/)
          matchData = $1
          apiKey = CGI.unescape(matchData)
        end

        obj = self.new(ontologies, subtree, apiKey, opts)
      rescue => err
        validationErrors << "ERROR: something went wrong creating bioOntology object: #{err.inspect}"
      end
      $stderr.debugPuts(__FILE__, __method__, "ERROR",  validationErrors.join("\n")) unless(validationErrors.empty?)
      return obj
    end

    # Search for a term in the object's given ontologies
    # @param term [String] term to search for
    # @param [Boolean] prefix use term for prefix search? (otherwise tokenize term and return results with any matching tokens)
    # @param [Fixnum] maxSize the maximum length of the returned array (limits number of requests to HOST)
    # @param [Hash] opts set of named parameters including
    #   :termViaSynonym [Boolean] only include in result set those terms whose prefLabel contains
    #     the term (false), or allow terms in the result set whose PREF_LABEL doesnt match the
    #     term, but whose synonyms do (true); default=false
    # @return [Array<Hash>] a collection of term objects from HOST or nil if an error occurs
    # @note some terms may not be present due to errors, check @errors for more information
    # @todo after how many errors at host should this method error?
    # @todo options appear in many places, put in class constant
    def requestTermsByNameViaSubtree(term, prefix=false, maxSize=nil, opts={})
      raise ArgumentError, "One or more ontologies must be set before calling #{__method__}!" if(@ontologies.nil?)
      @errors = {}
      retVal = nil
      @timeData = {}
      tt1 = tt7 = tt8 = tt9 = nil
      @requestTimeData = []
      tt1 = Time.now
      maxSize = (maxSize.nil? ? MAX_PAGE_SIZE*MAX_PAGES : maxSize)

      # handle optional named parameters
      # supportedOpts contains defaults for the options
      supportedOpts = {:termViaSynonym => true, :threads => 6, :timeout => 300, :mode => :token}
      opts = supportedOpts.merge(opts)
      if(prefix)
        opts.merge!(:mode => :prefix)
      end
      begin
        # collect ontology terms
        tt1 = Time.now
        allMatches = collectAndSearchForTerm(term, opts)
        tt8 = Time.now
 
        # sort the results
        allMatches.sort!{|aTerm, bTerm| aTerm[PREF_LABEL_KEY] <=> bTerm[PREF_LABEL_KEY]}
        tt9 = Time.now
        diff = tt9 - tt8
        @timeData[:"sort logic"] = diff

        # handle subset request from maxSize parameter
        retVal = allMatches[0...maxSize]
      rescue => err
        retVal = nil
        logError(err)
      end
      diff = Time.now - tt1
      @timeData[:full] = diff
      $stderr.puts(reportTimeData()) if(@debug)
      return retVal
    end

    # @see requestTermsByNameViaSubtree
    def requestExactTermsViaSubtree(term, maxSize=nil, opts={})
      maxSize = (maxSize.nil? ? MAX_PAGE_SIZE*MAX_PAGES : maxSize)
      supportedOpts = {:termViaSynonym => true}
      opts = supportedOpts.merge(opts)
      opts.merge!({:mode => :exact}) # mode must be exact for this method
      begin
        allMatches = collectAndSearchForTerm(term, opts)
        allMatches.sort!{|aTerm, bTerm| aTerm[PREF_LABEL_KEY] <=> bTerm[PREF_LABEL_KEY]}
        retVal = allMatches[0...maxSize]
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # ---------------------------------------------------------------
    # PROTECTED METHODS
    # ---------------------------------------------------------------

    # @param [NilClass, String] term the term to search for or nil if no collection subsetting
    #   is to be done
    # @param [Hash] opts named parameters pertaining to the optional proxy server and 
    #   threaded requests, @see requestTermsByNameViaSubtree
    # @return [Array<Hash>] collection of terms
    # @todo default timeout appears in multiple places -- put supported options in class constant?
    # @note the idea implemented is that if a false positive response occurs, it will probably only occur on
    #   the first page (recall the definition of a false positive from #falsePositiveResp?)
    #   in the event of a cache update this reduces the number of requests to bioOntology to
    #   n - 1 + 2 where n is the number of pages (this is down from 2n with the approach
    #   where a false positive is checked on every page before updating the cache). Unfortunately,
    #   this also exposes this method to the risk that the entire set of paged responses
    #   may be invalid (if any of the i > 1 pages exhibit false positives or fail). An
    #   alternative, more conservative wrt integrity and more expensive wrt time, approach
    #   would be to first check every page in the set for false positives/errors and then
    #   only if there are NO errors update the cache
    def collectAndSearchForTerm(term, opts={})
      # perform initial setup
      collection = []
      tt1 = tt2 = tt3 = tt4 = tt5 = tt6 = nil
      tt1 = Time.now

      # handle optional named parameters
      # supportedOpts contains defaults for the options
      supportedOpts = {:threads => 6, :timeout => 300}
      opts = supportedOpts.merge(opts)

      query = {
        INCLUDE_LINKS_PARAM => false,
        API_KEY_PARAM => @apiKey,
        FORMAT_PARAM => "json",
        PAGE_SIZE_PARAM => PREF_PAGE_SIZE,
        PAGE_PARAM => FIRST_PAGE,
        INCLUDE_CONTEXT_PARAM => false,
        INCLUDE_PARAM => [PREF_LABEL_KEY, DEFINITION_KEY, SYNONYM_KEY]
      }

      item = 0
      index = 1
      tt2 = Time.now
      diff = tt2 - tt1
      @timeData[:"setup"] = diff

      # request the first page from each ontology, after which we can deduce exactly how many 
      # more requests need to be made 
      link2Resp = {} # store individual links terms matching query
      first2RemainPages = {} # associate first page with its next pages
      first2Headers = Hash.new { |hh, kk| hh[kk] = {} }
      firstPages = ::Parallel.map_with_index(@ontologies, :in_threads => opts[:threads]) { |obj|
        ii = obj[index]
        subtree = (@ontologies.respond_to?(:size) and @subtrees.respond_to?(:size) and @ontologies.size == @subtrees.size) ? @subtrees[ii] : nil
        subtree = nil if(subtree.nil? or subtree.empty?)
        ontology = @ontologies[ii]
        if(subtree)
          # @todo validate subtree
          path = "/ontologies/#{ontology}/classes/#{CGI.escape(subtree)}/descendants"
        else
          path = "/ontologies/#{ontology}/classes"
        end

        # use predefined host and query for the request
        url = buildUrl(HOST, path, query)

        headers = getCacheHeaders(url)
        first2Headers[url] = headers

        # get successful responses and relate responses to the original ontology
        parsedResp = requestWrapper(url, headers, opts) rescue nil
        respIsError = errorResp?(parsedResp)
        jj = 0
        while(respIsError and jj < PRIME_PAGE_SIZES.length)
          # failures appeared to be based on page sizes, mutate page size a bit
          url.gsub!(/#{PAGE_SIZE_PARAM}=(\d+)/, "#{PAGE_SIZE_PARAM}=#{PRIME_PAGE_SIZES[jj]}")
          parsedResp = requestWrapper(url, headers, opts) rescue nil
          respIsError = errorResp?(parsedResp)
          jj += 1
        end

        pageLinks = []
        if(!respIsError and parsedResp.respond_to?(:key?) and parsedResp.key?(COLLECTION_KEY))
          unless(term.nil?)
            # before subsetting collection, construct next page links to try because the
            # collection size may be an indicator of an unreported internal server error
            # from the remote host
            pageLinks = pagesForResp(parsedResp)
            first2RemainPages[url] = pageLinks

            # save memory by subsetting collection to just the terms that match the query
            parsedResp[COLLECTION_KEY] = searchCollectionForTerm(parsedResp[COLLECTION_KEY], term, opts)
          end
        end

        if(pageLinks.nil? or respIsError)
          if(respIsError)
            $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "unable to get first page results for the #{ontology.inspect} ontology with subtree #{subtree.inspect}; final url: #{url.inspect}")
          end
          # then the first page response was probably bogus and /descendants may be unavailable
          @errors[url] = "Discarding response because some paging information was incorrect: pageLinks.nil?=#{pageLinks.nil?}; parsedResp.nil?=#{parsedResp.nil?}."
        else
          link2Resp[url] = parsedResp
        end
      }
      tt3 = Time.now
      diff = tt3 - tt2
      @timeData[:"first page requests"] = diff

      # collect links based on the first page, associate them with the ontology
      # subtree roots have to be done separate because they are not the same type of object
      unless(@subtrees.nil? or @subtrees.empty?)
        @subtrees.each_index{|ii|
          subtree = @subtrees[ii]
          ontology = @ontologies[ii]
          unless(subtree.nil? or subtree.empty?)
            # get subtree root itself (not needed for full ontology request)
            path = "/ontologies/#{ontology}/classes/#{CGI.escape(subtree)}"
            url = buildUrl(HOST, path, query)
    
            # request on a single item is not wrapped with page information
            headers = getCacheHeaders(url)
            parsedResp = requestWrapper(url, headers, opts) rescue nil
            if(!parsedResp.nil?)
              if(term.nil?)
                collection.push(parsedResp)
              else
                matches = searchCollectionForTerm([parsedResp], term, opts)
                collection += matches
              end
            else
              # failures appeared to be based on the presence of the INCLUDE_PARAM
              # @todo does this still happen? are all these url mutations just a cache failure on their end?
              newQuery = Marshal.load(Marshal.dump(query))
              newQuery.delete(INCLUDE_PARAM)
              newUrl = buildUrl(HOST, path, newQuery)
              parsedResp = requestWrapper(newUrl, headers, opts) rescue nil
              if(!parsedResp.nil?)
                if(term.nil?)
                  collection.push(parsedResp)
                else
                  matches = searchCollectionForTerm([parsedResp], term, opts)
                  collection += matches
                end
              else
                $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "failed to resolve subtree root retrieval error by removing #{INCLUDE_PARAM}; final url: #{newUrl.inspect}")
              end
            end
          end
        }
      end

      # link pages back to ontologies
      tt4 = Time.now
      diff = tt4 - tt3
      @timeData[:"mapping page links"] = diff

      # map 2nd, 3rd, ... pages to same headers used by 1st page
      pageUrl2Headers = {}
      first2RemainPages.each_key { |firstPageUrl|
        remainPageUrls = first2RemainPages[firstPageUrl]
        remainPageUrls.each { |remainPageUrl|
          pageUrl2Headers[remainPageUrl] = first2Headers[firstPageUrl]
        }
      }

      # @todo eliminate possible duplicate requests from same ontology and subtree?
      pageLinks = first2RemainPages.values.flatten
      ::Parallel.map(pageLinks, :in_threads => opts[:threads]){ |pageLink|
        headers = pageUrl2Headers[pageLink]
        headers = {} if headers.nil?
        parsedResp = requestWrapper(pageLink, headers, opts) rescue nil
        respIsError = errorResp?(parsedResp)
        if(respIsError)
          # while for the first page we are able to simply change the page size,
          # here we already have a lot of data and we dont want to start over so instead
          # we do some arithmetic (relying on the fact that the index of a particular term in 
          # the collection is fixed across multiple requests)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Splitting pageLink=#{pageLink.inspect} because it gave an error response") if(@debug)
          parsedResp = splitUrl(pageLink)
        end
        if(parsedResp.nil?)
          # @todo move this to a while loop with a set number of reattempts (splits)?
          $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "Unable to retrieve terms from #{pageLink.inspect} even after split reattempt")
          parsedResp = {COLLECTION_KEY => []}
        end
        unless(term.nil?)
          parsedResp[COLLECTION_KEY] = searchCollectionForTerm(parsedResp[COLLECTION_KEY], term, opts)
        end
        link2Resp[pageLink] = parsedResp
      }
      tt5 = Time.now
      diff = tt5 - tt4
      @timeData[:"parallel requests"] = diff

      link2Resp.each_key{|link|
        parsedResp = link2Resp[link]
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "link: #{link.inspect}\n\nparsedResp:\n#{JSON.pretty_generate(parsedResp)}\n\ncollection:\n#{JSON.pretty_generate(collection)}")
        collection += parsedResp[COLLECTION_KEY] if(!parsedResp.empty?)
        
      }

      tt6 = Time.now
      diff = tt6 - tt5
      @timeData[:"collect results"] = diff

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "errors from #{HOST}:\n\n#{JSON.pretty_generate(@errors)}") if(@debug and !@errors.empty?)
      return collection
    end

    # Collect all the ontology terms into memory
    # WARNING: some ontologies may consume 1-7GB of main memory themselves, be sure to use a
    #   subtree for large ontologies
    # @see collectAndSearchForTerm
    def collectOntologyTerms(opts={})
      term = nil
      return collectAndSearchForTerm(term, opts={})
    end

    # @param [Array<Hash>] collection a list of terms from bioOntology
    # @param [String] term the term to search for
    # @param [Hash<Symbol, Object>] opts named parameters
    #   @param [Symbol] :mode one of the following search modes
    #     :prefix use prefix based matching
    #     :exact search for the exact term (among prefix or synonym
    #     :token (default) 
    #   @param [Boolean] :termViaSynonym use synonyms in addition to prefLabel for matching
    # @return [Array<Hash>] subset of
    def searchCollectionForTerm(collection, term, opts={})
      # @todo this portion could be made significantly faster but 110,000 terms is only taking about 1.0-1.5 seconds
      supportedOpts = {:mode => :token, :termViaSynonym => true}
      opts = supportedOpts.merge(opts)

      matches = []
      if(opts[:mode] == :prefix)
        # then perform prefix search
        pattern = /^#{term}/i
        collection.each{|item|
          if(item['prefLabel'] =~ pattern)
            matches.push(item)
          else
            if(opts[:termViaSynonym])
              synonyms = item['synonym']
              if(!synonyms.nil? and synonyms.respond_to?(:each))
                synonyms.each{|synonym|
                  if(synonym =~ pattern)
                    matches.push(item)
                    break
                  end
                }
              end
            end
          end
        }
      elsif(opts[:mode] == :exact)
        collection.each{|item|
          label = item['prefLabel']
          if(label and label.downcase == term.downcase)
            matches.push(item)
          else
            if(opts[:termViaSynonym])
              synonyms = item['synonym']
              if(!synonyms.nil? and synonyms.respond_to?(:each))
                synonyms.each{|synonym|
                  if(synonym.respond_to?(:downcase) and (synonym.downcase == term.downcase))
                    matches.push(item)
                    break
                  end
                }
              end
            end
          end
        }
      else
        # then perform token search
        termTokens = term.split(/\s+/)
        termRegexpString = termTokens.join("|")
        pattern = /#{termRegexpString}/i
        collection.each{|item|
          tokenMatch = false
          label = item['prefLabel']
          if(label)
            tokens = label.split(/\s+/)
            tokens.each{|token|
              if(token =~ pattern)
                matches.push(item)
                tokenMatch = true
                break
              end
            }
          end
          unless(tokenMatch)
            if(opts[:termViaSynonym])
              synonyms = item['synonym']
              if(!synonyms.nil? and synonyms.respond_to?(:each))
                synonyms.each{|synonym|
                  if(synonym.respond_to?(:split))
                    tokens = synonym.split(/\s+/)
                    tokens.each{|token|
                      if(token =~ pattern)
                        matches.push(item)
                        break
                      end
                    }
                  end
                }
              end
            end
          end
        }
      end
      return matches
    end

    # Provide a wrapper around Net::HTTP to parse response body as JSON and raise
    #   errors if any are communicated according to the HOST's error response convention
    # @param [String] url the url to request, probably composed by buildUrl
    # @param [Hash] headers the http request headers to use
    # @param [Hash] opts optional named parameters; supported options:
    #   @param [Fixnum] :timeout the number of seconds to wait for one block to be read
    #   (Net::HTTP read_timeout parameter)
    # @return [NilClass, Hash] parsed response body from url or nil if an error occurred
    # @set @errors[url] with a message if an HTTP-related error occurs and if an unreported
    #   error occurs at HOST
    # @todo timeout 504 returns XML and crashes at the JSON parse line
    def requestWrapper(url, headers={}, opts={})
      $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "making request at url=#{url.inspect}") if(@debug)
      requestTimeDatum = {}
      parsedResp = nil
      tt1 = tt2 = tt3 = tt4 = nil

      # handle optional named parameters
      # supportedOpts contains defaults for the options
      supportedOpts = {:timeout => 300, :depth => 0}
      opts = supportedOpts.merge(opts)

      begin
        # establish connection at url, get contents
        tt1 = Time.now
        uriObj = URI.parse(url)
        http = ::Net::HTTP.new(uriObj.host, uriObj.port)
        http.read_timeout = opts[:timeout]
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "request headers:\n#{JSON.pretty_generate(headers)}") if(@debug)
        resp = http.get("#{uriObj.path}?#{uriObj.query}", headers)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "response headers:\n#{JSON.pretty_generate(resp.to_hash)}") if(@debug)
        tt2 = Time.now
        requestTimeDatum[:"establish connection"] = tt2 - tt1
        #$stderr.debugPuts(__FILE__, __method__, "ERROR", "resp:\n\n#{resp.body.inspect}") if(headers.empty?)
        # read and parse contents
        content = resp.body
        tt3 = Time.now
        requestTimeDatum[:"read response"] = tt3 - tt2

        begin
          parsedResp = JSON.parse(content)
        rescue ::JSON::ParserError => err
          parsedResp = nil
          @errors[url] = "Could not parse response as JSON; response code and message: #{resp.code} #{resp.msg}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not parse response for #{url} ; head of body: #{resp.body[0...BODY_SIZE]}")
        end

        tt4 = Time.now
        requestTimeDatum[:"parse response"] = tt4 - tt3

      rescue SocketError, ::Timeout::Error, ::Net::HTTPBadResponse, ::Net::HTTPExceptions => err
        # handle connection request read time exceeding timeout setting
        # handle protocol errors
        # handle all other net/http errors? hopefully?
        parsedResp = nil
        @errors[url] = err.message
      end

      # handle any explicit errors that may have occurred
      if(parsedResp.respond_to?(:key?) and parsedResp.key?(ERRORS_KEY))
        # multiple errors envelope
        errors = parsedResp[ERRORS_KEY]
        msg = "Server at #{HOST} reports the following errors:\n#{errors.join("\n")}"
        @errors[url] = msg
        parsedResp = nil
      elsif(parsedResp.respond_to?(:key?) and parsedResp.key?(ERROR_KEY))
        # single error envelope
        error = parsedResp[ERROR_KEY]
        msg = "Server at #{HOST} reports the following error:\n#{error}"
        @errors[url] = msg
        parsedResp = nil
      end

      # try to detect implict errors
      online = true
      if(!parsedResp.nil? and falsePositiveResp?(parsedResp))
        # then interrogate HOST server further to see if this term is not in the ontologies 
        # or if the ontologies are simply offline
        @errors[url] = msg
        online = ontologiesOnline?()
        unless(online)
          msg = "The #{@ontologies.join(", ").inspect} ontologies are temporarily unavailable"
          @errors[url] += " ; #{msg}"
          parsedResp = nil
        end
      end

      # purge cache if some error occured, try again exactly once
      if(@errors[url] and @proxyHost and @proxyPort and online)
        unless(headers.key?(PROXY_BYPASS_CACHE))
          purged = purgeCache(url)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Purged from cache #{url} with error message: #{@errors.delete(url)}") if(purged)
        end
        depth = opts[:depth].respond_to?(:to_i) ? opts[:depth].to_i : 0
        depth += 1
        opts[:depth] = depth
        unless(opts[:depth] > 1)
          parsedResp = requestWrapper(url, headers, opts)
        end
      end

      requestTimeDatum[:"error checking"] = Time.now - tt4
      requestTimeDatum[:full] = Time.now - tt1
      @requestTimeData << requestTimeDatum if(@debug)
      return parsedResp
    end

    # Construct URLs for /search endpoint's requirement that only one ontology/subtree pair can
    #   be provided if a subtree is provided at all
    # @param [Hash] query @see e.g. requestExactTerm, just key,value pairs for query string of /search endpoint
    # @param [Array<String>] ontologies @see @ontologies
    # @param [Array<String, NilClass>] subtrees @see @subtrees
    def buildSubtreeUrls(query, ontologies=@ontologies, subtrees=@subtrees)
      urls = []
      ontologies.each_index { |ii|
        ontology = ontologies[ii]
        subtree = subtrees[ii] rescue nil
        query = mergeSubtreeAndOntology(query, subtree, [ontology])
        url = buildUrl(HOST, PATH, query)
        urls << url
      }
      return urls
    end

    # @param [Array<String>] urls the urls to make searches at
    # @param [Hash] opts optional named parameters
    # @note this proceedure is separate than that of the "ViaSubtree" method because that one requires memory
    #   savings during the processing by searching the results as we go; here the search has been done
    #   by a remote server
    def parallelSearches(urls, opts={})
      defaultOpts = {
        :threads => 6,
        :maxSize => MAX_PAGE_SIZE*MAX_PAGES,
        :timeout => 300,
        :depth => 0,
        :detailed => false
      }
      opts = defaultOpts.merge(opts)

      collections = ::Parallel.map(urls, :in_threads => opts[:threads]) { |url|
        begin
          headers = getCacheHeaders(url)
          opts[:headers] = headers
          parsedResp = requestWrapper(url, headers, opts)
          if(parsedResp.nil?)
            collection = nil
          else
            collection = depageResp(parsedResp, opts[:maxSize], opts)
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "err.message=#{err.message} ; backtrace=\n#{err.backtrace.join("\n")}")
          collection = nil
        end
      }
      retVal = []
      if(opts[:detailed])
        retVal = collections
      else
        collections.each { |collection|
          retVal += collection unless(collection.nil?)
        }
        retVal = retVal[0...opts[:maxSize]]
      end
      retVal = nil if(retVal.empty?)
      return retVal
    end

    # A URL at the HOST specifies a collection of terms by the PAGE and PAGE_SIZE parameters;
    #   collect the same set of terms with a different PAGE_SIZE value, useful in handling
    #   errors that have been observed related to PAGE_SIZE
    # @param [String] url the url to split 
    # @param [Hash] opts optional named parameters
    # @return [Hash<String, Hash>] mapping of split URLs to their responses
    # @note responses from this method are not cached (it is intended as a temporary fallback)
    def splitUrl(url, opts={})
      retVal = nil
      uriObj = URI.parse(url)
      query = CGI.parse(uriObj.query)
      unless(query[PAGE_PARAM] and query[PAGE_SIZE_PARAM])
        raise ArgumentError, "Cannot split url #{url} because it does not contain query string parameters #{PAGE_PARAM} and #{PAGE_SIZE_PARAM}"
      end

      # @todo worst case running :threads ^ 2
      supportedOpts = {:threads => 6, :timeout => 300}
      opts = supportedOpts.merge(opts)

      page = query[PAGE_PARAM].first.to_i
      pageSize = query[PAGE_SIZE_PARAM].first.to_i

      splitPageSize = nil
      PRIME_PAGE_SIZES.each{|size|
        # get the next smallest page size from the list available to us
        if(pageSize > size)
          splitPageSize = size
          break
        end
      }
      if(splitPageSize.nil?)
        raise ArgumentError, "Cannot split URL in to page sizes smaller than #{PRIME_PAGE_SIZES.last}; given page size = #{pageSize.inspect}"
      end

      # assume we have taken a page size slightly smaller than the given page size,
      # then we need to get the next 2 pages since our page will start prior to the given one,
      # and end earlier
      query[PAGE_SIZE_PARAM] = splitPageSize
      splitUrls = []
      (page..page+1).each{|pc|
        query[PAGE_PARAM] = pc
        splitUrls.push(buildUrl(uriObj.host, uriObj.path, query))
      }

      noneNil = true
      link2Resp = {}
      ::Parallel.map(splitUrls, :in_threads => opts[:threads]){ |pageLink|
        headers = getCacheHeaders(pageLink)
        parsedResp = requestWrapper(pageLink, headers, opts) rescue nil
        if(!parsedResp.nil?)
          link2Resp[pageLink] = parsedResp
        else
          noneNil = false
        end
      }

      if(noneNil)
        # return a mocked parsedResp with the input URLs terms
        origRange = ((page - 1) * pageSize + 1 .. page * pageSize)
        splitRange = ((page - 1) * splitPageSize + 1 .. (page+1) * pageSize)
        offset = origRange.first - splitRange.first # +1 for 1-based counting, -1 for conversion to 0-based arrays
        length = origRange.size
        collection = []
        splitUrls.each { |link|
          parsedResp = link2Resp[link]
          collection += parsedResp[COLLECTION_KEY] unless(parsedResp.nil?)
        }
  
        # @todo modify other fields in the mock parsedResp?
        # need to mock prevPage, pageCount, nextPage, page, links
        parsedResp = link2Resp[splitUrls.first]
        parsedResp[COLLECTION_KEY] = collection[offset ... offset + length]
        retVal = parsedResp
      else
        retVal = nil
      end

      return retVal
    end

    # @param [Hash<String, Object>] parsedResp the parsed response body from a successful query to the HOST
    # @return [Array<String>, NilClass] a list of urls whose responses, together with parsedResp, represent the complete,
    #   collated response from HOST for a given query or nil if pageCount is 0 or nextPage link is provided even when the collection is empty (signs of uncaught internal server error at HOST)
    def pagesForResp(parsedResp)
      pageLinks = []
      pages = parsedResp[PAGE_COUNT_KEY]

      # base our page links off the provided next page link
      nextPage = parsedResp[NEXT_PAGE_KEY]
      nextPageLink = (parsedResp[LINKS_KEY].nil? ? nil : parsedResp[LINKS_KEY][LINKS_NEXT_PAGE_KEY])
      if(falsePositiveResp?(parsedResp))
        # uncaught internal server error at HOST
        pageLinks = nil
      elsif(nextPageLink.nil?)
        # all collection terms fit in a single page
        pageLinks = []
      else
        # all collection terms do NOT fit in a single page, enumerate pages
        uriObj = URI.parse(nextPageLink)
        query = CGI.parse(uriObj.query)
        (nextPage..pages).each{|pageNum|
          query[PAGE_KEY] = [pageNum] # [] to maintain query format from CGI.parse
          pageLink = buildUrl(uriObj.host, uriObj.path, query)
          pageLinks.push(pageLink)
        }
      end

      return pageLinks
    end

    # ---------------------------------------------------------------
    # DEPRECATED; use requestTermsByNameViaSubtree()! methods here are 
    # used only by non-subtree-based methods which are usually slower 
    # (than cached, descendants counterpart) and less reliable
    # ---------------------------------------------------------------

    # @todo use /ontology/{ontology}/classes instead of /search
    # Check if ontologies are still available for making requests
    # The API at HOST responds with HTTP 200 OK and the following response body instead of HTTP 500,
    # but also uses this same response if the q={TERM} is not in the ontology
    # {
    #     "page": 1,
    #     "pageCount": 0,
    #     "prevPage": null,
    #     "nextPage": null,
    #     "links": {
    #         "nextPage": "{someUrl}"
    #         "prevPage": null
    #     },
    #     "collection": [ ]
    # }
    # @return [Boolean] true if the at least 1 of @ontologies responds to simple prefix-based searches
    # @todo store result of test? when to update?
    # @todo update to not use /search ? resolve /classes based with changing page size, other strategies?
    # @todo still some false positives if a /descendants fails and a /search succeeds (need to check all
    #   ontology, subtree pairs)
    def ontologiesOnline?()
      retVal = false
      begin
        # check tree-based methods like /descendants
        ontToRoots = getOntologyRoots
        noneNil = ontToRoots.inject(true) { |bool, avp| bool && (!avp[1].nil? and !avp[1].empty?) }
        if(noneNil)
          retVal = true
        else
          # check search endpoint
          initLetters = ["s", "p", "c"] # "d", "m", "a" (6 most common for English dictionary)
          ontologyToSuccess = {}
          @ontologies.each { |ontology| ontologyToSuccess[ontology] = false }
          initLetters.each { |ltr|
            query = {
              QUERY_PARAM => "#{ltr}*",
              API_KEY_PARAM => @apiKey,
              INCLUDE_LINKS_PARAM => false,
              INCLUDE_CONTEXT_PARAM => false,
              INCLUDE_PARAM => [PREF_LABEL_KEY, DEFINITION_KEY, SYNONYM_KEY],
              EXACT_MATCH_PARAM => false,
              PAGE_SIZE_PARAM => 1,
              FORMAT_PARAM => "json"
            }
            if(@subtrees.nil? or @subtrees.empty?)
              subtree = @subtrees.first rescue nil
              query = mergeSubtreeAndOntology(query, subtree, @ontologies)
              url = buildUrl(HOST, PATH, query, false)
              parsedResp = requestWrapper(url)
              if(parsedResp.respond_to?(:[]) and parsedResp[PAGE_COUNT_KEY] != 0 and
                 !parsedResp[COLLECTION_KEY].empty?)
                retVal = true
                break
              end
            else
              urls = buildSubtreeUrls(query) # @parallel to @ontologies
              opts = {:detailed => true}
              collections = parallelSearches(urls, opts)
              @ontologies.each_index { |ii|
                ontology = @ontologies[ii]
                ontologyToSuccess[ontology] = true if(!collections[ii].nil? and !collections[ii].empty?)
              }
              allSuccess = !ontologyToSuccess.values.index(false)
              if(allSuccess)
                retVal = true
                break
              end
            end
          }
        end
      rescue => err
        retVal = false
        logError(err)
      end
      return retVal
    end

   
    # Request an exact match for a term
    # @param [String] term the term to match
    # @return [NilClass, Array<Hash>] a collection of term objects from HOST or nil if error occurs
    # @todo needs to use requestTermsByNameViaSubtree aka descendants based search
    def requestExactTerm(term, maxSize=nil, opts={})
      maxSize = (maxSize.nil? ? MAX_PAGE_SIZE*MAX_PAGES : maxSize)
      retVal = nil
      begin
        query = {
          QUERY_PARAM => term,
          API_KEY_PARAM => @apiKey,
          EXACT_MATCH_PARAM => true,
          INCLUDE_LINKS_PARAM => false,
          INCLUDE_CONTEXT_PARAM => false,
          INCLUDE_PARAM => [PREF_LABEL_KEY, DEFINITION_KEY, SYNONYM_KEY],
          FORMAT_PARAM => "json"
        }
        if(@subtrees.nil? or @subtrees.empty?)
          # then we can make a single request
          url = buildUrl(HOST, PATH, query)
          headers = getCacheHeaders(url)
          parsedResp = requestWrapper(url, headers)
          unless(parsedResp.nil?)
            collection = depageResp(parsedResp, maxSize, {:headers => headers})
            retVal = collection[0...maxSize]
          end
        else
          # then we must make individual requests for each subtree
          urls = buildSubtreeUrls(query)
          retVal = parallelSearches(urls)
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # An alternative search method that uses the HOST's /search endpoint -- this is less reliable
    # @see requestTermsByNameViaSubtree
    def requestTermsByName(term, prefix=false, maxSize=nil, opts={})
      retVal = nil
      @errors = {}
      term = term.dup()
      maxSize = (maxSize.nil? ? MAX_PAGE_SIZE*MAX_PAGES : maxSize)
      pageSize = (maxSize < MAX_PAGE_SIZE ? maxSize : MAX_PAGE_SIZE)

      # handle optional named parameters
      # supportedOpts contains defaults for the options
      supportedOpts = {:termViaSynonym => true}
      opts = supportedOpts.merge(opts)
     
      begin
        termNoPattern = nil
        if(prefix)
          if(term[-1] != "*")
            termNoPattern = term.dup()
            term << "*"
          else
            termNoPattern = term.chop
          end
        else
          if(term[-1] == "*")
            term.chop!
          end
          termNoPattern = term
        end

        # check for exact match first
        exactCollection = requestExactTerm(termNoPattern, maxSize)
        if(exactCollection.nil?)
          # an error occurred and it has already been logged
          retVal = nil
        else
          exactCollection.sort!{|aTerm, bTerm| aTerm[PREF_LABEL_KEY] <=> bTerm[PREF_LABEL_KEY]}
          if(exactCollection.length < maxSize)
            # then get more terms from inexact match, prepare url
            query = {
              QUERY_PARAM => term,
              API_KEY_PARAM => @apiKey,
              PAGE_PARAM => FIRST_PAGE,
              PAGE_SIZE_PARAM => pageSize,
              INCLUDE_LINKS_PARAM => false,
              INCLUDE_CONTEXT_PARAM => false,
              INCLUDE_PARAM => [PREF_LABEL_KEY, DEFINITION_KEY, SYNONYM_KEY],
              EXACT_MATCH_PARAM => false,
              FORMAT_PARAM => "json",
              SUGGEST_PARAM => true
            }
            if(@subtrees.nil? or @subtrees.empty?)
              # then we can save time by just making one request
              url = buildUrl(HOST, PATH, query)
  
              # make and parse request with depaging
              headers = getCacheHeaders(url)
              parsedResp = requestWrapper(url, headers)
              retVal = depageResp(parsedResp, maxSize, {:headers => headers})
            else
              # otherwise we just make individual request for each ontology/subtree pair
              urls = buildSubtreeUrls(query)
              opts.merge!({:maxSize => maxSize})
              retVal = parallelSearches(urls, opts)
            end

            # put exact matches first, subset response to match requested size, and sort the response
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matches=#{retVal.length}; exact matches=#{exactCollection.length}") if(@debug)
            retVal.sort!{|aTerm, bTerm| aTerm[PREF_LABEL_KEY] <=> bTerm[PREF_LABEL_KEY]}
            # NOTE! Array#delete_if does not behave like Array#delete; return value of former is array after deletions, latter is the value deleted
            retVal = retVal.delete_if{|aTerm| exactCollection.index{|bTerm| bTerm[PREF_LABEL_KEY].downcase == aTerm[PREF_LABEL_KEY].downcase}}
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matches without exact=#{retVal.length}") if(@debug)
            retVal = exactCollection + retVal
          else
            retVal = exactCollection
          end
          unless(opts[:termViaSynonym])
            # subset result set to exclude terms that only matched because of their synonyms
            retVal = retVal.delete_if{|term| !(term[PREF_LABEL_KEY].downcase().index(termNoPattern.downcase()))}
            # @todo maybe the first {maxSize} terms resulted from synonym match but subsequent terms match just based on the label (synonym matches APPEAR to be put at the end, however)
          end
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matches without synonym=#{retVal.length}") if(@debug)
          retVal = retVal[0...maxSize] unless(maxSize.nil?)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matches after maxSize subset=#{retVal.length}") if(@debug)
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Transform query hash to include subtree parameter if necessary
    # @param [Hash] queryHash current query hash to use to build url
    # @param [String] subtree current value of internal subtree parameter (url or empty string)
    # @param [Array<String>] ontologies current internal ontologies
    # @return [Hash] queryHash with correct SUBTREE_PARAM and ONTOLOGY or ONTOLOGIES param merged in
    def mergeSubtreeAndOntology(queryHash, subtree, ontologies=@ontologies)
      queryHash = Marshal.load(Marshal.dump(queryHash))
      if(subtree.nil? or subtree.empty?)
        queryHash[ONTOLOGIES_PARAM] = ontologies
      else
        queryHash[ONTOLOGY_PARAM] = ontologies.first
        queryHash[SUBTREE_PARAM] = subtree
        $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "WARNING: You may only use subtree root for a single ontology, "\
                                                               "but you provided many; using #{ontologies.first}") if(ontologies.length > 1)
      end
      return queryHash
    end

    # @see requestTermsByNameAndSubtree
    # @return [Array<String>] labels (PREF_LABEL_KEY) extracted from term collection
    def requestLabelsByName(term, prefix=false, maxSize=nil, opts={})
      retVal = nil
      begin
        collection = requestTermsByName(term, prefix, maxSize, opts)
        labels = []
        if(!collection.nil? and collection.respond_to?(:each))
          collection.each{|item|
            labels.push(item[PREF_LABEL_KEY])
          }
        end
        retVal = labels
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Determine if a term exists in an ontology
    # @param [String] term the term to check the ontology for
    # @return [Boolean] true if term is in ontology, false otherwise
    # @todo needs to ultimately use requestTermsByNameViaSubtree
    def termInOntology?(term)
      @errors = {}
      retVal = false
      collection = requestExactTermsViaSubtree(term)
      if(!collection.nil? and collection.respond_to?(:each))
        collection.each{|item|
          label = item[PREF_LABEL_KEY]
          if(label and (label.downcase() == term.downcase()))
            retVal = true
            @prefLabelForTerm = label
            break
          end
        }
      end
      return retVal
    end
    alias :termInOntolgies? :termInOntology?

    # Compile COLLECTION_KEY objects from parsedResp -- responses from HOST are paginated;
    #   top level JSON data defined pagination of results including PAGE_KEY, PAGE_COUNT
    #   and links (LINKS_KEY) to the next and previous pages
    # @param [Hash] parsedResp result from requestWrapper
    # @param [NilClass, Fixnum] maxSize maximum size of array of COLLECTION_KEY objects
    # @return [Array<Hash>] concatenated collection arrays from each page, filled with objects
    #   describing ontology terms
    # @todo ignore errors that occur on one page but not others?
    # @raise ArgumentError or RuntimeError if unable to use COLLLECTION_KEY from parsedResp
    def depageResp(parsedResp, maxSize=nil, opts={})
      supportedOpts = { :headers => {} }
      opts = supportedOpts.merge(opts)
      maxSize = (maxSize.nil? ? MAX_PAGE_SIZE*MAX_PAGES : maxSize)
      retVal = []
      raise ArgumentError, "Key #{COLLECTION_KEY.inspect} not parsable as Array" unless(parsedResp.respond_to?(:[]) and parsedResp[COLLECTION_KEY].is_a?(Array))
      retVal += parsedResp[COLLECTION_KEY]
      page = FIRST_PAGE
      nextPage = parsedResp[NEXT_PAGE_KEY]
      nextPageLink = (parsedResp[LINKS_KEY].nil? ? nil : parsedResp[LINKS_KEY][LINKS_NEXT_PAGE_KEY])
      while(!nextPage.nil? and !nextPageLink.nil? and retVal.length < maxSize and page <= MAX_PAGES)
        uriObj = URI.parse(nextPageLink)
        url = buildUrl(uriObj.host, uriObj.path, CGI.parse(uriObj.query))
        parsedResp = requestWrapper(url, opts[:headers])
        raise "Key #{COLLECTION_KEY} not parsable as Array" unless(parsedResp[COLLECTION_KEY].is_a?(Array))
        retVal += parsedResp[COLLECTION_KEY]
        page += 1
        nextPage = parsedResp[NEXT_PAGE_KEY]
        nextPageLink = (parsedResp[LINKS_KEY].nil? ? nil : parsedResp[LINKS_KEY][LINKS_NEXT_PAGE_KEY])
      end
      $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "refusing to make more than #{MAX_PAGES} requests to #{HOST}") if(page > MAX_PAGES)
      $stderr.debugPuts(__FILE__, __method__, "BIOONTOLOGY", "maxSize=#{maxSize} limit reached") if(retVal.length >= maxSize)
      return retVal
    end

    # @todo cache headers?
    # @return [Hash] mapping of ontology name to roots
    def getOntologyRoots
      # /ontologies/:ontology/classes/roots
      retVal = {}
      query = {
        API_KEY_PARAM => @apiKey,
        FORMAT_PARAM => "json",
        PAGE_SIZE_PARAM => PREF_PAGE_SIZE,
        PAGE_PARAM => FIRST_PAGE,
        INCLUDE_CONTEXT_PARAM => false,
        INCLUDE_PARAM => [PREF_LABEL_KEY, DEFINITION_KEY, SYNONYM_KEY]
      }
      @ontologies.each { |ontology|
        begin
          path = "/ontologies/#{CGI.escape(ontology)}/classes/roots"
          url = buildUrl(HOST, path, query)
          resp = requestWrapper(url)
          retVal[ontology] = resp
        rescue => err
          retVal[ontology] = nil
          logError(err)
        end
      }
      return retVal
    end

    # Get the cache headers that should be used for the URL based on whether the cache
    #   entry for the URL is out of date and (only then) if a request made to bioOntology
    #   now would result in a false positive
    # @param [String] url the url to check headers for
    # @return [Hash] headers to use for subsequent request (to update/not update cache)
    def getCacheHeaders(url)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "getting cache headers") 
      retVal = {}
      # check if we should update cache (or if we are using a proxy cache at all)
      updateStatus = updateCache?(url)
      falsePosStatus = false
      if(updateStatus)
        # then we take care to not discard our existing cache contents if we see a false 
        # positive 200 OK
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating status") 
        headers = {}
        headers[PROXY_BYPASS_CACHE] = true.to_s
        headers[PROXY_DONT_CACHE] = true.to_s
        parsedResp = requestWrapper(url, headers)
        unless(parsedResp.nil?)
          falsePosStatus = falsePositiveResp?(parsedResp)
        else
          begin
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Problems encountered while querying bioportal. See if we can find something in our own cache")
            headers = {}
            parsedResp = requestWrapper(url, headers)
            unless(parsedResp.nil?)
              # Looks like we got something from our cache. Don't update cache
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Cache query returned successfull!")
              updateStatus = false
            end
          rescue => err
            # Something went wrong pulling info from our cache. Keep the cache for safe keeping
            updateStatus = false
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error encountered while querying our own cache: #{err}")
          end
        end
      end
      parsedResp = nil
      # adjust headers based on cache update necessity and false positive detection
      if(updateStatus and falsePosStatus)
        # then we want to update but we cannot because HOST has failed us, resort to stale cache
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Refusing to update cache because request to #{HOST.inspect} has shown false positives") 
      elsif(updateStatus and !falsePosStatus)
        # then we want to update and we are ok to do so
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Updating cache because existing cache entry has expired and test request to #{HOST.inspect} has not shown false positives")
        retVal[PROXY_BYPASS_CACHE] = true.to_s
      end

      return retVal
    end

    # Check if cache entry is too old
    # @param [String] url 
    # @note while most cache information is in parent, this logic is specific to bioportal
    #   where we are at risk of a "false positive" 200 OK
    # @todo should this function transform urls hosted at bioportal to those at @proxyHost?
    def updateCache?(url, opts={})
      retVal = false
      supportedOpts = {:timeout => 300}
      opts = supportedOpts.merge(opts)

      proxy = true 
      if(@proxyHost.nil? or @proxyPort.nil? or @proxyPathRoot.nil?)
        proxy = false
      end

      if(proxy)
        # perform head request
        uriObj = URI.parse(url)
        http = ::Net::HTTP.new(uriObj.host, uriObj.port)
        http.read_timeout = opts[:timeout]
        resp = http.head("#{uriObj.path}?#{uriObj.query}")
        respHeaders = resp.to_hash

        # check cache hit and that cache has expired
        cacheStatus = respHeaders[PROXY_CACHE_STATUS].respond_to?(:first) ? respHeaders[PROXY_CACHE_STATUS].first : nil
        cacheTimeStr = respHeaders[DATE_RESP_HEADER].respond_to?(:first) ? respHeaders[DATE_RESP_HEADER].first : nil
        cacheTimeObj = Time.parse(cacheTimeStr) rescue nil
        if(cacheStatus == PROXY_CACHE_HIT and Time.now - cacheTimeObj > PROXY_CACHE_LIFE)
          retVal = true
        end
      end
      return retVal
    end

    # Check if result from requestWrapper is an explicit error or a false positive success
    # @param [NilClass, Hash] parsedResp
    # @return [Boolean] true if the response was an error
    def errorResp?(parsedResp)
      retVal = false
      if(parsedResp.nil?)
        retVal = true
      elsif(parsedResp.is_a?(Hash))
        # paginated responses
        retVal = falsePositiveResp?(parsedResp)
      elsif(parsedResp.is_a?(Array))
        # @todo non-paginated responses -- check false positive, empty? need to observe such a case
      else
        retVal = true
      end
      return retVal
    end

    # Check if parsed response is 200 OK but shows (previously observed) signs of an unreported 
    #   500 Internal Server Error; those signs right now are just that there is a "next page"
    #   even though the current page has no terms
    # @param [Hash, Array] parsedResp the parsed response from a request to HOST
    # @return [Boolean] if true, the server should have reported a 500 but instead gave a 200
    def falsePositiveResp?(parsedResp)
      retVal = false
      if(parsedResp.is_a?(Hash))
        pages = parsedResp[PAGE_COUNT_KEY]
        nextPage = parsedResp[NEXT_PAGE_KEY]
        nextPageLink = (parsedResp[LINKS_KEY].nil? ? nil : parsedResp[LINKS_KEY][LINKS_NEXT_PAGE_KEY])
        # false positive detection for paginated responses
        if(!nextPageLink.nil? and (parsedResp[COLLECTION_KEY].nil? or parsedResp[COLLECTION_KEY].empty?))
          # uncaught internal server error at HOST
          retVal = true
        end
      else
        # currently no false positives for non paginated responses -- maybe empty array?
      end
      return retVal
    end

    # Generate a report string that can be printed to $stderr to log time information
    # @return [String] report of timing information
    def reportTimeData()
      report = ''
      keys = @timeData.keys.sort()
      outerSum = 0.0
      keys.each{|kk| report << "#{kk}: #{@timeData[kk]}\n"; outerSum += @timeData[kk]}
      outerSum -= @timeData[:full]
      report << "unaccounted time: #{@timeData[:full] - outerSum}\n"
      report << "\nRequest detail for #{@requestTimeData.size} requests:\n"

      @requestTimeData.each{|timeHash|
        innerSum = 0.0
        keys = timeHash.keys().sort
        keys.each{|kk| report << "#{kk}: #{timeHash[kk]}\n"; innerSum += timeHash[kk]}
        innerSum -= timeHash[:full]
        report << "unaccounted time: #{timeHash[:full] - innerSum}\n\n"
      }
      return report
    end
  end

  class BioOntologyError < RuntimeError; end
end; end
