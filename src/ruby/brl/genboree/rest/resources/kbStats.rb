require 'brl/genboree/rest/resources/kb'
require 'brl/genboree/kb/stats/kbStats'
require 'brl/genboree/rest/data/rawDataEntity'

module BRL ; module REST ; module Resources
  class KbStats < Kb
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbStats'

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/stats}
    end

    def self.priority()
      return 5 # higher than kb
    end

    # Describe available statistics for a KB
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        rawDataEntity = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, BRL::Genboree::KB::Stats::KbStats::STAT_DESCRIPTIONS)
        configResponse(rawDataEntity)
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end # class Kb < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
