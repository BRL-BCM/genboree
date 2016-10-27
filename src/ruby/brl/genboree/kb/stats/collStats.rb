require 'brl/genboree/kb/stats/allCollStats'

module BRL; module Genboree; module KB; module Stats
  class CollStats < AllCollStats

    def initialize(mdb, dch)
      super(mdb)
      setDch(dch)
      setVh(@dch.coll.name)
    end

    def getAllStats
      raise NotImplementedError.new()
    end

    # Handles common logic for all stats
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

  end
end; end; end; end
