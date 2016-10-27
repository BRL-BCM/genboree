
#!/usr/bin/env ruby

require "brl/util/util"
require "brl/genboree/genboreeUtil"
require "brl/genboree/rest/apiCaller"
require "brl/db/dbrc"

module BRL ; module Genboree ;
  class GeneElementExtractor
    def self.extractGeneElements(geneName, trackName)
      genbConf = BRL::Genboree::GenboreeConfig.load()
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      dbrc = suDbDbrc
      dbrc.user = dbrc.user.dup.untaint
      dbrc.password = dbrc.password.dup.untaint
      apiCaller = BRL::Genboree::REST::ApiCaller.new("genboree.org",
      "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction=avg&nameFilter={name}&emptyScoreValue={esValue}",
      dbrc.user,
      dbrc.password)
      apiCaller.get(
      {
        :grp => CGI.escape("raghuram_group"),
        :db => CGI.escape("hg18-raghuram"),
        :trk => "GeneModel:GeneRefSeq",
        :scrTrack => "http://genboree.org/REST/v1/grp/#{CGI.escape("Epigenomics Roadmap Repository")}/db/#{CGI.escape("Data Freeze 1 - Full Repo")}/trk/#{trackName}",
        :name => geneName,
        :esValue => 0
      }
      )
      if(apiCaller.succeeded?)
        return apiCaller.respBody
      else
        return nil
      end
      
    end

  end
end; end;
