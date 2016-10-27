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

  # ProjectFile - exposes information about the custom links of a specific project.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ProjectFileEntity
  class ProjectFile < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'projectFile'

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/file/([^/\?]+)}       # Look for /REST/v1/group/{grp}/prj/{prj} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving projects etc within the database to match first
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
          end
        end
      end
    end

    # Uses same approach as database files (see REST::Resources::DatabaseFileAspect)
    def setFilesInfo()
      if(@projComponent.nil?)
        @projComponent = BRL::Genboree::Abstract::Resources::ProjectFiles.new(@groupName, @projComponent.prohName)
        @projComponent.rackEnv = @rackEnv
        @projComponent.suppressEmail = @suppressEmail
      end
      @prjFile = @projComponent.findFileRecByFileName(@fileName)
    end

    def releaseFilesInfo()
      @prjFile = nil
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initProjFile()
      if(@statusName == :OK)
        begin
          # Create Abstract files object
          setFilesInfo()
          if(!@prjFile.nil?)
            respEntity = BRL::Genboree::REST::Data::ProjectFileEntity.deserialize(@prjFile.to_json, :JSON)
            if(respEntity != :'Unsupported Media Type')
              @statusName = configResponse(respEntity)
            else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: Could not read and parse file for project #{@projName.inspect} in user group #{@groupName.inspect}."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          $stderr.puts err
        ensure
          releaseFilesInfo()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initProjFile()
      if(@statusName == :OK)
        begin
          # Create Abstract files object
          setFilesInfo()
          if(!@prjFile.nil?)
            @fileLabel = @prjFile['label']
          else
            @fileLabel = @fileName
          end
          if(!@prjFile.nil? and @req.body.is_a?(StringIO) and @req.body.string.empty?)
            @statusName, @statusMsg = :'Bad Request', "The file already exists so it can not be created and the request body is empty so it can not be updated."
          elsif(@statusName == :OK)
            reqEntity = parseRequestBodyForEntity(['ProjectFileEntity'])
            if(reqEntity == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = 'Unacceptable format.  Request body must be a ProjectFileEntity.  If you are trying to upload the file, PUT to the API resource /grp/<grp>/prj/<prj>/file/<fileName>/data'
            else
              # 'Touch' the file if it doesn't exist yet
              @projComponent.writeProjectFile(@fileName, StringIO.new(''), @context) if(@prjFile.nil?)
              if(!reqEntity.nil?)
                infoHash = {}
                BRL::Genboree::Abstract::Resources::FileManagement::EDITABLE_INDEX_FIELDS.each { |infoField|
                  infoHash[infoField] = reqEntity.send(infoField)
                }
                @projComponent.updateProjectFileInfo(@fileLabel, infoHash, @context)
              end
              @prjFile = @projComponent.findFileRecByFileName(@fileName)
              respEntity = BRL::Genboree::REST::Data::ProjectFileEntity.deserialize(@prjFile.to_json, :JSON)
              if(respEntity != :'Unsupported Media Type')
                respEntity.setStatus(:OK, "UPDATED: Project #{@projName.inspect}, file: #{@fileLabel.inspect} successfully updated.")
                @statusName = configResponse(respEntity)
              end
            end
          end
        rescue Exception => err
          $stderr.puts "FATAL ERROR: #{err}"
          $stderr.puts err.backtrace.join("\n")
          @statusName = :'Internal Server Error'
          @statusMsg = "FATAL ERROR: could not put your file on the server do to an internal processing error. The error was logged; please contact #{@genbConf.gbTechEmail} with this information."
        ensure
          releaseFilesInfo()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initProjFile()
      if(@statusName == :OK)
        begin
          # Create Abstract files object
          setFilesInfo()
          if(!@prjFile.nil?)
            @fileLabel = @prjFile['label']
            indexFileRec = @prjFile.deep_clone
            # Delete the file
            # - need to release lock before actual delete b/c can take a long time
            releaseFilesInfo()
            @statusName = @projComponent.deleteProjectFile(@fileLabel, @context)
            @statusMsg = "DELETED: Project file #{@fileName.inspect} successfully deleted from project #{@projName.inspect} in user group #{@groupName.inspect}." if(@statusName == :OK)
            if(@statusName == :OK)
              respEntity = BRL::Genboree::REST::Data::DatabaseFileEntity.deserialize(indexFileRec.to_json, :JSON)
              if(respEntity != :'Unsupported Media Type')
                respEntity.setStatus(:OK, "DELETED: #{@fileName.inspect} from project #{@projName.inspect} in user group #{@groupName.inspect}.")
                @statusName = configResponse(respEntity)
              end
            else # :Unsupported Media Type # <-- bad format indicated, bad representation given, or possible server error
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: Could not delete file: #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          $stderr.puts "ERROR: #{File.basename(__FILE__)}##{__method__} => #{err}\n#{err.backtrace.join("\n")}"
        ensure
          releaseFilesInfo()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError()
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS
    #------------------------------------------------------------------

  end # class ProjectFile
end ; end ; end # module BRL ; module REST ; module Resources
