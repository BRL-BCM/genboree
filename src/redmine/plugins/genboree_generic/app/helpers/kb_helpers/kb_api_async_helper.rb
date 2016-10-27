
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
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ MODEL ASYNC: Entered reusable async model retriever")
      initLastApiErrVars()
      @lastApiReq = GbApi::JsonAsyncApiRequester.new(env, @gbHost, @project) unless(@lastApiReq)
      rsrcPath = '/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model'
      fieldMap =  { :grp => @gbGroup, :kb => @gbKb, :coll => collName }
      model = nil
      # Callback for request. Will arrange to parse resp or to nil, and will capture any exceptions.
      @lastApiReq.bodyFinish {
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ MODEL ASYNC: in bodyFinish callback")
        begin
          if(@lastApiReq.apiDataObj and @lastApiReq.respStatus < 400 and !@lastApiReq.apiDataObj.is_a?(Exception))
            model = @lastApiReq.apiDataObj
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ MODEL ASYNC: SUCCESS - have model; resp was #{@lastApiReq.respStatus.inspect} with #{@lastApiReq.rawRespBody.size} byte payload")
          else
            model = @lastApiReq.respBody
            @lastApiReqErrText = "ERROR: Could not get model for #{collName.inspect}. Unexpected response payload from Genboree server."
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ MODEL ASYNC: FAILED - here is resp payload:\n\n#{model.inspect}\n\n")
          end
        rescue Exception => err
          model              = err
          @lastApiReqErr     = err
          @lastApiReqErrText = "ERROR: Could not get model for #{collName.inspect}."
          $stderr.debugPuts(__FILE__, __method__, 'ERROR', "#{@lastApiReqErrText.inspect}\n    Error class: #{err.class}\n    Error message: #{err.message}\n    Error trace:\n#{err.backtrace.join("\n")}")
        ensure
          # Call dev's callback with the model they wanted
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ MODEL ASYNC: regardless, calling dev's callback")
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
    # @yieldparam [KbDoc,Exception,nil] kbDoc Your code block will be called with the {KbDoc} as an argument.
    #   The Actionability doc will be a {KbDoc} if things went well. It will be an {Exception}
    #   generally because parsing the API response body failed. It will be nil
    #   if something else went wrong. If an exception is raised even within this
    #   code (i.e. not while parsing the api response), the exception will be in
    #   argument to your code block; also it will be available in @@lastApiReqErr@ as will
    #   a small log/display message in @@lastAsyncReqErrText@.
    def getDocAsync(docId, collName, &callback)
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC: Entered reusable async doc retriever")
      initLastApiErrVars()
      @lastApiReq = GbApi::JsonAsyncApiRequester.new(env, @gbHost, @project) unless(@lastApiReq)
      rsrcPath = '/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}'
      fieldMap = { :grp => @gbGroup, :kb => @gbKb, :coll => collName, :doc  => docId }
      @lastApiReq.bodyFinish {
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC: in bodyFinish callback")
        begin
          if(@lastApiReq.apiDataObj and @lastApiReq.respStatus < 400 and !@lastApiReq.apiDataObj.is_a?(Exception))
            doc = @lastApiReq.apiDataObj
            kbDoc = BRL::Genboree::KB::KbDoc.new( doc )
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC: SUCCESS - have KbDoc; resp was #{@lastApiReq.respStatus.inspect} with #{@lastApiReq.rawRespBody.size} byte payload")
          else
            kbDoc = @lastApiReq.respBody
            @lastApiReqErrText = "ERROR: Could not retrieve Actionability doc with ID #{docId.inspect}."
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "++++++ DOC ASYNC: FAILED - #{@lastApiReqErrText.inspect}. Here is resp payload:\n\n#{kbDoc.inspect}\n\n")
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
