require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/stats/kbStats'

module BRL; module REST; module Resources
class KbStat < BRL::REST::Resources::GenboreeResource
  HTTP_METHODS = { :get => true }
  RSRC_TYPE = 'kbStat'
  STAT_DESCRIPTIONS = BRL::Genboree::KB::Stats::KbStats::STAT_DESCRIPTIONS
  OPTION_DESCRIPTIONS = BRL::Genboree::KB::Stats::KbStats::OPTION_DESCRIPTIONS
  SUPPORTED_STATS = STAT_DESCRIPTIONS.keys()

  def cleanup()
    super()
    @groupId = @groupName = @groupDesc = nil
    @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = nil
    @statsObj = nil
  end

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/stat/([^/\?]+)}
  end

  def self.priority()
    return 5 # higher than kb
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      parseUri(@uriMatchData)
      validateAndSetupStats(@stat)
    end
    return initStatus
  end

  def parseUri(matchData=@uriMatchData)
    @groupName = Rack::Utils.unescape(matchData[1])
    @kbName = Rack::Utils.unescape(matchData[2])
    @stat = Rack::Utils.unescape(matchData[3])
    return matchData
  end

  # @set @statsObj if stat is a supported stat
  def validateAndSetupStats(stat=@stat)
    if(SUPPORTED_STATS.include?(@stat.to_sym))
      initStatus = initGroupAndKb()
      unless((200..299).include?(HTTP_STATUS_NAMES[initStatus]))
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end
      @statsObj = BRL::Genboree::KB::Stats::KbStats.new(@mongoKbDb)
    else
      msg = "Unsupported stat #{@stat.inspect}; please choose one of the following statistics provided with description:\n"
      SUPPORTED_STATS.each { |stat|
        msg << "#{stat}:  #{STAT_DESCRIPTIONS[stat]}\n"
      }
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
    end
    return @statsObj
  end

  # @return [BRL::Genboree::REST::Data::KbDocEntity, Hash] the statistic represented as a property-oriented KB doc
  #   or a http://www.highcharts.com config Hash
  def get(opts={})
    initStatus = initOperation
    OPTION_DESCRIPTIONS.keys.each { |opt|
      val = @nvPairs[opt.to_s]
      opts[opt] = val unless(val.nil?)
    }
    
    chart = /^hc/.match(opts[:format].to_s) ? true : false
    opts = mungeOpts(opts) # Used for overwriting default config
    data = nil
    begin
      data = @statsObj.send(@stat.to_sym, opts)
    rescue BRL::Genboree::KB::Stats::StatsError => err
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", err.message)
    end
    if(chart)
      # leave chart config as is, so override usual call to configResponse and fill in details ourselves
      @resp.status = HTTP_STATUS_NAMES[:OK]
      @resp.body = data.to_json
      @resp['Content-Length'] = @resp.body.size
    else
      # then wrap response
      propDocData = BRL::Genboree::KB::KbDoc.propDocFromHash(data, @stat)
      kbDocEntity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, propDocData)
      # @todo kbDocEntity.msg = @statsObj.warnings.join("\n") unless(@statsObj.warnings.empty?)
      configResponse(kbDocEntity)
    end
    @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
    return @resp
  end
  
  # @todo move to the place where all other option parsing and handling is done -- abstractStats
  def mungeOpts(opts)
    if (@stat == 'docCountOverTime' and (@nvPairs.key?('cumulative') and @nvPairs['cumulative'] =~ /true/))
      opts[:title] = "# Docs Over Time (cumulative)"
      opts[:yAxis] = "# Docs"
    elsif(@stat == 'docCount')
      opts[:title] = "# Docs Per Collection"
    elsif(@stat == 'lastNEditedDocs' and @nvPairs.key?('ndocs'))
      opts[:ndocs] = @nvPairs['ndocs'].to_i
    end
    return opts    
  end

end
end; end; end
