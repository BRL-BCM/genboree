#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/workbenchJobEntity'
require 'brl/genboree/tools/toolHelperClassLoader'
require 'brl/genboree/tools/workbenchErrors'
require 'brl/genboree/tools/viewHelper'
require 'brl/genboree/tools/toolConf'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class ToolUIResources < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Tools::ViewHelper
    include BRL::Genboree::Tools::ToolHelperClassLoader

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

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
      return %r{^/REST/#{VER_STR}/genboree/ui/tool/([^/\?]+)/([^/\?]+)$}
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
      @toolIdStr = Rack::Utils.unescape(@uriMatchData[1])
      @uiCategory = Rack::Utils.unescape(@uriMatchData[2]) # workbenchDialog
      # Protection to prevent breakage (only 1 responseFormat supported now and
      # in the anticipated future; override whatever dev put in the URL):
      @responseFormat = :HTML

      # From toolHelperClassLoader mix-in. Get proper class and instantiate them.
      self.getHelper(:Rules)  # instance in @rulesHelper
      self.getHelper(:Job)    # instance in @jobHelper
      # TODO: Determine if this is a valid toolIdStr
      if(@rulesHelper.workbenchRules.empty?)
        @statusName = :'Not Found'
        @statusMsg = "The rules for this UI could not be found"
      end

      return @statusName
    end

    # Process a GET operation on this resource.
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      # If something wasn't right, represent as error
      if(initStatus == :OK)
        # Request body must be a WorkbenchJob
        payload = parseRequestBodyForEntity('WorkbenchJobEntity')
        rulesSatisfied = true
        if(payload.is_a?(BRL::Genboree::REST::Data::WorkbenchJobEntity))
          # @todo DANGER DANGER. FIX THIS
          # - This is relying on context['userId'] for the id of the user trying to access the
          #   tool's UI. This is bad. If user sends someone else's ID, they will have inappropriate access to the
          #   real UI (horrors)
          # - This request is being done as a straight API call, not mediated by apiCaller.jsp. The @userId will be 0 in this case.
          #
          # Get tool config object and set hasAccess
          @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
          userId = ((payload.context and payload.context.key?('userId')) ? payload.context['userId'] : @userId)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "---- What is @userId from the super() calll?? ----> userId = #{userId.inspect} ; @userId = #{@userId.inspect}")
          @hasAccess = self.checkAccess(userId, @toolConf)
          # Add useful info about the user to the context
          payload = @jobHelper.fillClientContext(payload)
          begin
            # Get the relevant view for the dialog (UI vs Help)
            # Merge the payload into the template
            #uiType = (@rulesHelper.rulesSatisfied?(payload, [:inputs, :outputs]) ? @uiCategory : "#{@uiCategory}Help")
            if(@rulesHelper.rulesSatisfied?(payload, [:inputs, :outputs]))
              uiType = @uiCategory
            else
              uiType = "#{@uiCategory}Help"
              rulesSatisfied = false
            end
            # Add genbConf and toolIdStr to the evaluate() context so they are available
            # as @genbConf and @toolIdStr in the rhtml
            bodyText = renderDialogContent(@toolIdStr, uiType, payload.getEvalContext(:genbConf => @genbConf, :toolIdStr => @toolIdStr, :hasAccess => @hasAccess))
          rescue BRL::Genboree::Tools::WorkbenchUIError => wue
            @statusName = wue.statusName
            @statusMsg = wue.statusMsg
            $stderr.puts '-' * 60
            $stderr.puts "WorkbenchUIError => Status name: #{@statusName}\nStatus message: #{@statusMsg}\nError message: #{wue.message}\nBacktrace:\n #{wue.backtrace.join("\n")}"
          rescue => err
            @statusName = :'Bad Request'
            @statusMsg = "Either the template view for the requested resource does not exist, or some other problem trying to render the UI (error message: #{err.message})."
            $stderr.puts '-' * 60
            $stderr.puts "Error name: #{@statusName}\nError message: #{@statusMsg}\nBacktrace:\n #{err.backtrace.join("\n")}"
          end
        else
          @statusName = :"Unsupported Media Type"
          @statusMsg = "The request body must be a valid WorkbenchJobEntity"
          $stderr.puts "payload is a #{payload.class} #{payload.inspect}"
        end
      end
      if(@statusName == :OK)
        # Set the response to the template
        # @repFormat = :HTML
        # Since bodyText is just plain String with HTML (not a formal Entity),
        # we won't be going through any setResponse() and configResponse().
        # So set these things manually:
        #$stderr.puts("HTTP_STATUS_NAMES: #{HTTP_STATUS_NAMES.inspect}")
        #@resp.status = rulesSatisfied ? HTTP_STATUS_NAMES[:OK] : HTTP_STATUS_NAMES[:"Not Acceptable"]
        @resp.status = HTTP_STATUS_NAMES[:OK]
        @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:HTML]
        if(@resp.body.respond_to?(:size))
          @resp['Content-Length'] = @resp.body.size.to_s
        end
        @resp.body = bodyText
      else
        @resp = representError()
      end
      return @resp
    end

  end # class
end ; end ; end # module BRL ; module REST ; module Resources
