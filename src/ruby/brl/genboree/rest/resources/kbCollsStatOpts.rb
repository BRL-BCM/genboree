require 'brl/genboree/rest/resources/kbStatOpts'

module BRL; module REST; module Resources
class KbCollsStatOpts < KbStatOpts
  RSRC_TYPE = 'kbCollsStatOpts'

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/colls/stat/([^/\?]+)/opts}
  end

  def self.priority()
    return 7 # higher than kbCollsStat
  end
end
end; end; end
