#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/bkgrndLFFUpload'
require 'brl/genboree/bckgrndWIGUpload'
require 'brl/genboree/liveLFFDownload'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/annotationEntity'
require 'brl/genboree/abstract/resources/lffFile'
require 'brl/genboree/abstract/resources/gff3File'
require 'brl/genboree/abstract/resources/gtfFile'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/vcfFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # DbAnnos - Put/Get annos in a specific database. Note that uploads are _deferred_ using usual
  # uploader heuristics. So a 'successful' PUT request will just result in the upload job being "+ACCEPTED+"
  # although, it's possible the upload will later fail due to bad data.
  #
  # Data representation classes used:
  # * _none_, gets and delivers raw LFF text directly.
  class DbAnnos < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }
    ENV_VARS_TO_FIX = ['RUBYLIB', 'DBRC_FILE', 'DB_ACCESS_FILE', 'GENB_CONFIG', 'LD_LIBRARY_PATH', 'PATH', 'SITE_JARS', 'PERL5LIB', 'PYTHONPATH', 'DOMAIN_ALIAS_FILE', 'R_LIBS_USER']
    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/annos"

    RESOURCE_DISPLAY_NAME = "DB Annotations"
    def initialize(req, resp, uriMatchData)
      super(req, resp, uriMatchData)
      # Default repFormat for all API resources is :JSON but for this resource it should be :LFF
      @defResp = resp.dup() # default response
      @respFormat = :JSON
      @repFormat = :LFF
    end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @errOutFile = @lffFile = @lffFileBase = @refseqRow = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos$}     # Look for /REST/v1/grp/{grp}/db/annos URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        # Init and check group & database exist and are accessible
        initStatus = initGroupAndDatabase()
        @gbEnvSuffix = @genbConf.gbEnvSuffix
        if(initStatus == :OK)
          # Make sure either no tracks given or all tracks given exist and are accessible
          @trackNames = @nvPairs['trackName']
          @trackNames = [ @trackNames ] unless(@trackNames.nil? or @trackNames.is_a?(Array))
          if(@trackNames and @trackNames.is_a?(Array))
            @trackNames.each { |trackName|
              if(trackName !~ /:/)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "Track Name requires a ':'"
              elsif(trackName.split(":")[0].nil? or trackName.split(":")[0].empty?)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "Type cannot be empty in Track Name."
              elsif(trackName.split(":")[1].nil? or trackName.split(":")[1].empty?)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "Subtype cannot be empty in Track Name."
              elsif(trackName =~ /\t/)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "Track Name cannot have a tab character."
              else
                # Track name appears to be fine
              end
            }
          end
          # Hash containing format specific options
          @formatOptions = {}
          # Comma seperated list of format specific boolean options
          if(!@nvPairs['formatOpts'].nil?)
            formatOpts = @nvPairs['formatOpts'].split(',')
            formatOpts.map { |opt| @formatOptions[opt] = true }
          end
          # Get span
          if(!@nvPairs['span'].nil?)
            if(@nvPairs['span'].to_i > 0)
              @formatOptions['desiredSpan'] = @nvPairs['span'].to_i
            else
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "span must be a positive integer"
            end
          end
          # Get span aggregation function
          if(!@nvPairs['spanAggFunction'].nil? and !@nvPairs['spanAggFunction'].empty?)
            spanAggFunc = @nvPairs['spanAggFunction'].strip.downcase.to_sym
            availFunctions = { :med => true, :avg => true, :max => true, :min => true, :sum => true, :count => true, :stdev => true, :avgbylength => true }
            if(availFunctions.key?(spanAggFunc))
              @formatOptions['spanAggFunction'] = spanAggFunc
            else
              initStatus = @statusName = :'Bad Request'
              @statusMsg = 'span aggregation function (spanAggFunction) must be one of: ' + availFunctions.keys.join(', ')
            end
          else
            @formatOptions['spanAggFunction'] = :med
          end
          # Make sure the requested span is not larger than 20_000_000 if the aggregation function is median
          if((@formatOptions['spanAggFunction'] == :med) and !@formatOptions['desiredSpan'].nil? and @formatOptions['desiredSpan'] > 20_000_000)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = 'requested span cannot be more than 20,000,000 if the aggregating function is median (median is the default aggregation function)'
          end
          ucscTrackHeader = @nvPairs['ucscTrackHeader']
          if(ucscTrackHeader and !ucscTrackHeader.empty? and ucscTrackHeader =~ /^(?:yes|true)/i)
            @ucscTrackHeader = true
          elsif(ucscTrackHeader and !ucscTrackHeader.empty? and ucscTrackHeader =~ /^(?:false|no)/i)
            @ucscTrackHeader = false
          else
            if(@repFormat == :BED or @repFormat == :BEDGRAPH or @repFormat == :BED3COL or @repFormat == :GFF3)
              @ucscTrackHeader = true
            else
              @ucscTrackHeader = false
            end
          end
          rColHeaders = @nvPairs['colHeaders']
          @colHeaders = if(rColHeaders and !rColHeaders.empty? and rColHeaders =~ /^(?:no|false)/i) then false else true end
          rLandmark = @nvPairs['landmark']
          @landmark = if(rLandmark and !rLandmark.empty?) then rLandmark.strip else nil end
          # Get all the tracks in this user database (includes shared tracks) [that user has access to]
          ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
          # Check and parse various params
          initStatus = parseParameters(initStatus, ftypesHash)
          if(@reqMethod == :get)
            if(!@trackNames.nil? and !@trackNames.empty?) # downloading multiple specific tracks
              # Have 1+ trackName args, do some checking w.r.t. existence and permissions
              # Must check that each track exists and is accessible by user also...once we launch the downloader it will be impossible to
              # determine if it succeeds or fails, so we want to check as much as possible -now-.
              # - whole thing fails if any 1 track mentioned cannot be found in this group & database
              #
              # Verify each track is accessible, etc.
              @trackNames.each { |trackName|
                # Get just the one ftypeRow matching the track
                @ftypeHash = ftypesHash[trackName]
                if(@ftypeHash.nil? or @ftypeHash.empty?)
                  initStatus = :'Not Found'
                  @statusMsg = "NO_TRK: There is no track #{trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?). You should double-check other tracks you provided as well."
                  break
                end
              }
            else # downloading all tracks user has access to
              # Need to generate a trackNames array for the downloader
              @trackNames = []
              ftypesHash.each_key { |row|
                @trackNames << row
              }
            end
          end
        end
      end
      return initStatus
    end

    def parseParameters(initStatus, trkHash)
      # Check and parse ROI track
      # Note that the ROI track has to be a non high density track
      dbApiUriHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      trackApiUriHelperObj = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      if(!@nvPairs['ROITrack'].nil? and !@nvPairs['ROITrack'].empty?)
        tempHash = {}
        roiTrack = @nvPairs['ROITrack']
        dbRecord = dbApiUriHelperObj.tableRow(roiTrack)
        # if dbRecord is nil it should be a track name
        if(dbRecord.nil?)
          if(!trkHash.has_key?(roiTrack))
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "NO_TRK: There is no track #{roiTrack.inspect} " +
                        "in database #{@dbName.inspect} in user group #{@groupName.inspect}"
          else
            tempHash[roiTrack] = @refSeqId
          end
        # else 'roiTrack' is a URL
        else
          # get the uri for the main track
          verEquals = dbApiUriHelperObj.dbsVersionsMatch?([@rsrcURI, roiTrack])
          if(!verEquals)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "db version for ROI track: #{dbApiUriHelperObj.dbVersion(roiTrack).inspect} is not same as db " +
                         "version of resource track: #{dbApiUriHelperObj.dbVersion(@rsrcURI).inspect}"
          end

          # now get all tracks accessible by the user and check if score track is in that list
          # ARJ: code in this section was loading Config unnecessarily rather than re-using @genbConf like other resource classes.
          # ARJ: also, this section creates a new DBUtil instance rather than reusing already available @dbu, so it is contributing
          #      to overwhleming number of sockets which caused problems on web server side.
          # ARJ: will try to resuse @dbu here rather than local (and new) "dbuROI", but maybe new dbuScore is necessary due to some weird side effects
          #      and bad design of this code.
          #gc = BRL::Genboree::GenboreeConfig.load
          gc = @genbConf
          #dbuROI = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
          dbuROI = @dbu
          dbuROI.setNewDataDb(dbRecord['databaseName'])
          roiTrackDbHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(dbRecord['refSeqId'].to_i, @userId, true, dbuROI)
          roiTrackType = trackApiUriHelperObj.lffType(roiTrack)
          roiTrackSubType = trackApiUriHelperObj.lffSubtype(roiTrack)
          roiTrackName = "#{roiTrackType}:#{roiTrackSubType}"
          if(!roiTrackDbHash.has_key?(roiTrackName))
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "NO_TRK: There is no track: #{roiTrackName.inspect} in db: #{dbRecord['refseqName']}. (or user does not have permission?)"
          end
          tempHash[roiTrackName] = dbRecord['refSeqId'].to_i
        end
        if(initStatus == :OK)
          @formatOptions['ROITrack'] = Hash.new
          @formatOptions['ROITrack'] = tempHash
        end

        # wig not allowed with ROI track
        if(NON_LIFTABLE_FORMATS.key?(@repFormat))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with ROITrack"
        end
      end

      # Check if gname is provided, if it is ROI track also must be provided
      @formatOptions['gname'] = @nvPairs['gname'] if(!@nvPairs['gname'].nil? and !@nvPairs['gname'].empty?)
      if(@formatOptions['gname'] and !@formatOptions['ROITrack'])
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "ROITrack must be provided with gname"
      end

      # Landmark cannnot be provided with ROI track
      if(@landmark and @formatOptions['ROITrack'])
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "landmark cannot be provided with ROITrack"
      end

      # Check and parse (if provided) scoreTrack
      # Note that the scoreTrack must be HDHV
      if(!@nvPairs['scoreTrack'].nil? and !@nvPairs['scoreTrack'].empty?)
        # Generate error if 'ROITrack' also provided
        if(!@nvPairs['ROITrack'].nil? and !@nvPairs['ROITrack'].empty?)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "Both ROITRack and scoreTrack cannot be provided"
        end

        tempHash = {}
        scoreTrack = @nvPairs['scoreTrack']
        dbRecord = dbApiUriHelperObj.tableRow(scoreTrack)
        # if dbRecord is nil it should be a track name
        if(dbRecord.nil?)
          if(!trkHash.has_key?(scoreTrack))
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "NO_TRK: There is no score track #{scoreTrack.inspect} " +
                        "in database #{@dbName.inspect} in user group #{@groupName.inspect}"
          else
            tempHash[scoreTrack] = @refSeqId
          end
        # else 'scoreTrack' is a URL
        else
          verEquals = dbApiUriHelperObj.dbsVersionsMatch?([@rsrcURI, scoreTrack])
          if(!verEquals)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "db version for score track: #{dbApiUriHelperObj.dbVersion(scoreTrack).inspect} is not same as " +
                          "db version of resource track: #{dbApiUriHelperObj.dbVersion(@rsrcURI).inspect}"
          end
          # now get all tracks accessible by the user and check if score track is in that list
          # ARJ: code in this section was loading Config unnecessarily rather than re-using @genbConf like other resource classes.
          # ARJ: also, this section creates a new DBUtil instance rather than reusing already available @dbu, so it is contributing
          #      to overwhleming number of sockets which caused problems on web server side.
          # ARJ: will try to resuse @dbu here rather than local (and new) "dbuScore", but maybe new dbuScore is necessary due to some weird side effects
          #      and bad design of this code.
          #gc = BRL::Genboree::GenboreeConfig.load
          gc = @genbConf
          #dbuScore = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
          dbuScore = @dbu
          gc = BRL::Genboree::GenboreeConfig.load
          dbuScore = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
          dbuScore.setNewDataDb(dbRecord['databaseName'])
          scoreTrackDbHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(dbRecord['refSeqId'].to_i, @userId, true, dbuScore)
          scoreTrackType = trackApiUriHelperObj.lffType(scoreTrack)
          scoreTrackSubType = trackApiUriHelperObj.lffSubtype(scoreTrack)
          scoreTrackName = "#{scoreTrackType}:#{scoreTrackSubType}"
          if(!scoreTrackDbHash.has_key?(scoreTrackName))
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "NO_TRK: There is no score track: #{scoreTrackName.inspect} in db: #{dbRecord['refseqName']}. (or user does not have permission?)"
          end
          tempHash[scoreTrackName] = dbRecord['refSeqId'].to_i
        end
        if(initStatus == :OK)
          @formatOptions['scoreTrack'] = Hash.new
          @formatOptions['scoreTrack'] = tempHash
        end
        # wig not allowed with ROI track
        if(NON_LIFTABLE_FORMATS.key?(@repFormat))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with scoreTrack"
        end
      end

      # Check for 'nameFilter'
      if(!@nvPairs['nameFilter'].nil? and !@nvPairs['nameFilter'].empty?)
        @formatOptions['nameFilter'] = @nvPairs['nameFilter']
      end

      # Landmark cannot be provided with 'nameFilter'
      if(@landmark and @formatOptions['nameFilter'])
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "landmark cannot be provided with nameFilter"
      end

      # Check for 'emptyScoreValue'
      @formatOptions['emptyScoreValue'] = @nvPairs['emptyScoreValue'] if(!@nvPairs['emptyScoreValue'].nil? and !@nvPairs['emptyScoreValue'].empty?)

      # check for 'scoreFile'
      if(!@nvPairs['scoreFile'].nil? and !@nvPairs['scoreFile'].empty?)
        fullPath = @nvPairs['scoreFile']
        genbConf = ENV['GENB_CONFIG']
        genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
        scoreFilePath = genbConfig.gbDataFileRoot.to_s + fullPath.slice(fullPath.index('/grp/')..-1).gsub("/file", "")
        if(!File.exists?(scoreFilePath))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: scoreFile: #{@nvPairs['scoreFile']} does not exist"
        end
        @formatOptions['scoreFile'] = scoreFilePath
        if(NON_LIFTABLE_FORMATS.key?(@repFormat))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with scoreFile"
        end
      end

      # Both scoreTrack and scoreFile cannot be provided
      if(@formatOptions['scoreFile'] and @formatOptions['scoreTrack'])
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "BAD_REQUEST: scoreFile and scoreTrack cannot be provided together"
      end

      # Check for 'extendAnnos' and 'truncateAnnos'
      # add extendValue and truncateValue if not provided (default: 200)
      extendAnnos = @nvPairs['extendAnnos']
      @extendAnnos = if(extendAnnos and !extendAnnos.empty? and extendAnnos =~ /^(?:yes|true)/i) then true else false end
      if(@extendAnnos)
        @formatOptions['extendAnnos'] = nil
        if(!@nvPairs['extendValue'].nil? and !@nvPairs['extendValue'].empty?)
          extendValue = @nvPairs['extendValue']
          # Make sure its an integer value
          if(extendValue !~ /^\d+$/)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: 'extendValue' not an integer value"
          else
            @formatOptions['extendAnnos'] = extendValue.to_i
          end
        else
          @formatOptions['extendAnnos'] = 200 # use 200 as default extend value for now
        end
      end
      truncateAnnos = @nvPairs['truncateAnnos']
      @truncateAnnos = if(truncateAnnos and !truncateAnnos.empty? and truncateAnnos =~ /^(?:yes|true)/i) then true else false end
      if(@truncateAnnos)
        @formatOptions['truncateAnnos'] = nil
        if(!@nvPairs['truncateValue'].nil? and !@nvPairs['truncateValue'].empty?)
          truncateValue = @nvPairs['truncateValue']
          # Make sure its an integer value
          if(truncateValue !~ /^\d+$/)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: 'truncateValue' not an integer value"
          else
            @formatOptions['truncateAnnos'] = truncateValue.to_i
          end
        else
          @formatOptions['truncateAnnos'] = 200 # use 200 as default truncate value for now
        end
      end
      if((@extendAnnos or @truncateAnnos) and (NON_LIFTABLE_FORMATS.key?(@repFormat)))
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "#{@repFormat}.to_s.downcase format not allowed with extendAnnos or truncateAnnos"
      end

      # Check for the zoomLevels flag, if 'zoomLevelsRes' not provided use 100k res
      zoomLevels = @nvPairs['zoomLevels']
      @zoomLevels = if(zoomLevels and !zoomLevels.empty? and zoomLevels =~ /^(?:yes|true)/i) then true else false end
      if(@zoomLevels)
        if(!@nvPairs['zoomLevelsRes'].nil? and !@nvPairs['zoomLevelsRes'].empty?)
          @zoomLevelsRes = @nvPairs['zoomLevelsRes']
          if(@zoomLevelsRes != 5 and @zoomLevelsRes != 4)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: zoomLevelsRes needs to be either 5 (100Kbp) or 4 (10Kbp)."
          end
        else
          @zoomLevelsRes = 5
        end
        if(!@nvPairs['zoomLevelsFunction'].nil? and !@nvPairs['zoomLevelsFunction'].empty?)
          @zoomLevelsFunction = @nvPairs['zoomLevelsFunction']
          @zoomLevelsFunction.upcase!
          if(@zoomLevelsFunction != "AVG" and @zoomLevelsFunction != "MIN" and @zoomLevelsFunction != "MAX")
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: zoomLevelsFunction needs to be either 'MIN' or 'MAX' or 'AVG'"
          end
        else
          @zoomLevelsFunction = "AVG"
        end
        @formatOptions['zoomLevels'] = [@zoomLevelsRes, @zoomLevelsFunction]
      end

      # Check for 'modulusLastSpan': used for calculating the precise span for the last record of a wig file for bigwig generation
      # 'true' by default
      modLastSpan = @nvPairs['modulusLastSpan']
      @modulusLastSpan = 'true'
      if(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:yes|true|ucscStyle)/i)
        @modulusLastSpan = modLastSpan
      elsif(modLastSpan and !modLastSpan.empty? and modLastSpan =~ /^(?:no|false)/i)
        @modulusLastSpan = false
      else # true by default
        @modulusLastSpan = 'true'
      end
      @formatOptions['modulusLastSpan'] = @modulusLastSpan

      # Check for 'collapsedCoverage':
      collapsedCoverage = @nvPairs['collapsedCoverage']
      @collapsedCoverage = if(collapsedCoverage and !collapsedCoverage.empty? and collapsedCoverage =~ /^(?:yes|true)/i) then 'true' else false end
      @formatOptions['collapsedCoverage'] = @collapsedCoverage

      # Span must be provided with collapsedCoverage option
      if(@collapsedCoverage and !@formatOptions['desiredSpan'])
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "BAD_REQUEST: 'span' parameter required with collapsedCoverage option"
      end

      addCRC32Line = @nvPairs['addCRC32Line']
      @addCRC32Line = if(addCRC32Line and !addCRC32Line.empty? and addCRC32Line =~ /^(?:yes|true)/i) then 'true' else false end
      @formatOptions['addCRC32Line'] = @addCRC32Line

      ucscScaling = @nvPairs['ucscScaling'] # will be turned on by default for 'bed'. Can be turned on for 'gtf', 'gff' and 'gff3'
      if(@repFormat == :BED)
        @scaleScores = if(ucscScaling and !ucscScaling.empty? and ucscScaling =~ /^(?:no|false)/i) then 0 else 1 end
        @formatOptions['scaleScores'] = @scaleScores
      else
        @scaleScores = if(ucscScaling and !ucscScaling.empty? and ucscScaling =~ /^(?:true|yes)/i) then 1 else 0 end
        @formatOptions['scaleScores'] = @scaleScores
      end
      # See if column header is required
      addColHeader = @nvPairs['addColHeader']
      @formatOptions['addColHeader'] = if(addColHeader and !addColHeader.empty? and addColHeader =~ /^(?:yes|true)/i) then true else false end
      @formatOptions['addColHeader'] = false if(@repFormat == :VCF) # We will manually add the track header for VCF
      # See if chromosome info has to be added (only for lff)
      addChrInfo = @nvPairs['addChrInfo']
      if(addChrInfo and !addChrInfo.empty? and addChrInfo =~ /^(?:yes|true)/i)
        if(@repFormat != :LFF)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: Chr info cannot be requested unless format is LFF"
        else
          @formatOptions['addChrInfo'] = true
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # Because this delivers raw LFF text from the downloader, it does not make use
    # of many of the conveniences of the API server framework. It has to do a lot manually,
    # and in a special way. So the implementation here is quite long, relative to other resource classes.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      # when doing get, look for trackName (zero or more) and a landmark
      initStatus = initOperation()
      if(initStatus == :OK)
        prepResponse()
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def initPut()
      initStatus = initOperation()
      if(initStatus == :OK)
        @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
        @dbApiHelper.rackEnv = @rackEnv if(@rackEnv)
        # This request could be submitted by the superuser (userId => -10)
        # If so, get the optional URL parameter 'userId' to pass on to the uploaders
        # so that the emails get sent to the right people.
        # $stderr.puts "userId: #{@userId}\tuserIdFromOptions: #{@nvPairs['userId']}"
        if(@userId == @genbConf.gbSuperuserId.to_i)
          if(@nvPairs['userId'])
            # Ensure that the user has permission ('o' or 'w') to upload to the database.  If they don't the AutoUploader will fail
            altUserId = @nvPairs['userId'].to_i
            if(@dbApiHelper.accessibleByUser?(@rsrcURI, altUserId, [ 'w', 'o' ]))
              @userId = altUserId
              # set email id for this user:
              userRec = @dbu.getUserByUserId(@userId)
              @userEmail = userRec.first['email']
            else
              # FAILED: doesn't have write access to output database
              initStatus = :'Forbidden'
              @statusMsg = "FORBIDDEN: The userId : #{@nvPairs['userId']} provided does not have sufficient access or permissions to write to this database #{@dbName.inspect}."
            end
          else
            # FAILED: userId is required for a gbSuperuser upload
            initStatus = :'Bad Request'
            @statusMsg = "MISSING_USERID: The URL parameter userId is not set.  userId is required when uploading as superuser and must be a valid user with write permission to database #{@dbName.inspect}."
          end
        else
          # Ensure the user has write permission to this database
          unless(@dbApiHelper.accessibleByUser?(@rsrcURI, @userId, [ 'w', 'o' ])) # or superUser
            # FAILED: doesn't have write access to output database
            initStatus = :'Forbidden'
            @statusMsg = "FORBIDDEN: The userName provided does not have sufficient access or permissions to write to this database #{@dbName.inspect}."
          end
        end
        
        # if the put request uses a format other than lff or gff, at least one track name is required
        if(@repFormat != :LFF and @repFormat != :GFF3)
          if(@trackNames.nil? or @trackNames.empty?)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "You must specify a trackName with a colon separating the track type and subtype in the query string. For example, \".../annos?trackName=BED:track\""
          end
        end
        
      end
      return initStatus
    end

    # Process a PUT operation on this resource.
    # Because this accepts raw LFF text from the downloader, it does not make use
    # of many of the conveniences of the API server framework. It has to do a lot manually,
    # and in a special way. So the implementation here is quite long, relative to other resource classes.
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initPut()
      if(initStatus == :OK)
        # Prep lff file to save to and upload out file to use
        self.prepLFFFile()
        # Read through @req.body and save to file
        byteCount = 0
        @req.body.rewind if(@req.body.respond_to?(:rewind))
        if(@req.body.is_a?(Tempfile) or @req.body.is_a?(File))
          @req.body.flush rescue nil
          `mv #{@req.body.path} #{@lffFile}`
          @req.body.close()
          if($?.exitstatus != 0)
            initStatus = @statusName = :'Internal Server Error'
            @statusMsg = "INTERNAL_SERVER_ERROR: Failed to mv Tempfile: #{@req.body.path rescue "path unavailable!"} (Class: #{@req.body.class}) to #{@lffFile}."
          end
        else
          lffFileWriter = File.open(@lffFile, 'w+')
          @req.body.each_line { |block| # more likely a line but who knows
            lffFileWriter.print(block)
            byteCount += block.size
          }
          lffFileWriter.close()
        end
        if(initStatus == :OK)
          @initStatus = :OK
          # Make uploader
          # Make the dir for the bin file if it does not exit
          system("mkdir -p /usr/local/brl/data/genboree/ridSequences/#{@refSeqId}")
          # Create an entry for RID_SEQUENCE_DIR in the fmeta table
          # ARJ: these 4 lines were creating a new DBUtil every call. Tonnes of MySQL connections, causing web-server socket problems.
          # ARJ: will try to properly reuse @dbu like other resource classes do.
          #dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
          dbName = @dbu.selectDBNameByRefSeqID(@refSeqId)[0]['databaseName']
          @dbu.setNewDataDb(dbName)
          @dbu.updateFmetaEntry('RID_SEQUENCE_DIR', "/usr/local/brl/data/genboree/ridSequences/#{@refSeqId}")
          gc = BRL::Genboree::GenboreeConfig.load
          useCluster = gc.useClusterForAPI
          uploader = nil
          if(useCluster == 'true' and @repFormat != :GBTABBEDDBRECS)
            apiCaller = nil
            userRec = nil
            inputs = nil
            outputs = nil
            context = nil
            settings = nil
            # Transfer file to 'Raw Data Files' folder of the database where the track is being uploaded.
            gbDataFileRoot = @genbConf.gbDataFileRoot
            `mkdir -p #{gbDataFileRoot}/grp/#{@groupId}/db/#{@refSeqId}/Raw%20Data%20Files`
            `mv #{@lffFile} #{gbDataFileRoot}/grp/#{@groupId}/db/#{@refSeqId}/Raw%20Data%20Files`
            fileName = "Raw Data Files/#{File.basename(@lffFile)}"
            @dbu.insertFile(fileName, fileName, nil, 0, 0, Time.now(), Time.now(), @userId)
            userRec = @dbu.selectUserById(@userId).first
            apiCaller = ApiCaller.new(@genbConf.machineName, "/REST/v1/genboree/tool/uploadTrackAnnos/job?", @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            inputs = ["http://#{@genbConf.machineName}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}/file/Raw%20Data%20Files/#{File.basename(@lffFile)}?"]
            outputs = ["http://#{@genbConf.machineName}/REST/v1/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@dbName)}?"]
            context = {
                          "toolIdStr" => "uploadTrackAnnos",
                          "queue" => "gbApiHeavy",
                          "userId" => @userId,
                          "toolTitle" => "Upload Track Annotations",
                          "userLogin" => userRec['name'],
                          "userLastName" => userRec['lastName'],
                          "userFirstName" => userRec['firstName'],
                          "userEmail" => userRec['email'],
                          "gbAdminEmail" => @genbConf.gbAdminEmail,
                          "warningsConfirmed" => true
                        }
            lffType, lffSubType = @trackNames.first.split(":") if(@repFormat != :LFF and @repFormat != :GFF3)
            # Determine default class for format, if any
            # - how & whether we use this default depends on what the user provided and the format
            # - but get default first
            defClassName = Abstraction::Track.getDefaultClass(@repFormat)
            # Prep upload job settings
            settings =
            {
              "Skip non-assembly chromosomes" => "on",
              "Skip out-of-range annotations" => "on"
            }
            if(@repFormat == :WIG or @repFormat == :FWIG or @repFormat == :VWIG) # all wig formats
              settings.merge!(
              {
                "trackClassName"  => (@nvPairs["trackClassName"] or defClassName),
                "inputFormat"     => "wig",
                "lffType"         => lffType,
                "lffSubType"      => lffSubType,
              })
            elsif(@repFormat == :LFF)
              settings.merge!(
              {
                "inputFormat" => "lff",
              })
            elsif(@repFormat == :GFF3)
              settings.merge!(
              {
                "trackClassName"  => (@nvPairs["trackClassName"] or defClassName),
                "inputFormat"     => "lff",
              })
            else # BED, BEDGRAPH, GFF, etc
              settings.merge!(
              {
                "trackClassName"  => (@nvPairs["trackClassName"] or defClassName),
                "inputFormat"     => @repFormat.to_s.downcase,
                "lffType"         => lffType,
                "lffSubType"      => lffSubType,
              })
            end
            payload = {"inputs" => inputs, "outputs" => outputs, "context" => context, "settings" => settings}
            # Do a 'put' on the toolJob resource on 'this' machine
            apiCaller.put(payload.to_json)
            # pass on the status of preparing the job to the API caller handling this PUT request
            respHash = apiCaller.parseRespBody()
            unless(respHash.nil? or respHash.is_a?(Exception))
              @statusName = @initStatus = respHash['status']['statusCode'].to_sym
              if(apiCaller.succeeded?)
                # the toolJob resource's configured response includes a (trivially) serialized text entity with the job name and usually no
                # status message -- we pass along this information and add some more detail 
                msg = "Your job has been accepted with Job Id: #{respHash['data']['text']}."
                unless(respHash['status']['msg'].nil? or respHash['status']['msg'].empty?)
                  msg << " #{respHash['status']['msg']}"
                end
                @statusMsg = msg
                @resp.status = HTTP_STATUS_NAMES[@statusName]
                entity = BRL::Genboree::REST::Data::TextEntity.new(false, respHash['data']['text'])
                entity.setStatus(@statusName, @statusMsg)
                @resp.body = entity.to_json() # assume @respFormat fixed to JSON
                @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@respFormat]
                @resp['Content-Length'] = @resp.body.size.to_s
              else
                @statusMsg = respHash['status']['msg']
              end
            else
              @statusName = @initStatus = :"Internal Server Error"
              @statusMsg = "The server was unable to determine whether or not your track annotations were prepared for upload."
            end
          else
            if(@repFormat == :WIG or @repFormat == :FWIG or @repFormat == :VWIG) # all wig formats
              windowingMethod = nil
              if(@nvPairs.has_key?("gbTrackWindowingMethod") or @nvPairs.has_key?("w"))
                if(@nvPairs.has_key?("gbTrackWindowingMethod"))
                  windowingMethod = @nvPairs['gbTrackWindowingMethod'] if(@nvPairs['gbTrackWindowingMethod'] =~ /^(?:MAX|MIN|AVG)$/i)
                  windowingMethod.upcase!
                elsif(@nvPairs.has_key?("w"))
                  windowingMethod = @nvPairs['w'] if(@nvPairs['w'] =~ /^(?:MAX|MIN|AVG)$/i)
                  windowingMethod.upcase!
                end
              end
              # for record type:
              recordType = nil
              if(@nvPairs.has_key?("recordType") or @nvPairs.has_key?("z"))
                if(@nvPairs.has_key?("recordType"))
                  recordType = @nvPairs['recordType'] if(@nvPairs['recordType'] == "floatScore" or @nvPairs['recordType'] == "doubleScore")
                elsif(@nvPairs.has_key?("z"))
                  recordType = @nvPairs['z'] if(@nvPairs['z'] == "floatScore" or @nvPairs['z'] == "doubleScore")
                end
              end
              useLog = nil
              useLog = true if(@nvPairs.has_key?("useLog") or @nvPairs.has_key?("o"))
              attributesPresent = nil
              attributesPresent = true if(@nvPairs.has_key?("attributesPresent") or @nvPairs.has_key?("A"))
              uploader = BRL::Genboree::BckGrndWIGUploader.new(@userId, @refSeqId, @groupName, @userEmail, @lffFile, @taskErrOutFilesBase)
              # Here we set any options that we have ALREADY checked carefully and sanitized their values.
              # The trackName, if given, will be within the standard @trackNames Array that is init'd in initOperation()
              # It will be passed to the program via CGI.escape() approach, so is safe for command line as-is.
              uploader.trackName = @trackNames.first if(@trackNames and @trackNames.is_a?(Array) and !@trackNames.empty?)
              uploader.windowingMethod = windowingMethod
              uploader.recordType = recordType
              uploader.useLog = useLog
              uploader.attributesPresent = attributesPresent
            elsif(@repFormat == :LFF)
              uploader = BRL::Genboree::BckGrndLFFUploader.new(@userId, @refSeqId, @groupId, @lffFile, @taskErrOutFilesBase)
            elsif(@repFormat == :GBTABBEDDBRECS)
              annosFormat = @nvPairs['annosFormat']
              if(annosFormat == 'lff')
                uploadStatus = runLFFUploader()
                unless(uploadStatus)
                  @initStatus = @statusName = :'Internal Server Error'
                  baseDir = File.dirname(@lffFile)
                  @statusMsg = "INTERNAL_SERVER_ERROR: Please ask the Genboree admins to check the log files under #{baseDir}."
                end
              else
                ftypeIdRecs = @dbu.selectFtypeByTrackName(@trackNames.first)
                if(ftypeIdRecs.empty?)
                  @initStatus = @statusName = :"Not Found"
                  @statusMsg = "NOT_FOUND: Track must be created in order to insert blockLevel/zoomLevel records with the API."
                else
                  # Get the list of entrypoints (required for substituting)
                  frefHash = Hash.new()
                  annosType = @nvPairs['annosType']
                  begin
                    if(annosType == 'blockLevels')
                      @dbu.loadDataWithFile('blockLevelDataInfo', @lffFile)
                    else # must be zoomLevels
                      @dbu.loadDataWithFile('zoomLevels', @lffFile, true)
                    end
                  rescue => loadFileErr
                    @initStatus = @statusName = :'Internal Server Error'
                    @statusMsg = "INTERNAL_SERVER_ERROR: #{loadFileErr}"
                  end
                end
              end
            else
              @initStatus = @statusName = :'Bad Request'
              @statusMsg = "BAD_REQUEST: Formats other than wig/lff/gbTabbedDbRecs cannot be uploaded via the API if useCluster=false"
            end
          end
          if(@initStatus == :OK)
            if(useCluster == "true")
              if(@repFormat != :GBTABBEDDBRECS)
                $stderr.puts "#{self.class}##{__method__}: AFTER inserting job on cluster => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
                $stderr.puts "Job: #{@jobId} with id: #{@schedJobId} launched on cluster"
              end
            else
              $stderr.puts "#{self.class}##{__method__}: AFTER making uploader object.  put() => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
              # Do upload
              wrapperExitStatus = uploader.doUpload()
              $stderr.puts "#{self.class}##{__method__}: AFTER uploader.doUpload() => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
              # Command -should- be running in the background at this point. But maybe not. Let's close the IOs
              # to help test this and ensure they aren't left open
              $stderr.puts "#{self.class}##{__method__}: #{'#'*40}\nAPI LFF UPLOADER STARTED (actually genbTaskWrapper.rb, via BckGrndLFFUploader class). Wrapper exit status: #{wrapperExitStatus}\n#{'#'*40}"
              # Make sure to return proper status (accepted or something) & message
            end
            # if we are here, everything seems OK but we haven't set a more detailed status yet, set this one
            @statusName = :Accepted
            @statusMsg = "ACCEPTED: Your data has been transferred and is now scheduled for validation & uploading; it will be processed when the load & task queue permit. You should get an email at #{@userEmail}.  "
          else
            initStatus = @initStatus
          end
        end
      else
        @statusName = initStatus
      end
      if(@resp == @defResp)
        # no response has been set yet, set an empty response (no data to send back)
        @resp = representError()
      # else we have already set a response, dont change it
      end
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS:
    #------------------------------------------------------------------
    def envPathFix(envVar, gbEnvSuffix=@gbEnvSuffix)
      gbEnvSuffix = '""' unless(gbEnvSuffix and !gbEnvSuffix.empty?)
      return  "export #{envVar}=` ruby -e 'print ENV[ARGV.first.strip].gsub(%r{#{@clusterSharedRoot}/local/}, \"#{@clusterSharedRoot}/local#\{ARGV[1].strip\}/\")' #{envVar} #{gbEnvSuffix}` "
    end

    def runLFFUploader()
      retVal = true
      baseDir = File.dirname(@lffFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting zoom level script")
      cmd = "createZoomLevelsForLFF.rb -i #{CGI.escape(@lffFile)} -d #{@refSeqId} -g #{CGI.escape(@groupName)} -u #{@userId} -C -e -V > #{baseDir}/zoomLevels.out 2> #{baseDir}/zoomLevels.err"
      `#{cmd}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done adding zoom levels")
      #`createZoomLevelsAndUploadLFF.rb -i #{@lffFile} -g #{CGI.escape(@groupName)} -u #{@userId} -d #{@refSeqId} -V -e > #{baseDir}/createZoomLevelsAndUploadLFF.out 2> #{baseDir}/createZoomLevelsAndUploadLFF.err`
      if($?.exitstatus == 0)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting ruby lff uploader")
        #`java -classpath $CLASSPATH -Xmx1800M org.genboree.upload.AutoUploaderCluster -t lff -u #{@userId} -r #{@refSeqId} -f #{@lffFile} -b > #{baseDir}/autoUploader.out 2> #{baseDir}/autoUploader.err`
        `lffUploader.rb -i #{CGI.escape(@lffFile)} -u #{@userId} -r #{@refSeqId} --skipVal > #{baseDir}/lffUploader.out 2> #{baseDir}/lffUploader.err`
        retVal = false if($?.exitstatus != 0)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done running ruby lff uploader")
      else
        retVal = false
      end
      return retVal
    end

    # Generates the output adding it to @resp
    # [+returns+] @resp
    def prepResponse()
      retVal = nil
      @resp.body = ''

      # Create Track abstraction instances. We need to ask questions.
      trackObjs = {}
      @trackNames.each { |trackName|
        method, source = trackName.split(':')
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source)
        trackObjs[trackName] = trackObj
      }
      # Are any track tagged as not-downloadable? (via gbNotDownloadable attribute being true|yes)
      status = checkTracksDownloadable(trackObjs.values)
      if(status == :OK)
        if(@apiError.nil? and @statusName == :OK)
          case @repFormat
          when :BED, :BED3COL, :GFF, :WIG, :VWIG, :FWIG, :LFF, :GTF, :GFF3, :BEDGRAPH, :VCF
            @resp.body = ''
            @resp.status = HTTP_STATUS_NAMES[:OK]
            @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@repFormat]
            ## Get the data from the bedFile object
            annoFileObj = case @repFormat
              when :BED then BRL::Genboree::Abstract::Resources::BedFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :BEDGRAPH then BRL::Genboree::Abstract::Resources::BedGraphFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :BED3COL then BRL::Genboree::Abstract::Resources::Bed3ColFile.new(@dbu, nil, @ucscTrackHeader)
              when :GFF then BRL::Genboree::Abstract::Resources::GffFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :WIG then BRL::Genboree::Abstract::Resources::VWigFile.new(@dbu, nil, true, @formatOptions) # defaults to variable step
              when :VWIG then BRL::Genboree::Abstract::Resources::VWigFile.new(@dbu, nil, true, @formatOptions)
              when :FWIG then BRL::Genboree::Abstract::Resources::FWigFile.new(@dbu, nil, true, @formatOptions)
              when :LFF then BRL::Genboree::Abstract::Resources::LffFile.new(@dbu, nil, false, @formatOptions)
              when :GTF then BRL::Genboree::Abstract::Resources::GtfFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :GFF3 then BRL::Genboree::Abstract::Resources::Gff3File.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :VCF then BRL::Genboree::Abstract::Resources::VcfFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
            end
            annoFileObj.showColumnHeader = @formatOptions['addColHeader']
            annoFileObj.setTrackList(@trackNames, @refSeqId, @landmark)
            if(annoFileObj.error)
              @apiError = annoFileObj.error
            else
              @resp.body = annoFileObj
            end
            retVal = @resp
          when :LAYOUT
            prepDownloadErrorFile() # Helper-provided function
            # Because of checking in initOperation() we can assume either @layout or @layoutName are set
            if(@layout)
              downloader = BRL::Genboree::TabularDownload.new(@userId, @refSeqId, @trackNames, @layout, @landmark)
            else
              downloader = BRL::Genboree::TabularDownload.new(@userId, @refSeqId, @trackNames, @layoutName, @landmark)
            end
            downloader.errFile = @errFile
            tabStdin, tabStdout, tabStderr = downloader.doDownload()
            tabStdin.close
            tabStderr.close
            # Return the response as an io stream of the appropriate data.
            @resp.status = HTTP_STATUS_NAMES[:OK]
            @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:LAYOUT]
            @resp.body = tabStdout
            retVal = @resp
          else
            @statusName, @statusMsg = :'Bad Request', 'The format specified is not supported. Acceptable formats include: bed, bedGraph, bed3col, lff, gff, wig, vwig, fwig, layout'
          end
        end
      else # 1+ tracks not downloadable
        # @statusMsg has been set, but add some advice for doing selective track downloads:
        @statusMsg += " You could list the specific tracks you want to download via the 'trackNames' query string parameter, making sure to avoid these non-downloadable ones."
      end
      return retVal
    end

    # Helper: prepare the response object to deliver bunch of raw LFF text
    # [+lffStream+] An IO stream from which LFF data can be +read+.
    # [+returns+]   The existing <tt>Rack::Response</tt> instance
    def prepLargeLFFResponse(lffStream)
      @resp.status = HTTP_STATUS_NAMES[:OK]
      @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:LFF]
      @resp.body = lffStream
      return @resp
    end

    # Helper: prepare an upload directory and file in which to put the incoming LFF data.
    # [+returns+] _none_
    def prepLFFFile()
      apiUploadDir = @genbConf.gbApiUploadDir
      @lffFileBase = "#{apiUploadDir}/#{CGI.escape(@groupName)}/#{CGI.escape(@dbName)}/#{CGI.escape(@gbLogin)}/#{Time.now.strftime("%Y-%m-%d_%H-%M-%S")}"
      lffFile = "#{Time.now.to_f}_#{sprintf('%05d', rand(65535))}_uploadedViaApi"
      @lffFile = "#{@lffFileBase}/#{lffFile}.#{@repFormat.to_s.downcase}"
      @taskErrOutFilesBase = "#{@lffFileBase}/#{lffFile}.taskWrapper"
      # Let's make sure everything we need exists and set to right params
      FileUtils.mkdir_p(@lffFileBase)
      FileUtils.chmod(02775, @lffFileBase)
      FileUtils.touch(@lffFile)
      FileUtils.chmod(0664, @lffFile)
      return
    end
  end # class DbAnnos
end ; end ; end # module BRL ; module REST ; module Resources
