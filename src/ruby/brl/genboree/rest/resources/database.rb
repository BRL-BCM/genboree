#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/databaseEntity'
require 'brl/genboree/rest/data/entrypointEntity'
require 'brl/genboree/abstract/resources/unlockedGroupResource'
require 'brl/genboree/databaseCreator'
require 'brl/cache/helpers/dnsCacheHelper'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++
  # Database - exposes information about a specific user database (database info, the entrypoints within, the track list).
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedDatabaseEntity
  # * BRL::Genboree::REST::Data::DetailedEntrypointEntity
  class Database < BRL::REST::Resources::GenboreeResource # <- resource classes must inherit and implement this interface
    include BRL::Cache::Helpers::DNSCacheHelper::CacheClassMethods
    include BRL::Genboree::REST::Data

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    RSRC_TYPE = 'database'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @refseqRow = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = @aspect = nil
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)(?:/([^/\?]+))?$}      # Look for /REST/v1/grp/{grp}/db/{db}/[aspect] URIs
    end

    def self.getPath(groupName, databaseName)
      path = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(groupName)}/db/#{Rack::Utils.escape(databaseName)}"
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@dbName: #{@dbName.inspect}")
        @aspect = (@uriMatchData[3].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[3])  # Could be nil, 'name', 'refSeqId', 'description', 'species', 'version', or 'description'
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      @statusName = initOperation()
      if(@statusName == :OK)
        setResponse()
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return initGroupAndDatabase()
    end

    # Check payload - The following request body options are allowed
    # empty - Allowed when creating an empty Db or one from a template (specified in URL parameter templateName)
    # DetailedDatabaseEntity - Create/Update Db details
    # RefEntity - Copying a database
    def processPayload()
      status = entity = nil
      reqBody = self.readAllReqBody()
      if(reqBody.empty?)
        status = :OK
        entity = nil
      else
        entity = BRL::Genboree::REST::Data::DetailedDatabaseEntity.deserialize(reqBody, @repFormat)
        if(entity == :'Unsupported Media Type')
          status = :'Unsupported Media Type'
          entity = BRL::Genboree::REST::Data::RefEntity.deserialize(reqBody, @repFormat)
          if(entity == :'Unsupported Media Type')
            status = :'Unsupported Media Type'
          else
            status = :OK
          end
        else
          status = :OK
        end
      end
      return status, entity
    end

    def prepareEntityForUpdate(dbEntity)
      updateData = {}
      updateData['refseqName'] = dbEntity.name
      updateData['refseq_species'] = dbEntity.species
      updateData['refseq_version'] = dbEntity.version
      updateData['description'] = dbEntity.description
      if(!dbEntity.public.nil?)
        updateData['public'] = dbEntity.public == true ? 1 : 0
      end
      return updateData
    end

    def put()
      initStatus = initOperation()
      if(@groupAccessStr == 'o')
        if(@aspect.nil?)  # then need full db info
          if (initStatus == :OK or initStatus == :'Not Found')
            @statusName, payload = processPayload()
          end
          if(initStatus == :OK and @refSeqId.to_i > 0) # Update
            updateDatabase(payload)
          elsif(initStatus == :'Not Found') # Create
            createDatabase(payload)
          end
          if(@statusName == :OK or @statusName == :'Moved Permanently' or @statusName == :Created)
            setResponse(@statusName)
          end
        else
          @statusName = :'Not Implemented'
          @statusMsg = "This operation has not been implemented."
        end
      else
        @statusName = :Forbidden
        @statusMsg = "You do not have sufficient permissions to perform this operation."
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def delete()
      initStatus = initOperation()
      if(@groupAccessStr == 'o')
        if(initStatus == :'Not Found')
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_DB: There is no database: #{@dbName.inspect} in Group: #{@groupName.inspect} to delete."
        else
          begin
            groupRecs = @dbu.selectGroupByName(@groupName)
            refseqRows = @dbu.selectRefseqByNameAndGroupId(@dbName, groupRecs.first['groupId'])
            refseqRow = refseqRows.first
            dbRecs = @dbu.selectRefseqById(@refSeqId)
            @fullDbName = dbRecs.first['databaseName']
            @dbu.setNewDataDb(@fullDbName)
            @dbu.dropDatabase(@fullDbName)
            @dbu.deleteGroupRefSeq(@groupId, @refSeqId)
            @dbu.deleteRefseqRecordByRefSeqId(@refSeqId)
            @dbu.deleteDatabase2HostRecByDatabaseName(@fullDbName)
            @dbu.deleteUnlockedResourceAndChildrenByUri(@rsrcURI)
            escDbDeleteCmd = CGI.escape("deleteDbFiles.rb #{@groupId} #{@refSeqId}")
            `genbTaskWrapper.rb --cmd=#{escDbDeleteCmd} -o /dev/null -e /dev/null`
            respEntity =  BRL::Genboree::REST::Data::DetailedDatabaseEntity.new(
                         @connect,
                         refseqRow["refseqName"],
                         refseqRow["refseq_species"],
                         refseqRow["refseq_version"],
                         refseqRow["description"],
                         refseqRow["refSeqId"]
                       )
            respEntity.setStatus(:OK, "DELETED: database #{@databaseName.inspect} in user group #{@groupName.inspect}.")
            @statusName = configResponse(respEntity)
          rescue => err
            @statusName = :'Internal Server Error'
            @statusMsg = "A problem was encountered while deleting one or more components of the database: #{@dbName} in group: #{@groupName}. The database WILL reqiure manual cleanup."
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error: #{err.message}\nBacktrace: #{err.backtrace.join("\n")}")
          end
        end
      else
        @statusName = :Forbidden
        @statusMsg = "You do not have sufficient permissions to perform this operation."
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def updateDatabase(payload)
      if(payload.is_a?(DetailedDatabaseEntity))
        # parse data from DetailedDatabaseEntity
        updateData = prepareEntityForUpdate(payload)
        @dbu.updateRefSeqById(@refSeqId, updateData)
        # If the name has been changed then we need to update the 'unlockedGroupResources' table as well with new @rsrcPath
        newDbName = ((payload.name.nil? or payload.name.empty?) ? @dbName : payload.name)
        rsrcPath = @rsrcPath.gsub("/db/#{CGI.escape(@dbName)}", "/db/#{CGI.escape(newDbName)}")
        @dbu.updateResourceUriAndDigestByNewResourceUri(@rsrcPath, rsrcPath) if(@dbName != newDbName)
        # See if gbKey is present in payload
        # Since this is an update, a gbKey could already be present. In such a case, update it, otherwise create it.
        if(!payload.gbKey.nil? and !payload.gbKey.empty?)
          gbKey = payload.gbKey
          rows = @dbu.selectUnlockedResourcesByUri(rsrcPath)
          if(!rows.nil? and !rows.empty?) # update
            @dbu.updateGroupResourceById(rows.first['id'], gbKey)
          else # insert
            @dbu.insertUnlockedGroupResource(@groupId, 'database', @refSeqId, gbKey, @rsrcURI.gsub("/db/#{CGI.escape(@dbName)}", "/db/#{CGI.escape(newDbName)}"), false)
          end
        end
        @dbName = payload.name
        @statusName = :'Moved Permanently'
      else
        @statusName = :Conflict
        @statusMsg = "A database with the name #{@dbName} already exists.  If you are trying to update the database, the request body can not be empty."
      end
    end

    def createDatabase(payload)
      # Create the database for the group using a template Id
      # templateName is specified as a url parameter
      templateName = @nvPairs['templateName']
      if(!templateName.nil? and !templateName.empty?)
        # Get the templateId
        templateRow = @dbu.selectTemplateByName(Rack::Utils.unescape(templateName))
        if(!templateRow.nil? and !templateRow.empty?)
          templateId = templateRow.first['genomeTemplate_id']
          dbc = BRL::Genboree::DatabaseCreator.new(@userId, @groupId, @dbName)
          if(payload.is_a?(DetailedDatabaseEntity))
            exitStatus = dbc.createDbFromTemplate(templateId, payload.version, payload.species, payload.description)
            # If exitstatus is 0 and entity has public=true or a gbKey in the payload
            if(exitStatus == 0)
              dbRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, @groupId)
              if(!payload.public.nil? and payload.public == true)
                @dbu.publishDatabase(dbRecs.first['refSeqId'])
              end
              if(!payload.gbKey.nil? and !payload.gbKey.empty?)
                @dbu.insertUnlockedGroupResource(@groupId, 'database', dbRecs.first['refSeqId'], payload.gbKey, @rsrcURI, false)
              end
            end
          else
            exitStatus = dbc.createDbFromTemplate(templateId)
          end
          if(exitStatus == 0)
            @statusName = :Created
          else
            @statusName = :Fatal
            @statusMsg = "DatabaseCreator failed with exit status [#{exitStatus}]"
          end
        else
          @statusName = :'Bad Request'
          @statusMsg = "The template specified '#{templateName}' could not be found.  Database not created."
        end
      else
        # Create an empty database or create a new Db copying the database specified in the RefEntity
        if(payload.nil? or payload.is_a?(DetailedDatabaseEntity))
          # Create an empty Db
          dbc = BRL::Genboree::DatabaseCreator.new(@userId, @groupId, @dbName)
          if(payload.is_a?(DetailedDatabaseEntity))
            exitStatus = dbc.createEmptyDb(payload.description, payload.version, payload.species)
          else
            exitStatus = dbc.createEmptyDb()
          end
          if(exitStatus == 0)
            @statusName = :Created
          else
            @statusName = :Fatal
            @statusMsg = "DatabaseCreator failed with exit status [#{exitStatus}]"
          end
          if(payload.is_a?(DetailedDatabaseEntity))
            updateData = prepareEntityForUpdate(payload)
            @dbu.updateRefSeqById(@refSeqId, updateData)
          end
          @statusName = :Created
        elsif(payload.is_a?(RefEntity))
          @statusName = :'Not Implemented'
        end
      end
    end

    # This method sets the response of the resource
    # Requires that @groupName, @dbName are set
    ASPECT2COLNAME =
    {
      "refSeqId"    => "refSeqId",
      "name"        => "refseqName",
      "species"     => "refseq_species",
      "version"     => "refseq_version",
      "description" => "description",
      "isPublic"    => "public"
    }

    def setResponse(statusName=:OK, statusMsg=nil)
      refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}")
      groupRecs = @dbu.selectGroupByName(@groupName)
      refseqRows = @dbu.selectRefseqByNameAndGroupId(@dbName, groupRecs.first['groupId'])
      refseqRow = refseqRows.first
      if(@aspect.nil?)  # then need full db info
        dbEntity =  BRL::Genboree::REST::Data::DetailedDatabaseEntity.new(
                      @connect,
                      refseqRow["refseqName"],
                      refseqRow["refseq_species"],
                      refseqRow["refseq_version"],
                      refseqRow["description"],
                      refseqRow["refSeqId"]
                    )
        # Get entrypoints in the user database
        frefRows = getFrefRows(refseqRow["databaseName"])
        dbEntity.entrypoints.count = frefRows.size unless(frefRows.nil?)
        if(!frefRows.nil? and !frefRows.empty?)
          frefRows.each { |row|
            refname = row['refname']
            entity = BRL::Genboree::REST::Data::DetailedEntrypointEntity.new(@connect, refname, row['rlength'])
            # connect entity to more detailed info
            entity.makeRefsHash("#{refBase}/ep/#{Rack::Utils.escape(refname)}")
            dbEntity.entrypoints << entity
          }
          frefRows.clear() if(frefRows)
        end
        # Add gbKey if available for this database
        #unlockedResourcesRows = @dbu.selectUnlockKeyByResource(@groupId, 'database', @refSeqId)
        unlockedResourcesRows = @dbu.selectUnlockedResourcesByUri(@rsrcPath)
        if(unlockedResourcesRows and !unlockedResourcesRows.empty?)
          gbKey = unlockedResourcesRows.first['unlockKey']
          dbEntity.gbKey = gbKey
        end
        # Add public = true or false
        dbEntity.public = @dbu.isRefseqPublic(refseqRow['refSeqId'])
      else  # some simple aspect requested
        if(!ASPECT2COLNAME[@aspect].nil?)
          ref = "#{refBase}/#{Rack::Utils.escape(@aspect)}"
          dbEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, refseqRow[ASPECT2COLNAME[@aspect]])
          dbEntity.makeRefsHash(ref)
          dbEntity.setStatus(statusName, statusMsg)
          @statusName = configResponse(dbEntity)
          @resp['Location'] = ref
        else
          @statusName = :'Not Found'
          @statusMsg = "Unknown aspect #{@aspect}"
        end
      end
      if(dbEntity)
        @statusName = configResponse(dbEntity, statusName)
      end
    end

  end # class Database
end ; end ; end # module BRL ; module REST ; module Resources
