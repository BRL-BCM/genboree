require 'time' # add Time.parse
require 'brl/util/util'
require 'brl/genboree/gbHighChart'
require 'brl/genboree/kb/mongoKbDatabase'

module BRL; module Genboree; module KB; module Stats
  # @note the source here is large but is divided into some hopefully helpful sections
  #   that are delimited by comment lines like "# ---------"
  #   PUBLIC METHODS
  #   INTERFACES
  #   OPTIONS
  #   ENTITY METHODS
  #   PROTECTED METHODS (read as "other" protected methods since there are other non public ones)
  # @todo check methods for nil cases, other corner cases, errors (esp. mongo errors)
  class AbstractStats
    # aggregation pipeline constants
    DOC_IDS_KEY = "docIds"
    GROUP_KEY = "_id"
    GROUP_MEMBER_KEY = "groupDocs"
    CHILD_KEY = "value"

    # entity constants
    ENTITIES = [:docs, :versions, :creates, :edits, :deletes]
    TIMESTAMP_NAME = "timestamp"
    TIMESTAMP_PATH = "versionNum.properties.#{TIMESTAMP_NAME}.value" 
    DELETE_NAME = "deletion"
    DELETE_PATH = "versionNum.properties.#{DELETE_NAME}.value"
    PREV_VERSION_NAME = "prevVersion"
    PREV_VERSION_PATH = "versionNum.properties.#{PREV_VERSION_NAME}.value"

    # constants for "mapMonths" methods
    MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    ##################
    # time constants #
    ##################
    # http://docs.mongodb.org/manual/reference/operator/aggregation-date/
    # same order as Ruby Time#mktime with < 10 arguments
    # also assumed to be in decreasing order by @see labelTime
    TIME_UNITS = [:year, :month, :day, :hour, :minute] 
    # associations between ruby and mongo units
    GB_TO_MONGO_UNITS = {
      :year => :year,
      :month => :month,
      :day => :dayOfMonth,
      :hour => :hour,
      :minute => :minute
    }
    MONGO_TO_GB_UNITS = GB_TO_MONGO_UNITS.inject({}){|hh, avp| hh[avp[1]] = avp[0]; hh }
    # for use with time , ruby e.g. ruby Time.utc(*args)
    RESOLUTION_TO_RUBY = {
      :second => 0,
      :minute => 1,
      :hour => 2,
      :day => 3,
      :month => 4,
      :year => 5,
      :wday => 6,
      :yday => 7,
      :isdst => 8,
      :zone => 9
    }
    RUBY_TO_RESOLUTION = RESOLUTION_TO_RUBY.inject({}){|hh, avp| hh[avp[1]] = avp[0]; hh}
    MAX_RESOLUTION_IDX = 5
    # there is no 0th month and we dont support finer units than seconds (e.g. milliseconds)
    RESOLUTION_TO_FIRST = {
      :second => 1,
      :minute => 0,
      :hour => 0,
      :day => 1,
      :month => 1
    }
    # used for label heuristics - intended as last value before ambiguity:
    #   assuming unique times, if you have 61 minute values, at least 2 of them will specify 
    #   the same minute and you cannot tell which minute belongs to the original unique 
    #   time unless you consider a more coarse resolution: hours
    RESOLUTION_TO_LAST = {
      :minute => 60,
      :hour => 24,
      :day => 28,
      :month => 12,
      :year => +1.0/0.0
    }

    attr_reader :mdb # BRL::Genboree::KB::MongoKbDatabase
    attr_reader :dch # BRL::Genboree::KB::Helpers::DataCollectionHelper
    attr_reader :vh # BRL::Genboree::KB::Helpers::VersionsHelper
    attr_reader :warnings
    # @return [Array<Exception>] errors collects multiple errors where appropriate
    # @note public interfaces will raise an error rather than relying on the user to
    #   check this attr_reader
    attr_reader :errors 
    attr_accessor :debug # @todo add more debug flags?

    # @param [BRL::Genboree::KB::MongoKbDatabase] BRL object with kb to get stats about
    def initialize(mdb)
      @mdb = mdb # @todo check is mdb functional?
      @dch = nil
      @vh = nil
      @warnings = []
      @errors = []
    end

    # --------------------------------------------------
    # PUBLIC METHODS
    # --------------------------------------------------

    POINT_STATS = [ :docCount, :versionCount, :createCount, :editCount, :deleteCount, :byteSize, 
                    :avgByteSize, :lastEditTime, :lastEditAuthor ]
    STAT_DESCRIPTIONS = {
      :docCount => "The number of documents in a collection or KB",
      :docCountOverTime => "The net number of documents created - deleted in a given time period ",
      :versionCount => "The number of changes made to documents in a collection or KB: versions = creates + edits + deletes",
      :versionCountOverTime => "The version count partitioned into time range bins",
      :createCount => "The number of unique documents in a collection or KB",
      :createCountOverTime => "The createCount partitioned into time range bins",
      :editCount => "The number of times created documents in a collection or KB that have since been edited, but not deleted",
      :editCountOverTime => "The editCount partitioned into time range bins",
      :deleteCount => "The number of created documents in a collection or KB that have since been deleted (but possibly restored again)",
      :deleteCountOverTime => "The deleteCount partitioned into time range bins",
      :byteSize => "The number of bytes used by a kb or a collection",
      :avgByteSize => "The average number of bytes used across all documents in a kb or across all documents in a collection",
      :lastEditTime => "The time the last edit was made to a kb or one of its collection",
      :lastEditAuthor => "The author of the last edit to the kb or one of its collections",
      :allPointStats => "All of the following statistics as a property-oriented document: #{POINT_STATS.map{|xx| xx.to_s}.join(", ")}.",
      :lastNEditedDocs => "The last N edited documents in a collection. Response will include doc identfier, version number and timestamp."
    }
    OPTION_DESCRIPTIONS = {
      :resolution => "For over-time statistics, a frequency for calculating the statistic: one of \"minute\", \"hour\", \"day\", \"month\", or \"year\", defaults to \"month\"",
      :startTime => "A discernable time, preferably an RFC822 timestamp, but possibly \"2015\", \"2015JAN01\", \"2015/01/01\", etc., defaults to KB inception time",
      :endTime => "A discernable time, preferably an RFC822 timestamp, but possibly \"2015\", \"2015JAN01\", \"2015/01/01\", etc., defaults to the request time",
      :format => "One of \"json\", \"hcLine\", \"hcColumn\", or \"hcPie\". If an \"hc\" format, represent data as a http://www.highcharts.com chart object; if \"json\", return the statistic data as raw JSON; defaults to \"json\"",
      :cumulative => "If \"true\", compute statistic cumulatively across all times in the time range; defaults to \"true\"",
      :fill => "If \"true\", fill time range specified by startTime -- endTime with a time unit finer than the specified resolution; defaults to \"true\"",
      :closed => "If \"true\", the time range specified by startTime -- endTime is intended as a closed interval; if \"false\", a right-half-open interval; defaults to \"false\"",

      # expose a subset of underlying highchart options through this API as well 
      # @see BRL::Genboree::GenericHighchart
      :scale => "One of \"log\", \"linear\", or \"auto\" to set a highcharts y-axis type. Defaults to \"auto\" where some heuristics will be used to determine a chart format including the distance between data points, whether they are non-negative, etc."
    }

    def docCount(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Documents",
        :yAxis => "# Docs",
        :units => "Documents",
        :seriesNames => ["Documents"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:docCount, opts)
    end

    def docCountOverTime(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Net Doc Creations Over Time",
        :yAxis => "# Creations",
        :units => "Documents",
        :seriesNames => ["Documents"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapperOverTime(:docCountOverTime, opts)
    end
    
    def lastNEditedDocs(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Documents",
        :yAxis => "# Docs",
        :units => "Documents",
        :seriesNames => ["Documents"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:lastNEditedDocs, opts)
    end

    # @todo rename versions to actions for public interfaces?
    def versionCount(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Amount of Activity",
        :yAxis => "# Actions",
        :units => "Actions",
        :seriesNames => ["Actions"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:versionCount, opts)
    end

    def versionCountOverTime(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Activity Over Time",
        :yAxis => "# Actions",
        :units => "Actions",
        :seriesNames => ["Actions"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapperOverTime(:versionCountOverTime, opts)
    end

    def createCount(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Creations",
        :yAxis => "# Creations",
        :units => "Creations",
        :seriesNames => ["Creations"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:createCount, opts)
    end

    def createCountOverTime(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Doc Creations Over Time",
        :yAxis => "# Creations",
        :units => "Creations",
        :seriesNames => ["Creations"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapperOverTime(:createCountOverTime, opts)
    end

    def editCount(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Edits",
        :yAxis => "# Edits",
        :units => "Edits",
        :seriesNames => ["Edits"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:editCount, opts)
    end

    def editCountOverTime(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Doc Edits Over Time",
        :yAxis => "# Edits",
        :units => "Edits",
        :seriesNames => ["Edits"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapperOverTime(:editCountOverTime, opts)
    end

    def deleteCount(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Deletions",
        :yAxis => "# Deletions",
        :units => "Deletions",
        :seriesNames => ["Deletions"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:deleteCount, opts)
    end

    def deleteCountOverTime(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Doc Deletions Over Time",
        :yAxis => "# Deletions",
        :units => "Deletions",
        :seriesNames => ["Deletions"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapperOverTime(:deleteCountOverTime, opts)
    end

    def byteSize(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Number of Bytes Used",
        :yAxis => "# Bytes",
        :units => "Bytes",
        :seriesNames => ["Bytes"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:byteSize, opts)
    end

    def avgByteSize(opts={})
      @warnings = []
      @errors = []
      defaultOpts = { 
        :title => "Average Number of Bytes Used",
        :yAxis => "# Bytes",
        :units => "Bytes",
        :seriesNames => ["Bytes"]
      }
      opts = defaultOpts.merge(opts)
      return statWrapper(:avgByteSize, opts)
    end

    def lastEditTime(opts={})
      @warnings = []
      @errors = []
      return statWrapper(:lastEditTime, opts)
    end

    def lastEditAuthor(opts={})
      @warnings = []
      @errors = []
      return statWrapper(:lastEditAuthor, opts)
    end

    def allPointStats(opts={})
      @warnings = []
      @errors = []
      retVal = {}
      opts = parseAllPointStatsOpts(opts) # sets @errors, @warnings
      raiseAnyErrors()
      POINT_STATS.each { |stat|
        retVal[stat] = self.send(stat, opts)
      }
      return retVal
    end

    # @see OPTION_DESCRIPTIONS and the OPTIONS section of this file
    def options(stat)
      retVal = {}
      if([:docCount, :versionCount, :createCount, :editCount, :deleteCount].include?(stat))
        retVal = parseCoreOpts()
      elsif([:docCountOverTime, :versionCountOverTime, :createCountOverTime, :editCountOverTime, :deleteCountOverTime].include?(stat))
        retVal = parseCoreOptsOverTime()
      elsif([:byteSize, :avgByteSize].include?(stat))
        retVal = parseSizeOpts()
      elsif([:lastEditTime, :lastEditAuthor].include?(stat))
        retVal = parseLastEditOpts()
      end
      retVal.each_key { |opt|
        retVal[opt] = OPTION_DESCRIPTIONS[opt]
      }
      return retVal
    end

    # --------------------------------------------------
    # INTERFACES
    # --------------------------------------------------

    # INTERFACE
    def statWrapper(*args)
      raise NotImplementedError.new()
    end

    # INTERFACE
    def statWrapperOverTime(*args)
      raise NotImplementedError.new()
    end

    # --------------------------------------------------
    # OPTIONS
    # --------------------------------------------------

    # Sets default and supported option values for "core" stats: docCount, versionCount, createCount, 
    #   editCount, deleteCount
    # @see parseOpts
    def parseCoreOpts(opts={})
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    # Sets default and supported option values for "core" stats over time: docCountOverTime, 
    #   versionCountOverTime, createCountOverTime, editCountOverTime, deleteCountOverTime
    # @see parseOpts
    def parseCoreOptsOverTime(opts={})
      opt2DefaultVal = {
        :format => :json,
        :resolution => :month,
        :startTime => Time.gbMktime(*timeOfKbFirstEdit.to_a),
        :endTime => Time.gbMktime(*Time.now.to_a), # get rid of fractional seconds
        :cumulative => true,
        :fill => true,
        :closed => false,
        # chart options whose names match attr_accessors of BRL::Genboree::GenericHighchart:
        :scale => "auto",
        :yMin => 0, # @todo not accessible via API -- add to OPTION_DESCRIPTION and cast
        :allowDecimals => false # @todo not accessible via API -- add to OPTION_DESCRIPTION and cast
      }
      opt2SupportedVals = {
        :format => [:json, :hcLine, :hcColumn],
        :resolution => TIME_UNITS,
        :scale => ["log", "linear", "auto"]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    def parseSizeOpts(opts)
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    def parseLastEditOpts(opts={})
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    def parseAllPointStatsOpts(opts={})
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    # Return casted option values using default values where they are missing and reporting if
    #   an option is either not recognized at all in @warnings or doesn't have a supported value
    #   in @errors
    # @param [Hash] opts options to cast and validate
    # @param [Hash] opt2DefaultVal default values for options depending on the statistic
    # @param [Hash] opt2SupportedVals specific values required for options where they exist
    #   as in an enumeration such as :format
    # @return [Hash] option to value
    def parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
      origOpts = opts
      opts = castOptions(origOpts) # sets @errors with casting errors
      opts = opt2DefaultVal.merge(opts)
      extraOpts = opts.keys - opt2DefaultVal.keys
      @warnings << "Unsupported options: #{extraOpts.join(", ")}\n" unless(extraOpts.empty?)

      # sets @errors with enumeration errors
      opt2SupportedVals.each_key { |opt|
        vals = opt2SupportedVals[opt]
        unless(vals.index(opts[opt]))
          begin
            raise StatsError.new("Unsupported option #{opt}=\"#{opts[opt]}\"")
          rescue => err
            @errors << err
          end
        end
      }
      return opts
    end

    # @param [Hash] opts @see OPTION_DESCRIPTIONS
    # @raise errors if you give unexpected non-string objects as option values
    def castOptions(opts)
      retVal = {}
      opts.each_key { |kk|
        begin
          if kk == :resolution
            retVal[kk] = opts[kk].is_a?(Symbol) ? opts[kk] : opts[kk].to_sym
          elsif kk == :startTime
            retVal[kk] = opts[kk].is_a?(Time) ? opts[kk] : Time.parse(opts[kk])
          elsif kk == :endTime
            retVal[kk] = opts[kk].is_a?(Time) ? opts[kk] : Time.parse(opts[kk])
          elsif kk == :format
            retVal[kk] = opts[kk].is_a?(Symbol) ? opts[kk] : opts[kk].to_sym
            retVal[kk] = retVal[kk] == :json_pretty ? :json : retVal[kk]
          elsif kk == :cumulative
            retVal[kk] = !!opts[kk] == opts[kk] ? opts[kk] : opts[kk].to_bool
          elsif kk == :fill
            retVal[kk] = !!opts[kk] == opts[kk] ? opts[kk] : opts[kk].to_bool
          elsif kk == :closed
            retVal[kk] = !!opts[kk] == opts[kk] ? opts[kk] : opts[kk].to_bool
          elsif kk == :scale
            retVal[kk] = opts[kk].to_s
          else
            # pass through other options
            retVal[kk] = opts[kk]
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "WARNING", "Could not parse option #{kk}: #{err.message}: #{err.backtrace.join("\n")}")
          @errors << StatsError.new("Unsupported option #{kk}=#{opts[kk]}")
        end
      }
      return retVal
    end

    # --------------------------------------------------
    # ENTITY METHODS
    # Applies to Docs, Versions, Creates, Edits, Deletes
    # --------------------------------------------------

    # @see e.g. numDocsInColl
    def numEntityInColl(entity, coll=nil)
      raise ArgumentError.new("Unsupported entity #{entity.inspect}") unless(ENTITIES.include?(entity))
      self.send("num#{entity.to_s.capitalize}InColl", coll)
    end

    # @todo implement creates, edits, deletes?
    def numCollEntityInRange(entity, timeRange, coll=nil)
      raise ArgumentError.new("Unsupported entity #{entity.inspect}") unless(ENTITIES.include?(entity))
      self.send("numColl#{entity.to_s.capitalize}InRange", timeRange, coll)
    end

    # @todo implement creates, edits, deletes?
    def mapCollEntityInRange(entity, timeRange, opts={})
      raise ArgumentError.new("Unsupported entity #{entity.inspect}") unless(ENTITIES.include?(entity))
      self.send("mapColl#{entity.to_s.capitalize}InRange", timeRange, opts)
    end

    # Represent time ranges as RFC822 strings where time ranges appear as keys 
    #   in a hash or nested hash of depth 1
    # @todo better way to change key names?
    def rekeyTimeRanges(data)
      if(data.respond_to?(:each_key))
        if(data.first[0].is_a?(Range) rescue nil)
          data2 = {}
          data.each_key { |timeRange|
            kk = timeRange.first.rfc822
            data2[kk] = data[timeRange]
          }
          data = data2
        elsif(data.first[1].first[0].is_a?(Range) rescue nil)
          data.each_key { |coll|
            collData = {}
            data[coll].each_key { |timeRange|
              kk = timeRange.first.rfc822
              collData[kk] = data[coll][timeRange]
            }
            data[coll] = collData
          }
        end
      end
      return data
    end

    ######################
    # DOC ENTITY METHODS #
    ######################

    # Count the number of documents in a collection
    # @param [NilClass, String, BRL::Genboree::KB::Helpers::DataCollectionHelper] coll
    #   nil -> use previous collection ; String -> use collection with name coll ;
    #   dataCollectionHelper -> set @dch and use this collection
    # @return [Integer] the number of documents in the collection
    def numDocsInColl(coll=nil)
      setDch(coll)
      @dch.coll.size
    end

    # @todo rename "ByRes"
    def numCollDocsInRangeByRes(timeRange, coll=nil)
      setVh(coll)
      count = numCollCreatesInRange(timeRange, coll) - numCollDeletesInRange(timeRange, coll)
    end
    alias :numCollDocsInRange :numCollDocsInRangeByRes
    
    def lastNEditedDocsInColl(coll=nil, ndocs=3)
      setDch(coll)
      setVh(coll)
      gbIdName = @dch.getIdentifierName()
      gbIdPath = "versionNum.properties.content.value.#{gbIdName}.value"
      docRefName = "docRef"
      docRefPath = "versionNum.properties.#{docRefName}.value"

      # define aggregation pipeline
      pipeline = []    
      matchConfig = { "versionNum.properties.deletion.value" => false }
      match = { "$match" => matchConfig }
      pipeline << match

      group = { 
        "$group" => { 
          GROUP_KEY => {
            docRefName => "$#{docRefPath}"
          },
          "docId" => {
            "$first" => "$#{gbIdPath}"
          },
          "version" => {
            "$max" => "$versionNum.value"
          },
          "timestamp" => {
            "$max" => "$versionNum.properties.timestamp.value"
          }
        }
      }
      pipeline << group
      sort = {
        "$sort" => {"version" => -1 }
      }
      pipeline << sort
      limit = {
        "$limit" => ndocs
      }
      pipeline << limit
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Making aggregate request on #{@vh.coll.name.inspect} defined by pipeline:\n#{JSON.pretty_generate(pipeline)}") 
      resp = @vh.coll.aggregate(pipeline)
      return resp
    end

    # Count the number of data documents affected by edits for a time range
    # @see numCollVersionsInRange
    def numCollDocsInRangeByAgg(timeRange=nil, coll=nil)
      retVal = nil
      setDch(coll)
      setVh(coll)
      gbIdName = @dch.getIdentifierName()
      gbIdPath = "versionNum.properties.content.value.#{gbIdName}.value"
      docRefName = "docRef"
      docRefPath = "versionNum.properties.#{docRefName}.value"
      groupMemberKey = "push"

      # define aggregation pipeline
      pipeline = []    
      matchConfig = { "versionNum.properties.deletion.value" => false }
      if(timeRange)
        matchConfig.merge!(timeRangeToQuery(timeRange))
      end
      match = { "$match" => matchConfig }
      pipeline << match

      projection = {
        "$project" => {
          docRefPath => 1
        }
      }
      pipeline << projection

      group = { 
        "$group" => { 
          GROUP_KEY => {
            docRefName => "$#{docRefPath}"
          }
        }
      }
      pipeline << group

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Making aggregate request on #{@vh.coll.name.inspect} defined by pipeline:\n#{JSON.pretty_generate(pipeline)}") if(@debug)
      resp = @vh.coll.aggregate(pipeline)
      nUniqueDocs = resp.size # number of groups
      # @todo this doesnt scale, make another aggregation pipeline request ?
      # @todo do sort by time and check if deletion is true?
      nDeletedDocs = resp.inject(0) { |sum, aggDoc| sum += @mdb.db.dereference(aggDoc['_id']['docRef']).nil? ? 1 : 0 }
      retVal = nUniqueDocs - nDeletedDocs
      return retVal
    end

    # @note the definition of documents here is different than in mapCollDocsInRangeByAgg
    def mapCollDocsInRangeByRes(timeRange, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      setVh(opts[:coll])
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key { |range| retVal[range] = numCollDocsInRange(range, opts[:coll]) }
      return retVal
    end
    alias :mapCollDocsInRange :mapCollDocsInRangeByRes

    # @see mapCollVersionsInRangeByAgg
    def mapCollDocsInRangeByAgg(timeRange, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0

      pipelineOut = aggregateVersionsInRange(timeRange, opts[:coll])
      rangeToDocIds = Hash.new { |hh, kk| hh[kk] = Set.new() }
      pipelineOut.each { |projectDoc|
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(projectDoc[TIMESTAMP_NAME]) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        # difference vs @see mapCollVersionsInRangeByAgg - count unique documents
        rangeToDocIds[timeRange].add(projectDoc[@dch.getIdentifierName])
      }
      if(opts[:cumulative])
        # then we ensure uniqueness of the documents being counted with a cumulative set

        cumulativeSet = Set.new()
        timeRangeOrder.each_index { |ii|
          timeRange = timeRangeOrder[ii]
          cumulativeSet = cumulativeSet.union(rangeToDocIds[timeRange])
          retVal[timeRange] = cumulativeSet.size
        }
      else
        rangeToDocIds.each_key { |range| retVal[range] = rangeToDocIds[range].size }
      end
      return retVal
    end

    ##########################
    # VERSION ENTITY METHODS #
    ##########################

    # Count the number of document versions for a collection
    # @param [Object] coll @see numDocsInColl
    # @return [Integer] the number of versions for documents in the collection
    def numVersionsInColl(coll=nil)
      setVh(coll)
      @vh.coll.size
    end

    # Count the number of edits made in a collection for a time range
    # @see numVersionsInColl
    def numCollVersionsInRange(timeRange, coll=nil)
      setVh(coll)
      query = timeRangeToQuery(timeRange)
      count = @vh.coll.count( { :query => query } )
    end

    # @param [Range<Time>] timeRange @see enumerateTimeRange for notes on time ranges
    # @note MUCH faster than mapCollVersionsInRangeByAgg due to indexes on TIMESTAMP_PATH
    # @see numCollVersionsInRange
    # @see mapCollVersionsInRangeByAgg (alternative implementation)
    # @todo change interface to opts
    def mapCollVersionsInRangeByRes(timeRange, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key { |range| retVal[range] = numCollVersionsInRange(range, opts[:coll]) }
      return retVal
    end
    alias :mapCollVersionsInRange :mapCollVersionsInRangeByRes # this is the preferred method, not ByRes

    # @param [Range<Time>] timeRange @see enumerateTimeRange for notes on time ranges
    # @param [Symbol] resolution
    # @param [Object] coll
    # @see numCollVersionsInRangeByRes (alternative implementation)
    def mapCollVersionsInRangeByAgg(timeRange, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0
      # take advantage of sorted time range and sorted aggregation
      pipelineOut = aggregateVersionsInRange(timeRange, opts[:coll])
      pipelineOut.each_index { |ii|
        projectDoc = pipelineOut[ii]
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(projectDoc[TIMESTAMP_NAME]) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        retVal[timeRange] += 1
      }
      if(opts[:cumulative])
        # with versions we are not worried about uniqueness problems like we are with docs
        retVal = dateMapToCumulativeMap(retVal)
      end
      return retVal
    end

    #########################
    # CREATE ENTITY METHODS #
    #########################

    # Count the number of created documents in a collection
    # @param [Object] coll @see numDocsInColl
    # @return [Integer] the number of newly created documents in a collection
    # @note "restored" documents (those created -> deleted -> created) are not considered 
    #   "created"
    def numCreatesInColl(coll=nil)
      setVh(coll)
      query = { PREV_VERSION_PATH => 0 } # no previous version
      count = @vh.coll.count( { :query => query } )
    end

    def numCollCreatesInRange(timeRange, coll=nil)
      setVh(coll)
      query = { PREV_VERSION_PATH => 0 }
      timeQuery = timeRangeToQuery(timeRange)
      query.merge!(timeQuery)
      count = @vh.coll.count( { :query => query } )
    end

    def mapCollCreatesInRangeByRes(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key { |range| retVal[range] = numCollCreatesInRange(range, opts[:coll]) }
      return retVal
    end
    alias :mapCollCreatesInRange :mapCollCreatesInRangeByRes # this is the preferred method, not ByRes

    def mapCollCreatesInRangeByAgg(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      opts[:entity] = :creates
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      # take advantage of sorted time range and sorted aggregation
      pipelineOut = aggregateVersionsInRange(timeRange, opts[:coll], opts)
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0
      pipelineOut.each { |projectDoc|
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(projectDoc[TIMESTAMP_NAME]) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          return timeRangeOrder, projectDoc
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        retVal[timeRange] += 1 if(projectDoc[PREV_VERSION_NAME] == 0)
      }
      if(opts[:cumulative])
        retVal = dateMapToCumulativeMap(retVal)
      end
      return retVal
    end

    #######################
    # EDIT ENTITY METHODS #
    #######################

    # Count the number of (strictly) edited documents in a collection
    # @param [Object] coll @see numDocsInColl
    # @return [Integer] number of edited documents
    # @note "Edits" refers to strictly edits while "Version" or "Change" refers to
    #   documents in the versions collection which also includes "Create" and "Delete"
    def numEditsInColl(coll=nil)
      numVersionsInColl(coll) - numCreatesInColl(coll) - numDeletesInColl(coll)
    end

    # @note because of schema-less "$ne" is a bad query operator even for boolean fields
    #   (the query engine doesn't know that we enforce that field to be boolean), so one
    #   query to find the number of edits is actually slower than multiple queries and 
    #   arithmetic
    def numCollEditsInRange(timeRange=nil, coll=nil)
      setVh(coll)
      count = numCollVersionsInRange(timeRange, coll) - numCollCreatesInRange(timeRange, coll) - numCollDeletesInRange(timeRange, coll)
      return count
    end

    def mapCollEditsInRangeByRes(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key { |range| retVal[range] = numCollEditsInRange(range, opts[:coll]) }
      return retVal
    end
    alias :mapCollEditsInRange :mapCollEditsInRangeByRes

    def mapCollEditsInRangeByAgg(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil
      }
      opts = defaultOpts.merge(opts)
      opts[:entity] = :edits
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      # take advantage of sorted time range and sorted aggregation
      pipelineOut = aggregateVersionsInRange(timeRange, opts[:coll], opts)
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0
      pipelineOut.each { |projectDoc|
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(projectDoc[TIMESTAMP_NAME]) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          return timeRangeOrder, projectDoc
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        retVal[timeRange] += 1 if(projectDoc[DELETE_NAME] != true and projectDoc[PREV_VERSION_NAME] != 0)
      }
      if(opts[:cumulative])
        retVal = dateMapToCumulativeMap(retVal)
      end
      return retVal
    end

    #########################
    # DELETE ENTITY METHODS #
    #########################

    # Count the number of deleted documents in a collection
    # @todo test
    # @param [Object] coll @see numDocsInColl
    # @return [Integer] number of deleted documents
    def numDeletesInColl(coll=nil)
      setVh(coll)
      query = { DELETE_PATH => true } # document has been deleted
      count = @vh.coll.count( { :query => query } )
    end

    def numCollDeletesInRange(timeRange=nil, coll=nil)
      setVh(coll)
      query = { DELETE_PATH => true }
      query.merge!(timeRangeToQuery(timeRange))
      count = @vh.coll.count( { :query => query } )
    end

    def mapCollDeletesInRangeByRes(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key { |range| retVal[range] = numCollDeletesInRange(range, opts[:coll]) }
      return retVal
    end
    alias :mapCollDeletesInRange :mapCollDeletesInRangeByRes

    def mapCollDeletesInRangeByAgg(timeRange=nil, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil
      }
      opts = defaultOpts.merge(opts)
      opts[:entity] = :deletes
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      # take advantage of sorted time range and sorted aggregation
      pipelineOut = aggregateVersionsInRange(timeRange, opts[:coll], opts)
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0
      pipelineOut.each { |projectDoc|
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(projectDoc[TIMESTAMP_NAME]) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          return timeRangeOrder, projectDoc
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        retVal[timeRange] += 1 if(projectDoc[DELETE_NAME] == true)
      }
      if(opts[:cumulative])
        retVal = dateMapToCumulativeMap(retVal)
      end
      return retVal
    end

    #####################
    # DISK SIZE METHODS #
    #####################

    # Count the number of bytes used by a collection
    # @param [Object] coll @see numDocsInColl
    # @return [Integer] number of bytes
    def numBytesOfColl(coll=nil)
      setDch(coll)
      @dch.coll.stats['size'] + @dch.coll.stats['totalIndexSize']
    end

    # Average number of bytes used across documents in a collection
    # @param [Object] coll @see numDocsInColl
    # @return [Numeric] average number of bytes
    def avgBytesOfCollDocs(coll=nil)
      setDch(coll)
      @dch.coll.stats['avgObjSize'].to_f
    end

    #########################
    # EXTREMAL EDIT METHODS #
    #########################

    # @see timeOfCollLastEdit
    def timeOfCollFirstEdit(coll=nil, aggDoc=nil)
      setVh(coll)
      aggDoc = aggDoc.nil? ? aggDocOfFirstEdit(coll) : aggDoc
      time = aggDoc.nil? ? nil : getNestedAttr(aggDoc, TIMESTAMP_PATH)
    end

    def timeOfKbFirstEdit 
      retVal = nil
      mdh = @mdb.collMetadataHelper()
      mongoNamePath = "name.value"
      gbTimePath = "name.status.date"
      query = { mongoNamePath => mdh.coll.name }
      kbDoc = BRL::Genboree::KB::KbDoc.new(mdh.coll.find_one(query))
      retVal = kbDoc.getPropVal(gbTimePath)
      return retVal
    end

    # Date the last edit made for any document in a given collection
    # @todo may raise Mongo::OperationFailure if sort attempted on too many documents
    # @param [Object] coll @see numDocsInColl
    # @param [BSON::OrderedHash] aggDoc @see aggDocOfLastEdit
    # @return [Time, NilClass] time of the last edit or nil if no documents in collection
    def timeOfCollLastEdit(coll=nil, aggDoc=nil)
      setVh(coll)
      aggDoc = aggDoc.nil? ? aggDocOfLastEdit(coll) : aggDoc
      time = aggDoc.nil? ? nil : getNestedAttr(aggDoc, TIMESTAMP_PATH)
    end

    # Get the author of the last edit made of all documents in the collection
    # @param [Object] coll @see numDocsInColl
    # @param [BSON::OrderedHash] aggDoc @see aggDocOfLastEdit
    # @return [String] author who made the last edit
    def authorOfCollLastEdit(coll=nil, aggDoc=nil)
      setVh(coll)
      path = "versionNum.properties.author.value"
      aggDoc = aggDoc.nil? ? aggDocOfLastEdit(coll) : aggDoc
      author = aggDoc.nil? ? nil : getNestedAttr(aggDoc, path)
      return author
    end


    # --------------------------------------------------
    # PROTECTED METHODS
    # --------------------------------------------------

    # Functions here may collect multiple errors in @errors; "StatsError" is
    #   analogous to a Bad Request while any other type of error is analogous
    #   to an Internal Server Error; aggregate all reasons for bad request or
    #   simply raise any Internal Server Error encountered
    # @note errors may also be raised directly and may not be collected in @errors
    def raiseAnyErrors
      unless(@errors.empty?)
        nonStatsError = nil
        @errors.each{|error|
          unless(error.is_a?(StatsError))
            nonStatsError = error
            break
          end
        }
        if(nonStatsError)
          raise nonStatsError
        else
          raise StatsError.new(@errors.collect{|xx| xx.message}.join("; "))
        end
      end
      return nil
    end

    # Most stats by their nature are non-negative quantities. We enforce this assumption here
    #   because sometimes we have corrupt kbs which have, for example, version documents that
    #   mark a version as both a "creation" and a "deletion" -- an impossibility
    # @param [Hash] statData @see e.g. docCount, docCountOverTime especially for various children
    #   and especially note the nuance for allCollStats vs kbStats and collStats
    # @return [Hash] statData with non-positive values transformed to zero
    def cleanStatData(statData)
      rv = statData.deep_clone()

      # yay closures!
      anyNegative = false
      negToZero = Proc.new { |xx|
        if xx.is_a?(Numeric) and xx < 0
          anyNegative = true
          0
        else
          xx
        end
      }
      BRL::Util::dfs!(rv, negToZero)
      if(anyNegative)
        $stderr.debugPuts(__FILE__, __method__, "WARNING", "The Mongo DB named #{@mdb.db.name} "\
          "produces stats with negative values, suggesting corrupt version records!")
      end
      return rv
    end

    # Associate a parsable time object to a calendar month Time object range
    # @see mapMonthToNumCollVersions
    def timeObjToMonthRange(timeObj)
      timeObj = (timeObj.is_a?(String) ? Time.parse(timeObj) : timeObj) rescue nil
      raise ArgumentError.new("Could not parse time for desired month!") unless(timeObj.is_a?(Time))
      startTime = Time.utc(timeObj.year, timeObj.month).setTimezone(timeObj.zone)
      endTime = nil
      if(timeObj.month == 12)
        endTime = Time.utc(timeObj.year+1, 1).setTimezone(timeObj.zone)
      else
        endTime = Time.utc(timeObj.year, timeObj.month+1).setTimezone(timeObj.zone)
      end
      (startTime...endTime)
    end

    # Parse a time range and construct a half open interval with it
    # @param [Array, Range] timeRange 2-tuple of objects to parse as a time range
    #   @see enumerateTimeRange for notes on time ranges
    # @see mapMonthToNumCollVersions for information on time zones
    def timeRangeToQuery(timeRange)
      raise ArgumentError.new("Must specify 2 times in first input timeRange") unless(timeRange.respond_to?(:first) and timeRange.respond_to?(:last))
      timeRange = [timeRange.first, timeRange.last]
      timeRange = timeRange.map{|timeObj| (timeObj.is_a?(String) ? Time.parse(timeObj) : timeObj) rescue nil }
      raise ArgumentError.new("Could not parse time range!") unless(timeRange[0].is_a?(Time) and timeRange[1].is_a?(Time))
      query = { TIMESTAMP_PATH => { "$gte" => timeRange[0] , "$lt" => timeRange[1] } }
    end

    # Get YYYYMMM strings for nMonths prior to given time in descending order
    # @param [Time, String] timeObj @see mapMonthsToNumKbVersions
    # @param [Integer] nMonths number of months prior to timeObj
    def yearMonths(timeObj=Time.now, nMonths=MONTHS.size)
      retVal = []
      year = timeObj.year
      month = timeObj.month # 1 to 12
      nMonths.times { |ii|
        if(month == 0)
          year -= 1
          month = MONTHS.size
        end
        retVal.push( [year, MONTHS[month-1]].join("") )
        month -= 1
      }
      retVal
    end

    # Set @dch to a dataCollectionHelper instance and handle input polymorphism and caching 
    #   of object
    # @param [String, BRL::Genboree::KB::Helpers::DataCollectionHelper] 
    def setDch(coll)
      if(coll.nil?)
        unless(@dch.is_a?(BRL::Genboree::KB::Helpers::DataCollectionHelper))
          raise ArgumentError.new("No prior dataCollectionHelper object and none was provided!")
        end
      elsif(coll.is_a?(BRL::Genboree::KB::Helpers::DataCollectionHelper))
        @dch = coll
      elsif(coll.is_a?(String))
        @dch = @mdb.dataCollectionHelper(coll)
      else
        raise ArgumentError.new("Please provide a string or dataCollectionHelper object")
      end
      return @dch.coll.name
    end

    # Set @vh to a versionsHelper instance and handle input polymorphism and caching
    #   of object
    def setVh(coll)
      if(coll.nil?)
        unless(@vh.is_a?(BRL::Genboree::KB::Helpers::VersionsHelper))
          raise ArgumentError.new("No prior versionsHelper object and none was provided!")
        end
      elsif(coll.is_a?(BRL::Genboree::KB::Helpers::VersionsHelper))
        @vh = coll
      elsif(coll.is_a?(String))
        @vh = @mdb.versionsHelper(coll)
      else
        raise ArgumentError.new("Please provide a string or versionsHelper object")
      end
      return @vh.coll.name
    end

    # Get a nested hash attribute specified by dot-delimited string
    # @todo might need this, put somewhere else, delete it?
    def getNestedAttr(hh, path, delim=".")
      tokens = path.split(delim)
      obj = hh
      tokens.each { |token|
        obj = obj[token] rescue nil
        break if(obj.nil?)
      }
      return obj
    end

    # override inspect to prevent composite object info overload
    def inspect
      mdbName = @mdb.db.name rescue nil
      dchName = @dch.coll.name rescue nil
      vhName = @vh.coll.name rescue nil
      self.to_s.gsub(">", " @mdb=#{mdbName.inspect}, @dch=#{dchName.inspect}, @vh=#{vhName.inspect}>")
    end

    ######################
    # TIME RANGE HELPERS #
    ######################

    # @param [Hash] dateMap @see chartTimeData
    def orderDateMap(timeToVal)
      order = nil
      # assume homogeneous
      if(timeToVal.keys.first.is_a?(Range))
        order = timeToVal.keys.sort{|xx, yy| xx.last <=> yy.last}
      else
        order = timeToVal.keys.sort{|xx, yy| Time.parse(xx) <=> Time.parse(yy)}
      end
      order
    end

    # @param [Hash] timeToVal @see chartTimeData
    # @return [Hash] cumulative version of timeToVal
    # @note only valid for versions entity
    def dateMapToCumulativeMap(timeToVal, order=nil)
      retVal = {}
      order = orderDateMap(timeToVal) if(order.nil?)
      order.inject(0) { |sum, key| 
        value = timeToVal[key]
        sum += value
        retVal[key] = sum
      }
      return retVal
    end

    # Modify chartObj with the named parameters supplied in opts
    def applyOptsToChart(chartObj, opts={})
      opts.each_key { |kk|
        vv = opts[kk]
        chartObj.send("#{kk}=".to_sym, vv) rescue nil
      }
      return chartObj
    end

    # @param [Array, Hash] data
    # @param [Hash<Symbol, Object>] opts the values to use for chartObj attributes
    def chartData(data, opts={})
      chartConfig = nil
      opts = opts.deep_clone
      if(opts[:format] == :hcLine)
        opts[:type] = "line"
      elsif(opts[:format] == :hcPie)
        opts[:type] = "pie"
      elsif(opts[:format] == :hcColumn)
        opts[:type] = "column"
      else
        raise ArgumentError.new("Cannot create chart of unknown type=#{opts[:type].inspect}")
      end

      if(dataIsTimeData?(data))
        chartConfig = chartTimeData(data, opts[:resolution], opts)
      else
        chartObj = BRL::Genboree::GenericHighchart.new()
        applyOptsToChart(chartObj, opts)
        chartObj.data = data
        chartConfig = chartObj.fillChartTemplate
      end
      return chartConfig
    end

    # Scans the Hash (JSON-like) format of the return values of the public interface methods to see if
    #   the (possibly nested) keys use time range objects (if so, a special chartTimeData 
    #   function can be used)
    # @param [Hash] data
    # @return [Boolean] true if the data uses Time objects as (possibly nested) keys
    def dataIsTimeData?(data)
      retVal = false
      if(data.is_a?(Hash) and !data.empty?)
        if(data.first[1].is_a?(Hash) and !data.first[1].empty?)
          if(data.first[1].first[0].is_a?(Range) and data.first[1].first[0].first.is_a?(Time))
            retVal = true
          end
        else
          if(data.first[0].is_a?(Range) and data.first[0].first.is_a?(Time))
            retVal = true
          end
        end
      end
      return retVal
    end

    # Represent time data as a line chart
    # @param [Array, Hash] dataSeries @see BRL::Genboree::GenericHighchart#collectDataSeries
    #   where xAxis is provided as a time range to this method
    # @param [Hash] opts
    #   [String] :title title for chart
    #   [String] :yAxis y axis label for chart
    #   [String] :units "# Documents", "# Edits", etc. suggested
    # @return [Hash] chartConfig object
    # @todo apply opts to chartObj
    def chartTimeData(dataSeries, resolution, opts={})
      # determine order of time values before label representation in case some label
      # is not parsable

      # assume (multiple) input time range maps define the same keys and find a
      #   single time range map we can use to determine the order of chart labels
      rangeToValue = nil
      if(dataSeries.is_a?(Hash) and !dataSeries.empty?)
        if(dataSeries.first[1].is_a?(Hash) and !dataSeries.first[1].empty?)
          rangeToValue = dataSeries.first[1]
        else
          rangeToValue = dataSeries
        end
      elsif(dataSeries.is_a?(Array))
        rangeToValue = dataSeries.first
      end
      raise ArgumentError.new("Input data does not contain time ranges") unless(rangeToValue.is_a?(Hash) and rangeToValue.first[0].is_a?(Range))
      rangeOrder = orderDateMap(rangeToValue)
      labelOrder = rangeOrder.map{|range| labelTime(rangeOrder.size, range.first, resolution)}

      # rekey time range maps to be a time label
      if(dataSeries.is_a?(Hash))
        if(dataSeries.first[1].is_a?(Hash))
          # then { seriesName => { time1...time2 => value, ... }, ... }
          dataSeries.each_key { |seriesName|
            data = {}
            dataSeries[seriesName].each_key { |timeRange|
              kk = labelTime(rangeOrder.size, timeRange.first, resolution)
              data[kk] = dataSeries[seriesName][timeRange]
            }
            dataSeries[seriesName] = data
          }
        else
          # then { time1...time2 => value, ... }
          data = {}
          dataSeries.each_key { |timeRange|
             kk = labelTime(rangeOrder.size, timeRange.first, resolution)
             data[kk] = dataSeries[timeRange]
          }
          dataSeries = data
        end
      else
        # then [ { time1...time2 => value, ... }, ... ] 
        dataSeries.each_index { |ii|
          series = dataSeries[ii]
          data = {}
          series.each_key { |timeRange|
            kk = labelTime(rangeOrder.size, timeRange.first, resolution)
            data[kk] = series[timeRange]
          }
          dataSeries[ii] = data
        }
      end

      chartObj = BRL::Genboree::GenericHighchart.new()
      applyOptsToChart(chartObj, opts)
      chartObj.xAxis = labelOrder
      chartObj.data = dataSeries
      chartConfig = chartObj.fillChartTemplate
    end

    # Get resolution as well as its more coarse parent resolutions
    def getTimeUnits(resolution)
      ii = TIME_UNITS.index(resolution)
      units = TIME_UNITS[0..ii]
    end

    # For input time range, generate finer resolution time ranges according to
    #   resolutions used by this class that "span" a length of time provided by the resolution
    # @param [Range<Time>] timeRange the coarse time range
    # @param [Symbol] resolution a name of a finer resolution for a time range, 
    #   @see GB_TO_MONGO_UNITS.keys
    # @param [Boolean] fill if false, the times spanned by the enumeration
    #   are a homogenous subset of those spanned by the coarse time range: in particular,
    #   no partial time ranges are used to fill gaps in, say, the case of a 1 year and 1 day
    #   coarse time range (which would result in 12 month-long time ranges starting from
    #   the first time in the coarse range)
    # @note all time ranges handled by this class are expected to be half-open on the right;
    #   if you need a closed interval you can simply add a second to the final range
    #   since Ruby 1.8.7 treats times as a discrete number of seconds since Jan 1 1970
    #   (note that this changes in 1.9 and later to a continuous representation)
    # @return [Hash<Range<Time>, Object>] fine resolution time ranges
    def enumSpanTimeRange(timeRange, resolution, fill=true)
      retVal = {}
      currTime = timeRange.first
      nextTime = nextTimeValue(currTime, resolution)
      while(nextTime <= timeRange.last)
        retVal[currTime...nextTime] = nil
        currTime = nextTime
        nextTime = nextTimeValue(nextTime, resolution)
      end
      if(fill and currTime < timeRange.last)
        retVal[currTime...timeRange.last] = nil
      end
      return retVal
    end

    # Alternative implementation which provides canonical subranges instead of
    #   ones affected by the start time and span the resolution's time unit. For
    #   example, Oct 07 to Nov 07 to Dec 07 (enumerateTimeRange) vs. Oct 07 to Nov 01 to Dec 01
    #   (enumCanonTimeRange)
    # @see enumerateTimeRange
    def enumCanonTimeRange(timeRange, resolution, fill=true)
      retVal = {}

      # check if initial time value is canonical
      startIsCanon = true
      timeTokens = timeRange.first.to_a[0...RESOLUTION_TO_RUBY[resolution]]
      timeTokens.each{|xx|
        if(xx != 0)
          startIsCanon = false
          break
        end
      }

      if(startIsCanon)
        # then there is nothing to do
        retVal = enumSpanTimeRange(timeRange, resolution, fill)
      else
        # then we optionally include the first (and last) sub range according to fill
        startCanon = nextCanonTimeValue(timeRange.first, resolution)
        retVal = enumSpanTimeRange(startCanon...timeRange.last, resolution, fill)
        if(fill)
          retVal[timeRange.first...startCanon] = nil
        end
      end

      return retVal
    end
    alias :enumerateTimeRange :enumCanonTimeRange

    # Translate Mongo query groups to our time range enumeration
    # @param [Hash] groupIdObj a group from a "$group" clause in an aggregation pipeline query 
    #   to Mongo with the clause defined according to the time methods in this class
    # @param [Range<Time>] @see enumerateTimeRange
    # @param [Symbol] @see enumerateTimeRange
    # @param [Boolean] @see enumerateTimeRange
    def mongoGroupToTimeRange(groupIdObj, timeRange, resolution=:month, fill=true)
      # time units are those defined in groupConfig of aggregation pipeline
      # which are in turn defined by getDateAggregator
      zone = timeRange.first.zone
      timeUnits = getTimeUnits(resolution)
      timeValues = timeUnits.map{|unit| groupIdObj[unit.to_s]}

      # time range may provide time detail at a finer resolution than our mongo query, adjust
      offsetTokens = timeRange.first.to_a
      timeUnits.each_index { |unitIndex|
        unit = timeUnits[unitIndex]
        value = timeValues[unitIndex]
        rubyIndex = RESOLUTION_TO_RUBY[unit]
        offsetTokens[rubyIndex] = value
      }
      timeObjStart = Time.gbMktime(*offsetTokens)

      timeObjEnd = nextTimeValue(timeObjStart, resolution)
      if(timeObjEnd.nil?)
        raise ArgumentError.new("Could not get next time value for #{timeObjStart} at resolution #{resolution}")
      end
      timeObjEnd = timeObjEnd.setTimezone(zone)

      # time range may not divide evenly to sub ranges at the given resolution, fill
      #   the range if desired
      if(fill and timeObjEnd > timeRange.last)
        timeObjEnd = timeRange.last
      end
      range = timeObjStart...timeObjEnd
      return range
    end

    # Get the successor to a time value at a given resolution (rather than Ruby default :second)
    #   where the next time value "spans" the resolution
    # @param [Time] timeObj a time to get the next time for
    # @param [Symbol] resolution @see GB_TO_MONGO_UNITS.keys
    # @return [Time] the successor to timeObj
    # @note we can always increment year
    # @todo this behaves perhaps a bit unexpectedly with resolution=:day around DST changes:
    #   the next time for Sun Nov 02 00:00:00 -0500 2014 is Sun Nov 02 23:00:00 -0600 2014
    def nextSpanTimeValue(timeObj, resolution)
      timeArray = timeObj.to_a
      ii = RESOLUTION_TO_RUBY[resolution]
      raise ArgumentError.new("Cannot increment time for resolution #{resolution.inspect}") if(ii.nil? or ii > MAX_RESOLUTION_IDX)
      # try to increment time for the resolution until we dont encounter ArgumentError out of bounds (e.g. 61st second)
      nextTime = nil
      while(!nextTime.is_a?(Time) and ii <= MAX_RESOLUTION_IDX)
        resolution = RUBY_TO_RESOLUTION[ii]
        if(resolution == :year)
          # we can always increment year
          timeArray[5] += 1
          nextTime = Time.gbMktime(*timeArray)
        elsif(resolution == :month)
          # then we use Ruby's Date class for help around say Oct-31 -> Nov-30
          dd = Date.new(*timeArray[3..5].reverse)
          dd2 = dd >> 1
          timeArray[3] = dd2.day
          timeArray[4] = dd2.month
          timeArray[5] = dd2.year
          nextTime = Time.gbMktime(*timeArray)
        elsif(resolution == :day)
          # again, use Date for help
          dd = Date.new(*timeArray[3..5].reverse)
          dd2 = dd + 1
          timeArray[3] = dd2.day
          timeArray[4] = dd2.month
          timeArray[5] = dd2.year
          nextTime = Time.gbMktime(*timeArray)
        elsif(resolution == :minute or resolution == :hour)
          # otherwise we just increment the time unit associated with the resolution and start 
          # over from 0 at the next time unit if we fail
          timeArray[ii] += 1
          begin
            nextTime = Time.gbMktime(*timeArray)
          rescue ArgumentError => err
            timeArray[ii] = RESOLUTION_TO_FIRST[resolution]
          end
        end
        ii += 1
      end
      return nextTime
    end

    # Alternative implementation which provides canonical successive time units instead of
    #   ones affected by the subresolution time units of the timeObj and span the resolution's time unit. For
    #   example, Oct 07 to Nov 07 (nextTimeValue) vs. Oct 07 to Nov 01 (nextCanonTimeValue)
    # @see nextSpanTimeValue
    def nextCanonTimeValue(timeObj, resolution)
      retVal = nextSpanTimeValue(timeObj, resolution)

      # force retVal to be canonical by modifying sub-resolution time units to their first unit
      nTimeUnits = RESOLUTION_TO_RUBY[resolution]
      timeTokens = Array.new(nTimeUnits, 0)
      timeTokens.each_index{|ii|
        timeTokens[ii] = RESOLUTION_TO_FIRST[RUBY_TO_RESOLUTION[ii]]
      }
      timeTokens[RESOLUTION_TO_RUBY[:second]] = 0 # use first unit except for seconds: force to 0
      retValTokens = retVal.to_a
      retValTokens[0...nTimeUnits] = timeTokens
      retVal = Time.gbMktime(*retValTokens)

      return retVal
    end
    alias :nextTimeValue :nextCanonTimeValue

    RES_TO_STRF = {
      [:minute] => "%M",
      [:minute, :hour] => "%H:%M",
      [:minute, :hour, :day] => "%d %H:%M",
      [:minute, :hour, :day, :month] => "%^b %d %H:%M",
      [:minute, :hour, :day, :month, :year] => "%F %H:%M",

      [:hour] => "%H:00",
      [:hour, :day] => "%d %H:00", # er... unclear
      [:hour, :day, :month] => "%^b %d %H:00",
      [:hour, :day, :month, :year] => "%F %H:00",

      [:day] => "%d", # also unclear
      [:day, :month] => "%^b %d",
      [:day, :month, :year] => "%F",

      [:month] => "%^b",
      [:month, :year] => "%Y-%^b",

      [:year] => "%Y"
    }
    # Provide a minimal label for a time object based on some heuristics about the number of
    #   items that need labels and the resolution
    # @param [Hash] timeRanges @see enumerateTimeRange (return value of, e.g.)
    # @param [Time] timeObj e.g. timeRanges[kk].first
    # @param [Symbol] resolution @see TIME_UNITS
    # @note assume contiguous timeRanges as in @see enumerateTimeRange
    def labelTime(timeRangesSize, timeObj, resolution)
      timeUnits = [resolution]
      currValues = timeRangesSize
      currRes = resolution
      while currValues > RESOLUTION_TO_LAST[currRes]
        currValues /= RESOLUTION_TO_LAST[currRes]
        ii = TIME_UNITS.index(currRes)
        currRes = TIME_UNITS[ii - 1]
        timeUnits << currRes
      end
      return timeObj.strftime(RES_TO_STRF[timeUnits])
    end

    ################################
    # AGGREGATION PIPELINE HELPERS #
    ################################
    
    # Get date aggregator for a given time unit and document path
    # @param [String] unit @see TIME_UNITS, a list of GB time units
    # @param [String] path a Mongo property path e.g. "versionNum.properties.timestamp.value" 
    # @return [Hash] Mongo expression that can be used in e.g. a group by clause of aggregation pipeline
    def getDateAggregator(unit, path=TIMESTAMP_PATH)
      return { unit.to_s => { "$#{GB_TO_MONGO_UNITS[unit]}" => "$#{path}" } }
    end

    # @param [Object] coll @see setVh
    # @param [Integer] sortOrder if -1, last edit; if 1, first edit
    # @return [Array] pipeline a Mongo aggregation pipeline config
    def pipelineOfLastEdit(coll=nil, sortOrder=-1)
      setVh(coll)
      delim = "."
      mongoIdPath = "$_id"
      accumulator = "$push"
      sort = {"$sort" => { TIMESTAMP_PATH => sortOrder}}
      limit = {"$limit" => 1}
      pipeline = [ sort, limit ]
    end
   
    # Get a document containing all document IDs that were edited most recently
    #   (multiple documents may be edited at the same time with a bulk upsert operation)
    # @param [Object] coll @see numDocsInColl
    # @return [Hash] grouping object:
    #   GROUP_KEY="_id" => { CHILD_KEY="value" => Time }
    #   DOC_IDS_KEY="docIds" => [ { CHILD_KEY="value" => BSON::ObjectID } , ... ]
    def aggDocOfLastEdit(coll=nil)
      pipeline = pipelineOfLastEdit(coll)
      resp = @vh.coll.aggregate(pipeline).first
      return resp
    end

    # @see aggDocOfLastEdit (reverse sort order to get first edit)
    def aggDocOfFirstEdit(coll=nil)
      # modify pipeline to reverse sort order
      pipeline = pipelineOfLastEdit(coll, 1)
      resp = @vh.coll.aggregate(pipeline).first
      return resp
    end

    # @return Array<BSON::OrderedHash> documents defined by project config, e.g.
    #   [BSON::ObjectId] _id the object id for the version document
    #   [Object] @dch.getIdentifierName the value of the identifier property for the document
    #   [Time] timestamp the time associated with the version document
    def aggregateVersionsInRange(timeRange, coll=nil, opts={})
      setDch(coll)
      setVh(coll)
      defaultOpts = {
        :entity => :versions
      }
      opts = defaultOpts.merge(opts)
      delim = "."
      mongoIdPath = "_id"
      gbIdName = @dch.getIdentifierName()
      gbIdPath = "versionNum.properties.content.value.#{gbIdName}.value"
      accumulator = "$push"

      # define projectConfig based on the requested entity
      projectConfig = {
        TIMESTAMP_NAME => "$#{TIMESTAMP_PATH}",
        mongoIdPath => "$#{mongoIdPath}"
      }
      if(opts[:entity] == :docs)
        projectConfig.merge!({
          gbIdName => "$#{gbIdPath}"
        })
      elsif(opts[:entity] == :creates)
        projectConfig.merge!({
          PREV_VERSION_NAME => "$#{PREV_VERSION_PATH}"
        })
      elsif(opts[:entity] == :edits)
        # creates and deletes
        projectConfig.merge!({
          PREV_VERSION_NAME => "$#{PREV_VERSION_PATH}",
          DELETE_NAME => "$#{DELETE_PATH}"
        })
      elsif(opts[:entity] == :deletes)
        projectConfig.merge!({
          DELETE_NAME => "$#{DELETE_PATH}"
        })
      else
        # opts[:entity] == version default
        projectConfig.merge!({
          gbIdName => "$#{gbIdPath}"
        })
      end

      # define aggregation pipeline
      pipeline = []
      sortOrder = 1 # ascending, -1 for descending
      sort = {
        "$sort" => {
          TIMESTAMP_PATH => sortOrder
        }
      }
      pipeline << sort

      match = {}
      if(timeRange)
        match = {
          "$match" => timeRangeToQuery(timeRange)
        }
        pipeline << match
      end

      projection = {
        "$project" => projectConfig
      }
      if(opts["$project"])
        projection["$project"].merge!(opts["$project"])
      end
      pipeline << projection

      resp = @vh.coll.aggregate(pipeline)
      return resp
    end

    # Partition document versions into bins of a specified resolution with parts of
    #   the versions document that are relevant to public entity methods
    # @param [Range<Time>] timeRange @see enumerateTimeRange for notes on time ranges
    # @param [Symbol] resolution @see GB_TO_MONGO_UNITS
    # @param [Object] coll @see setVh
    # @param [Hash] opts supplements to projection and group clauses as needed
    #   [Hash] "$project" additional fields from the version document to include
    #   [Hash] "$group" additional fields from the projection to use in grouping
    # @return [Hash] mongo aggregation pipeline output
    # @see mapCollVersionsInRangeByAgg
    # @note DEPRECATED because incorrect for non-canonical startTime @see aggregateVerisonsInRange
    def aggregateVersionsByTime(timeRange=nil, resolution=:month, coll=nil, opts={})
      setDch(coll)
      setVh(coll)
      raise ArgumentError.new("Resolution #{resolution} is not a supported resolution: #{GB_TO_MONGO_UNITS.keys.inspect}") unless(GB_TO_MONGO_UNITS.key?(resolution))
      defaultOpts = {
        :entity => :versions
      }
      opts = defaultOpts.merge(opts)
      delim = "."
      mongoIdPath = "_id"
      gbIdName = @dch.getIdentifierName()
      gbIdPath = "versionNum.properties.content.value.#{gbIdName}.value"
      accumulator = "$sum"

      # setup time units for groupConfig based on resolution
      units = getTimeUnits(resolution)
      groupConfig = units.inject({}){|cfg, unit| cfg.merge!(getDateAggregator(unit, TIMESTAMP_PATH))}

      # define aggregation pipeline
      pipeline = []

      indexSort = {
        "$sort" => {
          TIMESTAMP_PATH => 1
        }
      }
      pipeline << indexSort

      match = {}
      if(timeRange)
        match = {
          "$match" => timeRangeToQuery(timeRange)
        }
        pipeline << match
      end

      group = { 
        "$group" => { 
          GROUP_KEY => groupConfig,
          # @todo make constant
          "groupCount" => {
            accumulator => 1
          }
        }
      }
      pipeline << group

      # @todo may error if large number of groups
      sortConfig = BSON::OrderedHash.new()
      units.each { |unit|
        sortConfig["#{GROUP_KEY}.#{unit.to_s}"] = 1
      }
      sort = {
        "$sort" => sortConfig
      }
      pipeline << sort

      resp = @vh.coll.aggregate(pipeline)
      return resp
    end

    def mapCollVersionsInRangeByTimeAgg(timeRange, opts={})
      defaultOpts = {
        :resolution => :month,
        :fill => true,
        :coll => nil,
        :cumulative => false
      }
      opts = defaultOpts.merge(opts)
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      timeRangeOrder = orderDateMap(retVal)
      timeRangeIndex = 0

      # use a resolution 1 unit finer than the request to support non-canonical time ranges
      # e.g. Jan 15 to Feb 15 rather than Jan 1 to Feb 1
      resolution = TIME_UNITS[TIME_UNITS.index(opts[:resolution]) + 1] rescue nil
      raise ArgumentError.new("Cannot complete query with a resolution finer than #{TIME_UNITS[TIME_UNITS.size-2]}") if(resolution.nil?)

      # use results from mongo query to populate return value
      # use sorted order of timeRangeOrder and pipelineOut
      pipelineOut = aggregateVersionsByTime(timeRange, resolution, opts[:coll], opts)
      pipelineOut.each_index { |ii|
        groupDoc = pipelineOut[ii]
        groupId = groupDoc["_id"]
        groupCount = groupDoc["groupCount"]
        mktimeArgs = TIME_UNITS.map{|xx| groupId[xx.to_s]}
        timeObj = Time.utc(*mktimeArgs)
        timeRange = timeRangeOrder[timeRangeIndex]
        until(timeRange.include?(timeObj) or timeRangeIndex >= timeRangeOrder.size)
          timeRangeIndex += 1
          timeRange = timeRangeOrder[timeRangeIndex]
        end
        if(timeRangeIndex >= timeRangeOrder.size)
          raise RuntimeError.new("Could not place version document #{projectDoc["_id"]} in time range enumeration")
        end
        retVal[timeRange] += groupCount
      }
      if(opts[:cumulative])
        # with versions we are not worried about uniqueness problems like we are with docs
        retVal = dateMapToCumulativeMap(retVal)
      end
      return retVal
    end

    ###############################
    # TOO SPECIFIC TIME FUNCTIONS #
    ###############################
    # Functions here remain as examples/convenience functions also for charts who require 
    #   some more specific functions
    # @see numCollVersionsInRange, mapCollVersionsInRangeByRes, mapCollVersionsInRangeByAgg for
    #   more generic alternatives
    
    # @see mapMonthToNumCollVersions
    def numCollVersionsInMonth(timeObj, coll=nil)
      mapMonthToNumCollVersions(timeObj, coll).values.first
    end

    # Map calendar month to the number of edits made in a collection for that month
    # @param [Time, String] timeObj specify the calendar month to report changes for through
    #   either a Time.parse parsable String or through a Time object directly
    # @param [Object] coll @see #setVh
    # @note specific time zones are supported according to the behavior of Time.parse:
    #   if the timeObj param specifies a time zone it is used, otherwise the machine's local 
    #   time is used
    # @note # edits for (right) half open interval of [month, month+1)
    def mapMonthToNumCollVersions(timeObj, coll=nil, opts={})
      setDch(coll)
      setVh(coll)
      timeRange = timeObjToMonthRange(timeObj)
      retVal = { timeRange => numCollVersionsInRange(timeRange, coll) }
      return retVal
    end

    # Map past year's months as YYYYMMM strings to number of edits
    # @param [Object] coll @see mapMonthToNumCollVersions
    # @param [Hash] opts optional named parameters
    #   [Boolean] :cumulative if true represent time data as cumulative
    #   [Boolean] :chart if true represent time data as a highcharts config
    #   [String] :title @see chartTimeData
    #   [String] :yAxis @see chartTimeData
    #   [String] :units @see chartTimeData
    # @return [Hash] map data as a raw hash or chart config
    def mapMonthsToNumCollVersions(coll=nil, opts={})
      retVal = {}
      yearMonths().each { |month|
        retVal[month] = numCollVersionsInMonth(month, coll)
      }
      defaultOpts = { 
        :cumulative => false, 
        :chart => false, 
        :title => "Number of #{@dch.coll.name} collection changes",
        :yAxis => "# Changes",
        :units => "Changes"
      }
      defaultOpts[:title] = "Cumulative number of #{@dch.coll.name} collection changes" if(opts[:cumulative] and !opts.key?(:title))
      opts = defaultOpts.merge(opts)
      retVal = dateMapToCumulativeMap(retVal) if(opts[:cumulative])
      retVal = chartTimeData(retVal, opts) if(opts[:chart])
      return retVal
    end

    # @see mapMonthToNumCollDocs
    def numCollDocsInMonth(timeObj, coll=nil)
      mapMonthToNumCollDocs(timeObj, coll).values.first
    end

    # Map calendar month to the number of unique documents in a collection
    # @see mapMonthToNumCollVersions (unique documents instead of edits)
    def mapMonthToNumCollDocs(timeObj, coll=nil)
      setDch(coll)
      setVh(coll)
      path = "versionNum.properties.content.value.#{@dch.getIdentifierName}.value"
      timeRange = timeObjToMonthRange(timeObj)
      query = timeRangeToQuery(timeRange)
      count = @vh.coll.distinct(path, query).size
      { timeRange => count }
    end

    # @see mapMonthsToNumCollVersions (unique documents instead of number of edits)
    def mapMonthsToNumCollDocs(coll=nil, opts={})
      retVal = {}
      yearMonths().each { |month|
        retVal[month] = numCollDocsInMonth(month, coll)
      }
      defaultOpts = { 
        :cumulative => false, 
        :chart => false, 
        :title => "Number of #{@dch.coll.name} collection documents",
        :yAxis => "# Documents",
        :units => "Documents"
      }
      defaultOpts[:title] = "Cumulative number of #{@dch.coll.name} collection documents" if(opts[:cumulative] and !opts.key?(:title))
      opts = defaultOpts.merge(opts)
      retVal = dateMapToCumulativeMap(retVal) if(opts[:cumulative])
      retVal = chartTimeData(retVal, opts) if(opts[:chart])
      return retVal
    end
  end

  # error messages from this class are okay to pass on to the user; if through the api, 
  #   its a bad request
  class StatsError < RuntimeError
  end
end; end; end; end
