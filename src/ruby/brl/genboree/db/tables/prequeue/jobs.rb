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
  # Table: jobs
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  JOB_DEFAULT_TIME = 'default'
  JOB_DEFAULT_TIME_STR = Time.at(-3600).utc.strftime("%Y-%m-%d %H:%M:%S")
  JOB_STATUSES = { :entered => true, :submitted => true, :running => true, :completed => true, :failed => true, :wait4deps => true, :partialSuccess => true, :cancelRequested => true, :canceled => true, :killed => true, :depsExpired => true, :depsFailed => true }
  JOB_TYPES = { 'gbToolJob' => true, 'pipelineJob' => true, 'utilityJob' => true, 'gbLocalTaskWrapperJob' => true }

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get jobs record by its id
  # @param [Fixnum] jobId The ID of the jobs record to return
  # @return [Array<Hash>] Array of 0 or 1 jobs rows
  def selectJobById(jobId)
    return selectByFieldAndValue(:otherDB, 'jobs', 'id', jobId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get job record by its name
  # [+name+]  Unique job name
  # [+returns+] Array of 0 or 1 jobs rows
  def selectJobByName(name)
    return selectByFieldAndValue(:otherDB, 'jobs', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Jobs records using a list of ids
  # [+ids+]     Array of jobs IDs
  # [+returns+] Array of 0+ jobss records
  def selectJobsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'jobs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get jobs statuses for jobs using a list of job row ids.
  # @param [Array<Fixnum>] ids Array of job row IDs.
  # @return [Array<Hash{String,Object}>] The result set as an Array of rows as Hashes which map column names to values.
  #   Each Hash (row) will have these keyes: "id", "name", "status".
  def selectJobStatusesByIds(ids)
    cols = [ 'id', 'name', 'status' ]
    return selectFieldsByFieldWithMultipleValues( :otherDB, 'jobs', cols, true, 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get jobs statuses for jobs using a list of jobs names.
  # @param [Array<Fixnum>] names Array of job names.
  # @return [Array<Hash{String,Object}>] The result set as an Array of rows as Hashes which map column names to values.
  #   Each Hash (row) will have these keyes: "id", "name", "status".
  def selectJobStatusesByNames(names)
    cols = [ 'id', 'name', 'status' ]
    return selectFieldsByFieldWithMultipleValues( :otherDB, 'jobs', cols, true, 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Jobs record.
  # - Typically, this would be used as part of entering a new job.
  #   . Thus only name, user, and toolId are needed because the DEFAULTS for the rest are good FOR NEW JOBS.
  # - If the job is a utility (immmediate) job, it can make sense to immediately set columns to these values:
  #   . status = :running
  #   . entryDate = Time.now()
  #   . submitDate = Time.now()
  #   . execStartDate = Time.now()
  # - Utility (immediate) type jobs should still update execEndDate when done!! (There is a helpful method for that)
  # - Sets dbu.lastInsertId in case you need it for follow up
  # [+name+]          The job name (id string) a.k.a. job ticket number.
  # [+user+]          Genboree login of the user who submitted the job.
  # [+toolId+]        A tool id String. Should correspond to an actual Genboree tool or identify something similar.
  # [+type+]          The kind of job this is. Current values are 'gbToolJob' or 'utility'.
  # [+status+]        [Default=:entered] Status String or Symbol for the job. Must be one of ('entered','submitted','running','completed','failed','wait4deps','partialSuccess','canceled','killed'
  # [+entryDate+]     [Default: Time.now] Ruby Time object for when the job was entered into the Genboree system / prequeue.
  # [+submitDate+]    [Default: Time.at(-3600).utc] Ruby Time object for when the job was submitted to the actual queuing system, to await execution.
  # [+execStartDate+] [Default: Time.at(-3600).utc] Ruby Time object for when the job actually started executing.
  # [+execEndDate+]   [Default: Time.at(-3600).utc] Ruby Time object for when the job actually finished executing.
  # [+returns+]       Number of rows inserted
  def insertJob(name, user, toolId, type='gbToolJob', status=:entered, entryDate=Time.now, submitDate=JOB_DEFAULT_TIME, execStartDate=JOB_DEFAULT_TIME, execEndDate=JOB_DEFAULT_TIME)
    begin
      raise ArgumentError, "ERROR: value for status arg ('#{status.inspect}') in #{__method__} must be one of #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}" unless(JOB_STATUSES.key?(status))
      data = [ name, user, toolId, type, status.to_s, entryDate, submitDate, execStartDate, execEndDate ]
      retVal = insertRecords(:otherDB, 'jobs', data, true, 1, 9, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, '[none]')
    end
    return retVal
  end

  # Update ALL the fields of a jobs record identified by its id.
  # - If you want to update just the status or just one of the time stamp columns there are dedicated methods for those.
  # - Usually you want the other update methods.
  # @param [Fixnum] jobId Jobs.id of the record to update
  # @param [String] name  The job name (id string) a.k.a. job ticket number.
  # @param [String] user  Genboree login of the user who submitted the job.
  # @param [String] toolIdSts A tool id String. Should correspond to an actual Genboree tool or identify something similar.
  # @param [String] type The kind of job this is. Current values are 'gbToolJob' or 'utility'.
  # @param [Symbol,Symbol] status String or Symbol for the job. Must be one of
  #   ('entered','submitted','running','completed','failed','wait4deps','partialSuccess','canceled','killed'
  # @param [Time] entryDate Ruby Time object for when the job was entered into the Genboree system / prequeue.
  # @param [Time] submitDate Ruby Time object for when the job was submitted to the actual queuing system, to await execution.
  # @param [Time] execStartDate Ruby Time object for when the job actually started executing.
  # @param [Time] execEndDate Ruby Time object for when the job actually finished executing.
  # @return [Fixnum] Number of rows updated
  UPDATE_JOB_BY_ID = 'update jobs set name = ?, user = ?, toolId = ?, type = ?, status = ?, entryDate = ?, submitDate = ?, execStartDate = ?, execEndDate = ? where id = ?'
  def updateJobById(jobId, name, user, toolId, type='gbToolJob', status=:entered, entryDate=Time.now, submitDate=JOB_DEFAULT_TIME, execStartDate=JOB_DEFAULT_TIME, execEndDate=JOB_DEFAULT_TIME)
    retVal = nil
    begin
      raise ArgumentError, "ERROR: value for status arg ('#{status.inspect}') in #{__method__} must be one of #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}" unless(JOB_STATUSES.key?(status))
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_BY_ID)
      stmt.execute(name, user, toolId, type, status.to_s, entryDate, submitDate, execStartDate, execEndDate, jobId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the status field of a jobs record identified by its id.
  # @param [Fixnum] jobId Jobs.id of the record to update
  # @param [Symbol,String] status Status String or Symbol for the job. Must be one of
  #   ('entered','submitted','running','completed','failed','wait4deps','partialSuccess','canceled','killed'
  # @return [Fixnum]       Number of rows updated
  UPDATE_JOB_STATUS_BY_ID = 'update jobs set status = ? where id = ?'
  def updateJobStatusById(jobId, status)
    retVal = nil
    begin
      raise ArgumentError, "ERROR: value for status arg ('#{status.inspect}') in #{__method__} must be one of #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}" unless(JOB_STATUSES.key?(status))
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_STATUS_BY_ID)
      stmt.execute(status.to_s, jobId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_STATUS_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the status field of a jobs record identified by its unique job name.
  # [+name+]           Jobs.name of the record to update
  # [+status+]        [Default=:entered] Status String or Symbol for the job. Must be one of ('entered','submitted','running','completed','failed','wait4deps','partialSuccess','canceled','killed'
  # [+returns+]       Number of rows updated
  UPDATE_JOB_STATUS_BY_NAME = 'update jobs set status = ? where name = ?'
  def updateJobStatusByJobName(name, status)
    retVal = nil
    begin
      raise ArgumentError, "ERROR: value for status arg ('#{status.inspect}') in #{__method__} must be one of #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}" unless(JOB_STATUSES.key?(status))
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_STATUS_BY_NAME)
      stmt.execute(status.to_s, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_STATUS_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the entryDate field of a Jobs record identified by its id.
  # [+id+]            Jobs.id of the record to update
  # [+entryDate+]     [Default: Time.now] Ruby Time object for when the job was entered into the prequeue, to await actual submission.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_ENTRYDATE_BY_ID = 'update jobs set entryDate = ? where id = ?'
  def updateJobEntryDateById(id, entryDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_ENTRYDATE_BY_ID)
      stmt.execute(entryDate.strftime("%Y-%m-%d %H:%M:%S"), id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_ENTRYDATE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the entryDate field of a Jobs record identified by its unique job name
  # [+name+]          Jobs.name of the record to update
  # [+entryDate+]     [Default: Time.now] Ruby Time object for when the job was entered into the prequeue, to await actual submission.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_ENTRYDATE_BY_NAME = 'update jobs set entryDate = ? where name = ?'
  def updateJobEntryDateByJobName(name, entryDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_ENTRYDATE_BY_NAME)
      stmt.execute(entryDate.strftime("%Y-%m-%d %H:%M:%S"), name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_ENTRYDATE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the submitDate field of a Jobs record identified by its id.
  # [+id+]            Jobs.id of the record to update
  # [+submitDate+]    [Default: Time.now] Ruby Time object for when the job was submitted to the actual queuing system, to await execution.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_SUBMITDATE_BY_ID = 'update jobs set submitDate = ? where id = ?'
  def updateJobSubmitDateById(id, submitDate=Time.now)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_SUBMITDATE_BY_ID)
      stmt.execute(submitDate.strftime("%Y-%m-%d %H:%M:%S"), id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_SUBMITDATE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the submitDate field of a Jobs record identified by its unique job name.
  # [+name+]           Jobs.name of the record to update
  # [+submitDate+]    [Default: Time.now] Ruby Time object for when the job was submitted to the actual queuing system, to await execution.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_SUBMITDATE_BY_NAME = 'update jobs set submitDate = ? where name = ?'
  def updateJobSubmitDateByJobName(name, submitDate=Time.now)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_SUBMITDATE_BY_NAME)
      stmt.execute(submitDate.strftime("%Y-%m-%d %H:%M:%S"), name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_SUBMITDATE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the execStartDate field of a Jobs record identified by its id.
  # [+id+]            Jobs.id of the record to update
  # [+execStartDate+] [Default: Time.at(-3600).utc] Ruby Time object for when the job actually started executing.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_EXECSTARTDATE_BY_ID = 'update jobs set execStartDate = ? where id = ?'
  def updateJobExecStartDateById(id, execStartDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_EXECSTARTDATE_BY_ID)
      stmt.execute(execStartDate.strftime("%Y-%m-%d %H:%M:%S"), id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_EXECSTARTDATE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the execStartDate field of a Jobs record identified by its unique job name.
  # [+name+]          Jobs.name of the record to update
  # [+execStartDate+] [Default: Time.at(-3600).utc] Ruby Time object for when the job actually started executing.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_EXECSTARTDATE_BY_NAME = 'update jobs set execStartDate = ? where name = ?'
  def updateJobExecStartDateByJobName(name, execStartDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_EXECSTARTDATE_BY_NAME)
      stmt.execute(execStartDate.strftime("%Y-%m-%d %H:%M:%S"), name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_EXECSTARTDATE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the execEndDate field of a Jobs record identified by its id.
  # [+id+]            Jobs.id of the record to update
  # [+execEndDate+]   [Default: Time.at(-3600).utc] Ruby Time object for when the job actually finished executing.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_EXECENDDATE_BY_ID = 'update jobs set execEndDate = ? where id = ?'
  def updateJobExecEndDateById(id, execEndDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_EXECENDDATE_BY_ID)
      stmt.execute(execEndDate.strftime("%Y-%m-%d %H:%M:%S"), id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_EXECENDDATE_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the execEndDate field of a Jobs record identified by its unique job name.
  # [+name+]          Jobs.name of the record to update
  # [+execEndDate+]   [Default: Time.at(-3600).utc] Ruby Time object for when the job actually finished executing.
  # [+returns+]       Number of rows updated
  UPDATE_JOB_EXECENDDATE_BY_NAME = 'update jobs set execEndDate = ? where name = ?'
  def updateJobExecEndDateByJobName(name, execEndDate=Time.now())
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_JOB_EXECENDDATE_BY_NAME)
      stmt.execute(execEndDate.strftime("%Y-%m-%d %H:%M:%S"), name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_JOB_EXECENDDATE_BY_NAME)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a Jobs record using its id.
  # [+id+]      The jobs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteJobById(id)
    return deleteByFieldAndValue(:otherDB, 'jobs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Jobs records using their ids.
  # [+ids+]     Array of jobs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteJobsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'jobs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Jobs record using its unique job name.
  # [+name+]      The jobs.name of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteJobByJobName(name)
    return deleteByFieldAndValue(:otherDB, 'jobs', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Jobs records using their unique job names.
  # [+names+]   Array of jobs.name of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteJobsByIds(names)
    return deleteByFieldWithMultipleValues(:otherDB, 'jobs', 'name', names, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # ------------------------------------------------------------------
  # MULTI-TABLE QUERIES - to answer questions about jobs
  # ------------------------------------------------------------------
  SQL_PATTERN_selectJobFullInfoByJobId =
    " select jobs.*, inputConfs.input, outputConfs.output, settingsConfs.settings, contextConfs.context, systems.type as systemType, systems.host, systems.adminEmails, systemInfos.queue, systemInfos.systemJobId, preconditions.id as preconditionId
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join inputConfs on inputConfs.id = job2config.inputConf_id
      left join outputConfs on outputConfs.id = job2config.outputConf_id
      left join settingsConfs on settingsConfs.id = job2config.settingsConf_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join preconditions on preconditions.id = job2config.precondition_id
      where jobs.id = '{jobId}' and systemInfos.system_id = systems.id "
  # Gets all the config info for a job. Does not include precondition info (assumed to be for scheduling).
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # *  id
  # *  name
  # *  user
  # *  toolId
  # *  type
  # *  status
  # *  entryDate
  # *  submitDate
  # *  execStartDate
  # *  execEndDate
  # *  input
  # *  output
  # *  settings
  # *  context
  # *  systemType
  # *  host
  # *  adminEmails
  # *  queue
  # *  systemJobId
  # [+id+]  Id in the Jobs table for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobFullInfoByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobFullInfoByJobId.dup()
      sql.gsub!(/\{jobId\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobFullInfosByJobIds =
    " select jobs.*, inputConfs.input, outputConfs.output, settingsConfs.settings, contextConfs.context, systems.type as systemType, systems.host, systems.adminEmails, systemInfos.queue, systemInfos.systemJobId, preconditions.id as preconditionId
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join inputConfs on inputConfs.id = job2config.inputConf_id
      left join outputConfs on outputConfs.id = job2config.outputConf_id
      left join settingsConfs on settingsConfs.id = job2config.settingsConf_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join preconditions on preconditions.id = job2config.precondition_id
      where jobs.id in {jobIdsSet} and systemInfos.system_id = systems.id "
  # Gets all the config info for a job. Does not include precondition info (assumed to be for scheduling).
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # *  id
  # *  name
  # *  user
  # *  toolId
  # *  type
  # *  status
  # *  entryDate
  # *  submitDate
  # *  execStartDate
  # *  execEndDate
  # *  input
  # *  output
  # *  settings
  # *  context
  # *  systemType
  # *  host
  # *  adminEmails
  # *  queue
  # *  systemJobId
  # [+ids+]  Array of ids in the Jobs table for the records
  # [+returns+] Result set with jobs rows with the above columns from multiple tables.
  def selectJobFullInfosByJobIds(ids, outputParams, filters)
    retVal = nil
    # If ids is empty, then we will set retVal to be an empty array. 
    # The MySQL query will error out if the ids array is empty.
    unless(ids.empty?)
      begin
        client = getMysql2Client(:otherDB)
        # Make sql
        sortBy, grouping = outputParams['sortBy'], outputParams['grouping']
        sortByCols = (filters['sortByCols'] || [ 'entryDate'] )
        sql = SQL_PATTERN_selectJobFullInfosByJobIds.dup()
        jobIdsSet = DBUtil.makeMysql2SetStr(ids)
        sql.gsub!(/\{jobIdsSet\}/, jobIdsSet)
        # - grouping
        if(grouping and grouping != 'none')
          if(grouping == 'status')
            sql << " group by status"
          elsif(grouping == 'toolId')
            sql << " group by toolId"
          else
            raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'"
          end
        end
        # - sortByCols
        if(sortByCols)
          direction = " desc "
          if(sortBy)
            raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'" unless(sortBy == 'newestFirst' or sortBy == 'oldestFirst')
            direction = ((sortBy == 'oldestFirst') ? '' : ' desc ')
          end
          sortByCols = [ sortByCols ] if(sortByCols.is_a?(String))
          sql << " order by "
          sortByCols.each_index { |ii|
            col = sortByCols[ii]
            sql << col
            sql << " #{direction}" if(col =~ /date$/i)
            sql << ", " unless(ii >= (sortByCols.size - 1))
          }
        end
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sql: #{sql.inspect}")
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
      ensure
        client.close rescue false
      end
    else 
      retVal = []
    end
    return retVal
  end

  SQL_PATTERN_selectJobFullInfoByJobName =
    " select jobs.*, inputConfs.input, outputConfs.output, settingsConfs.settings, contextConfs.context, systems.type as systemType, systems.host, systems.adminEmails, systemInfos.queue, systemInfos.systemJobId, preconditions.id as preconditionId
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join inputConfs on inputConfs.id = job2config.inputConf_id
      left join outputConfs on outputConfs.id = job2config.outputConf_id
      left join settingsConfs on settingsConfs.id = job2config.settingsConf_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join preconditions on preconditions.id = job2config.precondition_id
      where jobs.name = '{jobName}' and systemInfos.system_id = systems.id "
  # Gets all the config info for a job. Does not include precondition info (assumed to be for scheduling).
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # *  id
  # *  name
  # *  user
  # *  toolId
  # *  type
  # *  status
  # *  entryDate
  # *  submitDate
  # *  execStartDate
  # *  execEndDate
  # *  input
  # *  output
  # *  settings
  # *  context
  # *  systemType
  # *  host
  # *  adminEmails
  # *  queue
  # *  systemJobId
  # [+name+]  Unique job name for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobFullInfoByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobFullInfoByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobFullInfoByJobNames =
    " select jobs.*, inputConfs.input, outputConfs.output, settingsConfs.settings, contextConfs.context, systems.type as systemType, systems.host, systems.adminEmails, systemInfos.queue, systemInfos.systemJobId, preconditions.id as preconditionId
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join inputConfs on inputConfs.id = job2config.inputConf_id
      left join outputConfs on outputConfs.id = job2config.outputConf_id
      left join settingsConfs on settingsConfs.id = job2config.settingsConf_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join preconditions on preconditions.id = job2config.precondition_id
      where jobs.id in {jobNamesSet} and systemInfos.system_id = systems.id "
  # Gets all the config info for a job. Does not include precondition info (assumed to be for scheduling).
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # *  id
  # *  name
  # *  user
  # *  toolId
  # *  type
  # *  status
  # *  entryDate
  # *  submitDate
  # *  execStartDate
  # *  execEndDate
  # *  input
  # *  output
  # *  settings
  # *  context
  # *  systemType
  # *  host
  # *  adminEmails
  # *  queue
  # *  systemJobId
  # [+names+]   Array of unique job names for the records
  # [+returns+] Result set with jobs rows with the above columns from multiple tables.
  def selectJobFullInfosByJobNames(names)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobFullInfoByJobNames.dup()
      jobNamesSet = DBUtil.makeMysql2SetStr(names)
      sql.gsub!(/\{jobNamesSet\}/, jobNamesSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobFullInfoBySystemInfoAndSystemJobId =
    " select jobs.*, inputConfs.input, outputConfs.output, settingsConfs.settings, contextConfs.context, systems.type as systemType, systems.host, systems.adminEmails, systemInfos.queue, systemInfos.systemJobId, preconditions.id as preconditionId
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join inputConfs on inputConfs.id = job2config.inputConf_id
      left join outputConfs on outputConfs.id = job2config.outputConf_id
      left join settingsConfs on settingsConfs.id = job2config.settingsConf_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join preconditions on preconditions.id = job2config.precondition_id
      where systems.host = '{host}' and systems.type = '{systemType}' and systemInfos.systemJobId = '{systemJobId}' and systemInfos.system_id = systems.id "
  # Gets all the config info for a job. Does not include precondition info (assumed to be for scheduling).
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # *  id
  # *  name
  # *  user
  # *  toolId
  # *  type
  # *  status
  # *  entryDate
  # *  submitDate
  # *  execStartDate
  # *  execEndDate
  # *  input
  # *  output
  # *  settings
  # *  context
  # *  systemType
  # *  host
  # *  adminEmails
  # *  queue
  # *  systemJobId
  # The combination of batch system host, batch system type, and the job id assigned by that
  # batch system can uniquely identify a job in the prequeue.
  # [+host+]        String with the batch system host where job is queued, running, or ran.
  # [+systemType+]  String with the batch system type at that host where job is queued, running, or ran
  # [+systemJobId+] String with the job id the batch system assigned to the job once queued there.
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobFullInfoBySystemInfoAndSystemJobId(host, systemType, systemJobId)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobFullInfoBySystemInfoAndSystemJobId .dup()
      sql = sql.gsub(/\{host\}/, mysql2gsubSafeEsc(host.to_s))
      sql = sql.gsub(/\{systemType\}/, mysql2gsubSafeEsc(systemType.to_s))
      sql = sql.gsub(/\{systemJobId\}/, mysql2gsubSafeEsc(systemJobId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobAuditInfoByJobId =
    " select jobs.user, systems.host as systemHost, systems.type as systemType, systemInfos.queue, systemInfos.systemJobId, jobs.type as toolType, jobs.toolId, jobs.name, jobs.entryDate, jobs.submitDate, jobs.execStartDate, jobs.execEndDate, jobs.status, systemInfos.directives, contextConfs.context
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      where jobs.id = '{jobId}' and systemInfos.system_id = systems.id "
  # Gets audit-level info for a job. Does not include precondition info (assumed to be for scheduling)
  # and the specific inputs/outputs and config stuff.
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # * user
  # * submitHost
  # * systemHost
  # * systemType
  # * queue
  # * systemJobId
  # * toolType
  # * toolId
  # * label
  # * name
  # * entryDate
  # * submitDate
  # * execStartDate
  # * execEndDate
  # * status
  # * directives
  # [+id+]  Id in the Jobs table for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobAuditInfoByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobAuditInfoByJobId.dup()
      sql.gsub!(/\{jobId\}/, DBUtil.mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobAuditInfosByJobIds =
    " select jobs.user, systems.host as systemHost, systems.type as systemType, systemInfos.queue, systemInfos.systemJobId, jobs.type as toolType, jobs.toolId, jobs.name, jobs.entryDate, jobs.submitDate, jobs.execStartDate, jobs.execEndDate, jobs.status, systemInfos.directives, contextConfs.context
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      where jobs.id in {jobIdsSet} and systemInfos.system_id = systems.id "
  # Gets audit-level info for one or more jobs. Does not include precondition info (assumed to be for scheduling)
  # and the specific inputs/outputs and config stuff.
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # * user
  # * submitHost
  # * systemHost
  # * systemType
  # * queue
  # * systemJobId
  # * toolType
  # * toolId
  # * label
  # * name
  # * entryDate
  # * submitDate
  # * execStartDate
  # * execEndDate
  # * status
  # * directives
  # [+id+]  Id in the Jobs table for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobAuditInfosByJobIds(ids, outputParams, filters)
    t1 = Time.now
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sortBy, grouping = outputParams['sortBy'], outputParams['grouping']
      sortByCols = (filters['sortByCols'] || ['entryDate'] )
      sql = SQL_PATTERN_selectJobAuditInfosByJobIds.dup()
      jobIdsSet = DBUtil.makeMysql2SetStr(ids)
      sql.gsub!(/\{jobIdsSet\}/, jobIdsSet)
      # - grouping
      if(grouping and grouping != 'none')
        if(grouping == 'status')
          sql << " group by status"
        elsif(grouping == 'toolId')
          sql << " group by toolId"
        else
          raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'"
        end
      end
      # - sortByCols
      if(sortByCols)
        direction = " desc "
        if(sortBy)
          raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'" unless(sortBy == 'newestFirst' or sortBy == 'oldestFirst')
          direction = ((sortBy == 'oldestFirst') ? '' : ' desc ')
        end
        sortByCols = [ sortByCols ] if(sortByCols.is_a?(String))
        sql << " order by "
        sortByCols.each_index { |ii|
          col = sortByCols[ii]
          sql << col
          sql << " #{direction}" if(col =~ /date$/i)
          sql << ", " unless(ii >= (sortByCols.size - 1))
        }
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "---> BUILT SQL (#{Time.now - t1} secs):\n    #{sql}") ; t1 = Time.now
      resultSet = client.query(sql, :cast_booleans => true)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "---> QUERIED SQL (#{Time.now - t1} secs)") ; t1 = Time.now
      retVal = resultSet.entries
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "---> GOT resultSet.entries (#{Time.now - t1} secs)") ; t1 = Time.now
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobAuditInfoByJobName =
    " select jobs.user, systems.host as systemHost, systems.type as systemType, systemInfos.queue, systemInfos.systemJobId, jobs.type as toolType, jobs.toolId, jobs.name, jobs.entryDate, jobs.submitDate, jobs.execStartDate, jobs.execEndDate, jobs.status, systemInfos.directives, contextConfs.context
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      where jobs.name = '{jobName}' and systemInfos.system_id = systems.id "
  # Gets audit-level info for a job. Does not include precondition info (assumed to be for scheduling)
  # and the specific inputs/outputs and config stuff.
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # * user
  # * submitHost
  # * systemHost
  # * systemType
  # * queue
  # * systemJobId
  # * toolType
  # * toolId
  # * label
  # * name
  # * entryDate
  # * submitDate
  # * execStartDate
  # * execEndDate
  # * status
  # * directives
  # [+id+]  Id in the Jobs table for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobAuditInfoByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobAuditInfoByJobName.dup()
      sql.gsub!(/\{jobName\}/, DBUtil.mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  SQL_PATTERN_selectJobAuditInfoByJobNames =
    " select jobs.user, systems.host as systemHost, systems.type as systemType, systemInfos.queue, systemInfos.systemJobId, jobs.type as toolType, jobs.toolId, jobs.name, jobs.entryDate, jobs.submitDate, jobs.execStartDate, jobs.execEndDate, jobs.status, systemInfos.directives, contextConfs.context
      from systems, job2config
      left join jobs on jobs.id = job2config.job_id
      left join systemInfos on systemInfos.id = job2config.systemInfo_id
      left join contextConfs on contextConfs.id = job2config.contextConf_id
      where jobs.id in {jobNamesSet} and systemInfos.system_id = systems.id "
  # Gets audit-level info for a job. Does not include precondition info (assumed to be for scheduling)
  # and the specific inputs/outputs and config stuff.
  # If you need specific sections only, there are methods for that. This gets it all in one shot.
  # Result set has these columns (and should be a 1 row table):
  # * user
  # * submitHost
  # * systemHost
  # * systemType
  # * queue
  # * systemJobId
  # * toolType
  # * toolId
  # * label
  # * name
  # * entryDate
  # * submitDate
  # * execStartDate
  # * execEndDate
  # * status
  # * directives
  # [+id+]  Id in the Jobs table for the record
  # [+returns+] Result set with 0 or 1 rows with the above columns from multiple tables.
  def selectJobAuditInfosByJobNames(names)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobAuditInfoByJobNames.dup()
      jobNamesSet = DBUtil.makeMysql2SetStr(names)
      sql.gsub!(/\{jobNamesSet\}/, jobNamesSet)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the commands table record for a job using the jobs id. Not all jobs
  # need have commands. So empty result set is correct for certain classes of jobs.
  # [+id+]  ID in the jobs table for the job
  # [+returns+] Result set with 0 or 1 rows with the commands table record for the job, if any.
  SQL_PATTERN_selectJobCommandsByJobId = "select commands.* from jobs, commands, job2config where job2config.job_id = '{jobId}' and commands.id = job2config.command_id"
  def selectJobCommandsByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobCommandsByJobId.dup()
      sql.gsub!(/\{jobId\}/, DBUtil.mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the commands table record for a job using the job's unique name. Not all jobs
  # need have commands. So empty result set is correct for certain classes of jobs.
  # [+name+]  Unique job name for the job
  # [+returns+] Result set with 0 or 1 rows with the commands table record for the job, if any.
  SQL_PATTERN_selectJobCommandsByJobName = "select commands.* from jobs, commands, job2config where jobs.name = '{jobName}' and job2config.job_id = jobs.id and commands.id = job2config.command_id"
  def selectJobCommandsByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobCommandsByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the inputConfs table record for a job using the job's id. Not all jobs
  # need have inputConfs. So empty result set is correct for certain classes of jobs.
  # [+id+]  ID in the jobs table for the job
  # [+returns+] Result set with 0 or 1 rows with the inputConfs table record for the job, if any.
  SQL_PATTERN_selectJobInputsByJobId = "select inputConfs.* from inputConfs, job2config where job2config.job_id = '{jobId}' and inputConfs.id = job2config.inputConf_id"
  def selectJobInputsByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobInputsById.dup()
      sql.gsub!(/\{jobId\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the inputConfs table record for a job using the job's unique name. Not all jobs
  # need have inputConfs. So empty result set is correct for certain classes of jobs.
  # [+iname+]   Unique name for the job
  # [+returns+] Result set with 0 or 1 rows with the inputConfs table record for the job, if any.
  SQL_PATTERN_selectJobInputsByJobName = "select inputConfs.* from jobs, inputConfs, job2config where jobs.name = '{jobName}' and job2config.job_id = jobs.id and inputConfs.id = job2config.inputConf_id"
  def selectJobInputsByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobInputsByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the outputConfs table record for a job using the job's id. Not all jobs
  # need have outputConfs. So empty result set is correct for certain classes of jobs.
  # [+id+]  ID in the jobs table for the job
  # [+returns+] Result set with 0 or 1 rows with the outputConfs table record for the job, if any.
  SQL_PATTERN_selectJobOutputsByJobId = "select outputConfs.* from outputConfs, job2config where job2config.jc_id = '{jobId}' and outputConfs.id = job2config.outputConf_id"
  def selectJobOutputsByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobOutputsById.dup()
      sql.gsub!(/\{jobId\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the outputConfs table record for a job using the job's unique name. Not all jobs
  # need have outputConfs. So empty result set is correct for certain classes of jobs.
  # [+iname+]   Unique name for the job
  # [+returns+] Result set with 0 or 1 rows with the outputConfs table record for the job, if any.
  SQL_PATTERN_selectJobOutputsByJobName = "select outputConfs.* from jobs, outputConfs, job2config where jobs.name = '{jobName}' and job2config.job_id = jobs.id and outputConfs.id = job2config.outputConf_id"
  def selectJobOutputsByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobOutputsByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the settingsConfs table record for a job using the job's id. Not all jobs
  # need have settingsConfs. So empty result set is correct for certain classes of jobs.
  # [+id+]  ID in the jobs table for the job
  # [+returns+] Result set with 0 or 1 rows with the settingsConfs table record for the job, if any.
  SQL_PATTERN_selectJobSettingsByJobId = "select settingsConfs.* from settingsConfs, job2config where job2config.job_id = '{jobId}' and settingsConfs.id = job2config.settingsConf_id"
  def selectJobSettingsByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobSettingsById.dup()
      sql.gsub!(/\{jobId\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the settingsConfs table record for a job using the job's unique name. Not all jobs
  # need have settingsConfs. So empty result set is correct for certain classes of jobs.
  # [+iname+]   Unique name for the job
  # [+returns+] Result set with 0 or 1 rows with the settingsConfs table record for the job, if any.
  SQL_PATTERN_selectJobSettingsByJobName = "select settingsConfs.* from jobs, settingsConfs, job2config where jobs.name = '{jobName}' and job2config.job_id = jobs.id and inputConfs.id = job2config.settingsConf_id"
  def selectJobSettingsByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobSettingsByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the contextConfs table record for a job using the job's id. Not all jobs
  # need have contextConfs. So empty result set is correct for certain classes of jobs.
  # [+id+]  ID in the jobs table for the job
  # [+returns+] Result set with 0 or 1 rows with the contextConfs table record for the job, if any.
  SQL_PATTERN_selectJobContextByJobId = "select contextConfs.* from inputConfs, job2config where job2config.job_id = '{jobId}' and contextConfs.id = job2config.contextConf_id"
  def selectJobContextByJobId(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobContextById.dup()
      sql.gsub!(/\{jobId\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the contextConfs table record for a job using the job's unique name. Not all jobs
  # need have contextConfs. So empty result set is correct for certain classes of jobs.
  # [+iname+]   Unique name for the job
  # [+returns+] Result set with 0 or 1 rows with the contextConfs table record for the job, if any.
  SQL_PATTERN_selectJobContextByJobName = "select contextConfs.* from jobs, contextConfs, job2config where jobs.name = '{jobName}' and job2config.job_id = jobs.id and contextConfs.id = job2config.contextConf_id"
  def selectJobContextByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobInputsByJobName.dup()
      sql.gsub!(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get the names of jobType jobs in the prequeue destined for the batch system of type systemType running on host.
  # Optionally only get jobs whose status is one of the ones in statuses.
  # The combination of batch system host, batch system type, and the job id assigned by that
  # batch system can uniquely identify a job in the prequeue.
  # [+host+]        String with the batch system host where job is queued, running, or ran.
  # [+systemType+]  String with the batch system type at that host where job is queued, running, or ran
  # [+systemJobId+] String with the job id the batch system assigned to the job once queued there.
  # [+statuses+]    [Optional; default nil] Array of recognized statuses which the jobs must have.
  # [+returns+]     Result set with  rows contianing the approprate job names.
  SQL_PATTERN_selectJobNamesBySystemInfoAndJobType = "select jobs.name from jobs, systemInfos, systems, job2config where systems.host = '{host}' and systems.type = '{systemType}' and jobs.type = '{jobType}' and jobs.id = job2config.job_id and systemInfos.id = job2config.systemInfo_id and systemInfos.system_id = systems.id "
  def selectJobNamesBySystemInfoAndJobType(host, systemType, jobType, statuses=nil)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectJobNamesBySystemInfoAndJobType.dup()
      sql = sql.gsub(/\{host\}/, mysql2gsubSafeEsc(host.to_s))
      sql = sql.gsub(/\{systemType\}/, mysql2gsubSafeEsc(systemType.to_s)).gsub(/\{jobType\}/, mysql2gsubSafeEsc(jobType.to_s))
      if(statuses)
        statusSet = DBUtil.makeMysql2SetStr(statuses)
        sql << " and jobs.status in #{statusSet} "
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sql:\n#{sql.inspect}\n\n")
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Selects job ids (result set is a 1 column table with the ids) based on a number of possible selection filters.
  # Can also customize the sort order of the rows a little by affecting the "order by" and "group by" SQL clauses.
  #
  # Bother the filters and the outputParams arguments take *Hashes* with predefined Symbols as keys. In some cases,
  # the value must be something specific as well (esp. for data ranges)
  #
  # By default in the WHERE clause, the SQL for each filter is "and" with the SQL for the other filters. You can make it
  # "or" by setting booleanOp=:or
  #
  # If a filter is not provided, then it is skipped (any value for the column is fine).
  #
  # If a filter can take a single value or an Array of values, the single value is faster than a degenerate Array.
  #   - i.e. 'toolIdSts' => [ 'fileCopier' ] is slower than just doing 'toolIdStrs' => 'fileCopier', although both will work.
  #
  #   filters Hash Documentation:
  #    'users'         => A single userId or an Array of users. Typically for normal use, will just be the *requesting* user's id.
  #                          Unlike other filters, this MUST be set to something. No default.
  #    'toolIdStrs'      => A single toolIdStr or an Array of toolIdStrs. Must match a WorkbenchJobHelper::TOOL_ID for one of the tools, really.
  #    'statuses'        => A single status or an Array of statuses where the statuses must be one of the supported ones, as a Symbol.
  #                         See JOB_STATUSES constant above.
  #    'entryDateRange'  => A 2-column Array specifying the date range, [ startTime, stopTime ].
  #                         Values in the columns must be either a Time object or nil.
  #                         A nil start or end indicates an open range and will be converted appropriately internally.
  #    'submitDateRange' => A 2-column Array specifying the date range, [ startTime, stopTime ].
  #                         Values in the columns must be either a Time object or nil.
  #                         A nil start or end indicates an open range and will be converted appropriately internally.
  #    'execStartDateRange' => A 2-column Array specifying the date range, [ startTime, stopTime ].
  #                         Values in the columns must be either a Time object or nil.
  #                         A nil start or end indicates an open range and will be converted appropriately internally.
  #    'execStopDateRange' => A 2-column Array specifying the date range, [ startTime, stopTime ].
  #                         Values in the columns must be either a Time object or nil.
  #                         A nil start or end indicates an open range and will be converted appropriately internally.
  #
  #   outputParams Hash Documentation:
  #     'grouping' => One of 'none', 'status', 'toolId'. Used for SQL "group by" clause. Independent of sorting which occurs within groups. Default is 'none'.
  #     'sortBy'   => Onew of 'newestFirst', 'oldestFirst'. Applied to the entryDate. Default is 'newestFirst'.
  #
  SQL_PATTERN_selectJobsByFilters = "select jobs.id from jobs "
  DEFAULT_OUTPUT_PARAMS = { 'grouping' => 'none', 'sortBy' => 'newestFirst' }
  DATE_RANGE_TYPE_TO_TABLE_NAME = { 'entryDateRange' => 'entryDate', 'submitDateRange' => 'submitDate', 'execStartDateRange' => 'execStartDate', 'execStopDateRange' => 'execEndDate', 'execEndDateRange' => 'execEndDate'}
  DEFAULT_JOB_FILTERS =   { 'users' => nil, 'toolIdStrs' => nil, 'statuses' => nil, 'entryDateRange' => nil, 'submitDateRange' => nil, 'execStartDateRange' => nil, 'execStopDateRange' => nil, 'execEndDateRange' => nil, 'toolTypes' => nil, 'systemTypes' => nil }
  def selectJobIdsByFilters(filters={}, outputParams={}, booleanOp=:and)
    t1 = Time.now
    raise ArgumentError, "ERROR: booleanOp argument must be one of :and or :or" unless(booleanOp == :and or booleanOp == :or)
    # First, merge provided filters & outputParam configs with defaults
    outputParams = DEFAULT_JOB_FILTERS.dup.merge(outputParams)
    filters = DEFAULT_JOB_FILTERS.dup.merge(filters)
    # How many non-nil filters are there?
    numFilters = filters.count { |kk, vv| !vv.nil? }
    # Local variables for access efficiency
    booleanOpStr = booleanOp.to_s
    dates = {}
    sortBy, grouping = outputParams['sortBy'], outputParams['grouping']
    sortByCols = (filters['sortByCols'] || [ 'entryDate'] )
    users, toolIdStrs, statuses, toolTypes, systemTypes, entryDateRange, submitDateRange, execStartDateRange, execStopDateRange = filters['users'], filters['toolIdStrs'], filters['statuses'], filters['toolTypes'], filters['systemTypes']
    # Build SQL
    client = getMysql2Client(:otherDB)
    sql = SQL_PATTERN_selectJobsByFilters.dup
    # Add WHERE clause(s) based on filters
    seenFirstWhereClause = false
    if(numFilters > 0)
      # Are we filtering based on systemType?
      if(filters['systemTypes'])
        # Then we need to add some tables and joins to our query first
        sql << ", systemInfos, systems, job2config where jobs.id = job2config.job_id and systemInfos.id = job2config.systemInfo_id and systemInfos.system_id = systems.id "
        seenFirstWhereClause = true
      else # No more tables needed, just start the where-based filters
        sql << " where "
      end
      # - MATCH: users
      if(users)
        sql << " #{booleanOpStr} " if(seenFirstWhereClause)
        if(users.is_a?(Array))
          sqlSetStr = DBUtil.makeMysql2SetStr(users)
          sql << " user in #{sqlSetStr}"
          seenFirstWhereClause = true
        elsif(!users.nil?)
          sql << " user = '#{mysql2gsubSafeEsc(users)}'"
          seenFirstWhereClause = true
        else
          raise ArgumentError, "ERROR: filters['users'] MUST be set to at least one user id. Typically the id of the user who is making the request, in order to return their jobs in the list."
        end
      end
      # - MATCH: toolIdStrs
      if(toolIdStrs)
        sql << " #{booleanOpStr} " if(seenFirstWhereClause)
        if(toolIdStrs.is_a?(Array))
          sqlSetStr = DBUtil.makeMysql2SetStr(toolIdStrs)
          sql << " toolId in #{sqlSetStr}"
          seenFirstWhereClause = true
        else
          sql << " toolId = '#{mysql2gsubSafeEsc(toolIdStrs)}'"
          seenFirstWhereClause = true
        end
      end
      # - MATCH: statuses
      if(statuses)
        sql << " #{booleanOpStr} " if(seenFirstWhereClause)
        if(statuses.is_a?(Array))
          # validate correct first
          statuses.each { |status|
            unless(JOB_STATUSES.key?(status))
              raise ArgumentError, "ERROR: values for statuses arg ('#{statuses.inspect}') in #{__method__} must all be one of these #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}"
            end
          }
          sqlSetStr = DBUtil.makeMysql2SetStr(statuses)
          sql << " status in #{sqlSetStr}"
          seenFirstWhereClause = true
        else
          unless(JOB_STATUSES.key?(statuses))
            raise ArgumentError, "ERROR: values for statuses arg ('#{statuses.inspect}') in #{__method__} must all be one of these #{JOB_STATUSES.keys.map { |xx| xx.inspect }.join(', ')}"
          end
          sql << " status = '#{mysql2gsubSafeEsc(statuses)}'"
          seenFirstWhereClause = true
        end
      end
      # - MATCH: within some range ... entryDateRange, submitDateRange, execStartDateRange, execStartDateRange
      [ 'entryDateRange', 'submitDateRange', 'execStartDateRange', 'execStopDateRange', 'execEndDateRange' ].each { |dateType|
        dateRange = filters[dateType]
        if(dateRange)
          argError = false
          if(dateRange.is_a?(Array) and dateRange.size == 2)
            # If [ nil, nil ] then there is really no point--open range on both ends. No SQL filter to add, so skip.
            unless(dateRange.first.nil? and dateRange.last.nil?)
              # As long as we're dealing with correct values (nil or Time objs) in the range, we're good; else error
              if((dateRange.first.nil? or dateRange.first.is_a?(Time)) and (dateRange.last.nil? or dateRange.last.is_a?(Time)))
                # Start time as SQL datetime string
                if(dateRange.first.nil?) # then any start date (we'll use a few hours before start of unix epoch)
                  startTimeStr = JOB_DEFAULT_TIME_STR
                else
                  startTimeStr = dateRange.first.strftime("%Y-%m-%d %H:%M:%S")
                end
                # Stop time as SQL datetime string
                if(dateRange.last.nil?)  # then any stop date (we'll use 24 hours from right now)
                  stopTimeStr = (Time.now() + 86400).strftime("%Y-%m-%d %H:%M:%S")
                else
                  stopTimeStr = dateRange.last.strftime("%Y-%m-%d %H:%M:%S")
                end
                # add sql filter
                sql << " #{booleanOpStr} " if(seenFirstWhereClause)
                sql << " #{DATE_RANGE_TYPE_TO_TABLE_NAME[dateType]} between '#{startTimeStr}' and '#{stopTimeStr}' "
                seenFirstWhereClause = true
              else
                argError = true
              end
            end
          else
            argError = true
          end
          # Did we hit some sort of argument error?
          raise ArgumentError, "ERROR: date ranges provided via the #{dateType} argument MUST be 2-column [ startTime, stopTime ] Arrays. Use nil for open-ended ranges, else provide Time objects as usual." if(argError)
        end
      }
      # - MATCH: toolTypes
      if(toolTypes)
        sql << " #{booleanOpStr} " if(seenFirstWhereClause)
        toolTypes = [ toolTypes ] unless(toolTypes.is_a?(Array))
        # validate correct first
        toolTypes.each { |toolType|
          unless(JOB_TYPES.key?(toolType))
            raise ArgumentError, "ERROR: values for toolTypes arg ('#{toolTypes.inspect}') in #{__method__} must all be one of these #{JOB_TYPES.keys.map { |xx| xx.inspect }.join(', ')}"
          end
        }
        sqlSetStr = DBUtil.makeMysql2SetStr(toolTypes)
        sql << " jobs.type in #{sqlSetStr}"
        seenFirstWhereClause = true
      end
      # - MATCH: systemTypes
      if(systemTypes)
        sql << " #{booleanOpStr} " if(seenFirstWhereClause)
        systemTypes = [ systemTypes ] unless(systemTypes.is_a?(Array))
        sqlSetStr = DBUtil.makeMysql2SetStr(systemTypes)
        sql << " systems.type in #{sqlSetStr}"
        seenFirstWhereClause = true
      end
    end
    # - grouping
    if(grouping and grouping != 'none')
      if(grouping == 'status')
        sql << " group by status"
      elsif(grouping == 'toolId')
        sql << " group by toolId"
      else
        raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'"
      end
    end
    # - sortByCols
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sortByCols: #{sortByCols.inspect}")
    if(sortByCols)
      direction = " desc "
      if(sortBy)
        raise ArgumentError, "ERROR: the sortBy argument must contain either 'newestFirst' or 'oldestFirst'" unless(sortBy == 'newestFirst' or sortBy == 'oldestFirst')
        direction = ((sortBy == 'oldestFirst') ? '' : ' desc ')
      end
      sortByCols = [ sortByCols ] if(sortByCols.is_a?(String))
      sql << " order by "
      sortByCols.each_index { |ii|
        col = sortByCols[ii]
        sql << col
        sql << " #{direction}" if(col =~ /date$/i)
        sql << ", " unless(ii >= (sortByCols.size - 1))
      }
    end
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "sql:\n    #{sql.inspect}")
    # Execute sql
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      resultSet = client.query(sql, :cast_booleans => true)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "---> QUERIED SQL (#{Time.now - t1} secs)") ; t1 = Time.now
      retVal = resultSet.entries
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "---> GOT resultSet.entries (#{Time.now - t1} secs)") ; t1 = Time.now
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Update the systemJobId for a particular job. Most often used to set the systemJobId returned by the batch system
  # once the job has been submited to that system.
  # [+name+]    The name of the job to set the systemJobId for.
  # [+returns+] Fixnum indicating the number of records updated.
  SQL_PATTERN_updateSystemInfoSystemJobIdByJobName = "update jobs, systemInfos, job2config set systemInfos.systemJobId = ? where jobs.name = ? and jobs.id = job2config.job_id and systemInfos.id = job2config.systemInfo_id"
  def updateSystemInfoSystemJobIdByJobName(name, systemJobId=nil)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(SQL_PATTERN_updateSystemInfoSystemJobIdByJobName)
      stmt.execute(systemJobId, name)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_SYSTEMINFO_SYSTEMJOBID_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
