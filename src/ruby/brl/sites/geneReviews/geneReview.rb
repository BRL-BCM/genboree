require 'uri'
require 'open-uri'
require 'nokogiri'
require 'escape_utils'
require 'uri_template'
require 'crack'
require 'iconv'
require 'brl/util/callback'

module BRL ; module Sites ; module GeneReviews
  # A class when wraps a GeneReview record as a nested Hash (provided by Crack:XML).
  #   Created from one of the Factory methods ({#new} is private) and then generally call
  #   {#retrieve} to get the nested Hash.
  #   Supports {EventMachine}, and checks that you have properly registered callback and errback
  #   functions.
  class GeneReview
    UTF8_ASCII_HTML_SAFE = {
      />=/ => '&gt;=',
      /<=/ => '&lt;=',
      />>/ => '&gt;&gt;',
      /<</ => '&lt;&lt'
    }
    #URL_TEMPLATE = URITemplate.new('{proto}://www.ncbi.nlm.nih.gov/pubmed/?term=GeneReviews%5BBook%5D+and+%28+{grId}+or+{grId}%5Bpmid%5D+%29&report=xml')
    # Sameer: This URL seems to work. grId can be either pmid for that GeneReview or the geneReview id itself.
    URL_TEMPLATE = URITemplate.new('{proto}://www.ncbi.nlm.nih.gov/pubmed/?term=GeneReviews+and+%28+{grId}+or+{grId}%5Bpmid%5D+%29&report=xml')
    DEFAULT_OPTS = { :connect_timeout => 10, :inactivity_timeout => 60, :headers => {} }
    RESP_HEAD = 500

    attr_accessor :geneReviewId
    attr_accessor :opts
    attr_accessor :url
    attr_accessor :xml, :xmlHash
    attr_reader :callbackObj, :errbackObj
    attr_reader :errors, :warnings

    # FACTORY. Instantiate from raw GeneReview XML.
    #   EventMachine is optionally supported.
    # @param [String] xml The raw XML string.
    # @param [Hash] opts (Optional) Special options that influence behavior of this class
    #   are provided here. Key one is @:eventmachine@, a boolean which if set to @true@
    #   will cause this class to employ EM's async http request client and call your callback
    #   methods with the results. See {#retrieve}.
    # @return [BRL::Sites::GeneReviews::GeneReview] An instance of this class.
    def self.fromXml(xml, opts={})
      geneReview = new(opts)
      geneReview.xml = xml
      return geneReview
    end

    # FACTORY. Instantiate from GeneReview ID, which will be used to retrieve the document via HTTP.
    #   EventMachine is optionally supported.
    # @param [String] idStr The GeneReviews document id string.
    # @param [Hash] opts (Optional) Special options that influence behavior of this class
    #   are provided here. Key one is @:eventmachine@, a boolean which if set to @true@
    #   will cause this class to employ EM's async http request client and call your callback
    #   methods with the results. See {#callback, #errback, #retrieve}.
    # @return [BRL::Sites::GeneReviews::GeneReview] An instance of this class.
    def self.fromId(idStr, opts={})
      geneReview = new(opts)
      geneReview.geneReviewId = idStr
      return geneReview
    end

    # (Optional, but required for opts[:eventmachine]=true) Register your callback function
    #   which will be called upon successful retrieval and parsing of the GeneReview doc.
    # @note You can provide this function in one of 2 ways:
    #   1. Call this method with a code block (only) that take 2 Hash arguments.
    #        gr.callback { |xmlHash, infoHash| ...check and do stuff... }
    #   2. Call this method with 2 arguments: an object and a method-symbol of the method in
    #      in that object which will be called. That method must also take 2 Hash arguments.
    #        gr.callback(myHandler, :mySuccessMethod)
    # @note The code block or instance method will be called with 2 Hash arguments.
    #  1. @xmlHash@ - If nil, there was an error. Check @infoHash@. This is the parsed GeneReview
    #       document, as a nested Hash. When tags are
    #       repeated, they are present in an Array. Be careful, Crack:XML can't distinguish
    #       between a normal single tag and a tag list with just 1 entity (for which it won't
    #       use an Array because repeated tag). Also, for leaf tags that also have attributes,
    #       that String (text) value of the tag will have an @attributes@ accessor for getting
    #       at this info. This is not necessary for non-leaf tags; attributes are just Hash keys
    #       like sub-tags are. Look, probably you want to hand this useful data structure to some
    #       smart class that can do something with it, yes?
    # 2. @infoHash@ - Contains related info, especially useful when an error occurred (@xmlHash is nil
    #     in most cases). You should log the info in @:errors@, including a backtrace! See below.
    #     * @:url@ - The GeneReview url that was built, if any (nil when you provided raw xml)
    #     * @:xml@ - The raw XML extracted from the web page or provided by you.
    #     * @:warnings@ - Array of Hashes, nil if none. The @:msg@ keys will have String warning messages that didn't
    #       stop/skip the regular flow.
    #     * @:errors@ - Array of Hashes, nil if none. IMPORTANT. Errors halted/prevented normal processing. In SOME
    #       cases they may be due to Exceptions being raised, in others good checking noticed a problem first.
    #       These keys are useful:
    #         - @:msg@ - Text description of the problem.
    #         - @:status@ - Symbol summarizing kind of error: :BAD_ID, :ERROR_RAISED, :NO_DOC, :BAD_URL, :BAD_XML.
    #           Obviously, :BAD_ID should be expected when the id isn't valid at GeneReviews.
    #         - @:err@ - MOST IMPORTANT. If non-nil, then an Exception that was rescued. You should probably log
    #          its class, message, and stacktrace. Not all errors are due to Exceptions.
    def callback(*args, &blk)
      @callbackObj = BRL::Callback(*args, &blk)
    end

    # (Optional, but required for opts[:eventmachine]=true) Register your callback function
    #   which will be called upon failed retrieval and parsing of the GeneReview doc.
    # Same as {#callback} (@see #callback)
    def errback(*args, &blk)
      @errbackObj = BRL::Callback(*args, &blk)
    end

    # Having instantiated the class, and optionally registered callback/errback functions
    #   for EventMachine mode, call {#retrieve} to get and parse the doc. In normal mode,
    #   this will return the @xmlHash@ ; in EventMachine mode, your callback will be called
    #   with @xmlHash@ and @infoHash@ arguments and the return is useless..
    def retrieve()
      retVal = nil
      init()
      sanityChecks()

      if(@opts[:eventmachine])
        retVal = retrieveViaEM()
      else # direct/synchronously
        retVal = retrieveDirect()
      end

      return retVal
    end

    # ---------------------------------------------------------------
    # INTERNAL METHODS
    # ----------------------------------------------------------------

    # PRIVATE CONSTRUCTION new(). Use Factory constructors.
    class << self
      private :new
    end

    def initialize(opts={})
      @opts = DEFAULT_OPTS.merge(opts)
      @xml = @geneReviewId = @callbackObj = @errbackObj = nil
    end

    private

    def init()
      @url = @xmlHash = nil
      @warnings = []
      @errors = []
    end

    # Make sure we're set up sensibly.
    def sanityChecks()
      if(@opts[:eventmachine] and (@callbackObj.nil? or @errbackObj.nil?))
        raise RuntimeError, "No callback or errback was registered, yet opted for EventMachine mode (opts[:eventmachine]=#{@opts[:eventmachine].inspect}). This makes no sense. "
      end
      if( !(@xml.is_a?(String) and @xml =~ /\S/) and @geneReviewId.nil?)
        raise RuntimeError, "No geneReviewId has been set, but nor has raw xml been set. Nothing to process!"
      end
      return true
    end

    # Normal-mode retrieve and parse.
    def retrieveDirect()
      @xmlHash = nil
      # Get the xml if don't have it
      if(@xml.is_a?(String) and @xml =~ /\S/) # then xml was externally provided
        xml = @xml
      else  # need to get xml i.e. we need to retrieve the xml, wasn't provided externally by knowledgeable code
        begin
          @url = URL_TEMPLATE.expand(:proto => 'https', :grId => @geneReviewId)
          payload = readUrl(@url)
        rescue RuntimeError => rterr # probably a 'redirection forbidden' due to protocol switch ; give http a try
          @url = URL_TEMPLATE.expand(:proto => 'http', :grId => @geneReviewId)
          payload = readUrl(@url)
        end

        if(payload)
          xml = extractXml(payload)
        else
          msg = "GeneReviews site returned no payload."
          @errors << { :msg => msg, :status => :NO_DOC }
          xml = nil
        end
      end

      # Convert xml to hash
      if(xml)
        @xmlHash = xml2hash(xml)
      end

      # Set errors/warnings to nil if none encountered (for easier status detection)
      @errors = nil if(@errors and @errors.empty?)
      @warnings = nil if(@warnings and @warnings.empty?)
      return @xmlHash
    end

    # EventMachine-mode retrieve and parse and callback.
    def retrieveViaEM()
      @xmlHash = nil
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "@callbackObj: #{@callbackObj.inspect}")
      if(@xml.is_a?(String) and @xml =~ /\S/) # then have raw xml from external knowledgeable code, don't retrieve
        # Have raw XML, don't have to retrieve it from internets ; just schedule parsing and callback
        EM.next_tick {
          begin
            @xmlHash = xml2hash(xml)
            callCallback()
          rescue Exception => err
            @xmlHash = nil
            msg = "Failure parsing raw XML or possibly bad callback provided."
            @errors << { :msg => msg, :err => err, :status => :ERROR_RAISED }
            begin
              callErrback()
            rescue Exception => err
              # Complete failure. Can't even call errback safely
              $stderr.debugPuts(__FILE__, __method__, 'FATAL!!', "(EM-NextTick): Tried to call errback function, but it also threw exception, caught here for safety. Complete disaster: even error reporting triggered an error!. Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n\n#{err.backtrace.join("\n")}")
            end
          end
        }
      else # no raw xml available, download it asynchronously
        require 'em-http-request'
        req = nil
        @url = URL_TEMPLATE.expand(:proto => 'https', :grId => @geneReviewId)
        req = EventMachine::HttpRequest.new(
            @url,
            :connect_timeout => @opts[:connect_timeout],
            :inactivity_timeout => @opts[:inactivity_timeout]
        ).get
        # Register success callback
        req.callback {
          # Aggressive/conservative protection of callback code via begin-rescue.
          # * Fallback. NOT replacement for sensible/contextual begin-rescue and logging.
          begin
            payload  = req.response
            if(payload)
              xml = extractXml(payload)
              if(xml)
                @xmlHash = xml2hash(xml)
              end
            else
              msg = "GeneReviews site returned no payload."
              @errors << { :msg => msg, :status => :NO_DOC }
              xml = nil
            end
            if(@errors and !@errors.empty?)
              callErrback()
            else
              callCallback()
            end
          rescue Exception => err
            
            begin
              @xmlHash = nil
              @errors = []
              msg = "Could not process response for #{@url ? @url.inspect : '[unavailable]'} due to an unexpected error; head of body:\n\n#{payload ? payload[0...RESP_HEAD] : '[unavailable]'}\n\n"
              @errors << { :msg => msg, :err => err, :status => :ERROR_RAISED }
              callErrback()
            rescue Exception => err
              # Complete failure. Can't even call errback safely
              $stderr.debugPuts(__FILE__, __method__, 'FATAL!!', "(EM-NextTick): Tried to call errback function, but it also threw exception, caught here for safety. Complete disaster: even error reporting triggered an error!. Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n\n#{err.backtrace.join("\n")}")
            end
          end
        }
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Registered callback <<<<<")
        # Register failure callback
        req.errback {
          # Aggressive/conservative protection of errback code via begin-rescue.
          begin
            @xmlHash = nil
            payload = req.response
            msg = "(EM-HTTP): Could not retrieve url: #{@url.inspect}. Http request object: #{req.inspect}  ; Headers:\n\n#{req.response_header.inspect} ; Response:\n\n#{payload.inspect}"
            @errors << { :msg => msg, :status => :BAD_URL }
            callErrback()
          rescue Exception => err
            $stderr.debugPuts(__FILE__, __method__, 'FATAL!!', "(EM-HTTP): Could not retrieve url OR properly handle the underlying error! url: #{@url ? @url.inspect : '[unavailable]'}. Http request object: #{req ? req.inspect : '[unavailable]'}  ; Headers:\n\n#{(req and req.response_header) ? req.response_header.inspect : '[unavailable]'} ; Response:\n\n#{payload ? payload.inspect : '[unavailable]'}" )
          end
        }
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Registered errback <<<<<")
      end
      return nil
    end

    # Call the registered success callback.
    def callCallback()
      @errors = nil if(@errors and @errors.empty?)
      @warnings = nil if(@warnings and @warnings.empty?)
      @callbackObj.call(@xmlHash, { :url => @url, :xml => @xml, :warnings => @warnings, :errors => @errors})
    end

    # Call the registered failure callback.
    def callErrback()
      @errors = nil if(@errors and @errors.empty?)
      @warnings = nil if(@warnings and @warnings.empty?)
      @errbackObj.call(@xmlHash, { :url => @url, :xml => @xml, :warnings => @warnings, :errors => @errors})
    end

    # Retrieve the GeneReview content. Has oddly embedded (and html-escaped) XML.
    def readUrl(url = @url)
      payload = nil
      begin
        uri = URI.parse(url)
        urlFh = open(url)
        if(urlFh.status.first !~ /^2/)
          msg = "Received non-OK response from GeneReviews server. Received: #{urlFh.status.inspect}. Probably there will be no doc to parse in the payload."
          @warnings << { :msg => msg }
        end
        payload = urlFh.read() rescue ''
        payload = payload.to_s.strip
        payload = nil if(payload.empty?)
      rescue URI::InvalidURIError => uerr
        payload = nil
        msg = "Could not parse GeneReview url: #{url.inspect}. Cannot retrieve GeneReview doc."
        @errors << { :msg => msg, :uerr => nil, :status => :BAD_URL }
      rescue SocketError => serr
        payload = nil
        msg = "Bad GeneReviews host in url (#{url.insepct}. Cannot look up IP address. Cannot retrieve GeneReview doc."
        @errors << { :msg => msg, :serr => nil, :status => :BAD_URL }
      rescue => err
        payload = nil
        msg = "Retrieving content from #{@url.inspect} failed."
        @errors << { :msg => msg, :err => err, :status => :BAD_URL }
      ensure
        urlFh.close rescue nil
      end

      return payload
    end

    # Extract raw XML that is oddly embedded in the web page.
    def extractXml(payload)
      @xml = nil
      begin
        webDoc = Nokogiri::XML(payload)
        if(webDoc)
          contentElems = webDoc.css('pre')
          if(contentElems and !contentElems.empty?)
            # This will extract the html-escaped cdate in the <pre> tag and present it to you
            #   in unescaped form. Now you have actual XML.
            @xml = contentElems.first.text
            # But some UTF8 things are present. Will covert UTF8 copyright, trademark, asym-quotes, certain others
            # to sensible ASCII things:
            @xml = Iconv.conv("ASCII//TRANSLIT", "UTF-8", @xml)
            # But some of these have converted to invalid sequences like "\342\211\245" becoming ">=" or
            #   "\342\211\244" becoming "<=" or "\342\211\253" becoming ">>"
            # So we're going to try to undo some of those
            @xml = utf8AsciiAsXmlSafe(@xml)
          else
            msg = 'Unexpected payload retrieved from GeneReviews server. Cannot locate element that contains actual XML record. Most likely cause: bad GeneReview ID.'
            @errors << { :msg => msg, :status => :BAD_ID }
          end
        else
          msg = "Parsing GeneReview content retrieved from #{@url.inspect} failed."
          @errors << { :msg => msg, :status => :BAD_XML }
        end
      rescue => err
        msg = "Parsing GeneReview content retrieved from #{@url.inspect} failed."
        @errors << { :msg => msg, :err => err, :status => :BAD_XML }
      end
      return @xml
    end

    # Convert the XML string to a nested Hash.
    def xml2hash(xml = @xml)
      begin
        @xmlHash = Crack::XML.parse(xml)
      rescue => err
        msg = 'Could not parse GeneReview XML. Perhaps it is corrupt or malformed.'
        @errors << { :msg => msg, :err => err, :status => :BAD_XML }
      end
      return @xmlHash
    end

    # Following a systematic utf8=>ascii transliteration like Iconv.conv("ASCII//TRANSLIT", "UTF-8", string),
    # some specific utf8's have converted to invalid sequences like "\342\211\245" becoming ">=" or
    #   "\342\211\244" becoming "<=" or "\342\211\253" becoming ">>"
    # So we're going to try to fix some of those, making them XML safe which allows libraries like
    #   Crack::XML to work without erroring out over the malformed xml content (unescape > and < are malformed see).
    def utf8AsciiAsXmlSafe(str)
      retVal = str.dup
      UTF8_ASCII_HTML_SAFE.each_key { |re|
        retVal.gsub!(re, UTF8_ASCII_HTML_SAFE[re])
      }
      return retVal
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, 'ERROR', "Exception while trying to do gsubs on str. Tried to continue using original input, but here is exception info:\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
      retVal = str
      return retVal
    end
  end
end ; end ; end # module BRL ; module Sites ; module GeneReviews
