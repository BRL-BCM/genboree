#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # ProjectSimpleAspect - exposes straight-forward aspects of projects, generally ones
  # that have just a single text value rather than being lists of values. Things like:
  # * title
  # * description
  # * custom content
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  class ProjectSimpleAspect < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # Map of the project aspect in the rsrcPath to the keyword used for that aspect in the library code.
    ASPECT2PROJ_COMPONENT = {
                              'title' => 'projectTitle',
                              'description' => 'projectDesc',
                              'customContent' => 'projectContent'
                            }

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
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/(title|description|customContent)</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/(title|description|customContent)}      # Look for /REST/v1/grp/{grp}/prj/{prj}/{title|description|customContent} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    # Process a GET operation on one of the simple project aspects.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        @statusName = initProjectObj()
        if(@statusName == :OK)
          entity = loadSimpleProjectEntity()
          @statusName = configResponse(entity)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on one of the simple project aspects.
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        textEntity = BRL::Genboree::REST::Data::TextEntity.deserialize(self.readAllReqBody(), @repFormat)
        if(textEntity != :'Unsupported Media Type')
          @statusName = initProjectObj()
          if(@statusName == :OK)
            content = textEntity.text
            component = @projectObj.getComponent(@aspect)
            updateStatus = component.replaceDataFile(content)
            if(updateStatus) # create status response
              entity = loadSimpleProjectEntity()
              entity.setStatus(:OK, "UPDATED: Project #{@projName.inspect} #{@aspect} successfully updated.")
              # convert to <FORMAT>
              @statusName = configResponse(entity)
            else # failed to make change to project
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: Server error occurred trying to change #{@aspect.inspect} of project #{@projName.inspect} in user group #{@groupName.inspect}."
            end
          end
        else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
          @statusName = :'Unsupported Media Type'
          @statusMsg = "BAD_REP: Either bad format indicated (you used: #{@repFormat.inspect}) or a bad representation was provided and is not parsable."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on one of the simple project aspects.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        if(@aspect == 'description' or @aspect == 'customContent')
          @statusName = initProjectObj()
          if(@statusName == :OK)
            # 'Delete' by putting empty string there:
            content = ''
            component = @projectObj.getComponent(@aspect)
            updateStatus = component.replaceDataFile(content)
            if(updateStatus) # create status response
              entity = loadSimpleProjectEntity()
              entity.setStatus(:OK, "DELETED: Project #{@projName.inspect} #{@aspect} successfully deleted.")
              # convert to <FORMAT>
              @statusName = configResponse(entity)
            else # failed to make change to project
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: Server error occurred trying to delete #{@aspect.inspect} of project #{@projName.inspect} in user group #{@groupName.inspect}."
            end
          end
        else # title or something can't change or unknown
          return notImplemented()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: Load the current content of a simple project aspect using the
    # ProjectMainPage instance in @projMainPageObj.
    # [+returns+] A BRL::Genboree::REST::Data::TextEntity for the content.
    def loadSimpleProjectEntity()
      # load project data
      component = @projectObj.getComponent(@aspect)
      unless(component.empty?)
        # create Entity object from dataStr (storage format is json)
        entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, component.dataStr)
      else # no content [yet], empty
        entity = BRL::Genboree::REST::Data::TextEntity.new(@connect)
      end
      return entity
    end
  end # class ProjectSimpleAspect
end ; end ; end # module BRL ; module REST ; module Resources
