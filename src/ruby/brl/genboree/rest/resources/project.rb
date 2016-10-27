#!/usr/bin/env ruby
require 'brl/genboree/projectManagement/projectManagement'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/projectApiHelpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/refEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Project - exposes a specific project itself.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::RefsEntity
  class Project < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::REST::ProjectApiHelpers    # Mixin some project-api specific helper methods
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @topLevelProjs.clear() if(@topLevelProjs)
      @topLevelProjs = @projBaseDir  = @escProjName = @projDir = @projName = @aspect = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)$}      # Look for /REST/v1/grp/{grp}/prj/{prj} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return initProjOperation()
    end
    
    
    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        setResponse()
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # - Update Project Name if projName exists and payload is TextEntity
    # - Create Project if projName doesn't exist and payload is empty or TextEntity with the same value as projName
    # - Create Project and copy all contents if projName doesn't exist and payload is RefEntity containing a project resource
    # [+returns+] <tt>Rack::Response</tt> instance
    def put() # creates/renames project
      initStatus = initProjOperation()  # This will get @groupName, @projName etc; Returns :OK or :'Not Found'
      reqBodyEntity = getRequestBody()
      if(initStatus == :OK)
        # UPDATE
        @statusName, @statusMsg = updateProject(reqBodyEntity)
      elsif(initStatus == :'Not Found' and @statusMsg =~ /^NO_PRJ/)
        if(reqBodyEntity.is_a?(BRL::Genboree::REST::Data::RefEntity))
          # COPY
          @statusName, @statusMsg = copyProject(reqBodyEntity)
        elsif(reqBodyEntity.is_a?(BRL::Genboree::REST::Data::TextEntity) or reqBodyEntity == '')
          # CREATE
          # Call helper function to create project and generate appropriate info for API
          @statusName, @statusMsg = createProject(reqBodyEntity)
        end
      else
        @statusName = initStatus
      end
      if(@statusName == :OK)
        setResponse(@statusName, @statusMsg)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initProjOperation()  # This will get @groupName, @projName etc; Returns :OK or :'Not Found'
      if(BRL::Genboree::GenboreeDBHelper.checkUserAllowed(@userId, @groupId, 'o', dbu))
        @statusName = BRL::Genboree::ProjectManagement.deleteProject(@projName, @context)
        if(@statusName == :OK)
          entity = BRL::Genboree::REST::Data::RefsEntity.new(@connect)
          entity.setStatus(:OK, "DELETED: Project #{@projName.inspect} successfully deleted.")
          @statusName = configResponse(entity)
        end
      else
        @statusName = :Forbidden
        @statusMsg = "You do not have permission to delete this project"
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: Tries to parse the body of the request as a TextEntity or as a RefEntity.
    # [+returns+] Whichever entity type it was able to parse the body as, or :'Unsupported Media Type' if neither.
    def getRequestBody()
      entity = ''
      reqBody = self.readAllReqBody()
      unless(reqBody == '')
        entity = BRL::Genboree::REST::Data::TextEntity.deserialize(reqBody, @repFormat)
        if(entity == :'Unsupported Media Type')
          entity = BRL::Genboree::REST::Data::RefEntity.deserialize(reqBody, @repFormat)
        end
      end
      return entity
    end

    # Helper: Sets up the response for this resource
    # [+statusName+]  [optional; default=:OK] Current status code for the response.
    # [+statusMsg+]   [optional; default=nil] Current status message for the response, if any.
    def setResponse(statusName=:OK, statusMsg='')
      refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/prj")
      ref = "#{refBase}/#{Rack::Utils.escape(@projName)}"
      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @projName)
      entity.makeRefsHash(ref)
      entity.setStatus(statusName, statusMsg)
      @statusName = configResponse(entity)
      @resp['Location'] = ref
    end
  end # class Project
end ; end ; end # module BRL ; module REST ; module Resources
