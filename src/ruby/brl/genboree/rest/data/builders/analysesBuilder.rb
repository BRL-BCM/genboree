#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/analysis"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/analysisEntity"
require "brl/genboree/rest/resources/analyses"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # AnalysesBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for analysis lists.
  class AnalysesBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::Analysis

    PRIMARY_TABLE = "analyses"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "analysisAttrNames", "values" => "analysisAttrValues", "join" => "analysis2attributes" }

    CORE_FIELDS = { "primary"=>[ "name", "type", "dataLevel", "experiment_id", "state" ]}

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true
    
    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names 
    DISPLAY_NAMES = [{"name" => "Name"}, {"state" => "State"}, {"type"=> "Type"}, {"dataLevel" => "Data Level"}, {"experiment_id" => "Experiement ID"}]
    
    # RESPONSE_FORMAT: Constant to provide the response format meta-data for this resource
    RESPONSE_FORMAT = "tabbed"

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/analysis"
    end

    # Builds a text entity list of analysis names returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of analysis names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)

      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}
      entNames.each{ |analysisName|
        
        dups = false
        list.each{ |txt| dups = (txt.text == analysisName) }
        
        entity = BRL::Genboree::REST::Data::TextEntity.new(true,analysisName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(analysisName)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a analysis entity list of analyses returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A Analysis/gEntityList of analysiss
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = AnalysisEntityList.new(true)
      
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}

      entNames.each{|analysisName|
        hash = dbRows[analysisName]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
       
        name, type, dataLevel, state = hash["name"], hash["type"], hash["dataLevel"], hash["state"]
        avpHash = getAvpHash(dbu,hash['id'])
        
        entity = BRL::Genboree::REST::Data::AnalysisEntity.new(true, name, type, dataLevel, '', state, avpHash )
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(analysisName)}")
        
        experimentRow = dbu.selectExperimentById(hash['experiment_id']) unless(hash['experiment_id'].nil?)
        entity.experiment = experimentRow.first['name'] if(experimentRow and experimentRow.first)
        experimentRow.clear() unless(experimentRow.nil?)        

        dups = false
        list.each{ |ent| dups = (ent.name == analysisName) } 
        if(!dups)
          list << entity
        end
      }
      # Reset the database
      dbu.setNewDataDb(oldDataDbName) unless(dbu.dataDbName == oldDataDbName)
      # Send back the full list
      return list
    end

    def self.pattern()
      return BRL::REST::Resources::Analyses.pattern()
    end
  end # class TrackBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
