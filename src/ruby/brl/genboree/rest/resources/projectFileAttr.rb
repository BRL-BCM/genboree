#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/attributesEntity'
require 'brl/genboree/rest/data/projectFileEntity'
require 'brl/genboree/rest/data/refsEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # DatabaseFileAttribute - exposes information about the custom links of a specific database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DatabaseFileEntity
  class ProjectFileAttribute < BRL::REST::Resources::GenboreeResource
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
      @projComponent = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/file/([^\?]+)/attribute(?:/([^\?]+))?(?:\?.*)?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8          # Allow more specific URI handlers involving databases etc within the database to match first
    end

    # Initialize the instance vars required for this request
    def initProjFile
      @statusName = initProjOperation()
      if(@statusName == :OK)
        @projComponent = nil
        @statusName = initProjectObj()
        if(@statusName == :OK)
          @attrName = Rack::Utils.unescape(@uriMatchData[4]) if(@uriMatchData[4])
          @fileName = @aspect
          @projComponent = @projectObj.filesComponent()
          nameStatus = BRL::Genboree::Abstract::Resources::FileManagement.validatePropertyValue('fileName', @fileName)
          if(nameStatus != :OK)
            @statusName = :'Bad Request'
            @statusMsg = nameStatus
          else
            @prjFile = @projComponent.findFileRecByFileName(@fileName)
            if(@prjFile.nil?)
              @statusName = :'Not Found'
              @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
            else
              @fileLabel = @prjFile['label']
              if(!@prjFile['attributes'].has_key?(@attrName) and @reqMethod != :put)
                @statusName = :'Not Found'
                @statusMsg = "NOT FOUND: The attribute name #{@attrName.inspect} could not be found for file #{@fileName.inspect} in project #{@projName.inspect} in user group #{@groupName.inspect}."
              end
            end
          end
        end
      end
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initProjFile()
      begin
        if(@statusName == :OK)
          respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @prjFile['attributes'][@attrName])
          if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
            @statusName = configResponse(respEntity)
          end
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get project file object from index. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      ensure
        @projComponent.clearIndexFile() if(@projComponent)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initProjFile()
      begin
        if(@statusName == :OK)
          infoHash = {}
          if(@prjFile['attributes'].has_key?(@attrName))
            # Attribute exists
            # Update the aspect specified, parse the reqBody for a TextEntity or an AttributesEntity
            reqEntity = parseRequestBodyForEntity(['AttributesEntity', 'TextEntity'])
            if(!reqEntity.nil? and reqEntity != :"Unsupported Media Type")
              if(reqEntity.is_a?(BRL::Genboree::REST::Data::AttributesEntity))
                # Could be a rename
                infoHash['attributes'] = reqEntity.attributes
                updateStatus = @prjFile.replaceFileAttribute(@fileLabel, @attrName, infoHash['attributes'])
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::TextEntity))
                infoHash['attributes'] = {@attrName => reqEntity.text}
                updateStatus = @projComponent.updateFileAttribute(@fileLabel, infoHash)
              end
            else
              @statusName, @statusMsg = :"Unsupported Media Type", "The request body for updating attribute #{@attrName.inspect} should be a TextEntity or an AttributesEntity"
            end
          else
            # Attribute doesn't exist yet - create it
            # Update the aspect specified, parse the reqBody for a TextEntity or an AttributesEntity
            reqEntity = parseRequestBodyForEntity(['AttributesEntity', 'TextEntity'])
            if(reqEntity != :"Unsupported Media Type")
              if(reqEntity.nil?)
                # Touch - Can create attribute with a nil value
                infoHash['attributes'] = {@attrName => nil}
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::AttributesEntity))
                # @attrName and the attributeName in the entity should match.
                infoHash['attributes'] = reqEntity.attributes
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::TextEntity))
                infoHash['attributes'] = {@attrName => reqEntity.text}
              end
              updateStatus = @projComponent.updateFileAttribute(@fileLabel, infoHash)
            else
              @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a TextEntity or an AttributesEntity"
            end
          end
          if(updateStatus == :OK)
            @prjFile = @projComponent.findFileRecByFileName(@fileName)
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, infoHash['attributes'])
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attribute has been updated.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName, @statusMsg = :"Bad Request", "There was a problem updating file attribute (#{updateStatus})"
          end
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get project file object from index. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      ensure
        @projComponent.clearIndexFile() if(@projComponent)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initProjFile()
      begin
        if(@statusName == :OK)
          deleteStatus = @projComponent.deleteFileAttribute(@fileLabel, @attrName)
          if(deleteStatus == :OK)
            @prjFile = @projComponent.findFileRecByFileName(@fileName)
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, {})
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attribute has been deleted.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName, @statusMsg = :"Bad Request", "There was a problem deleting file attribute (#{updateStatus})"
          end
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get project file object from index. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      ensure
        @projComponent.clearIndexFile() if(@projComponent)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class DatabaseFileAttribute
end ; end ; end # module BRL ; module REST ; module Resources
