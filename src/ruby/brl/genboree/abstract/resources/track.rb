#!/usr/bin/env ruby
require 'thread'
require 'rack'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/ucscBigFile'
require 'brl/rest/resource'
require 'brl/genboree/abstract/resources/tracks'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/helpers'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources

  # This class provides methods for managing a track
  class Track

    UCSC_TRACK_STANZA_REQD  = [ 'track', 'type', 'bigDataUrl', 'shortLabel', 'longLabel' ]
    UCSC_WINDOWING_MAP      = { 'max' => 'maximum', 'min' => 'minimum', 'avg' => 'mean', 'mean+whiskers' => 'mean+whiskers' }

    # Set up a class-level cache to store repeatedly-accessed things over the course of a given request.
    # Because much of this cached data based on things the user or jobs do, we require caching by a
    # code-given 'sessionId'. Code wanting to benefit from a cache during repeated access (e.g. each
    # track in a list or in whole database will access much of the same stuff over and over) will:
    #     1. Generate a unqiue session id (this will set up the cache for that session)
    #     2. Set the session id for any object of this class they use
    #     3. Call methods on the object...some which may know how to use a session cache, if there is one.
    #     4. Invalidate the session id (this will remove the cache for that session)
    # NOTE: intended for a tight, short, block of code accessing multiple tracks in a single user database and
    # its associated template database. DON'T SHARE session ids ACROSSS USER DBS. Clear session id cache when done.
    class << self
      attr_accessor :sessionCache

      # Generate and return a session id, init cache for this session
      def generateSessionId()
        retVal = String.generateUniqueString()
        @sessionCache[retVal] = {}
        return retVal
      end

      # Invalidate a session id
      def invalidateSessionId(sessId)
        @sessionCache.delete(sessId)
      end
    end
    # The "class instance" variable:
    @sessionCache = Hash.new { |hh, kk| hh[kk] = {} }

    # The default class to use, keyed by format. Special key :unknownFormat is used to get
    #   the fallback class to use when the dev has not updated this constant. A @nil@ class
    #   indicates the format itself has class info or is otherwise not applicable.
    # @return [Hash]
    DEFAULT_CLASSES = {
      :WIG            => "High Density Score Data",
      :FWIG           => "High Density Score Data",
      :VWIG           => "High Density Score Data",
      :BIGWIG         => "High Density Score Data",
      :BEDGRAPH       => "High Density Score Data",
      :LFF            => nil,
      :GBTABBEDDBRECS => nil,
      :BED            => "User Data",
      :BIGBED         => "User Data",
      :BED3COL        => "User Data",
      :GFF            => "User Data",
      :GFF3           => "User Data",
      :LAYOUT         => nil,
      :unknownFormat  => "User Data"
    }

    # DBUtil object
    attr_accessor :dbu
    # refSeqId of the database that the track is in
    attr_accessor :refSeqId
    # The method part of the track name
    attr_accessor :fmethod
    # The source part of the track name
    attr_accessor :fsource
    # Typically it would contain 2 elements the first being the local (user) database and the last being the template (shared) db
    attr_accessor :dbRecs
    # Track name accessor
    attr_accessor :trackName

    attr_accessor :ftypeAttributesHash
    attr_accessor :sessionId

    # This struct contains the detail for the different databases that may contain information about the track
    # [+dbName+]    The database name (genboree_r_200f...)
    # [+ftypeid+]   The ftypeId for the track in the database
    # [+dbType+]    Either :userDb (local) or :sharedDb (template)
    DbRec = Struct.new(:dbName, :ftypeid, :dbType)

    # Constructor
    # Note that this will set the dbUtil object to the template database
    def initialize(dbu, refSeqId, fmethod, fsource, sessionId=nil)
      @sessionId = sessionId # can start off nil; using code will set using new() or via trkObj.sessionId = Track.generateSessionId
      @dbu, @refSeqId, @fmethod, @fsource = dbu, refSeqId, fmethod, fsource
      @trackName = "#{@fmethod}:#{@fsource}"
      # hierarchical array of database resources which include dbName, ftypeId, and dbType
      @dbRecs = loadAvailableDbRecs()
      @sessionId = sessionId # can start off nil; using code will set using new() or via trkObj.sessionId = Track.generateSessionId
      @ftypeAttributesHash = nil
      @globalTrkHash = nil
    end

    # Explicit clean up to help prevent memory leaks
    def clear()
      @trackName = @refSeqId = @fmethod = @fsource = @sessionId = nil
      @dbRecs.clear() if(@dbRecs)
      @ftypeAttributesHash.clear() if(@ftypeAttributesHash)
    end

    # This method will get the name of a track from the refSeqId and ftypeId
    #
    # [+dbu+]       DBUtil instance
    # [+refSeqId+]  database ID
    # [+ftypeId+]   track ID
    # [+returns+]   The name of the Track (Method:Source)
    def self.getName(dbu, refSeqId, ftypeId)
      dbNames = dbu.selectDBNameByRefSeqID(refSeqId)
      userDBName = dbNames.first['databaseName'] # array of DBI::Rows returned, get actual name String
      dbu.setNewDataDb(userDBName)
      ftypeRows = dbu.selectFtypesByIds([ftypeId])
      track = ftypeRows.first
      return track['fmethod'] + ":" + track['fsource']
    end

    # Return the default track class name given a format symbol
    # @param [Symbol,String] formatSym The uppercase format {Symbol} from, say, @repFormat@
    #   of the Rest Resource class. A key in DEFAULT_CLASSES. If it's a {String}, it will
    #   be converted automatically using @formatSym.upcase.to_sym@
    # @return [String,nil] the default class name or nil if not applicable for format
    def self.getDefaultClass(formatSym)
      # Is the arg a Symbol? If not, we'll convert it as should be appropriate
      unless(formatSym.is_a?(Symbol))
        formatSym = formatSym.to_s.upcase.to_sym
      end
      if(Abstraction::Track::DEFAULT_CLASSES.key?(formatSym))
        className = Abstraction::Track::DEFAULT_CLASSES[formatSym]
      else  # Not a known format...dev bug, didn't update DEFAULT_CLASSES in BRL::Genboree::Abstract::Track. Use fallback :(
        className = Abstraction::Track::DEFAULT_CLASSES[:unknownFormat]
      end
      return className
    end

    # Initializes global hash for storing detailed entity information for tracks
    # Note: Can work for one or more tracks
    # [+ftypesHash+]
    # [+returns] nil
    def self.initGlobalTrkHash(ftypesHash)
      @globalTrkHash = Hash.new { |hh, kk| # kk => trackname
        hh[kk] = {
          :attributes => Hash.new { |gg, mm| # mm => attribute name
            gg[mm] = {
              :value => "",
              :defaultDisplay => {
                :rank => "",
                :color => "",
                :flags => ""
              },
              :display => {
                :rank => "",
                :color => "",
                :flags => ""
              }
            }
          },
          :url => "",
          :urlLabel => "",
          :description => "",
          :classes => {},
          :annoAttributes => {}
        }
      }
    end

    # Initialize Hash for storing ftypeids for user and shared dbs by database names
    # Note: Can work for one or more tracks
    # [+ftypesHash+]
    # [+returns] ftypesDbHash
    def self.initFtypesDbHash(ftypesHash)

      ftypesDbHash = {
                           :userDb => {},
                           :sharedDb => {}
                      }
      ftypesHash.each_key { |key|
        dbNames = ftypesHash[key]['dbNames']
        dbNames.each { |db|
          dbName = db['dbName']
          ftypeid = db['ftypeid']
          dbType = db['dbType']
          if(!ftypesDbHash[dbType].has_key?(dbName))
            tmpHash = {}
            tmpHash[dbName] = [ftypeid]
            ftypesDbHash[dbType] = tmpHash
          else
            ftypesDbHash[dbType][dbName] << ftypeid
          end
        }
      }
      return ftypesDbHash
    end

    # Updates the globaltrack hash with the attributes including the display and default display for each attribute
    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+returns] nil
    def self.updateGlobalTrkHashWithAttributes(ftypeidList)
      # Make the query without any user
      attributesInfoRecs = @dbu.selectFtypeAttributesInfoByFtypeIdList(ftypeidList)
      attributesInfoRecs.each { |rec|
        @globalTrkHash[rec['trackName']][:attributes][rec['name']][:value] = rec['value']
      }
      # Make the query with the default user: 0
      attributesInfoRecs = @dbu.selectFtypeAttributesInfoByFtypeIdList(ftypeidList, 0)
      attributesInfoRecs.each { |rec|
        defaultDisplayHash = @globalTrkHash[rec['trackName']][:attributes][rec['name']][:defaultDisplay]
        defaultDisplayHash[:rank] = rec['rank']
        defaultDisplayHash[:color] = rec['color']
        defaultDisplayHash[:flags] = rec['flags']
      }
      # Make the query with the user: @userId
      attributesInfoRecs = @dbu.selectFtypeAttributesInfoByFtypeIdList(ftypeidList, @userId)
      attributesInfoRecs.each { |rec|
        displayHash = @globalTrkHash[rec['trackName']][:attributes][rec['name']][:display]
        displayHash[:rank] = rec['rank']
        displayHash[:color] = rec['color']
        displayHash[:flags] = rec['flags']
      }
    end

    # Updates the globaltrack hash with 'description', 'url' and 'urlLabel' for each track
    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+returns] nil
    def self.updateGlobalTrkHashWithUrlInfo(ftypeidList)
      urlRecs = @dbu.selectFeatureurlByFtypeIds(ftypeIdList)
      urlRecs.each { |rec|
        tmpTrkHash = @globalTrkHash[rec['trackName']]
        tmpTrkHash[:description] = rec['description']
        tmpTrkHash[:url] = rec['url']
        tmpTrkHash[:urlLabel] = rec['label']
      }
    end

    # Updates the globalTrkHash with the required fields: attributes, class, url, urlLabel, description and annoAttributes
    # [+globalTrkHash+]
    # [+sharedDbs+]
    # [+userDb+]
    # [+dbu+]
    # [+returns+] globalTrkHash
    def self.updateGlobalTrkHash(globalTrkHash, sharedDbs, userDb, dbu)
      # First we will get the attributes
      sharedDbs.each_key { |key|
        ftypeidList = sharedDbs[key]
        dbu.setNewDataDb(key)
        updateGlobalTrkHashWithAttributes(ftypeidList)
      }
      userDb.each_key { |key|
        ftypeidList = userDb[key]
        dbu.setNewDataDb(key)
        updateGlobalTrkHashWithAttributes(ftypeidList)
      }
      # Next get the description, url and labels
      sharedDbs.each_key { |key|
        ftypeidList = sharedDbs[key]
        dbu.setNewDataDb(key)
        updateGlobalTrkHashWithUrlInfo(ftypeidList)
      }
      userDb.each_key { |key|
        ftypeidList = userDb[key]
        dbu.setNewDataDb(key)
        updateGlobalTrkHashWithUrlInfo(ftypeidList)
      }
      # Next get the classes
      sharedDbs.each_key { |key|
        ftypeidList = sharedDbs[key]
        dbu.setNewDataDb(key)
        classRecs = dbu.selectAllFtypeClasses(ftypeidList)
        classRecs.each { |rec|
          classRecs.each { |rec|
            globalTrkHash[rec['trackName']][:class] = rec['glcass']
          }
        }
      }
      userDb.each_key { |key|
        ftypeidList = userDb[key]
        dbu.setNewDataDb(key)
        classRecs = dbu.selectAllFtypeClasses(ftypeidList)
        classRecs.each { |rec|
          classRecs.each { |rec|
            globalTrkHash[rec['trackName']][:class] = rec['glcass']
          }
        }
      }
      # Finally get the annoAttributes
      sharedDbs.each_key { |key|
        ftypeidList = sharedDbs[key]
        dbu.setNewDataDb(key)
        ftype2AttributeNameRecs = dbu.selectFtype2AttributeNameByFtypeidList(ftypeidList)
        attNameIds = []
        ftype2AttributeNameRecs.each { |rec|
          attNameIds << rec['attNameId']
        }
        attrNameRows = dbu.selectAttributesByIds(attrIds)
        attrNames = {}
        attrNameRows.each { |row|
          next if(row['name'].empty?) # skip empty string attribute if there...should NOT BE
          attrNames[row['name']] = true
        }
      }
      userDb.each_key { |key|
        ftypeidList = userDb[key]
        dbu.setNewDataDb(key)
        dbu.setNewDataDb(key)
        ftype2AttributeNameRecs = dbu.selectFtype2AttributeNameByFtypeidList(ftypeidList)
        attNameIds = []
        ftype2AttributeNameRecs.each { |rec|
          attNameIds << rec['attNameId']
        }
        attrNameRows = dbu.selectAttributesByIds(attrIds)
        attrNames = {}
        attrNameRows.each { |row|
          next if(row['name'].empty?) # skip empty string attribute if there...should NOT BE
          attrNames[row['name']] = true
        }
      }
    end

    # Session create/destroy...see notes above!
    def getFromSessionCache(key, subKey=nil, subSubKey=nil)
      retVal = nil
      if(@sessionId)
        if(key)
          sessionCache = Track.sessionCache[@sessionId]
          if(sessionCache)
            keySessionCache = sessionCache[key]
            if(subKey and keySessionCache)
              subSessionCache = keySessionCache[subKey]
              if(subSubKey and subSessionCache)
                retVal = subSessionCache[subSubKey]
              else # no subSubKey
                retVal = keySessionCache[subKey]
              end
            else # no subKey
              retVal = keySessionCache
            end
          end
        end
      end
      return retVal
    end

    def setInSessionCache(value, key, subKey=nil, subSubKey=nil)
      retVal = nil
      if(@sessionId)
        if(key)
          sessionCache = Track.sessionCache[@sessionId]
          if(sessionCache)
            if(subKey)
              sessionCache[key] = {} unless(sessionCache[key].is_a?(Hash))
              if(subSubKey)
                sessionCache[key][subKey] = {} unless(sessionCache[key][subKey].is_a?(Hash))
                retVal = sessionCache[key][subKey][subSubKey] = value
              else # no subSubKey
                retVal = sessionCache[key][subKey] = value
              end
            else # just key
              retVal = sessionCache[key] = value
            end
          end
        end
      end
      return retVal
    end

    # This method is mainly used when initializing the object.
    # It gets all the DBs and sorts them so that the user/local DB is first.
    #
    # Requires certain instance variable to be set: @refSeqId
    # Uses a struct for Database Resources, DbRec
    #
    # [+returns+] Array of DbRec Structs (dbName, ftypeid, dbType)
    def loadAvailableDbRecs()
      # IMPORTANT: we will use two completely different approaches depending on
      # whether smart code is using the session-caching feature (10x faster for loops of tracks in same database)
      # or the old, non-caching, many many table queries approach.
      # This will all depend on whether sessionId is available or not
      if(@sessionId) # use fast caching based approach
        # Get the userDB refseq DB name (this has priority over shared/template dbs)
        userDBName = getFromSessionCache(:userDBNameForRefSeqId, @refSeqId)
        unless(userDBName) # not cached, get manually
          userDBName = @dbu.selectDBNameByRefSeqID(@refSeqId)
          userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
          setInSessionCache(userDBName, :userDBNameForRefSeqId, @refSeqId)
        end

        # Get all refseq DB names (userDB & shared/template DB, using useDBName as sort)
        allDBs = getFromSessionCache(:allDBsForRefSeqId, @refSeqId, userDBName)
        unless(allDBs) # not cached, get manually
          allDBs = dbu.selectDBNamesByRefSeqID(@refSeqId)
          # sort the records
          allDBs.sort! { |aa, bb| # make sure -user- database is at first of list
            if(aa['databaseName'] == userDBName)
              retVal = -1
            elsif(bb['databaseName'] == userDBName)
              retVal = 1
            else
              retVal = aa['databaseName'] <=> bb['databaseName']
            end
          }
          # store in cache (if configured)
          setInSessionCache(allDBs, :allDBsForRefSeqId, @refSeqId, userDBName)
        end

        # Create dbRecs (databases where this track exists)
        dbRecs = []
        allDBs.each { |uploadRow|
          dbName = uploadRow['databaseName']
          # Get map of trackName => [DbRecs] for all tracks in dbRefSeqId (and related databases)
          map = getAllTrackDbRecsMap(dbName, userDBName)
          dbRec = map[@trackName]
          dbRecs << dbRec unless(dbRec.nil?)
        }
      else # use track-by-track approach
        dbRecs = []
        # Get all refseq DB names (userDB & shared/template DB)
        allDBs = dbu.selectDBNamesByRefSeqID(@refSeqId)
        # Get the userDB refseq DB name (this has priority over shared/template dbs)
        userDBName = dbu.selectDBNameByRefSeqID(@refSeqId)
        userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
        allDBs.sort! { |aa, bb| # make sure -user- database is at first of list
          if(aa['databaseName'] == userDBName)
            retVal = -1
          elsif(bb['databaseName'] == userDBName)
            retVal = 1
          else
            retVal = (aa['databaseName'] <=> bb['databaseName'])
          end
          retVal
        }
        allDBs.each { |uploadRow|
          dbName = uploadRow['databaseName']
          refseqRows = @dbu.selectRefseqByDatabaseName(dbName)
          dbRefSeqId = refseqRows.first['refSeqId']
          refseqRows.clear()
          @dbu.setNewDataDb(dbName)
          ftypeRow = @dbu.selectFtypeByTrackName(@trackName)
          # Flag the db type, so we can identify which is which
          dbType = (dbName == userDBName) ? :userDb : :sharedDb
          ftypeId = (ftypeRow.nil? or ftypeRow.empty?) ? nil : ftypeRow.first['ftypeid']
          dbRec = DbRec.new(dbName, ftypeId, dbType)
          dbRecs << dbRec
        }
        allDBs.clear()
      end
      return dbRecs
    end

    # [+returns+] trackName => DbRec for ALL tracks in dbName, using userDBName to determine the dbType
    def getAllTrackDbRecsMap(dbName, userDBName)
      map = getFromSessionCache(:allTracksDbRecMap, dbName, userDBName)
      unless(map) # not cached, get manually
        map = {}
        # Determine the dbType
        dbType = (dbName == userDBName) ? :userDb : :sharedDb
        # Next, we need the refseqid for dbName
        dbRefSeqId = getFromSessionCache(:refSeqIdForDbName, dbName)
        unless(dbRefSeqId) # not cached, get manually
          refseqRows = @dbu.selectRefseqByDatabaseName(dbName)
          dbRefSeqId = refseqRows.first['refSeqId']
          setInSessionCache(dbRefSeqId, :refSeqIdForDbName, dbName)
        end
        # Get all ftype records
        @dbu.setNewDataDb(dbName)
        allFtypeRows = @dbu.selectAllFtypes()
        # Loop over all the ftype rows and make the DbRec objects and store in map
        allFtypeRows.each { |row|
          ftypeId = row['ftypeid']
          trackName = "#{row['fmethod']}:#{row['fsource']}"
          dbRec = DbRec.new(dbName, ftypeId, dbType)
          map[trackName] = dbRec
        }
        # Cache result, if configured
        setInSessionCache(map, :allTracksDbRecMap, dbName, userDBName)
      end
      return map
    end

    # Does the track exist in any of the databases?
    #[+returns+] boolean
    def exists?
      trackExists = false
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        if(!dbRec.ftypeid.nil?)
          trackExists = true
          break
        end
      }
      return trackExists
    end

    # Has the track been blocked for annotation download?
    def annoDownloadBlocked?()
      nonDownloadValue = self.getAttributeValueByName('gbNotDownloadable')
      retVal = (nonDownloadValue.nil? or nonDownloadValue.empty? or nonDownloadValue.strip !~ /^(?:true|yes)$/i) ? false : true
      return retVal
    end

    # for debuggging
    # [+returns+] @dbRecs Array of DbRec Structs
    def getDbRecs()
      return @dbRecs
    end

    # Use this to get the database resource that refers to the database that
    # contains the track annotation data (records in fdata2)
    #
    # [+returns+] dbRec
    def getDbRecWithFdata()
      retVal = nil
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        annoCountRow = @dbu.selectFdataExistsForFtypeId(dbRec.ftypeid)
        if(!annoCountRow.nil? and !annoCountRow.empty?)
          retVal = dbRec
          break
        end
      }
      return retVal
    end

    # Use this to get the database resource that refers to the database that
    # contains the track annotation data (records in fdata2 or blockLevelDataInfo)
    #
    # [+returns+] dbRec
    def getDbRecWithData()
      retVal = nil
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        annoCountRow = @dbu.selectFdataExistsForFtypeId(dbRec.ftypeid)
        if(!annoCountRow.nil? and !annoCountRow.empty?)
          retVal = dbRec
          break
        else
          recordCountRows = @dbu.selectBlockLevelDataExistsForFtypeId(dbRec.ftypeid)
          if(!recordCountRows.nil? and !recordCountRows.empty?)
            retVal = dbRec
            break
          end
        end
      }
      return retVal
    end

    def getDbRecsWithData()
      retVal = []
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        annoCountRow = @dbu.selectFdataExistsForFtypeId(dbRec.ftypeid)
        if(!annoCountRow.nil? and !annoCountRow.empty?)
          retVal << dbRec
        else
          recordCountRows = @dbu.selectBlockLevelDataExistsForFtypeId(dbRec.ftypeid)
          if(!recordCountRows.nil? and !recordCountRows.empty?)
            retVal << dbRec
          end
        end
      }
      return retVal
    end
    # Determines whether the track has fdata2 records
    #
    # [+returns+] bool
    def hasFdata2Data?()
      retVal = false
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        annoCountRow = @dbu.selectFdataExistsForFtypeId(dbRec.ftypeid)
        if(!annoCountRow.nil? and !annoCountRow.empty?)
          retVal = true
          break
        end
      }
      return retVal
    end

    # Determines whether the track has blockLevelDataInfo records
    #
    # [+returns+] bool
    def hasBlockLevelData?()
      retVal = false
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        recordCountRows = @dbu.selectBlockLevelDataExistsForFtypeId(dbRec.ftypeid)
        if(!recordCountRows.nil? and !recordCountRows.empty?)
          retVal = true
          break
        end
      }
      return retVal
    end

    # Determines whether the track has either fdata2 records or blockLevelDataInfo records
    #
    # [+returns+] bool
    def hasAnnotations?()
      retVal = false
      if(hasFdata2Data?())
        retVal = true
      elsif(isHdhv?())
        retVal = true
      end
      return retVal
    end

    # Get the number of annotations (fdata2 records)
    #
    # [+returns+] int: number of annotations
    def getFdata2AnnotationCount()
      retVal = 0
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        annoCountRow = @dbu.selectFdataCountByFtypeId(dbRec.ftypeid)
        if(!annoCountRow.nil? and annoCountRow.first > 0)
          retVal += annoCountRow.first
        end
      }
      return retVal
    end

    # Get the number of annotations (blockLevelDataInfo records)
    #
    # [+returns+] int: number of annotations
    def getNumRecordCount()
      retVal = 0
      # loop through the dbRecs checking for fdata2 records for the track
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        recordCountRows = @dbu.selectNumRecordCountByFtypeId(dbRec.ftypeid)
        if(!recordCountRows.nil? and !recordCountRows.first['numRecordCount'].nil? and recordCountRows.first['numRecordCount'] > 0)
          retVal += recordCountRows.first['numRecordCount']
        end
      }
      return retVal
    end

    # Get the number of annotations from either fdata2 or blockLevelDataInfo
    #
    # [+returns+] int: number of annotations
    def getAnnotationCount()
      retVal = 0
      if(hasFdata2Data?())
        retVal = getFdata2AnnotationCount()
      elsif(isHdhv?())
        retVal = getNumRecordCount()
      end
      return retVal
    end

    def isHdhv?()
      retVal = false
      # loop through the dbRecs checking for fdata2 records for the track
      origDataDb = (@dbu.dataDbName ? @dbu.dataDbName : nil)
      @dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        retVal = @dbu.isHDHV?(dbRec.ftypeid)
        break if(retVal)
      }
      @dbu.setNewDataDb(origDataDb) if(origDataDb)
      return retVal
    end

    # A track is eligible to be exported to bigWig if it uses hdhv data or has the attribute bigWigAvailable
    def isBigWigAvailable?()
      # get attributes
      attrHash = getAttributeNamesAndValues()
      return (isHdhv? or attrHash['bigWigAvailable'] == 'true')
    end

    # Methods that control the availability of the BigBed feature
    def isBigBedAvailable?()
      # Currently available for all tracks
      return true
    end

    # This method returns
    def getConstantSpan()
      retVal = nil
      if(hasFdata2Data?())
        spanRows = @dbu.selectDataSpanByFtypeId(ftypeId, 2)
        if(spanRows.count == 1)
          retVal = spanRows.first['span'] + 1 # Add 1 because start and stop are included in the annotation
        end
      elsif(isHdhv?())
        # Should be a track attribute that is determined during import
        #retVal =
      end
      return retVal
    end

    # Determines whether a file format is allowed for the track
    #
    # [+formatSym+]   The format of the file, :LFF, WIG
    # [+returns+]     boolean
    def isFormatAllowed?(formatSym)
      retVal = true
      # get attributes
      attrHash = getAttributeNamesAndValues()
      if(isHdhv?)
        retVal = (formatSym == :BED or formatSym == :WIG or formatSym == :VWIG or formatSym == :VWIG or formatSym == :bedGraph)
      else # not blockBased
        if(formatSym == :WIG)
          if(attrHash['bigWigAvailable'] == 'true')
            retVal = true
          else
            retVal = false
          end
        else # fine for any other format
          retVal = true
        end
      end
      return retVal
    end

    # Ensures that the ftype record exists in the user Db for the track
    #
    # Use this method when adding a new track to a database
    #
    # [+returns+] @dbRecs.first.ftypeid
    def createLocalFtype()
      # If there isn't a ftype record in the userDB, create one
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      if(@dbRecs.first.ftypeid.nil?)
        @dbu.insertFtype(@fmethod, @fsource)
        @dbRecs.first.ftypeid = @dbu.dataDbh.func('insert_id')
      end
      return @dbRecs.first.ftypeid
    end
    alias getLocalFtypeId createLocalFtype

    def localFtypeExists?()
      @dbRecs.first.ftypeid.nil? and @dbRecs.last.dbType == :userDb
    end

    # Returns true/false if the track is a Template track
    # [+returns+] boolean
    def fromTemplate?()
      @dbRecs.last.dbType == :sharedDb and !@dbRecs.last.ftypeid.nil?
    end

    # Looks at all databases, getting the first non-nil value specified by colName from featureurl.
    # [+colName+]   The desired column name from the featureurl table
    # [+returns+]   The value of colName
    def getFeatureUrlValue(colName)
      retVal = ''
      # Loop through the dbs getting the first non-nil value
      @dbRecs.each { |dbRec|
        next if(dbRec.ftypeid.nil?)
        @dbu.setNewDataDb(dbRec.dbName)
        featureRows = @dbu.selectFeatureurlByFtypeId(dbRec.ftypeid)
        unless(featureRows.nil? or featureRows.empty?)
          retVal = featureRows.first[colName]
          break if(!retVal.nil?)
        end
      }
      return retVal
    end

    # Looks at all databases, getting the first non-nil value
    #
    # [+onlyFirstSentence+]   bool: optionally get only the first sentence
    # [+charLimit+]           int: truncate the text to charLimit characters and append '...'
    # [+returns+]             the track description
    def getDescription(onlyFirstSentence=false, charLimit=nil)
      description = getFeatureUrlValue('description')
      if(!description.nil? and !description.empty?)
        if(onlyFirstSentence)
          sentences = description.split(/[.?!](?:\s|<)/)
          description = sentences.first
        end
        if(!charLimit.nil?)
          description = description[0..charLimit] + "..."
        end
      end
      return description
    end

    # [+returns+] trackName => descriptions for all tracks in @refSeqId
    def getTrackDescMap(onlyFirstSentence=false)
      map = getFromSessionCache(:allTracksDescMap, @refSeqId)
      unless(map) # not cached, get manually
        map = {}
        # Loop through the DbRecs (user > shared, start with shared and visit all to get full and final map)
        revDbRecs = @dbRecs.reverse
        revDbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          rows = @dbu.selectTracksDescMap()
          unless(rows.nil? or rows.empty?)
            rows.each { |row|
              if(onlyFirstSentence)
                sentences = row['description'].split(/[.?!](?:\s|<)/)
                desc = sentences.first
              else
                desc = row['description']
              end
              trkName = row['trackName']
              map[trkName] = desc
            }
          end
        }
        setInSessionCache(map, :allTracksDescMap, @refSeqId)
      end
      return map
    end

    # Looks at all databases, getting the first non-nil value
    # [+returns+] the track url
    def getUrl()
      getFeatureUrlValue('url')
    end

    # Looks at all databases, getting the first non-nil value
    # [+returns+] the track url label
    def getUrlLabel()
      getFeatureUrlValue('label')
    end

    # Gets the value specified by colName from featureurl from the template Db
    # [+colName+]   The desired column name from the featureurl table
    # [+returns+]   The value specified by colName from featureurl.
    def getTemplateFeatureUrlValue(colName)
      retVal = nil
      if(@dbRecs.last.dbType == :shareDb and @dbRecs.last.ftypeid.nil?)
        retVal = BRL::Genboree::GenboreeError.new(:'Bad Request', '')
      else
        @dbu.setNewDataDb(@dbRecs.last.dbName)
        featureRows = @dbu.selectFeatureurlByFtypeId(@dbRecs.last.ftypeid)
        unless(featureRows.nil? or featureRows.empty?)
          retVal = featureRows.first[colName]
        end
      end
      return retVal
    end

    # Method for updating the track url, label or description
    # The ftype and/or featureurl records will be created if they don't already exits
    # [+colName+] The desired column name from the featureurl table
    # [+newValue+]  The new value of colName
    # [+returns+]   Number of rows updated
    def setFeatureUrlValue(colName, newValue)
      raise ArgumentError unless(colName == 'url' or colName == 'description' or colName == 'label')
      createLocalFtype()
      # Determine if there is already a feature url record for this ftypeid, if there isn't create one
      featureRows = @dbu.selectFeatureurlByFtypeId(@dbRecs.first.ftypeid)
      if(featureRows.nil? or featureRows.empty?)
        @dbu.insertFeatureurl(@dbRecs.first.ftypeid, nil, nil, nil)
      end
      return @dbu.updateFeatureurlByFtypeId(@dbRecs.first.ftypeid, {colName => newValue})
    end

    #############
    ## COLOR
    #############

    # Gets the track's color for the specified userId
    # [+userId+]  The userId for whom the color will be retrieved
    # [+returns+] The Color of the track in RGB Hex
    def getColorForUserId(userId)
      raise ArgumentError unless(userId.is_a?(Integer))
      # Get from cache
      retVal = getFromSessionCache(@trackName, :colorByUserId, userId)
      unless(retVal) # not cached, get manually
        # Loop through the dbs getting the first non-nil value
        @dbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          featureRow = @dbu.selectColorByFtypeIdUserId(dbRec.ftypeid, userId)
          unless(featureRow.nil? or featureRow.empty?)
            retVal = featureRow['value']
            break if(!retVal.nil?)
          end
        }
        setInSessionCache(retVal, @trackName, :colorByUserId, userId)
      end
      return retVal
    end

    # [+returns+] trackName => hexcolor for all tracks in @refSeqId for userId
    def getTrackColorMap(userId=0)
      map = getFromSessionCache(:allTracksColorMap, @refSeqId, userId)
      unless(map) # not cached, get manually
        map = {}
        # Loop through the DbRecs (user > shared, start with shared and visit all to get full and final map)
        revDbRecs = @dbRecs.reverse
        revDbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          rows = @dbu.selectTracksColorMap(userId)
          unless(rows.nil? or rows.empty?)
            rows.each { |row|
              trkName = row['trackName']
              color = row['value']
              map[trkName] = color
            }
          end
        }
        setInSessionCache(map, :allTracksColorMap, @refSeqId, userId)
      end
      return map
    end

    # Sets the color for a userId
    # [+colorValue+]  The new color value for the track in RGB Hex
    # [+userId+]      The userId for whom the color will be set
    # [+returns+\     Number of rows inserted
    def setColorForUserId(colorValue, userId)
      retVal = nil
      # Create local ftype record if it doesn't exist
      createLocalFtype()
      colorId = TrackColor.getColorId(@dbu, colorValue)
      # Delete and then insert
      deleteColorForUserId(userId)
      retVal = @dbu.insertRecords(:userDB, 'featuretocolor', [@dbRecs.first.ftypeid, userId, colorId], false, 1, 3, true, 'Track.setColorForUserId()')
      return retVal
    end

    # Delete the tracks color setting for a specified userId
    # [+userId+]      The userId for whom the color will be deleted
    # [+returns+]     number of rows deleted
    def deleteColorForUserId(userId)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      @dbu.deleteByMultipleFieldsAndValues(:userDB, 'featuretocolor', {'ftypeid'=>@dbRecs.first.ftypeid, 'userId'=>userId}, :and, 'Track.deleteColorForUserId()')
    end

    ###########
    ## STYLE
    ###########

    # [+userId+]    The userId for whom the style setting will be retrieved
    # [+returns+]   The style setting
    def getStyleForUserId(userId)
      raise ArgumentError unless(userId.is_a?(Integer))
      # Get from cache
      retVal = getFromSessionCache(@trackName, :styleByUserId, userId)
      unless(retVal) # not cached, get manually
        # Loop through the dbs getting the first non-nil value
        @dbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          featureRow = @dbu.selectStyleByFtypeIdUserId(dbRec.ftypeid, userId)
          unless(featureRow.nil? or featureRow.empty?)
            retVal = featureRow['description']
            break if(!retVal.nil?)
          end
        }
        setInSessionCache(retVal, @trackName, :styleByUserId, userId)
      end
      return retVal
    end

    # [+returns+] trackName => style long name for all tracks in @refSeqId for userId
    def getTrackStyleMap(userId=0)
      map = getFromSessionCache(:allTracksStyleMap, @refSeqId, userId)
      unless(map) # not cached, get manually
        map = {}
        # Loop through the DbRecs (user > shared, start with shared and visit all to get full and final map)
        revDbRecs = @dbRecs.reverse
        revDbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          rows = @dbu.selectTracksStyleMap(userId)
          unless(rows.nil? or rows.empty?)
            rows.each { |row|
              trkName = row['trackName']
              styleName = row['description']
              map[trkName] = styleName
            }
          end
        }
        setInSessionCache(map, :allTracksStyleMap, @refSeqId, userId)
      end
      return map
    end

    # [+userId+]      The userId for whom the style setting will be set
    # [+styleValue+]  The new style value for the track
    # [+returns+\     Number of rows inserted
    def setStyleForUserId(styleValue, userId)
      retVal = nil
      # Create local ftype record if it doesn't exist
      createLocalFtype()
      styleId = TrackStyle.getStyleId(@dbu, styleValue)
      # Delete and then insert
      deleteStyleForUserId(userId)
      retVal = @dbu.insertRecords(:userDB, 'featuretostyle', [@dbRecs.first.ftypeid, userId, styleId], false, 1, 3, true, 'Track.setStyleForUserId()')
      return retVal
    end

    # [+userId+]    The userId for whom the style setting will be deleted
    # [+returns+]   Number of rows deleted
    def deleteStyleForUserId(userId)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      @dbu.deleteByMultipleFieldsAndValues(:userDB, 'featuretostyle', {'ftypeid'=>@dbRecs.first.ftypeid, 'userId'=>userId}, :and, 'Track.deleteStyleForUserId()')
    end

    ###########
    ## Display
    ###########

    # [+userId+]         The userId for whom the display setting will be retrived
    # [+returns+]        The Display setting for the userId
    def getDisplayForUserId(userId)
      raise ArgumentError unless(userId.is_a?(Integer))
      retVal = ''
      # Loop through the dbs getting the first non-nil value
      @dbRecs.each { |dbRec|
        next if(dbRec.ftypeid.nil?)
        @dbu.setNewDataDb(dbRec.dbName)
        featureRow = @dbu.selectDisplayByFtypeIdUserId(dbRec.ftypeid, userId)
        unless(featureRow.nil? or featureRow.empty?)
          retVal = BRL::Genboree::Constants::TRACK_DISPLAY_TYPES[featureRow.first['display']]
          break if(!retVal.nil?)
        end
      }
      return retVal
    end

    # [+userId+]         The userId for whom the display setting will be set
    # [+displayValue+]   The new display value for the track
    # [+returns+]        Number of rows inserted
    def setDisplayForUserId(displayValue, userId)
      retVal = nil
      # Create local ftype record if it doesn't exist
      createLocalFtype()
      displayId = TrackDisplay.getDisplayId(displayValue)
      # Delete and then insert
      deleteDisplayForUserId(userId)
      retVal = @dbu.insertRecords(:userDB, 'featuredisplay', [@dbRecs.first.ftypeid, userId, displayId], false, 1, 3, true, 'Track.setDisplayForUserId()')
      return retVal
    end

    # [+userId+]         The userId for whom the display setting will be deleted
    # [+returns+]        Number of rows deleted
    def deleteDisplayForUserId(userId)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      @dbu.deleteByMultipleFieldsAndValues(:userDB, 'featuredisplay', {'ftypeid'=>@dbRecs.first.ftypeid, 'userId'=>userId}, :and, 'Track.deleteDisplayForUserId()')
    end

    ###########
    ## Rank
    ###########

    # [+returns+]
    def getRankForUserId(userId)
      raise ArgumentError unless(userId.is_a?(Integer))
      # Check cache
      retVal = getFromSessionCache(@trackName, :rankByUserId, userId)
      unless(retVal) # not cached, get manually
        # Loop through the dbs getting the first non-nil value
        @dbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          featureRow = @dbu.selectSortByFtypeIdUserId(dbRec.ftypeid, userId)
          unless(featureRow.nil? or featureRow.empty?)
            retVal = featureRow.first['sortkey']
            break if(!retVal.nil?)
          end
        }
        setInSessionCache(retVal, @trackName, :rankByUserId, userId)
      end
      return retVal
    end

    # [+returns+] trackName => sortkey for all tracks in @refSeqId for userId
    def getTrackRankMap(userId=0)
      map = getFromSessionCache(:allTracksRankMap, @refSeqId, userId)
      unless(map) # not cached, get manually
        map = {}
        # Loop through the DbRecs (user > shared, start with shared and visit all to get full and final map)
        revDbRecs = @dbRecs.reverse
        revDbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          rows = @dbu.selectTracksRankMap(userId)
          unless(rows.nil? or rows.empty?)
            rows.each { |row|
              trkName = row['trackName']
              rank = row['sortkey']
              map[trkName] = rank
            }
          end
        }
        setInSessionCache(map, :allTracksRankMap, @refSeqId, userId)
      end
      return map
    end

    # [+value+]   The new rank value for the track
    # [+returns+\ Number of rows inserted
    def setRankForUserId(rankValue, userId)
      retVal = nil
      # Create local ftype record if it doesn't exist
      createLocalFtype()
      # Delete and then insert
      deleteRankForUserId(userId)
      retVal = @dbu.insertRecords(:userDB, 'featuresort', [@dbRecs.first.ftypeid, userId, rankValue], false, 1, 3, true, 'Track.setRankForUserId()')
      return retVal
    end

    # [+returns+]
    def deleteRankForUserId(userId)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      @dbu.deleteByMultipleFieldsAndValues(:userDB, 'featuresort', {'ftypeid'=>@dbRecs.first.ftypeid, 'userId'=>userId}, :and, 'Track.deleteRankForUserId()')
    end

    # [+sortKey+]   The rank of the track
    # [+userId+]    the userId for the rank setting
    # [+returns+]   :OK or GenboreeError object
    def validateRankForUserId(sortKey, userId)
      retVal = :OK
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      if(sortKey.is_a?(Integer) or sortKey.to_i.to_s == sortKey)
        # Tests that sortKey is an integer even if it's datatype is a string (want to avoid just doing to_i as a string could be inadvertantly interpreted as 0)
        # Tie conditions are not allowed
        rankRows = @dbu.selectByMultipleFieldsAndValues(:userDB, 'featuresort', {'sortkey' => sortKey, 'userId' => userId}, :and, 'Track.validateRankForUserId()')
        unless(rankRows.empty?)
          retVal = BRL::Genboree::GenboreeError.new(:'Conflict', "The rank specified in the payload is already in use.  Use a temporary value if swapping values.")
        end
      else
        retVal = BRL::Genboree::GenboreeError.new(:'Bad Request', "The rank specified in the payload is invalid.  Value must be an integer.")
      end
      return retVal
    end

    ##############
    ## Attributes
    ##############

    # [+returns+]
    def getAttributes()
      getAttributeNamesAndValues()
    end

    # [+returns+]
    def getAttributeValueByName(attrName)
      retVal = nil
      @dbRecs.each { |dbRec|
        next if(dbRec.ftypeid.nil?)
        @dbu.setNewDataDb(dbRec.dbName)
        attrRows = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameText(dbRec.ftypeid, attrName)
        unless(attrRows.nil? or attrRows.empty?)
          retVal = attrRows.first['value']
        end
        break if(!retVal.nil?)
      }
      return retVal
    end

    # [+returns+]
    def setAttributeValueByName(attrName, attrValue)
      createLocalFtype()
      # Need to see if Name exists, if not, create it
      attrNameRows = @dbu.selectFtypeAttrNameByName(attrName)
      if(attrNameRows.nil? or attrNameRows.empty?)
        @dbu.insertFtypeAttrName(attrName)
        # get the insert id
        attrNameId = @dbu.dataDbh.func(:insert_id)
      else
        attrNameId = attrNameRows.first['id']
      end
      # Need to see if Value exists, if not, create it
      attrValueRows = @dbu.selectFtypeAttrValueByValue(attrValue)
      if(attrValueRows.nil? or attrValueRows.empty?)
        @dbu.insertFtypeAttrValue(attrValue)
        # get the insert id
        attrValueId = @dbu.dataDbh.func(:insert_id)
      else
        attrValueId = attrValueRows.first['id']
      end
      # This method deletes and inserts so it is safe to use for a create or update
      rows = @dbu.updateFtype2AttributeForFtypeAndAttrName(@dbRecs.first.ftypeid, attrNameId, attrValueId)
      return rows
    end

    # Deletes a track attibute.  Also removes any corresponding ftypAttrDisplays records for all users
    # [+attrName+]  the attribute name to be deleted
    # [+returns+]   number of rows deleted
    def deleteAttributeByName(attrName)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      attrNameRows = @dbu.selectFtypeAttrNameByName(attrName)
      unless(attrNameRows.nil? or attrNameRows.empty?)
        attrNameId = attrNameRows.first['id']
        # delete any display rows for the ftype
        @dbu.deleteByMultipleFieldsAndValues(:userDB, 'ftypeAttrDisplays', {'ftype_id' => @dbRecs.first.ftypeid, 'ftypeAttrName_id' => attrNameId}, :and, 'Track.deleteAttributeByName()')
        rows = @dbu.deleteFtype2AttributesByFtypeIdAndAttrNameId(@dbRecs.first.ftypeid, attrNameId)
      end
      return rows
    end

    # [+returns+]
    def hasAttributeInUserDb?(attrName)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      attrNameRows = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameText(@dbRecs.first.ftypeid, attrName)
      return !attrNameRows.empty?
    end

    # Looks in all Dbs for an ftype2attrbute record
    # [+returns+] boolean
    def hasAttribute?(attrName)
      retVal = nil
      @dbRecs.each { |dbRec|
        next if(dbRec.ftypeid.nil?)
        @dbu.setNewDataDb(dbRec.dbName)
        attrNameRows = @dbu.selectFtypeAttrValueByFtypeIdAndAttributeNameText(dbRec.ftypeid, attrName)
        if(!attrNameRows.empty?)
          retVal = true
          break
        end
      }
      return retVal
    end

    # [+returns+]
    def getAttributeNameIdFromUserDb(attrName)
      retVal = nil
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      attrNameRows = dbu.selectFtypeAttrNameByName(attrName)
      if(!attrNameRows.nil? and !attrNameRows.empty?)
        retVal = attrNameRows.first['id']
      end
      return retVal
    end

    # [+returns+] Hash attrName=>attrValue
    def getAttributeNamesAndValues()
      attrHash = {}
      attrDbRecs = @dbRecs.reverse
      # Loop through the DbRecs starting with the shared Dbs
      attrDbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        attrRows = @dbu.selectFtypeAttributeNamesAndValuesByFtypeId(dbRec.ftypeid)
        if(!attrRows.nil? and !attrRows.empty?)
          attrRows.each { |attrRow|
            attrHash[attrRow['name']] = attrRow['value']
          }
        end
      }
      return attrHash
    end

    # [+returns+] trackName => attrName => attrValue for all tracks in @refSeqId
    def getTrackAVPMap()
      map = getFromSessionCache(:allTracksAVPMap, @refSeqId)
      unless(map) # not cached, get manually
        map = Hash.new { |hh, kk| hh[kk] = {} }
        # Loop through the DbRecs starting with the shared Dbs (user > shared)
        attrDbRecs = @dbRecs.reverse
        attrDbRecs.each { |dbRec|
          next if(dbRec.ftypeid.nil?)
          @dbu.setNewDataDb(dbRec.dbName)
          rows = @dbu.selectTracksAvpMap()
          if(!rows.nil? and !rows.empty?)
            rows.each { |row|
              trkName = row['trackName']
              attrName = row['name']
              attrValue = row['value']
              map[trkName][attrName] = attrValue
            }
          end
        }
        setInSessionCache(map, :allTracksAVPMap, @refSeqId)
      end
      return map
    end

   # This version of getAttributeDisplayForUserId only looks in the local DB
    def getAttributeDisplayForUserId(attrName, userId)
      displayHash = {}
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      attrRow = @dbu.selectFtypeAttrDisplayByUserIdAndFtypeIdAndAttrNameText(userId, @dbRecs.first.ftypeid, attrName)
      if(!attrRow.nil? and !attrRow.empty?)
        displayHash['rank'], displayHash['color'], displayHash['flags'] = attrRow.first['rank'], attrRow.first['color'], attrRow.first['flags']
      end
      return displayHash
    end

    # This version of getAttributeDisplayForUserId only looks in the local DB
    def getAttributeDisplay(attrName, userId=0)
      displayHash = {}
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      # Get the user specific values
      displayHash = getAttributeDisplayForUserId(attrName, userId)
      if(displayHash.empty?)
        # Get the default values
        displayHash = getAttributeDisplayForUserId(attrName, 0)
      end
      return displayHash
    end

    # [+returns+]   :OK or GenboreeError
    def validateAttributeDisplayForUserId(attrName, rank, color, flags, userId)
      retVal = :OK
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      # Check that rank doesn't conflict
      selectData = {'rank' => rank, 'genboreeuser_id' => userId, 'ftype_id' => @dbRecs.first.ftypeid}
      attrDisplayRows = @dbu.selectByMultipleFieldsAndValues(:userDB, 'ftypeAttrDisplays', selectData, :and, 'Track.validateAttributeDisplayForUserId()')
      if(attrDisplayRows.nil? or attrDisplayRows.empty?)
        # Check color is valid format
        if(color =~ /\A#/)
          status = :OK
        else
          retVal = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "The format of the color value is incorrect. Must be in Hexadecimal RGB (#000000)")
        end
      else
        # This throws an exception if the value doesn't exist yet
        attrNameId = getAttributeNameIdFromUserDb(attrName)
        # Don't raise the error if we're looking at the same attribute because that's not a conflict
        unless(attrNameId == attrDisplayRows.first['ftypeAttrName_id'])
          retVal = BRL::Genboree::GenboreeError.new(:Conflict, "The rank specified in the payload is already in use.  Use a temporary value if swapping values.")
        end
      end
      return retVal
    end


    # Ensures that the ftype, ftypeAttrNames, ftypeAttrValues, ftype2attributes records exists in the user Db for the track
    # [+returns+]
    def setAttributeDisplayForUserId(attrName, rank, color, flags, userId)
      # May need to create the the ftype, ftypeAttrNames, ftypeAttrValues, ftype2attributes records first.
      # Mainly required if a user is trying to set display properties for an attribute that only exists in a template Db
      if(!hasAttributeInUserDb?(attrName))
        attrValue = getAttributeValueByName(attrName)
        setAttributeValueByName(attrName, attrValue)
      end
      attrNameId = getAttributeNameIdFromUserDb(attrName)
      deleteAttributeDisplayForUserId(attrName, userId)
      rows = @dbu.insertFtypeAttrDisplay(@dbRecs.first.ftypeid, attrNameId, userId, rank, color, flags)
    end

    # [+returns+]
    def deleteAttributeDisplayForUserId(attrName, userId)
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      attrRow = @dbu.selectFtypeAttrDisplayByUserIdAndFtypeIdAndAttrNameText(userId, @dbRecs.first.ftypeid, attrName)
      if(!attrRow.nil? and !attrRow.empty?)
        rows = @dbu.deleteFtypeAttrDisplayById(attrRow.first['id'])
      end
      return rows
    end

    ###################
    ## Entrypoints
    ###################
    def getEpsForTrack
      epsRows = []
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      rows = @dbu.selectDistinctRidsByFtypeId(@ftypeId)
      if(!rows.nil? and !rows.empty?)
        epsRows = rows
      end
      return epsRows
    end

    ##############
    ## Links
    ##############

    # [+returns+] Hash label=>url
    def getLinks(onlyTemplateLinks=false)
      linkInfo = {}
      # We manipulate this array depending on what we want
      if(onlyTemplateLinks and @dbRecs.last.dbType = :sharedDb)
        # We only want the links from the template Db so get rid of the local Db
        linkDbRecs = [@dbRecs.last]
      else
        # We want links from all Dbs but we process the template Db first so reverse the array
        linkDbRecs = @dbRecs.reverse
      end
      templateDbRec = dbRecs.first
      # Get all the ids from both Dbs first
      linkDbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        ftypeToLinkRows = @dbu.selectByFieldAndValue(:userDB, 'featuretolink', 'ftypeid', dbRec.ftypeid, '')
        unless(ftypeToLinkRows.empty?)
          ftypeToLinkRows.each { |row|
            linkRows = @dbu.selectByFieldAndValue(:userDB, 'link', 'linkId', row['linkId'], '')
            # This wouldn't be a problem if there weren't records in localDb.featuretolink that refer to records in templateDb.link
            # This is caused by the UI and should be phased out, but need the condition below to support the legacy data
            if((linkRows.nil? or linkRows.empty?) and !templateDbRec) # probably looking in localDb but it's in templateDb
              currentDbName = templateDbRec.dbName
              #@dbu.setNewDataDb(@templateDbRec.dbName)
              @dbu.setNewDataDb(currentDbName)
              linkRows = @dbu.selectByFieldAndValue(:userDB, 'link', 'linkId', row['linkId'], '')
              # Return to the original Db
              @dbu.setNewDataDb(currentDbName)
            end
            unless(linkRows.nil? or linkRows.empty?)
              if(linkRows.first['description'] == '')
                # Empty urls (link.description) are allowed and are used to 'hide' template links so drop it
                linkInfo.delete(linkRows.first['name'])
              else
                linkInfo[linkRows.first['name']] = linkRows.first['description']
              end
            end
          }
          ftypeToLinkRows.clear()
        end
      }
      return linkInfo
    end

    # [+returns+]
    def deleteLinksFromUserDb()
      @dbu.setNewDataDb(@dbRecs.first.dbName)
      @dbu.deleteByFieldAndValue(:userDB, 'featuretolink', 'ftypeid', @dbRecs.first.ftypeid, 'Track.restoreTemplateLinks()')
    end

    # Alias for deleteLinksFromUserDb()
    # [+returns+]
    def restoreTemplateLinks()
      deleteLinksFromUserDb()
    end

    # Helper method that creates the records in the link table and then links them to the ftype
    #
    # [+linkHash+] Hash containing links using format 'label'=>'url'.  url can be blank (used to hide links)
    def insertLinks(linkHash)
      createLocalFtype()
      linkHash.each_pair { |linkText, linkUrl|
        linkRows = nil
        # the linkId is a MD5 digest of the label and the url separated by a colon
        linkDigest = Digest::MD5.hexdigest(linkText + ':' + linkUrl)
        # Loop through the Dbs looking for the link
        @dbRecs.each { |dbRec|
          @dbu.setNewDataDb(dbRec.dbName)
          linkRows = @dbu.selectByFieldAndValue(:userDB, 'link', 'linkId', linkDigest, 'Track.insertLinks()')
          break if(!linkRows.empty?)
        }
        @dbu.setNewDataDb(@dbRecs.first.dbName)
        if(linkRows.empty?)
          # The link couldn't be found in any of the accesible Dbs so Insert into local Db
          linkData = [linkDigest, linkText, linkUrl]
          @dbu.insertRecords(:userDB, 'link', linkData, false, 1, 3, false, 'Track.insertLinks()')
        end
        linkToFeaturData = [@dbRecs.first.ftypeid, 0, linkDigest]
        @dbu.insertRecords(:userDB, 'featuretolink', linkToFeaturData, false, 1, 3, false, 'Track.insertLinks()')
      }
    end

    # [+returns+]
    def overwriteLinks(linkHash)
      deleteLinksFromUserDb()
      insertLinks(linkHash)
    end

    # [+returns+]
    def addEmptyLinksFromTemplate(linkHash)
      # Get all the template links
      @dbu.setNewDataDb(@dbRecs.last.dbName)
      templateLinksRows = @dbu.selectLinksByFtypeIdUserId(@dbRecs.last.ftypeid, 0)
      templateLinksRows.each { |linkRow|
        # 'Hide' any links that haven't been included in the payload
        # If a template link is missing from the payload, It should be 'hidden', meaning:
        #   Insert a record into localDb.link with localDb.link.name = templateDb.link.name and localDb.link.description = ''
        #   Insert record into localDb.featuretolink
        if(linkHash[linkRow['name']].nil?) # hasn't been included in the payload
          linkHash[linkRow['name']] = ''
        end
      }
      return linkHash
    end

    # Make UCSC track definition "stanza" or record.
    # @see https://genome.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html
    # @param [String] type Track data type; currently either 'bigWig' or 'bigBed'
    # @param [String] hostName Hostname of where the big* file exists
    # @param [String] groupId Id of group containing database with the track, mainly for gbKey purposes
    # @param [Hash] options Hash of USCS options, these will overwrite the defaults
    # @param [String] altName Alternative name for track, if any
    # @return [String] A UCSC multi-line track definition "stanza". If preparing a payload/file
    #   with more than one, make sure to separate each with a blank line.
    def makeUcscTrackStr(type, hostName, groupId, options=nil, altName=nil)
      # These maps can be cached at the class level using a sessionId if @sessionId is set by using code. Very fast when looping.
      # AVPS
      allTracksAVPMap = getTrackAVPMap()
      # COLORS
      allTracksColorMap = getTrackColorMap(0)
      trkColor = (allTracksColorMap[@trackName] || '#000000')
      # STYLES
      allTracksStyleMap = getTrackStyleMap(0)
      styleStrName = (allTracksStyleMap[@trackName] || 'Local Score Barchart (big)')
      # RANKS
      allTracksRankMap = getTrackRankMap(0)
      # DESCRIPTIONS
      allTracksDescMap = getTrackDescMap(true)
      trackDescr = (allTracksDescMap[@trackName] || @trackName)
      trackDescr.strip!

      trkAttr = {} # kvps in this hash will get converted to text for the track definition
      # Get group name for groupId
      groupName = getGroupNameForGroupId(groupId)
      # Get dbName for refSeqId
      dbName = getDbNameForRefSeqId(@refSeqId)
      # Get gbKey for database
      gbKeysByRefSeqId = getFromSessionCache(:gbKeysByRefSeqId, groupId)
      if(gbKeysByRefSeqId and gbKeysByRefSeqId[@refSeqId])
        gbKey = gbKeysByRefSeqId[@refSeqId]
      else # Might not be cached, or may not be a gbKey for whole database
        # Try manually for database gbKey
        gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getKeyForDatabaseById(@dbu, groupId, @refSeqId)
        if(gbKey) # then got one, store in cache
          if(@sessionId)
            gbKeysByRefSeqId = setInSessionCache({}, :gbKeysByRefSeqId, groupId) unless(gbKeysByRefSeqId)
            gbKeysByRefSeqId[@refSeqId] = gbKey
          end
        else # (gbKey.nil?) ## Couldn't get gbKey for database, what about specifically for track?
          dbRec = getDbRecWithData()
          gbKeysByRefSeqIdAndFtypeId = getFromSessionCache(:gbKeysByRefSeqIdAndFtypeId, groupId, @refSeqId)
          if(gbKeysByRefSeqIdAndFtypeId.is_a?(Hash) and gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid])
            gbKey = gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid]
          else # Might not be cached, try manually
            gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getKeyForTrackById(@dbu, groupId, @refSeqId, dbRec.ftypeid)
            if(gbKey)
              if(@sessionId)
                gbKeysByRefSeqIdAndFtypeId = setInSessionCache({}, :gbKeysByRefSeqIdAndFtypeId, groupId, @refSeqId) unless(gbKeysByRefSeqIdAndFtypeId.is_a?(Hash))
                gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid] = gbKey
              end
            end
          end
        end
      end
      # Get public attribute for database
      dbIsPublic = false
      refSeqRecs = @dbu.selectRefseqById(@refSeqId)
      unless(refSeqRecs.nil? or refSeqRecs.empty?)
        refSeqRec = refSeqRecs.first
        if(refSeqRec['public'] == true)
          # should be exactly true or false
          dbIsPublic = true
        elsif(refSeqRec['public'] == false)
          dbIsPublic = false
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "refSeqRec has a value other than Boolean true or false for public field")
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query made by @dbu.selectRefseqById for @refSeqId=#{@refSeqId.inspect} is #{refSeqRecs.inspect}")
      end
      
      # Build the hash of name value pairs.
      # SEE SPECS: https://genome.ucsc.edu/goldenPath/help/trackDb/trackDbHub.html
      # Required: 'track'
      trackKey = trkAttr['track'] = (altName.nil? ? @trackName.dup : altName.dup)
      # - fix it if necessary
      trackKey.strip!
      trackKey.gsub!(/[^a-zA-Z0-9\-_]/, '_')
      trackKey = "A_#{trackKey}" unless(trackKey =~ /^[a-z]/i)
      # Required: 'type'
      trkAttr['type'] = type
      # Required: 'shortLabel'
      trkAttr['shortLabel'] = @trackName[0, 17]
      # Required: 'longLabel'
      trkAttr['longLabel'] = ((trackDescr.nil? or trackDescr.empty?) ? "#{@trackName} - #{type}" : trackDescr)
      # Required: 'bigDataUrl' -- gbKey added if database is not public
      trkAttr['bigDataUrl'] = "http://#{hostName}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{Rack::Utils.escape(groupName)}/db/#{Rack::Utils.escape(dbName)}/trk/#{Rack::Utils.escape(@trackName)}/#{type}"
      trkAttr['bigDataUrl'] << "?gbKey=#{gbKey}" unless(dbIsPublic)
      # Optional: 'visibility'
      trkAttr['visibility'] = (type == 'bigBed') ? 'dense' : 'full' # Hardcoded for now: dense for bigBed, full for bigWig
      # Optional: 'color'
      trkAttr['color'] = TrackColor.rgbHexToRgbDec(trkColor).to_s
      # Optional: 'priority'
      trkAttr['priority'] = allTracksRankMap[@trackName]
      # Optional: 'group'
      trkAttr['group'] = 'Genboree Hosted'
      # Optional: 'windowingFunction'
      # - Set to Genboree browser defaults, may get overriden by AVPs below
      trkAttr['windowingFunction'] = 'maximum'
      # Optional: 'maxHeightPixels'
      # - Set to Genboree browser defaults, may get overriden by AVPs below
      trkAttr['maxHeightPixels'] = '53:53:11'

      # Optional scaling-related settings.
      # May only be needed for certain track settings.
      # Only if UserMin/Max differs from DataMin/Max explicitly set it for the UCSC browser otherwise we can rely on their default autoscale=on to scale to the data
      trkAVPs = allTracksAVPMap[@trackName]
      trkUserMax = trkAVPs['gbTrackUserMax']
      trkUserMin = trkAVPs['gbTrackUserMin']
      trkDataMax = trkAVPs['gbTrackDataMax']
      trkDataMin = trkAVPs['gbTrackDataMin']
      if( (styleStrName =~ /^Global Score Barchart/) or (trkUserMax != trkDataMax) or (trkUserMin != trkDataMin))
        # Then we need to apply the user's min/max limits
        trkAttr['autoScale'] = 'off'
        trkAttr['viewLimits'] = "#{trkUserMin}:#{trkUserMax}"
      else
        trkAttr['autoScale'] = 'on'
      end

      # Single Genboree track attributes that translate to UCSC Browser track attributes
      trkAVPs.each_pair { |kk, vv|
        trkAttr.merge!(translateTrackAttrToUcsc(kk, vv))
      }

      # Build the string
      trackStr = ''
      UCSC_TRACK_STANZA_REQD.each { |attrName|
        trackStr << "#{attrName} #{trkAttr[attrName]}\n"
      }
      trkAttr.each_pair { |attrName, attrVal|
        unless(UCSC_TRACK_STANZA_REQD.index(attrName))
          trackStr << "#{attrName} #{attrVal}\n" unless(attrVal.nil? or (attrVal.respond_to?('empty?') and attrVal.empty?))
        end
      }
      # Ensure will have blank lines between records
      trackStr << "\n"

      return trackStr
    end

    # [+returns+] Hash of name value pairs to be appended to the track definition string
    def translateTrackAttrToUcsc(trackAttr, value)
      retVal = {}
      case trackAttr
      when 'gbTrackPxHeight'
        retVal = { 'maxHeightPixels' => "#{value}:#{value}:#{(value.to_i < 11) ? value : 11}" } # Magic number here, it's what UCSC uses for default.
      when 'gbTrackNegativeColor'
        retVal = { 'altColor' => TrackColor.rgbHexToRgbDec(value).to_s }
      when 'gbTrackAlwaysZero'
        retVal = { 'alwaysZero' => (['on', 'yes', 'true'].index(value.downcase)) ? 'on' : 'off' }
      when 'gbTrackGridDefault'
        retVal = { 'gridDefault' => (['on', 'yes', 'true'].index(value.downcase)) ? 'on' : 'off' }
      when 'gbTrackGraphType'
        valDown = value.downcase
        retVal = { 'graphTypeDefault' => value.downcase } if(valDown == 'bar' or valDown == 'points')
      when 'gbTrackSmoothingWindow'
        retVal = { 'smoothingWindow' => value }
      when 'gbTrackWindowingMethod'
        retVal = { 'windowingFunction' => UCSC_WINDOWING_MAP[value.downcase] }
      when 'gbTrackYIntercept'
        retVal = { 'yLineMark' => value, 'yLineOnOff' => 'on' }
      end
      return retVal
    end

    # UCSC name=value single line track record.
    # [+type+]          Either 'bigWig' or 'bigBed'
    # [+rsrcHost+]      Hostname of where the big* file exists
    # [+options+]       Hash of USCS options, these will overwrite the defaults
    def makeUcscTrackStr_oneLine(type, hostName, groupId, options=nil, altName=nil)
      # These maps can be cached at the class level using a sessionId if @sessionId is set by using code. Very fast when looping.
      # AVPS
      allTracksAVPMap = getTrackAVPMap()
      # COLORS
      allTracksColorMap = getTrackColorMap(0)
      trkColor = (allTracksColorMap[@trackName] || '#000000')
      # STYLES
      allTracksStyleMap = getTrackStyleMap(0)
      styleStrName = (allTracksStyleMap[@trackName] || 'Local Score Barchart (big)')
      # RANKS
      allTracksRankMap = getTrackRankMap(0)
      # DESCRIPTIONS
      allTracksDescMap = getTrackDescMap(true)
      trackDescr = (allTracksDescMap[@trackName] || @trackName)

      trackStr = ''
      trkAttr = {} # kvps in this hash will get converted to text for the track definition
      # Get group name for groupId
      groupName = getGroupNameForGroupId(groupId)
      # Get dbName for refSeqId
      dbName = getDbNameForRefSeqId(@refSeqId)
      # Get gbKey for database
      gbKeysByRefSeqId = getFromSessionCache(:gbKeysByRefSeqId, groupId)
      if(gbKeysByRefSeqId and gbKeysByRefSeqId[@refSeqId])
        gbKey = gbKeysByRefSeqId[@refSeqId]
      else # Might not be cached, or may not be a gbKey for whole database
        # Try manually for database gbKey
        gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getKeyForDatabaseById(@dbu, groupId, @refSeqId)
        if(gbKey) # then got one, store in cache
          if(@sessionId)
            gbKeysByRefSeqId = setInSessionCache({}, :gbKeysByRefSeqId, groupId) unless(gbKeysByRefSeqId)
            gbKeysByRefSeqId[@refSeqId] = gbKey
          end
        else # (gbKey.nil?) ## Couldn't get gbKey for database, what about specifically for track?
          dbRec = getDbRecWithData()
          gbKeysByRefSeqIdAndFtypeId = getFromSessionCache(:gbKeysByRefSeqIdAndFtypeId, groupId, @refSeqId)
          if(gbKeysByRefSeqIdAndFtypeId.is_a?(Hash) and gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid])
            gbKey = gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid]
          else # Might not be cached, try manually
            gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getKeyForTrackById(@dbu, groupId, @refSeqId, dbRec.ftypeid)
            if(gbKey)
              if(@sessionId)
                gbKeysByRefSeqIdAndFtypeId = setInSessionCache({}, :gbKeysByRefSeqIdAndFtypeId, groupId, @refSeqId) unless(gbKeysByRefSeqIdAndFtypeId.is_a?(Hash))
                gbKeysByRefSeqIdAndFtypeId[dbRec.ftypeid] = gbKey
              end
            end
          end
        end
      end
      # Get public attribute for database
      dbIsPublic = false
      refSeqRecs = @dbu.selectRefseqById(@refSeqId)
      unless(refSeqRecs.nil? or refSeqRecs.empty?)
        refSeqRec = refSeqRecs.first
        if(refSeqRec['public'] == true)
          # should be exactly true or false
          dbIsPublic = true
        elsif(refSeqRec['public'] == false)
          dbIsPublic = false
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "refSeqRec has a value other than Boolean true or false for public field")
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "query made by @dbu.selectRefseqById for @refSeqId=#{@refSeqId.inspect} is #{refSeqRecs.inspect}")
      end
      # Build the hash of name value pairs
      # Set default values
      trkAttr['name'] = '"' + (altName.nil? ? @trackName : altName) + '"'
      trkAttr['description'] = '"' + ((trackDescr.nil? or trackDescr.empty?) ? "#{@trackName} - #{type}" : trackDescr) + '"'
      trkAttr['group'] = 'user'
      trkAttr['visibility'] = (type == 'bigBed') ? 'dense' : 'full' # Hardcoded for now: dense for bigBed, full for bigWig
      trkAttr['priority'] = allTracksRankMap[@trackName]
      trkAttr['color'] = TrackColor.rgbHexToRgbDec(trkColor).to_s
      # Set to Genboree browser defaults, may get over written by gbTrack* attributes
      trkAttr['windowingFunction'] = 'maximum'
      trkAttr['maxHeightPixels'] = '53:53:11'

      # Only if UserMin/Max differs from DataMin/Max explicitly set it for the UCSC browser otherwise we can rely on their default autoscale=on to scale to the data
      trkAVPs = allTracksAVPMap[@trackName]
      trkUserMax = trkAVPs['gbTrackUserMax']
      trkUserMin = trkAVPs['gbTrackUserMin']
      trkDataMax = trkAVPs['gbTrackDataMax']
      trkDataMin = trkAVPs['gbTrackDataMin']

      if( (styleStrName =~ /^Global Score Barchart/) or (trkUserMax != trkDataMax) or (trkUserMin != trkDataMin))
        trkAttr['autoScale'] = 'off'
        trkAttr['viewLimits'] = "#{trkUserMin}:#{trkUserMax}"
      end

      # Single Genboree track attributes that translate to UCSC Browser track attributes
      trkAVPs.each_pair { |kk, vv|
        trkAttr.merge!(translateTrackAttrToUcsc(kk, vv))
      }
      # add gbKey only if database is not public
      trkAttr['bigDataUrl'] = "http://#{hostName}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{Rack::Utils.escape(groupName)}/db/#{Rack::Utils.escape(dbName)}/trk/#{Rack::Utils.escape(@trackName)}/#{type}"
      trkAttr['bigDataUrl'] << "?gbKey=#{gbKey}" unless(dbIsPublic)
      # Overwrite or append the parameter options to track attributes
      options.each_pair { |kk, vv| trkAttr[kk] = vv} if(!options.nil? and !options.empty?)
      # Build the string
      trackStr << "track type=#{type}"
      trkAttr.each_pair { |kk,vv|
        trackStr << " #{kk}=#{vv}" unless(vv.nil? or (vv.respond_to?('empty?') and vv.empty?))
      }
      trackStr << "\n\n"

      return trackStr
    end

    def getDbNameForRefSeqId(refSeqId=@refSeqId)
      dbName = getFromSessionCache(:dbNamesById, refSeqId)
      unless(dbName)
        refSeqRows = @dbu.selectRefseqById(refSeqId)
        if(!refSeqRows.nil? and !refSeqRows.empty?)
          dbName = refSeqRows.first['refseqName']
          setInSessionCache(dbName, :dbNamesById, refSeqId)
        end
      end
      return dbName
    end

    def getSqlDbNameForRefSeqId(refSeqId=@refSeqId)
      sqlDbName = getFromSessionCache(:sqlNamesById, refSeqId)
      unless(sqlDbName)
        refSeqRows = @dbu.selectRefseqById(refSeqId)
        if(!refSeqRows.nil? and !refSeqRows.empty?)
          sqlDbName = refSeqRows.first['databaseName']
          setInSessionCache(sqlDbName, :sqlNamesById, refSeqId)
        end
      end
      return sqlDbName
    end

    def getGroupNameForGroupId(groupId)
      groupName = getFromSessionCache(:groupNamesById, groupId)
      unless(groupName)
        groupRows = @dbu.selectGroupById(groupId)
        groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
        setInSessionCache(groupName, :groupNamesById, groupId)
      end
      return groupName
    end

    def getGroupIdForRefSeqId(refSeqId=@refSeqId)
      groupId = getFromSessionCache(:groupIdForRefSeqId, refSeqId)
      unless(groupId)
        groupRefseqRows = @dbu.selectGroupRefSeqByRefSeqId(refSeqId)
        groupId = groupRefseqRows.first['groupId']
        setInSessionCache(groupId, :groupIdForRefSeqId, refSeqId)
      end
      return groupId
    end

    # NOTE: this doesn't use the BigWigFile object anymore, since creating
    # hundreds of such objects only to throw them away once doing the fileExists?() call
    # was very very expensive. Here it is done in 1 step for the current track (without
    # breaking the old way that requires a groupId arg), which also reduces the number of
    # method calls by a lot. For @refSeqId that are in multiple groups (e.g. user group and the 'Public'
    # group), provide groupId to ensure the right one is used for your needs (else it will be the
    # user group...which is the most sensible.)
    def bigFileExists?(bigFileType, groupId=nil)
      # Load GenboreeConfig and build path to file
      genbConf = BRL::Genboree::GenboreeConfig.load()
      # If no groupId given, find groupId and escaped groupName given @refSeqId
      if(groupId.nil?)
        groupId = getGroupIdForRefSeqId(@refSeqId)
      end
      # We need the name of the database for SQL work
      sqlDbName = getSqlDbNameForRefSeqId(@refSeqId)
      @dbu.setNewDataDb(sqlDbName)
      trkRecs = @dbu.selectFtypeByTrackName(@trackName)
      ftypeid = -1
      if(!trkRecs.nil? and !trkRecs.empty?)
        ftypeid = trkRecs.first['ftypeid']
      end
      # Actual 'big' file name:
      bigFileName = (bigFileType == :bigBed ? genbConf.gbTrackAnnoBigBedFile : genbConf.gbTrackAnnoBigWigFile)
      bigFilePath = "#{genbConf.gbAnnoDataFilesDir}grp/#{groupId}/db/#{@refSeqId}/trk/#{ftypeid}/#{bigFileName}"
      retVal = File.exist?(bigFilePath)
      return retVal
    end

    def bigWigFileExists?(groupId=nil)
      return bigFileExists?(:bigWig, groupId)
    end

    def bigBedFileExists?(groupId)
      return bigFileExists?(:bigBed, groupId)
    end

    def self.deleteHdhvData(dbu, ftypeId)
      fMetaRows = dbu.selectValueFmeta('RID_SEQUENCE_DIR')
      baseDir = fMetaRows.first['fvalue']
      # Get the files from blockLevelDataInfo
      fileNameRows = dbu.selectDistinctFileNamesByFtypeId(ftypeId)
      if(!fileNameRows.nil? and !fileNameRows.empty?)
        fileNameRows.each { |row|
          binFileName = baseDir + '/' + row['fileName']
          $stderr.puts "deleteing #{binFileName}"
          FileUtils.rm(binFileName) if(File.exists?(binFileName))
        }
      end
      dbu.deleteByFieldAndValue(:userDB, 'blockLevelDataInfo', 'ftypeid', ftypeId, 'ERROR: BRL::Abstract::Resouces::Track.delete()')
    end

  end

  # This class provides methods for managing a track color property
  class TrackColor
    # Set up a class-level cache to store mappings from RGB to DEC color string conversions. These are static and can probably be
    # shared across all threads if done carefully when used in self.rgbHexToRgbDec().
    class << self
      attr_accessor :hexToDecCache, :cacheLock
    end
    # The "class instance" variable:
    @hexToDecCache = nil
    @cacheLock = Mutex.new


    # [+dbu+]         current dbUtil object
    # [+colorValue+]  color value in RGB hex format (#000000)
    # [+returns+]     colorId from color table
    def self.getColorId(dbu, colorValue)
      retVal = nil
      # Get Id for value from color table
      colorRows = dbu.selectByFieldAndValue(:userDB, 'color', 'value', colorValue, 'TrackColor.getColorId()')
      if(colorRows.nil? or colorRows.empty?)
        # Color couldn't be found
        colorValue.upcase!
        if(colorValue =~ /^#[0-9A-F]{6}$/)
          # If its a valid RGB hex value, insert it and return the last insert id
          dbu.insertRecords(:userDB, 'color', [colorValue], true, 1, 1, true, 'TrackColor.getColorId()')
          retVal = dbu.dataDbh.func('insert_id')
        else
          retVal = BRL::Genboree::GenboreeError.new(:'Not Acceptable', "The color specified #{colorValue} is not an acceptable color.")
        end
      else
        retVal = colorRows.first['colorId']
      end
      return retVal
    end

    # Convert a RGB hexadecimal color value to RGB comma-separated decimal value
    # example: #00FF00 -> 0,255,0
    #
    # [+hexValue+]  color in RGB Hexadecimal format
    # [+returns+]   color in comma seperated RGB decimal format
    def self.rgbHexToRgbDec(hexValue)
      retVal = nil
      TrackColor.cacheLock.synchronize {
        if(TrackColor.hexToDecCache)
          decVal = TrackColor.hexToDecCache[hexValue]
          if(decVal)
            retVal = decVal
          else # not cached yet
            retVal = nil
          end
        else # no cache yet
          TrackColor.hexToDecCache = {}
          retVal = nil
        end
        # If retVal still nil, not cached yet.
        unless(retVal)
          # strip the leading '#' off if its there
          hexValue.gsub!(/#/, '')
          retVal = hexValue.scan(/../).map{|dd|dd.hex}.join(',')
          TrackColor.hexToDecCache[hexValue] = retVal
        end
      }
      return retVal
    end
  end

  # This class provides methods for managing a track style property
  class TrackStyle
    # [+dbu+]         The current DbUtil object
    # [+styleValue+]  the style of the track, style.description
    # [+returns+]     styleId from the style table
    def self.getStyleId(dbu, styleValue)
      retVal = nil
      # Get Id for value from style table
      styleRows = dbu.selectByFieldAndValue(:userDB, 'style', 'description', styleValue, 'TrackStyle.getStyleId()')
      if(styleRows.nil? or styleRows.empty?)
        # Style couldn't be found
        retVal = BRL::Genboree::GenboreeError.new(:'Not Acceptable', "The style specified '#{styleValue}' is not an acceptable style.")
      else
        retVal = styleRows.first['styleId']
      end
      return retVal
    end
  end


  # This class provides methods for managing a track display property
  class TrackDisplay
    def self.getDisplayId(displayValue)
      retVal = nil
      displayId = BRL::Genboree::Constants::TRACK_DISPLAY_TYPES.index(displayValue)
      if(displayId.nil?)
        retVal = BRL::Genboree::GenboreeError.new(:'Not Acceptable', "The value is not acceptable, must be one of, #{BRL::Genboree::Constants::TRACK_DISPLAY_TYPES.join(', ')}")
      else
        retVal = displayId
      end
      return retVal
    end
  end

  # This class provides methods for managing a track's links
  class TrackLinks
    # This method validates links
    # Currently only ensures that the label isn't empty
    #
    # [+label+]   The label for the link
    # [+url+]     The URL for the link
    # [+returns+] status
    def self.validateLink(label, url)
      status = :OK
      if(label.strip.empty?)
        # Empty label is not allowed
        status = :'Unsupported Media Type'
      end
      return status
    end
  end

  # This class is used to handle the various aspects of a Track resource
  # The aspect handler classes are used by API resource classes
  #
  # Generic behavior shared by all aspects should be defined here
  class TrackAspectHandler # Abstract
    include BRL::Genboree::REST::Helpers
    # An instance of <tt>BRL::Genboree:DBUtil</tt> which is used to connect to databases and perform DB operations.
    attr_accessor :dbu

    attr_accessor :trackName, :refSeqId

    # The Track aspect or property (color, style, etc...), Mainly requred when a TrackAspectHandler manages multiple aspects
    attr_accessor :aspect
    # A single ftypeRow from the Hash created by <tt>BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes()</tt>
    attr_accessor :fTypeHash
    # ftypeId for the track in the local db
    attr_accessor :fTypeId
    # Extracted from @fTypeHash
    attr_accessor :localDbRec
    # Extracted from @fTypeHash
    attr_accessor :templateDbRec
    # The userId of the user executing the process.  Some of the feature* tables use userId=0 to represent the default state
    attr_accessor :userId
    # The value of the proprty that the class represents.
    attr_accessor :value
    # The place to store errors, should be a GenboreeError object
    attr_accessor :error

    # Constructor for the Track Aspect Handler
    #
    # [+dbu+]       An instance of <tt>BRL::Genboree:DBUtil</tt>
    # [+aspect+]    The Track aspect or property (color, style, etc...)
    # [+fTypeHash+] Hash created by <tt>BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes()</tt>
    # [+userId+]    optional, userId is only required by some of the feature* tables so defaults to nil
    def initialize(dbu, trackName, refSeqId, aspect, fTypeHash, userId=nil)
      @dbu, @trackName, @refSeqId, @aspect, @fTypeHash, @userId = dbu, trackName, refSeqId, aspect, fTypeHash, userId
      @fTypeId = fTypeHash['ftypeid']
      @fmethod, @fsource = @trackName.split(':')
      @trackObj = Track.new(@dbu, refSeqId, @fmethod, @fsource)
      @error = nil
      @value = getValue()
    end

    # When a the put method is executed in the API it either insert or update may be required.
    # This method will direct to the appropriate create/update based on @value which is set in the constructor
    # i.e: If row exists update else insert
    #
    # [+returns+] status
    def put()
      result = create()
      status = (result.is_a?(Integer) and result > 0) ? :Created : result
    end

    def create()
      return :'Not Implemented'
    end

    # Returns the value part of the payload
    # Assumes payload is a TextEntity.  Override if Class uses something else
    def getValueFromPayload()
      return @payload.text
    end

    # Should be overridden
    def delete()
      return :'Not Implemented'
    end

    # Should be overridden
    def getValue()
      return nil
    end

    # Returns the value as a TextEntity
    # Override if a different Entity type is required
    #
    # [+connect+] Do you want the "refs" field in any representation of this entity
    # [+detailed+] Do you want the detailed representation of this entity
    # [+returns+] TextEntity
    def getEntity(connect, detailed)
      entity = nil
      if(!@value.nil?)
        entity = BRL::Genboree::REST::Data::TextEntity.new(connect, @value)
      else
        entity = BRL::Genboree::REST::Data::TextEntity.new(connect, '')
      end
      return entity
    end

    # Set @payload with the request body or if there's a problem set @error with a GenboreeError
    # When this method is called,
    #
    # This class looks for a TextEntity, override if parsing for a different Entity
    #
    # [+reqBody+]
    # [+repFormat+]
    # [+returns+]     Parsed Request Body - @payload
    def parsePayload(reqBody, repFormat)
      @payload = BRL::Genboree::REST::Data::TextEntity.deserialize(reqBody, repFormat)
      if(@payload == :'Unsupported Media Type')
        @error = GenboreeError.new(:'Unsupported Media Type', 'Cannot process the request payload because the data is not in a supported format.')
      end
      return @payload
    end

    # The instance variable @error is used to capture more information
    #
    # [+returns+] boolean
    def hasError?()
      !@error.nil?
    end
  end


  # Used to manage the color of a track as stored in the local database tables: featuretocolor and color
  class TrackColorHandler < TrackAspectHandler

    # [+returns+] The color of the track for the user
    def getValue()
      return @trackObj.getColorForUserId(@userId)
    end

    # [+returns+] status
    def parsePayload(reqBody, repFormat)
      super(reqBody, repFormat)
      if(@error.nil?)
        # Returns GenboreeError if there's a problem
        colorId = TrackColor.getColorId(@dbu, @payload.text)
        @error = colorId if(colorId.is_a?(BRL::Genboree::GenboreeError))
      end
      return @payload
    end

    # [+returns+] number of rows created (updated or inserted)
    def create()
      @value = getValueFromPayload() # Set the value for the Obj
      return @trackObj.setColorForUserId(@value, @userId)
    end

    # [+returns+\ Number of rows deleted
    def delete()
      @value = ''
      return @trackObj.deleteColorForUserId(@userId)
    end

  end

  # Used to manage the style of a track as stored in the local database tables: featuretostyle and style
  class TrackStyleHandler < TrackAspectHandler

    # [+returns+] The color of the track for the user
    def getValue()
      return @trackObj.getStyleForUserId(@userId)
    end

    # [+returns+] status
    def parsePayload(reqBody, repFormat)
      super(reqBody, repFormat)
      if(@error.nil?)
        # Returns GenboreeError if there's a problem
        styleId = TrackStyle.getStyleId(@dbu, @payload.text)
        @error = styleId if(styleId.is_a?(BRL::Genboree::GenboreeError))
      end
      return @payload
    end

    # [+returns+] number of rows created (updated or inserted)
    def create()
      @value = getValueFromPayload() # Set the value for the Obj
      return @trackObj.setStyleForUserId(@value, @userId)
    end

    # [+returns+\ Number of rows deleted
    def delete()
      @value = ''
      return @trackObj.deleteStyleForUserId(@userId)
    end

  end

  # Used to manage the display of a track as stored in the local database table: featuredisplay
  # The different display types are stored in the array BRL::Genboree::Constants::TRACK_DISPLAY_TYPES
  class TrackDisplayHandler < TrackAspectHandler
    # [+returns+] The color of the track for the user
    def getValue()
      return @trackObj.getDisplayForUserId(@userId)
    end

    # [+returns+] status
    def parsePayload(reqBody, repFormat)
      super(reqBody, repFormat)
      if(@error.nil?)
        # Returns GenboreeError if there's a problem
        displayId = TrackDisplay.getDisplayId(@payload.text)
        @error = displayId if(displayId.is_a?(BRL::Genboree::GenboreeError))
      end
      return @payload
    end

    # [+returns+] number of rows created (updated or inserted)
    def create()
      @value = getValueFromPayload() # Set the value for the Obj
      return @trackObj.setDisplayForUserId(@value, @userId)
    end

    # [+returns+\ Number of rows deleted
    def delete()
      @value = ''
      return @trackObj.deleteDisplayForUserId(@userId)
    end
  end

  # Used to manage the sort order of a track as stored in the local database table: featuresort
  class TrackRankHandler < TrackAspectHandler
    # [+returns+] The color of the track for the user
    def getValue()
      return @trackObj.getRankForUserId(@userId)
    end

    # [+returns+] status
    def parsePayload(reqBody, repFormat)
      # Parse payload
      super(reqBody, repFormat)
      if(@error.nil?)
        # Returns GenboreeError if there's a problem
        status = @trackObj.validateRankForUserId(@payload.text, @userId)
        @error = status if(status.is_a?(BRL::Genboree::GenboreeError))
      end
      return @payload
    end

    # [+returns+] number of rows created (updated or inserted)
    def create()
      @value = getValueFromPayload() # Set the value for the Obj
      return @trackObj.setRankForUserId(@value, @userId)
    end

    # [+returns+\ Number of rows deleted
    def delete()
      @value = ''
      return @trackObj.deleteRankForUserId(@userId)
    end

  end



  # Used to manage Url, UrlLabel and Description of a track as stored in the local and template database table: featureurl
  #
  # Notes about Track Url and Description
  #   A null value in localDb causes the templateDb value to be displayed
  #   A non-null value in localDb causes the localDb value to be displayed (templateDb value is overridden)
  #     Empty string, '', in localDb hides the value in templateDb
  class TrackUrlHandler < TrackAspectHandler
    # The keys of this hash are what the API uses, and the values are the db columns
    MAP_ASPECT_TO_COL = {'url' => 'url', 'description' => 'description', 'urlLabel' => 'label', 'templateUrl' => 'url', 'templateDescription' => 'description', 'templateUrlLabel' => 'label'}

    # [+returns+] The url, label or description for the track depending on value of @aspect
    def getValue()
      retVal = nil
      # The value of @userId determines what level we're looking for
      # nil means we want the template Db value so don't bother getting the local Db value and the template value will be returned
      # If the track did not originate from a template, and @userId is nil, return 400 Bad Request with a error saying there is no template value for a user uploaded track
      if(@userId.nil?)
        if(@fTypeHash['dbNames'].last.dbType == :userDb)
          @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "There is no template value for this track because it did not originate from a template.")
        else
          tmplVal = @trackObj.getTemplateFeatureUrlValue(MAP_ASPECT_TO_COL[@aspect])
          if(tmplVal.is_a?(BRL::Genboree::GenboreeError))
            @error = tmplVal
          else
            retVal = tmplVal
          end
        end
      else
        retVal = @trackObj.getFeatureUrlValue(MAP_ASPECT_TO_COL[@aspect])
      end
      return retVal
    end

    # [+value+]   The new url, label or description value for the track
    # [+returns+\ Number of rows udpated
    def create()
      @value = getValueFromPayload() # Set the value for the Obj
      # The Track object will create ftype and featureurl records if needed
      return @trackObj.setFeatureUrlValue(MAP_ASPECT_TO_COL[@aspect], @value)
    end

    # The featureurl row is not actually deleted, the values are set to NULL
    # [+returns+\ Number of rows updated 'deleted'
    def delete()
      @value = nil
      return put(@value)
    end

  end


  # Used to manage Annotation Attributes for a track
  #
  class TrackAnnoAttributesHandler < TrackAspectHandler
    def getEntity(connect, detailed)
      return makeAttributesListEntity(@fTypeHash['dbNames'])
    end

    def parsePayload(reqBody, repFormat)
      @error = BRL::Genboree::GenboreeError.new(:'Not Implemented','')
    end

  end

  # Used to manage attributes for a track
  class TrackAttributeHandler < TrackAspectHandler
    attr_accessor :attrName, :attrNameId

    def initialize(dbu, trackName, refSeqId, aspect, fTypeHash, userId, attrName)
      @attrName = attrName
      super(dbu, trackName, refSeqId, aspect, fTypeHash, userId)
    end

    def getValue()
      # If the attribute doesn't exist for the track, @value should be set to nil
      @value = @trackObj.getAttributeValueByName(@attrName)
    end

    # Returns the value as a TextEntity
    # Overriden because we want entity to be nil resulting in 404
    #
    # [+connect+] Do you want the "refs" field in any representation of this entity
    # [+returns+] TextEntity
    def getEntity(connect, detailed)
      entity = nil
      entity = BRL::Genboree::REST::Data::TextEntity.new(connect, @value) if(!@value.nil?)
      return entity
    end

    def parsePayload(reqBody, repFormat)
      entityTypes = ['TextEntity', 'OOAttributeEntity', 'AttributeValueDisplayEntity', 'OOAttributeValueDisplayEntity']
      entity = BRL::REST::Resources::GenboreeResource.parseRequestBodyAllFormats(entityTypes, reqBody, repFormat)
      if(entity == :'Unsupported Media Type')
        @error = GenboreeError.new(:'Unsupported Media Type', 'Cannot process the request payload because the data is not in a supported format.')
      else
        @payload = entity
      end
      return @payload
    end


    def put()
      result = nil
      if(@payload.is_a?(BRL::Genboree::REST::Data::TextEntity))
        @value = @payload.text
        result = @trackObj.setAttributeValueByName(@attrName, @value)
      elsif(@payload.is_a?(BRL::Genboree::REST::Data::OOAttributeEntity))
        @value = @payload.value
        newAttrName = @payload.name
        # Could be a rename, remove the old attr
         if(newAttrName != @attrName)
           @trackObj.deleteAttributeByName(@attrName)
         end
         @attrName = newAttrName
         result = @trackObj.setAttributeValueByName(newAttrName, @value)
      elsif(@payload.is_a?(BRL::Genboree::REST::Data::AttributeValueDisplayEntity)) # Cannot be used to rename an attribute, can only set value
        @value = @payload.value
        result = @trackObj.setAttributeValueByName(@attrName, @value)
      elsif(@payload.is_a?(BRL::Genboree::REST::Data::OOAttributeValueDisplayEntity))
        @value = @payload.value
        newAttrName = @payload.name
        # Could be a rename, remove the old attr
        if(newAttrName != @attrName)
          @trackObj.deleteAttributeByName(@attrName)
        end
        @attrName = newAttrName
        result = @trackObj.setAttributeValueByName(newAttrName, @value)
      else
        # Do nothing
      end
      status = (result.is_a?(Integer) and result > 0) ? :OK : result
    end


    # Used to create or update the value of an attribute.
    # This method will create the Name/Value records if they don't already exist
    def create()
    end

    # Delete the record from ftype2attributes.
    # Leave the records in ftypeAttrNames and ftypeAttrValues because they may be reused at some point
    def delete()
      return @trackObj.deleteAttributeByName(@attrName)
    end

  end

  # Used to handle track attributes stored in the ftype2attributes table
  class TrackAttributesHandler < TrackAspectHandler
    def getEntity(connect, detailed, attrNameList=nil)
      return makeAttributesEntity(detailed, attrNameList)
    end

    def getEntityForPayload(connect, detailed)
      return makeAttributesEntity(detailed, [@payload.name])
    end

    # [+returns+] Either a TextEntityList or a OOAttributeValueDisplayEntityList
    def makeAttributesEntity(detailed, attrNameList=nil)
      attrHash = @trackObj.getAttributeNamesAndValues()
      if(!attrHash.empty?)
        if(detailed)
          ftypesHash =  {
                          @trackName => @fTypeHash
                        }
          tracksObj = BRL::Genboree::Abstract::Resources::Tracks.new(@dbu, @refSeqId, ftypesHash, @userId, @connect)
          tracksObj.updateAttributes(attrNameList)
          tracksObj.updateAttributesWithDisplay(attrNameList)
          entityList = tracksObj.getAttributes(detailed, @trackName)
        else
          entityList = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
          attrHash.each { |attrName, attrValue|
            entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, attrName)
            entityList << entity
          }
        end
      else
        # There aren't any attributes for the ftype, return an empty list
        entityList = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
      end
      return entityList
    end

    def parsePayload(reqBody, repFormat)
      @payload = BRL::Genboree::REST::Data::OOAttributeValueDisplayEntity.deserialize(reqBody, repFormat)
      if(@payload == :'Unsupported Media Type')
        @error = GenboreeError.new(:'Unsupported Media Type', 'Cannot process the request payload because the data is not in a supported format.')
      end
      return @payload
    end

    def put()
      result = create()
      status = (result.is_a?(Integer) and result > 0) ? :OK : result
    end

    def create()
      return @trackObj.setAttributeValueByName(@payload.name, @payload.value)
    end

  end


  # Used to manage display properties of an attribute of a track
  class TrackAttributeDisplayHandler < TrackAspectHandler
    attr_accessor :attrName, :attrNameId

    def initialize(dbu, trackName, refSeqId, aspect, fTypeHash, userId, attrName)
      @attrName = attrName
      # do this next to initialize @trackObj
      super(dbu, trackName, refSeqId, aspect, fTypeHash, userId)
      if(!@trackObj.hasAttribute?(@attrName))
        # Create the attribute with an empty value
        @trackObj.setAttributeValueByName(attrName, '')
      end
    end

    def getEntity(connect, detailed)
      return makeAttributeDisplayEntity()
    end

    # [+returns+] AttributeDisplayEntity
    def makeAttributeDisplayEntity()
      return TrackAttributeDisplayHandler.makeAttributeDisplayEntityFromObj(@trackObj, @attrName, @userId, @connect)
    end

    # Class method version to avoid initializing another trackObj which is slow.
    def self.makeAttributeDisplayEntityFromObj(trackObj, attrName, userId, connect=false)
      displayHash = trackObj.getAttributeDisplayForUserId(attrName, userId)
      if(!displayHash.empty?)
        entity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(connect, displayHash['rank'], displayHash['color'], displayHash['flags'])
      else
        # If the record doesn't exist yet, because the display settings haven't been set,
        # return a AttributeDisplayEntity with empty values to imply that the values aren't set as opposed to a 404
        #entity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(@connect, '', '', '')
        entity = nil
      end
      return entity
    end

    # Payload should be an AttributeDisplayEntity
    #
    # This methond should set @payload
    # [+returns+]  payload
    def parsePayload(reqBody, repFormat)
      # Need to parse AttributeDisplayEntity
      parseResults = BRL::Genboree::REST::Data::AttributeDisplayEntity.deserialize(reqBody, repFormat)
      if(parseResults.is_a?(BRL::Genboree::REST::Data::AttributeDisplayEntity))
        # Do any validation here, this method returns GenboreeError if there's a problem
        validationStatus = @trackObj.validateAttributeDisplayForUserId(@attrName, parseResults.rank, parseResults.color, parseResults.flags, @userId)
        if(validationStatus.is_a?(BRL::Genboree::GenboreeError))
          @error = validationStatus
        else
          @payload = parseResults
        end
      else
        @error = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The request body does not contain a valid media type.')
      end
      return @payload
    end

    def create()
      if(@payload.is_a?(AttributeDisplayEntity))
        rows = @trackObj.setAttributeDisplayForUserId(@attrName, @payload.rank, @payload.color, @payload.flags, @userId)
      else
        @error = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', '')
      end
      return rows
    end

    def delete()
      return @trackObj.deleteAttributeDisplayForUserId(@attrName, @userId)
    end

  end

  class TrackEntrypointsHandler < TrackAspectHandler
    attr_accessor :nameFilter

    def initialize(dbu, trackName, refSeqId, aspect, fTypeHash, userId, nameFilter)
      @nameFilter = nil
      @nameFilter = nameFilter
      # do this next to initialize @trackObj
      super(dbu, trackName, refSeqId, aspect, fTypeHash, userId)
    end

    def getEntity(connect, detailed)
      return makeEpsListEntity(@fTypeHash['dbNames'], @nameFilter)
    end

    def parsePayload(reqBody, repFormat)
      @error = BRL::Genboree::GenboreeError.new(:'Not Implemented','PUT to track entrypoints is not currently supported (and is a little strange anyway).')
    end
  end


  # Used to manage classes for a track
  class TrackClassesHandler < TrackAspectHandler
    def getEntity(connect, detailed)
      return makeClassesListEntity(@fTypeHash['dbNames'])
    end

    def parsePayload(reqBody, repFormat)
      @error = BRL::Genboree::GenboreeError.new(:'Not Implemented', 'PUT to track classes is not currently supported.')
    end

  end

  # Used to manage links for a track as stored in the local and template database tables: featuretolink and link
  class TrackLinksHandler < TrackAspectHandler

    def getEntity(connect, detailed)
      return makeLinksListEntity(@fTypeHash['dbNames'])
    end

    # This method builds the TrackLinkEntityList for the links of a track
    #
    # dbRecs is an array of structs that contain db name and ftypeid
    # with the local Db as the first element and the template as the second
    #
    # [+dbRecs+]
    # [+returns+] TrackLinkEntityList
    def makeLinksListEntity(dbRecs)
      linkInfo = {}
      # If userId is nil, we only want the links from the template Db
      templateOnly = @userId.nil?
      linkInfo = @trackObj.getLinks(templateOnly)
      # Create the Entity list from linkInfo
      linkInfo.sort
      linkArray = BRL::Genboree::REST::Data::TrackLinkEntityList.new(@connect)
      unless(linkInfo.empty?) # Can have no links for track...
        # Need to look in both local and template DBs for the link name and url
        linkInfo.keys.sort.each { |label|
          entity = BRL::Genboree::REST::Data::TrackLinkEntity.new(@connect, linkInfo[label], label)
          linkArray << entity
        }
      end
      return linkArray
    end

    # Payload could be a TrackLinkEntityList
    # or a RefEntity containing the url for templateLinks which is used to restore the template defaults (truncate localDb.featuretolink for the ftypeid)
    #
    # [+returns+] status
    def parsePayload(reqBody, repFormat)
      # Need to parse TrackLinkEntityList or RefEntity
      parseResults = BRL::Genboree::REST::Data::TrackLinkEntityList.deserialize(reqBody, repFormat)
      if(parseResults != :'Unsupported Media Type' and !parseResults.nil?)
        dataStruct = parseResults.getFormatableDataStruct()
        dataPart = dataStruct['data']
        @payload = dataPart
      else
        parseResults = BRL::Genboree::REST::Data::RefEntity.deserialize(reqBody, repFormat)
        if(parseResults != :'Unsupported Media Type' and !parseResults.nil?)
          @payload = parseResults
        else
          @error = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The request body does not contain a valid media type.')
        end
      end
      return @payload
    end

    # This put method replaces all the existing links with what has been defined in the payload
    # So it can be used to either create or update a set of links.
    #
    # A link with the same label as one in the templateDb will be displayed instead of the template link
    # Empty urls (link.description) are allowed and are used to 'hide' template links
    #
    # It is assumed that Template links that are not included in the payload should be hidden
    #
    # The template links can be restored by putting a RefEntity containing templateLinks
    #
    # [+returns+] status
    def put()
      putStatus = :OK
      if(@payload.is_a?(RefEntity))
        # The template links can be restored by putting a RefEntity containing templateLinks
        uri = URI.parse(@payload.url)
        path = uri.path
        if(path =~ BRL::REST::Resources::Track.pattern() and $~[4] == 'templateLinks')
          # TODO: Check to make sure that the resource referenced in the payload is for the same track, (grp, db, trk)
          @trackObj.restoreTemplateLinks()
        else
          # Could provide an option to add links from another resource which would be implemented here
          putStatus = :'Not Implemented'
          @error = BRL::Genboree::GenboreeError.new(:'Not Implemented', 'Check the format of the resource.  Only accepts the templateLinks resource for the specified track.')
        end
      else # Payload should be a TrackLinkEntityList
        links = @payload
        linkHash = {} # Hash containing links to be added
        # validate the links and append them to linkHash
        links.each { |link|
          linkObj = link.getFormatableDataStruct()
          # URL Labels (link.name) should be unique to the database and empty labels are not allowed
          linkStatus = TrackLinks.validateLink(linkObj['linkText'], linkObj['url'])
          if(linkStatus == :OK)
            linkHash[linkObj['linkText']] = linkObj['url']
          else
            putStatus = linkStatus
          end
        }
        if(putStatus == :OK)
          # 'Hide' any links that haven't been included in the payload
          # If a template link is missing from the payload, It should be 'hidden', meaning:
          #   Insert a record into localDb.link with localDb.link.name = templateDb.link.name and localDb.link.description = ''
          #   Insert record into localDb.featuretolink
          linkHash = @trackObj.addEmptyLinksFromTemplate(linkHash)
          # Add the links
          @trackObj.overwriteLinks(linkHash)
        end
      end
      return putStatus
    end

    # Because the default behavior is to display all of the links in the templateDb.
    # In order to 'delete' the links from the users perspective, records must be added to the localDb
    # which 'hide' the links stored in the templateDb
    def delete()
      linkHash = {} # Hash containing links from the templateDB that are going to be 'deleted' (hidden)
      linkHash = @trackObj.addEmptyLinksFromTemplate(linkHash)
      @trackObj.overwriteLinks(linkHash)
    end
  end

end ; end ; end ; end
