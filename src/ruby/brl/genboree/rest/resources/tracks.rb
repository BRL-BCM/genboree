#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/tracks'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/trackEntity'
require 'brl/genboree/rest/data/trackAttributeMapEntity'
require 'brl/genboree/rest/data/attributesEntity'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/db/tables/tracks'
require 'ruby-prof'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Track - exposes information aboutthe collection of tracks in a group.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedTrackEntityList
  # * BRL::Genboree::REST::Data::TextEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  class Tracks < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/trks"

    RESOURCE_DISPLAY_NAME = "Tracks"

    PROHIBITED_ATTRIBUTES  =
                            {
                              "gbTrackBpSpan" => nil,
                              "gbTrackBpStep" => nil,
                              "gbTrackUseLog" => nil,
                              "gbTrackDataMax" => nil,
                              "gbTrackDataMin" => nil,
                              "gbTrackRecordType" => nil,
                              "gbTrackDataSpan" => nil,
                              "gbTrackHasNullRecords" => nil
                            }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
      @filter = @filterType = @filterTypeId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/trks or ../trks/{attr}/{value} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks(?:$|/attribute/([^/\?]+)/([^/\?]+)$|/attributes$)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 5          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return @statusName
    end

    def head()
      # alias for get() because the required headers are all set there
      # Use the headOnly parameter in get() to set the "Content-Length"
      # to the size of the body
      get(true)
    end

     # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get(headOnly=false)
      startTime = t1 = Time.now
      initStatus = initOperation()
      respEntity = nil

      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        if(@uriMatchData[3] and @uriMatchData[4])
          @filterType = Rack::Utils.unescape(@uriMatchData[3])
          @filter = Rack::Utils.unescape(@uriMatchData[4])
        else # no 'get' support for attributes for now
          pathElements = @rsrcPath.split('/')
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Implemented', "NOT_IMPLEMENTED") if(pathElements.last == 'attributes' or pathElements.last == 'attributes?')
        end
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/trk")
          # Get a hash of all track names (includes shared tracks) [that user has access to; superuser will have access to everything]
          tt = Time.now
          #@ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbNames for the db (template, user) track came from and the ftypeid within that database
          @ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu) # will also have dbNames for the db (template, user) track came from and the ftypeid within that database
          # if the 'class' url parameter is set filter for tracks mapped to this class
          if(@nvPairs['class'])
            ftypesHashByClass = {}
            # Lookup Hash for storing the ftypeIds linked to the class with the dbName as the key
            ftypeIdsForGclassHash = {}
            @ftypesHash.each_key { |tname|
              ftypeHash = @ftypesHash[tname]
              ftypeHash['dbNames'].each { |dbRec|
                # If the value in the hash for the key dbName is nil then we haven't looked yet,
                if(ftypeIdsForGclassHash[dbRec.dbName].nil?)
                  # Set the database
                  @dbu.setNewDataDb(dbRec.dbName)
                  # get the ftypeids that are mapped to the glclass
                  ftypeIdRows = @dbu.selectFtypeIdsByClass(@nvPairs['class'])
                  if(!ftypeIdRows.nil? and !ftypeIdRows.empty?)
                    ftypeIdsForGclassHash[dbRec.dbName] = ftypeIdRows.map {|nn| nn = nn['ftypeid'] }
                  else
                    ftypeIdsForGclassHash[dbRec.dbName] = []
                  end
                end
                if(!ftypeIdsForGclassHash[dbRec.dbName].index(dbRec.ftypeid).nil?)
                  ftypesHashByClass[tname] = @ftypesHash[tname]
                end
              }
            }
            @origFtypesHash = @ftypesHash
            @ftypesHash = ftypesHashByClass
          end
          tracksObj = BRL::Genboree::Abstract::Resources::Tracks.new(@dbu, @refSeqId, @ftypesHash, @userId, @connect)
          # Check if a valid filter was used
          if(@filterType and @filter and !@ftypesHash.empty?)
            rows = @dbu.selectFtypeAttrNameByName(@filterType)
            if(rows.empty?)
              @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "ATTR_NOT_FOUND: The attribute #{@filterType.inspect} was not found for this track list.")
            else
              # Convert filterType text into id
              @filterTypeId = rows.first['id']
            end
          end
          if(@repFormat == :UCSC_HUB_TRACKDB)
            t1 = Time.now
            makeUcscBrowserResponse(headOnly, false)
          elsif(@repFormat == :UCSC_BROWSER)
            t1 = Time.now
            makeUcscBrowserResponse(headOnly, true)
          else
            begin
              # Get the 'real' detailed option
              detailed = @nvPairs['detailed']
              if(detailed and detailed != "false")
                respEntity = tracksObj.getEntity(refBase, @filterType, @filter, detailed, true)
              else
                respEntity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
                @ftypesHash.keys.sort { |aa, bb|
                  aa.downcase <=> bb.downcase
                }.each { |tname|
                  entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, tname)
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
                  # Check filter (if any) for this track
                  if(!@filterTypeId.nil? and !@filter.nil?)
                    rows = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameId(@ftypesHash[tname]['ftypeid'], @filterTypeId)
                    filtered = true
                    rows.each { |row|
                      filtered = false if(row['value'] == @filter)
                    }
                    respEntity << entity unless(filtered)
                  else
                    if(@nvPairs['templateTracksOnly'])
                      respEntity << entity if(@ftypesHash[tname]['dbNames'].size > 1)
                    elsif(@nvPairs['userTracksOnly'])
                      respEntity << entity if(@ftypesHash[tname]['dbNames'].size == 1)
                    else
                      respEntity << entity
                    end
                  end
                }
              end
              @statusName = configResponse(respEntity)
            rescue => err
              msg = "FATAL: server encountered an error creating a representation of tracks in database #{@dbName.inspect} in user group #{@groupName.inspect}"
              BRL::Genboree::GenboreeUtil.logError(msg, err)
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', msg, err)
            end
          end
          @ftypesHash.clear() if(@ftypesHash)
        end
      end
      if(!@apiError.nil?)
        @statusName, @statusMsg = @apiError.type, @apiError.message
        initStatus = @statusName
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. Currently only supports trks/attributes
    def put()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      @apiError = nil
      if(initStatus == :OK)
        # Put for trks/attribute/attName/attValue not supported
        if(@uriMatchData[3] and @uriMatchData[4])
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Implemented', "NOT_IMPLEMENTED")
        end
        if(@apiError.nil?)
          # Also no support for 'metadata' @repType for now
          if(!@repType.nil? and @repType == 'metadata')
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Implemented', "NOT_IMPLEMENTED: Only supports repType: 'metadataMap' currently.")
          end
          if(@apiError.nil?)
            if(@groupAccessStr == 'r')
              @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a sample in database #{@dbName.inspect} in user group #{@groupName.inspect}")
            else
              if(@apiError.nil?)
                # Get the entity from the HTTP request
                entTime = Time.now
                entities = parseRequestBodyForEntity('TrackAttributeMapEntity')
                if(entities.nil?)
                  # If we have an @apiError set, use it, else set a generic one.
                  @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a TrackAttributeMapEntity") if(@apiError.nil?)
                elsif(entities == :'Unsupported Media Type')
                  # If we have an @apiError set, use it, else set a generic one.
                  @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not a TrackAttributeMapEntity") if(@apiError.nil?)
                else
                  # Need to check/validate that all samples have a "name" column and that name is unique
                  recCount = 1
                  attrNames = {} # Hash for storing attribute names and their ids
                  attrValues = {} # Hash for stroing attribute values and their ids
                  trksDone = [] # Array for storing succeeded tracks
                  dupTracks = [] # Array for storing tracks present multiple times
                  dupTracksHash = {} # Hash for storing tracks present multiple times
                  trkHash = {} # Hash for storing track name and ftypeids
                  missingTrks = [] # Array for storing missing track names
                  attrRecords = [] #  2-d array for attrNames to be inserted
                  attrValueRecords = [] # 2-d array for attrValues to be inserted
                  ftypeidList = [] # Array of just the ftypeids
                  t1 = Time.now
                  maxAttributesSize = 0
                  # TODO: collect track names in hash (will hash to ftypeid, but in loop hashes to nil)
                  entities.each_key { |entity|
                    if(entity.nil? or entity.empty?)
                      @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track record ##{recCount} -> Does not have a proper value in the 'name' column or is missing the required 'name' column altogether. Aborting import of track attributes/metadata.")
                      break
                    elsif(entities[entity].nil? or entities[entity].empty?)
                      @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track record ##{recCount} -> Does not have proper values for the attributes/metadata columns. Aborting import of track attributes/metadata.")
                      break
                    else # Collect all attribute names
                      # Need to this only once
                      attributes = entities[entity]
                      if(entity =~ /:/)
                        method, source = entity.split(':')
                        if((method.nil? or method.empty?) or (source.nil? or source.empty?))
                          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track record ##{recCount} -> type or subtype is either nil or empty. Aborting import of track attributes/metadata.")
                          break
                        end
                        attributes.each_key { |attr|
                          if(!attrNames.has_key?(attr))
                            attrNames[attr] = nil
                            attrRecords << [attr, 0]
                          end
                        }
                        trkName = entity
                        trkHash[trkName] = nil
                        maxAttributesSize = maxAttributesSize > attributes.keys.size ? maxAttributesSize : attributes.keys.size # This should be same for all attributes for 'tabbed' format
                        fmethodFsource = trkName.split(':')
                        # Assume all are missing: we will do a insert ignore (if creating empty tracks)
                        if(@nvPairs['createEmptyTracks'])
                          missingTrks << [fmethodFsource[0], fmethodFsource[1]]
                        end
                      else
                        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track record ##{recCount} -> Does not have a ':' in the track name. Aborting import of track attributes/metadata.")
                        break
                      end
                    end
                    recCount += 1
                  }

                  # Get the ftypeids for the tracks
                  if(@apiError.nil?)
                    begin
                      trackTime = Time.now
                      ftypeRecs = @dbu.selectFtypesByNames(trkHash.keys)
                      if(ftypeRecs.size < trkHash.size)
                        if(@nvPairs['createEmptyTracks'])
                          @dbu.insertFtypes(missingTrks, missingTrks.size)
                          ftypeRecs = @dbu.selectFtypesByNames(trkHash.keys)
                        end
                      end
                      ftypeRecs.each { |ftypeRec|
                        trkHash["#{ftypeRec['fmethod']}:#{ftypeRec['fsource']}"] = ftypeRec['ftypeid']
                        ftypeidList << ftypeRec['ftypeid'] # Not required; use trkHash.values
                      }
                      # Check if all the tracks are associated with a class. If not, link them to the
                      # appropriate default class for the format or to "trackClassName" argument if provided.
                      className = ( @nvPairs['trackClassName'] or Abstraction::Track.getDefaultClass(:unknownFormat) )
                      classTime = Time.now
                      ftype2gclass = @dbu.selectAllFtypeClasses(ftypeidList)
                      if(ftype2gclass.size < ftypeidList.size)
                        @dbu.insertGclassRecord(className)
                        gclass = @dbu.selectGclassByGclass(className)
                        gid = gclass.first['gid']
                        # First we need to collect the list of tracks that are not associated with a class
                        ftype2gid = {}
                        ftype2gclass.each { |rec|
                          ftype2gid[rec['ftypeid']] = rec['gid']
                        }
                        ftype2gclassData = []
                        ftypeidList.each  { |ftypeid|
                          unless(ftype2gid[ftypeid])
                            ftype2gclassData << [ftypeid, gid]
                          end
                        }
                        @dbu.insertFtype2Gclasses(ftype2gclassData, ftype2gclassData.size)
                      end
                      # Get the ids for attr names
                      attrTime = Time.now
                      attrRecs = @dbu.selectFtypeAttrNamesByNames(attrNames.keys)
                      if(attrRecs.size < attrNames.size)
                        @dbu.insertFtypeAttrNames(attrRecords, attrRecords.size)
                        attrRecs = @dbu.selectFtypeAttrNamesByNames(attrNames.keys)
                      end
                      attrRecs.each { |attr|
                        attrNames[attr['name']] = attr['id']
                      }
                      recordsToInsert = Array.new(entities.size * maxAttributesSize) # Array for storing records to insert into the 'ftype2attributes' table
                    rescue => err
                      @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "ERROR: Could not set up new tracks, classes and attribute names", err, true)
                    end
                  end
                  recordCount = 0
                  if(@apiError.nil?)
                    begin
                      ftypeRecs = @dbu.selectAllFtypes()
                      ftypeRecs.each { |rec|
                        trkHash["#{rec['fmethod']}:#{rec['fsource']}"] = rec['ftypeid']
                      }
                      entities.each_key { |trackName|
                        next if(!trkHash[trackName]) # Skip if value is nil
                        attributes = entities[trackName]
                        if(!dupTracksHash.has_key?(trackName))
                          dupTracksHash[trackName] = nil
                        else
                          dupTracks.push(trackName)
                        end
                        # Get the ftypeid of the track
                        # Create a new track if ftypeRec is nil or empty
                        ftypeid = trkHash[trackName]
                        attributes.each_key { |attribute|
                          next if(PROHIBITED_ATTRIBUTES.has_key?(attribute)) # Skip crucial attributes required by the hdhv library
                          attValue = attributes[attribute]
                          if(!attrValues.has_key?(attValue))
                            attrValues[attValue] = nil
                            attrValueRecords << [attValue, 0]
                          end
                          recordsToInsert[recordCount] = ftypeid
                          recordCount += 1
                          recordsToInsert[recordCount] = attrNames[attribute]
                          recordCount += 1
                          recordsToInsert[recordCount] = attValue # place holder
                          recordCount += 1
                        }
                        trksDone.push(trackName)
                      }
                      # Get the ids for the attr values
                      valTime = Time.now
                      attrValueRecs = @dbu.selectFtypeAttrValueByValues(attrValues.keys)
                      if(attrValueRecs.size < attrValues.size)
                        @dbu.insertFtypeAttrValues(attrValueRecords, attrValueRecords.size)
                        attrValueRecs = @dbu.selectFtypeAttrValueByValues(attrValues.keys)
                      end
                      attrValueRecs.each { |val|
                        attrValues[val['value']] = val['id']
                      }
                      # Loop over 'recordsToInsert' and replace the attValues with thier ids
                      2.step(recordsToInsert.size, 3) { |ii|
                        recordsToInsert[ii] = attrValues[recordsToInsert[ii]]
                      }
                      insertTime = Time.now
                      @dbu.insertFtype2Attributes(recordsToInsert, recordCount / 3, dupKeyUpdateCol='ftypeAttrValue_id', flatten=false)
                      @statusName = :'Created'
                      @statusMsg = "The metadata was successfully added. "
                    rescue => err
                      @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: Could not insert metadata information for track in database: #{@dbName} ", err, true)
                    end
                  end
                end
              end
            end
          end
        end
      end
      if(!@apiError.nil?)
        @statusName, @statusMsg = @apiError.type, @apiError.message
        initStatus = @statusName
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource
    # Requires a 'trackNames' param with a list of comma separated tracks to be deleted
    # Only ftypeids are removed live. The rest of the track data is removed in a daemonized manner.
    def delete()
      initStatus = initOperation()
      respEntity = nil
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initGroupAndDatabase()
        # Check for list of track names to delete
        trkNames = @nvPairs['trackNames']
        if(!trkNames.nil? and !trkNames.empty?)
          if(initStatus == :OK)
            refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/trk")
            # Get a hash of all track names (includes shared tracks) [that user has access to; superuser will have access to everything]
            @ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu) # will also have dbNames for the db (template, user) track came from and the ftypeid within that database
            trkList = trkNames.split(',')
            ftypeids = []
            ftypeHash = {}
            trkList.each { |trk|
              if(@ftypesHash.key?(trk))
                ftypeid = @ftypesHash[trk]['ftypeid']
                ftypeids << ftypeid
                ftypeHash[trk] = ftypeid
              end
            }
            begin
              @dbu.deleteFtypesByFtypeIds(ftypeids)
              groupId = @dbu.selectGroupByName(@groupName).first['groupId']
              userRec = @dbu.selectUserById(@userId).first
              # Delete the track from the ftype table.
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
              settings = {'ftypeHash' => ftypeHash, 'groupId' => groupId, 'refSeqId' => @refSeqId}
              payload = {"inputs" => [], "outputs" => outputs, "context" => context, "settings" => settings}
              # Do a 'put' on the toolJob resource on 'this' machine
              apiCaller.put(payload.to_json)
              respEntity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
              @statusMsg = "The track(s) were successfully deleted. "
              @statusName = configResponse(respEntity)
            rescue => err
              $stderr.puts err
              $stderr.puts err.backtrace.join("\n")
              @statusName = :'Internal Server Error'
              @statusMsg = "FATAL: #{err.message}."
            end
            @ftypesHash.clear() if(@ftypesHash)
          end
        else
          @statusName = :'Bad Request'
          @statusMsg = "Delete operation requires 'trackNames' parameter with comma separated list of track names. "
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def makeUcscBrowserResponse(headOnly=false, oneLineUcscFormat=false)
      @resp.body = ''
      bodyStr = ''
      sessionId = nil
      ucscOptions = {}
      trackBigFileHash = { :bigWig => Hash.new { |hh, kk| hh[kk] = 0 }, :bigBed => Hash.new { |hh, kk| hh[kk] = 0 } }
      trackHash = Hash.new { |hh, kk| hh[kk] = Hash.new { |mm, ll| mm[ll] = 0 } }
      # Defaults to bigWig files
      fileType = (@nvPairs['ucscType']) ? @nvPairs['ucscType'] : 'bigWig'
      ucscOptions['color'] = @nvPairs['ucscColor'] if(!@nvPairs['ucscColor'].nil? and !@nvPairs['ucscColor'].empty?)
      ucscOptions['visibility'] = @nvPairs['ucscVisibility'] if(!@nvPairs['ucscVisibility'].nil? and !@nvPairs['ucscVisibility'].empty?)
      # Need to support lists of tracks
      haveTrackList = false
      dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      # For storing track urls on other hosts (keyed by the db uri)
      trkUriHash = Hash.new { |hh,kk|
        hh[kk] = {}
      }
      gbKeyHash = {}
      if(@nvPairs['ucscTracks'])
        trackList = @nvPairs['ucscTracks'].split(',')
        trackList.each { |trk|
          # Process if trk is not a url (assumed to be a local track)
          #unescTrkName = CGI.unescape(trk)
          unescTrkName = trk.dup()
          # Using trackApiHelper to see if its a url since doing a URI.parse on an unescaped track name throws up an error
          if(trkApiHelper.extractName(unescTrkName))
            uriQuery = URI.parse(unescTrkName).query
            nvPairs = Rack::Utils.parse_query(uriQuery)
            suffix = ""
            gbKey = ""
            if(!nvPairs.key?('format'))
              raise "No format provided with track URL. Needs format=ucsc_bigwig or format=ucsc_bigbed"
            else
              suffix = ( nvPairs['format'].upcase.to_sym == :UCSC_BIGWIG ? '_bwuc' : '_bbuc' )
            end
            if(nvPairs.key?('gbKey'))
              gbKey = nvPairs['gbKey']
            end
            gbKeyHash[dbApiHelper.extractPureUri(unescTrkName)] = gbKey
            trkUriHash[dbApiHelper.extractPureUri(unescTrkName)]["#{CGI.escape(trkApiHelper.extractName(unescTrkName))}#{suffix}"] = nil
          elsif(dbApiHelper.extractName(unescTrkName)) # See if its a db uri with a list of tracks
            uriQuery = URI.parse(unescTrkName).query
            nvPairs = Rack::Utils.parse_query(uriQuery)
            tmpDbUri = dbApiHelper.extractPureUri(unescTrkName)
            gbKey = ""
            ucscTrkList = nvPairs['ucscTracks'].split(',')
            ucscTrkList.each { |ucscTrk|
              trkUriHash[tmpDbUri][ucscTrk] = nil
            }
            if(nvPairs.key?('gbKey'))
              gbKey = nvPairs['gbKey']
            end
            gbKeyHash[dbApiHelper.extractPureUri(unescTrkName)] = gbKey
          else # Just track name
            trkName = trk.gsub(/_b[w,b]uc$/, '')
            trackType = ((trk =~ /_bwuc$/) ? :bigWig : ((trk =~ /_bbuc$/) ? :bigBed : nil))
            if(trackType) # skip any with bad data type indicators
              trackBigFileHash[trackType][trkName] += 1
              trackHash[trkName][trackType] += 1
            end
            haveTrackList = true
          end
        }
      end
      # Create a session key for reusable cache in Track class, as we loop over many tracks
      sessionId = BRL::Genboree::Abstract::Resources::Track.generateSessionId()
      begin
        # Loop over tracks
        apiCallErrorMsg = nil
        apiCallErrorStatusCode = nil
        @ftypesHash.each_key { |trkName|
          if( (@nvPairs['nameFilter'].nil? and !haveTrackList) or  # no filters, no trk list given, get all
              (!@nvPairs['nameFilter'].nil? and trkName.index(@nvPairs['nameFilter'])) or   # nameFilter applied
              (haveTrackList and (trackBigFileHash[:bigWig].key?(trkName) or trackBigFileHash[:bigBed].key?(trkName))) # ucscTracks list specified, and this track is one
            )
            # Get track info
            method, source = trkName.split(':')
            # We will set the session key to use for caching while processing the list of tracks:
            trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source, sessionId)
            # See if asking for bigWig and/or bigBed for this track...both will be allowed.
            trackBigFileHash.each_key { |bigType|
              if(trackBigFileHash[bigType].key?(trkName))
                if( (bigType == :bigWig and trackObj.bigWigFileExists?(@groupId)) or
                    (bigType == :bigBed and trackObj.bigBedFileExists?(@groupId)))
                  if(trackHash[trkName].size > 1) # Then we have multiple big* type for this same file.
                    altName = "#{trkName}-#{bigType.to_s.gsub(/big/, '').downcase}"
                  else
                    altName = nil
                  end
                  if(oneLineUcscFormat)
                    bodyStr << trackObj.makeUcscTrackStr_oneLine(bigType.to_s, @rsrcHost, @groupId, ucscOptions, altName)
                  else # new / hub-oriented
                    bodyStr << trackObj.makeUcscTrackStr(bigType.to_s, @rsrcHost, @groupId, ucscOptions, altName)
                  end
                end
              end
            }
          end
        }
        # Now loop over trkUriHash and append any tracks residing on different hosts
        trkUriHash.each_key { |dbUri|
          uriObj = URI.parse(dbUri)
          host = uriObj.host
          gbKey = gbKeyHash[dbUri]
          rcscPath = "#{uriObj.path}/trks?"
          rcscPath << "gbKey=#{gbKey}&" if(!gbKey.empty?)
          rcscPath << "format=#{oneLineUcscFormat ? 'ucsc_browser' : 'ucsc_hub_trackdb'}&ucscTracks="
          rcscPath << trkUriHash[dbUri].keys.join(",")
          apiCaller = WrapperApiCaller.new(host, rcscPath, @userId)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
          apiCaller.get()
          if(!apiCaller.succeeded?)
            # Check if the response can be parsed
            begin
              resp = JSON.parse(apiCaller.respBody)
              if(resp.key?('status'))
                if(resp['status'].key?('msg'))
                  apiCallErrorMsg = resp['status']['msg']
                end
                if(resp['status'].key?('statusCode'))
                  apiCallErrorStatusCode = resp['status']['statusCode'].to_sym
                end
              end
            rescue
            ensure
              raise apiCaller.respBody
            end
          end
          bodyStr << apiCaller.respBody
        }
      rescue => err
        msg = "FATAL: Could not make UCSC browser response due to exception."
        BRL::Genboree::GenboreeUtil.logError(msg, err)
        statusCode = apiCallErrorStatusCode ? apiCallErrorStatusCode : :'Internal Server Error'
        statMsg = apiCallErrorMsg ? apiCallErrorMsg : msg
        @apiError = BRL::Genboree::GenboreeError.new(statusCode, statMsg, err)
      ensure
        # Invalidate session cache
        BRL::Genboree::Abstract::Resources::Track.invalidateSessionId(sessionId) unless(sessionId.nil?)
      end

      if(bodyStr.empty?)
        # Could also be that the database isn't unlocked, check and warn.
        if(!@nvPairs['nameFilter'].nil?)
          @statusMsg = "There aren't any unlocked tracks in this database that have UCSC big* files available using a nameFilter of #{@nvPairs['nameFilter'].inspect}. Ensure that you're using the correct format suffixes for each track (_bwuc or _bbuc) and that the appropriate big* files have been generated first."
        elsif(haveTrackList)
          @statusMsg = "There aren't any unlocked tracks in this database that have UCSC big* files available for ucscTracks list #{@nvPairs['ucscTracks'].inspect}. Ensure that you're using the correct format suffixes for each track (_bwuc or _bbuc) and that the appropriate big* files have been generated first."
        else
          @statusMsg = "There aren't any unlocked tracks in this database that have UCSC big* files available. Ensure that you're using the correct format suffixes for each track (_bwuc or _bbuc) and that the appropriate big* files have been generated first."
        end
        @statusName = :'Bad Request'
      else
        @resp.status = HTTP_STATUS_NAMES[:OK]
        @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@repFormat]
        @resp['Content-Length'] = bodyStr.length.to_s if(headOnly)
        @resp['Accept-Ranges'] = 'bytes' if(headOnly)
        @resp.body = bodyStr
      end
    end
  end # class Tracks
end ; end ; end # module BRL ; module REST ; module Resources
