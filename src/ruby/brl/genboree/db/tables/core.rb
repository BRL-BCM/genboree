require 'uri'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# CORE GENBOREE TABLES - DBUtil Extension Methods for dealing with Main Genboree tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # ------------------------------------------------------------------
  # MIXINS - bring in some generic useful methods used here and elsewhere
  # ------------------------------------------------------------------
  include BRL::Cache::Helpers::DNSCacheHelper

  # --------
  # Table: databaseHost
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def getHostForDbName(dbName)
    return selectFieldsByFieldAndValue(:mainDB, 'database2host', [ 'databaseHost' ], false, 'databaseName', dbName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def deleteDatabase2HostRecByDatabaseName(dbName)
    return deleteByFieldAndValue(:mainDB, 'database2host', 'databaseName', dbName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
  # --------
  # Table: genboreeuser
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_USER = 'insert into genboreeuser values (NULL, ?, ?, ?, ?, ?, ?, ?)'
  UPDATE_USER_BY_USERID = "update genboreeuser set name = ?, firstName = ?, lastName = ?, institution = ?, email = ?, phone = ? where userId = ?"
  UPDATE_LOGIN_AND_PASS_BY_USERID = "update genboreeuser set name = ?, password = ? where userId = ?"
  # ############################################################################
  # METHODS
  # ############################################################################
  def getUserByUserId(userId)
    return selectByFieldAndValue(:mainDB, 'genboreeuser', 'userId', userId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get user records based on email
  # May return more than one record if there are 2 users with same email (since email is not a unique key??)
  # [+email+]
  # [+retVal+] Array of 0+ records
  def getUserByEmail(email)
    return selectByFieldAndValue(:mainDB, 'genboreeuser', 'email', email, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getUserByFirstAndLastName(fName, lName)
    return selectByMultipleFieldsAndValues(:mainDB, 'genboreeuser', { 'firstName' => fName, 'lastName' => lName }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getUserByName(userName)
    return selectByFieldAndValue(:mainDB, 'genboreeuser', 'name', userName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getUsersByUserNames(userNames)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreeuser', 'name', userNames, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getUsersByUserIds(userIds)
    return selectByFieldWithMultipleValues(:mainDB, 'genboreeuser', 'userId', userIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SQL_PATTERN_getUsersByGroupId = "select genboreeuser.* from genboreeuser, usergroup where usergroup.userId = genboreeuser.userId and usergroup.groupId = '{groupId}' "
  def getUsersByGroupId(groupId, orderBy='')
    client = retVal = sql = nil
    begin
      client = getMysql2Client()
      sql = SQL_PATTERN_getUsersByGroupId.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      unless(orderBy.empty?)
        sql += " order by #{orderBy}"
      end
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SQL_PATTERN_getUsersWithRolesByGroupId = "select genboreeuser.*, usergroup.userGroupAccess from genboreeuser, usergroup where usergroup.userId = genboreeuser.userId and usergroup.groupId = '{groupId}'"
  def getUsersWithRolesByGroupId(groupId, orderBy='')
    client = retVal = sql = nil
    begin
      client = getMysql2Client()
      sql = SQL_PATTERN_getUsersWithRolesByGroupId.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      unless(orderBy.empty?)
        sql += " order by #{orderBy}"
      end
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close  rescue nil
    end
    return retVal
  end

  GET_GROUPS_DBS_BY_USERID_SQL =  "select usergroup.groupId, genboreegroup.groupName, refseq.refSeqId, refseq.refseqName, refseq.databaseName " +
                                  "from usergroup, genboreegroup, refseq, grouprefseq " +
                                  "where usergroup.userId = '{userId}' and " +
                                  "usergroup.groupId = genboreegroup.groupId and " +
                                  "grouprefseq.groupId = usergroup.groupId and " +
                                  "refseq.refSeqId = grouprefseq.refSeqId "
  def getGroupsDbsByUserId(userId)
    client = retVal = sql = nil
    begin
      client = getMysql2Client()
      sql = GET_GROUPS_DBS_BY_USERID_SQL.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close  rescue nil
    end
    return retVal
  end

  GET_GROUPS_DBS_BY_USERID_AND_TEMPLATE_VERSION_SQL =
    "select usergroup.groupId, genboreegroup.groupName, refseq.refSeqId, refseq.refseqName, refseq.databaseName " +
    "from usergroup, genboreegroup, refseq, grouprefseq, genomeTemplate " +
    "where " +
    "usergroup.userId = '{userId}' and genomeTemplate.genomeTemplate_version = '{templateVersion}' and " +
    "usergroup.groupId = genboreegroup.groupId and " +
    "grouprefseq.groupId = usergroup.groupId and " +
    "refseq.refSeqId = grouprefseq.refSeqId and " +
    "refseq.FK_genomeTemplate_id = genomeTemplate.genomeTemplate_id "
  def getGroupsDbsByUserIdAndTemplateVersion(userId, templateVersion=nil)
    client = retVal = sql = nil
    begin
      client = getMysql2Client()
      sql = GET_GROUPS_DBS_BY_USERID_AND_TEMPLATE_VERSION_SQL.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      sql = sql.gsub(/\{templateVersion\}/, mysql2gsubSafeEsc(templateVersion.to_s))
      recs = client.query(sql)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  def updateLoginAndPassByUserId(name, password, userId)
    retVal = nil
    begin
      connectToMainGenbDb()                           # Lazy connect to main database
      stmt = @genbDbh.prepare(UPDATE_LOGIN_AND_PASS_BY_USERID) # Prep the stmt
      stmt.execute(name, password, userId)                            # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateLoginAndPassByUserId():", @err, UPDATE_LOGIN_AND_PASS_BY_USERID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateUserByUserId(name, firstName, lastName, institution, email, phone, userId)
    retVal = nil
    begin
      connectToMainGenbDb()                           # Lazy connect to main database
      stmt = @genbDbh.prepare(UPDATE_USER_BY_USERID) # Prep the stmt
      stmt.execute(name, firstName, lastName, institution, email, phone, userId)                            # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateUserByUserId():", @err, UPDATE_USER_BY_USERID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertUserRec(name, password, firstName, lastName, institution, email, phone)
    retVal = nil
    begin
      connectToMainGenbDb()                           # Lazy connect to main database
      stmt = @genbDbh.prepare(INSERT_USER) # Prep the stmt
      stmt.execute(name, password, firstName, lastName, institution, email, phone)                            # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertUserRec():", @err, INSERT_USER)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: externalHostAccess
  # --------
  ############################################################################
  # CONSTANTS
  # ##########################################################################
  UPDATE_EXTERNAL_HOST_RECORD = 'insert into externalHostAccess values (null, ?, ?, ?, ?, ?) on duplicate key update login=values(login), password=values(password)'
  # ############################################################################
  # METHODS
  # ############################################################################
  # NOTE: We want to avoid confusion and unnecessary entries (or selection results)
  #       given that there can be multiple valid domain names for a single Genboree instance.
  #       (e.g. "genboree.org", "brl.bcm.tmc.edu", "www.genboree.org", "snprc.genboree.org" are all same IP!)
  #       - We will make simplifying assumptions:
  #         . the domain name for a Genboree instance corresponds to a "canonical" IP address that can be used instead
  #         . the host name retrieved for that IP address is the Genboree instance's domain name
  #         . i.e. ipOf(name) = ipof(nameOf(ipOf(name)))
  #         . i.e. no IP-multihosting!
  #         . but a single instance can support multiple (hostName, IP) tuples.
  #       - Corollary: any gets/selects using a host will be done using the *canonical* address column
  #       - Corollary: checking if there is already an entry for host needs to be done using the *canonical* address
  #       - Corolllary: only one entry per user per *canonical* address
  #       - Corollary: any inserts are done using the *canonical* address
  #
  # TODO: insert an externalHostAccess record.
  #       - insert for both the canoncialName of host AND any domain alias of host AND any domain alias of canoncialName (if different)
  #
  def getExternalHostInfoByHostAndUserId(host, userId, tryExactHostMatch=false)
    retVal = nil
    if(tryExactHostMatch) # then don't use canonical address normalization...try to match host as-is
      retVal = selectByMultipleFieldsAndValues(:mainDB, 'externalHostAccess', { 'host' => host, 'userId' => userId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    else
      # Get canonical address for host; going to query by canonicalAddress
      canonicalAddress = self.class.canonicalAddress(host)
      retVal = selectByMultipleFieldsAndValues(:mainDB, 'externalHostAccess', { 'canonicalAddress' => canonicalAddress, 'userId' => userId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    return retVal
  end

  def getExternalHostsByUserId(userId)
    return selectFieldsByFieldAndValue(:mainDB, 'externalHostAccess', [ 'host' ], true, 'userId', userId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getAllExternalHostInfoByUserId(userId)
    return selectByFieldAndValue(:mainDB, 'externalHostAccess', 'userId', userId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Handles both insert of new record or update of existing record.
  # - Will use self.class.canonicalAddress(host) to determine the canonical address of host
  # - Should return 1 if new record inserted or 2 (~delete + insert) if existing record updated
  def updateExternalHostInfoRecord(userId, host, remoteLogin, remotePass, tryExactHostMatch=false)
    retVal = nil
    begin
      if(tryExactHostMatch) # then don't use canonical address normalization...try to match host as-is
        canonicalAddress = host
      else
        # Get canonical address for host; going to query by canonicalAddress
        canonicalAddress = self.class.canonicalAddress(host)
      end
      # Do insert
      connectToMainGenbDb()                                 # Lazy connect to main database
      stmt = @genbDbh.prepare(UPDATE_EXTERNAL_HOST_RECORD)  # Prep the stmt
      stmt.execute(userId, host, canonicalAddress, remoteLogin, remotePass)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename(__FILE__)}##{__method__}]: ", @err, UPDATE_EXTERNAL_HOST_RECORD)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Remove a remote access to a given host for a specific user
  # - Will use self.class.canonicalAddress(host) to determine the canonical address of host
  # - Should return 1 if record found and removed or 0 if record not found and not removed
  def deleteExternalHostInfoRecord(userId, host, tryExactHostMatch=false)
    retVal = nil
    if(tryExactHostMatch) # then don't use canonical address normalization...try to match host as-is
      retVal = deleteByMultipleFieldsAndValues(:mainDB, 'externalHostAccess', { 'userId' => userId, 'host' => host }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    else
      # Get canonical address for host; going to query by canonicalAddress
      canonicalAddress = self.class.canonicalAddress(host)
      retVal = deleteByMultipleFieldsAndValues(:mainDB, 'externalHostAccess', { 'userId' => userId, 'canonicalAddress' => canonicalAddress }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    return retVal
  end

  # --------
  # Table: genboreegroup
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_GROUP_BY_ID_SQL = 'select * from genboreegroup where groupId = ? '
  SELECT_GROUP_BY_NAME_SQL = 'select * from genboreegroup where groupName = ? '
  SELECT_GROUPS_BY_USERID_SQL = 'select genboreegroup.groupId, genboreegroup.groupName, genboreegroup.description from genboree.genboreegroup, genboree.usergroup where genboreegroup.groupId = usergroup.groupId and usergroup.userId = ?'
  UPDATE_GROUP_NAME_BY_ID_SQL = 'update genboreegroup set groupName = ? where groupId = ?'
  UPDATE_GROUP_DESCRIPTION_BY_ID_SQL = 'update genboreegroup set description = ? where groupId = ?'
  INSERT_GROUP_SQL = 'insert into genboreegroup (groupName, description) values (?, ?)'
  DELETE_GROUP_BY_GROUPID = "delete from genboreegroup where groupId = ? "
  # ############################################################################
  # METHODS
  # ############################################################################
  def getAllGroups()
    return selectAll(:mainDB, 'genboreegroup', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def deleteGroupByGroupId(groupId)
    return deleteByFieldAndValue(:mainDB, 'genboreegroup', 'groupId', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_GROUPS_BY_USERID_SQL = "select genboreegroup.groupId, genboreegroup.groupName, genboreegroup.description from genboree.genboreegroup, genboree.usergroup where genboreegroup.groupId = usergroup.groupId and usergroup.userId = '{userId}'"
  def getGroupNamesByUserId(userId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_GROUPS_BY_USERID_SQL.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  GROUP_NAMES_BY_USERID_SQL = "select genboreegroup.groupId, genboreegroup.groupName from genboree.genboreegroup, genboree.usergroup where genboreegroup.groupId = usergroup.groupId and usergroup.userId = '{userId}'"
  def getGroupsByUserId(userId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = GROUP_NAMES_BY_USERID_SQL.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Find the group record using a refSeqId.
  # [+refSeqId+] The refSeqId to find the group for
  # [+publicGroupId+] If non-nil, then provide the groupId of the public group in order to hide/remove if from the result records.
  SELECT_GROUPS_BY_REFSEQ_ID = "select genboreegroup.* from genboreegroup, grouprefseq where genboreegroup.groupId = grouprefseq.groupId and grouprefseq.refSeqId = '{refSeqId}'"
  def getGroupsByRefseqId(refSeqId, publicGroupIdToHide=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_GROUPS_BY_REFSEQ_ID.gsub(/\{refSeqId\}/, mysql2gsubSafeEsc(refSeqId.to_s))
      sql += " and grouprefseq.groupId != '#{mysql2gsubSafeEsc(publicGroupIdToHide.to_s)}'" if(publicGroupIdToHide.is_a?(Fixnum))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end


  SELECT_PUBLIC_GROUPS_SQL = 'select distinct genboreegroup.groupId, genboreegroup.groupName from genboreegroup join grouprefseq on genboreegroup.groupId = grouprefseq.groupId join refseq on refseq.refSeqId = grouprefseq.refSeqId where refseq.public = 1'
  SELECT_PUBLIC_GROUPS_REQUIRE_UNLOCKED_DBS_SQL = "select distinct genboreegroup.groupId, genboreegroup.groupName from refseq, grouprefseq, unlockedGroupResources, genboreegroup where grouprefseq.groupId = genboreegroup.groupId and grouprefseq.refSeqId = refseq.refSeqId and refseq.public = 1 and unlockedGroupResources.group_id = grouprefseq.groupId and unlockedGroupResources.resourceType='database' and unlockedGroupResources.resource_id=refseq.refSeqId"
  def getPublicGroups(requireUnlockedPublicDBs=false)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      if(requireUnlockedPublicDBs)
        sql = SELECT_PUBLIC_GROUPS_REQUIRE_UNLOCKED_DBS_SQL
      else
        sql = SELECT_PUBLIC_GROUPS_SQL
      end
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # This method gets the groups for a specified user and access level
  # +userId+ - the userId
  # +accessLevels+ - used to get groups with a specific access level.  The default is to return any group membership by specifying all levels.
  # +orderBy+ - default is groupName, specify empty string '' to not include order by in select statement
  def getGroupsByUserIdAndAccess(userId, accessLevels=['r', 'w', 'o'], orderBy='groupName')
    retVal = nil
    begin
      connectToMainGenbDb() # Lazy connect to main database
      userGroupAccessSql = "userGroupAccess = ?"
      appendSql = Array.new(accessLevels.size, userGroupAccessSql).join(' or ')
      selectStmt = GROUP_NAMES_BY_USERID_SQL.dup.to_s + ' and (' +  appendSql + ')'
      unless(orderBy.empty?)
        selectStmt += " order by #{orderBy}"
      end
      stmt = @genbDbh.prepare(selectStmt)  # Prep the stmt
      valuesArr = [userId] + accessLevels
      stmt.execute(*valuesArr) # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getGroupNamesByUserId():", @err, GROUP_NAMES_BY_USERID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateGroupNameById(groupId, groupName)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_GROUP_NAME_BY_ID_SQL)
      stmt.execute(groupName, groupId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateGroupNameById(): ", @err, UPDATE_GROUP_NAME_BY_ID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateGroupDescriptionById(groupId, groupDescription)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_GROUP_DESCRIPTION_BY_ID_SQL)
      stmt.execute(groupDescription, groupId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateGroupDescriptionById(): ", @err, UPDATE_GROUP_DESCRIPTION_BY_ID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: usergroup
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_ACCESS_BY_USERID_GROUPID_SQL = 'update usergroup set userGroupAccess = ? where userId = ? and groupId = ? '
  INSERT_USER_IN_GROUP_SQL = 'insert into usergroup (userId, groupId, userGroupAccess) values (?, ?, ?)'
  INSERT_IGNORE_USER_IN_GROUP_SQL = 'insert ignore into usergroup (userId, groupId, userGroupAccess) values (?, ?, ?)'
  # ############################################################################
  # METHODS
  # ############################################################################
  def getAccessByUserIdAndGroupId(userId, groupId)
    retVal = nil
    rows = selectFieldsByMultipleFieldsAndValues(:mainDB, 'usergroup', [ 'userGroupAccess' ], false, { 'userId' => userId, 'groupId' => groupId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = rows.first if(rows and !rows.empty?)
    return retVal
  end

  def getUsersInGroup(groupId)
    return selectByFieldAndValue(:mainDB, 'usergroup', 'groupId', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def updateAccessByUserIdAndGroupId(userId, groupId, access)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_ACCESS_BY_USERID_GROUPID_SQL)
      stmt.execute(access, userId, groupId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateAccessByUserIdAndGroupId(): ", @err, UPDATE_ACCESS_BY_USERID_GROUPID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertUserIntoGroupById(userId, groupId, permission='r')
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(INSERT_USER_IN_GROUP_SQL)
      stmt.execute(userId, groupId, permission)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertUserIntoGroup(): ", @err, INSERT_USER_IN_GROUP_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # userIds can be a single integer or an array of integers
  # returns the number of rows inserted
  def insertMultiUsersIntoGroupById(userIds, groupId, permission='r', ignoreDups=true)
    retVal = nil
    insertStmt = ignoreDups ? INSERT_IGNORE_USER_IN_GROUP_SQL.dup : INSERT_USER_IN_GROUP_SQL.dup
    begin
      connectToMainGenbDb()
      if (userIds.is_a?(Array))
        (userIds.length-1).times {insertStmt += ", (?, ?, ?)"}
        stmt = @genbDbh.prepare(insertStmt)
        valueArr = userIds.map { |userId| [userId, groupId, permission] }.flatten
        stmt.execute(*valueArr)
      else
        stmt = @genbDbh.prepare(insertStmt)
        stmt.execute(userIds, groupId, permission)
      end
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertUserIntoGroup(): ", @err, INSERT_USER_IN_GROUP_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  DELETE_ACCESS_BY_USERID_GROUPID_SQL = 'delete from usergroup where userId = ? and groupId = ? '
  def deleteUserFromGroup(userId, groupId)
    return deleteByMultipleFieldsAndValues(:mainDB, 'usergroup', { 'userId' => userId, 'groupId' => groupId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: grouprefseq
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def getAllgrouprefseqRecs()
    return selectAll(:mainDB, 'grouprefseq', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGroupRefSeqByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'grouprefseq', 'groupId', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGroupRefSeq(groupId, refSeqId)
    return selectByMultipleFieldsAndValues(:mainDB, 'grouprefseq', {'groupId'=>groupId, 'refSeqId'=>refSeqId}, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  SELECT_GROUPREFSEQ_BY_REFSEQ = "select * from grouprefseq where refSeqId = '{refSeqId}' order by groupRefSeqId" # order by ensure s canonical owner group is first (not Public, etc)
  def selectGroupRefSeqByRefSeqId(refSeqId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_GROUPREFSEQ_BY_REFSEQ.gsub(/\{refSeqId\}/, mysql2gsubSafeEsc(refSeqId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  CHECK_IF_DATABASE_PART_OF_GROUP =
    "select grouprefseq.groupId, grouprefseq.refseqId from grouprefseq, " +
    "genboreegroup, refseq where genboreegroup.groupName = '{groupName}' and " +
    "refseq.databaseName = '{databaseName}' and genboreegroup.groupId = grouprefseq.groupId " +
    "and refseq.refSeqId = grouprefseq.refSeqId"
  def checkIfDatabasePartOfGroup(groupName, databaseName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = CHECK_IF_DATABASE_PART_OF_GROUP.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      sql = sql.gsub(/\{databaseName\}/, mysql2gsubSafeEsc(databaseName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      rows = resultSet.entries
      retVal = rows.first if(rows and !rows.empty?)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  def insertGroupRefSeq(groupId, refSeqId)
    return insertRecords(:mainDB, 'grouprefseq', [groupId, refSeqId], true, 1, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def deleteGroupRefSeq(groupId, refSeqId)
    deleteData = {'groupId'=>groupId, 'refSeqId'=>refSeqId}
    return deleteByMultipleFieldsAndValues(:mainDB, 'grouprefseq', deleteData, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGroupAndRefSeqNameByRefSeqId(refSeqId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = "select refseq.refseqName, genboreegroup.groupName from refseq, genboreegroup where refseq.refSeqId = #{mysql2gsubSafeEsc(refSeqId.to_s)} and genboreegroup.groupId = (select groupId from grouprefseq where refSeqId = #{mysql2gsubSafeEsc(refSeqId.to_s)}) "
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}(): with are refSeqId = #{refSeqId.inspect}", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: refseq
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################

  SELECT_REFSEQ_BY_ID_SQL = 'select * from genboree.refseq where refSeqId = ? '
  def selectRefseqById(refSeqId)
    return selectByFieldAndValue(:mainDB, 'refseq', 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # WARNING: this sucks...sure you can't use selectFlaggedDbNamesByRefSeqId()?
  # It is much faster and more efficient...less code for you.
  def selectDBNameByRefSeqID(refSeqId)
    return selectFieldsByFieldAndValue(:mainDB, 'refseq', [ 'databaseName' ], false, 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectRefseqVersionByRefSeqID(refSeqId)
    return selectFieldsByFieldAndValue(:mainDB, 'refseq', [ 'refseq_version' ], false, 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectRefseqByName(refSeqName)
    return selectByFieldAndValue(:mainDB, 'refseq', 'refseqName', refSeqName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectRefseqByDatabaseName(dbName)
    return selectByFieldAndValue(:mainDB, 'refseq', 'databaseName', dbName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Returns boolean
  def isRefseqPublic(refSeqId)
    retVal = false
    rows = selectByMultipleFieldsAndValues(:mainDB, 'refseq', { 'refSeqId' => refSeqId, 'public' => 1 }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = !(rows.nil? or rows.empty?)
    return retVal
  end

  GET_ALL_TEMPLATES = "select refseq.refseqName, refseq.refseq_species, refseq.refseq_version from refseq, upload, template2upload where refseq.refSeqId = upload.refSeqId and upload.uploadId = template2upload.uploadId "
  def getAllTemplates()
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = GET_ALL_TEMPLATES
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_ALL_DBNAMES_FROM_REFSEQ = "select databaseName from genboree.refseq"
  def selectAllDbNamesFromRefseq()
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_ALL_DBNAMES_FROM_REFSEQ
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Result table rows will have 2 columns:
  # 1. databaseName - Name of a mysql database associated with refSeqId
  # 2. isUserDb - A enum(0,1) indicated whether that databaseName is a user database (1) or a shared/template database (0)
  # - The user database will always be first (due to desc order by on isUseDb)
  SELECT_FLAGGED_DBNAMES_FOR_REFSEQID = "select upload.databaseName, (refseq.databaseName = upload.databaseName) as isUserDb from refseq, upload where (refseq.refSeqId = upload.refSeqId) and refseq.refSeqId = '{refSeqId}' order by isUserDb desc "
  def selectFlaggedDbNamesByRefSeqId(refSeqId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_FLAGGED_DBNAMES_FOR_REFSEQID.gsub(/\{refSeqId\}/, mysql2gsubSafeEsc(refSeqId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  REFSEQ_BY_NAME_AND_GROUPID_SQL = "select * from refseq,grouprefseq where refseq.refseqName = '{refSeqName}' and grouprefseq.groupId = '{groupId}' and grouprefseq.refSeqId = refseq.refSeqId"
  def selectRefseqByNameAndGroupId(refSeqName, groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = REFSEQ_BY_NAME_AND_GROUPID_SQL.gsub(/\{refSeqName\}/, mysql2gsubSafeEsc(refSeqName.to_s))
      sql = sql.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  REFSEQ_BY_NAME_AND_GROUPNAME_SQL = "select refseq.* from refseq,genboreegroup,grouprefseq where genboreegroup.groupName = '{groupName}' and refseq.refSeqName = '{refSeqName}' and refseq.refSeqId = grouprefseq.refSeqId and genboreegroup.groupId = grouprefseq.groupId"
  def selectRefseqByNameAndGroupName(refSeqName, groupName)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = REFSEQ_BY_NAME_AND_GROUPNAME_SQL.gsub(/\{refSeqName\}/, mysql2gsubSafeEsc(refSeqName.to_s))
      sql = sql.gsub(/\{groupName\}/, mysql2gsubSafeEsc(groupName.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  REFSEQS_BY_GROUPID_SQL = "select refseq.* from refseq, grouprefseq where grouprefseq.groupId = '{groupId}' and grouprefseq.refSeqId = refseq.refSeqId "
  def selectRefseqsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = REFSEQS_BY_GROUPID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  PUBLIC_REFSEQS_BY_GROUPID_SQL = "select refseq.* from refseq, grouprefseq where grouprefseq.groupId = '{groupId}' and grouprefseq.refSeqId = refseq.refSeqId and refseq.public = 1 "
  def selectPublicRefseqsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_REFSEQS_BY_GROUPID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  PUBLIC_UNLOCKED_REFSEQS_BY_GROUPID_SQL = "select refseq.*, unlockedGroupResources.unlockKey from refseq, grouprefseq, unlockedGroupResources where grouprefseq.groupId = '{groupId}' and grouprefseq.refSeqId = refseq.refSeqId and refseq.public = 1 and unlockedGroupResources.group_id = grouprefseq.groupId and unlockedGroupResources.resourceType='database' and unlockedGroupResources.resource_id=refseq.refSeqId"
  def selectPublicUnlockedRefseqsByGroupId(groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = PUBLIC_UNLOCKED_REFSEQS_BY_GROUPID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  PUBLIC_UNLOCKED_REFSEQS_SQL =
    "select refseq.*, unlockedGroupResources.unlockKey
    from refseq, unlockedGroupResources
    where refseq.public = 1
    and unlockedGroupResources.resourceType='database'
    and unlockedGroupResources.resource_id=refseq.refSeqId"
  def selectPublicUnlockedRefseqs()
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      resultSet = client.query(PUBLIC_UNLOCKED_REFSEQS_SQL, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  DROP_DATABASE = "drop database "
  def dropDatabase(databaseName)
    retVal = nil
    begin
      connectToDataDb() # Lazy connect
      sql = DROP_DATABASE.dup()
      sql << "#{databaseName}"
      stmt = @dataDbh.prepare(sql)    # Prep the stmt
      stmt.execute()                        # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#dropDatabase():", @err, DROP_DATABASE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  PUBLISH_DATABASE = "update refseq set public = 1 where refSeqId = ?"
  def publishDatabase(refSeqId)
    retVal = nil
    begin
      connectToMainGenbDb()                         # Lazy connect to main database
      stmt = @genbDbh.prepare(PUBLISH_DATABASE)    # Prep the stmt
      stmt.execute(refSeqId)                        # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#publishDatabase():", @err, PUBLISH_DATABASE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  RETRACT_DATABASE = "update refseq set public = 0 where refSeqId = ?"
  def retractDatabase(refSeqId)
    retVal = nil
    begin
      connectToMainGenbDb()                         # Lazy connect to main database
      stmt = @genbDbh.prepare(RETRACT_DATABASE)    # Prep the stmt
      stmt.execute(refSeqId)                        # Execute the stmt
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#retractDatabase():", @err, RETRACT_DATABASE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def deleteRefseqRecordByRefSeqId(refSeqId)
    return deleteByFieldAndValue(:mainDB, 'refseq', 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def updateRefSeqById(refSeqId, updateData)
    return updateByFieldAndValue(:mainDB, 'refseq', updateData, 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: projects
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_PROJECT_SQL = 'insert into projects values (null, ?, ?, ?)'
  UPDATE_PROJECT_NAME_BY_ID_SQL = 'update projects set name = ? where id = ?'
  UPDATE_PROJECT_STATE_BY_ID_SQL = 'update projects set state = ? where id = ? '
  UPDATE_PROJECT_GROUP_BY_ID_SQL = 'update projects set groupId = ? where id = ? '
  # ############################################################################
  # METHODS
  # ############################################################################
  def getProjectsByGroupId(groupId)
    return selectByFieldAndValue(:mainDB, 'projects', 'groupId', groupId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def getProjectsByName(projName, groupId=nil)
    retVal = nil
    if(groupId)
      retVal = selectByMultipleFieldsAndValues(:mainDB, 'projects', { 'name' => projName, 'groupId' => groupId }, :and, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    else # just by project name
      retVal = selectByFieldAndValue(:mainDB, 'projects', 'name', projName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    return retVal
  end

  def getProjectById(projId)
    return selectByFieldAndValue(:mainDB, 'projects', 'id', projId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def updateProjectNameById(projName, projId)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_PROJECT_NAME_BY_ID_SQL)
      stmt.execute(projName, projId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateProjectNameById(): ", @err, UPDATE_PROJECT_NAME_BY_ID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateProjectStateById(projId, newState)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_PROJECT_STATE_BY_ID_SQL)
      stmt.execute(newState, projId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateProjectStateById(): ", @err, UPDATE_PROJECT_STATE_BY_ID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateProjectGroupById(projId, newGroupId)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_PROJECT_GROUP_BY_ID_SQL)
      stmt.execute(newGroupId, projId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateProjectStateById(): ", @err, UPDATE_PROJECT_STATE_BY_ID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  DELETE_PROJECT_BY_ID = 'delete from projects where id = ?'
  def deleteProjectById(projId)
    return deleteByFieldAndValue(:mainDB, 'projects', 'id', projId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: searchConfig
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def getSearchConfigByScid(scid)
    return selectByFieldAndValue(:mainDB, 'searchConfig', 'scid', scid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: refSeqId2scid
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SCID = 0
  # ############################################################################
  # METHODS
  # ############################################################################
  def getScidForRefSeqID(refSeqId)
    return selectFieldsByFieldAndValue(:mainDB, 'refSeqId2scid', [ 'scid' ], false, 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: upload
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectDBNamesByRefSeqID(refSeqId)
    return selectByFieldAndValue(:mainDB, 'upload', 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectUploadIDByRefSeqID(refSeqId)
    return selectFieldsByFieldAndValue(:mainDB, 'upload', [ 'uploadId' ], false, 'refSeqId', refSeqId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectDBNameByUploadID(uploadId)
    retVal = nil
    rows = selectFieldsByFieldAndValue(:mainDB, 'upload', [ 'databaseName' ], false, 'uploadId', uploadId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = rows.first if(rows and !rows.empty?)
    return retVal
  end

  def selectRefSeqIdByUploadID(uploadId)
    retVal = nil
    rows = selectFieldsByFieldAndValue(:mainDB, 'upload', [ 'refSeqId' ], false, 'uploadId', uploadId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    retVal = rows.first if(rows and !rows.empty?)
    return retVal
  end

  def selectDBNamesByUserDbName(userDbName)
    return selectFieldsByFieldAndValue(:mainDB, 'upload', [ 'databaseName' ], false, 'userDbName', userDbName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  DBNAMES_SELECT_BY_GROUP_AND_USERID_SQL = "SELECT grouprefseq.groupId, refseq.databaseName, refseq.refSeqName, refseq.refSeqId FROM grouprefseq, refseq, usergroup WHERE grouprefseq.refSeqId=refseq.refSeqId AND usergroup.groupId=grouprefseq.groupId AND usergroup.userId = '{userId}' AND grouprefseq.groupId = '{groupId}'"
  def selectDBNamesByGroupAndUserId(userId, groupId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = DBNAMES_SELECT_BY_GROUP_AND_USERID_SQL.gsub(/\{groupId\}/, mysql2gsubSafeEsc(groupId.to_s))
      sql = sql.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: genomeTemplate
  # --------
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectTemplateByName(templateName)
    return selectByFieldAndValue(:mainDB, 'genomeTemplate', 'genomeTemplate_name', templateName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  TEMPLATE_VERSION_BY_REFSEQ = "select genomeTemplate.genomeTemplate_version from genomeTemplate, refseq where refseq.refSeqId = '{refSeqId}' and refseq.FK_genomeTemplate_id = genomeTemplate.genomeTemplate_id"
  def selectTemplateVersionByRefSeqID(refSeqId)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = TEMPLATE_VERSION_BY_REFSEQ.gsub(/\{refSeqId\}/, mysql2gsubSafeEsc(refSeqId.to_s))
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: textDigest
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_TEXT_DIGEST = 'insert into textDigest values(null, ?, null, ?) '
  # ############################################################################
  # METHODS
  # ############################################################################
  # Get by digest value (should give result set with 1 row)
  def selectTextDigestByDigest(digest)
    return selectByFieldAndValue(:mainDB, 'textDigest', 'digest', digest, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert new text value and associated digest.
  def insertTextDigestRec(digest, text, onDuplicateUpdate=true)
    retVal = 0
    begin
      connectToMainGenbDb()
      sql = INSERT_TEXT_DIGEST.dup
      sql += " on duplicate key update creationTime = now()" if(onDuplicateUpdate)
      stmt = @genbDbh.prepare(sql)
      stmt.execute(digest, text)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertTextDigestRec(): ", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # --------
  # Table: restAuthTokens
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  INSERT_REST_AUTH_REC = 'insert into restAuthTokens values (?, ?, ?, ?, ?, ?, ?) '
  INSERT_OR_UPDATE_REST_AUTH_REC = 'insert into restAuthTokens values (?, ?, ?, ?, ?, ?, ?) on duplicate key update time = ?, reqCount = reqCount + ? '
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectRestAuthRecByToken(token)
    return selectByFieldAndValue(:mainDB, 'restAuthTokens', 'token', token, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertRestAuthRec(token, timestamp, userId, remoteAddr, method, path, reqCount=1)
    retVal = 0
    method = method.to_s
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(INSERT_REST_AUTH_REC)
      stmt.execute(token, timestamp, userId, remoteAddr, method, path, reqCount)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertRestAuthRec(): ", @err, INSERT_REST_AUTH_REC)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertOrUpdateRestAuthRec(token, timestamp, userId, remoteAddr, method, path, reqCount=1)
    retVal = 0
    method = method.to_s
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(INSERT_OR_UPDATE_REST_AUTH_REC)
      stmt.execute(token, timestamp, userId, remoteAddr, method, path, reqCount, timestamp, reqCount)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertRestAuthRec(): ", @err, INSERT_REST_AUTH_REC)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  SELECT_RECENT_AUTH_TOKENS = "select * from restAuthTokens where userId = '{userId}' and time >= '{time}' and path like '{pathSqlPattern}' and method in "
  def getRecentExpensiveRestAuthTokens(userId, time, pathSqlPattern, methods)
    retVal = sql = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = SELECT_RECENT_AUTH_TOKENS.gsub(/\{userId\}/, mysql2gsubSafeEsc(userId.to_s))
      sql = sql.gsub(/\{time\}/, mysql2gsubSafeEsc(time.to_s)).gsub(/\{pathSqlPattern\}/, pathSqlPattern) # <= do not escape, presumed to have SQL "like" % in it and correct from calling method
      setSql = DBUtil.makeMysql2SetStr(methods)
      sql << setSql
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # --------
  # Table: tasks
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  FAIL_STATE, PENDING_STATE, RUNNING_STATE = 1, 2, 4
  INSERT_TASK_SQL = 'insert into tasks values (?, ?, ?, ?) '
  UPDATE_CMD_BY_TASKID_SQL = 'update tasks set command = ? where id = ? '
  SET_TASK_STATE_BIT_SQL = 'update tasks set state = (state | ?) where id = ? '
  TOGGLE_TASK_STATE_BIT_SQL = 'update tasks set state = (state ^ ?) where id = ? '
  CLEAR_TASK_STATE_BIT_SQL = 'update tasks set state = (state & ~?) where id = ? '
  # ############################################################################
  # METHODS
  # ############################################################################
  SELECT_TASK_BY_ID_SQL = 'select * from tasks where id = ? '
  def selectTaskById(taskId)
    return selectByFieldAndValue(:mainDB, 'tasks', 'id', taskId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def insertNewTask_returnTaskId(cmd, state=PENDING_STATE, timestamp=Time.now())
    retVal = -1
    begin
      if(cmd.nil? or cmd.strip.empty? or state < 0)
        raise ArgumentError, "Either cmd is nil/empty or state is less than 0 !!??"
      end
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(INSERT_TASK_SQL)
      stmt.execute(nil, cmd, timestamp, state)
      rows = stmt.rows
      if(rows < 0)
        raise "Failed to insert the 1 row?? (rows: #{rows.inspect})"
      end
      retVal = @genbDbh.func(:insert_id)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertNewTask(): ", @err, INSERT_TASK_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateCmdByTaskId(cmd, taskId)
    retVal = -1
    begin
      if(cmd.nil? or cmd.strip.empty?)
        raise ArgumentError, "Either cmd is nil/empty or state is less than 0 !!??"
      end
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(UPDATE_CMD_BY_TASKID_SQL)
      retVal = stmt.execute(cmd, taskId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateCmdByTaskId(): ", @err, UPDATE_CMD_BY_TASKID_SQL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def setTaskStateBit(taskId, stateBitToSet)
    return setStateBit(:mainDB, 'tasks', stateBitToSet, 'id', taskId, "ERROR: [#{File.basename($0)}] DBUtil#setTaskStateBit(): ")
  end

  def toggleTaskStateBit(taskId, stateBitToToggle)
    return toggleStateBit(:mainDB, 'tasks', stateBitToToggle, 'id', taskId, "ERROR: [#{File.basename($0)}] DBUtil#toggleTaskStateBit(): ")
  end

  def clearTaskStateBit(taskId, stateBitToClear)
    return clearStateBit(:mainDB, 'tasks', stateBitToClear, 'id', taskId, "ERROR: [#{File.basename($0)}] DBUtil#clearTaskStateBit(): ")
  end

  # --------
  # Table: unlockedGroupResources
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  DELETE_RESOURCE_AND_PARENTS_BY_GROUP_ID = 'delete from unlockedGroupResources, unlockedGroupResourceParents
                                              using unlockedGroupResources
                                              left join unlockedGroupResourceParents
                                              on unlockedGroupResources.id = unlockedGroupResourceParents.unlockedGroupResource_id
                                              where unlockedGroupResources.group_id = ?'

  DELETE_RESOURCE_BY_GROUP_ID_AND_RESOURCE = 'delete from unlockedGroupResources
                                              where unlockedGroupResources.group_id = ?
                                              and unlockedGroupResources.resourceType = ?
                                              and unlockedGroupResources.resource_id = ?'

  DELETE_RESOURCE_WITH_PARENT = 'delete from unlockedGroupResources, unlockedGroupResourceParents
                                  using unlockedGroupResources
                                  join unlockedGroupResourceParents
                                  on unlockedGroupResources.id = unlockedGroupResourceParents.unlockedGroupResource_id
                                  where unlockedGroupResources.group_id = ?
                                  and unlockedGroupResources.resourceType = ?
                                  and unlockedGroupResources.resource_id = ?
                                  and unlockedGroupResourceParents.resourceType = ?
                                  and unlockedGroupResourceParents.resource_id = ?'

  SELECT_KEY_BY_RESOURCE_WITH_PARENT = 'select ugr.*
                                        from unlockedGroupResources ugr, unlockedGroupResourceParents ugrp
                                        where ugr.id = ugrp.unlockedGroupResource_id
                                        and ugr.group_id = ?
                                        and ugr.resourceType = ?
                                        and ugr.resource_id = ?
                                        and ugrp.resourceType = ?
                                        and ugrp.resource_id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # ------------------------------------------------------------------
  # KEY METHODS
  # - New approach is simple and doesn't require resource-specific coding.
  # - Uses hierarchical nature of resource paths AND of unlocking (unlock parent == children also unlocked)
  # - Still group-oriented. Mainly to protect non-group resources from being unlocked. Group == ACL.
  # - Doesn't use resourceId AT ALL
  #   * resourceId is cumbersome and requires too much per-resource code (methods, helpers)
  #     to support as designed in the old methods.
  #   * rather, if needed, the resourceId can be found by calling code using group and resource type
  #     - the apiUriHelper classes are helpful here for extracting info from the resource path
  #     - the rest/resource classes are helpful for auto-matching the "best fit" resource against a given path
  #       and each has a RSRC_TYPE class variable.
  # RESULT: do not use the database/track/file specific methods. Use the more generic group-oriented methods ONLY.
  # ------------------------------------------------------------------

  # Get an unlocked resource record by id.
  # @param [Fixnum] id The record id in the unlockedGroupResources table
  # @return [Array<Hash>] Result set - Array of Row hashes. Should be empty or size=1.
  def selectUnlockedResourceById(id)
    selectByFieldAndValue(:mainDB, 'unlockedGroupResources', 'id', id, "ERROR: [#{File.basename($0)}] DBUtil#selectUnlockedResources():")
  end

  # Get all the unlocked resource records for a group using a groupId
  # @param [Fixnum] groupId The Genboree Group Id
  # @return [Array<Hash>] Result set - Array of Row hashes
  def selectUnlockedResources(groupId)
    selectByFieldAndValue(:mainDB, 'unlockedGroupResources', 'group_id', groupId, "ERROR: [#{File.basename($0)}] DBUtil#selectUnlockedResources():")
  end

  # Get all the unlocked resources by key.
  # @param [Fixnum] key  The unlockKey
  # @return [Array<Hash>] Result set - Array of Row hashes
  def selectUnlockedResourcesByKey(key)
    selectByFieldAndValue(:mainDB, 'unlockedGroupResources', 'unlockKey', key, "ERROR: [#{File.basename($0)}] DBUtil#selectUnlockedResourcesByKey():")
  end

  SELECT_UNLOCKED_RSRCS_UNDER_RSRC_SQL = "select * from unlockedGroupResources where locate('{rsrcPath}/', concat(resourceUri, '/')) = 1"
  # Get records for all unlocked resources UNDER a given parent resource. This includes the resource itself.
  #   The parent resource--provided by a path (not full url)--need not be unlocked.
  #   It is just used to identify sub-ordinate resources which are unlocked.
  #   For example: ALL unlocked resources within given GROUP.
  #   Mainly intended to support groups, so @rsrcPath@ should be a group defined on this Genboree host.
  #   most typically this will be for finding the list of unlocked databases under a group say.
  # @param [String, URI] rsrcPath The path to the parent resource under which you want to find all
  #   unlocked resources. Regardless of whether it is a full URL string, a string path, or a URI object,
  #   just the PATH portion will be used as part of a prefix search.
  # @return [Array<Hash>] Result set - Array of Row hashes. To be returned, a record must be associated with
  #   a valid group on the host (i.e. the group_id points to a valid group in genboreegroup table)
  def selectUnlockedResourcesUnderRsrc(rsrcPath)
    client = retVal = nil
    begin
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(rsrcPath)
      sql = SELECT_UNLOCKED_RSRCS_UNDER_RSRC_SQL.dup.gsub(/\{rsrcPath\}/, escUriPath)
      recs = client.query(sql, :cast_booleans => true)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_SQL = "select * from unlockedGroupResources where locate(concat(resourceUri, '/'), '{rsrcPath}/') = 1 "
  # Get records for all unlocked resources ABOVE a given child resource. This includes the resource itself.
  #   Because unlocking is hierarchical and unlocking a parent unlockes everything below it, this is almost
  #   the same as looking records WHICH WOULD GRANT ACCESS, if the correct key was provided
  # @see selectUnlockedResourcesAboveRsrcWithKey For a method which will look for records at or above
  #   resource AND what the given key. This is the +same+ as checking for access to rsrcPath.
  # @param [String, URI] rsrcPath The path to the resource above which you want to find all
  #   unlocked resources. Regardless of whether it is a full URL string, a string path, or a URI object,
  #   just the PATH portion will be used as part of a prefix search.
  # @return [Array<Hash>] Result set - Array of Row hashes. To be returned, a record must be associated with
  #   a valid group on the host (i.e. the group_id points to a valid group in genboreegroup table).
  def selectUnlockedResourcesAboveRsrc(rsrcPath)
    client = retVal = nil
    begin
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(rsrcPath)
      sql = SELECT_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_SQL.dup.gsub(/\{rsrcPath\}/, escUriPath)
      recs = client.query(sql, :cast_booleans => true)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_WITH_KEY_SQL = "select * from unlockedGroupResources where locate(concat(resourceUri, '/'), '{rsrcPath}/') = 1 and binary unlockedGroupResources.unlockKey = '{key}'"
  # Get records for all unlocked resources ABOVE a given child resource and which contain the given key.
  #   This includes the resource itself. Because unlocking is hierarchical and unlocking a parent unlockes
  #   everything below it, this is THE SAME AS CHECKING FOR ACCESS to resource.
  #   All that is required for access is:
  #   1. An unlocked parent or self.
  #   2. The matching key for that parent or self.
  #   Don't even care if multiple unlock records grant permission or not. As long as at least 1 record is found.
  #   the same as looking records WHICH WOULD GRANT ACCESS, if the correct key was provided
  # @param [String, URI] rsrcPath The path to the resource above which you want to find all
  #   unlocked resources. Regardless of whether it is a full URL string, a string path, or a URI object,
  #   just the PATH portion will be used as part of a prefix search.
  # @param [String] key The unlock key. Presumably the one that was provided with the resource. Either
  #   it is the key for that rsrcPath specifically or for one of the parents of rsrcPath.
  # @return [Array<Hash>] Result set - Array of Row hashes.
  def selectUnlockedResourcesAboveRsrcWithKey(rsrcPath, key)
    client = retVal = nil
    begin
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(rsrcPath)
      sql = SELECT_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_WITH_KEY_SQL.dup.gsub(/\{rsrcPath\}/, escUriPath)
      sql.gsub!(/\{key\}/, mysql2gsubSafeEsc(key))
      recs = client.query(sql, :cast_booleans => true)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SELECT_PUBLICLY_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_SQL = "select * from unlockedGroupResources where locate(concat(resourceUri, '/'), '{rsrcPath}/') = 1 and unlockedGroupResources.public = 1"
  # Get records for all unlocked resources ABOVE a given child resource and which are publicly unlocked
  #   (i.e. for which the key is "automatically discoverable"). This includes the resource itself.
  #   Because unlocking is hierarchical and unlocking a parent unlocks
  #   everything below it, this is THE SAME AS CHECKING FOR ACCESS to resource.
  #   All that is required for access is:
  #   1. An unlocked parent or self.
  #   2. The matching key for that parent or self, OR for the key to be "public".
  #   Don't even care if multiple unlock records grant permission or not. As long as at least 1 record is found.
  #   the same as looking records WHICH WOULD GRANT ACCESS, if the correct key was provided
  # @param [String, URI] rsrcPath The path to the resource above which you want to find all
  #   unlocked resources. Regardless of whether it is a full URL string, a string path, or a URI object,
  #   just the PATH portion will be used as part of a prefix search.
  # @return [Array<Hash>] Result set - Array of Row hashes.
  def selectPubliclyUnlockedResourcesAboveRsrc(rsrcPath)
    client = retVal = nil
    begin
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(rsrcPath)
      sql = SELECT_PUBLICLY_UNLOCKED_GRP_RSRCS_ABOVE_RSRC_SQL.dup.gsub(/\{rsrcPath\}/, escUriPath)
      recs = client.query(sql, :cast_booleans => true)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Get the unlockedGroupResource row for an unlocked resource using the URI (path).
  #   This will use EXACT MATCH. It's for getting the specific record when the
  #   exact path found in the record is available. NOT suitable for checking access
  #   since it doesn't respect any hierarchical-unlocking; mainly for record management.
  # @param [String, URI] rsrcPath Exact path of the resource you want the unlock record for.
  # @return [Array<Hash>] Result set - Array of Row hashes.
  def selectUnlockedResourcesByUri(rescPath)
    client = retVal = nil
    begin
      if(rescPath.is_a?(String))
        rescPath = URI.parse(rescPath)
        rsrcPath = rescPath.path
      else # must be a URI object
        rsrcPath = rescPath.path
      end
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(rsrcPath)
      # Don't need to escape sha in the SQL, as is normally REQUIRED for security & robustness, because any unsafe chars are made safe.
      sql = "select * from unlockedGroupResources where resourceUriDigest = sha1('#{escUriPath}')"
      recs = client.query(sql, :cast_booleans => true)
      retVal = recs.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end
  alias_method :selectUnlockedResourcesByPath, :selectUnlockedResourcesByUri

  # Insert a new unlocked group resource record for a resource given by path.
  # @param [Fixnum] groupId The id of the group the resource is in.
  # @param [String] rsrcType The resource type string.
  # @param [String] key The unlock key.
  # @param [String] rsrcPath The unlocked resource's path.
  # @param [Boolean] isPublic Is the key public/discoverable. Mainly for backward compatibility.
  # @param [Fixnum, nil] rsrcId The id of resource in its native table (if any...kb child resoures aren't in tables!) DO NOT USE. BACKWARD COMPATIBILITY ONLY.
  # @return [Fixnum] The number of records inserted. Should be 1 if things went well.
  def insertUnlockedGroupResourceByPath(groupId, rsrcType, key, rsrcPath, isPublic=false, rsrcId=nil)
    rsrcPath = URI.parse(rsrcPath) if(rsrcPath.is_a?(String))
    uriPath = rsrcPath.path
    escUriPath = mysql2gsubSafeEsc(uriPath)
    # NOTE: SHA1.hexdigest(uriPath) is same as SQL "sha1('#{escUriPath}')" (escape to make SQL safe)
    insertData = [groupId, rsrcType, rsrcId, key, SHA1.hexdigest(uriPath), escUriPath, isPublic]
    insertRecords(:mainDB, 'unlockedGroupResources', insertData, true, 1, 7, false, "ERROR: [#{File.basename($0)}] DBUtil#insertUnlockedGroupResource():")
  end

  # Change the key for an existing record using its id.
  # @param [Fixnum] unlockedGroupResourceId The id of the record to update
  # @param [String] key The new unlock key for that resource.
  # @return [Fixnum] The number of records updated. Should be exactly 1 if things went ok.
  def updateGroupResourceById(unlockedGroupResourceId, key)
    updateByFieldAndValue(:mainDB, 'unlockedGroupResources', {'unlockKey' => key}, 'id', unlockedGroupResourceId, "ERROR: [#{File.basename($0)}] DBUtil#updateGroupResourceById()")
  end

  # Set the isPublic flag for an existing record using its id.
  # @param [Fixnum] unlockedGroupResourceId The id of the record to update
  # @param [Boolean] isPublic The new value for isPublic.
  # @return [Fixnum] The number of records updated. Should be exactly 1 if things went ok.
  def setGroupResourcePublicFlagById(unlockedGroupResourceId, isPublic)
    updateByFieldAndValue(:mainDB, 'unlockedGroupResources', {'public' => isPublic}, 'id', unlockedGroupResourceId, "ERROR: [#{File.basename($0)}] DBUtil#setGroupResourcePublicFlagById()")
  end

  # Delete an unlocked resource record using its id.
  # @param [Fixnum] id The id of the record to delete
  # @return [Fixnum] The number of records delete. Should be exactly 1 if things went ok.
  def deleteUnlockedResourceById(id)
    return deleteByFieldAndValue(:mainDB, 'unlockedGroupResources', 'id', id, "ERROR: [#{File.basename($0)}] DBUtil#deleteUnlockedResourceById():")
  end

  # Delete the record via a resource path EXACT MATCH.
  # @param [String, URI] uri The resource path of the record to delete
  # @return [Fixnum] The number of records deleted. Should be 1 if things went ok.
  def deleteUnlockedResourceByUri(uri)
    client = retVal = nil
    uri = URI.parse(uri) if(uri.is_a?(String))
    uriPath = uri.path
    begin
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(uriPath)
      sql = "delete from unlockedGroupResources where resourceUriDigest = sha1('#{escUriPath}')"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end
  alias_method :deleteUnlockedResourceByPath, :deleteUnlockedResourceByUri

  # Delete all records associated with a group. i.e. relock a whole group
  def deleteUnlockedGroupResourcesByGroupId(groupId)
    return deleteByFieldAndValue(:mainDB, 'unlockedGroupResources', 'group_id', groupId, "ERROR: [#{File.basename($0)}] DBUtil#deleteUnlockedResourceById():")
  end

  # ------------------------------------------------------------------
  # OLD METHODS. More convoluted and involved
  # ------------------------------------------------------------------

  # Get the unlockedGroupResource row for an unlocked resource
  #
  # [+groupId+]       The Genboree Group Id
  # [+resourceType+]  The type of the resource ('database', 'track' or 'project', etc (...REST::Resources::{classes} have RSRC_TYPE constant for more)
  # [+resourceId+]    Primary key of the resource
  # [+returns+]       Array of Row objects
  def selectUnlockKeyByResource(groupId, resourceType, resourceId)
    whereData = {'group_id' => groupId, 'resource_id' => resourceId, 'resourceType' => resourceType}
    selectByMultipleFieldsAndValues(:mainDB, 'unlockedGroupResources', whereData, :and, "ERROR: [#{File.basename($0)}] DBUtil#selectUnlockKeyByResource():")
  end

  # Get the unlockedGroupResource row for an unlocked resource
  #
  # [+groupId+]       The Genboree Group Id
  # [+resourceType+]  The type of the resource ('database', 'track' or 'project')
  # [+resourceId+]    Primary key of the resource
  # [+parentType+]  The type of the resource ('database', 'track' or 'project')
  # [+parentId+]    Primary key of the resource
  # [+returns+]       Array of Row objects
  def selectUnlockKeyByResourceWithParent(groupId, resourceType, resourceId, parentType, parentId)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(SELECT_KEY_BY_RESOURCE_WITH_PARENT)
      stmt.execute(groupId, resourceType, resourceId, parentType, parentId)
      retVal = stmt.fetch_all
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#selectKeyByResourceWithParent():", @err, SELECT_KEY_BY_RESOURCE_WITH_PARENT)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def deleteUnlockedResourceAndChildrenByUri(uri)
    client = retVal = nil
    uri = URI.parse(uri) if(uri.is_a?(String))
    uriPath = uri.path
    begin
      client = getMysql2Client(:mainDB)
      escUriPath = mysql2gsubSafeEsc(uriPath)
      sql = "delete from unlockedGroupResources where resourceUri = '#{escUriPath}' or resourceUri like '#{escUriPath}/%';"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # BAD. Doesn't extract out the PATH, leading to many redundant (and exclusive) records for THE SAME RESOURCE
  #    Consider, just having "&useHost=ffo.edu" or similar on the full URL == new record. STUPID!
  #    Use insertUnlockedGroupResourceUri() instead!
  def insertUnlockedGroupResource(groupId, resourceType, resourceId, key, resourceUri, isPublic=false)
    insertData = [groupId, resourceType, resourceId, key, SHA1.hexdigest(resourceUri), resourceUri, isPublic]
    insertRecords(:mainDB, 'unlockedGroupResources', insertData, true, 1, 7, false, "ERROR: [#{File.basename($0)}] DBUtil#insertUnlockedGroupResource():")
  end

  def deleteUnlockedGroupResource(groupId, resourceType, resourceId)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(DELETE_RESOURCE_BY_GROUP_ID_AND_RESOURCE)
      stmt.execute(groupId, resourceType, resourceId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteUnlockedGroupResource():", @err, DELETE_RESOURCE_AND_PARENTS_BY_GROUP_ID_AND_RESOURCE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def deleteUnlockedGroupResourceWithParent(groupId, resourceType, resourceId, parentType, parentId)
    retVal = nil
    begin
      connectToMainGenbDb()
      stmt = @genbDbh.prepare(DELETE_RESOURCE_WITH_PARENT)
      stmt.execute(groupId, resourceType, resourceId, parentType, parentId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteUnlockedGroupResource():", @err, DELETE_RESOURCE_AND_PARENTS_BY_GROUP_ID_AND_RESOURCE)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateResourceUriAndDigestByNewResourceUri(oldRsrcUri, newRsrcUri)
    retVal = nil
    begin
      client = getMysql2Client(:mainDB)
      # Make sql
      escOldRsrcUri = mysql2gsubSafeEsc(oldRsrcUri)
      escNewRsrcUri = mysql2gsubSafeEsc(newRsrcUri)
      sql = "update unlockedGroupResources set resourceUri = replace(resourceUri, '#{escOldRsrcUri}', '#{escNewRsrcUri}'), resourceUriDigest =
            sha1('#{escNewRsrcUri}') where resourceUri = '#{escOldRsrcUri}' or resourceUri like '#{oldRsrcUri}/%'"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.updateResourceUriAndDigestByNewResourceUri():", @err, sql)
    ensure
      client.close  rescue nil
    end
    return retVal
  end

  def updateGroupResourceById(unlockedGroupResourceId, key)
    updateByFieldAndValue(:mainDB, 'unlockedGroupResources', {'unlockKey' => key}, 'id', unlockedGroupResourceId, "ERROR: [#{File.basename($0)}] DBUtil#updateGroupResourceById()")
  end

  # --------
  # Table: unlockedGroupResourceParents
  # --------

  # OLD. DO NOT USE.

  def selectParentResourcesByUnlockId(unlockedGroupResourceId)
    selectByFieldAndValue(:mainDB, 'unlockedGroupResourceParents', 'unlockedGroupResource_id', unlockedGroupResourceId, "ERROR: [#{File.basename($0)}] DBUtil#selectParentResourcesByUnlockId():")
  end

  def insertUnlockedGroupResourceParent(unlockedGroupResourceId, resourceType, resourceId)
    insertRecords(:mainDB, 'unlockedGroupResourceParents', [unlockedGroupResourceId, resourceType, resourceId], true, 1, 3, false, "ERROR: [#{File.basename($0)}] DBUtil#insertUnlockedGroupResourceParent():")
  end

  def deleteUnlockedGroupResourceParent(unlockedGroupResourceId)
    deleteByFieldAndValue(:mainDB, 'unlockedGroupResourceParents', 'unlockedGroupResource_id', unlockedGroupResourceId, "ERROR: [#{File.basename($0)}] DBUtil#deleteUnlockedGroupResourceParent():")
  end

  # --------
  # Table: image_cache
  # --------
  TRUNCATE_IMAGE_CACHE = 'truncate image_cache'
  def truncateImageCache()
    retVal = sql = nil
    begin
      sql = TRUNCATE_IMAGE_CACHE
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute()
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # -----------
  # Loading files using load data file
  # -----------
  def loadDataWithFile(tableName, filePath, replace=false, ignoreDup=false, fields=[], setFields={}, lowPriority=false)
    retVal = sql = nil
    begin
      raise "Cannot have both replace and ignoreDup as true." if(replace and ignoreDup)
      doReplace = replace ? "replace" : ""
      ignoreDuplicate = ignoreDup ? "ignore" : ""
      addLowPriority = ( lowPriority ? 'LOW_PRIORITY' : '')
      sql = "load data #{addLowPriority} local infile '#{filePath}' #{doReplace} #{ignoreDuplicate} into table #{tableName} "
      sql << " fields terminated by '\t' "
      if(!fields.empty?)
        sql << " (#{fields.join(',')}) "
      end
      if(!setFields.empty?)
        sql << " set "
        ii = 0
        setFields.each_key { |key|
          val = setFields[key]
          if(ii == 0)
            if(!val.nil?)
              sql << "#{key}='#{val}'"
            else
              sql << "#{key}=NULL"
            end
          else
            if(!val.nil?)
              sql << ",#{key}='#{val}'"
            else
              sql << ",#{key}=NULL"
            end
          end
          ii += 1
        }
      end
      client = getMysql2Client(:userDB)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.loadDataWithFile()", @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
