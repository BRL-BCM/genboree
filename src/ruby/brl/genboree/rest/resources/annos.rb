#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/countEntity'
require 'brl/genboree/rest/data/trackLinkEntity'
require 'brl/genboree/abstract/resources/track'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++
  # Track - exposes information about a specific tracks.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::DetailedTrackEntityList
  class Annos < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # Supported Aspects:
    SUPPORTED_ASPECTS = { 'count' => true, 'names' => true }

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
      #return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)(?:$|/([^/\?]+)$)}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/[aspect] URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/annos/([^/\?]+)$}
    end

    def self.getPath(groupName, databaseName, trackName, aspect=nil)
      path = "/REST/#{VER_STR}/grp/#{Rack::Utils.escape(groupName)}/db/#{Rack::Utils.escape(databaseName)}/trk/#{Rack::Utils.escape(trackName)}/annos"
      path += "/#{Rack::Utils.escape(@aspect)}" if(!@aspect.nil?)
      return path
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 9          # Try to match this URI pattern first
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip
      @aspect = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])
      if(@aspect.nil? or !SUPPORTED_ASPECTS.has_key?(@aspect))
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "ERROR: Request URI doesn't indicate an exposed resource or is otherwise incorrect."
      end
      if(initStatus == :OK)
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK and @apiError.nil?)
        # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser will have access to everything]
        ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbType (:userDb or :sharedDb), dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
        # Get just the one ftypeRow matching the track
        ftypeHash = ftypesHash[@trackName]
        ftypesHash.clear()
        # Track not found
        if(ftypeHash.nil? or ftypeHash.empty?)
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_TRK: There is no track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or the track is private and you don't have access)"
        else
          fmethod, fsource = ftypeHash['fmethod'], ftypeHash['fsource']
          # Handle the appropriate aspect
          if(@aspect == 'count')
            ftypeCount = 0
            ftypeHash['dbNames'].each { |dbRec|
              @dbu.setNewDataDb(dbRec.dbName)
              ftypeCountRecs = @dbu.selectFtypeCountByFtypeid(dbRec.ftypeid)
              if(!ftypeCountRecs.empty?)
                ftypeCount += ftypeCountRecs.first['numberOfAnnotations'].to_i
              end
            }
            entity = BRL::Genboree::REST::Data::CountEntity.new(@connect, ftypeCount)
          elsif(@aspect == 'names')
            limit = @nvPairs['maxNumRecords'] # can be nil (no limit)
            limit = limit.to_i if(limit)
            pattern = @nvPairs['pattern'] # can be nil (no pattern)
            random = @nvPairs['random']  # can be nil (don't return random set of matching names)
            random = (random.nil? ? false : (random.strip =~ /^(?:true|yes)$/ ? true : false))
            # fix pattern so it can be used in SQL (with a bind slot, not directly!!)
            if(pattern)
              pattern.gsub!(/\*/, "%")
            end
            # We will visit the user database first and get the names.
            # - IF we still have room left in the "limit", we will then visit the shared database
            sortedDbRecs = ftypeHash['dbNames'].sort { |aa, bb|
                ((aa.dbType == :userDB) ? -1 : ((bb.dbType == :userDB) ? 1 : 0 ))
            }
            gnames = {}
            currLimit = 0
            sortedDbRecs.each { |dbRec|
              #$stderr.puts "DEBUG: doing db #{dbRec.inspect}"
              @dbu.setNewDataDb(dbRec.dbName)
              gnameRows = @dbu.selectDistinctGnamesByTrack(dbRec.ftypeid, limit, pattern, random)
              # $stderr.puts "DEBUG: Using #{dbRec.ftypeid.inspect}, #{limit.inspect}, #{pattern.inspect}, found #{gnameRows.size} rows"
              # Add in the gnames as long as we have room AND we have not seen the gname yet
              # (say, from looking at a previous database)
              rowIdx = 0
              while(rowIdx < gnameRows.size and (limit.nil? or (currLimit < limit)))
                row = gnameRows[rowIdx]
                gname = row['gname']
                unless(gnames.key?(gname))
                  gnames[row['gname']] = true
                end
                currLimit += 1
                rowIdx += 1
              end
              # Before going on to next dbRec, try to short circuit (i.e. if limit reached already). Code
              # should work even if limit is reached, but maybe we can avoid unnecessary DB activity...
              break if(!limit.nil? and currLimit >= limit)
            }
            # $stderr.puts "DEBUG: Should have no more than #{limit} gnames: # gnames = #{gnames.size}"
            # Build text entity list:
            entity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            sortedNames = gnames.keys.sort { |aa,bb| aa.downcase <=> bb.downcase }
            entity.importFromRawData(sortedNames)
            # $stderr.puts "DEBUG: #{__FILE__}:#{__method__}() -> entity =\n#{entity.inspect}"
          else # can't reach here due to SUPPORTED_ASPECTS...
            raise "ERROR: #{File.basename(__FILE__)}: #{__method__} => Reached impossible area of code using annos aspect '#{@aspect.inspect}'?!?"
          end
        end
        @statusName = configResponse(entity)
        #$stderr.puts "DEBUG: @statusName = #{@statusName.inspect} ; @statusMsg = #{@statusMsg.inspect}"
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      #$stderr.puts "DEBUG: resp = #{@resp.inspect}"
      return @resp
    end
    
    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a BioSampleEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to set annos info in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('CountEntity')
        # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser will have access to everything]
        ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbType (:userDb or :sharedDb), dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
        # Get just the one ftypeRow matching the track
        ftypeHash = ftypesHash[@trackName]
        ftypesHash.clear()
        # Track not found
        if(ftypeHash.nil? or ftypeHash.empty?)
          initStatus = @statusName = :'Not Found'
          @statusMsg = "NO_TRK: There is no track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or the track is private and you don't have access)"
        elsif(@aspect != 'count')
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: You can only set the 'count' aspect."
        elsif(entity == :'Unsupported Media Type')
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: The payload is not of type CountEntity."
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a bioSample with a nil entity
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update."
        elsif(ftypeHash['dbNames'].size > 1 or ftypeHash['dbNames'][0].dbType == :sharedDb) # Make sure track is not a template track
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "TEMPLATE_TRACK: You cannot set annos count for template tracks."
        else
          ftypeId = ftypeHash['dbNames'][0].ftypeid
          ftypeCountRecs = @dbu.selectFtypeCountByFtypeid(ftypeId)
          if(!ftypeCountRecs.nil? and !ftypeCountRecs.empty?)
            @dbu.updateNumberOfAnnotationsByFtypeid(ftypeId, entity.count)
          else
            @dbu.insertFtypeCount(ftypeId, entity.count)   
          end
          @statusName = configResponse(entity)
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Track
end ; end ; end # module BRL ; module REST ; module Resources
