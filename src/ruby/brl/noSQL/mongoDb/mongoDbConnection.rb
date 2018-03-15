#!/bin/env ruby
require 'json'
require 'yaml'
require 'brl/extensions/bson' # BEFORE require 'mongo' or require 'bson'!
require 'mongo'
require 'brl/util/util'
require 'brl/dataStructure/singletonCache'
require 'brl/noSQL/mongoDb/mongoDbDSN'
require 'brl/noSQL/mongoDb/mongoDbURI'

module BRL ; module NoSQL ; module MongoDb
  # A class for accessing global, process-wide MongoDB connection mangager classes
  #   (i.e. instances of this class). It keeps track of 1 such connection manager
  #   per unique mongo server connnection--unique in terms of host, authentication
  #   credentials, options employed, etc. It is possible to maintain several
  #   connections to a given MongoDB engine which employ differing authentication
  #   credentials and/or options, if needed [rare!]
  # One should NOT connect to the MongoDB directly using {MongoClient}! This will
  #   open up too many connections unnecessarily when reusing an existing one could
  #   be done instead. Use {MongoDbConnection.getInstance} instead!
  # MongoDB uses per-database credentials, rather than a centralized set of credentials.
  #   However, this class lets you provide the default credentials to use when getting
  #   {Mongo:DB} instances via {#db}. Of course you can, if needful, provide speicific
  #   per-database credential information which will be tracked and used by this class.
  #   You can force it to replace existing authentication info for a database easily, without having
  #   to go through @remove_auth@ and @add_auth@ yourself. However, this is all RARE; most
  #   usages will rely on the default auth credentials specified just once, up front.
  class MongoDbConnection
    include Mongo

    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # @return [Class] A local shortcut to {BRL::DataStructure::SingletonCache}
    MongoDbConnectionCache = BRL::DataStructure::SingletonCache
    # @return [Hash] The default @opts@ hash which is used. If you provide your own
    #   @opts@ hash to {#getInstance}, it will be MERGED with this one.
    DEFAULT_OPTS =
    {
      :w        => 1,
      :j        => true,
      :fsync    => false,
      :wtimeout => 0
    }
    # @return [Fixnum] Default MongoDB TCP/IP port
    DEFAULT_PORT = Mongo::MongoClient::DEFAULT_PORT
    # @return [String] Default MongoDB TCP/IP host (localhost, but as IP address of 127.0.0.1)
    DEFAULT_HOST = "localhost"

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @attr_reader [Hash] defaultAuthInfo A {Hash} with two keys.
    # @option defaultAuthInfo [String] :user The default user to use when authenticating
    #   against a database
    # @option defaultAuthInfo [String] :pass The default password to use when
    #  authenticating againsta database
    attr_reader :defaultAuthInfo
    # @attr [Hash] connInfo Containing the connection information. Possible keys are the usual:
    # * @:host@ - database host, if available ; mutually exclusive with @socket@
    # * @:port@ - database port, if available ; mutually exclusive with @socket@ ;
    #     default is 27017 if @host@ present but no @port@.
    # * @:socket@ - database socket file path, if available ; mutually exclusive
    #     with @host@ and @port@
    attr_reader :connInfo
    # @attr [Hash] opts Containingg any extra connection options. Key options are:
    # @option opts [Integer, Symbol] :w The WriteConcern level. 0=unacknowledged (fast, no guarrantee;
    #   1=acknowledge, pretty fast, no gauarrantee even in journal; 2+=number of replica sets
    #   which have to acknowledge, slow!). Special value :majority is useful here, as it says
    #   "as soon as majority of replica sets acknowledge the write, whatever that majority is".
    # @option opts [Boolean] :j Whether journal acknowledgement should be done. If committed to
    #   journal at least, then the write can be replayed/applied even after a failure/crash on the server.
    #   This is a good option, if your journal-writing is fast (separate partition on different disk system
    #   maybe SSDs, not NFS, etc)!
    # @option opts [Boolean] :fsync Set fsync acknowledgement? Only respond once data is actually on disk
    #   from OS fsync operation. Super slow!!!
    # @option opts [Integer] :wtimeout The write timeout to replica sets in milliseconds. Really only
    #   issue when w>=2, and then it's required to prevent infinite blocking. You decide what to do if write
    #   timesout. A value of 0 means "indefinite" and is the default.
    attr_reader :opts
    # @attr [Mongo::MongoClient] client The {MongoClient} instance for this connection, if needed. Generally you
    #   should use {#db} to get database objects, not @client.db()@, because this connection object will
    #   automatically apply your default authorization credentials and try to ensure you're working with a
    #   live {client}, etc.
    attr_reader :client
    # @attr [String] dsn A ~normalized DSN connection string for this connection object. Used as a key in the
    #   global connection cache and may be otherwise useful too.
    attr_reader :dsn
    # @attr [Hash] auths The map of authentication credentials per-database. MongoDB uses per-database
    #   credentials. While we prefer to rely on the {#defaultAuthInfo} credenitals, internally this
    #   class supports the different credentials-per-database if needed. (i.e. If defaults not applicable
    #   in all cases. Rare.)
    attr_reader :auths

    # Make "new()" method protected. Only callable by THIS CLASS (i.e. for getInstance()).
    class << self
      protected :new
    end

    # Get an instance of this connection class for subsequent use (e.g. to call {#db} on). It will consult
    #   the global connection cache using your connection info and re-use a matching existing connection
    #   if available. Or it will create a new one and cache it.
    # @note Use this instead of @new@ (which should fail if you try to use it).
    # @note When using a URI, don't provide @defaultAuthInfo@ and @opts@ parameters. Everything is in the URI.
    # @note When using a DSN, don't provide @opts@, as that info should be in the DSN.
    # @param [Hash,String] connInfo A connection string (DSN and URI both supported) or a connection hash. See {#connInfo}
    #   for keys to use in the hash.
    # @param [Hash] defaultAuthInfo This is only needed the FIRST time you get an instance for a given @connInfo@. It will
    #   save the default authorization credentials to use when accessing specific databases via {#db}. Subsequent calls
    #   to {#getInstance} using the same @connInfo@ do not need this parameter, although if provided [systematically say]
    #   it will be IGNORED as the cached connection will already have it. The Hash should have sub-keys @:user@ and @:pass@;
    #   most commonly these would come from a DBRC record
    #   Consider: @dbrc = BRL::DB::DBRC.new() ; dbrcRec = dbrc.getRecordByHost(gbHost, :nosql)@)
    # @param [Hash] opts Any extra options for making the connection. See {#opts} for some key options.
    # @return [MongoDbConnection] Re-usable and cached instance of this class.
    def self.getInstance(connInfo, defaultAuthInfo=nil, opts={})
      # Merge in opts
      newOpts = DEFAULT_OPTS.merge(opts)
      # Deal with DSN or URI connection strings, if needed.
      if(connInfo.is_a?(String))
        # assume connInfo is a String
        connInfo = connInfo.strip
        if(connInfo =~ /^mongodb:\/\//)
          # then looks like a mongodb:// URI. Parse it.
          unless(defaultAuthInfo.nil? and (opts.nil? or opts.empty?))
            raise ArgumentError, "ERROR: do not provide defaultAuthInfo and opts parameters when using a mongodb:// type URI connection string. All that info shall be properly in the mongodb:// URI."
          else
            mongoInfo = BRL::NoSQL::MongoDb::MongoDbURI.parse(connInfo)
            connInfo = mongoInfo[:connInfo]
            defaultAuthInfo = mongoInfo[:auth]
            opts = mongoInfo[:opts]
          end
        else # assume it's a DSN connection string
          unless(opts.nil? or opts.empty?)
            raise ArgumentError, "ERROR: do not provide opts parameter when using a NoSQL:MongoDb: type DSN connection string. All that info shall be properly in the DSN string."
          else
            mongoInfo = BRL::NoSQL::MongoDb::MongoDbDSN.parse(connInfo)
            connInfo = mongoInfo[:connInfo]
            opts = mongoInfo[:opts]
          end
        end
      end
      # At this point we either already had a connInfo hash or we made one from the connection string.
      # Create ~normalized DSN connection string (mainly for use as a cache key)
      dsn = BRL::NoSQL::MongoDb::MongoDbDSN.makeDSN(connInfo, opts)

      # BUG WORKAROUND: Cache disabled. Seeing connection accumulation up to max on dev. Likely it is UNCLOSED CURSORS though.
      mgoDbUtil = nil
      # # Check cache using DSN
      # mgoDbUtil = MongoDbConnectionCache.getObject(:mongoDbUtil, dsn)
      # # Check if have connection in global cache and connection alive.
      # if(mgoDbUtil and mgoDbUtil.client)
      #   unless(mgoDbUtil.client.active?)
      #     # Not connected. Need to reconnect.
      #     begin
      #       mgoDbUtil.client.reconnect()
      #       if(mgoDbUtil.client.active?)
      #         mgoDbUtil.client.apply_saved_authentication()
      #       else
      #         # Checked again after reconnect, STILL not active?? WTF? Wipe and create a new one.
      #         mgoDbUtil.removeFromCache()
      #         mgoDbUtil = nil
      #       end
      #     rescue => err
      #       # Reconnect failed outright. Let's try a whole new connection below. But first, try to clean out this one.
      #       mgoDbUtil.removeFromCache()
      #       mgoDbUtil = nil
      #     end
      #   end
      # end
      # Either we have an active mgoDbUtil here from the cache (even if due to a reconnect) and we're good,
      # or it's nil and we need to [re]make one and add to cache.
      unless(mgoDbUtil)
        # Make connection
        mgoDbUtil = MongoDbConnection.new(connInfo, defaultAuthInfo, opts)
        # Ensure we authorize against the "admin" database up front to get full & appropriate access
        mgoDbUtil.addAuth('admin', defaultAuthInfo)
        # BUG WORKAROUND: Cache disabled. Seeing connection accumulation up to max on dev. Likely it is UNCLOSED CURSORS though.
        # # Cache the connection
        # MongoDbConnectionCache.cacheObject(:mongoDbUtil, mgoDbUtil.dsn, mgoDbUtil)
      end
      return mgoDbUtil
    end

    # Set/change the default authorization credentials for this instance. Really, this
    #   info should have been provided upon the first call to {#getInstance} either via
    #   the URI, or via the @defaultAuthInfo@ parameter when using a DSN or connection info {Hash}.
    # However, this method allows you to DEFER setting this default info or to CHANGE existing
    #   default (although need for that should be very rare).
    # @param [Hash] defaultAuthInfo Two-key hash having values for @:user@ and @:pass@.
    # @return [Hash] the saved default authentication info.
    def setDefaultAuthInfo(defaultAuthInfo)
      retVal = {}
      if(defaultAuthInfo.key?(:user) and defaultAuthInfo.key?(:pass))
        retVal[:user], retVal[:pass] = defaultAuthInfo[:user], defaultAuthInfo[:pass]
      else
        raise ArgumentError, "ERROR: the defaultAuthInfo parameter must have values for both the keys :user and :pass."
      end
      @defaultAuthInfo = retVal
    end

    # Clear out this connection by clearing auth info, closing the connections,
    #   clearing others state, and removing itfrom the global cache.
    # @note The {#dsn} proptery will still be available if needed (to reconnect or something weird).
    #   Most everything else will be cleared.
    # @return (see BRL::DataStructure::SingletonCache#removeObject)
    def destroy()
      disconnect()
      @connInfo = @defaultAuthInfo = @opts = nil
      removed = MongoDbConnectionCache.removeObject(:mongoDbUtil, @dsn) rescue nil
      return removed
    end

    def db(database, authInfo=nil, forceNewAuth=false)
      # Ensure we have some authInfo set up. If not provided here, use @defaultAuthInfo for this object.
      if(authInfo.nil?)
        authInfo = @defaultAuthInfo
      end
      # Only save authInfo IF DATABASE ACTUALLY EXISTS
      # - Else, we're expecting it will be made via createDb()
      # - Trying to save/apply authInfo for databases that don't exist
      #   yet will fail.
      if(@client.database_names.include?(database))
        if(database == 'admin')
          if(authInfo and authInfo.key?(:user) and authInfo.key?(:pass))
            addAuth(database, authInfo, forceNewAuth) # No-op if already have auth info for database
          else
            raise "ERROR: No default authentication credentials have been provided via a getInstance() parameter or subsequently via setDefaultAuthInfo() nor was any suitable database-specific authInfo provided to this db() call [which is rarely needed anyway, the default credentials are what should be relied on for the most part). So can't authenticate. Authentication hashes will have both :user and :pass Symbols as keys."
          end
        end
      end
      # return a Mongo::DB ... underlying database may or may not exist yet
      return @client.db(database)
    end

    def createDb(dbName, user=@defaultAuthInfo[:user], pass=@defaultAuthInfo[:pass])
      # Ensure we are authenticated against the "admin" database
      #   so we know if we have needed *AnyDatabase privileges to add new
      #   databases and administer them.
      # We ALWAYS do this with the @defaultAuthInfo content. This will auth us against the admin database as a side effect.
      adminDb = self.db("admin", @defaultAuthInfo)
      # Next, use our admin-level privileges to create the new database unless it already exists
      unless(@client.database_names.include?(dbName))
        newDb = @client[dbName] # lazy create...doesn't exist until you do something with it
      else
        raise ArgumentError, "ERROR: the database #{dbName.inspect} already exists! Cannot create again."
      end
      return newDb
    end

    # ------------------------------------------------------------------
    # RARELY NEEDED UTILITY METHODS
    # - usually won't need these, as the default usage is simpler and takes
    #   care of worrying about the kinds of issues these support
    #   (e.g. managing the differing auth credentials per database)
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # HELPER METHODS.
    # - mainly used internally
    # ------------------------------------------------------------------

    # HELPER METHOD. Try hard to disconnect the {MongoClient} ({#client}). Usually as part of
    #   removing this {MongoDbConnection} object from the global cache.
    def disconnect()
      if(@client)
        @client.clear_auths() rescue false
        @client.close() rescue false
        @client = nil
      end
    end

    # Add specific authentication information for a given database. Presumably
    #   different from info in {#defaultAuthInfo}.
    # @param [String] database Name of MongoDB database this authentication info is for
    # @param [Hash] authInfo A two-key {Hash} with specific keys @:user@ and @:pass@.
    # @param [Boolean] forceReplace Set to @true@ to override whatever is already saved
    #   for the database in this connection object. The default (@false@) will basically
    #   do nothing if there is authentication info already saved for the database.
    #   Setting to @true@ will cause a forcible removal of saved info from both this object
    #   and from the {#client} object.
    # @return [Boolean] indicating whether stored auth info was ACTUALLY changed. May not be
    #   if already available and @forceReplace@ is @false@.
    def addAuth(database, authInfo, forceReplace=false)
      retVal = false
      # If not present yet or present but being asked to replace, remove from (a) the client and (b) from @auths.
      if((@auths.key?(database) and forceReplace) or !@auths.key?(database))
        @client.remove_auth(database) # this works fine even if not present in @client yet (returns false in that case)
        # Add to client
        retVal = @client.add_auth(database, authInfo[:user], authInfo[:pass], nil)
        # Apply (actually authenticate...all saved authentications)
        @client.apply_saved_authentication()
        # Add to @auths (if successful auth)
        @auths[database] = authInfo
        retVal = true
      end
      return retVal
    end

    # Add a set of database => authInfo mappings all at once (batch add.)
    # @see #addAuth
    # @param [Hash{String=>Hash}] db2auth Mapping database names to a two-key {Hash}
    #   with specific keys @:user@ and @:pass@.
    # @param [Boolean] forceReplace Set to @true@ to override whatever is already saved
    #   for the database in this connection object. The default (@false@) will basically
    #   do nothing if there is authentication info already saved for the database.
    #   Setting to @true@ will cause a forcible removal of saved info from both this object
    #   and from the {#client} object.
    # @return [Boolean] Always true.
    def addAuths(db2auth, forceReplace=false)
      db2auth.each_key { |db|
        addAuth(db, db2auth[db][:user], db2auth[db][:pass])
      }
      return true
    end

    # Remove saved auth information for a given database
    # @param [String] database The database to remove the auth info for
    # @return [Boolean] indicating whether the removal went ok or not. (Generally always @true@)
    def removeAuth(database)
      retVal = false
      # Remove from our @auths property
      @auths.delete(database)
      # Remove from the @client as well
      @client.remove_auth(database)
      retVal = true
      return retVal
    end

    # HELPER CLASS METHOD. Ensures the connection info contains the minimum info needed and applies
    #   certain default info in a few cases (e.g. a host of 127.0.0.1 when only port is provided)
    #   etc.
    # @param [Hash] connInfo The connection info hash, often from a DSN or built manually in code.
    # @return [Hash] The same hash object, possibly updated with additional keys
    # @raise [ArgumentError] When there is not even minimal connection info...something to work with...
    def self.ensureMinConnInfo(connInfo)
      # Check for minimum info. Apply defaults if needed.
      if(connInfo.key?(:host) or connInfo.key?(:port) or connInfo.key?(:socket))
        if(connInfo.key?(:host))
          if(!connInfo.key?(:port) and !connInfo.key?(:socket))
            connInfo[:port] = DEFAULT_PORT
          end
        elsif(connInfo.key?(:port)) # elsif works nicely here, yes; means no host...
          connInfo[:host] = DEFAULT_HOST unless(connInfo.key?(:host))
        elsif(connInfo.key?(:socket))
          connInfo[:host] = DEFAULT_HOST unless(connInfo.key?(:host))
        end
      else
        raise ArgumentError, "ERROR: The connection info provided doesn't have at least one of 'host', 'port', or 'socket'. Can't connect to nothing!"
      end
      return connInfo
    end

    # PROTECTED. DO NOT CALL new() DIRECTLY. Use {#getInstance} instead.
    # @param (see #getInstance)
    def initialize(connInfo, defaultAuthInfo, opts={})
      @auths = {}
      @connInfo = connInfo
      @connInfo[:port] = @connInfo[:port].to_i if(@connInfo.key?(:port))
      # Save defaultAuthInfo
      @defaultAuthInfo = ( defaultAuthInfo || {} )
      # Go through opts and try to auto-cast values to proper Fixnums, Floats, boolean values, etc
      if(opts.is_a?(Hash))
        newOpts = {}
        opts.each_key { |opt|
          val = opts[opt]
          newOpts[opt.to_sym] = (val.is_a?(String) ? val.autoCast(false) : val)
        }
      end
      # Create client, using opts merged with default opts
      @opts = DEFAULT_OPTS.merge(newOpts)
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MongoClient opts: #{@opts.inspect}")
      if(@connInfo.key?(:socket))
        @client = MongoClient.new(@connInfo[:socket], nil, @opts)
      else
        @client = MongoClient.new(@connInfo[:host], @connInfo[:port], @opts)
      end
      # Save ~normalized DSN
      @dsn = BRL::NoSQL::MongoDb::MongoDbDSN.makeDSN(@connInfo, @opts)
    end
  end # class MongoDbConnection
end ; end ; end # module BRL ; module NoSQL ; module Mongo
