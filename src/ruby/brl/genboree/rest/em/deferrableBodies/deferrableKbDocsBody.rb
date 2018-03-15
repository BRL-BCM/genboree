require 'brl/genboree/rest/em/deferrableBodies/abstractMultiPhaseBody'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/producers/nestedTabbedModelProducer'
require 'brl/genboree/kb/producers/nestedTabbedDocProducer'
require 'brl/genboree/kb/producers/fullPathTabbedModelProducer'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'
require 'brl/genboree/kb/helpers/viewsHelper'
require 'brl/genboree/rest/resources/kbViews'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class DeferrableKbDocsBody < AbstractMultiPhaseBody
    # What states are there to streaming the data?
    #   * MUST have no-arg methods corresponding to exactly these.
    #     - No-arg, and must return a String (the chunk) even if '' is most appropriate when finishing up or something.
    #   * Processing will automatically begin in your FIRST  state in this array.
    #   * SPECIAL: There is ALWAYS :finish state, corresponding to AbstractDeferrableBody#finish.
    #     - You're supposed to implement that (with super() call) to close handles and help free memory!
    #     - You can list it here for completeness/documentation or now
    STATES = [ :preData, :getData, :postData, :finish ]

    DEF_NUM_DOCS = 100
    KEYS_TO_CLEAN = ['_id', :_id]
    CACHE_MAX_BYTES = 200 * 1024 * 1024 # ~200MB

    attr_accessor :docsCursor, :revision
    attr_accessor :format, :model, :limit, :viewCursor, :viewType, :viewName, :viewsHelper, :dataHelper, :wrapInGenbEnvelope

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :preData => called after the preData setup phase is done
    #   * :getData => called after the data sending phase is done
    #   * :postData => called after the postData phase is done
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events
    attr_reader :cacheContent

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts) # Initialize inherited infrastructure
      @events += [ :preData, :postData, :getData ]

      # Our stuff:
      @maxDocs    = (opts[:chunkMaxDocs] or DEF_NUM_DOCS)
      @detailed   = (opts.key?(:detailed) ? opts[:detailed] : true)
      @idPropName = opts[:idPropName]
      @limit      = opts[:limit]
      @docsCursor = opts[:docsCursor]
      @model      = opts[:model]
      @viewName   = opts[:viewName]
      @viewsHelper  = opts[:viewsHelper]
      @viewCursor = opts[:viewCursor]
      @viewType   = (opts[:viewType] or 'flat')
      @dataHelper   = opts[:dataHelper]
      @revision = (opts.key?(:revision) ? opts[:revision] : nil)
      @wrapInGenbEnvelope = (opts.key?(:gbEnvelope) ? opts[:gbEnvelope] : true)
      @format     = (opts[:format] or :JSON)

      @producer = nil
      @currNum = 0
      @firstDoc = true
      @cacheContent = ''
      genbConf = BRL::Genboree::GenboreeConfig.load()
      @cache_max_bytes = genbConf.apiCacheMaxBytes.to_i rescue nil
      @cache_max_bytes = @cache_max_bytes.nil? ? CACHE_MAX_BYTES : @cache_max_bytes

       #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "MAX CACHE = #{@cache_max_bytes.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Extracted opts and now have:\n\n  - limit: #{@limit.inspect}\n  - detailed: #{@detailed.inspect}\n  - veiwName: #{@viewName.inspect}\n  - viewCursor: #{@viewCursor.class.inspect}\n  - format: #{@format.inspect}\n  - model: #{@model.class.inspect}")

      # Sanity checks
      raise ArgumentError, "ERROR: Must provide name of root property via :idPropName" unless(!@idPropName.nil? and @idPropName =~ /\S/)
    end

    # AUGMENT. Implement but include a super() call.
    def finish()
      super()
      @docsCursor.close rescue nil
      # Try to make sure mongo connections etc get closed.
      # - The Resource HTTP method disabled clean up at request time, so we have to
      #   handle clean up at deferred time.
      begin
        @dataHelper.kbDatabase.clear()
        @viewsHelper.kbDatabase.clear()
      rescue => err
        # no-op
      end

      # Aid GC!
      @model = @producer = @viewsHelper = @dataHelper = @viewCursor = @viewPropObj = @viewProps = @cacheContent = nil
      return
    end

    # IMPLEMENT.
    # STATE: :preData - Phase 1, Pre data spooling set-up.
    #   * Use this to do any set-up or send out any header-row/open-wrapper type text etc.
    #   * Don't set up IO handles in initialize() since calling code may set some post-instantiation
    #     config via the accessors. Do it here.
    #   * MUST ensure proper state-transition happens by setting @state to next state when ready.
    #     Generally this is called once and then does a @state=:getData to go to data sending phase.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of data. Typically some column header or wrapper-open text.
    def preData()
      # Arrange for MongoKbDatabase#clear to actually release its resources since we prevented that when Resource#get() was called
      tt = Time.now
      begin
        @dataHelper.kbDatabase.doClear = true
        @viewsHelper.kbDatabase.doClear = true
      rescue => err # mainly because @viewsHelper propabbly nil when no view used.
        # no-op
      end
      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Entering pre data spooling phase; to do set up and any initial bytes for format.")
      chunk = ''
      # Set up to send dat ain @format:
      if(@format == :TABBED or @format == :TABBED_PROP_PATH)
        @producer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model)
      elsif(@format == :TABBED_PROP_NESTING)
        @producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(@model)
      else
        if(@format == :JSON_PRETTY)
          if(@wrapInGenbEnvelope)
            chunk << "{\n  \"data\":\n   [\n"
          else
            chunk << "[\n"
          end
        else
          if(@wrapInGenbEnvelope)
            chunk << "{\"data\":["
          else
            chunk << "["
          end
        end
      end
      # Set up counters and flags, etc:
      @currNum = 0
      @firstDoc = true
      @viewProps = [ { 'value' => @idPropName } ]
      # $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Prior to view processing, have (note viewProps):\n\n  - limit: #{@limit.inspect}\n  - detailed: #{@detailed.inspect}\n  - veiwName: #{@viewName.inspect}\n  - viewCursor: #{@viewCursor.class.inspect}\n  - format: #{@format.inspect}\n  - model: #{@model.class.inspect}\n  - @viewProps: #{@viewProps.inspect}")
      # Set up view stuff if needed:
      if(@viewName)
        if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName))
          @viewCursor.each { |doc| # Only has one doc, actually
            doc = BRL::Genboree::KB::KbDoc.new( doc )
            viewPropsList = doc['name']['properties']['viewProps']['items']
            @viewType = doc.getPropVal('name.type')
            viewPropsList.each { |propObj|
              viewPropValue = propObj['prop']['value']
              viewPropLabel = nil
              if(propObj['prop'].key?('properties') and propObj['prop']['properties'].key?('label'))
                propObjKbDoc = BRL::Genboree::KB::KbDoc.new( propObj )
                viewPropLabel = propObjKbDoc.getPropVal('prop.label')
              end
              viewPropObj = { "value" => viewPropValue }
              viewPropObj['label'] = viewPropLabel if(viewPropLabel)
              @viewProps << viewPropObj
            }
          }
        end
        @detailed = true # For views, we will need the full document
      end
      # $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Prior to view processing, have (note viewProps):\n\n  - limit: #{@limit.inspect}\n  - detailed: #{@detailed.inspect}\n  - veiwName: #{@viewName.inspect}\n  - viewCursor: #{@viewCursor.class.inspect}\n  - format: #{@format.inspect}\n  - model: #{@model.class.inspect}\n  - @viewProps: #{@viewProps.inspect}")
      # Next state:
      @cacheContent = chunk
      @state = :getData
      notify(:preData)

      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done pre data spooling phase. Moving to data spooling.")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> @cacheContent: #{@cacheContent.inspect}")
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Time to complete: #{Time.now - tt} secs")
      return chunk
    end # def preData()

    # IMPLEMENT.
    # STATE: :getData - Phase 2, spool out the doc data
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally when run out of actual data lines to send (so many times @state will be set to :getData
    #     while there is still data to send, so we stay in this state). Then after all data gone out,
    #     you would effet a state transition via @state=:postData
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Not too big for memory, not too long to generate (short ticks!), etc.
    def getData()
      chunk = ''
      docCount = 0
      mongoDoc = nil
      tt = Time.now
      while( mongoDoc = @docsCursor.next() )
        doc = BRL::Genboree::KB::KbDoc.new( mongoDoc )
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Streaming doc with ID #{doc.getPropVal(@idPropName)}" )
        unless(@detailed) # ensure we only have the identifier (mainly for the all-docs/no-matching case)
          oldDoc = BRL::Genboree::KB::KbDoc.new(doc)
          newDoc = BRL::Genboree::KB::KbDoc.new()
          newDoc.setPropVal(@idPropName, oldDoc.getPropVal(@idPropName))
          doc = newDoc
        end
        if(@format.to_s =~ /json/i)
          unless(@firstDoc)
            chunk << ",\n"
          end
        end
        # Clean the document by removing unwanted keys from the response
        docKb = BRL::Genboree::KB::KbDoc.new(doc)
        docKb.cleanKeys!(KEYS_TO_CLEAN)
        doc.cleanKeys!(KEYS_TO_CLEAN)
        doc = @dataHelper.transformIntoModelOrder(doc, { :doOutCast => true, :castToStrOK => true }) if(@detailed) #Transform the doc order into model order if full representation is requested.
        # If @viewName is not nil, we may need to generate the docs as a custom view
        # A view essentially defines a set of properties to show alongwith the document identifier property instead of all the properties
        if(@viewName.nil?)
          if(@format == :JSON_PRETTY)
            chunk << JSON.pretty_generate(doc).gsub(/^/, "        ") # This makes it look better on the client side
          elsif(@format == :JSON)
            chunk << JSON.generate(doc)
          else
            @producer.produce(doc) { |line| chunk << "#{line}\n" }
          end
        else
          transformedDoc = @viewsHelper.transformDoc(docKb, @viewProps, @idPropName, @viewType)
          if(@format == :JSON_PRETTY)
            chunk << JSON.pretty_generate(transformedDoc).gsub(/^/, "        ")
          elsif(@format == :JSON)
            chunk << JSON.generate(transformedDoc)
          else
            addHeader = ( @docCount == 0 ? true : false )
            chunk << @viewsHelper.tabbedDoc(transformedDoc, @viewProps, @viewType, addHeader) # Cannot use the producer since 'flat' view docs have no root property neither do they follow the model schema
          end
        end
        # Now have another doc
        @currNum += 1
        docCount += 1
        @firstDoc = false
        # Are we done accumulating for this tick?
        # - Have we reached the @limit of docs?
        # - Or, if not, have we reached the maximum chunk size?
        if(@limit and @limit > 0 and @currNum >= @limit)
          # Yes, reached @limit number of docs to return.
          # Send this out and then move to post-spooling phase
          @state = :postData
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "limit (#{@limit}) reached. calling postData(); Next state: #{@state.inspect}: docs done so far: #{@currNum}")
          notify(:getData)
          break
        elsif(docCount >= @maxDocs or chunk.size >= @chunkSize)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Reached yield criteria. docCount: #{docCount}; buff.size: #{buff.size} Yielding..." )
          # Yes, this chunk is now too big to accumulate more, time to send.
          # Send this out and then spool up another chunk.
          @state = :getData
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "limit (#{@limit}); doc count: ( #{docCount} ) >= @maxDocs (#{@maxDocs}) or chunk size (#{chunk.size}) exceeds threshold (#{@chunkSize}). Docs done so far: #{@currNum}. Next state: #{@state.inspect} Yielding...")
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- have sent total #{@currNum.inspect} docs, #{docCount.inspect} in this chunk of #{chunk.size} bytes")
          break
        # else keep accumulating more for this chunk
        end
      end

      # If we're still in the send-data phase (no limit reached etc), then did the last cursor.next()
      # end with an actual mongo doc (so there still be more) or with nil (no more docs in cursor)?
      if(mongoDoc and @state == :getData)
        # Send out current chunk.
        # Keep spooling more docs next tick
        @state = :getData
      else # mongoDoc is nil or we're done for another reason
        # Send out current chunk.
        # Enter post spooling phase.
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "cursor has reached end and we have sent out #{@currNum} docs")
        @state = :postData
        notify(:getData)
      end
      # add to cache if cache is not nil
      unless(@cacheContent.nil?)
        # check the size
        # keep adding
        if(@cacheContent.size < @cache_max_bytes)
          @cacheContent << chunk
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- Cache content size - #{@cacheContent.size} bytes exceeded the limit !!! #{@cache_max_bytes}. Buffering stopped and cache set to nil" )
          @cacheContent = nil
        end
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- have sent total #{@currNum.inspect} docs, #{docCount.inspect} in this chunk of #{chunk.size} bytes, MAX CACHE = #{@cache_max_bytes.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- cache str in TOTAL  #{@cacheContent.size} bytes") unless(@cacheContent.nil?)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Time to complete: #{Time.now - tt } secs")
      return chunk
    end # def getData()

    # IMPLEMENT.
    # STATE: :postData - Phase 3, post data spooling.
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally this will be :finish to schedule clean up.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Typically some footer text, close-wrapper, or even empty string if not applicable.
    def postData()
      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done data spooling. Entering post data spooling phase to send any final bytes for fomat.")
      chunk = ''
      tt = Time.now
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Done looping over docCursor." )
      if(@format == :JSON_PRETTY)
        if(@wrapInGenbEnvelope)
          chunk << "\n   ],\n  \"status\":\n   {\n     \"msg\": \"OK\"\n   }\n"
          if(@revision)
            chunk << ", \n  \"metadata\":\n   {\n     \"revision\": \"#{@revision}\"\n   }\n"
          end
          chunk << " }"
        else
          chunk << "\n ]"
        end
      elsif(@format == :JSON)
        if(@wrapInGenbEnvelope)
          chunk << "],\"status\":{\"msg\": \"OK\"}"
          if(@revision)
            chunk << ",\"metadata\":{\"revision\": \"#{@revision}\"}"
          end
          chunk << "}"
        else
          chunk << "]"
        end
      end
      # Get the last bit to the cache as well
      unless(@cacheContent.nil?)
        @cacheContent << chunk
      end
      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done post data spooling phase. Should done any final finishing/cleanup next.")
      @state = :finish # really only needed for older yield approach; scheduleSend knows to go directly to scheduleFinish after postData
      notify(:postData)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- have sent total #{@currNum.inspect} docs,  chunk of #{chunk.size} bytes")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "<#{self.object_id}> --- @cacheContent TOTAL,  chunk of #{@cacheContent.inspect} ")
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Time to complete: #{Time.now - tt} secs") 
      return chunk
    end
  end
end ; end ; end ; end ; end
