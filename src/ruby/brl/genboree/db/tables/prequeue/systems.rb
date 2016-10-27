require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: systems
  # - Read-only, for the most part. System instances Genboree knows about.
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  DEFAULT_SYSTEM_TYPE = 'TorqueMaui'
  # ############################################################################
  # METHODS
  # ############################################################################
  # Get system record by its id
  # [+id+]      The ID of the system record to return
  # [+returns+] Array of 0 or 1 system  rows
  def selectSystemById(id)
    return selectByFieldAndValue(:otherDB, 'systems', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Systems records using a list of ids
  # [+ids+]     Array of system IDs
  # [+returns+] Array of 0+ systems records
  def selectSystemsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'system', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get system record by the host and type (since there may be systems of different types at the same host)
  # [+host+]  The host FQDN for the system you want to submit to, interrogate, etc
  # [+type+]  [Default: TorqueMaui]. The type of system at that host.
  # [+returns+] Array of 0 or 1 system  rows
  def selectSystemByHost(host, type=DEFAULT_SYSTEM_TYPE)
    selectConds = { 'host' => host, 'type' => type }
    return selectByMultipleFieldsAndValues(:otherDB, 'systems', selectConds, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
