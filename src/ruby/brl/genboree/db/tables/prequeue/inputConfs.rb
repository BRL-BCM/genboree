require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with InputConf-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: inputConfs
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_INPUTCONF_BY_ID = 'update inputConfs set input = ? where id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get inputConf record by its id
  # [+id+]      The ID of the inputConf record to return
  # [+returns+] Array of 0 or 1 inputConf  rows
  def selectInputConfById(id)
    return selectByFieldAndValue(:otherDB, 'inputConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get InputConfs records using a list of ids
  # [+ids+]     Array of inputConf IDs
  # [+returns+] Array of 0+ inputConfs records
  def selectInputConfsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'inputConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select InputConf records using supplied MySQL Fulltext search string for
  # match the input column against, i.e. via a "WHERE MATCH(input) AGAINST('searchStr' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  def selectInputConfsByFulltext(fulltextSearchString, mode=:boolean)
    return selectByFulltext(:otherDB, 'inputConfs', 'input', fulltextSearchString, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select InputConf records using supplied Array of strings to build an "exact phrase" keyword string for
  # matching the input column against (using the "" fulltext operator.
  # i.e. via a "WHERE MATCH(input) AGAINST('"word1 word2 ... wordN"' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  # - If you need more custom fulltext search strings, such as combinations of one-or-more + operands and one-or-more ""
  #   operands, you should use selectInputConfsByFulltext()
  # [+keywords]  Array of Strings which are the keywords to use within the "" operator
  def selectInputConfsByFulltextKeywords(keywords, mode=:boolean)
    return selectByFulltextKeywords(:otherDB, 'inputConfs', 'input', keywords, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new InputConf record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+inputsText+]  The complete VALUE for a job's "inputs" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]       Number of rows inserted
  def insertInputConf(inputsText)
    data = [ inputsText ]
    return insertRecords(:otherDB, 'inputConfs', data, true, 1, 1, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a InputConf record identified by its id
  # [+id+]          InputConfs.id of the record to update
  # [+inputsText+]  The complete replacement VALUE for a job's "inputs" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]     Number of rows inserted
  def updateInputConfById(id, inputsText)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_INPUTCONF_BY_ID)
      stmt.execute(inputsText, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_INPUTCONF_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a InputConf record using its id.
  # [+id+]      The inputConfs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteInputConfById(id)
    return deleteByFieldAndValue(:otherDB, 'inputConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete InputConf records using their ids.
  # [+ids+]     Array of inputConfs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteInputConfsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'inputConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
