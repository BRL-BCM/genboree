require 'mysql2'
require 'mysql2/em'
require 'brl/db/dbrc'

module GbDb
  class GbUsers < GbDb::DbConnection
    # Get all genboreeuser rows.
    # @note This is a BLOCKING call. Also, it's stupid why are you using it??
    # @return [Array<Array>, nil] All the genboreeuser rows or nil if errro.
    def allUsers()
      sql = 'select * from genboreeuser '
      client = nil
      retVal = nil
      begin
        client = getMysql2Client()
        recs = client.query(sql)
        retVal = recs.entries
      rescue => err
        $stderr.puts err
      ensure
        client.close
      end
      return retVal
    end
  end
end