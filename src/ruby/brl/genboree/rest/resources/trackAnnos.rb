#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/graphics/cytobandDrawer'
require 'brl/genboree/liveLFFDownload'
require 'brl/genboree/tabularDownloader'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/annotationEntity'
require 'brl/genboree/abstract/resources/bedFile'
require 'brl/genboree/abstract/resources/gffFile'
require 'brl/genboree/abstract/resources/wigFile'
require 'brl/genboree/abstract/resources/lffFile'
require 'brl/genboree/abstract/resources/gff3File'
require 'brl/genboree/abstract/resources/vcfFile'
require 'brl/genboree/abstract/resources/zoomLevelsFile'
require 'brl/genboree/abstract/resources/tabularLayout'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/tools/toolHelperClassLoader'
require 'brl/genboree/rest/data/workbenchJobEntity'
include BRL::Genboree::REST

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TrackAnnos - get the annos in a specified track
  #
  # Data representation classes used:
  # * _none_, gets and delivers raw LFF text directly.
  class TrackAnnos < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Tools::ToolHelperClassLoader
    # INTERFACE: Map of what http methods this resource supports
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }
    ENV_VARS_TO_FIX = ['RUBYLIB', 'DBRC_FILE', 'DB_ACCESS_FILE', 'GENB_CONFIG', 'LD_LIBRARY_PATH', 'PATH', 'SITE_JARS', 'PERL5LIB', 'PYTHONPATH', 'DOMAIN_ALIAS_FILE', 'R_LIBS_USER']
    MEDIAN_LIMIT = 10_000_000
    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos"

    RESOURCE_DISPLAY_NAME ="Track Annotations"
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
      @ftypeRow.clear() if(@ftypeRow)
      @ftypeRow = @refseqRow = @aspect = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
      # Track related data
      @ftypeHash = @trackName = @tracks = nil
      # Layout related data
      @layout = @layoutName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/annos$</tt>
    def self.pattern()
      #return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/annos$}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:(?:trk/([^/\?]+))|(?:trks))/annos$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 8          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      # Init the resource instance vars
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip unless(@uriMatchData[3].nil?)
      if(@trackName)
        if(@trackName !~ /:/)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "Track Name requires a ':'"
        elsif(@trackName.split(":")[0].nil? or @trackName.split(":")[0].empty?)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "Type cannot be empty in Track Name."
        elsif(@trackName.split(":")[1].nil? or @trackName.split(":")[1].empty?)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "Subtype cannot be empty in Track Name."
        elsif(@trackName =~ /\t/)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "Track Name cannot have a tab character."
        else
          # Track name appears to be fine
        end
      end
      if(initStatus == :OK)
        # Init and check group & database exist and are accessible
        initStatus = initGroupAndDatabase()
        @gbEnvSuffix = @genbConf.gbEnvSuffix
        # Handle layout name (not payload -- that happens later)
        if(@nvPairs['layoutName'].nil? or @nvPairs['layoutName'].empty?)
          @layoutName = nil
        else
          @layoutName = @nvPairs['layoutName']
          # Check for missing layout (bad name)
          if(initStatus == :OK)
            unless(BRL::Genboree::Abstract::Resources::TabularLayout.layoutNameExists(@dbu, @layoutName))
              initStatus = @statusName = :'Not Found'
              @statusMsg = "NO_LAYOUT: The specified layout #{@layoutName.inspect} does not exist in the database #{@dbName.inspect} in the group #{@groupName.inspect}"
            end
          end
        end
        # Column headers and landmark
        rColHeaders = @nvPairs['colHeaders']
        @colHeaders = if(rColHeaders and !rColHeaders.empty? and rColHeaders =~ /^(?:no|false)/i) then false else true end
        rLandmark = @nvPairs['landmark']
        # If multiple landmarks are provided, join them into a comma seperated string.
        @landmark = (rLandmark.is_a?(Array)) ? rLandmark.join(',') : rLandmark
        @landmark = (@landmark and !@landmark.empty?) ? @landmark.strip : nil
        @ftypeRow = nil

        # Handle tracks appropriately (handle both trks and trk/{name})
        @tracks = @layout = nil
        # Hash containing format specific options
        @formatOptions = {}
        # Comma seperated list of format specific boolean options
        if(!@nvPairs['formatOpts'].nil?)
          formatOpts = @nvPairs['formatOpts'].split(',')
          formatOpts.map { |opt| @formatOptions[opt] = true }
        end
        # Get span for wig output
        if(!@nvPairs['span'].nil?)
          if(@nvPairs['span'].to_i > 0)
            @formatOptions['desiredSpan'] = @nvPairs['span'].to_i
          else
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "span must be a positive integer"
          end
        end
        # Get span aggregation function for wig output
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
          @formatOptions['spanAggFunction'] = :avg
        end
        # Make sure the requested span is not larger than 20_000_000 if the aggregation function is median
        if((@formatOptions['spanAggFunction'] == :med) and !@formatOptions['desiredSpan'].nil? and @formatOptions['desiredSpan'] > MEDIAN_LIMIT)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "requested span cannot be more than #{MEDIAN_LIMIT} if the aggregating function is median (median is the default aggregation function)"
        end
        ucscTrackHeader = @nvPairs['ucscTrackHeader']
        if(ucscTrackHeader and !ucscTrackHeader.empty? and ucscTrackHeader =~ /^(?:yes|true)/i)
          @ucscTrackHeader = true
        elsif(ucscTrackHeader and !ucscTrackHeader.empty? and ucscTrackHeader =~ /^(?:false|no)/i)
          @ucscTrackHeader = false
        else
          if(@repFormat == :BED or @repFormat == :BEDGRAPH or @repFormat == :BED3COL or @repFormat == :GFF3 or @repFormat == :WIG or @repFormat == :VWIG or @repFormat == :FWIG)
            @ucscTrackHeader = true
          else
            @ucscTrackHeader = false
          end
        end
        if(initStatus == :OK)
          # First get our payload (if any) only for 'get'
          if(@reqMethod != :put)
            if(!@nvPairs.key?('hasROIInPayload')) # Skip if this parameter is present. The payload will be annotation data. No need of parsing.
              entity = parseRequestBodyAllFormats(['TabularLayoutEntity', 'TextEntityList'])
              initStatus = @statusName = :'Unsupported Media Type' if(entity == :'Unsupported Media Type')
            end
          end
          if(@uriMatchData[3].nil? and initStatus == :OK)
            # Using the "trks" form of the URL
            @tracks = []
            @trkHash = nil
            # Check for a payload, otherwise use "all" tracks
            if(entity.nil?)
              dbTracks = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu)
              trkHash = dbTracks
              dbTracks.each_key{|row|
                @tracks << row
              }
            elsif (entity.is_a?(BRL::Genboree::REST::Data::TextEntityList))
              dbTracks = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu)
              @trkHash = dbTracks
              entity.each{|textEntity|
                if(dbTracks.has_key?(textEntity.text))
                  @tracks << textEntity.text
                else
                  initStatus = @statusName = :'Not Found'
                  @statusMsg = "NO_TRK: The requested track #{textEntity.text.inspect} does not exist or you do not have permission to access it in database #{@dbName.inspect} in group #{@groupName.inspect}"
                  break
                end
              }
            else
              initStatus = @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_PAYLOAD: The payload provided must be a TextEntityList of track names"
            end
            # Check and parse various params
            initStatus = parseParameters(initStatus)
            # When in "trks" mode, ensure a layoutName was provided for format=layout
            if(@repFormat == :LAYOUT && @layoutName.nil?)
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "BAD_REQUEST: When using format=layout, you must specify a layout name in your request (layoutName={name})."
            end
          elsif(initStatus == :OK)
            # Using the "trk/{name}" form of the URL
            # @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip
            # Check for a missing or inaccessible track
            # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
            ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refSeqId, @userId, true, @dbu)
            @trkHash = ftypesHash
            if(@reqMethod != :put)
              if(ftypesHash.has_key?(@trackName))
                @ftypeHash = ftypesHash[@trackName]
                @tracks = [@trackName]
              else
                initStatus = @statusName = :'Not Found'
                @statusMsg = "NO_TRK: The requested track #{@trackName.inspect} does not exist or you do not have permission to access it in database #{@dbName.inspect} in group #{@groupName.inspect}"
              end
            else
              @tracks = @trackName
            end
            # Check and parse various params
            initStatus = parseParameters(initStatus)
            # Handle the layoutName / layout payload
            if(@repFormat == :LAYOUT)
              if(entity.is_a?(BRL::Genboree::REST::Data::TabularLayoutEntity) and @layoutName.nil?)
                @layout = entity
              elsif(entity.is_a?(BRL::Genboree::REST::Data::TabularLayoutEntity) and !@layoutName.nil?)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "BAD_REQUEST: You cannot specify a tabular layout by name and also provide a TabularLayoutEntity as a payload"
              elsif(!entity.is_a?(BRL::Genboree::REST::Data::TabularLayoutEntity) and @layoutName.nil?)
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "BAD_REQUEST: When using format=layout, you must specify a layout name, or else provide a TabularLayoutEntity as a payload."
              end
            end
          end
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
      initOperation()
      prepResponse() if(@statusName == :OK)
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
    #
    # @todo Why is this DUPLICATED from dbAnnos? Copy/paste reuse or similar stupidity?
    def put()
      initStatus = initPut()
      if(initStatus == :OK)
        # Prep lff file to save to and upload out file to use
        self.prepLFFFile()
        # Read through @req.body and save to file
        lffFileWriter = File.open(@lffFile, 'w+')
        byteCount = 0
        @req.body.rewind if(@req.body.respond_to?(:rewind))
        @req.body.each { |block| # more likely a line but who knows
          lffFileWriter.print(block)
          byteCount += block.size
        }
        lffFileWriter.close()
        # Make the dir for the bin file (required for wig uploads) if it does not exit
        system("mkdir -p /usr/local/brl/data/genboree/ridSequences/#{@refSeqId}")
        # Create an entry for RID_SEQUENCE_DIR in the fmeta table
        dbName = @dbu.selectDBNameByRefSeqID(@refSeqId)[0]['databaseName']
        @dbu.setNewDataDb(dbName)
        @dbu.updateFmetaEntry('RID_SEQUENCE_DIR', "/usr/local/brl/data/genboree/ridSequences/#{@refSeqId}")
        # Make uploader
        gc = BRL::Genboree::GenboreeConfig.load
        useCluster = gc.useClusterForAPI
        uploader = nil
        if(useCluster == 'true')
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
            #uploader.trackName = @trackNames.first if(@trackNames and @trackNames.is_a?(Array) and !@trackNames.empty?)
            uploader.trackName = CGI.escape(@trackName)
            uploader.windowingMethod = windowingMethod
            uploader.recordType = recordType
            uploader.useLog = useLog
            uploader.attributesPresent
          elsif(@repFormat == :LFF)
            uploader = BRL::Genboree::BckGrndLFFUploader.new(@userId, @refSeqId, @groupId, @lffFile, @taskErrOutFilesBase)
          else
            @initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: Formats other than wig and lff cannot be uploaded via the API if useCluster=false"
          end
        end
        if(@initStatus == :OK)
          if(useCluster == "true")
            $stderr.puts "#{self.class}##{__method__}: AFTER inserting job on cluster => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
            $stderr.puts "Job: #{@jobId} with id: #{@schedJobId} launched on cluster"
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

    # [+returns+] @resp
    def prepResponse()
      retVal = nil
      @resp.body = ''
      # Create Track abstraction instances. We need to ask questions.
      trackObjs = {}
      @tracks.each { |trackName|
        method, source = trackName.split(':')
        # ARJ: this next line was using "dbu" not "@dbu". But dbu not defined here...presumably it was picking up @dbu despite sloppy coding.
        trackObj = BRL::Genboree::Abstract::Resources::Track.new(@dbu, @refSeqId, method, source)
        trackObjs[trackName] = trackObj
      }
      # Are any track tagged as not-downloadable? (via gbNotDownloadable attribute being true|yes)
      status = checkTracksDownloadable(trackObjs.values)
      if(status == :OK)
        if(@apiError.nil? and @statusName == :OK)
          case @repFormat
          when :BED, :BED3COL, :BEDGRAPH, :GFF, :WIG, :VWIG, :FWIG, :LFF, :GTF, :GFF3, :ZOOMLEVELS, :VCF
            @resp.body = ''
            @resp.status = HTTP_STATUS_NAMES[:OK]
            @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@repFormat]

            ## The annotation data should always be in the last DbRec because if it's a user defined track,
            ## there will only be one DbRec and if it's a template track, the last DbRec will be the template
            # Only do this if getting annos for a single track, ftypeHash will be set
            @dbu.setNewDataDb(@ftypeHash['dbNames'].last.dbName) if(!@ftypeHash.nil?)
            #
            ## Instantiate the annotation File Object
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@repFormat: #{@repFormat.inspect}")
            annoFileObj = case @repFormat
              when :BED then BRL::Genboree::Abstract::Resources::BedFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :BED3COL then BRL::Genboree::Abstract::Resources::Bed3ColFile.new(@dbu, nil, @ucscTrackHeader)
              when :BEDGRAPH then BRL::Genboree::Abstract::Resources::BedGraphFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :GFF then BRL::Genboree::Abstract::Resources::GffFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :WIG then BRL::Genboree::Abstract::Resources::VWigFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions) # Defaults to variable step
              when :VWIG then BRL::Genboree::Abstract::Resources::VWigFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :FWIG then BRL::Genboree::Abstract::Resources::FWigFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :GFF3 then BRL::Genboree::Abstract::Resources::Gff3File.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :GTF then BRL::Genboree::Abstract::Resources::GtfFile.new(@dbu, nil, @ucscTrackHeader, @formatOptions)
              when :LFF then BRL::Genboree::Abstract::Resources::LffFile.new(@dbu, nil, false, @formatOptions)
              when :VCF then BRL::Genboree::Abstract::Resources::VcfFile.new(@dbu, nil, false, @formatOptions)
              when :ZOOMLEVELS then BRL::Genboree::Abstract::Resources::ZoomLevelsFile.new(@dbu, nil, false, @formatOptions)
            end
            annoFileObj.showColumnHeader = @formatOptions['addColHeader']
            # if trks/annos has been requested, pass the array of tracks
            if(@ftypeHash.nil?)
              annoFileObj.setTrackList(@tracks, @refSeqId, @landmark)
            else
              # else only one track has been requested and we already have the ftypeid, so use it
              annoFileObj.setFtypeId(@ftypeHash['dbNames'].last.ftypeid, @refSeqId, @landmark)
            end
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
              downloader = BRL::Genboree::TabularDownload.new(@userId, @refSeqId, @tracks, @layout, @landmark)
            else
              downloader = BRL::Genboree::TabularDownload.new(@userId, @refSeqId, @tracks, @layoutName, @landmark)
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
          when :CHR_BAND_PNG
            # To create a cytoband image of the annotations, we need a landmark specified
            if(@landmark and !@landmark.empty?)
              begin
                # Create a cytoband drawer
                drawer = BRL::Genboree::Graphics::CytobandDrawer.new(@dbu, @databaseName, @userId, @genbConf)
                drawOpts = Hash.new()
                drawOpts['height'] = @nvPairs['pxHeight']
                drawOpts['width'] = @nvPairs['pxWidth']
                drawOpts['orientation'] = @nvPairs['orientation']
                drawOpts['topMargin'] = @nvPairs['topMargin']
                drawOpts['rightMargin'] = @nvPairs['rightMargin']
                drawOpts['bottomMargin'] = @nvPairs['bottomMargin']
                drawOpts['leftMargin'] = @nvPairs['leftMargin']

                # Generate a cytoband image for the annotations in this track - Returned as a blog (string)
                #image = drawer.createCytobandImageForTrack(@landmark, @ftypeHash, drawOpts)
                image = drawer.createCytobandImageForTrack(@landmark, @ftypeHash, drawOpts)

                # Return the image
                @resp.status = HTTP_STATUS_NAMES[:OK]
                @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:CHR_BAND_PNG]
                @resp.body = image
                retVal = @resp
              rescue => error
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "An error occurred while trying to draw the cytoband image: #{error}\n#{error.backtrace.join(" \n")}")
                $stderr.puts "ERROR: An error occurred in BRL::Util::CytobandDrawer#createCytobandImage: #{error}\n#{error.backtrace.join(" \n")}"
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', 'A landmark is required to create a cytoband PNG image of the track annotations')
            end
          else
            @statusName, @statusMsg = :'Bad Request', 'The format specified is not supported.  Acceptable formats include: bed, bed3col, lff, gff, wig, vwig, fwig, layout, chr_band_png'
          end
        end
      end
      return retVal
    end

    # This method is used for building the color column of bed files,
    # It converts a color in RGB hex format to decimal RGB comma seperated format
    # example: #00FF00 -> 0,255,0
    # Then it stores the values in the hash @colorHash so that if the color is requested again, it is not computed again.
    #
    # [+hexValue+]  color in RGB Hexadecimal format
    # [+returns+]   color in comma seperated RGB decimal format
    def colorLookup(hexValue)
      # strip the leading '#' off if its there
      hexValue.gsub!(/#/, '')
      if(@colorHash[hexValue].nil?)
        decValue = hexValue.scan(/../).map{|dd|dd.hex}.join(',')
        @colorHash[hexValue] = decValue
      end
      return @colorHash[hexValue]
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

    # Sets up information for 'ROI' track in @formatOptions
    # [+initStatus+]
    # [+return+] initStatus
    def setROITrack(initStatus)
      initStatus = :OK
      tempHash = {}
      roiTrack = @nvPairs['ROITrack']
      @dbRecord = @dbApiUriHelperObj.tableRow(roiTrack)
      # If dbRecord is nil it is probably the track name or it could be on a different machine
      if(@dbRecord.nil?)
        # We first need to check if its a track name or a URI to an external track
        uri = URI.parse(roiTrack)
        if(uri.host.nil? and !@trkHash.has_key?(roiTrack)) # ERROR: ROI Track is just the name but not present in the database/not accessible to the user
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NO_TRK: There is no track: #{roiTrack.inspect} in database: #{@dbName.inspect} in user group: #{@groupName.inspect}"
        elsif(uri.host.nil? and @trkHash.has_key?(roiTrack)) # ROI Track is just the track name and is present in the database/accessible to the user
          @formatOptions['ROITrack'] = {roiTrack => @refSeqId}
          @formatOptions['INTERNAL'] = true
        elsif(!uri.host.nil?) # ROI Track is a URL to an external host
          initStatus = setTrkByHostAndUriInfo('EXTERNAL', roiTrack, 'ROITrack')
        else
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NO_TRK: There is no track: #{roiTrack.inspect} in database: #{@dbName.inspect} in user group: #{@groupName.inspect}"
        end
      # else 'roiTrack' is a URL ?
      else
        initStatus = setTrkByHostAndUriInfo('INTERNAL', roiTrack, 'ROITrack')
      end
      if(initStatus == :OK)
        # wig not allowed with ROI track
        if(NON_LIFTABLE_FORMATS.key?(@repFormat))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with 'ROITrack'"
        end
      end
      return initStatus
    end

    # Sets track info for 'ROI' or 'score' track using hostType and trk uri information
    # [+returns+] initStatus
    def setTrkByHostAndUriInfo(hostType, trkURI, trackType)
      initStatus = :OK
      # Get the uri for the main track
      dbPath = @dbApiUriHelperObj.extractPath(trkURI)
      trkGbKey = @dbApiUriHelperObj.extractGbKey(trkURI)
      trkGbKey = (trkGbKey.nil? ? "" : "gbKey=#{trkGbKey}")
      host = URI.parse(trkURI).host
      rsrcURIDbVer = @dbApiUriHelperObj.dbVersion(@rsrcURI)
      # To get the db version of the 'ROI Track', make an API call
      apiCaller = nil
      if(initStatus == :OK)
        apiCaller = ApiCaller.new(host, "#{dbPath}?#{trkGbKey}", @hostAuthMap)
        #$stderr.puts("trkURI: #{trkURI.inspect}")
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)
        trackDbVer = resp['data']['version']
        $stderr.puts("trkURI: #{trkURI.inspect}; @rsrcURI: #{@rsrcURI.inspect}; trackDbVer: #{trackDbVer}; rsrcURIDbVer: #{rsrcURIDbVer}")
        if(trackDbVer != rsrcURIDbVer)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "db versions for 'ROI' and 'score' tracks not same"
        end
        if(initStatus == :OK)
          # Make an API call to see if the track is part of the db and if the user has permission
          apiCaller.setRsrcPath("#{dbPath}/trks?#{trkGbKey}")
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          resp = JSON.parse(apiCaller.respBody)
          retVal = resp['data']
          trkPresent = false
          trkName = @trackApiUriHelperObj.extractName(trkURI)
          retVal.each { |trk|
            if(trk['text'] == trkName)
              trkPresent = true
              break
            end
          }
          unless(trkPresent)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "NO_TRK: The track: #{trkName.inspect} does not exist in db: #{@dbApiUriHelperObj.extractName(trkURI).inspect}. (or user does not have permission?)"
          else
            if(hostType == 'INTERNAL')
              @formatOptions[trackType] = {trkName => @dbRecord['refSeqId'].to_i}
              @formatOptions['INTERNAL'] = true
            else
              trkPath = URI.parse(trkURI).path
              apiCaller = ApiCaller.new(host, "", @hostAuthMap)
              @formatOptions[trackType] = {trkName => nil}
              @formatOptions['extTrackApiObj'] = {trkName => apiCaller} # For external cases, we will use this apiCaller object in 'annotationFile.rb'
              @formatOptions['INTERNAL'] = false
              @formatOptions['extTrackURI'] = trkURI
              @formatOptions['repFormat'] = @repFormat
              @formatOptions['selfUri'] = "http://#{@rsrcHost}/#{@rsrcPath}"
              @formatOptions['extTrkGbKey'] = trkGbKey
            end
          end
        end
      end
      return initStatus
    end

    # Sets up information for 'score' track in @formatOptions
    # [+initStatus+]
    # [+return+] initStatus
    def setScoreTrack(initStatus)
      tempHash = {}
      scoreTrack = @nvPairs['scoreTrack']
      @dbRecord = @dbApiUriHelperObj.tableRow(scoreTrack)
      # If dbRecord is nil it is probably the track name or it could be on a different machine
      if(@dbRecord.nil?)
        # We first need to check if its a track name or a URI to an external track
        uri = URI.parse(scoreTrack)
        if(uri.host.nil? and !@trkHash.has_key?(scoreTrack)) # ERROR: Score Track is just the name but not present in the database/not accessible to the user
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NO_TRK: There is no track: #{scoreTrack.inspect} in database: #{@dbName.inspect} in user group: #{@groupName.inspect}"
        elsif(uri.host.nil? and @trkHash.has_key?(scoreTrack)) # Score Track is just the track name and is present in the database/accessible to the user
          @formatOptions['scoreTrack'] = {scoreTrack => @refSeqId}
          @formatOptions['INTERNAL'] = true
        elsif(!uri.host.nil?) # Score Track is a URL to an external host
          initStatus = setTrkByHostAndUriInfo('EXTERNAL', scoreTrack, 'scoreTrack')
        else
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NO_TRK: There is no track: #{scoreTrack.inspect} in database: #{@dbName.inspect} in user group: #{@groupName.inspect}"
        end
      # else 'scoreTrack' is a URL ?
      else
        initStatus = setTrkByHostAndUriInfo('INTERNAL', scoreTrack, 'scoreTrack')
      end
      if(initStatus == :OK)
        # wig not allowed with ROI track
        if(NON_LIFTABLE_FORMATS.key?(@repFormat))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "#{@repFormat}.to_s.downcase format not allowed with 'scoreTrack'"
        end
      end
      return initStatus
    end

    # Parses all user provided args and options for downloading annotations
    # [+initStatus+]
    # [+return+] initStatus
    def parseParameters(initStatus)
      # Check and parse 'ROI track'
      @dbApiUriHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      @trackApiUriHelperObj = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
      if(!@nvPairs['ROITrack'].nil? and !@nvPairs['ROITrack'].empty?)
        initStatus = setROITrack(initStatus)
        # Landmark cannnot be provided with ROI track
        if(initStatus == :OK)
          if(@landmark)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "landmark cannot be provided with ROITrack"
          end
        end
      end

      # Check and parse 'scoreTrack'
      if(initStatus == :OK)
        if(!@nvPairs['scoreTrack'].nil? and !@nvPairs['scoreTrack'].empty?)
          # Generate error if 'ROITrack' also provided
          if(@formatOptions['ROITrack'])
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "Both 'ROITrack' and 'scoreTrack' cannot be provided"
          end
          initStatus = setScoreTrack(initStatus)
          # Landmark cannnot be provided with score track
          if(initStatus == :OK)
            if(@landmark)
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "landmark cannot be provided with scoreTrack"
            end
          end
        end
      end

      # Check and parse 'nameFilter'
      if(initStatus == :OK)
        if(!@nvPairs['nameFilter'].nil? and !@nvPairs['nameFilter'].empty?)
          @formatOptions['nameFilter'] = @nvPairs['nameFilter']
          # Landmark cannot be provided with 'nameFilter'
          if(@landmark)
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "'landmark' cannot be provided with 'nameFilter'"
          end
        end
      end

      if(initStatus == :OK)
        # Check and parse 'emptyScoreValue'
        @formatOptions['emptyScoreValue'] = @nvPairs['emptyScoreValue'] if(!@nvPairs['emptyScoreValue'].nil? and !@nvPairs['emptyScoreValue'].empty?)
      end

      # Check and parse 'scoreFile'
      if(initStatus == :OK)
        if(!@nvPairs['scoreFile'].nil? and !@nvPairs['scoreFile'].empty?)
          fullPath = @nvPairs['scoreFile']
          scoreFilePath = @genbConf.gbDataFileRoot.to_s + fullPath.slice(fullPath.index('/grp/')..-1).gsub("/file", "")
          if(!File.exists?(scoreFilePath))
            initStatus = @statusName = :'Bad Request'
            @statusMsg = "BAD_REQUEST: scoreFile: #{@nvPairs['scoreFile']} does not exist"
          end
          if(initStatus == :OK)
            @formatOptions['scoreFile'] = scoreFilePath
            if(NON_LIFTABLE_FORMATS.key?(@repFormat))
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with scoreFile"
            end
            # Both 'scoreTrack' and 'scoreFile' cannot be provided
            if(initStatus == :OK)
              if(@formatOptions['scoreFile'] and @formatOptions['scoreTrack'])
                initStatus = @statusName = :'Bad Request'
                @statusMsg = "BAD_REQUEST: 'scoreFile' and 'scoreTrack' cannot be provided together"
              end
            end
          end
        end
      end

      # Check and parse 'extendAnnos' and 'truncateAnnos'
      # Add extendValue and truncateValue if not provided (default: 200)
      if(initStatus == :OK)
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
        if(initStatus == :OK)
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
          if(initStatus == :OK)
            if((@extendAnnos or @truncateAnnos) and (NON_LIFTABLE_FORMATS.key?(@repFormat)))
              initStatus = @statusName = :'Bad Request'
              @statusMsg = "#{@repFormat.to_s.downcase} format not allowed with extendAnnos or truncateAnnos"
            end
          end
        end
      end

      # Check for the zoomLevels flag, if 'zoomLevelsRes' not provided use 100k res (NOT TESTED)
      if(initStatus == :OK)
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
      end

      # Check for 'modulusLastSpan': used for calculating the precise span for the last record of a wig file for bigwig generation
      # 'true' by default
      if(initStatus == :OK)
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
      end

      if(initStatus == :OK)
        # Check for 'collapsedCoverage':
        collapsedCoverage = @nvPairs['collapsedCoverage']
        @collapsedCoverage = if(collapsedCoverage and !collapsedCoverage.empty? and collapsedCoverage =~ /^(?:yes|true)/i) then 'true' else false end
        @formatOptions['collapsedCoverage'] = @collapsedCoverage
        # Span must be provided with collapsedCoverage option
        if(@collapsedCoverage and !@formatOptions['desiredSpan'])
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: 'span' parameter required with collapsedCoverage option"
        end
      end

      # Check if the adler 32 check sum needs to be added at the end of the downloaded file
      addCRC32Line = @nvPairs['addCRC32Line']
      @addCRC32Line = if(addCRC32Line and !addCRC32Line.empty? and addCRC32Line =~ /^(?:yes|true)/i) then 'true' else false end
      @formatOptions['addCRC32Line'] = @addCRC32Line

      proxyDownload = @nvPairs['proxyDownload']
      @formatOptions['proxyDownload'] = true if(proxyDownload and !proxyDownload.empty? and proxyDownload =~ /^(?:yes|true)/i)

      ucscScaling = @nvPairs['ucscScaling'] # will be turned on by default for 'bed'. Can be turned on for 'gtf', 'gff' and 'gff3'
      if(@repFormat == :BED)
        @scaleScores = if(ucscScaling and !ucscScaling.empty? and ucscScaling =~ /^(?:no|false)/i) then 0 else 1 end
        @formatOptions['scaleScores'] = @scaleScores
      else
        @scaleScores = if(ucscScaling and !ucscScaling.empty? and ucscScaling =~ /^(?:true|yes)/i) then 1 else 0 end
        @formatOptions['scaleScores'] = @scaleScores
      end
      hasROIInPayload = @nvPairs['hasROIInPayload']
      @formatOptions['hasROIInPayload'] = if(hasROIInPayload and !hasROIInPayload.empty? and hasROIInPayload =~ /^(?:yes|true)/i) then true else false end
      if(@formatOptions['hasROIInPayload'])
        if(@req.body)
          @req.body.rewind()
          @formatOptions['roiData'] = @req.body.read
        end
        @formatOptions['payloadROIRID'] = @nvPairs['payloadROIRID']
        @formatOptions['ROITrack'] = nil
        @formatOptions['INTERNAL'] = false
        @formatOptions['repFormat'] = @nvPairs['format'] == 'bedgraph' ? "bedGraph" : @nvPairs['format']
        if(@formatOptions['roiData'].nil? or @formatOptions['roiData'].empty?)
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: payload required with 'hasROIInPayload'"
        end
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

  end # class TrackAnnos
end ; end ; end # module BRL ; module REST ; module Resources
