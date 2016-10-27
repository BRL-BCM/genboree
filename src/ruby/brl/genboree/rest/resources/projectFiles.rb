#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/projectFileEntity'
require 'brl/genboree/rest/data/refsEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # ProjectFiles - exposes information about the custom links of a specific project.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ProjectFileEntity
  class ProjectFiles < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true}

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @topLevelProjs.clear() if(@topLevelProjs)
      @projectObj = @topLevelProjs = @projBaseDir  = @escProjName = @projDir = @projName = @aspect = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/files}       # Look for /REST/v1/group/{grp}/prj/{prj} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        @statusName = initProjectObj()
        if(@statusName == :OK)
          entity = loadFileListEntity()
          if(entity != :'Unsupported Media Type')
            @statusName = configResponse(entity)
          else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: Could not read files for project #{@projName.inspect} in user group #{@groupName.inspect}."
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: Read in the file list from the project's data file.
    # [+returns+] A BRL::Genboree::REST::Data::ProjectFileEntityList with one or more custom links.
    def loadFileListEntity()
      component = @projectObj.filesComponent()
      unless(component.empty?(true))
        # create Entity object from dataStr (storage format is json)
        entity = BRL::Genboree::REST::Data::ProjectFileEntityList.deserialize(component.dataStr, :JSON)
      else # no Files [yet], empty
        entity = BRL::Genboree::REST::Data::ProjectFileEntityList.new(@connect)
      end
      return entity
    end
  end # class ProjectFiles
end ; end ; end # module BRL ; module REST ; module Resources
#!/usr/bin/env ruby
