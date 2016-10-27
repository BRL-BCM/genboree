require 'brl/genboree/dbUtil'

module BRL ; module Genboree
class DBUtil  # previously module QueriesTable
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_QUERY_BY_ID_SQL = 'SELECT * FROM queries WHERE id = ?'
  SELECT_QUERIES_BY_NAME_SQL = 'SELECT * FROM queries WHERE name = ?'
  SELECT_QUERIES_BY_USER_ID = 'SELECT * FROM queries WHERE user_id = ?'
  SELECT_SHARED_AND_PRIVATE_QUERIES_SQL = 'SELECT * FROM queries WHERE user_id = -1 OR user_id = ?'
  SELECT_SHARED_QUERIES_SQL = 'SELECT * FROM queries WHERE user_id= -1'
  INSERT_QUERY= 'INSERT INTO queries (name, description, query, user_id) VALUES (?,?,?,?)'
  DELETE_QUERY_BY_ID = 'DELETE FROM queries WHERE id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllQueries()
    return selectAll(:userDB, 'queries', "ERROR: [#{File.basename($0)}] DBUtil#selectAllQueries:")
  end

  def getQueryById(queryId)
    return nil if(queryName.nil?)

    retVal = nil
    begin
      sql = SELECT_QUERIES_BY_ID_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(queryId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getQueryById():", @err, sql, queryId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getQueryByName(queryName)
    return nil if(queryName.nil?)

    retVal = nil
    begin
      sql = SELECT_QUERIES_BY_NAME_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(queryName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getQueryByName():", @err, sql, queryName)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getQueriesByOwner(userId)
    return nil if(userId.nil?)
    retVal = nil
    begin
      sql = SELECT_QUERIES_BY_USER_ID
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(userId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getQueriesByOwner():", @err, sql, userId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getSharedAndPrivateQueries(userId)
    return nil if(userId.nil?)
    retVal = nil
    begin
      sql = SELECT_SHARED_AND_PRIVATE_QUERIES_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(userId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getSharedAndPrivateQueries():", @err, sql, userId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getSharedQueries()
    retVal = nil
    begin
      sql = SELECT_SHARED_QUERIES_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getSharedQueries():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end


  def insertQuery(queryName, desc="", query="", userId ="")
    retVal = nil
    begin
      sql = INSERT_QUERY
      test = connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(queryName, desc, query, userId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertQuery():", @err, sql, queryName)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateQuery(queryId, queryName=nil, description=nil, query=nil, userId=nil)
    return nil if (queryName.nil? and description.nil? and query.nil? and userId.nil?)

    retVal = nil
    begin
      connectToDataDb()
      sql = "UPDATE queries SET "
      sql += " name = ? " if (!queryName.nil?)
      sql += ", description = ? " if (!description.nil?)
      sql += ", query = ? " if (!query.nil?)
      sql += ", user_id = ? " if (!userId.nil?)
      sql += "WHERE id = ? "
      stmt = @dataDbh.prepare(sql)
      params = []
      params << queryName if (!queryName.nil?)
      params << description if (!description.nil?)
      params << query if (!query.nil?)
      params << userId if (!userId.nil?)
      params << queryId
      stmt.execute(*params)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateQuery():", @err, sql, queryId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def deleteQueryById(queryId)
    retVal = nil
    begin
      sql = DELETE_QUERY_BY_ID
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(queryId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteQueryById():", @err, sql, queryId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def queryResults(sql)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute()
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#queryResults():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Grab the results of a custom query as a block with defined block size
  # [+sql+] The SQL string for this custom query
  # [+orderField+] The field to use in the ORDER BY clause for this query.
  #   This is required so that the order of the results is determinate and thus
  #   the sliding limit window does not yield unpredicatable results.  A good
  #   field to use as a default is just the primary key of one of the tables in
  #   the query.
  # [+blockSize+] The specified block size (default 10,000)
  # [+returns+] The results of the query as blocks, yielded one block at a time.
  def queryResultsByBlock(sql, orderField, blockSize=10000, &block)
    retVal = []
    offset = 0
    sql += " ORDER BY ? LIMIT ?, #{blockSize}"

    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      loop {
        stmt.execute(orderField, offset)
        retVal = stmt.fetch_all_hash
        break if(retVal.empty?)
        yield(retVal)
        offset += blockSize
        break if(retVal.size() < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#queryResults():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
  end
end # updates to class DBUtil
end ; end # module BRL ; module Genboree
