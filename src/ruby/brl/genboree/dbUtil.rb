$VERBOSE = nil

# ##############################################################################
# Overriding 'require' so as to assume all paths are untainted.  This works around
# the safe level errors in which require 'rubygems' was throwing an insecure 'require' operation
# ##############################################################################
#module Kernel
#  alias require__orig require  # Should be either Ruby's or Rubygems at this point
#
#  def require(path)
#    require__orig path.dup.untaint
#  end
#end  # module Kernel

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'sha1'
require 'dbi'
require 'stringio'
require 'json'
require 'mysql2'
require 'brl/db/dbrc'
require 'brl/sql/binning'
require 'brl/util/util'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
# Also/Old: Questionnaire stuff not deployed yet...only include if available on dev machine
# require 'brl/genboree/sampleQuestionnaire/dbUtil'


# ##############################################################################
# AUTO-LOAD ENTITY-SPECIFIC RUBY FILES THAT EXTEND DBUtil CLASS
# ##############################################################################
module BRL ; module Genboree
  # Path(s) where to find Ruby files that extend DBUtil class will some
  # extra methods (should all be related to the same kind of resource)
  DBUTIL_EXTENSION_PATHS = [ "brl/genboree/db/tables", "brl/genboree/db/tables/prequeue", "brl/genboree/db/tables/kb", "brl/genboree/db/tables/hub" ]
  DBUTIL_FOUND_EXTENSIONS = {}  # For ensuring given extension only required once, even if found on different paths.
end ; end

class DBI::StatementHandle
  # Map the columns and results into an Array of Hash resultset.
  # Returns the entire array.
  #
  # DOES TYPE CONVERSION unlike fetch_hash
  #
  def fetch_all_hash
    sanity_check({:fetchable => true, :prepared => true, :executed => true})
    fetchedRows = []
    while (row = @handle.fetch) != nil
      rowHash = {}
      row.each_with_index {|v,i| rowHash[column_names[i]] = column_types[i].parse(v)}
      fetchedRows.push(rowHash)
    end
    @handle.cancel
    @fetchable = false
    return fetchedRows
  end
end

module BRL ; module Genboree

class DbUtilError < RuntimeError
end

