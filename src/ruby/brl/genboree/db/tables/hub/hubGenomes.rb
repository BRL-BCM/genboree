require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# DATABASE RELATED TABLES - DBUtil Extension Methods for dealing with Hub-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: hubGenomes
  # --------
  # NOTE: the hubGenomes entity table is called "hubGenomes"
  # Methods below are for uniform method consistency and any AVP-related functionality

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all HubGenomes records
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubGenomes()
    return countRecords(:mainDB, 'hubGenomes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Count all HubGenomes within a given hub, identified by hubId
  # @param [Fixnum] hubId The id of the group.
  # @return [Array<Hash>] Result set - with a row containing the count.
  def countHubGenomesByHubId(hubId)
    return countByFieldAndValue(:mainDB, 'hubGenomes', 'hub_id', hubId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all HubGenomes records
  # @return [Array<Hash>] Result set - Rows with the hub records
  def selectAllHubGenomes()
    return selectAll(:mainDB, 'hubGenomes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubGenome record by its id
  # @param [Fixnum] id ID of the hub record to return
  # @return [Array<Hash>] Result set - 0 or 1 hubGenomes record rows
  def selectHubGenomeById(id)
    return selectByFieldAndValue(:mainDB, 'hubGenomes', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubGenomes records using a list of ids
  # @param [Array<Fixnum>] ids The list of hub record IDs
  # @return [Array<Hash>] Result set - 0+ hubGenomes records
  def selectHubGenomesByIds(ids)
    return selectByFieldWithMultipleValues(:mainDB, 'hubGenomes', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubGenomes records for a hub using the hub's ID
  # @param [Fixnum] groupid The id of the group.
  # @return [Array<Hash>] Result set - 0+ hubGenomes record
  def selectHubGenomesByHubId(hubId)
    return selectByFieldAndValue(:mainDB, 'hubGenomes', 'hub_id', hubId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubGenomes using a list of hubIds
  # @param [Array<Fixnum>] Array of hubIds
  # @return [Array<Hash>] Result set - 0+ hubGenomes record
  def selectHubGenomesByHubIds(hubIds)
    return selectByFieldWithMultipleValues(:mainDB, 'hubGenomes', 'hub_id', hubIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get HubGenome by the unique genome string within the hub identified by hubId
  # @param [String] genome The name of the genome
  # @param [Fixnum] hubId The id of the hub containing a genome of that name
  # @return [Array<Hash>] Result set - 0 or 1 hub records
  def selectHubGenomeByGenomeAndHubId(genome, hubId)
    return selectByMultipleFieldsAndValues(:mainDB, 'hubGenomes', { 'genome' => genome, 'hub_id' => hubId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_FULL_HUBGENOME_BY_GENOMES_AND_HUBID_SQL = "
  select hubGenome.id as hubGenome_id, hubGenome_genome as hubGenome_genome, hubTracks.id as hubTrack_id, hubTracks.hubGenome_id as hubTrack_hubGenome_id, hubTracks.trkKey as hubTrack_trkKey, hubTracks.type as hubTrack_type, hubTracks.parent_id as hubTrack_parent_id, hubTracks.aggTrack as hubTrack_aggTrack, hubTracks.trkUrl as hubTrack_trkUrl, hubTracks.dataUrl as hubTrack_dataUrl, hubTracks.shortLabel as hubTrack_shortLabel, hubTracks.longLabel as hubTrack_longLabel,
  from hubGenomes, hubTracks
  where hubGenomes.hub_id = {hubId}
  and hubGenomes.genome = '{genome}'
  and hubTracks.hubGenome_id = hubGenomes.id
  "
  # Get all tracks for the given genomes from a given hub using its name and the id of the group it's in.
  # @param [Array<String>] genomes  The names of the genomes to get track records for
  # @param [Fixnum] hubId The id of the hub containing those genomes
  # @return [Array<Hash>] Result set - 0+ records with columns:
  #   * hubGenome_id, hubGenome_genome, AND
  #   * all hubTracks.* columns as hubTrack_{colName}
  def selectFullHubGenomeInfoByGenomeAndHubId(genomes, hubId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_FULL_HUBGENOME_BY_GENOME_AND_HUBID_SQL.gsub(/\{hubId\}/, hubId)
      sql = sql.gsub(/\{genome\}/, mysql2gsubSafeEsc(genome.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # Insert a new HubGenome record.
  # @param [Fixnum] hubId The id of the hub the hubGenome is in.
  # @param [String] genome  HubGenome name within the hub. Must be unique within the hub and needs to be a UCSC genome name or a 2bit-supplied genome.
  # @param [String] description The genome's description. Optional.
  # @param [String] organism The human-readable name of the organism involved. Anything. Optional.
  # @param [String] defaultPos A UCSC landmark string to be used as the default genomic region to view; typically something interesting. Optional
  # @param [Fixnum] orderKey A number indicating where to place this organism in any lists/pull-downs of organisms at UCSC
  # @return [Fixnum] Number of rows inserted
  def insertHubGenome(hubId, genome, description=nil, organism=nil, defaultPos=nil, orderKey=4800)
    data = [ hubId, genome, description, organism, defaultPos, orderKey ]
    return insertHubGenomes(data, 1)
  end

  # Insert multiple HubGenome records using column data.
  # @see insertHub
  # @param [Array, Array<Array>] data An Array of values to use for hubId, name, state (in that order!)
  #   The Array may be 2-D (i.e. N rows of 6 columns or simply a flat array with appropriate values)
  # @param [Fixnum] numHubGenomes Number of hubGenomes to insert using values in @data@.
  #   This is required because the data array may be flat and yet have the dynamic field values for many HubGenomes.
  # @return [Fixnum] Number of rows inserted
  def insertHubGenomes(data, numHubGenomes)
    return insertRecords(:mainDB, 'hubGenomes', data, true, numHubGenomes, 6, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a HubGenome record using its id.
  # @param [Fixnum] id   The hubGenomes.id of the record to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubGenomeById(id)
    return deleteByFieldAndValue(:mainDB, 'hubGenomes', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete HubGenome records using their ids.
  # @param [Array<Fixnum>] ids      Array of hubGenomes.id of the records to delete.
  # @return [Fixnum]  Number of rows deleted
  def deleteHubGenomesByIds(ids)
    return deleteByFieldWithMultipleValues(:mainDB, 'hubGenomes', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a HubGenome record using its unique genome name within the hub identified by hubId
  # @param [String] genome  The unique genome name of the record to delete.
  # @param [Fixnum] hubId  The id of the hub in which genome lives
  # @return [Fixnum]  Number of rows deleted
  def deleteHubGenomeByNameAndHubId(genome, hubId)
    whereCriteria = { 'genome' => genome, 'hub_id' => hubId }
    return deleteByMultipleFieldsAndValues(:mainDB, 'hubGenomes', whereCriteria, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete all the hubGenomes in a hub identified by hubId
  # @param [String] hubName  The unique hub name of the record to delete.
  # @param [Fixnum] groupid  The id of the group in which hubName is a unique hub name.
  # @return [Fixnum]  Number of rows deleted
  def deleteAllHubGenomesByHubId(hubId)
    return deleteByFieldAndValue(:mainDB, 'hubGenomes', 'hub_id', hubId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update the fields of a Hub Genome record identified by its id
  # @param [Fixnum] id
  # @param [Hash] cols2vals map columns-to-update to their new values identified by id
  #   with the following (optional) fields
  #   [Fixnum] hub_id
  #   [String] genome
  #   [String] description
  #   [String] organism
  #   [String] defaultPos
  #   [Fixnum] orderKey
  # @return [Fixnum] Number of rows updated
  def updateHubGenomeById(id, cols2vals)
    return updateColumnsByFieldAndValue(:mainDB, 'hubGenomes', cols2vals, 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
