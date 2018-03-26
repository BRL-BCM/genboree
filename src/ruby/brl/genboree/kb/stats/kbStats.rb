require 'brl/genboree/kb/stats/abstractStats'

module BRL; module Genboree; module KB; module Stats
  class KbStats < AbstractStats

    # simple alias is insufficent but provide a map of associated methods
    STAT_TO_METHOD = {
      :docCount => :numDocsInKb,
      :versionCount => :numVersionsInKb,
      :createCount => :numCreatesInKb,
      :editCount => :numEditsInKb,
      :deleteCount => :numDeletesInKb,
      :byteSize => :numBytesOfKb,
      :avgByteSize => :avgBytesOfKbDocs,
      :lastEditTime => :timeOfKbLastEdit,
      :lastEditAuthor => :authorOfKbLastEdit,
      :docCountOverTime => :mapKbDocsInRange,
      :versionCountOverTime => :mapKbVersionsInRange,
      :createCountOverTime => :mapKbCreatesInRange,
      :editCountOverTime => :mapKbEditsInRange,
      :deleteCountOverTime => :mapKbDeletesInRange,
      :lastNEditedDocs => :lastNEditedDocsInColl
    }

    ##################
    # PUBLIC METHODS #
    ##################

    # Collect commonly requested statistics into a single object
    # @return [Hash<Symbol, Object>]
    def getAllStats
      {
        :numColl => numCollections,
        :numDocs => numDocsInKb,
        :numVersions => numVersionsInKb,
        :numCreates => numCreatesInKb,
        :numEdits => numEditsInKb,
        :numDeletes => numDeletesInKb,
        :timeLastEdit => timeOfKbLastEdit,
        :authorLastEdit => authorOfKbLastEdit,
        :diskSize => numBytesOfKb,
        :mapCollsToNumDocs => mapCollsToNumDocs,
        :mapMonthsToNumKbEdits => mapMonthsToNumKbEdits,
        :mapMonthsToNumKbDocs => mapMonthsToNumKbDocs
      }
    end

    #####################
    # PROTECTED METHODS #
    #####################

    # Handles common logic for all stats
    # @todo same as collStats but not allCollStats
    # @todo should cleanStatData be called? this is a scalar
    def statWrapper(stat, opts={})
      opts = parseCoreOpts(opts) # sets @errors, @warnings
      raiseAnyErrors()
      retVal = {}
      chart = /^hc/.match(opts[:format].to_s) ? true : false
      retVal = self.send(STAT_TO_METHOD[stat])
      retVal = cleanStatData(retVal)
      if(chart)
        retVal = chartData(retVal, opts)
      end
      return retVal
    end

    # Handles common logic for all "over time" stats
    # @todo same as collStats but not allCollStats
    def statWrapperOverTime(stat, opts={})
      retVal = {}
      opts = parseCoreOptsOverTime(opts) # sets @errors, @warnings
      raiseAnyErrors()
      timeRange = (opts[:startTime]...opts[:endTime])
      retVal = self.send(STAT_TO_METHOD[stat], timeRange, opts)
      retVal = cleanStatData(retVal)
      retVal = dateMapToCumulativeMap(retVal) if(opts[:cumulative])
      chart = /^hc/.match(opts[:format].to_s) ? true : false
      if(chart)
        retVal = chartData(retVal, opts)
      else
        retVal = rekeyTimeRanges(retVal)
      end
     
      return retVal
    end

    def mapKbEntityInRange(entity, timeRange, opts)
      entity2Method = {
        :docs => :mapCollDocsInRange,
        :versions=> :mapCollVersionsInRange,
        :creates => :mapCollCreatesInRange,
        :edits => :mapCollEditsInRange,
        :deletes => :mapCollDeletesInRange,
      }
      retVal = enumerateTimeRange(timeRange, opts[:resolution], opts[:fill])
      retVal.each_key{ |kk| retVal[kk] = 0}
      @mdb.collections.each { |coll|
        opts[:coll] = coll
        collEnum = self.send(entity2Method[entity], timeRange, opts)
        retVal.each_key { |subTimeRange|
          retVal[subTimeRange] += collEnum[subTimeRange].to_i
        }
      }
      return retVal
    end

    def mapKbDocsInRange(timeRange, opts)
      mapKbEntityInRange(:docs, timeRange, opts)
    end

    def mapKbVersionsInRange(timeRange, opts)
      mapKbEntityInRange(:versions, timeRange, opts)
    end

    def mapKbCreatesInRange(timeRange, opts)
      mapKbEntityInRange(:creates, timeRange, opts)
    end

    def mapKbEditsInRange(timeRange, opts)
      mapKbEntityInRange(:edits, timeRange, opts)
    end

    def mapKbDeletesInRange(timeRange, opts)
      mapKbEntityInRange(:deletes, timeRange, opts)
    end

    # Get number of external collections (e.g. not .versions)
    def numCollections
      @mdb.collections.size
    end

    def numEntityInKb(entity)
      raise ArgumentError.new("Unsupported entity #{entity.inspect}") unless(ENTITIES.include?(entity))
      self.send("num#{entity.to_s.capitalize}InKb")
    end

    # @return [Integer] number of documents in the KB
    def numDocsInKb
      @mdb.collections.inject(0) { |sum, coll| sum += numDocsInColl(coll) }
    end

    # @return [Hash] map of collection name to number of documents in it
    def mapNumDocsInKb
      @mdb.collections.inject({}) { |map, coll| map[coll] = numDocsInColl(coll) }
    end

    # @see numVersionsInColl
    def numVersionsInKb
      @mdb.collections.inject(0) { |sum, coll| sum += numVersionsInColl(coll) }
    end

    # @return [Hash] map of collection name to number of versions in it
    def mapNumVersionsInKb
      @mdb.collections.inject({}) { |map, coll| map[coll] = numVersionsInColl(coll) }
    end

    # @see numCreatesInColl
    def numCreatesInKb
      @mdb.collections.inject(0) { |sum, coll| sum += numCreatesInColl(coll) }
    end

    # @return [Hash] map of collection name to number of creates in it
    def mapNumCreatesInKb
      @mdb.collections.inject({}) { |map, coll| map[coll] = numCreatesInColl(coll) }
    end

    # @see numEditsInColl
    def numEditsInKb
      @mdb.collections.inject(0) { |sum, coll| sum += numEditsInColl(coll) }
    end

    # @return [Hash] map of collection name to number of Edits in it
    def mapNumEditsInKb
      @mdb.collections.inject({}) { |map, coll| map[coll] = numEditsInColl(coll) }
    end

    # @see numDeletesInColl
    def numDeletesInKb
      @mdb.collections.inject(0) { |sum, coll| sum += numDeletesInColl(coll) }
    end

    # @return [Hash] map of collection name to number of versions in it
    def mapNumDeletesInKb
      @mdb.collections.inject({}) { |map, coll| map[coll] = numDeletesInColl(coll) }
    end

    # @see timeOfLastCollEdit
    def timeOfKbLastEdit
      max = 0
      @mdb.collections.inject(0) { |max, coll| 
        max = [max, timeOfCollLastEdit(coll).to_i].max
      }
      max == 0 ? nil : Time.at(max)
    end

    # @see authorOfCollLastEdit
    def authorOfKbLastEdit
      author = nil
      map = mapTimeOfCollLastEditToAuthor
      max = map.max_by { |avp| kk = avp[0] }
      author = max[1] rescue nil # if new kb and there are no edits
    end

    # Get disk usage of entire kb (including internal collections)
    # @see numBytesOfColl (in addition to internal collections, this adds namespace bytes)
    def numBytesOfKb
      @mdb.db.stats['fileSize'] + @mdb.db.stats['indexSize'] + @mdb.db.stats['nsSizeMB'] * (1024*1024)
    end

    # Get average number of bytes used for documents in all collections in the kb 
    #   (including internal collections)
    # @see avgBytesOfCollDocs
    def avgBytesOfKbDocs
      @mdb.db.stats['avgObjSize'].to_f
    end

    # Show detail for numDocsInKb by enumerating numDocsInColl
    # @see numDocsInColl
    # @see numDocsInKb
    def mapCollsToNumDocs
      coll2NumDocs = {}
      @mdb.collections.each { |coll| coll2NumDocs[coll] = numDocsInColl(coll) }
      coll2NumDocs
    end

    # @see mapMonthsToNumCollEdits
    def mapMonthsToNumKbEdits(opts={})
      retVal = {}
      yearMonths().each { |month|
        retVal[month] = @mdb.collections.inject(0) { |sum, coll| sum += numCollEditsInMonth(month, coll) }
      }
      defaultOpts = { 
        :cumulative => false, 
        :chart => false, 
        :title => "Number of #{@mdb.db.name} KB edits",
        :yAxis => "# Edits",
        :units => "Edits"
      }
      defaultOpts[:title] = "Cumulative number of #{@mdb.db.name} KB edits" if(opts[:cumulative] and !opts.key?(:title))
      opts = defaultOpts.merge(opts)
      retVal = dateMapToCumulativeMap(retVal) if(opts[:cumulative])
      retVal = chartTimeData(retVal, opts) if(opts[:chart])
      return retVal
    end

    # @see mapMonthsToNumKbEdits (unique documents instead of number of edits)
    def mapMonthsToNumKbDocs(opts={})
      retVal = {}
      yearMonths().each { |month|
        retVal[month] = @mdb.collections.inject(0) { |sum, coll| sum += numCollDocsInMonth(month, coll) }
      }
      defaultOpts = { 
        :cumulative => false, 
        :chart => false, 
        :title => "Number of #{@mdb.db.name} KB documents",
        :yAxis => "# Documents",
        :units => "Documents"
      }
      defaultOpts[:title] = "Cumulative number of #{@mdb.db.name} KB documents" if(opts[:cumulative] and !opts.key?(:title))
      opts = defaultOpts.merge(opts)
      retVal = dateMapToCumulativeMap(retVal) if(opts[:cumulative])
      retVal = chartTimeData(retVal, opts) if(opts[:chart])
      return retVal
    end

    # Chart e.g. mapCollsToNumDocs data
    def chartMapData(map, type="pie")
      chartObj = BRL::Genboree::GenericHighchart.new()
      chartObj.type = type
      chartConfig = fillChartTemplateWithHash(map)
    end

    # @see parent
    def inspect
      super()
    end

    # Utility method for KB aggregation of collection last edit authors
    # @see authorOfCollLastEdit
    # @note multiple collections could feasibly be edited within the same second
    def mapTimeOfCollLastEditToAuthor
      map = {}
      # parallel with collections order
      @mdb.collections.each { |coll|
        aggDoc = aggDocOfLastEdit(coll) # nil if coll has no doc
        unless(aggDoc.nil?)
          map[timeOfCollLastEdit(coll, aggDoc)]  = authorOfCollLastEdit(coll, aggDoc)
        end
      }
      map
    end
  end
end; end; end; end
