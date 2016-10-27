require 'brl/genboree/dbUtil'

module BRL; module Genboree; module DB; module Tables; module API
  TABLE_NAME = "apiRecord"
  KEY_FIELD = "id"
  FIELDS = ["userName", "rsrcType", "rsrcPath", "queryString", "method", "contentLength", "clientIp", "respCode", "reqStartTime", "reqEndTime", "machineName", "thinNum", "memUsageStart", "memUsageEnd", "byteRange", "userAgent", "referer"]
  def self.newApiRecordHash(fields=FIELDS)
    hh = {}
    FIELDS.each { |field| hh[field] = nil }
    return hh
  end
end; end; end; end; end

module BRL; module Genboree
class DBUtil

  # Insert API request information into log database
  # @param [Array<Object>] data the record to insert into the table
  # @see insertRecords
  # @return [Integer] @lastInsertId of API record inserted
  def insertApiRecord(data)
    retVal = nil
    begin
      if(data.is_a?(Hash))
        array = Array.new(DB::Tables::API::FIELDS.size)
        DB::Tables::API::FIELDS.each_index { |ii|
          field = DB::Tables::API::FIELDS[ii]
          array[ii] = data[field]
        }
        data = array
      end
      nInserted = insertRecords(:mainDB, DB::Tables::API::TABLE_NAME, data, true, 1, DB::Tables::API::FIELDS.size, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
      retVal = @lastInsertId
    rescue => @err
      DBUtil.logDbError("ERROR: Could not insert API record into table", @err, "n/a")
    end
    return retVal
  end

  def updateApiRecord(id, data)
    retVal = nil
    begin
      if(data.is_a?(Array))
        raise ArgumentError.new("Provided data size #{data.size} does not match table field size #{DB::Tables::API::FIELDS.size}") unless(data.size == DB::Tables::API::FIELDS.size)
        hh = {}
        data.each_index { |ii|
          field = DB::Tables::API::FIELDS[ii]
          value = data[ii]
          hh[field] = value unless(value.nil?)
        }
        data = hh 
      end
      nUpdated = updateByFieldAndValue(:mainDB, DB::Tables::API::TABLE_NAME, data, DB::Tables::API::KEY_FIELD, id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
      retVal = nUpdated
    rescue => @err
      DBUtil.logDbError("ERROR: Could not insert API record into table", @err, "n/a")
    end
    return retVal
  end

end
end; end
