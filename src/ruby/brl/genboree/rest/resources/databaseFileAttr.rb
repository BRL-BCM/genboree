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

  # DatabaseFileAttribute - exposes information about the custom links of a specific database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DatabaseFileEntity
  class DatabaseFileAttribute < BRL::REST::Resources::GenboreeResource
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'databaseFileAttr'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @databaseObj = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/file/([^\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8          # Allow more specific URI handlers involving databases etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @dbFilesObj = nil
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])
        @subDirs = Rack::Utils.unescape(@uriMatchData[3])[0..-1]
        @attrName = nil
        @attrName = Rack::Utils.unescape(@uriMatchData[4])
        @aspect = (@uriMatchData[5] ? Rack::Utils.unescape(@uriMatchData[5]).strip : 'value') # currently the pattern nor code support any other attribute aspects other than value
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          @fileRecs = @dbu.selectFileByDigest(@fileName, true)
          # It may be an implicit folder if it returned empty.
          if(@fileRecs.nil? or @fileRecs.empty?)
            childRecs = @dbu.selectChildrenFilesAndFolders(@subDirs, 'immediate', false, true)
            if(!childRecs.nil? and !childRecs.empty?) # yes, the folder is an implicit entry
              # Enter a record for this implicit folder
              groupRecs = @dbu.selectGroupByName(@groupName)
              groupId = groupRecs.first['groupId']
              refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, groupId)
              @grpDbFileBase = BRL::Genboree::Abstract::Resources::DatabaseFiles.buildFileBase(groupId, refseqRecs.first['refSeqId'])
              FileUtils.mkdir_p(@grpDbFileBase)
              @filesDir = Dir.new(@grpDbFileBase)
              `mkdir -p #{@grpDbFileBase}/#{File.makeSafePath(@fileName)}`
              fileName = "#{@fileName}/"
              @dbu.insertFile(fileName, fileName, nil, 0, 0, Time.now(), Time.now(), @userId)
              @fileRecs = @dbu.selectFileByDigest(fileName)
            end
          end
          if(@fileRecs.nil? or @fileRecs.empty?)
            initStatus = :'Not Found'
            @statusMsg = "NOT FOUND: The file #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          else
            attrRecs = @dbu.selectFileAttrNameByName(@attrName)
            if( ( attrRecs.nil? or attrRecs.empty? ) and @reqMethod != :put)
              initStatus = :'Not Found'
              @statusMsg = "NOT FOUND: The attribute name #{@attrName.inspect} could not be found for file #{@fileName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}."
            end
          end
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      begin
        if(initStatus == :OK)
          if(!@attrName.nil?)
            attrValueRecs = @dbu.getAttrValueByAttrNameAndFileId(@fileRecs[0]['id'], @attrName)
            if(attrValueRecs and !attrValueRecs.empty?) # we found some value
              respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, attrValueRecs[0]['value'])
              if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
                @statusName = configResponse(respEntity)
              end
            else
              initStatus = :'Not Found'
              @statusMsg = "NOT FOUND: The attribute name #{@attrName.inspect} could not be found for file #{@fileName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}."
            end
          else
            initStatus = :'Bad request'
            @statusMsg = "BAD REQUEST: No Attribute name provided."
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get value for attr name: #{@attrName.inspect} for file: #{@fileName.inspect}. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
      @statusName = initStatus
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. This method performs differently depending on the request
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      begin
        if(initStatus == :OK)
          infoHash = {}
          attrRecs = @dbu.selectFileAttrNamesAndValuesByFileId(@fileRecs[0]['id'])
          attributes = {}
          attrRecs.each { |attr|
            attributes[attr['name']] = attr['value']
          }
          if(attributes.has_key?(@attrName))
            # Attribute exists
            # Update the aspect specified, parse the reqBody for a TextEntity or an AttributesEntity
            reqEntity = parseRequestBodyForEntity(['AttributesEntity', 'TextEntity'])
            if(!reqEntity.nil? and reqEntity != :"Unsupported Media Type")
              if(reqEntity.is_a?(BRL::Genboree::REST::Data::AttributesEntity))
                # Could be a rename
                reqAttributes = reqEntity.attributes
                if(reqAttributes.keys.size > 1)
                  initStatus = :'Bad request'
                  @statusMsg = "BAD REQUEST: Too many attribute key value pairs provided for renaming attribute: #{@attrName.inspect}."
                else
                  # Insert the new attribute name and values
                  newAttrName = reqAttributes.keys[0]
                  newAttrValue = reqAttributes[newAttrName]
                  @dbu.insertFileAttrName(newAttrName)
                  attrRecs = @dbu.selectFileAttrNameByName(newAttrName)
                  attrNameId = attrRecs[0]['id']
                  @dbu.insertFileAttrValue(newAttrValue)
                  attrValueRecs = @dbu.selectFileAttrValueByValue(newAttrValue)
                  attrValueId = attrValueRecs[0]['id']
                  @dbu.deleteFile2AttributesByFileIdAndAttrNameId(@fileRecs[0]['id'], @dbu.selectFileAttrNameByName(@attrName)[0]['id'])
                  updatedRecs = @dbu.insertFile2Attribute(@fileRecs[0]['id'], attrNameId, attrValueId)
                  if(updatedRecs != 0)
                    updateStatus = :OK
                  end
                end
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::TextEntity)) # Just replace the value for the requested attribute name
                attrValue = reqEntity.text
                attrRecs = @dbu.selectFileAttrNameByName(@attrName)
                attrNameId = attrRecs[0]['id']
                @dbu.insertFileAttrValue(attrValue)
                attrValueRecs = @dbu.selectFileAttrValueByValue(attrValue)
                attrValueId = attrValueRecs[0]['id']
                updatedRecs = @dbu.updateFile2AttributeForFileAndAttrName(@fileRecs[0]['id'], attrNameId, attrValueId)
                if(updatedRecs != 0)
                  updateStatus = :OK
                end
              end
            else
              @statusName, @statusMsg = :"Unsupported Media Type", "The request body for updating attribute #{@attrName.inspect} should be a TextEntity or an AttributesEntity"
            end
          else
            # Attribute doesn't exist yet - create it
            # Update the aspect specified, parse the reqBody for a TextEntity or an AttributesEntity
            reqEntity = parseRequestBodyForEntity(['AttributesEntity', 'TextEntity'])
            if(reqEntity != :"Unsupported Media Type")
              attrValue = ""
              if(reqEntity.nil?)
                # Touch - Can create attribute with a nil value; Sameer: for inserting as a db record, the value will be "" (empty string) since the table will not accept a NULL for 'value'
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::AttributesEntity))
                reqAttributes = reqEntity.attributes
                if(reqAttributes.keys.size > 1)
                  initStatus = :'Bad request'
                  @statusMsg = "BAD REQUEST: Too many attribute key value pairs provided for creating attribute-value pair for: #{@attrName.inspect}."
                else
                  attrName = reqAttributes.keys[0]
                  # @attrName and the attrName in the entity should match.
                  if(attrName != @attrName)
                    initStatus = :'Bad request'
                    @statusMsg = "BAD REQUEST: Attribute name in the URL: #{@attrName.inspect} does not match Attribute name in payload: #{attrName.inspect}."
                  end
                end
                attrValue = reqAttributes[attrName]
              elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::TextEntity))
                attrValue = reqEntity.text
              else
                # Do nothing
              end
              @dbu.insertFileAttrName(@attrName)
              attrRecs = @dbu.selectFileAttrNameByName(@attrName)
              attrNameId = attrRecs[0]['id']
              @dbu.insertFileAttrValue(attrValue)
              attrValueRecs = @dbu.selectFileAttrValueByValue(attrValue)
              attrValueId = attrValueRecs[0]['id']
              updatedRecs = @dbu.updateFile2AttributeForFileAndAttrName(@fileRecs[0]['id'], attrNameId, attrValueId)
              if(updatedRecs != 0)
                updateStatus = :OK
              end
            else
              @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a TextEntity or an AttributesEntity"
            end
          end
          if(updateStatus == :OK)
            @fileRecs = @dbu.selectFileByDigest(@fileName)
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, {})
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attribute has been updated.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName, @statusMsg = :"Bad Request", "There was a problem updating file attribute (#{updateStatus})"
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not put data for file: #{@fileName.inspect}. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      begin
        if(initStatus == :OK)
          if(!@attrName.nil?)
            attrNameRecs = @dbu.selectFileAttrNameByName(@attrName)
            deletedRecs = @dbu.deleteFile2AttributesByFileIdAndAttrNameId(@fileRecs[0]['id'], attrNameRecs[0]['id'])
            if(deletedRecs != 0)
              respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, {})
              if(respEntity != :'Unsupported Media Type')
                respEntity.setStatus(:OK, "The file attribute has been deleted.")
                @statusName = configResponse(respEntity)
              end
            else
              @statusName, @statusMsg = :"Bad Request", "There was a problem deleting file attribute (#{@attrName.inspect})"
            end
          else
            @statusName, @statusMsg = :"Bad Request", "No Attribute name provided for deleting. "
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not delete file: #{@fileName.inspect} from database. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class DatabaseFileAttribute
end ; end ; end # module BRL ; module REST ; module Resources
