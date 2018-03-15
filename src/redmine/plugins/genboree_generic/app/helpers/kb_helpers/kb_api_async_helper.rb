
module KbHelpers
  module KbApiAsyncHelper

    # @return [GbApi::SimpleAsyncApiRequester, nil]  The last GB API request helper created/used
    #   by methods in this module. Note that a single api requester instance is reused as much as possible.
    attr_accessor :lastApiReq
    # @return [Exception,nil] If an error was rescued during this module's methods, it will be accessible here.
    attr_accessor :lastApiReqErr
    # @return [String,nil] Simple error text when methods of this module notice a problem. Suitable for basic
    #   message to users (no code mumbo-jumbo).
    attr_accessor :lastApiErrText

    # Retrieve the model for a collection in the already configured grp & kb, via async
    #   api call. When done, your callback will be called with the model {KbDoc}
    #   or Exception/nil if there was some problem getting you your model.
    # @note You should have already used the @genboreeAcSettings@ before_filter before using this method,
    #   and thus @gbHost, @gbGroup, @gbKb are all populated.
    # @param [String] collName The collection name to get the model for.
    # @yieldparam [KbDoc,Exception,nil] model Your code block will be called with the model as an argument.
    #   The model will be a {KbDoc} if things went well. It will be an {Exception}
    #   generally because parsing the API response body failed. It will be nil
    #   if something else went wrong. If an exception is raised even within this
    #   code (i.e. not while parsing the api response), the exception will be in
    #   argument to your code block; also it will be available in @@lastApiReqErr@ as will
    #   a small log/display message in @@lastAsyncReqErrText@.
    def getModelAsync(collName, &callback)
      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ MODEL ASYNC: Entered reusable async model retriever")
      initLastApiErrVars()
      @lastApiReq = GbApi::JsonAsyncApiRequester.new(env, @gbHost, @project) unless(@lastApiReq)
      rsrcPath = '/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model'
      fieldMap =  { :grp => @gbGroup, :kb => @gbKb, :coll => collName }
      model = nil
      # Callback for request. Will arrange to parse resp or to nil, and will capture any exceptions.
      @lastApiReq.bodyFinish {
        # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ MODEL ASYNC: in bodyFinish callback")
        begin
          if(@lastApiReq.apiDataObj and @lastApiReq.respStatus < 400 and !@lastApiReq.apiDataObj.is_a?(Exception))
            model = @lastApiReq.apiDataObj
            # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ MODEL ASYNC: SUCCESS - have model; resp was #{@lastApiReq.respStatus.inspect} with #{@lastApiReq.rawRespBody.size} byte payload")
          else
            model = @lastApiReq.respBody
            @lastApiReqErrText = "ERROR: Could not get model for #{collName.inspect}. Unexpected response payload from Genboree server."
            # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ MODEL ASYNC: FAILED - here is resp payload:\n\n#{model.inspect}\n\n")
          end
        rescue Exception => err
          model              = err
          @lastApiReqErr     = err
          @lastApiReqErrText = "ERROR: Could not get model for #{collName.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "#{@lastApiReqErrText.inspect}\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
        ensure
          # Call dev's callback with the model they wanted
          # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ MODEL ASYNC: regardless, calling dev's callback")
          callback.call( model )
        end
      }
      # Do api request
      @lastApiReq.get(rsrcPath, fieldMap)
      # NO CODE HERE. Async.
    end

    # Retrieve a doc from a collection in the already configured grp & kb, via async
    #   api call. When done, your callback will be called with the {KbDoc} Ruby object
    #   or Exception/nil if there was some problem getting you your model.
    # @note You should have already used the @genboreeAcSettings@ before_filter before using this method,
    #   and thus @gbHost, @gbGroup, @gbKb are all populated.
    # @param [String] docId The doc identifier.
    # @param [String] collName The collection name to get the doc from.
    # @param [Hash{Symbol,Object}] opts Optional. Hash of additional options use to get the doc.
    #   @option opts [Fixnum,String] :docVersion Get a specific version of the document, not the default current/head version.
    # @yieldparam [KbDoc,Exception,nil] kbDoc Your code block will be called with the {KbDoc} as an argument.
    #   The Actionability doc will be a {KbDoc} if things went well. It will be an {Exception}
    #   generally because parsing the API response body failed. It will be nil
    #   if something else went wrong. If an exception is raised even within this
    #   code (i.e. not while parsing the api response), the exception will be in
    #   argument to your code block; also it will be available in @@lastApiReqErr@ as will
    #   a small log/display message in @@lastAsyncReqErrText@.
    def getDocAsync(docId, collName, opts={}, &callback)
      # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ DOC ASYNC: Entered reusable async doc retriever")
      initLastApiErrVars()
      # Options
      docVersion = opts[:docVersion]

      @lastApiReq = GbApi::JsonAsyncApiRequester.new(env, @gbHost, @project) unless(@lastApiReq)
      rsrcPath = '/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}?'
      fieldMap = { :grp => @gbGroup, :kb => @gbKb, :coll => collName, :doc  => docId }
      # Incorporate doc version if provided
      if( docVersion )
        rsrcPath += 'versionNum={docVersion}'
        fieldMap[:docVersion] = docVersion
      end

      @lastApiReq.bodyFinish {
        # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ DOC ASYNC: in bodyFinish callback")
        begin
          if(@lastApiReq.apiDataObj and @lastApiReq.respStatus < 400 and !@lastApiReq.apiDataObj.is_a?(Exception))
            doc = @lastApiReq.apiDataObj
            kbDoc = BRL::Genboree::KB::KbDoc.new( doc )
            # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ DOC ASYNC: SUCCESS - have KbDoc; resp was #{@lastApiReq.respStatus.inspect} with #{@lastApiReq.rawRespBody.size} byte payload")
          else
            kbDoc = @lastApiReq.respBody
            if( @lastApiReq.apiStatusObj.is_a?(Hash) and @lastApiReq.apiStatusObj.key?('msg') )
              @lastApiReqErrText = "#{@lastApiReq.apiStatusObj['msg']}"
            else
              @lastApiReqErrText = "ERROR: Could not retrieve Actionability doc with ID #{docId.inspect}."
            end
            # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ DOC ASYNC: FAILED - #{@lastApiReqErrText.inspect}. Here is resp payload:\n\n#{kbDoc.inspect}\n\n")
          end
        rescue Exception => err
          kbDoc = err
          @lastApiReqErr = err
          @lastApiReqErrText = "ERROR: could not retrieve doc with id #{docId.inspect} from collection #{collName.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "#{@lastApiReqErrText.inspect}\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
        ensure
          # Call dev's callback with the KbDoc they wanted
          callback.call( kbDoc )
        end
      }
      @lastApiReq.get(rsrcPath, fieldMap)
      # NO CODE HERE. Async.
    end

    # Get the version record info for a given doc at the indicated version. Can get full versionRec (can be large/expensive) or just the
    #   version number (default); currently there is no way to get just the version record metadata like timestamp, number, is deletion
    #   due to back-end limitation in Genboree API. But when available that can be added.
    # @note Assumes the Controller using this has instance variables @project, @gbHost, @gbGroup, and @gbKb OR that this information
    #   will be provided/overridden via :rmProj, :host, :grp, :kb in the options Hash argument, respectively
    # @note Async. Callback required.
    # @param [Fixnum, Symbol] version Either a supported Symbol :curr, :head, or :prev to get the current/head version record for the doc or
    #   the immediately previous version [if any] ; or a Fixnum corresponding to a valid version id for this dcoument.
    # @param [String] docId The document identifier.
    # @param [String] collName The collection name to get the doc from.
    # @param [Hash{Symbol,Object}] opts Optional. Hash of additional options use to get the doc.
    #   @option opts [Symbol] :info Optional. Default value is :full to get the full version record, which is in KbDoc format.
    #     If you provide the value :versionNum insteady you get a Hash with a single key "number" whose value is the version number.
    #   @option opts [Symbol] :rmProj Optional. Override Controller's @project instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :host Optional. Override Controller's @gbHost instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :grp Optional. Override Controller's @gbGroup instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :kb Optional. Override Controller's @gbKb instance variable or supply it if not available in Controller.
    # @yieldparam [KbDoc,Hash,Exception,nil] kbDoc Your code block will be called with either a {KbDoc}, plain {Hash}, Exception,
    #   or nil argument depending on the :info option you supplied and the result. When asking for the :info=>:full version record,
    #   you'll get back the version record as a KbDoc and it will even have a copy of the content. When asking for just the
    #   :info=>:versionNum info it will be a simple Hash with just the "number" key. It will be an {Exception}
    #   generally because parsing the API response body failed. It will be nil
    #   if something else went wrong. If an exception is raised even within this
    #   code (i.e. not while parsing the api response), the exception will be in
    #   argument to your code block; also it will be available in @@lastApiReqErr@ as will
    #   a small log/display message in @@lastAsyncReqErrText@.
    def getDocVersionRecAsync( version, docId, collName, opts={}, &callback )
      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ VERSION REC ASYNC: Entered reusable async version rec retriever")
      initLastApiErrVars()
      # Options
      info = ( opts[:info] or :full )
      project = ( opts[:rmProj] or @project )
      gbHost = ( opts[:host] or @gbHost )
      gbGroup = ( opts[:grp] or @gbGroup )
      gbKb = ( opts[:kb] or @gbKb )
      raise ArgumentError, "ERROR: the version argument must be one of the Symbols :curr, :head, :prev or a Fixnum version number valid for the document." unless( [:curr, :head, :prev].include?(version) )

      @lastApiReq = GbApi::JsonAsyncApiRequester.new(env, gbHost, project) unless(@lastApiReq)
      rsrcPath = '/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/ver/{ver}?'
      fieldMap = { :grp => gbGroup, :kb => gbKb, :coll => collName, :doc  => docId, :ver => version.to_s.upcase }
      # Incorporate doc version if provided
      if( info == :versionNum )
        rsrcPath += '&versionNumOnly=true'
      else #( info == :full )
        rsrcPath += '&detailed=yes'
      end

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ VERSION REC ASYNC: final rsrcPath: #{rsrcPath.inspect} ; fieldMap:\n\n#{fieldMap.inspect}\n\n")

      @lastApiReq.bodyFinish {
        #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ VERSION REC ASYNC: in bodyFinish callback")
        begin
          if(@lastApiReq.apiDataObj and @lastApiReq.respStatus < 400 and !@lastApiReq.apiDataObj.is_a?(Exception))
            # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ VERSION REC ASYNC: SUCCESS ; resp was #{@lastApiReq.respStatus.inspect} with #{@lastApiReq.rawRespBody.size} byte payload")
            if( info == :versionNum )
              result = @lastApiReq.apiDataObj
            else # (info == :full )
              result = BRL::Genboree::KB::KbDoc.new( @lastApiReq.apiDataObj )
            end
          else # problem
            result = @lastApiReq.respBody
            if( @lastApiReq.apiStatusObj.is_a?(Hash) and @lastApiReq.apiStatusObj.key?('msg') )
              @lastApiReqErrText = "#{@lastApiReq.apiStatusObj['msg']}"
            else
              @lastApiReqErrText = "ERROR: Could not retrieve version rec for #{docId.inspect} at version #{version.inspect}."
            end
            #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ VERSION REC ASYNC: FAILED - #{@lastApiReqErrText.inspect}. Here is resp payload:\n\n#{result.inspect}\n\n")
          end
        rescue Exception => err
          result = err
          @lastApiReqErr = err
          @lastApiReqErrText = "ERROR: could not retrieve version record info for doc with id #{docId.inspect} from collection #{collName.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "#{@lastApiReqErrText.inspect}\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
        ensure
          # Call dev's callback with the KbDoc they wanted
          callback.call( result )
        end
      }
      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ VERSION REC ASYNC: callbacks registered. Now putting get() on event queue.")
      @lastApiReq.get(rsrcPath, fieldMap)
      # NO CODE HERE. Async.
    end

    # Get the current/most-recent version number for a given doc at the indicated version.
    # @note Assumes the Controller using this has instance variables @project, @gbHost, @gbGroup, and @gbKb OR that this information
    #   will be provided/overridden via :rmProj, :host, :grp, :kb in the options Hash argument, respectively
    # @note Async. Callback required.
    # @note A streamlined-convenience method that uses {#getDocVersionRecAsync} internally.
    # @param [String] docId The document identifier.
    # @param [String] collName The collection name to get the doc from.
    # @param [Hash{Symbol,Object}] opts Optional. Hash of additional options use to get the doc.
    #   @option opts [Symbol] :rmProj Optional. Override Controller's @project instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :host Optional. Override Controller's @gbHost instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :grp Optional. Override Controller's @gbGroup instance variable or supply it if not available in Controller.
    #   @option opts [Symbol] :kb Optional. Override Controller's @gbKb instance variable or supply it if not available in Controller.
    # @yieldparam [Fixnum,Exception] versionNumber Your code block will be called with the current version number fo rthe doc or
    #   and Exception with info about the problem. The exception is also in the exception will be in
    #   argument to your code block; also it will be available in @@lastApiReqErr@ as will
    #   a small log/display message in @@lastAsyncReqErrText@.
    def getDocCurrVersionNumAsync( docId, collName, opts={}, &callback )
      #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ CURR VERSION NUM ASYNC: Entered reusable async version rec retriever (#{Time.now.to_f})")
      initLastApiErrVars()

      # Use the more flexible getDocVersionRecAsync(0 to do this)
      version = :curr
      subOpts = opts.merge( { :info => :versionNum } )
      getDocVersionRecAsync( version, docId, collName, subOpts ) { |result|
        # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ CURR VERSION NUM ASYNC: in bodyFinish callback (#{Time.now.to_f})")
        fwdResult = nil
        begin
          if( result.is_a?(Hash) and result.key?('number') )
            fwdResult = result['number'].to_i
          else # unexpected object type in result
            $stderr.debugPuts(__FILE__, __method__, 'ERROR', "Unexpected callback argument given by getDocVersionRecAsync(). Received #{result.class} which has no 'number' key, rather than a Hash with the version number stored at the 'number' key.")
            if( result.is_a?(Exception) )
              # Already logged by getDocVersionRecAsync(). Just arrange fwdResult to dev's callback.
              fwdResult = result
            else
              # Log the result we did get...maybe it's incorrectly the full version rec KbDoc or something?
              $stderr.debugPuts(__FILE__, __method__, 'ERROR', "Received this argument to our callback...not even an Exception but an unexpected object altogether:\n\n#{JSON.pretty_generate(result) rescue result.inspect}\n\n")
              raise IOError, "Unexpected object type provided to internal callback, likely sign of some underlying error."
            end
          end
        rescue => err
          fwdResult = err
          @lastApiReqErr = err
          @lastApiReqErrText = "ERROR: could not retrieve version number for current/most-recent version of doc with id #{docId.inspect} from collection #{collName.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "#{@lastApiReqErrText.inspect}\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
        ensure
          #$stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ CURR VERSION NUM ASYNC:  about to call callback with #{fwdResult.inspect} (#{Time.now.to_f})")
          callback.call( fwdResult )
        end
      }
      # $stderr.debugPuts(__FILE__, __method__, 'TIME', "++++++ CURR VERSION NUM ASYNC: callbacks registered. Now putting get() on event queue.")
      # NO CODE HERE. Async.
    end

    # Convenience method. A number of controller-actions which have Views set appropriate
    #   instance variables which are used by the View to render the page. This method
    #   can be used to arrange for appropriate rendering of the View to the client--even
    #   if some early sanity checks meant NO non-blocking/async api requests were made (thus apiReq is empty), this
    #   method will render normally or via the async-compatible renderToClient() method.
    # @param [Symbol] view The View (usually matches the Controller Action), as a Symbol. e.g. @:show@
    #   or @:index@ or @:update@ are common/standard.
    # @param [GbApi::SimpleAsyncApiRequester, nil] apiReq IFF async/non-blocking http requests were initiated and thus
    #   Thin knows this is an async/deferred response then this will be a non-nil {GbApi::SimpleAsyncApiRequester}
    #   instance used for the request (defaults to @@lastApiReq@ since likely you're using the {GenboreeAcAsyncHelper}
    #   mixin methods). If async request handling was never initiated--probably due to up-front sanity checks--then
    #   there is no such instance and thus @nil@ is passed. This will result in normal (non-async) rendering, probably
    #   of an error display.
    def renderPage( view, apiReq=@lastApiReq )
      if(apiReq)
        if(!@lastApiReqErrText.nil?) # some little error message we want user to see (presumably logged)
          apiReq.renderToClient(self, view)
        else # can render full doc
          apiReq.renderToClient(self, view, apiReq.respStatus)
        end
        # NO CODE HERE. Async.
      else # non-async flow
        render(view, { :content_type => "text/html", :status => "OK" })
      end
    end

    def initLastApiErrVars()
      @lastApiReqErr = @lastApiReqErrText = nil
    end
  end
end
