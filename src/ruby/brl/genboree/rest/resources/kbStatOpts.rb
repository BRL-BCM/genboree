require 'brl/genboree/rest/resources/kbStat'
require 'brl/genboree/rest/data/rawDataEntity'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/stats/kbStats'

module BRL; module REST; module Resources
class KbStatOpts < BRL::REST::Resources::KbStat
  HTTP_METHODS = { :get => true }
  RSRC_TYPE = 'kbStatOpts'

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/stat/([^/\?]+)/opts}
  end

  def self.priority()
    return 6 # higher than kbStat
  end

  # @return [Hash] Mapping option name to its default and a description
  def get
    initStatus = initOperation
    hashData = {}
    optsWithDefault = @statsObj.options(@stat.to_sym)
    optsWithDefault.each_key { |opt|
      hashData[opt] = {}
      hashData[opt][:default] = optsWithDefault[opt]
      hashData[opt][:description] = OPTION_DESCRIPTIONS[opt]
    }
    rawDataEntity = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, hashData)
    rawDataEntity.msg = @statsObj.warnings.join("\n") unless(@statsObj.warnings.empty?)
    configResponse(rawDataEntity)
    @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
    return @resp
  end

end
end; end; end
