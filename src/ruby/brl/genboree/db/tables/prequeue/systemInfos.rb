require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: systemInfos
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_SYSTEMINFO_BY_ID = 'update systemInfos set queue = ?, systemJobId = ?, directives = ? where id = ?'
  UPDATE_SYSTEMINFO_systemJobId_BY_ID = 'update systemInfos set systemJobId = ? where id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get systemInfos record by its id
  # [+id+]      The ID of the systemInfos record to return
  # [+returns+] Array of 0 or 1 systemInfos  rows
  def selectSystemInfoById(id)
    return selectByFieldAndValue(:otherDB, 'systemInfos', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get SystemInfos records using a list of ids
  # [+ids+]     Array of systemInfos IDs
  # [+returns+] Array of 0+ systemInfos records
  def selectSystemInfosByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'systemInfos', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get SystemInfo record using the unique combination of host & type & systemJobId.
  # - host & type get us the systems table record FK system_id
  # - within systemInfos, together systemJobId and system_id is unique
  #   . i.e. the systemJobId is unique only for a specific batch system identified by host and type
  # The combination of batch system host, batch system type, and the job id assigned by that
  # batch system can uniquely identify a job in the prequeue.
  # [+host+]        String with the batch system host where job is queued, running, or ran.
  # [+systemType+]  String with the batch system type at that host where job is queued, running, or ran
  # [+systemJobId+] String with the job id the batch system assigned to the job once queued there.
  # [+returns+]     Result set with 0 or 1 systemInfos records.
  SQL_PATTERN_selectSystemInfoByHostTypeAndSystemJobId =
    " select systemInfos.* from systemInfos, systems
      where systems.host = '{host}'
      and systems.type = '{systemType}'
      and systemInfos.systemJobId = '{systemJobId}'
      and systems.id = systemInfos.system_id "
  def selectSystemInfoByHostTypeAndSystemJobId(host, systemType, systemJobId)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectSystemInfoByHostTypeAndSystemJobId.dup()
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

  # Get systemInfos + systems info together in one record for a given systemInfos record. It is
  # common to want both the job-specific systemInfos data and the system-wide data together for convenience.
  # [+id+]  ID of the systemInfos record for which to get the complete system info.
  # [+returns+] Result set with 0 or more rows containing all the columns in systemInfos table plus host, type, and adminEmails from systems table.
  SQL_PATTERN_selectFullSystemInfoById =
    " select systemInfos.*, systems.host, systems.type, systems.adminEmails from systemInfos, systems
      where systemInfos.id = '{id}'
      and systems.id = systemInfos.system_id "
  def selectFullSystemInfoById(id)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectFullSystemInfoById.dup()
      sql = sql.gsub(/\{id\}/, mysql2gsubSafeEsc(id.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Get systemInfos + systems info together in one record for a given systemInfos record. It is
  # common to want both the job-specific systemInfos data and the system-wide data together for convenience.
  # The combination of batch system host, batch system type, and the job id assigned by that
  # batch system can uniquely identify a job in the prequeue.
  # [+host+]        String with the batch system host where job is queued, running, or ran.
  # [+systemType+]  String with the batch system type at that host where job is queued, running, or ran
  # [+systemJobId+] String with the job id the batch system assigned to the job once queued there.
  # [+returns+] Result set with 0 or more rows containing all the columns in systemInfos table plus host, type, and adminEmails from systems table.
  SQL_PATTERN_selectFullSystemInfoByHostTypeAndSystemJobId =
    " select systemInfos.*, systems.host, systems.type, systems.adminEmails from systemInfos, systems
      where systems.host = '{host}'
      and systems.type = '{systemType}'
      and systemInfos.systemJobId = '{systemJobId}'
      and systems.id = systemInfos.system_id "
  def selectFullSystemInfoByHostTypeAndSystemJobId(host, systemType, systemJobId)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectFullSystemInfoByHostTypeAndSystemJobId.dup()
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

  # Get systemInfos + systems info together in one record for a given systemInfos record. It is
  # common to want both the job-specific systemInfos data and the system-wide data together for convenience.
  # [+name+]    Unique job name associated with the systemInfos record for which to get the complete system info.
  # [+returns+] Result set with 0 or more rows containing all the columns in systemInfos table plus host, type, and adminEmails from systems table.
  SQL_PATTERN_selectFullSystemInfoByJobName=
    " select systemInfos.*, systems.host, systems.type, systems.adminEmails from jobs, job2config, systemInfos, systems
      where jobs.name = '{jobName}'
      and jobs.id = job2config.job_id
      and systemInfos.id = job2config.systemInfo_id
      and systems.id = systemInfos.system_id "
  def selectFullSystemInfoByJobName(name)
    retVal = nil
    begin
      client = getMysql2Client(:otherDB)
      # Make sql
      sql = SQL_PATTERN_selectFullSystemInfoByJobName.dup()
      sql = sql.gsub(/\{jobName\}/, mysql2gsubSafeEsc(name.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue false
    end
    return retVal
  end

  # Insert a new SystemInfo record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+host+]  The host FQDN for the system the info is valid at
  # [+type+]  The type of system at that host.
  # [+queue+]       Name of the "queue" (or resource category/set) to submit the job to.
  # [+directives+]  [optiona] Json Hash of batch system-specific directives in the form of directive => value
  # [+systemJobId+] [optional] The id the SYSTEM assigned to the job. Often nil initially and then filled
  #                   in with an update upon successful submission.
  # [+systemRecId+] [optional] The id in the systems table of the record associated with host and type, if known. If not, determined dynamically.
  # [+returns+]       Number of rows inserted
  def insertSystemInfo(host, type, queue, directives=nil, systemJobId=nil, systemRecId=nil)
    # First, we need the system row matching host & type
    rows = selectSystemByHost(host, type)
    raise "ERROR: there is no batch system configured of type #{type.inspect} at #{host.inspect}." unless(rows and !rows.empty?)
    systemId = rows.first['id']
    data = [ queue, systemJobId, directives, systemId ]
    return insertRecords(:otherDB, 'systemInfos', data, true, 1, 4, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a SystemInfo record identified by its id.
  # - If you just want to update to provide the systemJobId, there's a dedicated method for that
  # - Usually you want the other method, unless you need to change the queue for some reason...
  # [+id+]            SystemInfos.id of the record to update
  # [+queue+]         Name of the "queue" (or resource category/set) to submit the job to.
  # [+directives+]  Json Hash of batch system-specific directives in the form of directive => value
  # [+systemJobId+]  The jobId the SYSTEM assigned to the job. Often nil initially and then filled
  #                   in with an update upon successful submission.
  # [+returns+]       Number of rows updated
  def updateSystemInfoById(id, queue, directives=nil, systemJobId=nil)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_SYSTEMINFO_BY_ID)
      stmt.execute(queue, systemJobId, directives, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_SYSTEMINFO_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the systemJobId field of a SystemInfo record identified by its id.
  # [+id+]            SystemInfos.id of the record to update
  # [+systemJobId+]  The jobId the SYSTEM assigned to the job.
  # [+returns+]       Number of rows updated
  def updateSystemInfoSystemJobIdById(id, systemJobId=nil)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_SYSTEMINFO_systemJobId_BY_ID)
      stmt.execute(systemJobId, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_SYSTEMINFO_systemJobId_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a SystemInfo record using its id.
  # [+id+]      The systemInfos.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteSystemInfoById(id)
    return deleteByFieldAndValue(:otherDB, 'systemInfos', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete SystemInfo records using their ids.
  # [+ids+]     Array of systemInfos.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteSystemInfosByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'systemInfos', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
