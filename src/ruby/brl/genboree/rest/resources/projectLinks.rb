#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/projectLinkEntity'
require 'brl/genboree/rest/data/refsEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # ProjectLinks - exposes information about the custom links of a specific project.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ProjectLinkEntityList
  class ProjectLinks < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }

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
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/links</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/links}       # Look for /REST/v1/group/{grp}/prj/{prj}/links URIs
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
          entity = loadLinksListEntity()
          if(entity != :'Unsupported Media Type')
            @statusName = configResponse(entity)
          else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: Could not read and parse links for project #{@projName.inspect} in user group #{@groupName.inspect}."
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        @statusName = initProjectObj()
        if(@statusName == :OK)
          entity = BRL::Genboree::REST::Data::ProjectLinkEntityList.deserialize(self.readAllReqBody(), @repFormat)
          if(entity != :'Unsupported Media Type')
            dataStruct = entity.getFormatableDataStruct()
            dataPart = dataStruct['data']
            # storage format is json
            jsonStr = JSON.pretty_generate(dataPart)
            component = @projectObj.linksComponent()
            updateStatus = component.replaceDataFile(jsonStr)
            if(updateStatus) # create status response
              entity = loadLinksListEntity()
              entity.setStatus(:OK, "UPDATED: Project #{@projName.inspect} links successfully updated.")
              # convert to <FORMAT>
              @statusName = configResponse(entity)
            else # failed to make change to project
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: Server error occurred trying to change links for project #{@projName.inspect} in user group #{@groupName.inspect}."
            end
          else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
            @statusName = entity
            @statusMsg = "BAD_REP: Either bad format indicated (#{@repFormat.inspect}) or a bad representation was provided and is not parsable."
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        @statusName = initProjectObj()
        if(@statusName == :OK)
          # 'Delete' by putting empty string there:
          content = ''
          component = @projectObj.linksComponent()
          updateStatus = component.replaceDataFile(content)
          if(updateStatus) # create status response
            entity = loadLinksListEntity()
            entity.setStatus(:OK, "DELETED: Project #{@projName.inspect} links successfully deleted.")
            # convert to <FORMAT>
            @statusName = configResponse(entity, :OK)
          else # failed to make change to project
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: Server error occurred trying to delete links for project #{@projName.inspect} in user group #{@groupName.inspect}."
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

    # Helper: Read in the custom links list from the project's data file.
    # [+returns+] A BRL::Genboree::REST::Data::ProjectLinkEntityList with one or more custom links.
    def loadLinksListEntity()
      component = @projectObj.linksComponent()
      unless(component.empty?)
        # create Entity object from dataStr (storage format is json)
        entity = BRL::Genboree::REST::Data::ProjectLinkEntityList.deserialize(component.dataStr, :JSON)
      else # no links [yet], empty
        entity = BRL::Genboree::REST::Data::ProjectLinkEntityList.new(@connect)
      end
      return entity
    end
  end # class ProjectLinks
end ; end ; end # module BRL ; module REST ; module Resources
