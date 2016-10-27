#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/rest/data/projectEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # ProjectSubProjects - exposes information about the sub Projects of a specific project.
  #
  class ProjectSubProjects < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @topLevelProjs.clear() if(@topLevelProjs)
      @projectObj = @topLevelProjs = @projBaseDir = @escProjName = @projDir = @projName = @aspect = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/subProjects}       # Look for /REST/v1/group/{grp}/prj/{prj} URIs
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
          entity = loadEntity()
          if(entity != :'Unsupported Media Type')
            @statusName = configResponse(entity)
          else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: Could not get subprojects for project #{@projName.inspect} in user group #{@groupName.inspect}."
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

    # [+returns+] A BRL::Genboree::REST::Data::TextEntityList with one or more custom links.
    def loadEntity()
      refsBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/prj/#{Rack::Utils.escape(@projName)}")
      subProjects = @projectObj.subProjects
      if(@detailed)
        entityList = BRL::Genboree::REST::Data::DetailedProjectEntityList.new(@connect)
        unless(subProjects.empty?)
          subProjects.each { |subProj|
            subPrjObj = BRL::Genboree::Abstract::Resources::Project.new("#{@projName}/#{subProj}", @groupId)
            refName = "#{refsBase}%2F#{CGI.escape(subProj)}"
            # Build a textEntityList for the subprojects
            subPrjEntityList = BRL::Genboree::REST::Data::TextEntityList.new()
            unless(subPrjObj.subProjects.nil? or subPrjObj.subProjects.empty?)
              subPrjObj.subProjects.each { |subSubProj|
                subPrjEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, subSubProj)
                subPrjEntity.makeRefsHash("#{refName}%2F#{Rack::Utils.escape(subSubProj)}")
                subPrjEntityList << subPrjEntity
              }
            end             
            entity = BRL::Genboree::REST::Data::DetailedProjectEntity.new(@connect, subProj, 'foo', subPrjEntityList )
            entity.makeRefsHash(refName)
            entityList << entity
          }
        end

        
      else
        
        entityList = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
        unless(subProjects.empty?)
          subProjects.each { |subProj|
            refName = "#{refsBase}%2F#{CGI.escape(subProj)}"
            entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, subProj)
            entity.setRefs(refName)
            entityList << entity
          }
        end
      end
      
      return entityList
    end
  end 
end ; end ; end # module BRL ; module REST ; module Resources
