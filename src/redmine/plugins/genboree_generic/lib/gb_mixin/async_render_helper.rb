module GbMixin
  # Mixes in some render helper methods intended for use in your async callback code. Useful for both basic library
  #   (lib/) implementation AND app/controller/ or app/helper/ code.
  module AsyncRenderHelper
    attr_reader :rackEnv, :rackCallback, :rackClose
    # @return [String] The Rails 'action_dispatch.request_id' uniq request id value. This is the same
    #   as the {ActionDispatch::Request#uuid} value available from the @request@ variable in your controller
    #   and acts as a unique id for the incoming request rails is trying to handle.
    attr_reader :railsRequestId

    # Saves key rack infrastructure callbacks and unique request ids (for trackable logging). Extracts commonly needed
    #   info into standard variables for use doing async stuff.
    # @note Thus async-aware libraries should arrange to call this BEFORE doing any work. Generally this is done
    #   by having the library class constructor take the rackEnv from the Controller context where the Rack env hash is availble.
    #   For example: @SimpleAsyncApiRequester.new( env, tgtHost, @project )@ does this.
    # @param [Hash] rackEnv The Rack env hash.
    # @return [Hash] The Rack env Hash you passed in.
    def initRackEnv( rackEnv )
      @rackEnv          = rackEnv
      @rackCallback     = @rackEnv['async.callback']
      @rackClose        = @rackEnv['async.close']
      @railsRequestId   = @rackEnv['action_dispatch.request_id']
      return rackEnv
    end

    # Get a SaferRackProc corresponding to the callback arg or code block.
    #   Will automatically use @rackCallback--extracted from Rack env during a prior call to initRackEnv--
    #   when creating the SaferRackProc object. As explained in SaferRackProc, the Rack callback (typically the
    #   Proc storage at 'async.callback' in the Rack environment hash) is used to respond directly to the client
    #   when a serious error from within callback code is rescued by SaferRackProc's fall-back/protection code.
    # @param [Proc] callback The Proc or code-block for which to generate a SaferRackProc object.
    # @return [SaferRackProc] The SaferRackProc object to use. Employ like you would a Proc but note that if you
    #   provide it to a method via "&", as is common, that operator will convert it BACK INTO a regular Proc!
    def saferRackProc( &callback )
      cb = ( block_given? ? Proc.new : callback )
      retVal = ( cb.is_a?(Proc) ? SaferRackProc.withRackCallback( @rackCallback, &cb ) : nil )
    end

    # Render the view and send results to client via the async.callback.
    #   Generally called with just the controller (@renderToClient(self)@) to have the default
    #   template found and used by Rails, or called with just the controller plus
    #   the template/View as a {Symbol} which is useful when want to render using non-default
    #   template (@render(self, :alt_show)@). More complex scenarios are possible, such as
    #   provding render configs that indicate partials or XML or whatever, as well as tweaking
    #   the status and headers appropriately.
    # @param [ApplicationController] controller The specific {ApplicationController} instance which is
    #   calling this method. The @render@ method will be called in the context of this object, so
    #   all instance variables etc are available to the View template as usual.
    # @param [nil,Symbol,Hash] templateOrConf OPTIONAL. Either (1) not-provided or @nil@ in order to have the default View
    #   template used as normal ; (2) the {Symbol} of a View template to render (or String, including
    #   the various namespaced/organized View template strings that employ paths etc ; (3) a render
    #   config {Hash} for special rendering scenarios. See Rails' @render@ docs. Generally option (1) or
    #   (2) are employed.
    # @param [Fixnum] status OPTIONAL. Override the default response status of 200.
    # @param [Hash] headers OPTIONAL. Provide additional headers. By default the 'Content-Type' header
    #   will be set to 'text/html' and 'Content-Length' will be set to the length of the render output
    #   unless you override these.
    def renderToClient(controller, templateOrConf=nil, status=200, headers={})
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Have params? #{params.inspect rescue "NO, DON'T"}")
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "headers #{headers.inspect}")
      # Make render config no matter how called
      if(templateOrConf.is_a?(Symbol) or templateOrConf.is_a?(String))
        renderConf = { :action => templateOrConf }
      else # templateOrConf must be a render config Hash or nil
        renderConf = templateOrConf
      end

      # Should we try to fill in Content-Type automatically? Yes, if not provided and there's a standard 'format' param
      unless( headers.key?('Content-Type') and headers.key?('Content-type'))
        # No content-type provided. need to set one.
        # Can we use an appropriate one according to the 'format' param?
        if( defined?(params) and params and !params['format'].to_s.blank?)
          format = params['format']
          mimeType = Mime::Type.lookup_by_extension(format)
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUg', "format = #{format.inspect} ; mimeType = #{mimeType.inspect}")
          if( mimeType )
            mimeTypeStr = mimeType.to_s # should be a type/subtype mime string
            if( mimeTypeStr.size >= 3 and mimeTypeStr.index('/') ) # trust no one
              #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "use #{mimeTypeStr.inspect}")
              headers['Content-Type'] = mimeTypeStr
            else # can't locate a sensible mime type for format
              headers['Content-Type'] = 'text/html'
              #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "1 use text/html")
            end
          end
        else # no params['format']
          #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "2 use text/html")
          headers['Content-Type'] = 'text/html'
        end
      end

      # Render (returns "lines" array...although generally just 1 big String in it)
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "renderConf: #{renderConf.inspect} ; app: #{Rails.application.class.inspect rescue "none"} ; app default_scope:\n\n#{Rails.application.routes.default_scope.inspect rescue "none"}\n\n")

      htmlLines = controller.instance_eval { (renderConf ? render(renderConf) : render()) }

      unless(headers['Content-Length'])
        contentLength = htmlLines.reduce(0) { |sum, line| sum += line.size ; sum }
        headers['Content-Length'] = contentLength.to_s
      end

      # Send to client
      sendToClient(status, headers, htmlLines)
    end

    # When ready to send to client, probably from within one of your bodyFinish callbacks,
    #   can use this to send body back to the client. As long as you passed the rackEnv forward,
    #   it will work
    # @param [Fixnum] status The HTTP response status code to send to the client.
    # @param [Hash] headers The HTTP response headers.
    # @param [String,Object] body A String or Object supporting @each()@ which contains chunk strings that will be sent to client.
    def sendToClient(status, headers, body)
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "#{'-'*80}\n\nself: #{self.object_id} [#{@railsRequestId.inspect}] sendToClient called with status: #{status.inspect} ; body (a #{body.class.inspect}) is:\n\n#{body.inspect.size > 1024 ? "#{body.inspect[0,1024]}" : body.inspect}")
      # @todo Only actually send to client if connection is not closed.
      @rackCallback.call( [ status, headers, body ] )
    end
  end
end
