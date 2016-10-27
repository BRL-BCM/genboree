#!/usr/bin/env ruby

require "json"
require "brl/genboree/abstract/resources/publication"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/publicationEntity"
require "brl/genboree/rest/resources/publications"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # TrackBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for publication lists.
  class PublicationsBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::Abstract::Resources::Publication

    PRIMARY_TABLE = "publications"

    PRIMARY_ID = "id"

    SECONDARY_TABLES = nil

    AVP_TABLES = { "names" => "publicationAttrNames", "values" => "publicationAttrValues", "join" => "publication2attributes" }

    CORE_FIELDS = { "primary"=>["id", "pmid", "type", "title", "authorList", "journal", "meeting", "date", "volume", "issue", "startPage", "endPage", "abstract", "meshHeaders", "url", "state", "language"  ]}

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"id" => "ID"}, {"pmid" => "PubMed ID"}, {"type" => "Type"}, {"title" => "Title"}, {"authorList" => "Author List"}, {"journal" => "Journal"}, {"meeting" => "Meeting"}, {"date" => "Date"}, {"volume" => "Volume"}, {"issue" => "Issue"}, {"startPage" => "Start Page"}, {"endPage" => "End Page"}, {"abstract" => "Abstract"}, {"meshHeaders" => "MESH Headers"}, {"url" => "URL"}, {"language" => "Language"}, {"state" => "State"}]

    RESPONSE_FORMAT = "tabbed"
    

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/publication"
    end

    # Builds a partial pub entity list of publications returned by the query, 
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A PartialPublicationEntityList of publication names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::PartialPublicationEntityList.new(true)
      entIds = dbRows.keys
      entIds.sort!
      entIds.each{ |publicationId|
        row = dbRows[publicationId] 
        dups = false
        list.each{ |ent| dups = (ent.id == publicationId) }
        entity = BRL::Genboree::REST::Data::PartialPublicationEntity.new(true,publicationId,row['type'],row['title'])
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(publicationId)}")
        if(!dups) 
          list << entity
        end
      }
      return list
    end

    # Builds a publication entity list of pubs returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A PublicationEntityList of publications
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = PublicationEntityList.new(true)
      
      entIds = dbRows.keys
      entIds.sort!
    
      entIds.each{|publicationId|
        hash = dbRows[publicationId]
        dbName = hash['dbNames'].first[:dbName]
        dbu.setNewDataDb(dbName)
        pmid, type, title, authorList = hash["pmid"], hash["type"], hash["title"], hash["authorList"]
        journal, meeting, date, volume, issue = hash["journal"], hash["meeting"], hash["date"], hash["volume"], hash["issue"]
        startPage, endPage, abstract, meshHeaders = hash["startPage"], hash["endPage"], hash["abstract"], hash["meshHeaders"]
        url, state, language = hash["url"], hash["state"], hash["language"]
         
        avpHash = getAvpHash(dbu,hash['id'])
         
        entity = BRL::Genboree::REST::Data::PublicationEntity.new(true, id, pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language, avpHash  )
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(publicationName)}")

        dups = false
        list.each{ |ent| dups = (ent.name == publicationName) } 
        if(!dups)
          list << entity
        end
      }
      # Reset the database
      dbu.setNewDataDb(oldDataDbName) unless(dbu.dataDbName == oldDataDbName)
      # Send back the full list
      return list
    end

    # Helper method for getting publication ids
    # [+dbRow+] The database row you want an id from
    # [+returns+] Nil if the row is nil, id otherwise
    def getName(dbRow)
      return dbRow['id']
    end
    
    def self.pattern()
      return BRL::REST::Resources::Publications.pattern()
    end
  end # class PublicationsBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
