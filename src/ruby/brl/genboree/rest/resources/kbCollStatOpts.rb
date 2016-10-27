require 'brl/genboree/rest/resources/kbStatOpts'

module BRL; module REST; module Resources
class KbCollStatOpts < KbStatOpts
  RSRC_TYPE = 'kbCollStatOpts'

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/stat/([^/\?]+)/opts}
  end

  def self.priority()
    return 7 # higher than kbCollStat
  end

  # override parent
  def parseUri(matchData=@uriMatchData)
    @groupName = Rack::Utils.unescape(@uriMatchData[1])
    @kbName = Rack::Utils.unescape(@uriMatchData[2])
    @coll = Rack::Utils.unescape(@uriMatchData[3])
    @stat = Rack::Utils.unescape(@uriMatchData[4])
    return matchData
  end
end
end; end; end
