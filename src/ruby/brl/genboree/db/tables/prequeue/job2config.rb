require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: job2config
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get Job2Config record via the job_id
  # @param [Fixnum] jobId The ID of the contextConf record to return
  # @return [Array<Hash>] Array of 0 or 1 contextConf  rows
  def selectJob2ConfigByJobId(jobId)
    return selectByFieldAndValue(:otherDB, 'job2config', 'job_id', jobId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Job2Configs records using a list of job_ids
  # [+job_ids+]     Array of contextConf IDs
  # [+returns+] Array of 0+ contextConfs records
  def selectJob2ConfigsByIds(jobIds)
    return selectByFieldWithMultipleValues(:otherDB, 'job2config', 'job_id', jobIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectJob2ConfigByComponentId(component, compId)
    raise "ERROR: #{component.inspect} is not a valid component of a Job. Must be a Symbol: :job, :inputConf, :outputConf, :contextConf, :settingsConf, :command, :systemInfo, :precondition" unless([:job, :inputConf, :outputConf, :contextConf, :settingsConf, :command, :systemInfo, :precondition].include?(component))
    return selectByFieldAndValue(:otherDB, 'job2config', "#{component}_id", compId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectJob2ConfigsByComponentIds(component, compIds)
    raise "ERROR: #{component.inspect} is not a valid component of a Job. Must be a Symbol: :job, :inputConf, :outputConf, :contextConf, :settingsConf, :command, :systemInfo, :precondition" unless([:job, :inputConf, :outputConf, :contextConf, :settingsConf, :command, :systemInfo, :precondition].include?(component))
    return selectByFieldWithMultipleValues(:otherDB, 'job2config', "#{component}_id", compIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Job2Config record, with all the foreign keys
  # [+job_id+]          The id of the record in the jobs table.
  # [+systemInfo_id+]   The id of the record in the systemInfos table.
  # [+command_id+]      The id of the record in the commands table. Can be nil, if none (e.g. utility job?)
  # [+inputConf_id+]    The id of the record in the inputConfs table. Can be nil, which means there are no inputs ([]).
  # [+outputConf_id+]   The id of the record in the outputConfs table. Can be nil, which means there are no outputs ([]).
  # [+settingsConf_id+] The id of the record in the settingsConfs table. Can be nil, which means there are no settings ({}). Rare.
  # [+contextConf_id+]  The id of the record in the contextConfs table. Can be nil, which means there is no context info ({}). Rare.
  # [+precondition_id+] The id of the record in the preconditions table. Can be nil, which means there are no preconditions.
  # [+returns+]       Number of rows inserted
  def insertJob2Config(job_id, systemInfo_id, command_id=nil, inputConf_id=nil, outputConf_id=nil, contextConf_id=nil, settingsConf_id=nil, precondition_id=nil)
    data = [ job_id, inputConf_id, outputConf_id, contextConf_id, settingsConf_id, command_id, systemInfo_id,  precondition_id ]
    return insertRecords(:otherDB, 'job2config', data, false, 1, 8, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Set the precondition_id column to a specific value for a given job_id.
  # @param [Fixnum] job_id The job id for the job2config record to update
  # @param [Fixnum] precondition_id The precondition record id to store in the
  #   precondition_id column for the matching job2config record
  # @return [Fixnum] the number of records updated. Should 1.
  def setJob2ConfigPreconditionIdById(job_id, precondition_id)
    cols2vals = { 'precondition_id' => precondition_id }
    return  updateColumnsByFieldAndValue(:otherDB, 'job2config', cols2vals, 'job_id', job_id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Job2Config record via the job_id
  # @param [Fixnum] jobId The contextConfs.id of the record to delete.
  # @return [Fixnum] Number of rows deleted
  def deleteJob2ConfigById(jobId)
    return deleteByFieldAndValue(:otherDB, 'job2config', 'job_id', jobId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Job2Config records via their job_ids
  # @param [Fixnum] jobIds Array of job_ids of the records to delete.
  # @return [Fixnum] Number of rows deleted
  def deleteJob2ConfigsByIds(jobIds)
    return deleteByFieldWithMultipleValues(:otherDB, 'job2config', 'job_id', jobIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
