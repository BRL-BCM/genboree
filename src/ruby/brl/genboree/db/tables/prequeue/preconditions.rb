require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
# @api BRL Ruby - database interaction
# @api BRL Ruby - prequeue
# @api BRL RUby - preconditions
class DBUtil
  # --------
  # Table: preconditions
  # --------
  # ------------------------------------------------------------------
  # CONSTANTS
  # ------------------------------------------------------------------

  UPDATE_PRECONDITIONS_BY_ID = 'update preconditions set count = ?, numMet = ?, willNeverMatch = ?, someExpired = ?, preconditions = ? where id = ?'
  UPDATE_PRECONDITIONS_NUMMET_BY_ID = 'update preconditions set numMet = ? where id = ?'
  UPDATE_PRECONDITIONS_SOMEEXPIRED_BY_ID = 'update preconditions set someExpired = ? where id = ?'
  UPDATE_PRECONDITIONS_INFO_BY_ID = 'update preconditions set info = ? where id = ?'
  UPDATE_PRECONDITIONS_PRECONDITIONS_BY_ID = 'update preconditions set preconditions = ? where id = ?'

  # ------------------------------------------------------------------
  # METHODS
  # ------------------------------------------------------------------

  # Get preconditions record by its id
  # @param  [Fixnum] precondId  IDof the preconditions record to return
  # @return [Array<Hash>] preconditions table rows
  def selectPreconditionsById(precondId)
    return selectByFieldAndValue(:otherDB, 'preconditions', 'id', precondId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Preconditions records using a list of ids
  # @param [Array<Fixnum>] ids     Array of preconditions IDs
  # @return [Array<Hash>] Array of 0+ preconditionss records
  def selectPreconditionsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'preconditions', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Preconditions record
  # Sets dbu.lastInsertId in case you need it for follow up
  # @param [String]  preconditions JSON Hash/Object String specifying the preconditions
  # @param [Fixnum]  count the number of specific preconditions encoded in the JSON object
  # @param [Fixnum]  numMet the number of specific conditions already met
  # @param [Boolean] willNeverMatch indicating if it's possible some conditions may never match
  #   (e.g. if some other ocnditional job can run *instead* of this one, depending on how conditions are met)
  # @param [Boolean] someExpired indicating if some of the preconditions have expired due to too much time passing
  # @return [Fixnum] number of rows inserted
  def insertPreconditions(preconditions, count, numMet=0, willNeverMatch=false, someExpired=false)
    retVal = nil
    begin
      data = [ count, numMet, willNeverMatch, someExpired, preconditions ]
      retVal = insertRecords(:otherDB, 'preconditions', data, true, 1, data.size, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, '[none]')
    end
    return retVal
  end

  # Update ALL the fields of a preconditions record identified by its id.
  # - If you want to update just the numMet, someExpired, the preconditions then there are dedicated methods for those.
  # - Usually you want the other update methods
  # @param  [Fixnum] precondId ID of the preconditions record to update
  # @param  (see #insertPreconditions)
  # @return (see #insertPreconditions)
  def updatePreconditionsById(precondId, preconditions, count, numMet=0, willNeverMatch=false, someExpired=false)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_PRECONDITIONS_BY_ID)
      stmt.execute(count, numMet, willNeverMatch, someExpired, preconditions, precondId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_PRECONDITIONS_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the numMet field of a preconditions record identified by its id.
  # @param  [Fixnum] precondId ID of the preconditions record to update
  # @param  [Fixnum] numMet the number of specific preconditions that have been met
  # @return [Fixnum] the number of rows updated
  def updatePreconditionsNumMetById(precondId, numMet)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_PRECONDITIONS_NUMMET_BY_ID)
      stmt.execute(numMet.to_s, precondId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_PRECONDITIONS_NUMMET_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the someExpired field of a preconditions record identified by its id.
  # @param  [Fixnum]  precondId ID of the preconditions record to update
  # @param  [Boolean] someExpired indicating if some of the specific preconditions have timed out or not
  # @return [Fixnum]  the number of rows updated
  def updatePreconditionsSomeExpiredById(precondId, someExpired)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_PRECONDITIONS_SOMEEXPIRED_BY_ID)
      stmt.execute(someExpired, precondId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_PRECONDITIONS_SOMEEXPIRED_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the preconditions field of a Preconditions record identified by its id.
  # @param  [Fixnum] precondId ID of the preconditions record to update
  # @param  [Fixnum] preconditions JSON Hash/Object String specifying the preconditions.
  # @return [Fixnum] number of rows updated
  def updatePreconditionsPreconditionsById(precondId, preconditions)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_PRECONDITIONS_PRECONDITIONS_BY_ID)
      stmt.execute(preconditions, precondId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_PRECONDITIONS_PRECONDITIONS_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Preconditions record using its id.
  # @param  [Fixnum] precondId the preconditionss.id of the record to delete.
  # @return [Fixnum] number of rows deleted
  def deletePreconditionsById(precondId)
    return deleteByFieldAndValue(:otherDB, 'preconditions', 'id', precondId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Preconditions records using their ids.
  # @param  [Array<Fixnum>] ids list of preconditionss.id of the records to delete.
  # @return [Fixnum] number of rows deleted
  def deletePreconditionsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'preconditions', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
