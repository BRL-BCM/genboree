#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/experiment"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/experimentEntity"
require "brl/genboree/rest/resources/experiments"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # ExperimentsBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for experiment lists.
  class ExperimentsBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::Experiment

    PRIMARY_TABLE = "experiments"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "experimentAttrNames", "values" => "experimentAttrValues", "join" => "experiment2attributes" }

    CORE_FIELDS = { "primary"=>[ "name", "type", "study_id", "bioSample_id", "state" ]}

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"name" => "Name"}, {"state" => "State"}, {"type"=> "Type"}, {"study_id" => "Study ID"}, {"bioSample_id" => "BioSample ID"}]

    RESPONSE_FORMAT = "tabbed"

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/experiment"
    end

    # Builds a text entity list of experiment names returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of experiment names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)
      
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}
 
      entNames.each{ |experimentName|
        
        dups = false
        list.each{ |txt| dups = (txt.text == experimentName) }
        
        entity = BRL::Genboree::REST::Data::TextEntity.new(true,experimentName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(experimentName)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a experiment entity list of experiments returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A ExperimentEntityList of experiments
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = ExperimentEntityList.new(true)
      
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}

      entNames.each{|experimentName|
        hash = dbRows[exerimentName]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
       
        name, type, state = hash['name'], hash['type'], hash['state']
        avpHash = getAvpHash(dbu,hash['id'])
        
        entity = BRL::Genboree::REST::Data::ExperimentEntity.new(true, name, type, '', '', state, avpHash )
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(experimentName)}")
        
        studyRow = dbu.selectStudyById(hash['study_id']) unless(hash['study_id'].nil?)
        entity.study = studyRow.first['name'] if(studyRow and studyRow.first)
        bioSampleRow = dbu.selectBioSampleById(hash['bioSample_id']) unless(hash['bioSample_id'].nil?)
        entity.bioSample = bioSampleRow.first['name'] if(bioSampleRow and bioSampleRow.first)

        dups = false
        list.each{ |ent| dups = (ent.name == experimentName) } 
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
      return BRL::REST::Resources::Experiments.pattern()
    end
  end # class TrackBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
