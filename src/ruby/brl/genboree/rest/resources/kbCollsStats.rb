require 'brl/genboree/rest/resources/kbStats'

module BRL ; module REST ; module Resources
  class KbCollStats < KbStats
    RSRC_TYPE = 'kbCollsStats'

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/colls/stats}
    end

    def self.priority()
      return 6 # higher than kbCollections
    end

    # Describe available statistics for all collections in a KB
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        rawDataEntity = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, BRL::Genboree::KB::Stats::AllCollStats::STAT_DESCRIPTIONS)
        configResponse(rawDataEntity)
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end # class Kb < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
