require 'brl/genboree/dbUtil'

module BRL; module Genboree

# We refer to "redminePrj" as the entity with
#   Ruby "groupId" -> SQL "group_id" (linked to genboreegroup table)
#   Ruby "projectId" => SQL "project_id" (associated with redmine http api)
#   Ruby "url" => SQL "url" (location of redmine http api)
module DB; module Tables; module RedminePrjs

  # --------------------------------------------------
  # Select queries - {{
  # --------------------------------------------------

  # @note one group may have many projects
  # @see [BRL::Genboree::DBUtil#selectByFieldAndValue]
  def selectRedminePrjsByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'redminePrjs', 'group_id', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # @note a project has 0 or 1 groups
  # @see [BRL::Genboree::DBUtil#selectByFieldAndValue]
  def selectRedminePrjByProjectId(projectId)
    return selectByFieldAndValue(:mainDB, 'redminePrjs', 'project_id', projectId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # @see [BRL::Genboree::DBUtil#selectByMultipleFieldsAndValues]
  def selectRedminePrjByGroupIdAndProjectId(groupId, projectId)
    selectCond = {
      "group_id" => groupId,
      "project_id" => projectId
    }
    booleanOp = :and
    return selectByMultipleFieldsAndValues(:mainDB, 'redminePrjs', selectCond, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select redminePrjs from a list of given projectIds
  # @note this table performs a join to return group names instead of group ids in the result set
  def selectRedminePrjsByProjectIds(projectIds)
    sql = 'select t1.groupName, t2.project_id from genboreegroup as t1, redminePrjs as t2 where t1.groupId = t2.group_id and project_id not in '
    tableType = :mainDB
    errMsg = "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():"
    extraOpts = nil
    retVal = nil
    begin
      client = getMysql2Client(tableType)
      sql << DBUtil.makeMysql2SetStr(projectIds)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
    ensure
      client.close
    end
    return retVal
  end

  # }} -

  # ----------------------------------------
  # Insert/update queries - {{
  # ----------------------------------------

  # @see insertRedminePrjs
  def insertRedminePrj(groupId, projectId, url)
    data = [groupId, projectId, url]
    insertRedminePrjs(data, 1)
  end

  # @see [BRL::Genboree::DBUtil#insertRecords]
  def insertRedminePrjs(data, numMaps)
    insertRecords(:mainDB, 'redminePrjs', data, true, numMaps, 3, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # @see [BRL::Genboree::DBUtil#updateByMultipleFieldsAndValues]
  def updateRedminePrjIdAndUrlByGroupIdAndPrjId(newProjectId, url, groupId, oldProjectId)
    setData = {
      "project_id" => newProjectId,
      "url" => url
    }
    whereData = {
      "group_id" => groupId,
      "project_id" => oldProjectId
    }
    booleanOp = :and
    updateByMultipleFieldsAndValues(:mainDB, 'redminePrjs', setData, whereData, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # @see [BRL::Genboree::DBUtil#updateByMultipleFieldsAndValues]
  def updateRedminePrjUrlByGroupIdAndPrjId(url, groupId, projectId)
    setData = {
      "url" => url
    }
    whereData = {
      "group_id" => groupId,
      "project_id" => projectId
    }
    booleanOp = :and
    updateByMultipleFieldsAndValues(:mainDB, 'redminePrjs', setData, whereData, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # }} -

  # --------------------------------------------------
  # Delete queries - {{
  # --------------------------------------------------

  # Delete a Redmine project/Genboree group association by the unique Redmine project identifier
  # @see BRL::DB::DBUtil#deleteByFieldAndValue
  def deleteRedminePrjByPrjId(projectId)
    deleteByFieldAndValue(:mainDB, 'redminePrjs', 'project_id', projectId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # }} -

end; end; end

class DBUtil
  include DB::Tables::RedminePrjs
end
end; end
