#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/run"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/runEntity"
require "brl/genboree/rest/resources/runs"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # RunsBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for run lists.
  class RunsBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::Run

    PRIMARY_TABLE = "runs"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "runAttrNames", "values" => "runAttrValues", "join" => "run2attributes" }

    CORE_FIELDS = { "primary"=>[ "name", "type", "time", "performer", "location" , "experiment_id", "state" ]}

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"name" => "Name"}, {"state" => "State"}, {"type"=> "Type"}, {"time" => "Time"}, {"performer" => "Performer"}, {"location" => "Location"}, {"experiment_id" => "Experiment ID"}]

    RESPONSE_FORMAT = "tabbed"

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/run"
    end

    # Builds a text entity list of run names returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of run names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)
        
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}
      entNames.each{ |name|
        runName = name
        hash = dbRows[name]
        
        dups = false
        list.each{ |txt| dups = (txt.text == runName) }
        
        entity = BRL::Genboree::REST::Data::TextEntity.new(true,runName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(runName)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a run entity list of runs returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A RunEntityList of runs
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = RunEntityList.new(true)
      
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase} 
      
      entNames.each{|entName|
        hash = dbRows[entName]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
        runName = hash['name']
        name, type, time, performer, location, state = hash['name'], hash['type'], hash['time'], hash['performer'], hash['location'], hash['state']
        avpHash = getAvpHash(dbu,hash['id'])
        
        entity = BRL::Genboree::REST::Data::RunEntity.new(true,name, type, time, performer, location, '', state, avpHash )
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(runName)}")
        
        experimentRow = dbu.selectExperimentById(hash['experiment_id']) unless(hash['experiment_id'].nil?)
        entity.experiment = experimentRow.first['name'] if(experimentRow and experimentRow.first)

        dups = false
        list.each{ |ent| dups = (ent.name == runName) } 
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
      return BRL::REST::Resources::Runs.pattern()
    end
  end # class RunsBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
