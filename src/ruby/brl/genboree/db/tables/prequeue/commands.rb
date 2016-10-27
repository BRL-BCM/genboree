require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: commands
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # ############################################################################
  # METHODS
  # ############################################################################
  # Get command record by its id
  # [+id+]      The ID of the command record to return
  # [+returns+] Array of 0 or 1 command  rows
  def selectCommandById(id)
    return selectByFieldAndValue(:otherDB, 'commands', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Commands records using a list of ids
  # [+ids+]     Array of command IDs
  # [+returns+] Array of 0+ commands records
  def selectCommandsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'commands', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Command record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+commands+]      The main commands string to run, all on one line. If more than one command, turn into usual ;-separated multi-command bash string so all run in 1 go.
  # [+preCommands+]   Json-encoded Array of commands to run in order to set up the job.
  #                   Typically placed into a .pbs or script file BEFORE of the main
  #                   commands string. Run one at a time prior to the main commands string.
  #                   If nil, then there are none ([])
  # [+postCommands+]   Json-encoded Array of commands to run after the main commands string,
  #                   to clean up after the job and do any post-run moving of files, etc.
  #                   Typically placed into a .pbs or script file AFTER of the main
  #                   commands string. Run one at a time prior to the main commands string.
  #                   If nil, then there are none ([])
  # [+returns+]       Number of rows inserted
  def insertCommand(commands, preCommands=nil, postCommands=nil)
    data = [ preCommands, commands, postCommands ]
    return insertRecords(:otherDB, 'commands', data, true, 1, 3, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Command record using its id.
  # [+id+]      The commands.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteCommandById(id)
    return deleteByFieldAndValue(:otherDB, 'commands', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Command records using their ids.
  # [+ids+]     Array of commands.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteCommandsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'commands', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