#--------------------------------------------------------------------------
# Wrapper class for convenience
#--------------------------------------------------------------------------
class DBUtil
  # Set up class instance variables
  class << self
    # @return [Boolean] indicating whether class-level resources have been dynamically
    #   found and stored already or not. i.e. so they are done once per process.
    attr_accessor :resourcesLoaded
    DBUtil.resourcesLoaded = false
  end

  # Resource discovery: Find submitter & manager classes
  unless(DBUtil.resourcesLoaded or ((GenboreeRESTRackup rescue nil) and GenboreeRESTRackup.classDiscoveryDone[self]))
    DBUtil.resourcesLoaded = true
    # Record that we've done this class's discovery. Must do before start requiring.
    # - Must use already-defined global store of this info to prevent dependency requires while trying to define this class
    #   re-entering this discovery block over and over and over.
    (GenboreeRESTRackup.classDiscoveryDone[self] = true) if(GenboreeRESTRackup rescue nil)
    # This will automatically find and require Ruby files in DBUTIL_EXTENSION_PATHS
    # paths. The purpose is to AUTOMATICALLY bring in extensions of DBUtil class which
    # add new entity-specific sets of methods.
    #
    # Using this approach:
    # (a) we don't have to manually require such files (~newish way)
    # (b) we don't have to manually include modules (old way)
    # (c) Ruby automatically finds the files and requires them, and DBUtil automatically
    #     gets the huge set of methods it needs.
    $LOAD_PATH.sort.each { |topLevel|
      if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
        # We need to ENSURE we will only use the FIRST source file for a given extensionPath.
        # While a given extensionPath source file may be found under multiple topLevel paths,
        # (and consider that the SAME extensionPath may be found via different topLevel paths due to symlinks)
        # the FIRST one is the ONLY one we're allowed to use. This is standard convention for
        # RUBYLIB, PERL5LIB, PYTHONPATH, PATH, LD_LIBRARY_PATH, etc.
        # - Thus, the code below will note in BRL::Genboree::DBUTIL_FOUND_EXTENSIONS where a given extension was found.
        BRL::Genboree::DBUTIL_EXTENSION_PATHS.each { |extensionPath|
          extensionFiles = Dir["#{topLevel}/#{extensionPath}/*.rb"]
          extensionFiles.sort.each { |extFile|
            extension = "#{extensionPath}/#{File.basename(extFile, ".rb")}"
            unless(BRL::Genboree::DBUTIL_FOUND_EXTENSIONS[extension])
              begin
                require extFile
                BRL::Genboree::DBUTIL_FOUND_EXTENSIONS[extension] = extFile
              rescue => err # just log error and try more files
                BRL::Genboree::GenboreeUtil.logError("ERROR: #{__FILE__} => failed to require file '#{extFile.inspect}'.", err)
              end
            end
          }
        }
      end
    }
    #$stderr.debugPuts(__FILE__, "<Outside of Method>", "LOAD", "registered db table classes")
  end

  # For convenience/organization, mixin the functions from the modules above
  begin # sample questionnaires may not be deployed
    include BRL::Genboree::QuestionnairesTable
    include BRL::Genboree::SampleAttTypesTable
    include BRL::Genboree::QuestionsTable
    include BRL::Genboree::RevisionsTable
    include BRL::Genboree::QuestionRevisionJoinsTable
  rescue Exception => err
  end

  # ############################################################################
  # CONSTANTS
  # ############################################################################
  # DRIVER_STR = 'dbi:Mysql:%dbName%:localhost'
  MAX_CONN_RETRY = 10
  RETRY_SLEEP = 2
  MAX_INSERT_VALUES = 32_000

  # Set up a cached version of the simple (?, ?, ?) sql set strings and for the
  # more complex values strings like ((?,?), (?, ?)). No sense building same
  # strings over and over.
  # - a "Class Instance" variable used like this GenboreeConfig.cache
  # - only the GenboreeConfig.load() class method will take advantage of this caching.
  # - not thread friendly, be careful!!
  # - Current cache keys are :sqlSetStrs and :sqlValueStrs
  class << self
    attr_accessor :cache, :cacheLock
  end
  @cache = nil
  @cacheLock = Mutex.new

  # ------------------------------------------------------------------
  # CONSTANTS
  # ------------------------------------------------------------------
  SPECIAL_TABLE_NAME_MAP = { 'user' => 'genboreeuser', 'users' => 'genboreeusers', 'group' => 'genboreegroup', 'groups' => 'genboreegroup', 'database' => 'refseq', 'databases' => 'refseq' }

  # ############################################################################
  # ATTRIBUTES
  # ############################################################################
  attr_accessor :dataDbh, :genbDbh, :dbrcKey, :dbrc, :driverPattern
  attr_accessor :mainGenbDbName, :mainGenbDbHost, :mainGenbDriver
  attr_accessor :dataDbName, :dataDriver
  attr_accessor :err
  attr_accessor :driver2dbh, :dbh2driver
  attr_accessor :otherDbh, :otherDbHost, :otherDbName, :otherDbDriver
  attr_accessor :cacheConn
  # Only valid IMMEDIATELY and for the last DB insert/update for ANY dbh or mysql2 client.
  attr_accessor :lastInsertId

  # --------------------------------------------------------------------------
  # INITIALIZER
  # --------------------------------------------------------------------------
  # Initialized using appropriate database connection info (from DBRC).
  # -NO- Connections established. This is done JIT and lazily.
  def initialize(genboreeDbrcKey, dataDbName, dbrcFileName=nil)    # Init current database handles and caches
    @dataDbh, @genbDbh, @dataDriver = nil
    @otherDbDbrcKey = @otherDbh = @otherDbHost = @otherDbName = @otherDbDriver = nil
    @lastInsertId = nil
    @genbConf = BRL::Genboree::GenboreeConfig.load()
    @driver2dbh = {}
    @dbh2driver = {}
    # What key to use in the dbrc file?
    @dbrcKey = genboreeDbrcKey
    # What is the name of the current user database?
    @dataDbName = dataDbName
    # Config DBRC object to use (same user will also access the data database)
    # First, what dbrcFile to use? Provided, from ENV, or default in user home dir?
    if(!dbrcFileName.nil?)
      @dbrcFile = dbrcFileName
    elsif(ENV.key?('DBRC_FILE') and File.exist?(File.expand_path(ENV['DBRC_FILE'])))
      @dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    elsif(ENV.key?('DB_ACCESS_FILE') and File.exist?(File.expand_path(ENV['DB_ACCESS_FILE'])))
      @dbrcFile = File.expand_path(ENV['DB_ACCESS_FILE'])
    else
      @dbrcFile = File.expand_path('~/.dbrc')
    end
    # Second, read the DBRC record (corresponding to the info for the main genboree database)
    @dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
    @dbrc.user = @dbrc.user.dup.untaint
    @dbrc.password = @dbrc.password.dup.untaint
    # Make general database resource string
    driverFields = @dbrc.driver.dup.split(/:/)
    thirdField = driverFields[2]
    if(thirdField =~ /database\s*=\s*([^ \t\n:;]+)/)
      @mainGenbDbName = $1
    else
      @mainGenbDbName = thirdField
    end
    @driverPattern = "#{driverFields[0]}:#{driverFields[1]}:database=%DATABASE%;host=%HOST%;%OPTS%"
    # Driver for main genboree database
    @mainGenbDriver = @dbrc.driver.dup.untaint
    # caching on by default
    @cacheConn =
    {
      :mainDB => true,
      :userDB => true,
      :otherDB => true
    }
  end

  # --------------------------------------------------------------------------
  # Instance methods
  # --------------------------------------------------------------------------

  # Connect to the database specified by +tableType+
  #
  # [+tableType+]   Symbol (mainDB, :userDB, otherDB)
  # [+returns+]     Database handler
  def connectToDB(tableType)
    dbh = nil
    case tableType
      when :mainDB
        connectToMainGenbDb()
        dbh = @genbDbh
      when :userDB
        connectToDataDb()
        dbh = @dataDbh
      when :otherDB
        connectToOtherDb()
        dbh = @otherDbh
      else
        raise ArgumentError, "ERROR: unknown tableType argument '#{tableType}'; should one of: :mainDB, :userDB, :otherDB"
    end
    return dbh
  end

  # Connect to main genboree database.
  def connectToMainGenbDb(useCache=@cacheConn[:mainDB])
    retVal = false
    @genbDbh = nil # ensure we check the connection is good, even if it's already created
    @genbDbh = self.attemptConnection(@mainGenbDriver, useCache)
    return !@genbDbh.nil?
  end

  # Connect to Genboree user database.
  # - This involves looking up the host that the user database lives on and then making a conn to it.
  def connectToDataDb(useCache=@cacheConn[:userDB], opts='')
    retVal = false
    @dataDbh = nil # ensure we check the connection is good, even if it's already created and is our current dataDbh
    unless(@dataDbName.nil? or @dataDbName.empty?)
      # First, make sure connected to main genboree database
      self.connectToMainGenbDb()
      # Second, find host for the user database using genboree.database2host table
      hostName = self.getHostForDbName(@dataDbName)
      hostName = hostName[0]['databaseHost']
      # Third, get a connection to the user database
      # (A) Make driver string
      @dataDriver = @driverPattern.gsub(/%DATABASE%/, @dataDbName).gsub(/%HOST%/, hostName).gsub(/%OPTS%/, opts)
      # (B) Attempt to get connection via driver
      @dataDbh = self.attemptConnection(@dataDriver, useCache)
    end
    return !@dataDbh.nil?
  end

  # Prep for a Mysql2 client based data DB connection. Unlike DBI version connectToDataDb(), DOES NOT MAKE actual CONNECTION. Prep.
  # - This involves looking up the host that the user database lives on and then making a conn to it.
  def prepDataDbConn(opts='')
    retVal = false
    unless(@dataDbName.nil? or @dataDbName.empty?)
      # Find host for the user database using genboree.database2host table
      hostNameRows = self.getHostForDbName(@dataDbName)
      hostName = hostNameRows.first['databaseHost']
      # Make driver string
      @dataDriver = @driverPattern.gsub(/%DATABASE%/, @dataDbName).gsub(/%HOST%/, hostName).gsub(/%OPTS%/, opts)
      retVal = true
    end
    return retVal
  end

  def getMaxRetries()
    # Default/fallback is to use the hardcoded MAX_CONN_RETRY value in this class. This will be used if we don't find a better one.
    retVal = MAX_CONN_RETRY
    # But every DBRC record has a max_reconn value in the 6th column. If available, use it.
    if(@dbrc and @dbrc.max_reconn.to_s =~ /\d+/)
      retVal = @dbrc.max_reconn.to_i
    # The GenboreeConfig may also have a connRetries property. If couldn't get max_reconn from the dbrc, try looking for this.
    elsif(@genbConf and @genbConf.connRetries.to_s =~ /\d+/)
      retVal = @genbConf.connRetries.to_i
    end
    return retVal
  end

  def attemptConnection(driver, checkCache=true, maxRetries=getMaxRetries(), retrySleep=RETRY_SLEEP)
    # (A) Check cache first?
    if(checkCache)
      dbh = @driver2dbh[driver]
    else
      dbh = nil
    end
    # (B) If not in cache, not looking in cache, or dead connection, get a fresh one
    if(!DBUtil::alive?(dbh))
      # First, try to ensure the thing is closed...may not go well if not alive, so protect:
      unless(dbh.nil?)
        begin
          dbh.disconnect()
        rescue => disErr
          DBUtil.logDbError("WARNING: #{__FILE__}:#{__method__}() => failed to disconnect from non-alive DB handle. (driver: #{driver.inspect})", disErr)
        ensure # clear from the cache
          @driver2dbh.delete(driver)
          @dbh2driver.delete(dbh)
          dbh = nil
        end
      end
       # Now try to get a proper connection
      begin
        retryCount = 0
        while(retryCount < maxRetries)
          begin
            retryCount += 1
            dbh = DBI.connect(driver, @dbrc.user, @dbrc.password)
            retryCount = 0
            break
          rescue => retriableErr
            DBUtil.logDbError(
              "WARNING: #{__FILE__}:#{__method__}() => Failed attempt #{retryCount} to connect to data db. " +
                (retryCount >= MAX_CONN_RETRY ? 'Max retry count achieved. Will not retry again.' : "Will try again after short sleep.") +
                "  driver: #{driver.inspect}\n",
              retriableErr,
              "n/a"
            )
            if(retryCount >= MAX_CONN_RETRY) # Re-raise error if that was the last retry attempt
              dbu = nil
              raise retriableErr
            else # Pause and try again
              dbu = nil
              sleep(retrySleep)
            end
          end
        end
        # Arrive here with fresh connection. Add fresh connection to cache
        if(checkCache)
          @driver2dbh[driver] = dbh
          @dbh2driver[dbh] = driver
        end
      rescue Exception => cErr
        DBUtil.logDbError("FATAL ERROR: #{__FILE__}:#{__method__}() => can't get conn to data database due to fundamental problem.\n" +
                          "       - driver: #{@dataDriver.inspect}\n" +
                          "       - user: #{@dbrc.user}\n",
                          cErr,
                          "n/a")
        raise
      end
    end
    # Either got live connection from cache, or made a fresh one:
    return dbh
  end

  def getMysql2Client(dbType=:mainDB)
    driver = dbName = maxRetries = nil
    if(dbType==:mainDB)
      driver = @mainGenbDriver
      dbName = @mainGenbDbName
      maxRetries = getMaxRetries()
    elsif(dbType==:userDB)
      # Prep for data DB connection via Mysql2 libs. (mainly to get hostname for the @dataDbName and to set up appropriate @dataDbDriver)
      prepDataDbConn()
      driver = @dataDriver
      dbName = @dataDbName
      maxRetries = getMaxRetries()
    elsif(dbType==:otherDB)
      # Prep for data DB connection via Mysql2 libs. (mainly to get hostname for the @otherDbName and to set up appropriate @otherDbDriver)
      prepOtherDbConn()
      driver = @otherDbDriver
      dbName = @otherDbName
      if(@otherDbDbrc and @otherDbDbrc.max_reconn)
        maxRetries = @otherDbDbrc.max_reconn.to_i
      else
        maxRetries = getMaxRetries()
      end
    else
      raise "ERROR: #{dbType.inspect} is not a known type of Genboree database."
    end
    # determine socket or host info
    client = nil
    unless(driver.nil?)
      driverFields = driver.split(/:/)
      thirdField = driverFields[2]
      unless(dbName)
        if(thirdField =~ /database\s*=\s*([^ \t\n:;]+)/)
          dbName = $1
        elsif(driverFields.size >= 4)
          dbName = driverFields[2]
        else
          raise "ERROR: #{driver.inspect} does not appear to be correct. Should be either a 3-field driver string, which host or socket parameter in the 3rd field OR an old-style 4-field driver string with the host in the 4th field."
        end
      end
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
      # Try to create client which will establish connection to mysql server
      lastConnErr = nil # The last Exception thrown during the creation attempt.
      connRetries = 0
      loop {
        if(connRetries < maxRetries)
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
            $stderr.debugPuts(__FILE__, __method__, "WARNING", "Attempt ##{connRetries} DB connect to #{host ? host.inspect : socket.inspect} failed. Will retry in #{'%.2f' % sleepTime} secs. Maximum total attempts: #{maxRetries}. Exception class and message: #{lastConnErr.class} (#{lastConnErr.message.inspect}).")
            sleep(sleepTime)
          end
        else  # Tried many times and still cannot connect. Big problem...
          msg = "ALL #{connRetries} attempts failed to establish DB connection to #{host ? host.inspect : socket.inspect}. Was using these params: maxRetries = #{maxRetries.inspect}, host = #{host.inspect}, socket = #{socket.inspect}, username = #{@dbrc.user.inspect}, database = #{dbName.inspect}, driver = #{driver.inspect}, driverFields = #{driverFields.inspect}, thirdField = #{thirdField.inspect}.\n    Last Attempt's Exception Class: #{lastConnErr ? lastConnErr.class : '[NONE?]'}\n    Last Attempt's Exception Msg: #{lastConnErr ? lastConnErr.message.inspect : '[NONE?]'}\n    Last Attempts's Exception Backtrace:\n#{lastConnErr ? lastConnErr.backtrace.join("\n") : '[NONE?]'}\n\n"
          $stderr.debugPuts(__FILE__, __method__, "FATAL", msg)
          raise Exception, msg
        end
        break if(client)
      }

    end
    return client
  end


  # Set a new "other" database (don't connect until forced to though)
  # +otherDbDbrcKey+ : dbrc key to use in @dbrcFile to find the correct record of this other database
  def setNewOtherDb(otherDbDbrcKey)
    resetOtherDb()
    @otherDbDbrcKey = otherDbDbrcKey
    # @dbrcFile is available upon initialize
    @otherDbDbrc = BRL::DB::DBRC.new(@dbrcFile, @otherDbDbrcKey)
    @otherDbDriver = @otherDbDbrc.driver.dup.untaint
    @otherDbName = @otherDbDbrc.dbName
    @otherDbHost = @otherDbDbrc.host
    return @otherDbName
  end

  # Clear the current genboree user database (but don't disconnect it or remove from cache)
  def resetOtherDb()
    @otherDbDbrc = @otherDbDbrcKey = @otherDbh = @otherDbDriver = nil
    return
  end

  # Connect to some other (non Genb) database via DBI.
  # - This involves looking up the host that the user database lives on and then making a conn to it.
  def connectToOtherDb(dbrcKey=nil, useCache=@cacheConn[:otherDB])
    retVal = false
    setNewOtherDb(dbrcKey) if(dbrcKey and dbrcKey != @otherDbDbrcKey)
    @otherDbh = nil # ensure we check the connection is good, even if it's already created and is our current dataDbh
    # (A) Check cache first
    @otherDbh = @driver2dbh[@otherDbDriver] if(useCache)
    # (B) If not in cache, not looking in cache, or dead connection, get a fresh one
    if(!DBUtil::alive?(@otherDbh))
      # Try to ensure the thing is closed...may not go well if not alive, so protect:
      unless(@otherDbh.nil?)
        begin
          @otherDbh.disconnect()
        rescue => disErr
          DBUtil.logDbError("WARNING: DBUtil#connectToOtherDb() => failed to disconnect from non-alive DB handle. (This is probably ok; not alive == can't disconnect. But if keeps recurring, it may reflect bugs in code like inappropriate disconnects() on db handles that the rest of server code assumes will remain connected and available!)", disErr)
        ensure
          @driver2dbh.delete(@otherDbDriver)
          @dbh2driver.delete(@otherDbh)
          @otherDbh = nil
        end
      end
      # Now try to get a proper connection, using connection info from @otherDbDbrc
      begin
        @otherDbh = DBI.connect(@otherDbDriver, @otherDbDbrc.user, @otherDbDbrc.password)
        # Add fresh connection to cache
        if(useCache)
          @driver2dbh[@otherDbDriver] = @otherDbh
          @dbh2driver[@otherDbh] = @otherDbDriver
        end
        retVal = true
      rescue => cErr
          DBUtil.logDbError("ERROR: DBUtil#connectToDataDb() => can't get conn to other database.\n" +
                            "       - otherDbDbrcKey: #{@otherDbDbrcKey}\n" +
                            "       - driver: #{@otherDbDriver.inspect}\n" +
                            "       - user: #{@otherDbDbrc.user}\n" +
                            "       - pw: #{(@otherDbDbrc.password.nil? or @otherDbDbrc.password.empty?) ? 'nil or empty!' : 'provided Ok (check that it is correct)'}" +
                            "       - otherDbDbrc:: #{@otherDbDbrc.inspect}\n",
                            cErr,
                            "n/a")
          retVal = false
      end
    else # It's not nil and it is alive
      retVal = true
    end
    return retVal
  end

  # Prep for a Mysql2 client based non Genb DB connection. Unlike DBI version connectToOtherDb(), DOES NOT MAKE actual CONNECTION. Prep.
  # - This involves looking up the host that the user database lives on and then making a conn to it.
  def prepOtherDbConn(dbrcKey=nil)
    retVal = setNewOtherDb(dbrcKey) if(dbrcKey and dbrcKey != @otherDbDbrcKey)
  end

  # "Close" a database handle properly.
  # If forceClosed, even if cached it will be closed and removed from cache
  def closeDbh(dbh, forceClosed=false)
    retVal = false
    # We don't want to close cached connections, we want to re-use them.
    # HOWEVER, if it's an uncached connection we should indeed close it since
    # it won't be reused and the code that asked for it says it's done with it.
    unless(dbh.nil? or (@dbh2driver.key?(dbh) and !forceClosed) )
      begin
        # If it's alive, disconnect it
        dbh.disconnect() if(DBUtil::alive?(dbh))
        # If it's either our current main genbDbh or our current dataDbh, clear them
        if(@genbDbh == dbh)
          @driver2dbh.delete(@mainGenbDriver)
          @dbh2driver.delete(@genbDbh)
          @genbDbh = nil
        elsif(@dataDbh == dbh)
          @driver2dbh.delete(@dataDriver)
          @dbh2driver.delete(@dataDbh)
          @dataDbh = nil
        elsif(@otherDbh == dbh)
          @driver2dbh.delete(@otherDbDriver)
          @dbh2driver.delete(@otherDbh)
          @otherDbh = nil
        end
        retVal = true
      rescue => @err
        DBUtil.logDbError("ERROR: DBUtil.closeDbh() => couldn't close dbh for some reason, but should have been able to.", @err, "n/a") ;
        retVal = false
      end
    end
    return retVal
  end

  def clearCaches()
    # Disconnect what is in our dbh/driver caches
    # - for disconnecting, just loop over one of the two caches
    unless(@dbh2driver.nil? or @dbh2driver.empty?)
      @dbh2driver.each_key { |dbh|
        begin
          dbh.disconnect() if(DBUtil::alive?(dbh))
        rescue # nothing to do if a disconnect fails
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "FAILED TO DISCONNECT a dbh (#{dbh.object_id})")
        end
      }
    end
    # Regardless, also try to disconnect the standard trio of fixed dbhs
    # - may have been disconnected in loop above if cached
    # - thus check via alive? first
    begin
      @genbDbh.disconnect() if(DBUtil::alive?(@genbDbh))
      @dataDbh.disconnect() if(DBUtil::alive?(@dataDbh))
      @otherDbh.disconnect() if(DBUtil::alive?(@otherDbh))
    rescue
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "FAILED TO DISCONNECT either genbDbh or dataDbh")
    end
    # Finally, safely try to clear the two caches themselves
    # - We won't set them to nil in case this DBUtil instannce is actually used again post clearCaches(). Leave them as Hashes.
    @dbh2driver.clear() if(@dbh2driver and @dbh2driver.respond_to?(:clear))
    @driver2dbh.clear() if(@driver2dbh and @driver2dbh.respond_to?(:clear))
    return
  end

  # Clear the current genboree user database (but don't disconnect it or remove from cache)
  def resetDataDb()
    @dataDbh = @dataDriver = @dataDbName = nil
    return
  end

  # Set a new current genboree user database (don't connect until forced to though)
  # - Note: if dataDb is a String, then assumed to be DB name; if dataDb is a Fixnum then assumed to be a refseqid
  def setNewDataDb(dataDb)
    resetDataDb()
    if(dataDb.kind_of?(Fixnum))
      # Get database name for refseqid
      databaseNameRows = self.selectDBNameByRefSeqID(dataDb)
      @dataDbName = databaseNameRows.first['databaseName']
    else
      @dataDbName = dataDb
    end
    return @dataDbName
  end

  # Clear the current main genboree and user databases (disconnect safely, without removing from cache unless supposed to)
  def clear(doClearCaches=false)
    closeDbh(@genbDbh)
    closeDbh(@dataDbh)
    closeDbh(@otherDbh)
    # clear current user database
    resetDataDb()
    # clear current main genboree database
    @genbDbh = @mainGenbDriver = @mainGenbDbName = nil
    # clear caches only if told to
    clearCaches() if(doClearCaches)
    return
  end

  def to_s()
    return   "BRL::Genboree::DBUtil -->\n[\n" +
            "  dbrcKey        = #{@dbrcKey}\n" +
            "  mainGenbDbName = #{@mainGenbDbName}\n" +
            "  dataDbName     = #{@dataDbName}\n" +
            "  mainGenbDriver = #{@mainGenbDriver}\n" +
            "  dataDriver     = #{@dataDriver}\n" +
            "  otherDbName    = #{@otherDbName}\n" +
            "  otherDbDriver  = #{@otherDbDriver}\n" +
            "  otherDbHost    = #{@otherDbHost}\n" +
            "  dbrcFile       = #{@dbrcFile}\n" +
            "]\n"
  end

  # --------------------------------------------------------------------------
  # Class/Module methods
  # --------------------------------------------------------------------------
  def self.sqlEscape(text, allowAltWildcards=true, returnQuoted=true)
    # First, escape the % and _ (for safety, we don't allow people to put % and _ in...no encouraging SQL injection)
    # NOTE: .gsub(/'/, "\\'") doesn't work!  must use .gsub(/'/, "\\\\'")
    text = text.gsub(/%/, "\\%").gsub(/_/, "\\_").gsub(/'/, "\\\\'")
    # Next switch * and ? to % and . if allowing that
    text = text.gsub(/\*/, "%").gsub(/\?/, "_") if(allowAltWildcards)
    # Finally, quote the query string so we can put it in queries directly and safely (no SQL injection)
    text = "'#{text}'" if(returnQuoted)
    return text
  end

  def self.logDbError(msg, err, sql=nil, *params)
    @err = err
    $stderr.puts "-"*50 + "\n#{Time.now}"
    $stderr.puts msg
    $stderr.puts "#{@err.class}: #{@err.message}"
    $stderr.puts @err.backtrace.join("\n") unless(@err.nil? or @err.backtrace.nil?)
    $stderr.puts "SQL issued: #{sql}"
    if(params and !params.empty?)
      $stderr.print "Other possibly useful variable values:\n    "
      params.each { |param|
        $stderr.puts "    - #{param.inspect}"
      }
    end
    $stderr.puts "-"*50 + "\n#{Time.now}"
    return
  end

  # Add additional SQL extras to end of sql to handle many (but not all) "special" cases involving
  # order by, group by, limits. The currently supported extra keys are:
  #
  #     :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #     :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #     :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #     :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  def applySqlExtraOpts(sql, extraOpts=nil)
    retVal = sql.dup
    # Apply extraOpts, if any. Order is important here.
    if(extraOpts.is_a?(Hash))
      # What column(s) to group by
      if(extraOpts[:groupBy])
        groupBy = extraOpts[:groupBy]
        groupBy = [ groupBy ] unless(groupBy.is_a?(Array))
        retVal << " group by #{groupBy.join(', ')} "
      end
      # What column(s) to order by
      if(extraOpts[:orderBy])
        orderBy = extraOpts[:orderBy]
        orderBy = [ orderBy ] unless(orderBy.is_a?(Array))
        retVal << " order by #{orderBy.join(', ')} "
      end
      # What column(s) to order by
      if(extraOpts[:descOrderBy].is_a?(Array))
        orderBy = extraOpts[:descOrderBy]
        orderBy = [ orderBy ] unless(orderBy.is_a?(Array))
        retVal << " order by #{orderBy.join(' DESC, ')} DESC "
      end
      # Simple limit for how many records to return, max.
      if(extraOpts[:simpleLimit].is_a?(Fixnum))
        retVal << " limit #{extraOpts[:simpleLimit]} "
      end
    end
    return retVal
  end

  # Method to build a SQL set using bind variables. E.g. (?, ?, ?)
  # NOTE Re:CACHE: Because class-level variables are shared across ALL threads, this method
  # had to be written VERY carefully, assuming that at ANY point a different thread could interrupt
  # and leave things in an inconsistent state. Therefore there is a bunch of testing to see if things
  # are really there and really populated with non-default values. These tests are fast.
  #
  # For use in "where column in (?, ?, ?)" type constructs for example.
  #
  # [+numItems+]  Number of bind variable slots in the set
  # [+returns+]   Partial SQL String of the form (?, ?, ?, ?)
  def self.makeSqlSetStr(numItems)
    retVal = nil
    raise ArgumentError, "ERROR: numItems arg cannot be < 1 in makeSqlSetStr()" if(numItems < 1)
    # Try to get from global class-level cache
    DBUtil.cacheLock.synchronize {
      # Get cache record using numItems as key
      if(DBUtil.cache)
        cacheToUse = DBUtil.cache[:sqlSetStrs]
        if(cacheToUse and !cacheToUse.empty?)
          retVal = cacheToUse[numItems]
        end
      else # no cache yet
        DBUtil.cache = Hash.new { |hh,kk| hh[kk] = Hash.new { |gg,jj| gg[jj] = nil } }
      end
      # If retVal still nil, must not be cached yet. Construct & cache the string.
      unless(retVal)
        # Build SQL set string
        sqlIO = StringIO.new()
        sqlIO << ' ( '
        numItems.times { |ii|
          sqlIO << '?,'
        }
        # Trim trailing comma
        sqlIO.truncate(sqlIO.length-1)
        sqlIO.pos -= 1
        sqlIO << ' ) '
        retVal = sqlIO.string
        # Cache result
        DBUtil.cache[:sqlSetStrs][numItems] = retVal
      end
    }
    return retVal
  end

  # Method to build a SQL set by escaping the values in items Array via Mysql2::Client.escape()
  # - Useful for constructing " where column in " clauses
  #
  # [+numItems+]  Array of Strings (values) to build the set string, via escaping
  # [+opts+] Hash of specific options if required - sha1 strings, etc
  # [+returns+]   Partial SQL String of the form ('{escItem1}', '{escItem2}', '{escItem3}, ...)
  def self.makeMysql2SetStr(items, opts={})
    retVal = nil
    items = [ items ] unless(items.is_a?(Array))
    raise ArgumentError, "ERROR: this method was incorrectly called; the items arg must be an Array and must have >= 1 item in makeMysql2SetStr(). Instead it was:\n    #{items.inspect}\n\n" unless(items.is_a?(Array) and items.size >= 1)
    # Build SQL set string
    lastIdx = (items.size - 1)
    sqlIO = StringIO.new()
    sqlIO << ' ( '
    items.each_index { |ii|
      if(opts.key?(:sha1Cols))
        sqlIO << "sha1('#{items[ii].to_s}')"
      else
        sqlIO << "'#{Mysql2::Client.escape(items[ii].to_s)}'"
      end
      sqlIO << ', ' unless(ii >= lastIdx)
    }
    sqlIO << ' ) '
    retVal = sqlIO.string
    return retVal
  end

  # Method to help build a partial SQL string for searching 1+ keywords.
  # It makes a where condition of the form "fieldName LIKE CONCAT('%', ?, '%') AND fieldName LIKE CONCAT('%', ?, '%')".
  # - With the optional prefixOnly flag, it will use LIKE CONCAT(?, '%') so you can look for prefixes (best anyway).
  # This would then be used by binding a keywords Array during statement execution (e.g. stmt.execute(*keywords))
  #
  # The boolean operation can also be OR. Used to match a field against keywords, ANY or ALL of which will be matched
  # depending on the booleanOp arg.
  #
  # NOTE: this is the safe way of doing keyword LIKE searches, rather than trying to quote the user's keywords.
  #
  # [+fieldName+]   Name of field to look for keyword in.
  # [+numKeywords+] The number of keywords to look for.
  # [+booleanOp+]   Either :and or :or, depending on whether ALL or ANY keywords must be matched
  # [+prefixOnly+]  [Default: false] Use LIKE CONCAT(?, '%') instead.
  # [+returns+]     Partial SQL String of the form "fieldName LIKE CONCAT('%', ?, '%') AND fieldName LIKE CONCAT('%', ?, '%')"
  def self.makeLikeSQL(fieldName, numKeywords, booleanOp, prefixOnly=false)
    retVal = nil
    raise ArgumentError, "ERROR: value for booleanOp arg ('#{booleanOp.inspect}') in makeMultiLikeSQL() is not either :and nor :or" unless(booleanOp == :and or booleanOp == :or)
    if(fieldName and numKeywords > 0)
      # Build multi-like string
      sqlIO = StringIO.new()
      numKeywords.times { |ii|
        if(prefixOnly)
          sqlIO << " #{fieldName} LIKE CONCAT(?, '%')"
        else
          sqlIO << " #{fieldName} LIKE CONCAT('%', ?, '%') "
        end
        if(ii < (numKeywords-1))
          if(booleanOp == :and)
            sqlIO << " AND "
          else # :or
            sqlIO << " OR "
          end
        end
      }
      retVal = sqlIO.string
    else
      retVal = nil
    end
    return retVal
  end

  # Method to help build a partial SQL string for searching 1+ keyword by escaping the keywords in items Array via Mysql2::Client.escape()
  # It makes a where condition of the form "fieldName LIKE '%{escKeyword1}%' AND fieldName LIKE '%{escKeyword2}%'".
  # - With the optional prefixOnly flag, it will use LIKE '{escKeyword1}%' so you can look for prefixes (best anyway).
  #
  # The boolean operation can also be OR. Used to match a field against keywords, ANY or ALL of which will be matched
  # depending on the booleanOp arg.
  #
  # NOTE: this is the safe way of doing keyword LIKE searches, rather than trying to quote the user's keywords.
  #
  # [+fieldName+]   Name of field to look for keyword in.
  # [+keywords+]    Array of keywords to search fieldName against.
  # [+booleanOp+]   Either :and or :or, depending on whether ALL or ANY keywords must be matched
  # [+prefixOnly+]  [Default: false] Use LIKE CONCAT('{escKeyword1}', '%') instead.
  # [+returns+]     Partial SQL String of the form "fieldName LIKE CONCAT('%', ?, '%') AND fieldName LIKE CONCAT('%', ?, '%')"
  def self.makeMysql2LikeSQL(fieldName, keywords, booleanOp, prefixOnly=false)
    retVal = nil
    raise ArgumentError, "ERROR: value for booleanOp arg ('#{booleanOp.inspect}') in makeMultiLikeSQL() is not either :and nor :or" unless(booleanOp == :and or booleanOp == :or)
    if(fieldName and keywords.is_a?(Array) and !keywords.empty?)
      # Build multi-like string
      lastIdx = (keywords.size - 1)
      sqlIO = StringIO.new()
      keywords.each_index { |ii|
        if(prefixOnly)
          sqlIO << " #{fieldName} LIKE '#{Mysql2::Client.escape(keywords[ii].to_s)}%'"
        else
          sqlIO << " #{fieldName} LIKE '%#{Mysql2::Client.escape(keywords[ii].to_s)}%'"
        end
        if(ii < lastIdx)
          if(booleanOp == :and)
            sqlIO << " AND "
          else # :or
            sqlIO << " OR "
          end
        end
      }
      retVal = sqlIO.string
    end
    return retVal
  end

  # Method to build an SQL CSV values list with bind variables.
  # e.g. (?, ?, ?), (?, ?, ?)
  # For use in building batch insert SQL
  # [+numValues+]           Number of value sets to build
  # [+numBindVarsPerValue+] Number of bind variable per value
  # [+reserveId+]           Assume first column is for auto-incrementing id and put a "null" there (e.g (null, ?, ?))
  # [+returns+]             Partial SQL String of the form (?, ?), (?, ?), (?,?)
  def self.makeSqlValuesStr(numValues, numBindVarsPerValue, reserveId=true)
    retVal = nil
    raise ArgumentError, "ERROR: neither numValues nor numBindVarsPerValue can be < 1 in makeSqlValuesStr()" if(numValues < 1 or numBindVarsPerValue < 1)
    # Construct key
    cacheKey = :"#{numValues}-#{numBindVarsPerValue}-#{reserveId}"
    # Try to get from global class-level cache
    DBUtil.cacheLock.synchronize {
      # Get cache record using method args as key
      if(DBUtil.cache)
        cacheToUse = DBUtil.cache[:sqlValueStrs]
        if(cacheToUse and !cacheToUse.empty?)
          retVal = cacheToUse[cacheKey]
        end
      else # no cache yet
        DBUtil.cache = Hash.new { |hh,kk| hh[kk] = Hash.new { |gg,jj| gg[jj] = nil } }
      end
      # If retVal still nil, must not be cached yet. Construct & cache the string.
      unless(retVal)
        # Build SQL values string
        sqlIO = StringIO.new()
        numValues.times { |ii|
          sqlIO << ' ( '
          sqlIO << ' null, ' if(reserveId)
          numBindVarsPerValue.times { |jj|
            sqlIO << '?,'
          }
          # Trim trailing comma
          sqlIO.truncate(sqlIO.length-1)
          sqlIO.pos -= 1
          sqlIO << ' ),'
        }
        # Trim trailing comma
        sqlIO.truncate(sqlIO.length-1)
        sqlIO.pos -= 1
        retVal = sqlIO.string
        # Cache result
        DBUtil.cache[:sqlValueStrs][cacheKey] = retVal
      end
    }
    return retVal
  end

  # Method to build an SQL CSV values list  by escaping the values in items Array via Mysql2::Client.escape()
  # e.g. ('{escItem1}', '{escItem2}', '{escItem3}'), ('{escItem4}', '{escItem5}', '{escItem6}')
  # For use in building batch insert SQL for example.
  #
  # [+items+]               Flat Array of values to prepare partial
  # [+numBindVarsPerValue+] Number of bind variable per value
  # [+reserveId+]           Assume first column is for auto-incrementing id and put a "null" there (e.g (null, ?, ?))
  # [+returns+]             Partial SQL String of the form ('{escItem1}', '{escItem2}'), ('{escItem3}', '{escItem4}'), ('{escItem5}', '{escItem6}')
  def self.makeMysql2ValuesStr(items, numBindVarsPerValue, reserveId=true, opts={})
    retVal = nil
    raise ArgumentError, "ERROR: neither numValues nor numBindVarsPerValue can be < 1 in makeSqlValuesStr()" if(items.nil? or items.empty? or numBindVarsPerValue < 1)
    raise ArgumentError, "ERROR: options for sha1Cols must be represented in an Array of column indices of interest, instead - #{opts[:shalCols].class} found." if(opts.key?(:sha1Cols) and !opts[:sha1Cols].is_a?(Array))
    # Compute these once, for use in iterative tests
    numValues = (items.size / numBindVarsPerValue)
    lastValIdx = (numValues - 1)
    lastFieldIdx = (numBindVarsPerValue - 1)
    # Build SQL values string
    sqlIO = StringIO.new()
    itemIdx = 0
    numValues.times { |ii|
      sqlIO << ' ( '
      sqlIO << ' null, ' if(reserveId)
      numBindVarsPerValue.times { |jj|
        value = items[itemIdx]
        if(opts.key?(:sha1Cols) and opts[:sha1Cols].include?(jj))
          sqlIO << "sha1('#{value.to_s}')" # unescaped sha1 of the col value
        else
          sqlIO << "'#{Mysql2::Client.escape(value.to_s)}'"
        end
        sqlIO << ', ' unless(jj >= lastFieldIdx)
        itemIdx += 1
      }
      sqlIO << ' )'
      sqlIO << ', ' unless(ii >= lastValIdx)
    }
    retVal = sqlIO.string
    return retVal
  end

  # Method to help build a partial SQL string for key-value pairs where the values will be '?' to be used by bindVars
  # Commonly used for SET or WHERE clauses.
  # example:      fieldNameArr = ['colX', 'colY']; seperatorSym = :and
  # would return: "colX = ? and colY = ?"
  #
  # [+fieldNameArr+]  Array of field names
  # [+seperatorSym+]  Symbol used to separate pairs (:and, :or, :comma)
  # [+returns+]       Partial SQL String
  def self.makeKeyValuePairsSql(fieldNamesArr, seperatorSym)
    sep = case seperatorSym
      when :and then ' and '
      when :or then ' or '
      when :comma then ', '
      else raise ArgumentError, "ERROR: value for seperatorSym arg ('#{seperatorSym.inspect}') in makeKeyValuePairsSql() is not either :and nor :or, :comma"
    end
    whereSql = fieldNamesArr.map { |fieldName| fieldName += " = ?" }.join(sep)
    return whereSql
  end

  # Method to help build a partial SQL string for key-value pairs by escaping the values in items Array via Mysql2::Client.escape()
  # Commonly used for SET or WHERE clauses.
  # example:      fieldNameArr = ['colX', 'colY']; seperatorSym = :and
  # would return: "colX = '{escVal1}' and colY = '{escVal2}'"
  #
  # [+fieldNames+]  Array of field names
  # [+items+]       Flat Array of values to test for each field. Must have same size as fieldNames
  # [+seperatorSym+]  Symbol used to separate pairs (:and, :or, :comma)
  # [+returns+]       Partial SQL String
  def self.makeMysql2KeyValuePairsSql(fieldNames, items, seperatorSym)
    raise ArgumentError, "ERROR: fieldNames Array and items Array must have same size" unless(fieldNames and items and (fieldNames.size == items.size))
    sep = case seperatorSym
      when :and then ' and '
      when :or then ' or '
      when :comma then ', '
      else raise ArgumentError, "ERROR: value for seperatorSym arg ('#{seperatorSym.inspect}') in makeKeyValuePairsSql() is not either :and nor :or, :comma"
    end
    lastIdx = (fieldNames.size - 1)
    sqlIO = StringIO.new()
    fieldNames.each_index { |ii|
      fieldName = fieldNames[ii]
      item = items[ii]
      sqlIO << "#{fieldName} = '#{Mysql2::Client.escape(item.to_s)}'"
      sqlIO << sep unless(ii >= lastIdx)
    }
    return sqlIO.string
  end

  # Convert an entity table name--plural by convention--into its singular name, for use
  # in constructing SQls, etc. Add new rules here.
  # [+entityTableName+] Name of the entity table, as its plural.
  # [+returns+]         Singular name of the table, as a +String+.
  def self.makeSingularTableName(entityTableName)
    singularName = nil
    if(entityTableName =~ /ies$/)
      singularName = entityTableName.gsub(/ies$/, 'y')
    elsif(entityTableName =~ /yses$/)
      singularName = entityTableName.gsub(/yses$/, 'ysis')
    elsif(entityTableName =~ /s$/)
      singularName = entityTableName.gsub(/s$/, '')
    else # assume entityTableName is singular already (against policy...maybe old?)
      singularName = entityTableName
    end
    return singularName
  end

  # Check if DBI handle is alive (a working connection)
  def DBUtil::alive?(dbh)
    retVal = false
    # Is it a handle at all?
    if(!dbh.nil? and dbh.kind_of?(DBI::DatabaseHandle))
      begin
        if(dbh.connected?) # It thinks it is alive
          if(dbh.ping)      # Does knows it is alive
            retVal = true
          end
        end
      rescue
        retVal = false      # Did it throw an exception during ping?
      end
    end
    return retVal
  end

  #--------------------------------------------------------------------------
  # HELPER SQL METHODS
  #--------------------------------------------------------------------------

  # Get last insert id, but only for DBI dbh objects, not Mysql2 clients
  def getLastInsertId(tableType)
    retVail = nil
    sql = "SELECT LAST_INSERT_ID() AS last"
    begin
      # First, try by calling mysql_insert_id() directly on the dbh, assuming we can get one
      dbh = nil
      case tableType
        when :mainDB
          dbh = @genbDbh
        when :userDB
          dbh = @dataDbh
        when :otherDB
          dbh = @otherDbh
        else
          raise ArgumentError, "ERROR: unknown tableType argument '#{tableType}'; should one of: :mainDB, :userDB, :otherDB"
      end
      # Did we get a non-nil dbh? Call mysql_insert_id() on it
      if(dbh)
        retVal = dbh.func(:insert_id)
      end
      # If dbh nil or retVal didn't get set by dbh.func or something, try SQL based approach.
      if(dbh.nil? or retVal.nil? or retVal < 0)
        dbh = connectToDB(databaseType)
        stmt = dbh.prepare(sql)
        stmt.execute()
        rows = stmt.fetch_all()
        retVal = rows.first['last'] unless(rows.nil? or rows.empty?)
      end
    rescue => @err
      errMsg = "Problem getting last insert id:"
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic count ALL records in table that works for tables in main Genboree
  # database, user database, or another database. You must have properly set
  # the right database handle.
  #
  # [+tableType+]   A flag indicating which database handle  to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to count in.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_countRecords = 'select count(*) from {tableName}'
  def countRecords(tableType, tableName, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_countRecords.gsub(/\{tableName\}/, tableName)
      resultSet = client.query(sql, :cast_booleans => true, :as => :array)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic count ALL unique/distinct values in a given field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to get the distinct values of.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_countDistinctValues = 'select count(distinct({fieldName})) as count from {tableName} '
  def countDistinctValues(tableType, tableName, fieldName, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_countDistinctValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Count ALL records in table by exact field match. This will work for tables in main Genboree
  # database, user database, or another database. You must have properly set
  # the right database handle.
  #
  # It will select all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then they will all be counted.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValue+]  Value of the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]     A row with a value for 'count' for the number of rows whose field matches the value,
  #                 or nil if query not executed (due to exception)
  SQL_PATTERN_countByFieldAndValue = 'select count(*) as count from {tableName} where {fieldName} = '
  def countByFieldAndValue(tableType, tableName, fieldName, fieldValue, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_countByFieldAndValue.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << "'#{Mysql2::Client.escape(fieldValue.to_s)}'"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic count records whose +fieldName+ matches one of the values in the +fieldValues+ list.
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will count all records which have one of the +fieldValues+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValues+] Array of possible values for the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_countByFieldWithMultipleValues = 'select count(*) as count from {tableName} where {fieldName} in '
  def countByFieldWithMultipleValues(tableType, tableName, fieldName, fieldValues, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_countByFieldWithMultipleValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << DBUtil.makeMysql2SetStr(fieldValues)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL records in table. This will work for tables in main Genboree
  # database, user database, or another database. You must have properly set
  # the right database handle.
  #
  # [+tableType+]   A flag indicating which database handle  to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [++]
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectAll = 'select * from {tableName} '
  ACCEPTED_RESOURCES_FOR_PARTIAL_ENTITIES = {"ftype" => true, "bioSamples" => true, "files" => true, "bioSampleSets" => true, "run" => true}
  def selectAll(tableType, tableName, errMsg, extraOpts=nil, includePartialEntities=false)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectAll.gsub(/\{tableName\}/, tableName)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      if(!includePartialEntities and ACCEPTED_RESOURCES_FOR_PARTIAL_ENTITIES.key?(tableName))
        idCol = ( tableName == 'ftype' ? "ftypeid" : "id" )
        avpPrefix = tableName.gsub(/s$/, '')
        sql << " where #{tableName}.#{idCol} NOT IN (select #{tableName}.#{idCol} from #{tableName}, #{avpPrefix}2attributes, #{avpPrefix}AttrNames,
        #{avpPrefix}AttrValues where #{avpPrefix}AttrNames.name = 'gbPartialEntity' and #{avpPrefix}AttrValues.value = true and
        #{tableName}.#{idCol} = #{avpPrefix}2attributes.#{avpPrefix}_id and #{avpPrefix}AttrNames.id = #{avpPrefix}2attributes.#{avpPrefix}AttrName_id and
        #{avpPrefix}AttrValues.id = #{avpPrefix}2attributes.#{avpPrefix}AttrValue_id) "
      end
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL records in table, but only selected columns and indicate if you want distinct rows or not.
  # This will work for tables in main Genboree database, user database, or another database.
  #
  # [+tableType+]     A flag indicating which database handle  to use for executing the query.
  #                   One of these +Symbols+:   :userDB, :mainDB, :otherDB
  # [+tableName+]     Name of the table to select from.
  # [+desiredFields+] Array of fields needed in the result set.
  # [+distinct+]      Return only unique rows (common). If false, does not apply the distinct() operation (rare).
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]       The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectAllFields = 'select {distinct} {desiredFields} from {tableName} '
  def selectAllFields(tableType, tableName, desiredFields, distinct, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      # Make sure desiredFields is an Array (e.g. maybe just 1 field and a String)
      desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
      # Make SQL list of fields
      desiredFieldsStr = desiredFields.join(',')
      # Set distinct appropriately
      distinctStr = (distinct ? 'distinct' : '')
      sql = SQL_PATTERN_selectAll.gsub(/\{tableName\}/, tableName)
      sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL unique/distinct values in a given field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to get the distinct values of.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectDistinctValues = 'select distinct({fieldName}) from {tableName} '
  def selectDistinctValues(tableType, tableName, fieldName, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectDistinctValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL records in table by exact field match. This will work for tables in main Genboree
  # database, user database, or another database. You must have properly set
  # the right database handle.
  #
  # It will select all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then you will get ALL of them back.
  # Make sure you know in your code whether multiple matches are possible and process all results
  # accordingly. Just because you think application logic means only be one should be returned is
  # not enough; if table allows more than one item to have that field name & value, you should check
  # that you received what your application logic expect. If you didn't error, warn, or deal appropriately.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValue+]  Value of the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByFieldAndValue = 'select * from {tableName} where {fieldName} = '
  def selectByFieldAndValue(tableType, tableName, fieldName, fieldValue, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectByFieldAndValue.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << "'#{Mysql2::Client.escape(fieldValue.to_s)}'"
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select records with just the desired fields using a +fieldName+ which matches one of the values in the +fieldValues+ list.
  # This will work or tables in main Genboree database, user database, or another database.
  # You must have properly set the right database handle.
  #
  # It will select records with just the desired fields which have one of the +fieldValues+ for their +fieldName+ field.
  # Can get distinct result rows or non-distinct result set.
  #
  # [+tableType+]     A flag indicating which database handle to use for executing the query.
  #                   One of these +Symbols+:
  #                   :userDB, :mainDB, :otherDB
  # [+tableName+]     Name of the table to select from.
  # [+desiredFields+] Array of fields needed in the result set.
  # [+distinct+]      Return only unique rows (common). If false, does not apply the distinct() operation (rare).
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValues+]   Array of possible values for the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]       The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectFieldsByFieldAndValue = "select {distinct} {desiredFields} from {tableName} where {fieldName} = '{fieldValue}'"
  def selectFieldsByFieldAndValue(tableType, tableName, desiredFields, distinct, fieldName, fieldValue, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      # Make sure desiredFields is an Array (e.g. maybe just 1 field and a String)
      desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
      # Make SQL list of fields
      desiredFieldsStr = desiredFields.join(',')
      # Set distinct appropriately
      distinctStr = (distinct ? 'distinct' : '')
      sql = SQL_PATTERN_selectFieldsByFieldAndValue.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
      sql = sql.gsub('{fieldValue}', mysql2gsubSafeEsc(fieldValue.to_s))
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select records whose +fieldName+ matches one of the values in the +fieldValues+ list.
  # This will work for tables in main Genboree database, user database, or another database.
  # You must have properly set the right database handle.
  #
  # It will select all records which have one of the +fieldValues+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValues+] Array of possible values for the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByFieldWithMultipleValues = 'select * from {tableName} where {fieldName} in '
  def selectByFieldWithMultipleValues(tableType, tableName, fieldName, fieldValues, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectByFieldWithMultipleValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << DBUtil.makeMysql2SetStr(fieldValues)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select records whose +fieldName+ matches (case sensitive) one of the values in the +fieldValues+ list.
  # This will work for tables in main Genboree database, user database, or another database.
  # You must have properly set the right database handle.
  #
  # It will select all records which have one of the +fieldValues+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValues+] Array of possible values for the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByFieldWithMultipleCaseSensitiveValues = 'select * from {tableName} where binary {fieldName} in '
  def selectByFieldWithMultipleCaseSensitiveValues(tableType, tableName, fieldName, fieldValues, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectByFieldWithMultipleCaseSensitiveValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << DBUtil.makeMysql2SetStr(fieldValues)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
    ensure
      client.close rescue nil
    end
    return retVal
  end


  # Generic select records with just the desired fields using a +fieldName+ which matches one of the values in the +fieldValues+ list.
  # This will work or tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will select records with just the desired fields which have one of the +fieldValues+ for their +fieldName+ field.
  # Can get distinct result rows or non-distinct result set.
  #
  # [+tableType+]     A flag indicating which database handle to use for executing the query.
  #                   One of these +Symbols+:
  #                   :userDB, :mainDB, :otherDB
  # [+tableName+]     Name of the table to select from.
  # [+desiredFields+] Array of fields needed in the result set.
  # [+distinct+]      Return only unique rows (common). If false, does not apply the distinct() operation (rare).
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValues+]   Array of possible values for the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]       The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectFieldsByFieldWithMultipleValues = 'select {distinct} {desiredFields} from {tableName} where {fieldName} in '
  def selectFieldsByFieldWithMultipleValues(tableType, tableName, desiredFields, distinct, fieldName, fieldValues, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      # Make sure desiredFields is an Array (e.g. maybe just 1 field and a String)
      desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
      # Make SQL list of fields
      desiredFieldsStr = desiredFields.join(',')
      # Set distinct appropriately
      distinctStr = (distinct ? 'distinct' : '')
      sql = SQL_PATTERN_selectFieldsByFieldWithMultipleValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
      sql << DBUtil.makeMysql2SetStr(fieldValues)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select records whose select conditions are defined in a Hash +selectCond+
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will select all records which have the values specified in +selectCond+ separated by +booleanOp+
  # for example:    +selectCond+ = {'col1'=>'x', 'col2'=>'y'};  +booleanOp+ = :and
  # would create:   'select * from table where col1 = x and col2 = y;
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+selectCond+]  Hash containing the fields that will be used in SQL where clause, must have the format: 'fieldName' => 'fieldValue'
  # [+booleanOp+]   Boolean operator used to combine conditions (:and or :or)
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByMultipleFieldsAndValues = 'select * from {tableName} where '
  def selectByMultipleFieldsAndValues(tableType, tableName, selectCond, booleanOp, errMsg, extraOpts=nil)
    retVal = sql = nil
    fieldNames = selectCond.keys
    fieldValues = selectCond.values
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectByMultipleFieldsAndValues.gsub(/\{tableName\}/, tableName)
      sql << DBUtil.makeMysql2KeyValuePairsSql(fieldNames, fieldValues, booleanOp)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select records whose select conditions are defined in a Hash +selectCond+
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will select all records which have the values specified in +selectCond+ separated by +booleanOp+
  # for example:    +selectCond+ = {'col1'=>'x', 'col2'=>'y'};  +booleanOp+ = :and
  # would create:   'select * from table where col1 = x and col2 = y;
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+desiredFields+] Array of fields needed in the result set.
  # [+distinct+]      Return only unique rows (common). If false, does not apply the distinct() operation (rare).
  # [+selectCond+]  Hash containing the fields that will be used in SQL where clause, must have the format: 'fieldName' => 'fieldValue'
  # [+booleanOp+]   Boolean operator used to combine conditions (:and or :or)
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectFieldsByMultipleFieldsAndValues = 'select {distinct} {desiredFields} from {tableName} where '
  def selectFieldsByMultipleFieldsAndValues(tableType, tableName, desiredFields, distinct, selectCond, booleanOp, errMsg, extraOpts=nil)
    retVal = sql = nil
    fieldNames = selectCond.keys
    fieldValues = selectCond.values
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectFieldsByMultipleFieldsAndValues.gsub(/\{tableName\}/, tableName)
      # Make sure desiredFields is an Array (e.g. maybe just 1 field and a String)
      desiredFields = [ desiredFields ] unless(desiredFields.is_a?(Array))
      # Make SQL list of fields
      desiredFieldsStr = desiredFields.join(',')
      # Set distinct appropriately
      distinctStr = (distinct ? 'distinct' : '')
      sql = sql.gsub('{distinct}', distinctStr).gsub('{desiredFields}', desiredFieldsStr)
      sql << DBUtil.makeMysql2KeyValuePairsSql(fieldNames, fieldValues, booleanOp)
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL records in table by keyword match in the indicated field. This will work for tables
  # in main genboree, database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will select all records which have +keyword+ in their their +fieldName+ field.
  #
  # NOTE: this is SLOW because it can't make use of any index; it uses an SQL 'like' condition against "%keyword%".
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+keyword+]     The keyword to match within the field.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  def selectByFieldAndKeyword(tableType, tableName, fieldName, keyword, errMsg, extraOpts=nil)
    retVal = nil
    keywords = [ keyword ]
    return selectByFieldWithMultipleKeywords(tableType, tableName, fieldName, keywords, :and, errMsg, extraOpts=nil)
  end

  # Generic select records whose +fieldName+ matches either ALL or ANY of the keywords in the +keywords+ list.
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly setthe right database handle.
  #
  # NOTE: this is SLOW because it can't make use of any index; it uses multiple SQL 'like' conditions against "%keyword1%".
  #
  # It will select all records which have one of the +fieldValues+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+keywords+]    Array of keywords to look for in the field
  # [+booleanOp+]   Either :and or :or, indicating that ALL or ANY of the keywords must match
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+extraOpts+]     [Default: nil] Add any additional stuff like group by, order by, limitm, etc. to end of SQL to handle many (but not all)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByFieldWithMultipleKeywords = 'select * from {tableName} where '
  def selectByFieldWithMultipleKeywords(tableType, tableName, fieldName, keywords, booleanOp, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      likeSql = DBUtil.makeMysql2LikeSQL(fieldName, keywords, booleanOp)
      sql = SQL_PATTERN_selectByFieldWithMultipleKeywords.gsub(/\{tableName\}/, tableName)
      sql += likeSql
      # Apply extraOpts, if any.
      sql = applySqlExtraOpts(sql, extraOpts) if(extraOpts)
      # Query
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic select ALL records in table by prefix match in the indicated field. This will work for tables
  # in main genboree, database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will select all records which have +prefix+ at the start of their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+prefix+]      The prefix to match at the start of the field.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  def selectByFieldAndPrefix(tableType, tableName, fieldName, prefix, errMsg, extraOpts=nil)
    retVal = nil
    prefixes = [ prefix ]
    return selectByFieldWithMultiplePrefixes(tableType, tableName, fieldName, prefixes, :and, errMsg)
  end

  # Generic select records whose +fieldName+ matches either ALL or ANY of the prefixes in the +prefixes+ list.
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will select all records which begin with one of the the +prefixes+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+fieldName+]   Name of the field to look in.
  # [+prefixes+]    Array of keywords to look for in the field
  # [+booleanOp+]   Either :and or :or, indicating that ALL or ANY of the keywords must match
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  #                   "special" cases. This is a Hash with certain keys supported:
  #                       :groupBy      => Array of 1+ columns to use for grouping records (usually just 1 column)
  #                       :orderBy      => Array of 1+ columns to use for sorting the records in ASCENDING order
  #                       :descOrderBy  => Array of 1+ columns to use for sorting the records in DESCENDING order
  #                       :simpleLimit  => Fixnum indicating the maximum number of records to return (via an SQL limit X)
  # [+returns+]     The results of the query or nil if query not executed (due to exception)
  SQL_PATTERN_selectByFieldWithMultipleKeywords = 'select * from {tableName} where '
  def selectByFieldWithMultiplePrefixes(tableType, tableName, fieldName, prefixes, booleanOp, errMsg, extraOpts=nil)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      likeSql = DBUtil.makeMysql2LikeSQL(fieldName, keywords, booleanOp, true)  # <= prefixOnly = true in this call
      sql = SQL_PATTERN_selectByFieldWithMultipleKeywords.gsub(/\{tableName\}/, tableName)
      sql += likeSql
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SQL_PATTERN_eachBlockOfCols = 'select {columns} from {tableName} '
  def eachBlockOfCols(tableType, tableName, columns='*', order=nil, blockSize=10_000, &block)
    retVal = nil
    currRowOffset = 0
    begin
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_eachBlockOfCols.gsub(/\{columns\}/, columns)
      sql.gsub!(/\{tableName\}/, tableName)
      sql += " limit ?, #{blockSize} "
      stmt = dbh.prepare(sql)
      loop {
        stmt.execute(currRowOffset)
        retVal = []
        retVal = stmt.fetch_all_hash
        break if(retVal.empty?)
        yield(retVal)
        currRowOffset += blockSize
        break if(retVal.size < blockSize)
      }
    rescue => @err
      DBUtil.logDbError("ERROR: #{self.class}##{__method__}():", @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return
  end

  # Select records by doing a fulltext search on the indicated column using the supplied MySQL Fulltext search string
  # to match the column against. i.e., via a "WHERE MATCH(column) AGAINST('searchStr' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  SQL_PATTERN_selectByFulltext = "select * from {tableName} where match({colName}) against('{searchStr}' {mode})"
  def selectByFulltext(tableType, tableName, column, fulltextSearchString, mode=:boolean, errMsg=nil)
    retVal = sql = nil
    begin
      fulltextSearchString = fulltextSearchString.gsub(/'/, "\\'")
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectByFulltext.gsub(/\{tableName\}/, tableName).gsub(/\{colName\}/, column).gsub(/\{searchStr\}/, fulltextSearchString)
      if(mode == :boolean)
        sql = sql.gsub(/\{mode\}/, 'in boolean mode')
      else
        raise ArgumentError, "ERROR: unacceptable value for mode arg ('#{mode.inspect}') in #{__method__}(). Currently can only be :boolean."
      end
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select records using supplied Array of strings to build an "exact phrase" keyword string for
  # matching the input column against (using the "" fulltext operator.
  # i.e. via a "WHERE MATCH(input) AGAINST('"word1 word2 ... wordN"' IN BOOLEAN MODE)"
  # - Currently only :boolean is supported for the mode parameter. This may be enhanced in the future
  # - If you need more custom fulltext search strings, such as combinations of one-or-more + operands and one-or-more ""
  #   operands, you should use selectByFulltext()
  # [+keywords]  Array of Strings which are the keywords to use within the "" operator
  def selectByFulltextKeywords(tableType, tableName, column, keywords, mode=:boolean, errMsg=nil)
    fulltextSearchString = keywords.join(' ')
    fulltextSearchString.gsub!(/'/, "\\'")
    return selectByFulltext(:otherDB, tableName, column, fulltextSearchString, mode, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the distinct names for an entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectDistinctEntityNames = "select distinct({entityTableName}.name) as entityName from "
  def selectDistinctEntityNames(tableType, entityTableName, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_selectDistinctEntityNames.dup
      sql = sql.gsub(/\{entityTableName\}/, entityTableName)
      sql << "#{entityTableName}"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute-value information using AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectEntityAttributeMap =  "
                                            select {entityTableName}.{entityNameCol} as entityName,
                                            {singularName}AttrNames.name as attributeName, {singularName}AttrValues.value as attributeValue
                                            from {singularName}2attributes
                                            join {entityTableName} on ({singularName}2attributes.{singularName}_id = {entityTableName}.{entityIdCol})
                                            join {singularName}AttrNames on
                                            ({singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id)
                                            join {singularName}AttrValues on
                                            ({singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id)
                                          "
  def selectEntityAttributesInfo(tableType, entityTableName, errMsg, attributeList=nil, entityNameCol='name', entityIdCol='id')
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Normalize the list to arrays, in case given just String
      attributeList = [ attributeList ] if(attributeList.is_a?(String))
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Do we have an exception for the entity table itself that needs to be fixed due to bad table naming policy?
      entityTableName = SPECIAL_TABLE_NAME_MAP[singularName] if(SPECIAL_TABLE_NAME_MAP.key?(singularName))
      # Make sql
      sql = SQL_PATTERN_selectEntityAttributeMap.dup
      # Optionally add in attribute list to restrict result set
      if(attributeList)
        sql << " and {singularName}AttrNames.name in "
        sql << DBUtil.makeMysql2SetStr(attributeList)
      end
      sql = sql.gsub(/\{entityNameCol\}/, entityNameCol).gsub(/\{entityIdCol\}/, entityIdCol)
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute-value information using AVP tables associated with the CORE entity table
  def selectCoreEntityAttributesInfo(entityTableName, entityNameList, attributeList=nil, errMsg=nil, entityNameCol='name', entityIdCol = 'id')
    errMsg = "Error in #{File.basename(__FILE__)}##{__method__}: Could not query main database for #{entityTableName.inspect} attribute map." unless(errMsg)
    # Because the core columns are so poorly names and inconsistent, this will
    # call some specific methods for certain tables (older ones), but fail over
    # to the usual approach to handle newer core tables (like projects).
    retVal = singularName = nil
    begin
      client = getMysql2Client(:mainDB)
      # Normalize the lists to arrays, in case given just Strings
      entityNameList = [ entityNameList ] if(entityNameList.is_a?(String))
      attributeList = [ attributeList ] if(attributeList.is_a?(String))
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Do we have an exception for the entity table itself that needs to be fixed due to bad table naming policy?
      entityTableName = SPECIAL_TABLE_NAME_MAP[singularName] if(SPECIAL_TABLE_NAME_MAP.key?(singularName))
      # Make sql
      sql = SQL_PATTERN_selectEntityAttributeMap.dup
      sql << " and #{entityTableName}.#{entityNameCol} in "
      sql << DBUtil.makeMysql2SetStr(entityNameList)
      # Optionally add in attribute list to restrict result set
      if(attributeList)
        sql << " and {singularName}AttrNames.name in "
        sql << DBUtil.makeMysql2SetStr(attributeList)
      end
      sql = sql.gsub(/\{entityNameCol\}/, entityNameCol).gsub(/\{entityIdCol\}/, entityIdCol)
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute (no values) information using AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (e.g., name of method calling this one, etc.)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectEntityAttributeNameMap =  "
                                            select {entityTableName}.name as entityName,
                                            {singularName}AttrNames.name as attributeName
                                            from {singularName}2attributes
                                            join {entityTableName} on ({singularName}2attributes.{singularName}_id = {entityTableName}.id)
                                            join {singularName}AttrNames on
                                            ({singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id)
                                          "
  def selectEntityAttributesNameMapInfo(tableType, entityTableName, errMsg, attributeList=nil)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntityAttributeNameMap.dup
      # Optionally add in attribute list to restrict result set
      if(attributeList)
        sql << " and {singularName}AttrNames.name in "
        sql << DBUtil.makeMysql2SetStr(attributeList)
      end
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute values (only values) information using AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectEntityAttributeValueMap =  "
                                            select {entityTableName}.name as entityName,
                                            {singularName}AttrValues.value as attributeValue
                                            from {singularName}2attributes
                                            join {entityTableName} on ({singularName}2attributes.{singularName}_id = {entityTableName}.id)
                                            join {singularName}AttrValues on
                                            ({singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id)
                                          "
  def selectEntityAttributesValueMapInfo(tableType, entityTableName, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntityAttributeValueMap.dup
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute information using 'only' the attribute names tables associated with the entity table
  # to do the query.
  # Some tool require only the attribute names. In such cases, its a waste of time getting the entire AVP map
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectEntityAttribute =  "
                                            select distinct({singularName}AttrNames.name)
                                             as attributeName
                                            from {singularName}2attributes
                                            join {entityTableName} on ({singularName}2attributes.{singularName}_id = {entityTableName}.id)
                                            join {singularName}AttrNames on
                                            ({singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id)
                                          "
  def selectEntityAttributes(tableType, entityTableName, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntityAttribute.dup
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the entity-attribute value information using 'only' the values associated with the entity table
  # to do the query.
  # Some tools may require only the attribute values. In such cases, its a waste of time getting the entire AVP map
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records with these columns (and col names):
  #                       entityName, attributeName, attributeValue
  SQL_PATTERN_selectEntityAttributeValues =  "
                                            select distinct({singularName}AttrValues.value)
                                             as attributeValue
                                            from {singularName}2attributes
                                            join {entityTableName} on ({singularName}2attributes.{singularName}_id = {entityTableName}.id)
                                            join {singularName}AttrValues on
                                            ({singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id)
                                          "
  def selectEntityAttributeValues(tableType, entityTableName, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntityAttributeValues.dup
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: #{__FILE__}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select rows from an entity table using an attribute-value pair.
  # This method will use the standard AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameId+]      ID for the attribute name to consider
  # [+attrValueId+]     ID for the attribute value to match
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records
  SQL_PATTERN_selectEntitiesByAttributeNameAndValueIds =
      "select {entityTableName}.* " +
      "from {entityTableName}, {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectEntitiesByAttributeNameAndValueIds(tableType, entityTableName, attrNameId, attrValueId, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntitiesByAttributeNameAndValueIds.dup()
      sql << " where {singularName}AttrNames.id = '#{Mysql2::Client.escape(attrNameId.to_s)}' and {singularName}AttrValues.id = '#{Mysql2::Client.escape(attrValueId.to_s)}' "
      sql << " and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id  and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id and {entityTableName}.id = {singularName}2attributes.{singularName}_id "
      sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectEntitiesByAttributeNameAndValueIds():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select rows from an entity table using an attribute-value pair.
  # This method will use the standard AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameText+]    The attribute name to consider
  # [+attrValueText+]   The attribute value to match (sha1 will be computed for you, and that digest used in query)
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records
  SQL_PATTERN_selectEntitiesByAttributeNameAndValueTexts =
      "select {entityTableName}.* " +
      "from {entityTableName}, {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectEntitiesByAttributeNameAndValueTexts(tableType, entityTableName, attrNameText, attrValueText, errMsg)
    retVal = []
    singularName = nil
    unless(attrValueText.nil? or attrNameText.nil?)  # Those should be two Strings or some kind of real value...if nil (e.g. nil value), we will not be able to look up anything so result set will be [].
      begin
        client = getMysql2Client(tableType)
        # Make singular name
        singularName = DBUtil.makeSingularTableName(entityTableName)
        # Digest of value text
        valueDigest = SHA1.hexdigest(attrValueText.to_s)
        # Make sql
        sql = SQL_PATTERN_selectEntitiesByAttributeNameAndValueTexts.dup()
        sql << " where {singularName}AttrNames.name = '#{Mysql2::Client.escape(attrNameText.to_s)}' and {singularName}AttrValues.sha1 = '#{valueDigest}' "
        sql <<  " and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id  and {entityTableName}.id = {singularName}2attributes.{singularName}_id"
        sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: DBUtil.selectEntitiesByAttributeNameAndValueTexts():", @err, sql)
        raise
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Select rows from an entity table using an attribute-value pair.
  # This method will use the standard AVP tables associated with the entity table
  # to do the query.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameText+]    The attribute name to consider
  # [+attrValueText+]   The attribute value to match (sha1 will be computed for you, and that digest used in query)
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ entity table records
  def selectCoreEntitiesByAttributeNameAndValueTexts(tableType, entityTableName, attrNameText, attrValueText, errMsg)
    retVal = []
    singularName = nil
    unless(attrValueText.nil? or attrNameText.nil?)  # Those should be two Strings or some kind of real value...if nil (e.g. nil value), we will not be able to look up anything so result set will be [].
      begin
        client = getMysql2Client(tableType)
        # Make singular name
        singularName = DBUtil.makeSingularTableName(entityTableName)
        # Do we have an exception for the entity table itself that needs to be fixed due to bad table naming policy?
        entityTableName = SPECIAL_TABLE_NAME_MAP[singularName] if(SPECIAL_TABLE_NAME_MAP.key?(singularName))
        # Digest of value text
        valueDigest = SHA1.hexdigest(attrValueText.to_s)
        # Make sql
        sql = SQL_PATTERN_selectEntitiesByAttributeNameAndValueTexts.dup()
        sql << " where {singularName}AttrNames.name = '#{Mysql2::Client.escape(attrNameText.to_s)}' and {singularName}AttrValues.sha1 = '#{valueDigest}' "
        sql <<  " and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id  and {entityTableName}.id = {singularName}2attributes.{singularName}_id"
        sql = sql.gsub(/\{entityTableName\}/, entityTableName).gsub(/\{singularName\}/, singularName)
        resultSet = client.query(sql, :cast_booleans => true)
        retVal = resultSet.entries
      rescue => @err
        DBUtil.logDbError("ERROR: DBUtil.selectEntitiesByAttributeNameAndValueTexts():", @err, sql)
        raise
      ensure
        client.close rescue nil
      end
    end
    return retVal
  end

  # Select the value record for a particular attribute of an entity, using the attribute id.
  # "what's the value of the ___ attribute for this entity?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+entityId+]        The id of the entity.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  SQL_PATTERN_selectValueByEntityAndAttributeNameId =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrValues, {singularName}2attributes "
  def selectValueByEntityAndAttributeNameId(tableType, entityTableName, entityId, attrNameId, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectValueByEntityAndAttributeNameId.dup()
      sql << " where {singularName}2attributes.{singularName}_id = '#{Mysql2::Client.escape(entityId.to_s)}' and {singularName}2attributes.{singularName}AttrName_id = '#{Mysql2::Client.escape(attrNameId.to_s)} ' "
      sql << " and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValueByEntityAndAttributeNameId():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select the value record for a particular attribute of an entity, using the attribute name (text).
  # "what's the value of the ___ attribute for this entity?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+entityId+]        The id of the entity.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  SQL_PATTERN_selectValueByEntityAndAttributeNameText =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectValueByEntityAndAttributeNameText(tableType, entityTableName, entityId, attrNameText, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectValueByEntityAndAttributeNameText.dup()
      sql <<  "where {singularName}2attributes.{singularName}_id = '#{Mysql2::Client.escape(entityId.to_s)}' and {singularName}AttrNames.name = '#{Mysql2::Client.escape(attrNameText.to_s)}' "
      sql <<  " and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValueByEntityAndAttributeNameText():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the value records associated with a particular attribute (i.e. across all entities), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameId+]      The id of the attribute we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ attribute value record
  SQL_PATTERN_selectValuesByAttributeNameId =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrValues, {singularName}2attributes "
  def selectValuesByAttributeNameId(tableType, entityTableName, attrNameId, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectValuesByAttributeNameId.dup()
      sql << " where {singularName}2attributes.{singularName}AttrName_id = '#{Mysql2::Client.escape(attrNameId.to_s)}' "
      sql << "and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributeNameId():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the value records associated with a particular attribute (i.e. across all entities), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameText+]      The id of the attribute we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ attribute value record
  SQL_PATTERN_selectValuesByAttributeNameText =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectValuesByAttributeNameText(tableType, entityTableName, attrNameText, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectValuesByAttributeNameText.dup()
      sql << " where {singularName}AttrNames.name = '#{Mysql2::Client.escape(attrNameText.to_s)}' "
      sql <<  " and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributeNameText():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all entities), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ attribute value record
  SQL_PATTERN_selectValuesByAttributeNameIds =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrValues, {singularName}2attributes " +
      "where {singularName}2attributes.{singularName}AttrName_id in {setSql} " +
      "and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
  def selectValuesByAttributeNameIds(tableType, entityTableName, attrNameIds, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Get partial sql for a set
      setSql = DBUtil.makeMysql2SetStr(attrNameIds)
      # Make sql
      sql = SQL_PATTERN_selectValuesByAttributeNameIds.gsub(/\{singularName\}/, singularName)
      sql.gsub!(/\{setSql\}/, setSql)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributeNameIds():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all entities), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ attribute value record
  SQL_PATTERN_selectValuesByAttributeNameTexts =
      "select {singularName}AttrValues.* " +
      "from {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes " +
      "where {singularName}AttrNames.name in {setSql} " +
      "and {singularName}2attributes.{singularName}AttrName_id = {singularName}AttrNames.id " +
      "and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
  def selectValuesByAttributeNameTexts(tableType, entityTableName, attrNameTexts, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Get partial sql for a set
      setSql = DBUtil.makeMysql2SetStr(attrNameTexts)
      # Make sql
      sql = SQL_PATTERN_selectValuesByAttributeNameTexts.gsub(/\{singularName\}/, singularName)
      sql.gsub!(/\{setSql\}/, setSql)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributeNameTexts():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SQL_PATTERN_selectEntity2AttributesByAttrNameIdAndAttrValueId = 'select * from {singularName}2attributes where {singularName}AttrName_id = {nameId} and {singularName}AttrValue_id = {valueId}'
  def selectEntity2AttributesByAttrNameIdAndAttrValueId(tableType, entityTableName, attrNameId, attrValueId)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectEntity2AttributesByAttrNameIdAndAttrValueId.gsub(/\{singularName\}/, singularName)
      sql = sql.gsub(/\{nameId\}/, attrNameId.to_i.to_s).gsub(/\{valueId\}/, attrValueId.to_i.to_s)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributeNameTexts():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  SQL_PATTERN_deleteEntity2AttributesByEntityIdAndAttrNameId = 'delete from {singularName}2attributes where {singularName}_id = {entityId}'
  def deleteEntity2AttributesByEntityIdAndAttrNameId(tableType, entityTableName, entityId, attrNameId=nil, attrValueId=nil)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_deleteEntity2AttributesByEntityIdAndAttrNameId
      sql += " and {singularName}AttrName_id = #{attrNameId.to_i}" unless(attrNameId.nil?)
      sql += " and {singularName}AttrValue_id = #{attrValueId.to_i}" unless(attrValueId.nil?)
      sql = sql.gsub(/\{singularName\}/, singularName)
      sql = sql.gsub(/\{entityId\}/, entityId.to_i.to_s)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select an attribute->value "map" for the given attributes of particular enity, using attribute ids
  # "what are the current values associated with these attributes for this entity, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+attrName_id+]     Id of the attribute.
  # [+attrName_text+]   Name of the attribute.
  # [+attrValue_id+]    Id of the attribute value associated with the attribute, for this entity.
  # [+attrValue_text+]  Value of the attribute value associated with the attribute, for this entity.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+entityId+]        The id of the entity to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  SQL_PATTERN_selectAttributeValueMapByEntityAndAttributeIds =
      "select {singularName}AttrNames.id as attrName_id, {singularName}AttrNames.name as attrName_name, " +
      "{singularName}AttrValues.id as attrValue_id, {singularName}AttrValues.value as attrValue_value " +
      "from {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectAttributeValueMapByEntityAndAttributeIds(tableType, entityTableName, entityId, attrNameIds, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectAttributeValueMapByEntityAndAttributeIds.dup()
      sql << " where {singularName}2attributes.{singularName}_id = '#{Mysql2::Client.escape(entityId.to_s)}' and {singularName}2attributes.{singularName}AttrName_id in "
      sql << DBUtil.makeMysql2SetStr(attrNameIds)
      sql <<  " and {singularName}AttrNames.id = {singularName}2attributes.{singularName}AttrName_id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectValuesByAttributesNameIds():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Select an attribute->value "map" for the given attributes of particular enity, using attribute names
  # "what are the current values associated with these attributes for this entity, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # Table conventions must be followed for this to be valid;
  # entity table name must be plural, singular entity name must be deducible
  # by normal rules of English.
  #
  # DO NOT use on entities that have no AVP tables or that do not follow the table naming convention.
  # DO NOT use where entity table and/or their attrValue table is massive; this method uses the
  # obvious SQL join which should be avoided for such massive tables.
  #
  # [+tableType+]       A flag indicating which database handle to use for executing the query.
  #                     One of these +Symbols+:
  #                     :userDB, :mainDB, :otherDB
  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  # [+entityId+]        The id of the entity to get attribute->value map info for
  # [+attrNameTexts+]    Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  SQL_PATTERN_selectAttributeValueMapByEntityAndAttributeTexts =
      "select {singularName}AttrNames.id as {singularName}AttrName_id, {singularName}AttrNames.name as {singularName}AttrName_name, " +
      "{singularName}AttrValues.id as {singularName}AttrValue_id, {singularName}AttrValues.value as {singularName}AttrValue_value " +
      "from {singularName}AttrNames, {singularName}AttrValues, {singularName}2attributes "
  def selectAttributeValueMapByEntityAndAttributeTexts(tableType, entityTableName, entityId, attrNameTexts, errMsg)
    retVal = singularName = nil
    begin
      client = getMysql2Client(tableType)
      # Make singular name
      singularName = DBUtil.makeSingularTableName(entityTableName)
      # Make sql
      sql = SQL_PATTERN_selectAttributeValueMapByEntityAndAttributeTexts.dup()
      sql << "where {singularName}2attributes.{singularName}_id = '#{Mysql2::Client.escape(entityId.to_s)}' and {singularName}AttrNames.name in "
      sql << DBUtil.makeMysql2SetStr(attrNameTexts)
      sql << " and {singularName}AttrNames.id = {singularName}2attributes.{singularName}AttrName_id and {singularName}2attributes.{singularName}AttrValue_id = {singularName}AttrValues.id "
      sql.gsub!(/\{singularName\}/, singularName)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = resultSet.entries
    rescue => @err
      DBUtil.logDbError("ERROR: DBUtil.selectAttributeValueMapByEntityAndAttributeTexts():", @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Insert 1+ records into a table using an "insert values" type SQL statement.
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # To build the right SQL insert statement, you need to provide the record count and the
  # number of bind variables per record.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+data+]        Array of all data values used to construct the records; do not provide
  #                 "null" for autoincrement id column if you have reserveId=true set...this
  #                 method will add them. NOTE: this array can be flat (1-D)
  #                 or an array of arrays (2-D, mimicing the rows and column); regardless,
  #                 this method will flatten() it before using it.
  #                 DANGER: THIS ARRAY WILL BE MODIFIED TO MAKE IT SQL-HAPPY!
  # [+reserveId+]   Should the method reserve the first column in each record for an autoincrement
  #                 id? Most often true.
  # [+numValues+]   The number of records to insert
  # [+numBindVarsPerRecord+]  The number of dynamic bind slots per record.
  # [+ignoreDuplicates+]  Normally inserting a record with same primary/unique key as existing reocrd
  #                       is an error...this will skip the insertion of such records. Generally false.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+dupKeyUpdateCol+] specifies the column name if using duplicate key update inserts
  # [+flatten+]     Can override to false if SURE already flattened (faster than uselessly trying to flatten already flat array)
  # [+returns+]     Number of records inserted (useful to check when ignoreDuplicates=true)
  def insertRecords(tableType, tableName, data, reserveId, numValues, numBindVarsPerValue, ignoreDuplicates, errMsg, dupKeyUpdateCol=false, flatten=true)
    retVal = 0
    sql = 'insert '
    sql += 'ignore ' if(ignoreDuplicates)
    sql += "into #{tableName} values "

    # Ensure whole of data array is flattened
    # - NOTE: MODIFIES data ARG
    data.flatten! if(flatten)

    # Properly handle Ruby Time objects for SQL DATETIME fields.  This behavior
    # will potentially decrease performance, and *possibly* should be turned
    # on/off with an argument to the method (like 'ignoreDuplicates') as
    # necessary (the check is only needed on tables with DATETIME fields).
    # - NOTE: MODIFIES data ARG
    data.each_index{ |index|
      value = data[index]
      if(value.is_a?(Time))
        data[index] = value.strftime("%Y-%m-%d %H:%M:%S")
      end
    }
    begin
      # Lazy connect
      dbh = connectToDB(tableType)
      # Insert no more than MAX_INSERT_VALUES worth of bind slots at a time
      maxBindVarsPerIter = (MAX_INSERT_VALUES - (MAX_INSERT_VALUES % numBindVarsPerValue))
      0.step(data.size-1, maxBindVarsPerIter) { |ii|
        # Create inputArray for this iteration (handed to execute())
        inputData = data[ii, maxBindVarsPerIter]
        # Create sqlValuesStr for this chunk records
        valuesSql = DBUtil.makeSqlValuesStr(inputData.size / numBindVarsPerValue, numBindVarsPerValue, reserveId)
        # Create this iteration's sql
        currSql = (sql + valuesSql)
        if(dupKeyUpdateCol)
          currSql << " on duplicate key update "
          if(dupKeyUpdateCol.is_a?(Array))
            lastIdex = dupKeyUpdateCol.size - 1
            dupKeyUpdateCol.size.times { |ii|
              if(ii != lastIdex)
                currSql << " #{dupKeyUpdateCol[ii]} = VALUES(#{dupKeyUpdateCol[ii]}), "
              else
                currSql << " #{dupKeyUpdateCol[ii]} = VALUES(#{dupKeyUpdateCol[ii]}) "
              end
            }
          else
            currSql << " #{dupKeyUpdateCol} = VALUES(#{dupKeyUpdateCol}) "
          end
        end
        stmt = dbh.prepare(currSql)
        stmt.execute(*inputData)
        retVal += stmt.rows
        stmt.finish()
      }
      # Set last insert id for easy access
      @lastInsertId = getLastInsertId(tableType)
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise @err
    end
    return retVal
  end

  # Generic method to replace the values of some of the columns.
  # the method uses the 'replace' mysql command that inserts a new row after deleting the old row
  # if both the old and the new rows have the same value for a primary key or a unique key
  # [+tableType+] A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+] name of the table where th replace will take place
  # [+data+] array of records to replace
  # [+numValues+] number of records to insert
  # [+numBindVarsPerValue+] The number of dynamic slots per record
  # [+errMsg+] Prefix to use when an error is raised and logged vis logDbError.
  #  Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+] number of rows affected
  def replaceRecords(tableType, tableName, data, numValues, numBindVarsPerValue, errMsg)
    retVal = sql = nil
    sqlPattern = 'replace into '
    sqlPattern += '{tableName} values '
    begin
      dbh = connectToDB(tableType)
      valuesSql = DBUtil.makeSqlValuesStr(numValues, numBindVarsPerValue, reserveId = false)
      sql = sqlPattern.gsub(/\{tableName\}/, tableName)
      sql += valuesSql
      stmt = dbh.prepare(sql)
      stmt.execute(*data.flatten)
      retVal = stmt.rows
      # Set last insert id for easy access
      @lastInsertId = getLastInsertId(tableType)
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic method to set 1+ columns to 1+ values for all records where a field matches a specific value.
  # This will work for tables in main genboree, database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will update all records which have @fieldValue@ for their @fieldName@ field.
  #
  # NOTE: if multiple things match your field name & value pair, then you will update ALL of them.
  # Make sure you know in your code whether multiple matches are possible and process all results
  # accordingly. Just because you think application logic means only be one should be returned is
  # not enough; if table allows more than one item to have tha field name & value, you should check
  # that you recieved what your application logic expect. If you didn't error, warn, or deal appropriately.
  #
  # @param [Symbol] tableType A flag indicating which database handle to use for executing the query.
  #   One of these @Symbols@: :userDB, :mainDB, :otherDB
  # @param [String] tableName   Name of the table to select from.
  # @param [Hash{String=>String}] cols2vals Hash of field/column names to values which will be set for matching records.
  # @param [String] fieldName   Name of the field to look in.
  # @param [String] fieldValue  Value of the field to match.
  # @param [String] errMsg      Prefix to use when an error is raised and logged vis logDbError.
  #   Typically to provide context info of the call (eg name of method calling this one, etc)
  # @return [Fixnum] number of rows affected
  # @todo copy paste duplicate of updateByFieldAndValue?? except for erroneous hh.keys hh.values comments??
  SQL_PATTERN_updateColumnsByFieldAndValue = 'update {tableName} set {setStr} where {fieldName} = ?'
  def updateColumnsByFieldAndValue(tableType, tableName, cols2vals, fieldName, fieldValue, errMsg, relayError=false)
    retVal = -1
    begin
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_updateColumnsByFieldAndValue.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      # Create setStr
      setStr = DBUtil.makeKeyValuePairsSql(cols2vals.keys, :comma)
      sql = sql.gsub(/\{setStr\}/, setStr)
      # Build bindData Array
      bindData = cols2vals.keys.map { |kk| cols2vals[kk] }  # we do this rather than Hash#values to ensure we get same order as Hash#keys!!
      bindData.map! { |value| value.is_a?(Time) ? prepTimeStamp(value) : value }
      bindData << fieldValue
      stmt = dbh.prepare(sql)
      stmt.execute(*bindData)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
  alias :updateByFieldAndValue :updateColumnsByFieldAndValue

  # Generic method to set bits in state field of records in table by exact field match. This will work for tables in main genboree,
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will update all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then you will update ALL of them.
  # Make sure you know in your code whether multiple matches are possible and process all results
  # accordingly. Just because you think application logic means only be one should be returned is
  # not enough; if table allows more than one item to have tha field name & value, you should check
  # that you recieved what your application logic expect. If you didn't error, warn, or deal appropriately.
  #
  # [+tableType+]      A flag indicating which database handle to use for executing the query.
  #                    One of these +Symbols+:
  #                    :userDB, :mainDB, :otherDB
  # [+tableName+]      Name of the table to select from.
  # [+stateBitToSet+]  Bit flag/pattern indicating which bits should be 'on' in a particular state field
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValue+]    Value of the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       The number of rows updated
  SQL_PATTERN_setStateBit = 'update {tableName} set state = (state | ?) where {fieldName} = ?'
  def setStateBit(tableType, tableName, stateBitToSet, fieldName, fieldValue, errMsg)
    retVal = -1
    begin
      if(stateBitToSet < 0)
        raise ArgumentError, "Cannot set a negative state bit (#{stateBitToSet}) !!??"
      end
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_setStateBit.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      bindData = [stateBitToSet, fieldValue]
      stmt = dbh.prepare(sql)
      stmt.execute(*bindData)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic method to toggle bits in state field of records in table by exact field match. This will work for tables in main genboree,
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will update all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then you will update ALL of them.
  # Make sure you know in your code whether multiple matches are possible and process all results
  # accordingly. Just because you think application logic means only be one should be returned is
  # not enough; if table allows more than one item to have tha field name & value, you should check
  # that you recieved what your application logic expect. If you didn't error, warn, or deal appropriately.
  #
  # [+tableType+]      A flag indicating which database handle to use for executing the query.
  #                    One of these +Symbols+:
  #                    :userDB, :mainDB, :otherDB
  # [+tableName+]      Name of the table to select from.
  # [+stateBitToToggle+]  Bit flag/pattern indicating which bits should be toggled in a particular state field
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValue+]    Value of the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       The number of rows updated
  SQL_PATTERN_toggleStateBit = 'update {tableName} set state = (state | ^?) where {fieldName} = ?'
  def toggleStateBit(tableType, tableName, stateBitToToggle, fieldName, fieldValue, errMsg)
    retVal = -1
    begin
      if(stateBitToToggle < 0)
        raise ArgumentError, "Cannot set a negative state bit (#{stateBitToToggle}) !!??"
      end
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_toggleStateBit.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      bindData = [stateBitToToggle, fieldValue]
      stmt = dbh.prepare(sql)
      stmt.execute(*bindData)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic method to clear bits in state field of records in table by exact field match. This will work for tables in main genboree,
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will update all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then you will update ALL of them.
  # Make sure you know in your code whether multiple matches are possible and process all results
  # accordingly. Just because you think application logic means only be one should be returned is
  # not enough; if table allows more than one item to have tha field name & value, you should check
  # that you recieved what your application logic expect. If you didn't error, warn, or deal appropriately.
  #
  # [+tableType+]      A flag indicating which database handle to use for executing the query.
  #                    One of these +Symbols+:
  #                    :userDB, :mainDB, :otherDB
  # [+tableName+]      Name of the table to select from.
  # [+stateBitToClear+]  Bit flag/pattern indicating which bits should be 'off' in a particular state field
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValue+]    Value of the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       The number of rows updated
  SQL_PATTERN_clearStateBit = 'update {tableName} set state = (state & ~?) where {fieldName} = ?'
  def clearStateBit(tableType, tableName, stateBitToClear, fieldName, fieldValue, errMsg)
    retVal = -1
    begin
      if(stateBitToClear < 0)
        raise ArgumentError, "Cannot set a negative state bit (#{stateBitToClear}) !!??"
      end
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_clearStateBit.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      bindData = [stateBitToClear, fieldValue]
      stmt = dbh.prepare(sql)
      stmt.execute(*bindData)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic method to check if a particular bit in the state field of records in table is set by exact field match. This will work for tables in main genboree,
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  #
  # [+tableType+]      A flag indicating which database handle to use for executing the query.
  #                    One of these +Symbols+:
  #                    :userDB, :mainDB, :otherDB
  # [+tableName+]      Name of the table to select from.
  # [+stateBitToCheck+]  Bit flag/pattern indicating which bits should be checked for being 'on' in a particular state field
  # [+fieldName+]     Name of the field to look in.
  # [+fieldValue+]    Value of the field to match.
  # [+errMsg+]        Prefix to use when an error is raised and logged vis logDbError.
  #                   Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]       The number of rows updated
  SQL_PATTERN_checkStateBit = 'select state from {tableName} where {fieldName} = ?'
  def checkStateBit(tableType, tableName, stateBitToCheck, fieldName, fieldValue, errMsg)
    retVal = false
    begin
      if(stateBitToCheck < 0)
        raise ArgumentError, "Cannot check for a negative state bit (#{stateBitToCheck}) !!??"
      end
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_checkStateBit.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      bindData = [fieldValue]
      stmt = dbh.prepare(sql)
      stmt.execute(*bindData)
      rows = stmt.fetch_all
      numRows = rows.length
      if(numRows ==  0)
        raise ArgumentError, "No records meet specified criteria #{fieldName} = #{fieldValue} in table #{tableName} !!??"
      elsif(numRows > 1)
        raise ArgumentError, "Multiple records meet specified criteria #{fieldName} = #{fieldValue} in table #{tableName} !!??"
      else
        if((rows[0]['state']&stateBitToCheck) == stateBitToCheck) then retVal = true end
      end
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic update records whose update conditions are defined in a Hash +selectCond+
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will select all records which have the values specified in +selectCond+ seperated by +booleanOp+
  # for example:    +selectCond+ = {'col1'=>'x', 'col2'=>'y'};  +booleanOp+ = :and
  # would create:   'update table set colA = ?, colB = ? where col1 = x and col2 = y;
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to select from.
  # [+setData+]     Hash containing the fields and values that will be used in SQL SET clause, must have the format: 'fieldName' => 'fieldValue'
  # [+whereData+]   Hash containing the fields and values that will be used in SQL WHERE clause, must have the format: 'fieldName' => 'fieldValue'
  # [+booleanOp+]   Boolean operator used to combine conditions in where clause :and or :or
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]     The number of rows updated
  # @todo if you follow the comments of updateColumnsByFieldAndValue, should update to avoid setData.values
  SQL_PATTERN_updateByMultipleFieldsAndValues = 'update {tableName} set '
  def updateByMultipleFieldsAndValues(tableType, tableName, setData, whereData, booleanOp, errMsg)
    retVal = sql = nil
    setFieldNames = setData.keys
    setFieldValues = setData.values
    setFieldValues.map! { |value| value.is_a?(Time) ? prepTimeStamp(value) : value }
    whereFieldNames = whereData.keys
    whereFieldValues = whereData.values
    begin
      dbh = connectToDB(tableType)
      sql = SQL_PATTERN_updateByMultipleFieldsAndValues.gsub(/\{tableName\}/, tableName)
      sql += DBUtil.makeKeyValuePairsSql(setFieldNames, :comma)
      sql += " where "
      sql += DBUtil.makeKeyValuePairsSql(whereFieldNames, booleanOp)
      stmt = dbh.prepare(sql)
      bindData = setFieldValues.concat(whereFieldValues)
      stmt.execute(*bindData)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Generic delete ALL records in table by exact field match that works for tables in main genboree
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will delete all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then ALL of them will be deleted (!!).
  # Make sure you know in your code whether multiple matches are possible...if you didn't realize ahead
  # of time that multiple records can have the same value for this field, you'll end up deleting unexpected
  # data!
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to delete from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValue+]  Value of the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]     The number of rows deleted
  SQL_PATTERN_deleteByFieldAndValue = 'delete from {tableName} where {fieldName} = '
  def deleteByFieldAndValue(tableType, tableName, fieldName, fieldValue, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_deleteByFieldAndValue.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      sql << "'#{Mysql2::Client.escape(fieldValue.to_s)}'"
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic delete ALL records in table by exact field match that works for tables in main genboree
  # database, user database, or an other database. You must have properly set
  # the right database handle.
  #
  # It will delete all records which have +fieldValue+ for their +fieldName+ field.
  #
  # NOTE: if multiple things match your field name & value pair, then ALL of them will be deleted (!!).
  # Make sure you know in your code whether multiple matches are possible...if you didn't realize ahead
  # of time that multiple records can have the same value for this field, you'll end up deleting unexpected
  # data!
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to delete from.
  # [+whereData+]   Hash containing the fields and values that will be used in SQL WHERE clause, must have the format: 'fieldName' => 'fieldValue'
  # [+booleanOp+]   Boolean operator used to combine conditions in where clause (AND or OR)
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]     The number of rows deleted
  SQL_PATTERN_deleteByMultipleFieldsAndValues = 'delete from {tableName} where '
  def deleteByMultipleFieldsAndValues(tableType, tableName, whereData, booleanOp, errMsg)
    retVal = sql = nil
    whereFieldNames = whereData.keys
    whereFieldValues = whereData.values
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_deleteByMultipleFieldsAndValues.gsub(/\{tableName\}/, tableName)
      sql += DBUtil.makeMysql2KeyValuePairsSql(whereFieldNames, whereFieldValues, booleanOp)
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  # Generic delete records whose +fieldName+ matches one of the values in the +fieldValues+ list.
  # This will work for tables in main genboree, database, user database, or an other database.
  # You must have properly set the right database handle.
  #
  # It will delete all records which have one of the +fieldValues+ for their +fieldName+ field.
  #
  # [+tableType+]   A flag indicating which database handle to use for executing the query.
  #                 One of these +Symbols+:
  #                 :userDB, :mainDB, :otherDB
  # [+tableName+]   Name of the table to delete from.
  # [+fieldName+]   Name of the field to look in.
  # [+fieldValues+] Array of possible values for the field to match.
  # [+errMsg+]      Prefix to use when an error is raised and logged vis logDbError.
  #                 Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]     The number of rows deleted
  SQL_PATTERN_deleteByFieldWithMultipleValues = 'delete from {tableName} where {fieldName} in '
  def deleteByFieldWithMultipleValues(tableType, tableName, fieldName, fieldValues, errMsg)
    retVal = sql = nil
    begin
      client = getMysql2Client(tableType)
      sql = SQL_PATTERN_deleteByFieldWithMultipleValues.gsub(/\{tableName\}/, tableName).gsub(/\{fieldName\}/, fieldName)
      setSQL = DBUtil.makeMysql2SetStr(fieldValues)
      sql += setSQL
      resultSet = client.query(sql, :cast_booleans => true)
      retVal = client.affected_rows
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      client.close rescue nil
    end
    return retVal
  end

  def lockTables(tableType, tableNames, lockType=nil, errMsg=nil)
    retVal = sql = nil
    lockType = "write" if(lockType.nil?)
    errMsg = "ERROR: DBUtil.lockTables():" if(errMsg.nil?)
    setSQL = ""
    tableNames.size.times { |ii|
      if(ii == 0)
        setSQL << "#{tableNames[ii]} #{lockType}"
      else
        setSQL << ", #{tableNames[ii]} #{lockType}"
      end
    }
    begin
      sql = "lock tables #{setSQL}"
      dbh = connectToDB(tableType)
      stmt = dbh.prepare(sql)
      retVal = stmt.execute()
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def unlockTables(tableType)
    tableType = "userDB".to_sym if(tableType.nil?)
    retVal = nil
    errMsg = "ERROR: DBUtil.unlockTables():"
    begin
      dbh = connectToDB(tableType)
      sql = "unlock tables"
      stmt = dbh.prepare(sql)
      retVal = stmt.execute()
    rescue => @err
      DBUtil.logDbError(errMsg, @err, sql)
      raise
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  def prepTimeStamp(value)
    retVal = nil
    if(value.is_a?(Time))
      retVal = value.strftime("%Y-%m-%d %H:%M:%S")
    end
    return retVal
  end

  def self.mysql2gsubSafeEsc(arg)
    escArg = Mysql2::Client.escape(arg)
    return escArg.gsub("\\'", /\\\\'/.source)
  end

  def mysql2gsubSafeEsc(arg)
    return self.class.mysql2gsubSafeEsc(arg)
  end

end # class DBUtil

end ; end # module BRL ; module Genboree
