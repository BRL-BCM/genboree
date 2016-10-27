#!/usr/bin/env ruby
require 'json'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/projectApiHelpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/projectEntity'

#--
module BRL ; module REST ; module Resources                # <- service classes must be in this namespace
#++

  # Projects -  exposes the collection of projects within a certain group
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  class Projects < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::REST::ProjectApiHelpers    # Mixin some project-api specific helper methods
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

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

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prjs$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prjs$}      # Look for /REST/v1/grp/{grp}/prjs URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 4          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initProjOperation()
      if(initStatus == :OK)
        if(@detailed)
          entityList = BRL::Genboree::REST::Data::DetailedProjectEntityList.new()
          unless(@topLevelProjs.nil? or @topLevelProjs.empty?)
            refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/prj")
            @topLevelProjs.each { |tpRow|
              prjObj = BRL::Genboree::Abstract::Resources::Project.new(tpRow['id'], tpRow['groupId'])
              tpName = tpRow['name']
              # Build a textEntityList for the subprojects
              subPrjEntityList = BRL::Genboree::REST::Data::TextEntityList.new()
              unless(prjObj.subProjects.nil? or prjObj.subProjects.empty?)
                prjObj.subProjects.each { |subProj|
                  subPrjEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, subProj)
                  subPrjEntity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tpName)}%2F#{Rack::Utils.escape(subProj)}")
                  subPrjEntityList << subPrjEntity
                }
              end
              entity = BRL::Genboree::REST::Data::DetailedProjectEntity.new(@connect, tpName, prjObj.descComponent().dataStr , subPrjEntityList)
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tpName)}")
              entityList << entity
            }
          end
        else
          # Put top level project in this group into a TextEntityList
          entityList = BRL::Genboree::REST::Data::TextEntityList.new()
          unless(@topLevelProjs.nil? or @topLevelProjs.empty?)
            refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/prj")
            @topLevelProjs.each { |tpRow|
              tpName = tpRow['name']
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, tpName)
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tpName)}")
              entityList << entity
            }
          end
        end
        @statusName = configResponse(entityList)
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. Create a new project wihtin this group.
    # [+returns+] <tt>Rack::Response</tt> instance
    def put() # create new project in this group
      # Init group info (@groupName etc)
      initStatus = initGroup()
      if(initStatus == :OK)
        # Extract project name to create from request body
        textEntity = BRL::Genboree::REST::Data::TextEntity.deserialize(self.readAllReqBody(), @repFormat)
        if(textEntity != :'Unsupported Media Type')
          # Get new name from the TextEntity in the body
          newProjName = textEntity.text
          # Call helper function to create project and generate appropriate info for API
          @statusName, @statusMsg = createProject(textEntity)
          setResponse(@statusName, @statusMsg)
        else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
          @statusName = :'Unsupported Media Type'
          @statusMsg = "BAD_REP: Either bad format indicated (#{@repFormat.inspect}) or a bad representation was provided and is not parsable."
        end
      else
        @statusName = initStatus  
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

    # Helper: Sets up the response for this resource using @groupName and @projName
    # [+statusName+]  [optional; default=:OK] Current status code for the response.
    # [+statusMsg+]   [optional; default=''] Current status message for the response, if any.
    def setResponse(statusName=:OK, statusMsg='')
      refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/prj")
      ref = "#{refBase}/#{Rack::Utils.escape(@projName)}"
      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @projName)
      entity.makeRefsHash(ref)
      entity.setStatus(statusName, statusMsg)
      @statusName = configResponse(entity, statusName)
      @resp['Location'] = ref
    end
  end # class Projects
end ; end ; end # module BRL ; module REST ; module Resources
