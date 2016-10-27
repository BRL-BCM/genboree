require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Hub-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: hubTracks
  # --------
  # NOTE: the hubTracks entity table is called "hubTracks"
  # Methods below are for uniform method consistency and any AVP-related functionality

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all HubTracks records
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubTracks()
    return countRecords(:mainDB, 'hubTracks', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Count all HubTracks within a given hubGenome, identified by hubGenomeId
  # @param [Fixnum] hubGenomeId The id of the group.
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubTracksByHubGenomeId(hubGenomeId)
    return countByFieldAndValue(:mainDB, 'hubTracks', 'hubGenome_id', hubGenomeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all HubTracks records
  # @return [Array<Hash>] Result set - Rows with the hub records
  def selectAllHubTracks()
    return selectAll(:mainDB, 'hubTracks', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubTrack record by its id
  # @param [Fixnum] id ID of the hub record to return
  # @return [Array<Hash>] Result set - 0 or 1 hubTracks record rows
  def selectHubTrackById(id)
    return selectByFieldAndValue(:mainDB, 'hubTracks', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubTracks records using a list of ids
  # @param [Array<Fixnum>] ids The list of hub record IDs
  # @return [Array<Hash>] Result set - 0+ hubTracks records
  def selectHubTracksByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'hubTracks', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubTracks records for a hub using the hub's ID
  # @param [Fixnum] groupid The id of the group.
  # @return [Array<Hash>] Result set - 0+ hubTracks record
  def selectHubTracksByHubGenomeId(hubGenomeId)
    return selectByFieldAndValue(:mainDB, 'hubTracks', 'hubGenome_id', hubGenomeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubTracks using a list of hubGenomeIds
  # @param [Array<Fixnum>] Array of hubGenomeIds
  # @return [Array<Hash>] Result set - 0+ hubTracks record
  def selectHubTracksByHubGenomeIds(hubGenomeIds)
    return selectByFieldWithMultipleValues(:mainDB, 'hubTracks', 'hubGenome_id', hubGenomeIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubTrack by the unique trkKey string within the hubGenome identified by hubGenomeId
  # @param [String] trkKey The unique trkKey
  # @param [Fixnum] hubGenomeId The id of the hub containing a genome of that name
  # @return [Array<Hash>] Result set - 0 or 1 hub records
  def selectHubTrackByTrackAndHubGenomeId(trkKey, hubGenomeId)
    return selectByMultipleFieldsAndValues(:mainDB, 'hubTracks', { 'trkKey' => trkKey, 'hubGenome_id' => hubGenomeId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new HubTrack record.
  # @param [Fixnum] hubGenomeId The id of the hubGenome the track is in.
  # @param [String] trkKey  The unique trkKey for the track. Must use a-zA-Z0-9_, and first character must be a letter. UCSC rules.
  # @param [String] type One of UCSC's known track type strings. Currently: @bigWig@, @bigBed@, @bam@, @vcfTabix@
  # @param [String] trkUrl The full URL to the track.
  #   Track metadata will come from here and the bigDataUrl in that metadata will be handed to UCSC when asked
  #   UNLESS dataUrl is a non-empty/non-nil URL, in which case that will be given to UCSC for bigDataUrl instead.
  # @param [String] shortLabel The hub's shortLabel. No longer than 17 chars. Must be unique within the group.
  # @param [String] longLabel The hub's longLabel or description. Generally 1 sentence/line; 80 chars recommended by UCSC.
  # @param [String] dataUrl A full URL to the bigData for the track if different than what is returned by trkUrl (i.e. an override).
  #   URL *must* match @type@!
  # @param [Fixnum] parent_id id of hubTrack that is parent of this one; may be a "group" or some kind of aggregate track; null if none
  # @param [String] aggTrack if this is an aggregate track--i.e. some kind of multiwindow & parent that will have child hubTrack recs--put aggregate info here
  # @return [Fixnum] Number of rows inserted
  def insertHubTrack(hubGenomeId, trkKey, type, trkUrl, shortLabel, longLabel, dataUrl=nil, parent_id=nil, aggTrack=nil)
    data = [ hubGenomeId, trkKey, type, parent_id, aggTrack, trkUrl, dataUrl, shortLabel, longLabel ]
    return insertHubTracks(data, 1)
  end

  # Insert multiple HubTracks records using column data.
  # @see insertHub
  # @param [Array, Array<Array>] data An Array of values to use for hubGenomeId, name, state (in that order!)
  #   The Array may be 2-D (i.e. N rows of 6 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numHubTracks Number of hubTracks to insert using values in @data@.
  #   This is required because the data array may be flat and yet have the dynamic field values for many HubTracks.
  # @return [Fixnum] Number of rows inserted
  def insertHubTracks(data, numHubTracks)
    return insertRecords(:mainDB, 'hubTracks', data, true, numHubTracks, 9, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a HubTrack record using its id.
  # @param [Fixnum] id   The hubTracks.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubTrackById(id)
    return deleteByFieldAndValue(:mainDB, 'hubTracks', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete HubTracks using their ids.
  # @param [Array<Fixnum>] ids      Array of hubTracks.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubTracksByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'hubTracks', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a HubTrack record using its unique trkKey name within the genome identified by hubGenomeId
  # @param [String] trkKey  The unique trkKey for the track to delete. Must use a-zA-Z0-9_, and first character must be a letter. UCSC rules.
  # @param [Fixnum] hubGenomeId  The id of the hubGenome in which track lives
  # @return [Fixnum]  Number of rows deleted
  def deleteHubTrackByNameAndHubGenomeId(trkKey, hubGenomeId)
    whereCriteria = { 'genome' => genome, 'hubGenome_id' => hubGenomeId }
    return deleteByMultipleFieldsAndValues(:mainDB, 'hubTracks', whereCriteria, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete all the hubTracks in a hubgenome identified by hubGenomeId
  # @param [Fixnum] hubGenomeId  The id of the hubgenome from which to delete all tracks
  # @return [Fixnum]  Number of rows deleted
  def deleteAllHubTracksByHubGenomeId(hubGenomeId)
    return deleteByFieldAndValue(:mainDB, 'hubTracks', 'hubGenome_id', hubGenomeId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a Hub Track record identified by its id
  # @param [Fixnum] id row id to update
  # @param [Hash] cols2vals map columns-to-update to their new values identified by id
  #   with the following optional fields 
  #   [Fixnum] hubGenome_id new value of hubGenome_id for row
  #   [String] trkKey new value of trkKey for row
  #   [String] type new value of type for row
  #   [Fixnum] parent_id new value of parent_id for row
  #   [String] aggTrack new value of aggTrack for row
  #   [String] trkUrl new value of trkUrl for row
  #   [String] dataUrl new value of dataUrl for row
  #   [String] shortLabel new value of shortLabel for row 
  #   [String] longLabel new value of longLabel for row
  # @return [Fixnum] Number of rows updated
  def updateHubTrackById(id, cols2vals)
    return updateColumnsByFieldAndValue(:mainDB, 'hubTracks', cols2vals, 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
