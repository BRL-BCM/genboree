#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/attributesEntity'
require 'brl/genboree/rest/data/databaseFileEntity'
require 'brl/genboree/rest/data/refsEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # DatabaseFileAttributes - exposes information about the custom links of a specific database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DatabaseFileEntity
  class ProjectFileAttributes < BRL::REST::Resources::GenboreeResource
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/file/([^\?]+)/attributes(?:\?.*)?$}
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
        @statusName = initProjectObj()
        if(@statusName == :OK)
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
          if(!@prjFile.nil?)
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, @prjFile['attributes'])
            if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
              @statusName = configResponse(respEntity)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
          end
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get project file object from index. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      ensure # Ensure index file gets unlocked
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
          @fileLabel = @prjFile['label']
          infoHash = {}
          # Update the aspect specified, parse the reqBody for a TextEntity
          reqEntity = parseRequestBodyForEntity(['AttributesEntity'])
          if(!reqEntity.nil? and reqEntity != :"Unsupported Media Type")
            infoHash['attributes'] = reqEntity.attributes
            # update the file property
            pp @fileLabel
            pp infoHash
            updateStatus = @projComponent.updateFileInfo(@fileLabel, infoHash)
            if(updateStatus == :OK)
              @prjFile = @projComponent.findFileRecByFileName(@fileName)
              respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, @prjFile['attributes'])
              if(respEntity != :'Unsupported Media Type')
                respEntity.setStatus(:OK, "The file attributes have been updated.")
                @statusName = configResponse(respEntity)
              end
            else
              @statusName, @statusMsg = :"Bad Request", "There was a problem updating file attributes (#{updateStatus})"
            end
          else
            @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a TextEntity"
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
          if(!@prjFile.nil?)
            @fileLabel = @prjFile['label']
            infoHash = {'attributes' => {}}
            @projComponent.updateFileInfo(@fileLabel, infoHash)
            @prjFile = @projComponent.findFileRecByFileName(@fileName)
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, @prjFile['attributes'])
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attributes have been deleted.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
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
  end # class DatabaseFileAttributes
end ; end ; end # module BRL ; module REST ; module Resources
