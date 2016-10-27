#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Hub  - this module defines helper methods related to UCSC Track Hubs, intended to be used as a mix-in
  module Hub

    # Transform hash data to stanza format
    # @note NOTE return string will be prefixed with newline
    def hashToStanza(hash)
      retVal = ''
      hash.each_key{|key|
        retVal << "\n#{key.to_s} #{hash[key].to_s}"
      }
      return retVal
    end

    # Parse stanza for multiple sets of attribute/value pairs
    # @param data [String] stanza data to parse
    # @return dataMap [Array<Hash>] array of hash mapping of stanza data fields to their values
    def parseStanzaData(data)
      retVal = []
      dataMap = {}
      data.toUnix()
      data.each_line{|line|
        line.lstrip! # dont #strip! bc maybe empty string as values
        if(line !~ /\S+/)
          # any middle-of-data blank lines indicate a new set of attribute/value pairs
          unless(dataMap.empty? or dataMap.nil?)
            retVal << dataMap.dup()
          end
          dataMap = {}
        else
          firstSpaceIndex = line.index(/\s+/)
          unless(firstSpaceIndex.nil?)
            fieldName = line[0...firstSpaceIndex].to_sym()
            fieldValue = line[firstSpaceIndex+1..-1]
            dataMap[fieldName] = fieldValue.strip
          else
            msg = "The data you provided is not in UCSC's stanza format\n"\
                  "Refer to the track hub documentation at "\
                  "https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html "\
                  "for more information"
            err = BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", msg)
            raise err
          end
        end
      }
      retVal << dataMap unless(dataMap.empty?)
      return retVal
    end

    # Parse stanza data for a singular entity type
    # @see #parseStanzaDataForEntities
    def parseStanzaDataForEntity(data, entity)
      entities = parseStanzaDataForEntities(data, entity)
      return entities.first
    end

    # Parse stanza data for BRL data entities
    # @param data [String] stanza data to parse
    # @param entity [Class] entity must define SIMPLE_FIELD_NAMES constant which is used to search stanza AVPs
    # @note NOTE field names are case sensitive
    def parseStanzaDataForEntities(data, entity)
      retVal = []
      # inverse of UCSC_FIELD_MAP
      # used for entity constructor field order
      gbFieldMap = {}
      entity::UCSC_FIELD_MAP.each_key{|kk|
        vv = entity::UCSC_FIELD_MAP[kk]
        gbFieldMap[vv] = kk
      }

      # parse data for expected fields
      dataMapArray = parseStanzaData(data)

      # determine if required fields are present in data
      requiredFields = entity::UCSC_FIELD_MAP
      dataMapArray.each{|dataMap|

        hasRequiredFields = true
        requiredFields.each_key{|field|
          hasRequiredFields = (hasRequiredFields and dataMap.key?(field.to_sym))
        }

        gbFields = {}
        dataMap.each_key{|kk|
          gbField = entity::UCSC_FIELD_MAP[kk.to_s]
          gbFields[gbField] = dataMap[kk]
        }

        # return a list of entities if required fields are present
        if(hasRequiredFields)
          entityObj = entity.from_json(gbFields)
          retVal << entityObj
        else
          msg = "The data you provided #{dataMap.keys().inspect} is missing one or more required fields "\
                "#{requiredFields.inspect}.\nIf you have provided all required fields, most likely it does not "\
                "match UCSC's stanza format available at https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html"
          err = BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", msg)
          raise err
        end
      }
      return retVal
    end

    # Create hubTrack from database query result set
    # @param hubTrackRecs [Array<Hash>] rows of column names mapped to their values
    # @return entities [Array<Hash>] (JSON) representation of records in hubTrackRecs
    def hubTrackRecordsToEntityList(hubTrackRecs)
      entities = []

      # relate database columns to entity variable names where there is a straight-forward mapping
      colVarMap = {
        "trkKey" => "track",
        "shortLabel" => "shortLabel",
        "longLabel" => "longLabel",
        "type" => "type"
      }

      entityHashTemplate = {
        "track" => "",
        "shortLabel" => "",
        "longLabel" => "",
        "type" => "",
        "bigDataUrl" => ""
      }

      hubTrackRecs.each{|rec|
        entityHash = entityHashTemplate.dup()

        # perform straight-foward mapping
        colVarMap.each_key{|kk|
          entityHash[colVarMap[kk]] = rec[kk]
        }

        # get remaining template fields 
        if(rec['dataUrl'].nil?)
          # then we are not overriding trkUrl, use it
          entityHash["bigDataUrl"] = rec['trkUrl']
        else
          # otherwise, use the override
          entityHash["bigDataUrl"] = rec['dataUrl']
        end
        entities << entityHash
      }

      return entities
    end

    # Create detailed=hubSummary hubGenomes from database query result set
    # @param hubGenomeRecs [Array<Hash>] row of column names obtained from a simple query on hubGenomes table
    # @return entities [Array<Hash>] (JSON) representation of records from hubGenomeRecs
    # @note currently does not support nonstandard genomes
    # @note inclusion of this method here may pollute path/to/data/hubTrack.rb
    def hubGenomeRecordsToEntityList(hubGenomeRecs)
      entities = [] 

      colVarMap = {
        "genome" => "genome"
      }

      entityHashTemplate = {
        "genome" => "",
        "trackDb" => ""
      }

      hubGenomeRecs.each{|rec|
        entityHash = entityHashTemplate.dup()

        # perform straight-forward mapping
        colVarMap.each_key{|kk|
          entityHash[colVarMap[kk]] = rec[kk]
        }

        # add remaining fields defined in template
        entityHash['trackDb'] = "#{entityHash['genome']}/trackDb.txt"

        entities << entityHash
      }

      return entities
    end

    # Create detailed=true hubGenomes from database query result set
    # @param hubGenomeAndTrackRecs [Array<Hash>] column names mapped to their values obtained from a join hubGenomes and hubTracks tables
    #   possibly from multiple hubGenomes
    # @return entities [Array<Hash>] (JSON) representation of records from hubGenomeRecs
    # @note currently does not support nonstandard genomes
    # @note inclusion of this method here may pollute path/to/data/hubTrack.rb
    def hubGenomeJoinRecordsToFullEntityList(hubGenomeAndTrackRecs)
      entities = [] 
      entityHashTemplate = {
        "genome" => "",
        "trackDb" => "",
        "tracks" => []
      }

      # map genomes to their associated entity because hubGenomeAndTrackRecs may have records from multiple different genomes
      genomeEntityMap = {} 

      hubGenomeAndTrackRecs.each{|rec|
        # get the hubSummary data for genome
        summaryHash = hubGenomeRecordsToEntityList([rec]).first

        # add it to the entity if it hasnt been done already
        genome = summaryHash['genome']
        genomeFullEntity = genomeEntityMap[genome]
        if(genomeFullEntity.nil?)
          genomeFullEntity = deepCopy(entityHashTemplate)
          genomeFullEntity.merge!(summaryHash)
          genomeEntityMap[genome] = genomeFullEntity
        end

        # get the track data and add it to existing entity
        trackHash = hubTrackRecordsToEntityList([rec]).first
        genomeEntityMap[genome]['tracks'] << trackHash
      }

      # transform genomeEntityMap into our json representation
      genomeEntityMap.each_key{|genome|
        entity = genomeEntityMap[genome]
        entities << entity
      }

      return entities
    end

    # Create detailed=hubSummary hub entity from database query result
    # @param [Array<Hash>] hubRecs column names mapped to their values obtained from hubs table
    # @return [Array<Hash>] entities (JSON) representation of records from hubRecs
    # @note this is no longer needed since the database representation matches the entity representation
    def hubRecordsToEntityList(hubRecs)
      return hubRecs
    end

    # Create detailed=true hub entity from database query result on hubs table
    # use hub_id from hubRecs to query hubGenomes, and similarly use hubGenome_id to query hubTracks
    # @param hubRecs [Array<Hash>] column names mapped to their values obtained from hubs table
    # @param dbu [BRL::Genboree::DBUtil] database connection object already connected to main Genboree database
    # @return entities [Array<Hash>] (JSON) representation of records from hubRecs
    # @note inclusion of this method here needlessly adds to the stack of path/to/data/hubTrack.rb and path/to/data/hubGenome.rb
    def hubRecordsToFullEntityList(hubRecs, dbu)
      entities = []

      hubRecs.each{|hubRec|
        entity = {}

        # add hub summary data to the entity
        # ensure all required fields are present and the extraneous fields are removed
        hubSummaryData = hubRec.dup()
        hubSummaryData.delete('id')
        hubSummaryData.delete('group_id')
        entity = entity.merge(hubSummaryData)

        # add genome summary data to the entity
        hubGenomeRecs = dbu.selectHubGenomesByHubId(hubRec['id'])
        unless(hubGenomeRecs.nil?)
          genome_idx = 0
          entity['genomes'] = []
          hubGenomeRecs.each{|genomeRec|
            # ensure all required fields are present and the extraneous fields are removed
            genomeSummaryData = genomeRec.dup()
            genomeSummaryData.delete('id')
            genomeSummaryData.delete('hub_id')
            entity['genomes'] << genomeSummaryData
  
            # add track summary data to the entity
            entity['genomes'][genome_idx]['tracks'] = []
            hubTrackRecs = dbu.selectHubTracksByHubGenomeId(genomeRec['id'])
            unless(hubTrackRecs.nil?)
              tracks = []
              hubTrackRecs.each{|trackRec|
                # ensure all required fields are present and the extraneous fields are removed
                trackSummaryData = trackRec.dup()
                trackSummaryData.delete('id')
                trackSummaryData.delete('hubGenome_id')
                tracks << trackSummaryData
              }
              entity['genomes'][genome_idx]['tracks'] = tracks
            else
              msg = "Unable to retrieve hub track records from database. Query returned nil as a result of an "\
                "unexpected error while retrieving data from the database"
              error = BRL::Genboree::GenboreeError.new(:"Internal Server Error", msg)
              raise error
            end
  
            genome_idx += 1
          }
        else
          msg = "Unable to retrieve hub genome records from database. Query returned nil as a result of an "\
                "unexpected error while retrieving data from the database"
          error = BRL::Genboree::GenboreeError.new(:"Internal Server Error", msg)
          raise error
        end

        entities << entity
      }

      return entities
    end

    # Create detailed=true hub entity from database join on hubs and hubGenomes and hubTracks tables
    # @param hubAndGenomeAndTrackRecs [Array<Hash>] column names mapped to their values obtained from join on hubs, 
    #   hubGenomes, and hubTracks tables
    # @return entities [Array<Hash>] (JSON) representation of records from hubAndGenomeAndTrackRecs
    # @note inclusion of this method here needlessly pollutes stack of path/to/data/hubTrack.rb and path/to/data/hubGenome.rb
    # @note hubAndGenomeAndTrackRecs must be from within the same group
    # @todo TODO unfinished - probably hubRecordsToFullEntityList is more db connections but less db operations
    def hubJoinRecordsToFullEntityList(hubAndGenomeAndTrackRecs)
      entities = []

      # convert genomes to array when finished
      entityHashTemplate = {
        "hub" => "",
        "genomesFile" => "",
        "shortLabel" => "",
        "longLabel" => "",
        "email" => "",
        "genomes" => {}
      }

      genomeHashTemplate = {
        "genome" => "",
        "trackDb" => "",
        "tracks" => []
      }

      # map hubs to their associated entity because hubAndGenomeAndTrackRecs may have records from multiple different hubs
      hubToGenomeToEntityMap = {} 

      hubAndGenomeAndTrackRecs.each{|rec|
        # get the hubSummary data for hub and add it to the entity if not already done
        hubSummaryHash = hubRecordsToEntityList([rec]).first
        hub = hubSummaryHash['hub']
        if(hubToGenomeToEntityMap[hub].nil?)
          hubToGenomeToEntityMap[hub] = deepCopy(entityHashTemplate)
          hubToGenomeToEntityMap[hub].merge(summaryHash)
        end

        # get the hubSummary data for genome and add it to the entity if not already done
        genomeHash = hubGenomeRecordsToEntityList([rec]).first
        genome = genomeHash['genome']
        genomeEntity = hubToGenomeToEntityMap[hub]['genomes'][genome]
        if(genomeEntity.nil?)
          genomeEntity = deepCopy(genomeHashTemplate)
          genomeEntity.merge(genomeHash)
        end

        # get the data for track and add it to the entity (will not be done because no duplicate tracks)
        trackHash = hubTrackRecordsToEntityList([rec]).first
        track = trackHash['track']
        hubToGenomeToEntityMap[hub]['genomes'][genome]['tracks'] << track
      }

      # transform genomes from hash to array as required by our representation
      hubToGenomeToEntityMap.each_key{|hub|
        genomesHash = hubToGenomeToEntityMap[hub]['genomes']
        genomesArray = hashToArray(genomesHash)
        hubToGenomeToEntityMap[hub]['genomes'] = genomesArray
      }

      return entities
    end

    # Convert a hash of objects to an array of objects
    # Intended as a helper method for the association of tracks to genomes and genomes to hubs
    # @param hash [Hash<Object>]
    # @reutrn array [Array<Object>]
    def hashToArray(hash)
      array = []
      hash.each_key{|kk|
        array << hash[kk]
      }
      return array
    end
    
    # Copy/Dup for even nested objects
    # @param obj [Object] any object that can be serialized by Marshal
    # @return [Object] a copy of obj
    def deepCopy(obj)
      return Marshal.load(Marshal.dump(obj))
    end

  end
end ; end ; end ; end
