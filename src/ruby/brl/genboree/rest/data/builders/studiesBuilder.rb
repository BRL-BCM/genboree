#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/study"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/studyEntity"
require "brl/genboree/rest/resources/studies"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # StudiesBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for study  lists.
  class StudiesBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::Study

    PRIMARY_TABLE = "studies"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "studyAttrNames", "values" => "studyAttrValues", "join" => "study2attributes" }

    CORE_FIELDS = { "primary"=>[ "id", "name", "state", "type", "lab", "contributors" ]}

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"name" => "Name"}, {"state" => "State"}, {"type"=> "Type"}, {"lab" => "Lab"}, {"contributors" => "Contributors"}]

    RESPONSE_FORMAT = "tabbed"

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/study"
    end

    # Builds a text entity list of study names returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of study names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}
 
      entNames.each{ |studyName|
        dups = false
        list.each{ |txt| dups = (txt.text == studyName) }
        
        entity = BRL::Genboree::REST::Data::TextEntity.new(true,studyName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(studyName)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a study entity list of studies returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A StudyEntityList of studies
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = StudyEntityList.new(true)
      
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}

      entNames.each{|studyName|
        hash = dbRows[studyName]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
        name, type, state = hash['name'], hash['type'], hash['state']
        lab, contributors = hash['lab'], hash['contributors']
         
        avpHash = getAvpHash(dbu,hash['id'])
         
        entity = BRL::Genboree::REST::Data::StudyEntity.new(true, name, type, lab, contributors, state, avpHash )
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(studyName)}")

        dups = false
        list.each{ |ent| dups = (ent.name == studyName) } 
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
      return BRL::REST::Resources::Studies.pattern()
    end
  end # class StudiesBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
