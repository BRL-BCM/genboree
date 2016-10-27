#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/bioSample"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/bioSampleEntity"
require "brl/genboree/rest/resources/bioSamples"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # TrackBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for bioSample lists.
  class BioSamplesBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::BioSample

    PRIMARY_TABLE = "bioSamples"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "bioSampleAttrNames", "values" => "bioSampleAttrValues", "join" => "bioSample2attributes" }

    CORE_FIELDS = { "primary"=>[ "id", "name", "state", "type", "biomaterialState", "biomaterialProvider", "biomaterialSource" ]}
    
    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"name" => "Name"}, {"state" => "State"}, {"type"=> "Type"}, {"bioMaterialState" => "Biomaterial State"}, {"biomaterialProvider" => "Biomaterial Provider"}, {"biomaterialSource" => "Biomaterial Source"}]

    RESPONSE_FORMAT = "tabbed"
          
    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/bioSample"
    end

    # Builds a text entity list of sample names returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of bioSample names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}

      entNames.each{ |sampleName|

        dups = false
        list.each{ |txt| dups = (txt.text == sampleName) }
        
        entity = BRL::Genboree::REST::Data::TextEntity.new(true,sampleName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(sampleName)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a sample entity list of biosamples returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A BioSampleEntityList of bioSamples
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = BioSampleEntityList.new(true)
      entNames = dbRows.keys
      entNames.sort!{|aa,bb| aa.downcase <=> bb.downcase}

      entNames.each{|sampleName|
        hash = dbRows[sampleName]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
        name, type, bioMaterialState = hash['name'], hash['type'], hash['biomaterialState']
        bioMaterialProvider, bioMaterialSource, state = hash['biomaterialProvider'], hash['biomaterialSource'], hash['state']
        
        avpHash = getAvpHash(dbu,hash['id'])
         
        entity = BRL::Genboree::REST::Data::BioSampleEntity.new(true, name, type, bioMaterialState, bioMaterialProvider, bioMaterialSource, state, avpHash)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(sampleName)}")
        dups = false
        list.each{ |ent| dups = (ent.name == sampleName) } 
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
      return BRL::REST::Resources::BioSamples.pattern()
    end
  end # class BioSamplesBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
