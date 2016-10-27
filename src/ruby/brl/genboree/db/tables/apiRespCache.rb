require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# GROUP RELATED TABLES - DBUtil Extension Methods for dealing with api response cache table
# ------------------------------------------------------------------

module BRL ; module Genboree
class DBUtil
  # --------
  # Table: commands
  # --------
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # ############################################################################
  # METHODS
  # ############################################################################
  # Get api response cache record record by its id
  # [+id+]      The ID of the apiRespCache record to return
  # [+returns+] Array of 0 or 1  apiRespCache rows
  def selectApiRespById(id)
    return selectByFieldAndValue(:otherDB, 'apiRespCache', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new apiRespCache record.
  # @param [String] cacheKey The id of the apiRespCache record, generated from a normalized query string.
  # @param [String] rsrcPath  resource path of the api request
  # @param [String] versionId last edit time of the source collection or version of relevant source document
  # @param [String] content the api response.
  # @param [String] secKey other key validation paramters associated with the resource path. 
  # @param [String] recordDate time of the entry of the data
  # @return [Fixnum] Number of rows inserted
  def insertRespCache(cacheKey, rsrcPath, versionId, content, secKey='', recordDate=nil)
    data = [ cacheKey, rsrcPath, versionId, content, secKey, recordDate ]
    return insertApiRespCache(data, 1)
  end

  # Inserts one or more records to the apiRespCache table
  # @param [Array, Array<Array>]. An array of values to be inserted
  # @param [Fixnum] numResp number of rows inserted
  def insertApiRespCache(data, numResp)
    return insertRecords(:otherDB, 'apiRespCache', data, false, numResp, 6, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

end # class DBUtil
end ; end # module BRL ; module Genboree
