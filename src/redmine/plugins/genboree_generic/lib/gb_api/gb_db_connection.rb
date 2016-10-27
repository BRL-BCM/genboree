require 'mysql2'
require 'brl/db/dbrc'

module GbApi
  
  # Encapsulates key access to the Genboree main MySQL database for the
  #  Genboree instance providing authentication services to this Redmine.
  #
  # @note Since it's intended for the authentication aspect of Genboree [only],
  #   generally you just use it the genboreeuser table record for a given
  #   login.
  class GbDbConnection
    MAX_RETRIES = 5
  
    attr_accessor :dbrc
  
    # Initialize for a given genboree authorization host.
    def initialize(gbAuthHost)
      @dbrc = BRL::DB::DBRC.new(nil, "DB:#{gbAuthHost}")
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
    end
  
    # Get the genboreeuser table record for login
    # @param [String] login OPTIONAL. The login, typically the current Redmine login which is default.
    # @return [Array, nil] The genboreeuser row matching login or nil if not found.
    def userRecByGbLogin(login=User.current.login)
      resultSet = userRecsByGbLogin(login)
      return (resultSet.is_a?(Array) ? resultSet.first : nil)
    end
  
    # Get all the externalHostAccess table records for a genboree user, given
    #  the user's genboree userId number.
    # @param [Fixnum] userId The genboree user id number.
    # @return [Array<Array>, nil] Array of all externalHostAccess rows, possibly empty, or nil if error.
    def allExternalHostInfoByGbUserId(userId)
      sql = "select * from externalHostAccess where userId = #{Mysql2::Client.escape(userId.to_s)}"
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
  
    # Get all genboreeuser rows.
    # @ return [Array<Array>, nil] All the genboreeuser rows or nil if errro.
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
  
    # Gets "all" genboreeuser records for a given Genboree login; obviously
    #   this should be a result set (array of arrays) with exactly 1 row.
    #   Better to just use {#userRecByGbLogin} perhaps, unless you need the
    #   uniformity of always getting back a proper result set.
    # @param [String] login OPTIONAL. The login, typically the current Redmine login which is default.
    # @return [Array<Array>] Result set with genboreeuser row matching login or empty if not found.
    def userRecsByGbLogin(login)
      sql = "select * from genboreeuser where name = '#{Mysql2::Client.escape(login)}'"
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
  
    # Get a Mysql2 client connected to the authenticating Genboree's main MySQL database.
    # @note Will apply retrying if immediate connection unsuccessful.
    # @return [Mysql2::Client, nil] The connected {Mysql2::Client} or nil if error.
    def getMysql2Client()
      maxRetries = MAX_RETRIES
      driver = @dbrc.driver
      driverFields = driver.dup.split(/:/)
      thirdField = driverFields[2]
      client = nil
      dbName = nil
      # Get params for making client.
      socket = host = nil
      if(thirdField =~ /host\s*=\s*([^ \t\n:;]+)/)
        host = $1
      elsif(thirdField =~ /socket\s*=\s*([^ \t\n:;]+)/)
        socket = $1
      elsif(driverFields.size >= 4) #  old-style driver string
        host = driverFields[3]
      else
        raise "ERROR: #{driver.inspect} does not appear to be correct. Should be either a 3-field driver string, which host or socket parameter in the 3rd field OR an old-style 4-field driver string with the host in the 4th field."
      end
      if(thirdField =~ /database\s*=\s*([^ \t\n:;]+)/)
        dbName = $1
      else
        dbName = thirdField
      end
      # Try to create client which will establish connection to mysql server
      lastConnErr = nil # The last Exception thrown during the creation attempt.
      connRetries = 0
      loop {
        if(connRetries < MAX_RETRIES)
          connRetries += 1
          begin
            if(host)
              client = Mysql2::Client.new(:host => host, :username => @dbrc.user, :password => @dbrc.password, :database => dbName)
            else
              client = Mysql2::Client.new(:socket => socket, :username => @dbrc.user, :password => @dbrc.password, :database => dbName)
            end
          rescue Exception => lastConnErr
            # Slightly variable progressive sleep.
            sleepTime = ((connRetries / 2.0) + 0.4 + rand())
            # 1-line log msg about this failure
            $stderr.puts "WARNING", "Attempt ##{connRetries} DB connect to #{host ? host.inspect : socket.inspect} failed. Will retry in #{'%.2f' % sleepTime} secs. Maximum total attempts: #{maxRetries}. Exception class and message: #{lastConnErr.class} (#{lastConnErr.message.inspect})."
            sleep(sleepTime)
          end
        else  # Tried many times and still cannot connect. Big problem...
          msg = "ALL #{connRetries} attempts failed to establish DB connection to #{host ? host.inspect : socket.inspect}. Was using these params: maxRetries = #{maxRetries.inspect}, host = #{host.inspect}, socket = #{socket.inspect}, username = #{@dbrc.user.inspect}, database = #{dbName.inspect}, driver = #{driver.inspect}, driverFields = #{driverFields.inspect}, thirdField = #{thirdField.inspect}.\n    Last Attempt's Exception Class: #{lastConnErr ? lastConnErr.class : '[NONE?]'}\n    Last Attempt's Exception Msg: #{lastConnErr ? lastConnErr.message.inspect : '[NONE?]'}\n    Last Attempts's Exception Backtrace:\n#{lastConnErr ? lastConnErr.backtrace.join("\n") : '[NONE?]'}\n\n"
          $stderr.puts "FATAL:\n\n#{msg}"
          raise Exception, msg
        end
        break if(client)
      }
      return client
    end
  end
end
