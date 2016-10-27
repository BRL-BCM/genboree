require 'brl/genboree/rest/resources/kbStat'
require 'brl/genboree/kb/stats/collStats'

module BRL; module REST; module Resources
class KbCollStat < KbStat
  RSRC_TYPE = 'kbCollStat'
  STAT_DESCRIPTIONS = BRL::Genboree::KB::Stats::CollStats::STAT_DESCRIPTIONS
  OPTION_DESCRIPTIONS = BRL::Genboree::KB::Stats::CollStats::OPTION_DESCRIPTIONS
  SUPPORTED_STATS = STAT_DESCRIPTIONS.keys()

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/stat/([^/\?]+)}
  end

  def self.priority()
    return 6 # higher than kbCollection
  end

  # override parent
  def parseUri(matchData=@uriMatchData)
    @groupName = Rack::Utils.unescape(@uriMatchData[1])
    @kbName = Rack::Utils.unescape(@uriMatchData[2])
    @coll = Rack::Utils.unescape(@uriMatchData[3])
    @stat = Rack::Utils.unescape(@uriMatchData[4])
    return matchData
  end

  # @set @statsObj if stat is a supported stat
  def validateAndSetupStats(stat=@stat)
    if(SUPPORTED_STATS.include?(@stat.to_sym))
      initStatus = initGroupAndKb()
      unless((200..299).include?(HTTP_STATUS_NAMES[initStatus]))
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end
      @statsObj = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @coll)
    else
      msg = "Unsupported stat #{@stat.inspect}; please choose one of the following statistics provided with description:\n"
      SUPPORTED_STATS.each { |stat|
        msg << "#{stat}:  #{STAT_DESCRIPTIONS[stat]}\n"
      }
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
    end
    return @statsObj
  end
end
end; end; end
