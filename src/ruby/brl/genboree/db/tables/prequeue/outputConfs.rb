require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: outputConfs
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_OUTPUTCONF_BY_ID = 'update outputConfs set output = ? where id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get outputConf record by its id
  # [+id+]      The ID of the outputConf record to return
  # [+returns+] Array of 0 or 1 outputConf  rows
  def selectOutputConfById(id)
    return selectByFieldAndValue(:otherDB, 'outputConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get OutputConfs records using a list of ids
  # [+ids+]     Array of outputConf IDs
  # [+returns+] Array of 0+ outputConfs records
  def selectOutputConfsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'outputConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select OutputConf records using supplied MySQL Fulltext search string for
  # match the output column against, i.e. via a "WHERE MATCH(output) AGAINST('searchStr' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  def selectOutputConfsByFulltext(fulltextSearchString, mode=:boolean)
    return selectByFulltext(:otherDB, 'outputConfs', 'output', fulltextSearchString, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select OutputConf records using supplied Array of strings to build an "exact phrase" keyword string for
  # matching the output column against (using the "" fulltext operator.
  # i.e. via a "WHERE MATCH(output) AGAINST('"word1 word2 ... wordN"' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  # - If you need more custom fulltext search strings, such as combinations of one-or-more + operands and one-or-more ""
  #   operands, you should use selectOutputConfsByFulltext()
  # [+keywords]  Array of Strings which are the keywords to use within the "" operator
  def selectOutputConfsByFulltextKeywords(keywords, mode=:boolean)
    return selectByFulltextKeywords(:otherDB, 'outputConfs', 'output', keywords, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new OutputConf record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+outputsText+]  The complete VALUE for a job's "outputs" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]       Number of rows inserted
  def insertOutputConf(outputsText)
    data = [ outputsText ]
    return insertRecords(:otherDB, 'outputConfs', data, true, 1, 1, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a OutputConf record identified by its id
  # [+id+]          OutputConfs.id of the record to update
  # [+outputsText+]  The complete replacement VALUE for a job's "outputs" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]     Number of rows inserted
  def updateOutputConfById(id, outputsText)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_OUTPUTCONF_BY_ID)
      stmt.execute(outputsText, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_OUTPUTCONF_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a OutputConf record using its id.
  # [+id+]      The outputConfs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteOutputConfById(id)
    return deleteByFieldAndValue(:otherDB, 'outputConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete OutputConf records using their ids.
  # [+ids+]     Array of outputConfs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteOutputConfsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'outputConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
