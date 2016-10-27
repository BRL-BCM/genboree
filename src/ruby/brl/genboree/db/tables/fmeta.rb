require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# FMETA RELATED TABLES - DBUtil Extension Methods for dealing with Fmeta-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: fmeta
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_FMETA_ENTRY = 'insert into fmeta values (?, ?)'
  UPDATE_FMETA_ENTRY = 'replace into fmeta values (?, ?)'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllFmeta()
    return selectAll(:userDB, 'fmeta', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectValueFmeta(entryName)
    selectFieldsByFieldAndValue(:userDB, 'fmeta', [ 'fvalue' ], false, 'fname', entryName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertFmetaEntry(entryName, entryValue)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(INSERT_FMETA_ENTRY)
      retVal = stmt.execute(entryName, entryValue)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, INSERT_FMETA_ENTRY)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateFmetaEntry(entryName, entryValue)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_FMETA_ENTRY)
      retVal = stmt.execute(entryName, entryValue)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_FMETA_ENTRY)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
