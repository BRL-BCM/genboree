require 'uri'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/abstract/resources/track'
require 'brl/util/checkSumUtil'

module BRL ; module Genboree ; module REST ; module Helpers
  class TrackApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trk/([^/\?]+)}
    MAX_THREADS = 3
    SLEEP_BASE = 5
    EXTRACT_SELF_URI = %r{^(.+?/trk/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off
    ID_COLUMN_NAME = 'ftypeid'
    FORMAT_TO_EXT = {
                    "lff" => "lff.bz2",
                    "bedgraph" => "bedGraph.bz2",
                    "gff3" => "gff3.bz2",
                    "gff" => "gff.bz2",
                    "fwig" => "fwig.bz2",
                    "vwig" => "vwig.bz2",
                    "variablestep" => "vwig.bz2",
                    "fixedstep" => "fwig.bz2",
                    "bed" => "bed.bz2",
                    "gtf" => "gtf.bz2"
                  }
    AGGFUNCTION_TO_DIRNAME = {
                                "avg" => "By%20Avg",
                                "med" => "By%20Median",
                                "max" => "By%20Max",
                                "min" => "By%20Min",
                                "count" => "By%20Count",
                                "avgbylength" => "By%20AvgByLength",
                                "sum" => "By%20Sum",
                                "stdev" => "By%20Stdev",
                                "rawdata" => "Raw%20Data",
                                :rawdata => "Raw%20Data"
                              }
    attr_accessor :dbApiUriHelper
    attr_accessor :grpApiUriHelper
    attr_accessor :staticFile
    attr_accessor :containers2Children

    # associate class-specific names to parent methods
    alias expandTrackContainers expandContainers

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @dbApiUriHelper = @grpApiUriHelper = @staticFile = nil
      @attemptNumber = 0

      # provide a set of REGEXP to identify sample and sample-containing URIs
      @TRACK_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trk/([^\?]+)}
      @TRACK_ENTITY_LIST_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trks/entityList/([^/\?]+)}
      @DB_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/([^/\?]+)(?!/)}
      @TRACK_CLASS_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/trks\?class=([^/\?]+)}
      @CLASS_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/class/([^/\?]+)} # not used currently

      # set the order these regexp should be matched in (generally most-specific to least-specific)
      @typeOrder = [:track, :track_list, :track_class, :database]

      # associate type symbols to their associated regexps
      @type2Regexp = {
        :track => @TRACK_REGEXP,
        :track_list => @TRACK_ENTITY_LIST_REGEXP,
        :track_class => @TRACK_CLASS_REGEXP,
        :database => @DB_REGEXP
      }

      # associate type symbols to a method that can be used to extract samples from that type
      # if type doesnt have a key, nothing to do -- just use the uri (case of track uri)
      @type2Method = {
        :track_list => :getTracksInList,
        :track_class => :getTracksInClass,
        :database => :getTracksInDb
      }

      # provide a cache for an association between container uris and their contents/children
      @containers2Children = Hash.new([])

      super(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @dbApiUriHelper = DatabaseApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@dbApiUriHelper)
      @grpApiUriHelper = @dbApiUriHelper.grpApiUriHelper unless(@grpApiUriHelper)
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      super(reusableComponents)
      reusableComponents.each_key { |compType|
        case compType
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        when :dbApiUriHelper
          @dbApiUriHelper = reusableComponents[compType]
        end
      }
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      # Call clear() on track abstraction objects
      if(!@cache.nil?)
        @cache.each_key { |uri|
          trkObj = @cache[uri][:abstraction]
          trkObj.clear() if(trkObj and trkObj.respond_to?(:clear))
        }
      end
      super()
      @dbApiUriHelper.clear() if(@dbApiUriHelper)
      @dbApiUriHelper = nil
      # grpApiUriHelper is cleared by dbApiUriHelper from whence it came
      @grpApiUriHelper = nil
      @containers2Children = Hash.new([])
    end

    # Get lffType
    def lffType(uri)
      lffType = nil
      if(uri)
        # First, try from cache
        lffType = getCacheEntry(uri, :lffType)
        if(lffType.nil?)
          # If not cached, try to retrieve it
          #
          trkName = extractName(uri)
          if(trkName)
            parts = trkName.split(/:/)
            if(parts.size > 1)
              lffType = parts.first
              setCacheEntry(uri, :lffType, lffType)
            end
          end
        end
      end
      return lffType
    end

    # Get lffSubtype
    def lffSubtype(uri)
      lffSubtype = nil
      if(uri)
        # First, try from cache
        lffSubtype = getCacheEntry(uri, :lffSubtype)
        if(lffSubtype.nil?)
          # If not cached, try to retrieve it
          #
          trkName = extractName(uri)
          if(trkName)
            parts = trkName.split(/:/)
            if(parts.size > 1)
              lffSubtype = parts[1]
              setCacheEntry(uri, :lffSubtype, lffSubtype)
            end
          end
        end
      end
      return lffSubtype
    end

    # Is the name of this resource syntactically acceptable
    def nameValid?(uri)
      retVal = false
      if(uri)
        # First, try from cache
        nameValid = getCacheEntry(uri, :nameValid)
        if(nameValid.nil?) # then test manually
          nameValid = false
          name = extractName(uri)
          if(name and name =~ /\S/)
            parts = name.split(/:/)
            lffType, lffSubtype = parts
            if( parts and parts.size == 2 and
                lffType and lffType =~ /\S/ and lffType !~ /[:\t\n]/ and
                lffSubtype and lffSubtype =~ /\S/ and lffSubtype !~ /[:\t\n]/)
              nameValid = true
              setCacheEntry(uri, :nameValid, nameValid)
            end
          end
        end
        retVal = nameValid
      end
      return retVal
    end

    # Does this resource actually exist? Tracks can exist either in user
    # database or the template database...need to override this method.
    def exists?(uri, hostAuthMap=nil)
      exists = false
      if(uri)
        # First, try from cache
        exists = getCacheEntry(uri, :exists)
        unless(hostAuthMap)
          if(exists.nil?) # then test manually
            name = extractName(uri)
            if(name)
              # Get all the ftypes in both user and shared dbs
              allFtypes = self.allFtypes(uri)
              if(allFtypes)
                # Is track name in allFtypes?
                exists = allFtypes.key?(name)
                setCacheEntry(uri, :exists, exists)
              else
                exists = false
              end
            end
          end
        else
          uriObj = URI.parse(uri)
          apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}?", hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          exists = apiCaller.succeeded? ? true : false
        end
      end
      return exists
    end

    # Is the track empty of annotations?
    # (If doesn't exist yet, it's "empty"; if not a trk URI, returns nil)
    def empty?(uri)
      retVal = true
      if(uri)
        isTrk = extractPureUri(uri)
        if(isTrk)
          trkObj = rsrcAbstraction(uri)
          if(trkObj.nil?)
            retVal = true
          elsif(trkObj.hasAnnotations?)
            retVal = false
          end
        else
          retVal = nil
        end
      end
      return retVal
    end

    # Is the track an HDHV track
    # (If doesn't exist yet, it's "empty"; if not a trk URI, returns nil)
    def isHdhv?(uri, hostAuthMap=nil)
      retVal = false
      if(uri)
        unless(hostAuthMap)
          $stderr.debugPuts(__FILE__, __method__, "DANGER DANGER", "No hostAuthMap provided to the isHdhv?() method. Will look in DB directly. BREAKS GENBOREE NETWORK.")
          isTrk = extractPureUri(uri)
          if(isTrk)
            trkObj = rsrcAbstraction(uri)
            if(trkObj.isHdhv?)
              retVal = true
            end
          else
            retVal = nil
          end
        else
          uriObj = URI.parse(uri)
          apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/attribute/gbTrackRecordType/value?", hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          retVal = apiCaller.succeeded? ? true : false # 'gbTrackRecordType' only exist for high density tracks.
        end
      end
      return retVal
    end

    # Is any track empty of annotations? (If they don't exist yet, they are "empty")
    # (If doesn't exist yet, it's "empty"; if any is not a trk URI, returns nil)
    def anyEmpty?(uris)
      retVal = false
      if(uris)
        uris.each { |uri|
          isEmpty = empty?(uri)
          if(isEmpty.nil?)
            retVal = nil
            break
          elsif(isEmpty)
            retVal = true
            break
          else
            retVal = false
          end
        }
      end
      return retVal
    end

    # Db version for database this track is in
    def dbVersion(uri)
      return @dbApiUriHelper.dbVersion(uri)
    end

    # Is this track's db version equal to versionStr?
    def dbVersionEquals?(uri, versionStr)
      return @dbApiUriHelper.dbVersionEquals?(uri, versionStr)
    end

    # Do ALL tracks' db versions match?
    def dbsVersionMatch?(uris)
      return @dbApiUriHelper.dbsVersionMatch?(uris)
    end

    # Get trackName => dbVersion hash
    def dbVersionsHash(uris)
      return @dbApiUriHelper.dbVersionsHash(uris)
    end

    # Is trk in db?
    def trkInDb?(trkUri, dbUri, andNotEmpty=false)
      retVal = false
      if(trkUri and dbUri)
        # First, check if trk is in db according to URI.
        #
        # MUST trim off any crud off the URIs.
        trimmedDbUri = @dbApiUriHelper.extractPureUri(dbUri)      # For dbUri, this will likely just remove query string, if there
        trimmedTrkDbUri = @dbApiUriHelper.extractPureUri(trkUri)  # For trkUri, this will isolate the db URI
        if(trimmedDbUri == trimmedTrkDbUri)
          retVal = true
        else
          # Second, if required, check if track is in db by track name
          #
          # Get name of track:
          trkName = extractName(trkUri)
          # Check if track in database (user or shared):
          #
          # 1. Get track abstraction to help us with this
          trkObj = rsrcAbstraction(trkUri)
          if(trkObj)
            # 2. Does the track exist in user or shared db's?
            retVal = trkObj.exists?
            retVal &= trkObj.hasAnnotations? if(andNotEmpty)
          end
        end
      end
      return retVal
    end

    # Verify user has access to trk
    # TODO: make this API-based and multi-host compliant like GroupApiUriHelper#accessibleByUser().
    #       Use similar approach, leveraging / extending Abstraction::Track class if needed
    # TODO: assemble the unique list of track URIs here, like the group one does, to help
    #       avoid unnecessary checking via api calls.
    # [+hostAuthMap+] Optional. An already-filled Hash of canonical address of hostName to 3-column Array record with login & password & hostType
    #                 (:internal | :external) for that host. If not provided, it will have to be retrieved, so it can
    #                 save time to provide this if it is available (often is).
    def accessibleByUser?(uri, userId, accessCodes, hostAuthMap=nil)
      retVal = false
      if(uri and userId and accessCodes)
        # This is not cached directly, since we don't know what accessCodes are acceptable (it's dynamic)
        # and individual track access is binary. So the group-checking is more-or-less cached (it has a similar
        # constraint though), and the list of all accessible ftypes is cached (by db uri), so really most of
        # it's decently cached actually.
        #
        # User must have access to the group the track is in
        if(@grpApiUriHelper.accessibleByUser?(@grpApiUriHelper.extractPureUri(uri), userId, accessCodes, hostAuthMap))
          # Now check if track even exists. If not, and user has access to group, then that's sufficient (especially for writing new tracks!).
          unless(self.exists?(uri))
            retVal = true
          else # track exists, need to check for per-track access restrictions
            retVal = false
            # Get all accessible ftype rows (from user & template dbs)
            # 1. Need hostAuthMap for this user from the local Genboree instance, so we can do ApiCaller stuff
            allAccessibleFtypes = allAccessibleFtypes(uri, userId, hostAuthMap)
            if(allAccessibleFtypes and !allAccessibleFtypes.empty?)
              # Get track name
              name = extractName(uri)
              retVal = allAccessibleFtypes.key?(name)
            end
          end
        end
      end
      return retVal
    end

    # Verify that user has access to ALL trks
    def allAccessibleByUser?(uris, userId, accessCodes, hostAuthMap=nil)
      retVal = true
      if(uris and userId and accessCodes)
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId.to_i) unless(hostAuthMap)
        uris.each { |uri|
          unless(accessibleByUser?(uri, userId, accessCodes, hostAuthMap))
            retVal = false
            break
          end
        }
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # Feedback helpers
    # ------------------------------------------------------------------
    # Get trackName => isEmpty [boolean] Hash (if track doesn't exist, it's "empty")
    def trackEmptyHash(uris)
      trackEmptyHash = {}
      if(uris)
        uris.each { |uri|
          # Track name
          name = extractName(uri)
          # Store whether is empty?
          trackEmptyHash[name] = empty?(uri)
        }
      end
      return trackEmptyHash
    end

    # Get trackName => canAccess [boolean] Hash
    def accessibleTracksHash(uris, userId, accessCodes)
      accessibleTracksHash = {}
      if(uris and userId and accessCodes)
        uris.each { |uri|
          # Track name
          name = extractName(uri)
          # Store whether accessible
          accessibleTracksHash[name] = accessibleByUser?(uri, userId, accessCodes)
        }
      end
      return accessibleTracksHash
    end

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    # Set the database as the active data db in the handle
    def setNewDataDb(uri)
      retVal = false
      if(uri)
        # Get name of database
        refSeqId = @dbApiUriHelper.id(uri)
        # Get MySQL database name
        databaseNameRows = @dbu.selectDBNameByRefSeqID(refSeqId)
        if(databaseNameRows and !databaseNameRows.empty?)
          databaseName = databaseNameRows.first['databaseName']
          # Set as active data db in handle
          @dbu.setNewDataDb(databaseName)
          retVal = true
        end
      end
      return retVal
    end

    # Get appropriate database entity table row (ftype row)
    def tableRow(uri)
      row = nil
      if(uri)
        # First, try from cache
        row = getCacheEntry(uri, :tableRow)
        if(row.nil?)
          # If not cached, try to retrieve it
          #
          # Get name of track
          name = extractName(uri)
          if(name)
            # Set track database as active data db in the handle
            self.setNewDataDb(uri)
            # Get ftype rows
            rows = @dbu.selectFtypeByTrackName(name)
            if(rows and !rows.empty?)
              row = rows.first
              # Cache table row
              setCacheEntry(uri, :tableRow, row)
            end
          end
        end
      end
      return row
    end

    # Gets the array of ALL Ftype rows augmented with the 'dbNames' key that has an array of DbRec structs
    # just as GenboreeDbHelper.getAllFtypes() returns. User independent.
    def allFtypes(uri)
      allFtypes = []
      if(uri)
        # First, try from cache.
        # - This is cached by DATABASE URI, to speed up questions for other tracks too
        # - So we don't use getCacheEntry()/setCacheEntry()
        #
        # Get dbUri
        dbUri = @dbApiUriHelper.extractPureUri(uri)
        # Get cached data
        uriCache = @cache[dbUri]
        allFtypes = uriCache[:allFtypes]
        unless(allFtypes) # not in cache, we have to get manually
          # Get refSeqId for this trk's db
          refSeqId = @dbApiUriHelper.id(uri)
          if(refSeqId)
            allFtypes = BRL::Genboree::GenboreeDBHelper.getAllFtypes(refSeqId, true, @dbu)
            if(allFtypes and !allFtypes.empty?)
              # Store in cache:
              uriCache[:allFtypes] = allFtypes
            end
          end
        end
      end

      return allFtypes
    end

    # Gets the 'numberOfAnnotations' entry in the ftypeCount table for a track
    # This equates to the number of fdata rows for a regular track and the number of bp scores for a high density track
    # [+uri+] URI of the track
    # [+returns+] An integer indicating the number of annotations
    def getAnnosCount(uri, userId, hostAuthMap=nil)
      retVal = nil
      hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId.to_i) unless(hostAuthMap)
      uriObj = URI.parse(uri)
      gbKey = extractGbKey(uri)
      rsrcUri = "#{uriObj.path}/annos/count?"
      # Do we need to add back on gbKey?
      rsrcUri << "&gbKey=#{gbKey}" if(gbKey)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, rsrcUri, hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        retVal = JSON.parse(apiCaller.respBody)['data']['count']
      end
      return retVal
    end

    # Class method to return max number of concurrent threads to run when downloading track data
    # [+retVal+] retVal: integer value
    def self.getMaxThreads()
      retVal = nil
      maxThreadsFromEnv = ENV['GB_NUM_CORES']
      if(maxThreadsFromEnv =~ /^\d+$/)
        maxThreadsFromEnv.strip!
        retVal = ( maxThreadsFromEnv.to_i <= MAX_THREADS ? maxThreadsFromEnv.to_i : MAX_THREADS)
      else
        retVal = MAX_THREADS
      end
      return retVal
    end

    # Downloads either a static data file for the given track URI or performs a dynamic download using threads.
    # [+uriFileHash+] score track URI list mapped to their respective output file path
    # [+format+] format of the data file: bedGraph, fwig, etc (recommended: bedGraph with ROI and fwig with fixed span)
    # [+aggFunction+] Aggregating function: avg, avgByLength, med, etc
    # [+regions+] either a fixnum (for fixed windows) or the URI of a Regions of Interest (ROI) track
    # [+userId+]
    # [+hostAuthMap+]
    # [+emptyScoreValue+] Only used for dynamic downloads (static files already have them)
    # [+noOfAttempts+] number of attempts to perform dynamic downloads (will use alder32 to check validity of file, NOT used for static file downloads)
    # [+maxThreads+] Maximum number of children threads to keep in the pool [Default: 4]. This should ideally match the number of cores the process has access to.
    # [+returns+] nil
    def getDataFilesForTracksWithThreads(uriFileHash, format, aggFunction, regions, userId, hostAuthMap=nil, emptyScoreValue=nil, noOfAttempts=30, maxThreads=TrackApiUriHelper.getMaxThreads())
      count = 0
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using threads: #{maxThreads}.")
      threads = []
      uriFileHash.each_key {|uri|
        childrenThreads = (Thread.list.size - 1)
        if(childrenThreads == 0 or childrenThreads % maxThreads != 0)
          threads << Thread.new {
            getDataFileForTrack(uri, format, aggFunction, regions, uriFileHash[uri], userId, hostAuthMap, emptyScoreValue, noOfAttempts)
          }
        else
          addedToPool = false
          # Sleep every 5 seconds and then query the number of children threads running.
          # As soon as one spot is free, insert the *current* job in the thread pool and move on to the next download.
          loop {
            sleep(5)
            childrenThreads = (Thread.list.size - 1)
            if(childrenThreads == 0 or childrenThreads % maxThreads != 0)
              threads << Thread.new {
                getDataFileForTrack(uri, format, aggFunction, regions, uriFileHash[uri], userId, hostAuthMap, emptyScoreValue, noOfAttempts)
              }
              addedToPool = true
            end
            break if(addedToPool)
          }
        end
        count += 1
       }
       threads.each { |aThread| aThread.join }
     end

    # Downloads either a static data file for the given track URI or performs a dynamic download.
    # @param [String] uri score track URI
    # @param [String] format format of the data file: bedGraph, fwig, etc (recommended: bedGraph with ROI and fwig with fixed span)
    # @param [String] aggFunction Aggregating function: avg, avgByLength, med, etc
    # @param [Fixnum, String] regions either a fixnum (for fixed windows) or the URI of a Regions of Interest (ROI) track
    # @param [String] outputFilePath location to write track data to
    # @param [Fixnum] userId user id to use to get track data
    # @param [nil, Hash<String, Array>] hostAuthMap map of host to 3-tuple authentication parameters
    # @param [nil, String] emptyScoreValue value to write in dynamic downloads (static files already have them) if score track doesnt have data for a region
    # @param [Fixnum] noOfAttempts number of attempts to perform dynamic downloads (will use alder32 to check validity of file, NOT used for static file downloads)
    # @param [Hash<String, String>] uriParams if regions is a Fixnum, use these query string parameters in addition to
    #   the usual ones for the uri
    # @param [Hash<String, String>] regionsParams if regions is URI of a Regions of Interest (ROI) track, use these query
    #   string parameters in addition to the usual ones (gbKey, etc.) for the regions uri
    # @return [nil,String] full path of the downloaded file or nil if file was not downloaded
    # @note if a static file has already been prepared, it will be the target of the download and @staticFile will be set to true; static files are compressed
    #   and will need to be uncompressed to have the same content type as the dynamic download mode
    def getDataFileForTrack(uri, format, aggFunction, regions, outputFilePath, userId, hostAuthMap=nil, emptyScoreValue=nil, noOfAttempts=30, uriParams=nil, regionsParams=nil)
      retVal = nil
      @attemptNumber = 1
      raise "noOfAttempts cannot be less than 1" if(noOfAttempts < 1)
      aggFunction = aggFunction.to_s
      hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Using hostAuthMap:\n  #{JSON.pretty_generate(hostAuthMap)}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n#{'='*80}\nDBU:\n#{@dbu.inspect}\n")
      dbUri = @dbApiUriHelper.extractPureUri(uri)
      trkName = CGI.escape(extractName(uri))
      host = URI.parse(dbUri).host
      gbKey = extractGbKey(uri)
      roiGbKey = nil
      rsrcPath = URI.parse(dbUri).path
      if(aggFunction.downcase == "rawdata")
        rsrcPath << "/file/Raw%20Data/#{trkName}.#{FORMAT_TO_EXT[format.downcase]}"
      else
        # First check whether 'regions' represents a fixed window or a ROI track
        $stderr.debugPuts(__FILE__, __method__, "Downloading Track", "#{uri}\tRegions: #{regions}\taggFunction: #{aggFunction}\temptyScoreValue: #{emptyScoreValue.inspect}\tformat: #{format}")
        if(regions.is_a?(Fixnum))
          rsrcPath << "/file/#{regions}bp%20span/#{AGGFUNCTION_TO_DIRNAME[aggFunction.downcase]}/#{trkName}.#{FORMAT_TO_EXT[format.downcase]}"
        else
          roiTrack = CGI.escape(extractName(regions))
          rsrcPath << "/file/#{roiTrack}/#{AGGFUNCTION_TO_DIRNAME[aggFunction.downcase]}/#{trkName}.#{FORMAT_TO_EXT[format.downcase]}"
          roiGbKey = extractGbKey(regions)
        end
      end
      sizeRsrcPath = "#{rsrcPath}/size?"
      # Do we need to add gbKey to the rsrcPath?
      sizeRsrcPath << "&gbKey=#{gbKey}" if(gbKey)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, sizeRsrcPath, hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?) # Static file exists. Download it
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Static file exists. Downloading...")
        # Get the size of the file first
        @fileSize = JSON.parse(apiCaller.respBody)['data']['number']
        dataRsrcPath = "#{rsrcPath}/data?"
        dataRsrcPath << "&gbKey=#{gbKey}" if(gbKey)
        resp = downloadFile(host, dataRsrcPath, outputFilePath, hostAuthMap, :STATIC)
        retVal = outputFilePath if(resp)
        @staticFile = true
      else
        @staticFile = false
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Static file does not does not exist. Downloading dynamically...")
        if(aggFunction.downcase == "rawdata")
          trkUri = URI.parse(uri)
          host = trkUri.host
          rsrcPath = trkUri.path
          rsrcPath << "/annos?format=#{CGI.escape(format)}&addCRC32Line=true"
          # Do we need to add gbKey to the rsrcPath?
          rsrcPath << "&gbKey=#{gbKey}" if(gbKey)
          sleep(1)
          resp = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, :DYNAMIC, noOfAttempts)
          retVal = outputFilePath if(resp)
        else
          if(regions.is_a?(Fixnum))
            trkUri = URI.parse(uri)
            host = trkUri.host
            rsrcPath = trkUri.path
            rsrcPath << "/annos?format=#{CGI.escape(format)}&spanAggFunction=#{CGI.escape(aggFunction)}&span=#{regions}"
            rsrcPath << "&emptyScoreValue=#{CGI.escape(emptyScoreValue)}" if(emptyScoreValue)
            rsrcPath << "&addCRC32Line=true"
            # Do we need to add gbKey to the rsrcPath?
            rsrcPath << "&gbKey=#{gbKey}" if(gbKey)
            # add any additional query string parameters for trkUri
            unless(uriParams.nil? or uriParams.empty?)
              oldParams = ["format", "spanAggFunction", "span", "emptyScoreValue", "addCRC32Line", "gbKey"]
              paramComps = []
              # remove query string parameters already appended to rsrc path
              oldParams.each{|param|
                uriParams.delete(param)
              }
              uriParams.each_key{|kk|
                paramComps.push("#{kk}=#{uriParams[kk]}")
              }
              queryString = paramComps.join("&")
              rsrcPath << "&#{queryString}"
            end
            resp = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, :DYNAMIC, noOfAttempts)
            retVal = outputFilePath if(resp)
          else
            roiTrkUri = URI.parse(regions)
            host = roiTrkUri.host
            rsrcPath = roiTrkUri.path
            rsrcPath << "/annos?format=#{CGI.escape(format)}&spanAggFunction=#{CGI.escape(aggFunction)}"
            rsrcPath << "&emptyScoreValue=#{CGI.escape(emptyScoreValue)}" if(emptyScoreValue)
            rsrcPath << "&addCRC32Line=true"
            rsrcPath << "&scoreTrack=#{CGI.escape(uri)}"
            # Do we need to add gbKey to the rsrcPath?
            rsrcPath << "&gbKey=#{roiGbKey}" if(roiGbKey)
            unless(regionsParams.nil? or regionsParams.empty?)
              oldParams = ["format", "spanAggFunction", "emptyScoreValue", "addCRC32Line", "scoreTrack", "gbKey"]
              oldParams.each{|param|
                regionsParams.delete(param)
              }
              paramComps = []
              regionsParams.each_key{|kk|
                paramComps.push("#{kk}=#{regionsParams[kk]}")
              }
              queryString = paramComps.join("&")
              rsrcPath << "&#{queryString}"
            end
            resp = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, :DYNAMIC, noOfAttempts)
            retVal = outputFilePath if(resp)
          end
        end
      end
      return retVal
    end

    # Downloads data file for a track
    # [+host+]
    # [+rsrcPath+]
    # [+outputFilePath+]
    # [+hostAuthMap+]
    # [+returns+] true or false
    def downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, type, noOfAttempts=30)
      retVal = true
      raise "noOfAttempts cannot be less than 1" if(noOfAttempts < 1)
      #sleep((@attemptNumber-1) * 30)
      $stderr.debugPuts(__FILE__, __method__, "SLEEP TIME", "Sleeping for #{SLEEP_BASE * (@attemptNumber-1)**2} seconds ...")
      sleep(SLEEP_BASE * (@attemptNumber-1)**2)
      uri = "http://#{host}#{rsrcPath}"
      begin
        hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(host, rsrcPath, hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        staticWriter = File.open(outputFilePath, "w")
        apiCaller.get() { |chunk| staticWriter.print(chunk) }
        @attemptNumber += 1
        staticWriter.close()
        if(!apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "API ERROR", " [#{uri}] - HTTP Response: #{apiCaller.httpResponse.inspect}\nAPI Response: #{apiCaller.respBody.inspect}\nParams:\n  - host: #{host.inspect}\n  - rsrcPath: #{rsrcPath.inspect}\n  - outputFilePath: #{outputFilePath.inspect}\n  - hostAuthMap: <PRIVATE>\n  - type: #{type.inspect}\n  - noOfAttempts: #{noOfAttempts.inspect}\n  - fullApiUri: #{apiCaller.fullApiUri.inspect}\n#{'-'*40}")
          retVal = false
        end
        if(type == :DYNAMIC) # Check for adler32 checksum
          adlerVal = BRL::Util::CheckSumUtil.getAdler32CheckSum(outputFilePath)
          if(adlerVal)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] -  [Success] Dynamic track downloaded...")
            BRL::Util::CheckSumUtil.stripAdler32(outputFilePath) # for removing the checksum value
          else # Try again, if attempt# is smaller than or equal to 3
            if(@attemptNumber <= noOfAttempts)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] - Could not get complete data (Missing Adler). Trying again...")
              staticWriter.close() if(staticWriter and !staticWriter.closed?)
              retVal = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, type, noOfAttempts)
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] - Could not get complete data after trying #{noOfAttempts} time(s). Quitting...")
              retVal = false
            end
          end
        else # Check that the size of the downloaded file is the same as one recieved from an API call
          downloadFileSize = File.size(outputFilePath)
          if(downloadFileSize != @fileSize)
            if(@attemptNumber <= noOfAttempts)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] - Could not get complete data. Size from API call: #{@fileSize} does not match downloaded file: #{downloadFileSize}. Trying again...")
              staticWriter.close() if(staticWriter and !staticWriter.closed?)
              retVal = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, type, noOfAttempts)
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] - Could not get complete data after trying #{noOfAttempts} time(s). Quitting...")
              retVal = false
            end
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "[#{uri}] - [Success] Size of the downloaded file matches the size of the file recieved from the API...")
          end
        end
      rescue Exception => err
        if(@attemptNumber <= noOfAttempts)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "[#{uri}] - Failed to download track data to a file after attempt number: #{@attemptNumber-1} . Trying again...\nError:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
          staticWriter.close() if(staticWriter and !staticWriter.closed?)
          retVal = downloadFile(host, rsrcPath, outputFilePath, hostAuthMap, type, noOfAttempts)
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "[#{uri}] - Failed to download track data to a file after trying #{noOfAttempts} time(s). Quitting.\n Error:\n#{err.message}\nBacktrace:\n\n#{err.backtrace.join("\n")}")
          staticWriter.close() if(staticWriter and !staticWriter.closed?)
          retVal = false
        end
      end
      return retVal
    end

    # Gets the names of tracks in a database
    # @param uri [String] a database uri
    # @param userId [String] the id number associated with the user making the request
    # @param hostAuthMap [Hash] authentication map for user making the request
    # @return retVal [Hash] hash of accessible track names in the database (at uri)
    def allAccessibleFtypes(uri, userId, hostAuthMap=nil)
      retVal = {}
      if(uri and userId)
        gbKey = extractGbKey(uri)
        userId = userId.to_i
        # First, try from cache.
        # - This is cached by DATABASE URI, to speed up questions for other tracks too
        # - So we don't use getCacheEntry()/setCacheEntry()
        #
        # Get dbUri
        dbUri = @dbApiUriHelper.extractPureUri(uri)
        # Get cached data
        uriCache = @cache[dbUri]
        perUserAllAccessibleFtypes = uriCache[:allAccessibleFtypes]
        allAccessibleFtypes = (perUserAllAccessibleFtypes.nil? ? nil : perUserAllAccessibleFtypes[userId])
        unless(allAccessibleFtypes) # not in cache, we have to get manually
          host = extractHost(uri)
          rsrcPath = "#{URI.parse(dbUri).path}/trks?connect=false"
          # Do we need to add back on gbKey?
          rsrcPath << "&gbKey=#{gbKey}" if(gbKey)
          dbName = @dbApiUriHelper.extractName(dbUri)
          hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
          authRec = Abstraction::User.getAuthRecForUserAtHost(host, hostAuthMap, @genbConf)
          login = authRec[0]
          apiCaller = BRL::Genboree::REST::ApiCaller.new(host, rsrcPath, hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          begin
            apiCaller.get()
            resp = apiCaller.parseRespBody()
            allAccessibleFtypes = {}
            resp['data'].each { |trk|
              allAccessibleFtypes[trk['text']] = nil
            }
            if(allAccessibleFtypes and !allAccessibleFtypes.empty?)
              # Store in cache:
              uriCache[:allAccessibleFtypes] ||= {} # init allAccessibleTracks-by-userId hash if not init'd previously
              uriCache[:allAccessibleFtypes][userId] = allAccessibleFtypes
            end
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not get trks for user #{login.inspect} at Genboree host #{host.inspect} for db: #{dbName.inspect}. Received a #{apiCaller.httpResponse.class}")
          end
        end
        retVal = (allAccessibleFtypes.nil? ? [] : allAccessibleFtypes)
      end
      return retVal
    end

    # Expand a database uri to its child track uris
    # @param [String] dbUri uri to database to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] track uris whose parent is dbUri
    # @raise [RuntimeError] if API server is down
    def getTracksInDb(dbUri, userId)
      trackUriArray = []
      uriObj = URI.parse(dbUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}/trks?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |trackDetail|
          trackUri = trackDetail['refs'][BRL::Genboree::REST::Data::DetailedTrackEntity::REFS_KEY]
          trackUriArray << trackUri
        }
      else
        raise "URI: #{dbUri.inspect} was inaccessible to the API caller."
      end
      return trackUriArray
    end

    # Expand a track entity list uri to its child track uris
    # @param [String] listUri uri to track entity list to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] track uris whose parent is listUri
    # @raise [RuntimeError] if API server is down
    def getTracksInList(listUri, userId)
      trackUriArray = []
      uriObj = URI.parse(listUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |trackDetail|
          trackUri = trackDetail['url']
          trackUriArray << trackUri
        }
      else
        raise "URI: #{listUri.inspect} was inaccessible to the API caller."
      end
      return trackUriArray
    end

    # Expand a class uri to its child track uris
    # @param [String] classUri uri to class to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] track uris whose parent is classUri
    # @raise [RuntimeError] if API server is down
    def getTracksInClass(classUri, userId)
      trackUriArray = []
      uriObj = URI.parse(classUri)
      rsrcPath = "#{uriObj.path}?#{uriObj.query}"
      apiCaller = WrapperApiCaller.new(uriObj.host, rsrcPath, userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |trackDetail|
          trackUri = trackDetail['refs'][BRL::Genboree::REST::Data::TextEntity::REFS_KEY]
          trackUriArray << trackUri
        }
      else
        raise "URI: #{rsrcPath.inspect} was inaccessible to the API caller.\n"\
              "Response body: #{apiCaller.respBody}"
      end

      return trackUriArray
    end

    def rsrcAbstraction(uri)
      trkObj = nil
      if(uri)
        # First, try from cache
        trkObj = getCacheEntry(uri, :abstraction)
        if(trkObj.nil?)
          # If not cached, try to retrieve it
          #
          type = lffType(uri)
          subtype = lffSubtype(uri)
          refSeqId = @dbApiUriHelper.id(uri)
          if(type and subtype and refSeqId and self.exists?(uri))
            trkObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, refSeqId, type, subtype)
            setCacheEntry(uri, :abstraction, trkObj)
          end
        end
      end
      return trkObj
    end
  end # class TrackApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
