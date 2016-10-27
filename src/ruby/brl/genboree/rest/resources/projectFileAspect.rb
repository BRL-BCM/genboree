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

  # ProjectFileAspect - exposes information about the custom links of a specific project.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ProjectFileEntity
  class ProjectFileAspect < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'projectFileAspect'

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/file/([^/\?]+)/([^/\?]+)}       # Look for /REST/v1/group/{grp}/prj/{prj} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    # Initialize the instance vars required for this request
    def initProjFile
      @statusName = initProjOperation()
      if(@statusName == :OK)
        @statusName = initProjectObj()
        if(@statusName == :OK)
          @fileName = @aspect
          @fileProperty = @aspectProperty
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
          if(@fileProperty == 'data')
            # Create Abstract files object
            setFilesInfo()
            if(!@prjFile.nil? and !@prjFile.empty?)
              # Serve the file
              fullFilePath = @projComponent.filesDir.path + '/' + @prjFile['fileName']
              # Release files object (release lock on index file while serving actual data)
              releaseFilesInfo()
              file = File.open(fullFilePath, 'r')
              @resp.body = file
              @resp.status = HTTP_STATUS_NAMES[:OK]
              @resp['Content-Type'] = 'application/octet-stream'
            else
              @statusName = :'Not Found'
              @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
            end
          elsif(BRL::Genboree::Abstract::Resources::FileManagement::EDITABLE_INDEX_FIELDS.include?(@fileProperty))
            # Create Abstract files object
            setFilesInfo()
            respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @prjFile[@fileProperty])
          else
            @statusName, @statusMsg = :"Bad Request", "The aspect #{@fileProperty.inspect} is not a valid aspect."
          end
          if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
            @statusName = configResponse(respEntity)
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
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
          # If the file does not exist, return Not Found, except for the 'data' aspect as it is used to create files.
          if(@prjFile.nil? and @fileProperty != 'data')
            @statusName, @statusMsg = :"Not Found", "The file #{@fileName.inspect} count not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
          else
            if(@fileProperty == 'data')
              # Release prjFile info while writing possibly large file (don't hold locks for big write)
              #indexFileRec = @dbFileHash.deep_clone # If new file, this will be nil; else will be existing file record
              releaseFilesInfo()
              # Request body should be the file contents
              initStatus = @projComponent.writeProjectFile(@fileName, @req.body, @context, true)
              if(initStatus == :Accepted) # If files large, their uploads are accepted pretty quickly but data may not appear right away
                # Will be updating @projComponent (project files) info
                setFilesInfo()
                # File may or may not be in place; e.g. not yet if upload is in progress
                if(@projFile.nil?) # Then new file not appearing on disk yet and no new record found. Empty response.
                  respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, :Accepted, msg="ACCEPTED: Upload of raw data to Project #{@projName.inspect}, file: #{@fileName.inspect}, accepted. Final storage of file may be ongoing.")
                  @statusMsg = respEntity.msg
                else # We have a record for the new file.
                  # Try to return full file properties in the response
                  respEntity = BRL::Genboree::REST::Data::ProjectFileEntity.deserialize(@prjFile.to_json, :JSON)
                  if(respEntity != :'Unsupported Media Type')
                    respEntity.setStatus(:Accepted, "ACCEPTED: Upload of raw data to Project #{@projName.inspect}, file: #{@fileName.inspect}, accepted. Final storage of file may be ongoing.")
                    @statusName = configResponse(respEntity, :Accepted)
                    @statusMsg = respEntity.msg
                  else
                    @statusName, @statusMsg = :"Internal Server Error", "FATAL: Internal error parsing file index record to prepare response. "
                  end
                end
              else
                @statusName, @statusMsg = :"Bad Request", "There was a problem uploading the file (status: #{initStatus})"
              end
            elsif(!@prjFile.nil? and BRL::Genboree::Abstract::Resources::FileManagement::EDITABLE_INDEX_FIELDS.include?(@fileProperty))
              @fileLabel = @prjFile['label']
              infoHash = {}
              # Update the aspect specified, parse the reqBody for a TextEntity
              reqEntity = parseRequestBodyForEntity(['TextEntity'])
              if(reqEntity != :"Unsupported Media Type")
                validationStatus = BRL::Genboree::Abstract::Resources::FileManagement.validatePropertyValue(@fileProperty, reqEntity.text)
                if(validationStatus != :OK)
                  @statusName, @statusMsg = :"Bad Request", "The value for aspect #{@fileProperty.inspect} is invalid (#{validationStatus})."
                else
                  if(reqEntity.text.nil?)
                    @statusName, @statusMsg = :"Bad Request", "The aspect request body cannot be nil."
                  else
                    infoHash[@fileProperty] = reqEntity.text
                    # update the file property
                    updateStatus = @projComponent.updateProjectFileInfo(@fileLabel, infoHash, @context)
                    if(updateStatus == :OK)
                      @fileName = reqEntity.text if(@fileProperty == 'fileName')
                      @prjFile = @projComponent.findFileRecByFileName(@fileName)
                      respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @prjFile[@fileProperty])
                      if(respEntity != :'Unsupported Media Type')
                        respEntity.setStatus(:OK, "The file property #{@fileProperty.inspect} has been updated.")
                        @statusName = configResponse(respEntity)
                      end
                    else
                      @statusName, @statusMsg = :"Bad Request", "There was a problem updating '#{@fileProperty}' to '#{reqEntity.text}' (#{updateStatus})"
                    end
                  end
                end
              else
                @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a TextEntity"
              end
            else
              @statusName, @statusMsg = :"Bad Request", "The aspect #{@fileProperty.inspect} is not a valid aspect."
            end
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
        ensure
          releaseFilesInfo()
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK or @statusName != :Accepted)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initProjFile()
      if(!@prjFile.nil?)
        @fileLabel = @prjFile['label']
        # Can only delete description
        deleteableAspects = {'description' => true}
        if(deleteableAspects[@fileProperty])
          infoHash = {@fileProperty => ''}
          @projComponent.updateProjectFileInfo(@fileLabel, infoHash, @context)
          @prjFile = @projComponent.findFileRecByFileName(@fileName)
          respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, @prjFile[@fileProperty])
          if(respEntity != :'Unsupported Media Type')
            respEntity.setStatus(:OK, "The file property #{@fileProperty.inspect} has been deleted.")
            @statusName = configResponse(respEntity)
          end
        else
          @statusName = :'Method Not Allowed'
          @statusMsg = "NOT ALLOWED: Delete is not allowed for the aspect #{@fileProperty.inspect}."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for project #{@projName.inspect} in user group #{@groupName.inspect}."
      end
      # If something wasn't right, represent as error
      @resp = representError()
      return @resp
    end
  end # class ProjectFileAspect
end ; end ; end # module BRL ; module REST ; module Resources
