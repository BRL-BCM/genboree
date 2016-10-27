require 'brl/genboree/kb/stats/abstractStats'

module BRL; module Genboree; module KB; module Stats
  class AllCollStats < AbstractStats

    # simple alias is insufficent but provide a map of associated methods
    STAT_TO_METHOD = {
      :docCount => :numDocsInColl,
      :versionCount => :numVersionsInColl,
      :createCount => :numCreatesInColl,
      :editCount => :numEditsInColl,
      :deleteCount => :numDeletesInColl,
      :byteSize => :numBytesOfColl,
      :avgByteSize => :avgBytesOfCollDocs,
      :lastEditTime => :timeOfCollLastEdit,
      :lastEditAuthor => :authorOfCollLastEdit,
      :docCountOverTime => :mapCollDocsInRange,
      :versionCountOverTime => :mapCollVersionsInRange,
      :createCountOverTime => :mapCollCreatesInRange,
      :editCountOverTime => :mapCollEditsInRange,
      :deleteCountOverTime => :mapCollDeletesInRange
    }

    #--------------------------------------------------
    # helper methods
    #--------------------------------------------------

    # override default chart options
    def docCount(opts={})
      defaultOpts = { 
        :title => "# Docs Per Collection",
        :yAxis => "# Docs",
        :units => "Documents",
        :seriesNames => ["Documents"]
      }
      opts = defaultOpts.merge(opts)
      super(opts)
    end

    # Handles common logic for all stats
    def statWrapper(stat, opts={})
      opts = parseCoreOpts(opts) # sets @errors, @warnings
      raiseAnyErrors()
      retVal = {}
      chart = /^hc/.match(opts[:format].to_s) ? true : false
      @mdb.collections.each { |coll|
        retVal[coll] = self.send(STAT_TO_METHOD[stat], coll)
      }
      retVal = cleanStatData(retVal)
      if(chart)
        retVal = chartData(retVal, opts)
      end
      return retVal
    end

    # Handles common logic for all "over time" stats
    def statWrapperOverTime(stat, opts={})
      retVal = {}
      opts = parseCoreOptsOverTime(opts) # sets @errors, @warnings
      raiseAnyErrors()
      timeRange = (opts[:startTime]...opts[:endTime])
      @mdb.collections.each { |coll|
        opts[:coll] = coll
        retVal[coll] = self.send(STAT_TO_METHOD[stat], timeRange, opts)
        retVal = cleanStatData(retVal)
        retVal[coll] = dateMapToCumulativeMap(retVal[coll]) if(opts[:cumulative])
      }

      chart = /^hc/.match(opts[:format].to_s) ? true : false
      if(chart)
        unless(@mdb.collections.empty?)
          retVal = chartData(retVal, opts)
        else
          retVal = nil
          begin
            raise StatsError.new("Cannot create chart for #{:stat.to_s.inspect} because the KB has no collections!")
          rescue => err
            @errors << err
          end
        end
      else
        retVal = rekeyTimeRanges(retVal)
      end
     
      return retVal
    end

    # Override parent to provide hcColumn and hcPie formats
    def parseCoreOpts(opts={})
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json, :hcColumn, :hcPie]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end

    # Override parent to provide hcColumn and hcPie formats
    def parseSizeOpts(opts)
      opt2DefaultVal = {
        :format => :json
      }
      opt2SupportedVals = {
        :format => [:json, :hcColumn, :hcPie]
      }
      return parseOpts(opts, opt2DefaultVal, opt2SupportedVals)
    end


  end
end; end; end; end
