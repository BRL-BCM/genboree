require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GCLASS RELATED TABLES - DBUtil Extension Methods for dealing with gclass-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: gclass
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllGIDs()
    return selectAll(:userDB, 'gclass', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGclassByGclass(gclass)
    return selectByFieldAndValue(:userDB, 'gclass', 'gclass', gclass, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertGclassRecord(gclass)
    data = [gclass]
    return insertRecords(:userDB, 'gclass', data, true, 1, 1, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
