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
  class DatabaseFileAttributes < BRL::REST::Resources::GenboreeResource
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
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
      @databaseObj = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/file/([^\?]+)/attributes(?:\?.*)?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8          # Allow more specific URI handlers involving databases etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @dbFilesObj = nil
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])
        @subDirs = Rack::Utils.unescape(@uriMatchData[3])[0..-1]
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          @fileRecs = @dbu.selectFileByDigest(@fileName, true)
          # It may be an implicit folder if it returned empty.
          if(@fileRecs.nil? or @fileRecs.empty?)
            childRecs = @dbu.selectChildrenFilesAndFolders(@subDirs, 'immediate', false)
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
          if(!@fileRecs.nil? and !@fileRecs.empty?)
            fileRec = @fileRecs[0]
            attributes = {}
            attributeRecs = @dbu.selectFileAttrNamesAndValuesByFileId(fileRec['id'])
            if(!attributeRecs.nil? and !attributeRecs.empty?)
              attributeRecs.each { |rec|
                attributes[rec['name']] = rec['value']
              }
            end
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, attributes)
            if(!respEntity.nil? and respEntity != :'Unsupported Media Type')
              @statusName = configResponse(respEntity)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get record for file: #{@fileName.inspect}. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
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
          # Add the attributes, parse the reqBody for a TextEntity
          reqEntity = parseRequestBodyForEntity(['AttributesEntity'])
          if(!reqEntity.nil? and reqEntity != :"Unsupported Media Type")
            fileRec = @fileRecs[0]
            attributes = reqEntity.attributes
            attrNameRecs = []
            attrValueRecs = []
            attrValueArray = []
            attributes.each_key { |attrName|
              attrNameRecs << [attrName, 0]
              attrValueRecs << [attributes[attrName], 0]
              attrValueArray << attributes[attrName]
            }
            # Insert on duplicate is enabled
            @dbu.insertFileAttrNames(attrNameRecs, attrNameRecs.size)
            @dbu.insertFileAttrValues(attrValueRecs, attrValueRecs.size)
            # Get the list of attr names and values which we just inserted
            attrNames = @dbu.selectFileAttrNamesByNames(attributes.keys)
            attrValues = @dbu.selectFileAttrValueByValues(attrValueArray)
            attrNameIdHash = {}
            attrNames.each { |rec|
              attrNameIdHash[rec['name']] = rec['id']
            }
            attrValueIdHash = {}
            attrValues.each { |rec|
              attrValueIdHash[rec['value']] = rec['id']
            }
            fileUpdateRecs = []
            fileId = fileRec['id']
            attributes.each_key { |attrName|
              attrValue = attributes[attrName]
              fileUpdateRecs << [fileId, attrNameIdHash[attrName], attrValueIdHash[attrValue]]
            }
            @dbu.insertFile2Attributes(fileUpdateRecs, fileUpdateRecs.size, dupKeyUpdateCol='fileAttrValue_id')
            attributes = {}
            attributeRecs = @dbu.selectFileAttrNamesAndValuesByFileId(fileRec['id'])
            if(!attributeRecs.nil? and !attributeRecs.empty?)
              attributeRecs.each { |rec|
                attributes[rec['name']] = rec['value']
              }
            end
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, attributes)
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attributes have been updated.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName, @statusMsg = :"Unsupported Media Type", "The request body should be a AttributesEntity"
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not put attributes for file: #{@fileName.inspect}. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      ensure
        @dbFilesObj.clearIndexFile() if(@dbFilesObj)
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
          if(!@fileRecs.nil? and !@fileRecs.empty?)
            deletedRecs = @dbu.deleteFile2AttributesByFileIdAndAttrNameId(@fileRecs[0]['id'])
            respEntity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, {})
            if(respEntity != :'Unsupported Media Type')
              respEntity.setStatus(:OK, "The file attributes have been deleted.")
              @statusName = configResponse(respEntity)
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file name #{@fileName.inspect} could not be found for database #{@dbName.inspect} in user group #{@groupName.inspect}."
          end
        else
          @statusName = initStatus
        end
      rescue Exception => err
        @statusMsg = "FATAL: could not get file object from index. Message: #{err}\n#{err.backtrace.join("\n")}"
        @statusName = :'Internal Server Error'
        $stderr.puts @statusMsg
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class DatabaseFileAttributes
end ; end ; end # module BRL ; module REST ; module Resources
