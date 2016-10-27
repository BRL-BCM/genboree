require 'mysql2'
require 'brl/genboree/dbUtil'
module BRL; module Genboree

module DB; module Tables; module GbToRmMaps
  GB_TO_RM_MAPS_WILDCARD = "*"
  GB_TO_RM_MAPS_ESC_WILDCARD = Mysql2::Client.escape(GB_TO_RM_MAPS_WILDCARD)
  GBTORMMAPS_FIELDS = ["gbGroup", "gbType", "gbRsrc", "rmType", "rmRsrc"]

  def selectAllGbToRmMaps
    selectAll(:mainDB, "gbToRmMaps", "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  def selectGbToRmMapsByGroup(groupName)
    selectByFieldAndValue(:mainDB, "gbToRmMaps", "gbGroup", groupName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select gbToRmMaps with single filter values
  # @param [String] groupName the name of the group to include in a where clause
  # @param [Hash<String, String>, Hash<String, Array<String>>] filtersHash (only select records 
  #   that match the values of  the filtersHash)  with keys "gbType", "gbRsrc", "rmType", or "rmRsrc"
  #   if a value is a String then only records that match the value are returned; the wild card operator
  #   "*" may be used to represent "zero or more of any character"; if the value is an Array<String>, then
  #   returned records will match at least one of the values (an "or" operation); filters are joined
  #   together with an "and" operation
  # @return [NilClass, Array<Hash>] objects resulting from query or nil if error (logged to stderr)
  def selectGbToRmMapsByGroupAndFilters(groupName, filtersHash)
    rv = nil
    begin
      client = getMysql2Client(:mainDB)
      filtersHash = filtersHash.dup()
      filtersHash["gbGroup"] = groupName
      sql = "select * from gbToRmMaps where #{composeWhereClause(filtersHash)}"
      resultSet = client.query(sql, :cast_booleans => true) # @todo cast_booleans necessary?
      rv = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return rv
  end

  # Insert gbToRmMaps (upsert if unique index on gbGroup, gbRsrc, rmRsrc matches)
  # @param [Array<Array>] records @see BRL::Genboree::REST::Data::GbToRmMapEntity#toRecord
  # @return [Integer, NilClass] number of records inserted or nil if error
  def insertGbToRmMaps(records)
    rv = nil
    logErrors = true
    begin
      if(records.empty?)
        raise "Unable to insert provided records because there records is an empty array!"
      else
        data = records.dup()
        numValues = data.size
        numBindVarsPerValue = data.first.size
        logErrors = false
        dupKeyUpdateColumn = ["gbType", "rmType"]
        rv = insertRecords(:mainDB, "gbToRmMaps", data, true, numValues, numBindVarsPerValue, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", dupKeyUpdateColumn)
      end
      rescue => @err
        if(logErrors)
          DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err)
        end
      end
    return rv
  end

  # Delete existing records by their values
  # @todo select then delete by id?
  # @todo delete by hash of record values?
  def deleteGbToRmMaps(records)
    rv = nil
    begin
      client = getMysql2Client(:mainDB)
      sql = "delete from gbToRmMaps where #{composeDeleteWhereClause(records)}"
      resultSet = client.query(sql, :cast_booleans => true) # @todo cast_booleans necessary?
      rv = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      client.close rescue nil
    end
    return rv
  end

  # Delete all gbToRmMaps associated with a given group
  def deleteGbToRmMapsByGroup(groupName)
    rv = deleteByFieldAndValue(:mainDB, "gbToRmMaps", "gbGroup", groupName, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  private

  # Construct where clause of a select statement for queries on this table
  # @param [Hash] filtersHash @see selectGbToRmMapsByGroupAndFilters
  def composeWhereClause(filtersHash)
    rv = nil
    if(filtersHash.empty?)
      raise GbToRmMapsError.new("Invalid filtersHash: it is empty")
    end
    fieldSubClauses = filtersHash.map { |key, value|
      if(value.is_a?(Array))
        whereSubClauses = value.map { |valueItem|
          if(containsWildcard?(valueItem))
            composeLikeClause(key, valueItem)
          else
            composeEqClause(key, valueItem)
          end
        }
        subClause = "#{whereSubClauses.join(" OR ")}"
      elsif(value.is_a?(String))
        if(containsWildcard?(value))
          subClause  = composeLikeClause(key, value)
        else
          subClause = composeEqClause(key, value)
        end
      else
        raise GbToRmMapsError.new("Invalid filtersHash; key #{key.inspect} has a value of class #{value.class} which is not an Array or String")
      end
    }
    rv = fieldSubClauses.join(" AND ")
    return rv
  end

  # Construct where clause of a delete statement for queries on this table
  # @Param [Array] records @see deleteGbToRmMaps
  def composeDeleteWhereClause(records)
    rv = nil
    if(records.empty?)
      raise GbToRmMapsError.new("Invalid records to delete: there are no records")
    else
      if(records.first.size != GBTORMMAPS_FIELDS.size)
        raise GbToRmMapsError.new("Invalid records: number of fields does not match the number of fields in the table")
      end

      recordsClauses = records.map { |record|
        recordSubClause = []
        record.each_index { |ii|
          field = GBTORMMAPS_FIELDS[ii]
          value = record[ii]
          recordSubClause << composeEqClause(field, value)
        }
        "(#{recordSubClause.join(" AND ")})"
      }

      rv = recordsClauses.join(" OR ")
    end
    return rv
  end

  # Return true if str contains wildcard
  def containsWildcard?(str)
    ii = str.index(GB_TO_RM_MAPS_WILDCARD)
    return !ii.nil?
  end

  # Perform pattern matching in a where clause of a select statement
  # @see [BRL::Genboree::DBUtil.makeMysql2LikeSQL]
  def composeLikeClause(fieldName, fieldValue)
    escValue = Mysql2::Client.escape(fieldValue)
    escValue.gsub!(escWildcard, "%")
    return "#{fieldName} LIKE \"#{escValue}\""
  end

  # Perform exact match for a value in a where clause of a select statement
  def composeEqClause(fieldName, fieldValue)
    return "#{fieldName} = \"#{Mysql2::Client.escape(fieldValue)}\""
  end
end; end; end

class DBUtil
  include DB::Tables::GbToRmMaps
end

class GbToRmMapsError < DbUtilError
end

end; end
