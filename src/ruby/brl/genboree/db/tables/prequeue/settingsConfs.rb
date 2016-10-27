require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with Group-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: settingsConfs
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_SETTINGSCONF_BY_ID = 'update settingsConfs set settings = ? where id = ?'

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get settingsConf record by its id
  # [+id+]      The ID of the settingsConf record to return
  # [+returns+] Array of 0 or 1 settingsConf  rows
  def selectSettingsConfById(id)
    return selectByFieldAndValue(:otherDB, 'settingsConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get SettingsConfs records using a list of ids
  # [+ids+]     Array of settingsConf IDs
  # [+returns+] Array of 0+ settingsConfs records
  def selectSettingsConfsByIds(ids)
    return selectByFieldWithMultipleValues(:otherDB, 'settingsConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select SettingsConf records using supplied MySQL Fulltext search string for
  # match the settings column against, i.e. via a "WHERE MATCH(settings) AGAINST('searchStr' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  def selectSettingsConfsByFulltext(fulltextSearchString, mode=:boolean)
    return selectByFulltext(:otherDB, 'settingsConfs', 'settings', fulltextSearchString, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select SettingsConf records using supplied Array of strings to build an "exact phrase" keyword string for
  # matching the settings column against (using the "" fulltext operator.
  # i.e. via a "WHERE MATCH(settings) AGAINST('"word1 word2 ... wordN"' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  # - If you need more custom fulltext search strings, such as combinations of one-or-more + operands and one-or-more ""
  #   operands, you should use selectSettingsConfsByFulltext()
  # [+keywords]  Array of Strings which are the keywords to use within the "" operator
  def selectSettingsConfsByFulltextKeywords(keywords, mode=:boolean)
    return selectByFulltextKeywords(:otherDB, 'settingsConfs', 'settings', keywords, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new SettingsConf record
  # - sets dbu.lastInsertId in case you need it for follow up
  # [+settingssText+]  The complete VALUE for a job's "settingss" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]       Number of rows inserted
  def insertSettingsConf(settingssText)
    data = [ settingssText ]
    return insertRecords(:otherDB, 'settingsConfs', data, true, 1, 1, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a SettingsConf record identified by its id
  # [+id+]          SettingsConfs.id of the record to update
  # [+settingssText+]  The complete replacement VALUE for a job's "settingss" section. Must be enclosed in [ ]. Should parse to JSON as-is.
  # [+returns+]     Number of rows inserted
  def updateSettingsConfById(id, settingssText)
    retVal = nil
    begin
      connectToOtherDb()
      stmt = @otherDbh.prepare(UPDATE_SETTINGSCONF_BY_ID)
      stmt.execute(settingssText, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_SETTINGSCONF_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Delete a SettingsConf record using its id.
  # [+id+]      The settingsConfs.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deleteSettingsConfById(id)
    return deleteByFieldAndValue(:otherDB, 'settingsConfs', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete SettingsConf records using their ids.
  # [+ids+]     Array of settingsConfs.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deleteSettingsConfsByIds(ids)
    return deleteByFieldWithMultipleValues(:otherDB, 'settingsConfs', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
