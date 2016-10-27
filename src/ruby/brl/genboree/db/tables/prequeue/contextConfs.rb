require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: contextConfs
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_CONTEXTCONF_BY_ID = 'update contextConfs set context = ? where id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get contextConf record by its id
  # [+id+]      The ID of the contextConf record to return
  # [+returns+] Array of 0 or 1 contextConf  rows
  def selectContextConfById(id)
    return selectByFieldAndValue(:otherDB, 'contextConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get ContextConfs records using a list of ids
  # [+ids+]     Array of contextConf IDs
  # [+returns+] Array of 0+ contextConfs records
  def selectContextConfsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'contextConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select ContextConf records using supplied MySQL Fulltext search string for
  # match the context column against, i.e. via a "WHERE MATCH(context) AGAINST('searchStr' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  def selectContextConfsByFulltext(fulltextSearchString, mode=:boolean)
    return selectByFulltext(:otherDB, 'contextConfs', 'context', fulltextSearchString, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select ContextConf records using supplied Array of strings to build an "exact phrase" keyword string for
  # matching the context column against (using the "" fulltext operator.
  # i.e. via a "WHERE MATCH(context) AGAINST('"word1 word2 ... wordN"' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  # - If you need more custom fulltext search strings, such as combinations of one-or-more + operands and one-or-more ""
  #   operands, you should use selectContextConfsByFulltext()
  # [+keywords]  Array of Strings which are the keywords to use within the "" operator
  def selectContextConfsByFulltextKeywords(keywords, mode=:boolean)
    return selectByFulltextKeywords(:otherDB, 'contextConfs', 'context', keywords, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new ContextConf record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+contextsText+]  The complete VALUE for a job's "contexts" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]       Number of rows inserted
  def insertContextConf(contextsText)
    data = [ contextsText ]
    return insertRecords(:otherDB, 'contextConfs', data, true, 1, 1, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a ContextConf record identified by its id
  # [+id+]          ContextConfs.id of the record to update
  # [+contextsText+]  The complete replacement VALUE for a job's "contexts" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]     Number of rows inserted
  def updateContextConfById(id, contextsText)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_CONTEXTCONF_BY_ID)
      stmt.execute(contextsText, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_CONTEXTCONF_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a ContextConf record using its id.
  # [+id+]      The contextConfs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteContextConfById(id)
    return deleteByFieldAndValue(:otherDB, 'contextConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete ContextConf records using their ids.
  # [+ids+]     Array of contextConfs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteContextConfsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'contextConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
