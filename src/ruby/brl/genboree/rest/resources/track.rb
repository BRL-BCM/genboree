#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/trackEntity'
require 'brl/genboree/rest/data/trackLinkEntity'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/tracks'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  # Track - exposes information about a specific tracks.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::DetailedTrackEntityList
  class Track < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true } # TODO: implement a PUT for creating new [empty] track and for renaming tracks

    ASPECT_PERMISSIONS = {
      # permissions for the root resource - track
      '/' => PERMISSIONS_R_GET_ONLY,

      'color' => PERMISSIONS_ALL_ACCESS,
      'style' => PERMISSIONS_ALL_ACCESS,
      'rank' => PERMISSIONS_ALL_ACCESS,
      'display' => PERMISSIONS_ALL_ACCESS,

      'defaultColor' => PERMISSIONS_RW_GET_ONLY,
      'defaultStyle' => PERMISSIONS_RW_GET_ONLY,
      'defaultRank' => PERMISSIONS_RW_GET_ONLY,
      'defaultDisplay' => PERMISSIONS_RW_GET_ONLY,
      'queryable' => PERMISSIONS_RW_GET_ONLY,

      'url' => PERMISSIONS_R_GET_ONLY,
      'urlLabel' => PERMISSIONS_R_GET_ONLY,
      'description' => PERMISSIONS_R_GET_ONLY,
      'links' => PERMISSIONS_R_GET_ONLY,

      'templateUrl' => PERMISSIONS_ALL_READ_ONLY,
      'templateUrlLabel' => PERMISSIONS_ALL_READ_ONLY,
      'templateDescription' => PERMISSIONS_ALL_READ_ONLY,
      'templateLinks' => PERMISSIONS_ALL_READ_ONLY,

      # PUT/DELETE aren't implemented for these yet
      'attributes' => PERMISSIONS_R_GET_ONLY,
      'annoAttributes' => PERMISSIONS_R_GET_ONLY,
      'classes' => PERMISSIONS_R_GET_ONLY,
      'eps' => PERMISSIONS_R_GET_ONLY
    }
    # Admin Aspects require administrator role to perform PUT or DELETE operations
    ADMIN_ASPECTS = {'defaultColor' => true, 'defaultStyle' => true, 'defaultDisplay' => true, 'defaultRank' => true, 'links' => true}
    # Template aspects are only available for GET not PUT or DELETE
    TEMPLATE_ASPECTS = {'templateLinks' => true, 'templateDescription' => true, 'templateUrl' => true, 'templateUrlLabel' => true, 'queryable' => true, 'eps' => true}

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @ftypeHash.clear() if(@ftypeHash)
      @ftypeHash = @refseqRow = @trackName = @aspect = @aspectObj = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
      @noGrpOrNoDb = false
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)(?:/([^/\?]+))?</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)(?:$|/([^/\?]+)$)}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/[aspect] URIs
    end

    def self.getPath(groupName, databaseName, trackName, aspect=nil)
      path = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(groupName)}/db/#{Rack::Utils.escape(databaseName)}/trk/#{Rack::Utils.escape(trackName)}"
      path += "/#{Rack::Utils.escape(aspect)}" if(!aspect.nil?)
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip
      @aspect = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])  # Could be nil, 'classes', 'attributes', or 'description'
      @addDefaultClass = true
      @addDefaultClass = false if(@nvPairs['addDefaultClass'] and @nvPairs['addDefaultClass'] == 'false')
      if(initStatus == :OK)
        @ftypeHash = nil
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          unless(@trackName.index(":").nil?)
            aspectIndex = (@aspect.nil?) ? '/' : @aspect # Look for the 'root' resource (Track) if there is no aspect provided.
            if(!ASPECT_PERMISSIONS[aspectIndex].nil?)
              if(!ASPECT_PERMISSIONS[aspectIndex][@groupAccessStr.to_sym][@reqMethod])
                @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have access to #{@aspect.inspect} for #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
              else
                @isAdmin = (@groupAccessStr == 'o')
                # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser will have access to everything]
                ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
                # Get just the one ftypeRow matching the track
                @ftypeHash = ftypesHash[@trackName]
                @ftypesHash = {
                                @trackName => @ftypeHash
                              }
                ftypesHash.clear()
                if(@ftypeHash.nil? or @ftypeHash.empty?)
                  # Check if track has 'restricted' access
                  fmethod, fsource = @trackName.split(':')
                  restrictedTrackRec = @dbu.selectAllByFmethodAndFsource(fmethod, fsource)
                  if(!restrictedTrackRec.empty?)
                    initStatus = @statusName = :'Forbidden'
                    @statusMsg = "FORBIDDEN: This track is under restricted access. Please contact the group admin to get access to this track."
                  else
                    initStatus = @statusName = :'Not Found'
                    @statusMsg = "NO_TRK: There is no track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or the track is private and you don't have access)"
                  end
                else
                  @fTypeId = @ftypeHash['ftypeid']
                  unless(@aspect.nil?)
                    @aspectObj = getAspectHandler()
                    if(@aspectObj.nil?)
                      initStatus = @statusName = :'Not Found'
                      @statusMsg = "NO_TRK: There is no aspect #{@aspect} for track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
                    end
                  end
                end
              end
            else
              # pemissions haven't been defined for the aspect, or the user is trying to access an aspect that doesn't exist
              initStatus =  @statusName = :'Not Found'
              @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "Permissions haven't been defined for this aspect or the aspect doesn't exist in the database  #{@dbName.inspect} and group #{@groupName.inspect}.")
            end
          else
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_TRK_NAME: The track name '#{@trackName}' is not valid. Track names follow the pattern '{type}:{subtype}'. Have you perhaps double-escaped the track name by mistake?"
          end
        else
          # Group or database Not Found. Need to distinguish from track not found, which is ok for some requests (e.g. put new track)
          @noGrpOrNoDb = true
        end
      end
      return initStatus
    end

    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return @statusName
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK and @apiError.nil?)
        setResponse()
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      #cleanup()
      return @resp
    end

    # Process a PUT operation on this resource.
    # _returns_ - Rack::Response instance
    def put()
      initStatus = initOperation()
      # First, did we encounter specifically a Not Found group or database?
      # - if so, return error
      # - if yes, then maybe ok if adding new track or new aspect
      unless(@noGrpOrNoDb)
        @className = ( @nvPairs['trackClassName'] or Abstraction::Track.getDefaultClass(:unknownFormat) )
        if(!@aspectObj.nil? and initStatus == :OK) # PUT the aspect of trk
          if(TEMPLATE_ASPECTS[@aspect])
            @apiError = BRL::Genboree::GenboreeError.new(:'Method Not Allowed', "You do not have access to #{@aspect} for #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          else
            @aspectObj.parsePayload(self.readAllReqBody(), @repFormat)
            if(@aspectObj.hasError?)
              @apiError = @aspectObj.error
            else
              putStatus = @aspectObj.put()
              if(putStatus.is_a?(Integer))
                putStatus = (putStatus > 0) ? :Created : :'Not Modified'
              end
            end
          end
        else
          # Parse the payload for a DetailedTrackEntity
          entity = parseRequestBodyForEntity(['DetailedTrackEntity', 'TextEntity'])
          urlDescHash = {
                          "url" => nil,
                          "label" => nil,
                          "description" => nil
                        }
          if(initStatus == :OK and (entity.is_a?(TextEntity) or entity.is_a?(DetailedTrackEntity)))
            # Track name exists and payload is a DetailedTrackEntity so... Update the track
            putStatus = :'Not Modified'
            if(entity != :'Unsupported Media Type')
              method = source = nil
              if(entity.is_a?(TextEntity))
                method, source = entity.text.split(':')
                @trackName = "#{method}:#{source}"
              else
                method, source = entity.name.split(':')
                @trackName = entity.name
              end
              if((!method.nil? and !method.empty?) and (!source.nil? and !source.empty?))
                # Validate name
                rowsUpdated = @dbu.updateFtypeById(@fTypeId, method, source)
                # Check if the track is associated with a class. If not link it with the provided class or the default class
                if(@addDefaultClass)
                  ftypeClasses = @dbu.selectAllFtypeClasses(@fTypeId)
                  if(ftypeClasses.empty?)
                    className = (@nvPairs['trackClassName'] ? @nvPairs['trackClassName'] : Abstraction::Track.getDefaultClass(:unknownFormat))
                    @dbu.insertGclassRecord(className)
                    gclass = @dbu.selectGclassByGclass(className)
                    gid = gclass.first['gid']
                    @dbu.insertFtype2Gclass(@fTypeId, gid)
                  end
                end
                # Update instance vars with new name
                @ftypeHash['fmethod'], @ftypeHash['fsource'] = method, source
                putStatus = :'Moved Permanently' if(rowsUpdated == 1)
                if(entity.is_a?(DetailedTrackEntity))
                  # First get the information from the database and fill up the hash set up earlier
                  featureRows = @dbu.selectFeatureurlByFtypeId(@fTypeId)
                  featureRows.each { |row|
                    urlDescHash['url'] = row['url']
                    urlDescHash['label'] = row['label']
                    urlDescHash['description'] = row['description']
                  }
                  # Next overwrite the data with the one from the payload.
                  urlDescHash['url'] = entity.url if(entity.url) # May not be there (optional)
                  urlDescHash['description'] = entity.description # Has to be there
                  urlDescHash['label'] = entity.urlLabel if(entity.urlLabel) # May not be there (optional)
                  # Do an insert on duplicate key update
                  rowsAffected = @dbu.insertFeatureUrlOnDupKeyUpdate(@fTypeId, urlDescHash['url'], urlDescHash['description'], urlDescHash['label'])
                  putStatus = :'Moved Permanently' if(rowsAffected > 0)
                end
              else
                putStatus = @statusName = :'Bad Request'
                @statusMsg = "BAD_TRK_NAME: The new track name '#{@trackName.inspect}' from the payload is not valid. Track names follow the pattern '{type}:{subtype}'. Have you perhaps double-escaped the track name by mistake?"
              end
            end
          elsif(@aspect.nil? and initStatus == :'Not Found' and (entity.is_a?(DetailedTrackEntity) or entity.nil?))
            # Track name doesn't exist and payload is either empty or a DetailedTrackEntity so... Create the Track
            method, source = @trackName.split(':')
            if((!method.nil? and !method.empty?) and (!source.nil? and !source.empty?))
              rowsInserted = @dbu.insertFtype(method, source)
              if(rowsInserted == 1)
                putStatus = :Created
                @fTypeId = @dbu.dataDbh.func(:insert_id)
                # We need to associate this track with a class; use the provided class or default class
                if(@addDefaultClass)
                  if(@fTypeId > 0)
                    @dbu.insertGclassRecord(@className)
                    gclass = @dbu.selectGclassByGclass(@className)
                    gid = gclass.first['gid']
                    @dbu.insertFtype2Gclass(@fTypeId, gid)
                  end
                end
                # Need to set info so that setResponse can get and display the entity
                ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
                # Get just the one ftypeRow matching the track
                @ftypeHash = ftypesHash[@trackName]
                @ftypesHash = {
                                @trackName => @ftypeHash
                              }
                if(entity.is_a?(DetailedTrackEntity) and @fTypeId > 0)
                  urlDescHash['url'] = entity.url if(entity.url) # May not be there (optional)
                  urlDescHash['description'] = entity.description # Has to be there
                  urlDescHash['label'] = entity.urlLabel if(entity.urlLabel) # May not be there (optional)
                  rowsAffected = @dbu.insertFeatureUrlOnDupKeyUpdate(@fTypeId, urlDescHash['url'], urlDescHash['description'], urlDescHash['label'])
                  putStatus = :Created if(rowsAffected > 0)
                  @statusMsg = "Created: The track: #{@trackName.inspect} was created"
                end
              end
            else
              putStatus = @statusName = :'Bad Request'
              @statusMsg = "BAD_TRK_NAME: The new track name '#{@trackName.inspect}' from the payload is not valid. Track names follow the pattern '{type}:{subtype}'. Have you perhaps double-escaped the track name by mistake?"
            end
          elsif(self.estimateBodySize().nil? or self.estimateBodySize() <= 0) # Track DOES exist already, but payload empty (so not a rename)....trying to create track that already exists
            putStatus = :'Conflict'
            @statusMsg = "ALREADY_EXISTS: You appear to be trying to create a new empty track, but the track actually already exists."
          else
            putStatus = :'Unsupported Media Type'
            @statusMsg = "BAD_PAYLOAD: The payload does not appear to be either a Detailed Track Entity or a Text Entity representation. Need one of those for doing updates."
          end
        end
        if(putStatus == :"Moved Permanently" or putStatus == :Created or putStatus == :OK)
          @statusName = setResponse(putStatus)
        else
          @statusName = putStatus
        end
      else # grp or db not found error
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # _returns_ - Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(!@aspectObj.nil?) # DELETE the aspect of trk
        if(ADMIN_ASPECTS[@aspect] and !@isAdmin)
          @statusName = :'Forbidden'
          @statusMsg = "You do not have access to #{@aspect} for #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
        elsif(TEMPLATE_ASPECTS[@aspect])
          @statusName = :'Method Not Allowed'
          @statusMsg = "You do not have access to #{@aspect} for #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
        else
          rows = @aspectObj.delete()
          if(rows.is_a?(Numeric) and rows > 0)
            @statusName = :OK
            @statusMsg = 'DELETED'
          else
            # The delete method should return a status if not Numeric
            @statusName = rows
          end
        end
      elsif(@aspectObj.nil? and initStatus == :OK) # Delete the track
        # Delete ftypeid from ftype and all link tables
        deleteTrackByFtype(@fTypeId)
        @statusName = :OK
      else
        @statusName = initStatus
      end
      setResponse(@statusName, 'DELETED')
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def deleteTrackByFtype(fTypeId)
      userRec = @dbu.selectUserById(@userId).first
      # Delete the track from the ftype table.
      @dbu.deleteByFieldAndValue(:userDB, 'ftype', 'ftypeid', fTypeId, 'ERROR: BRL::Rest::Resouces::Track.delete()')
      # Launch a job to delete the rest of the track contents so that we can return to the client
      apiCaller = ApiCaller.new(@genbConf.machineName, "/REST/v1/genboree/tool/cleanTrackData/job?", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      outputs = ["http://#{@genbConf.machineName}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}?"]
      context = {
                    "toolIdStr" => "cleanTrackData",
                    "queue" => @genbConf.gbDefaultPrequeueQueue,
                    "userId" => @userId,
                    "toolTitle" => "Clean Track Data",
                    "userLogin" => userRec['name'],
                    "userLastName" => userRec['lastName'],
                    "userFirstName" => userRec['firstName'],
                    "userEmail" => userRec['email'],
                    "gbAdminEmail" => @genbConf.gbAdminEmail
                  }
      settings = {'ftypeHash' => {@trackName => fTypeId}, 'groupId' => @groupId, 'refSeqId' => @refSeqId}
      payload = {"inputs" => [], "outputs" => outputs, "context" => context, "settings" => settings}
      # Do a 'put' on the toolJob resource on 'this' machine
      apiCaller.put(payload.to_json)
    end

    def setResponse(statusName=:OK, statusMsg='')
      if(@repFormat == :UCSC_BROWSER or @repFormat == :UCSC_HUB_TRACKDB)
        fileType = (@nvPairs['ucscType']) ? @nvPairs['ucscType'] : 'bigWig'
        @resp.body = ''
        bodyStr = ''
        # Need to support lists of tracks
        method, source = @trackName.split(':')
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source)
        if( (fileType == 'bigWig' and trackObj.bigWigFileExists?(@groupId)) or (fileType == 'bigBed' and trackObj.bigBedFileExists?(@groupId)) )
          if(@repFormat == :UCSC_HUB_TRACKDB) # new / hub oriented multi-line stanza
            bodyStr << trackObj.makeUcscTrackStr(fileType, @rsrcHost, @groupId)
          else # old name=value format
            bodyStr << trackObj.makeUcscTrackStr_oneLine(fileType, @rsrcHost, @groupId)
          end
        end
        if(bodyStr.empty?)
          @statusName, @statusMsg = :'Bad Request', "There aren't any tracks in this database that have #{fileType} format available.  Ensure that the #{fileType} files exist."
        else
          @resp.status = HTTP_STATUS_NAMES[:OK]
          @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@repFormat]
          @resp.body = bodyStr
        end
      elsif(@repFormat == :BROWSER_PNG) # For the Genboree genome browser
        method, source = @trackName.split(':')
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source)
        # Get the entrypoint, startCoord and stopCoord
        @chrom = @nvPairs['chrom']
        @startCoord = @nvPairs['startCoord'] ? @nvPairs['startCoord'].to_i : 1
        stopCoord = @nvPairs['stopCoord']
        drawRuler = @nvPairs.key?('drawRuler') ? 1 : 0
        displayTrackDescription = @nvPairs.key?('displayTrackDescription') ? 1 : 0
        if(!stopCoord.nil? and !stopCoord.empty?)
          @stopCoord = stopCoord.to_i
        else
          frefHash = {}
          allDbs = trackObj.getDbRecsWithData() # Get all dbs for the track
          allDbs.each { |db|
            @dbu.setNewDataDb(db['dbName'])
            allFrefRecords = @dbu.selectAllRefNames()
            allFrefRecords.each { |record|
              if(record['refname'] == @chrom)
                @stopCoord = record['rlength'].to_i
                break
              end
            }
          }
        end
        # Now get the PNG for the landmark requested
        genBrowserObj = BRL::Genboree::Graphics::GenomeBrowser::GenomeBrowserClass.new()
        png = genBrowserObj.getPNGImage(@chrom, @startCoord, @stopCoord, @refSeqId, @userId, @trackName, drawRuler, displayTrackDescription)
        @resp.status = HTTP_STATUS_NAMES[:OK]
        @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:PNG]
        @resp.body = png

      else
        # Create entity for this track or aspect of this track that was requested
        if(!@aspectObj.nil?)
          if(@aspectObj.hasError?)
            @apiError = @aspectObj.error
          else
            detailed = nil
            if(!@aspect.nil? and @aspect == "attributes")
              detailed = @nvPairs['detailed'] # 'attributes' support multiple detailed options instead of just true and false
            else
              detailed = @detailed
            end
            entity = @aspectObj.getEntity(@connect, detailed)
          end
        elsif(!@ftypeHash.nil? and !@ftypeHash.empty?)  # no aspect or unknown, default to full information
          begin
            tracksObj = BRL::Genboree::Abstract::Resources::Tracks.new(@dbu, @refSeqId, @ftypesHash, @userId, @connect)
            detailed = @nvPairs['detailed']
            detailed = 'minDetails' unless(detailed)
            # If the response format is tabbed and detailed is any of the 'OO' entity types, give an error
            if(@repFoprmat == 'tabbed' and detailed =~ /^oo/)
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "tabbed response format not allowed with any of the 'OO' entity types. ")
            else
              refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/trk")
              entity = tracksObj.getEntity(refBase, nil, nil, detailed, false)
            end
          rescue => err
            msg = "FATAL: server encountered an error creating a representation of tracks in database #{@dbName.inspect} in user group #{@groupName.inspect}"
            BRL::Genboree::GenboreeUtil.logError(msg, err)
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', msg, err)
          end
        end
        if(entity.is_a?(BRL::Genboree::REST::Data::AbstractEntity))
          entity.setStatus(statusName, statusMsg)
          @statusName = configResponse(entity, statusName)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The track or aspect by that name does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
      end
    end

    # This method defines aspects to the appropriate handler objects
    # +returns+:: AspectHandler or nil if there was no match to @aspect
    def getAspectHandler()
      aspectObj = case @aspect
        ### User-defined settings
        when 'style' then TrackStyleHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)
        when 'color' then TrackColorHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)
        when 'display' then TrackDisplayHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)
        when 'rank' then TrackRankHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)
        when 'queryable' then TrackQueryableHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)

        ### Default settings
        when 'defaultStyle' then TrackStyleHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'defaultColor' then TrackColorHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'defaultDisplay' then TrackDisplayHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'defaultRank' then TrackRankHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)

        ### Values from the local Db that the track originated from.  Only a default value, no user-defined values
        when 'description' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'url' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'urlLabel' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'links' then TrackLinksHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0)
        when 'annoAttributes' then TrackAnnoAttributesHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash)
        when 'classes' then TrackClassesHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash)
        when 'eps' then TrackEntrypointsHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, 0, @nvPairs['nameFilter'])
        # attributes is different from annoAttributes, attributes are track level attributes (ftype2attribute tables)
        when 'attributes' then TrackAttributesHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, @userId)
        # API requests to Individual track attributes are handled by BRL::REST::Resources::TrackAttribute

        ### Values from the template Db that the track originated from
        when 'templateDescription' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, nil)
        when 'templateUrl' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, nil)
        when 'templateUrlLabel' then TrackUrlHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, nil)
        when 'templateLinks' then TrackLinksHandler.new(@dbu, @trackName, @refSeqId, @aspect, @ftypeHash, nil)

       else nil
      end
      return aspectObj
    end

    ###
    # Used to report the queryable status of the track uri
    # NOTE: Interacts with BRL::REST::Resources::Track so does not belong in the
    # BRL::Genboree::Abstract::Resources module outside of the REST code
    class TrackQueryableHandler < TrackAspectHandler
      # [+returns+] The value of BRL::REST::Resources::Track.queryable?
      def getValue()
        return BRL::REST::Resources::Track.queryable?
      end

      # [+returns+] Creates error GenboreeError(:"Unsupported Media Type") if the
      #   request body is not empty, no payloads are supported by this aspect
      def parsePayload(reqBody, repFormat)
        unless(reqBody.empty?)
          @error = GenboreeError(:'Unsupported Media Type', 'This aspect does not support any payloads')
        end
        return nil
      end

      # [+returns+] :"Method Not Allowed"
      def create()
        return :'Method Not Allowed'
      end

      # [+returns+] :"Method Not Allowed"
      def delete()
        return :'Method Not Allowed'
      end
    end # class TrackQueryableHandler
  end # class Track
end ; end ; end # module BRL ; module REST ; module Resources
