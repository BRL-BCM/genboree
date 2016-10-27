#!/usr/bin/env ruby

require "json"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/trackEntity"
require "brl/genboree/rest/resources/tracks"

#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # TrackBuilder
  #   This class is based on the +BRL::Genboree::REST::Data::Builders::Builder+
  #   superclass in order to implement a concrete resource that can be used to
  #   implement the Query API for track lists.
  class TracksBuilder < Builder
    include BRL::Genboree::REST::Helpers

    PRIMARY_TABLE = "ftype"

    PRIMARY_ID = "ftypeid"

    SECONDARY_TABLES = {"gclass"=> "ftype2gclass.gid=gclass.gid", "ftype2gclass"=>"p.ftypeid=ftype2gclass.ftypeid"}

    AVP_TABLES = { "names" => "ftypeAttrNames", "values" => "ftypeAttrValues", "join" => "ftype2attributes" }

    CORE_FIELDS = { "primary"=>[ "fmethod", "fsource", "ftypeid" ], "gclass"=>["gclass"] }

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES =  [{"fmethod" => "Type"}, {"fsource" => "Subtype"}, {"url" => "URL"}, {"urlLabel" => "URL Label"}, {"description" => "Description"},{"gclass"=>"Class"}]

    RESPONSE_FORMAT = "tabbed"

    def initialize(url)
      matches = self.class::pattern().match(url)
      @refBase = "/REST/v1/grp/#{matches[1]}/db/#{matches[2]}/trk"
    end


    # Builds a text entity list of tracks names returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TextEntityList of track names
    def buildTextEntities(dbu, dbRows, refBase)
      list = BRL::Genboree::REST::Data::TextEntityList.new(true)
      check = []
      dbRows.each{ |db, row|
        trackName = "#{row['fmethod']}:#{row['fsource']}"

        dups = false
        list.each{ |txt| dups = (txt.text == trackName) }

        entity = BRL::Genboree::REST::Data::TextEntity.new(true,trackName)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(trackName)}")
        if(!dups)
          list << entity
          check << entity.text
        end
      }
      return list
    end

    # Builds a track entity list of tracks returned by the query,
    # making sure there are no duplicates.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query, filtered via the filterByPermissions method
    # [+refBase+] Base for making refs hash for each entity
    # [+returns+] A TrackEntityList of tracks
    def buildDataEntities(dbu, dbRows, refBase)
      oldDataDbName = dbu.dataDbName
      list = DetailedTrackEntityList.new(true)
      dbRows.each{|tname, hash|
        dbName = hash['dbNames'].first['dbName']
        dbu.setNewDataDb(dbName)
        attrs = dbu.selectFeatureurlByFtypeId(hash['ftypeid'])
        if(attrs.length > 0)
          attrs = attrs[0]
          desc, url, urlLabel = attrs['description'],attrs['url'],attrs['urlLabel']
        else
          desc, url, urlLabel = nil
        end
        entity = BRL::Genboree::REST::Data::DetailedTrackEntity.new(@connect, tname, desc, url, urlLabel)
        entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
        dbRecs = [ DbRec.new(dbName, hash['ftypeid']) ]

        # Build our classes array (circumventing the overly complicated and
        # unfortunately integrated "makeClassesListEntity" in helpers.rb)
        entity.classes = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
        ftype2gclassNamesRows = dbu.selectAllFtypeClasses(hash['ftypeid'])
        ftype2gclassNamesRows.each { |row|
          entity.classes << BRL::Genboree::REST::Data::TextEntity.new(@connect, row['gclass'])
        }
        list << entity
      }
      # Reset the database
      dbu.setNewDataDb(oldDataDbName) unless(dbu.dataDbName == oldDataDbName)
      # Send back the full list
      return list
    end

    # This method filters tracks based on the user's permissions in the database.
    # [+dbu+] A usable instance of dbu
    # [+dbRows+] Set of rows returned by the query
    # [+userId+] Login of the user making the query
    # [+returns+] Appropriate db rows
    def filterByPermissions(dbu, dbRows, userId)
      # Loop through tracks, get database names
      oldDataDbName = dbu.dataDbName
      dbNames = []
      dbRows.each{|key, row|
        row['dbNames'].each{|struct|
          if(dbNames.include?(struct[:dbName])==false)
            dbNames << struct[:dbName]
          end
        }
      }
      accessibleTracks = {}
      dbNames.each{|dbName|
        refSeqRows = dbu.selectRefseqByDatabaseName(dbName)
        dbRefSeqId = refSeqRows.first['refSeqId']
        refSeqRows.clear()
        dbu.setNewDataDb(dbName)
        trackIds = GenboreeDBHelper.getAccessibleTrackIds(dbRefSeqId,userId,true,dbu)
        accessibleTracks[dbName] = trackIds.to_hash
      }
      delRows = []
      dbRows.each{|name, row|
        row['dbNames'].delete_if{|rec|
          !accessibleTracks[rec['dbName']].key?(rec['ftypeid'])
        }

        if(row['dbNames'].length == 0)
          delRows << name
        end
      }

      delRows.each{|key| dbRows.delete(key)}

      dbu.setNewDataDb(oldDataDbName) unless(dbu.dataDbName == oldDataDbName)
      return dbRows
    end


    # Helper method for making Track names
    # [+dbRow+] The database row you want a name from
    # [+returns+] Nil if the row is nil, fmethod:fsource format track name otherwise
    def getName(dbRow)
      return nil if(dbRow.nil?)

      return "#{dbRow['fmethod']}:#{dbRow['fsource']}"
    end

    def self.pattern()
      return BRL::REST::Resources::Tracks.pattern()
    end
  end # class TracksBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
