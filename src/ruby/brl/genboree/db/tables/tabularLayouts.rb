require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# TABULAR-LAYOUT RELATED TABLES - DBUtil Extension Methods for dealing with Tabular-Layout-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: tabularLayouts
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_LAYOUTS_BY_ID_SQL = 'SELECT * FROM tabularLayouts WHERE id = ?'
  SELECT_LAYOUTS_BY_NAME_SQL = 'SELECT * FROM tabularLayouts WHERE name = ?'
  INSERT_LAYOUT= 'INSERT INTO tabularLayouts (name, description, userId, columns, sort, groupMode, createDate, lastModDate) VALUES (?,?,?,?,?,?,CURDATE(), NOW())'
  DELETE_LAYOUT_BY_ID = 'DELETE FROM tabularLayouts WHERE id = ?'
  # ############################################################################
  # METHODS
  # ############################################################################
  def selectAllLayouts()
    return selectAll(:userDB, 'tabularLayouts', "ERROR: [#{File.basename($0)}] DBUtil#selectAllLayouts:")
  end

  def getLayoutById(layoutId)
    return nil if(layoutName.nil?)

    retVal = nil
    begin
      sql = SELECT_LAYOUTS_BY_ID_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(layoutId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getLayoutById():", @err, sql, layoutId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def getLayoutByName(layoutName)
    return nil if(layoutName.nil?)

    retVal = nil
    begin
      sql = SELECT_LAYOUTS_BY_NAME_SQL
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(layoutName)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#getLayoutByName():", @err, sql, layoutName)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def insertLayout(layoutName, desc="", user=nil, columns=nil, sort=nil, groupMode=nil)
    retVal = nil
    begin
    sql = INSERT_LAYOUT
    connectToDataDb()
    stmt = @dataDbh.prepare(sql)
    user = 0 if(user.nil?)
    columns = "lName,lType,lSubtype,lEntry Point,lStart,lStop" if(columns.nil?)
    sort = "lEntry Point,lStart" if(sort.nil?)
    groupMode = 1 if(groupMode.nil?)
    stmt.execute(layoutName, desc, user, columns, sort, groupMode)
    retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#insertLayout():", @err, sql, layoutName)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def updateLayout(layoutId, layoutName=nil, description=nil, columns=nil, sort=nil, groupMode=nil)
    return nil if (layoutName.nil? and description.nil? and columns.nil? and sort.nil? and groupMode.nil?)

    # Translate group mode
    gMode = {"" => 0, "terse" => 1, "verbose" => 2}
    groupMode = nil if(gMode[groupMode].nil?)

    retVal = nil
    begin
      connectToDataDb()
      sql = "UPDATE tabularLayouts SET lastModDate = NOW() "
      sql += ", name = '#{layoutName.gsub(/'/, "\\\\'")}' " if (!layoutName.nil?)
      sql += ", description = '#{description.gsub(/'/, "\\\\'")}' " if (!description.nil?)
      sql += ", columns = '#{columns.gsub(/'/, "\\\\'")}' " if (!columns.nil?)
      sql += ", sort = '#{sort.gsub(/'/, "\\\\'")}' " if (!sort.nil?)
      sql += ", groupMode = #{gMode[groupMode]} " if (!groupMode.nil?)
      sql += "WHERE id = #{layoutId}"
      stmt = @dataDbh.prepare(sql)
      stmt.execute()
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#updateLayout():", @err, sql, layoutId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def deleteLayoutById(layoutId)
    retVal = nil
    begin
      sql = DELETE_LAYOUT_BY_ID
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(layoutId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] DBUtil#deleteLayoutById():", @err, sql, layoutId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
