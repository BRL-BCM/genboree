=begin
= Description
		HACKED dbi/dbrc.rb library for more general usage, like with apache
					 HACKED BY: Andrew R Jackson (arjackson@bcm.tmc.edu)

   This is a supplement to the dbi module, allowing you to avoid hard-coding
   passwords in your programs that make database connections.

= Synopsis
   require 'brl/db/dbrc'

	 dbrcFile = ENV['DB_ACCESS_FILE'] # get file name somehow

   dbrc = BRL::DB::DBRC.new(dbrcFile, "mydb")

   or

   dbrc = DBRC.new(dbrcFile, "mydb", "someUser")

   puts dbrc.db
   puts dbrc.user
   puts dbrc.driver
   puts dbrc.timeout
   puts dbrc.max_reconn
   puts dbrc.interval
   puts dbrc.dsn

   dbh = DBI.connect(dbrc.dsn, dbrc.user, dbrc.password)

= Requirements
   The 'etc' module

   Designed for *nix systems.  Untested on Windows.

= Notes on the .dbrc file

   This module relies on a file in your home directory called ".dbrc", and it
   is meant to be analogous to the ".netrc" file used by programs such as telnet.
   The .dbrc file has several conditions that must be met by the module or it
   will fail:

   1) Permissions *MUST* be set to 600.
   2) Must be owned by the current user
   3) Must be in the following space-separated format:

      <database> <user> <password> <driver> <timeout> <maximum reconnects> <interval>

   e.g. mydb     dan    mypass     oracle   10       2                    30

   You may include comments in the .dbrc file by starting the line with a "#" symbol

	 You may list as many entries as needed. As long as the first two fields
	 uniquely identify the record, it all makes sense.

= Class Methods

--- new(fileName, db,?user?)
    The constructor takes two or three arguments. The 1st argument is the name/location
    of the .dbrc file with all the access record. The 2nd argument is the database
    name.  This *must* be provided.  If the database name is passed without a user
    argument, the module will look for the first database entry in the .dbrc file that matches.

    The 3rd argument, a user name, is optional.  If it is passed, the module will
    look for the first entry in the .dbrc file where both the database *and* user
    name match.

= Instance Methods

--- <database>
    The name of the database.  Note that the same entry can appear more than once,
    presumably because you have multiple user id's for the same database.

--- <user>
    A valid user name for that database.

--- <password>
    The password for that user.

--- <driver>
    The driver type for that database (Oracle, MySql, etc).

--- <timeout>
    The timeout period for a connection before the attempt is dropped.

--- <maximum reconnects>
    The maximum number of reconnect attempts that should be made for the the
    database.  Presumablly, you would use this with a "retry" within a rescue
    block.

--- <interval>
    The number of seconds to wait before attempting to reconnect to the database
    again should a network/database glitch occur.

--- <dsn>
    Returns a string in "dbi:<driver>:<database>" format. Bogus for many useful
    things, such as MySql connections to a non-local host. You can put the full
    dsn in the 'driver' field in this case and just use that directly.

= Summary

   These "methods" don't really do anything.  They're simply meant as a convenience
   mechanism for you dbi connections, plus a little bit of obfuscation (for passwords).

= Changelog

--- 0.1.2.ARJ 12/18/2002 12:56AM
   - hacked by Andrew for use in other contexts (like apache)
   - added some comments about it
   - added a real error class--StandardError abuse slows debugging
   - removed home directory requirement--file now passed as arg to init
   - left in the 600 permissions and user-owned, since those are vital

--- 0.1.1 - 14:54 on 26-Jul-2002
   - Added 'dsn()' method
   - Minor documentation additions

--- 0.1.0 - 12:24 on 26-Jul-2002
   - Initial release

= Authors
   Andrew R Jackson
   arjackson@acm.org

   Daniel J. Berger
   djberg96@nospam.hotmail.com (remove the 'nospam')

=end

require 'etc'
require 'brl/util/util'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'

module BRL ; module DB

class DBRCError < RuntimeError ; end

class DBRC
  # ------------------------------------------------------------------
  # MIX-INS
  #------------------------------------------------------------------
  # Uses the global domain alias cache and methods
  include BRL::Cache::Helpers::DomainAliasCacheHelper
  include BRL::Cache::Helpers::DNSCacheHelper

  # Set up a cached version of the dbrc file records for speed. But the load()
  # method below MUST check if file has changed since we last cached it.
  # - a "Class Instance" variable used like this DBRC.cache
  # - only the DBRC.load() class method will take advantage of this caching.
  # - not thread friendly, be careful!!
  # Set up class-level cache (stored in "class-instance" variables)
  class << self
    attr_accessor :cache, :cacheLock
  end
  @cache = nil
  @cacheLock = Mutex.new

  # Real object-instance variables:
  attr_accessor :key, :user, :password, :driver, :dsn, :dbName
  attr_accessor :max_reconn, :timeout, :interval, :host, :port, :socket, :driverType, :driverSubType
  attr_accessor :hostType # Internal or External ?
  attr_accessor :dbrcRecs # loaded hash-of-hashes from dbrc file
  alias_method :db, :key
  alias_method :db=, :key=
  alias_method :database, :dbName

  # Because class-level variables are shared across ALL threads, this method
  # had to be written VERY carefully, assuming that at ANY point a different thread could interupt
  # and leave things in an inconsistent state. Therefore there is a bunch of testing to see if things
  # are really there and really populated with non-default values. These tests are fast.
  def self.load(dbrcFile=nil, domainAliasFile=ENV['DOMAIN_ALIAS_FILE'])
    dbrcFile = (ENV['DBRC_FILE'] || ENV['DB_ACCESS_FILE'] || '~/.dbrc') unless(dbrcFile)
    dbrcFile = "~/.dbrc" if(dbrcFile.to_s !~ /\S/)
    retVal = nil
    DBRC.cacheLock.synchronize {
      # Get cache record using dbrcFile path as key
      if(DBRC.cache)
        cacheRec = DBRC.cache[dbrcFile]
        if(cacheRec and !cacheRec.empty? and cacheRec[:mtime]) # have cached config object, can we use it?
          mtimeOfDbrcFile = File.mtime(dbrcFile)
          if(cacheRec[:mtime] >= mtimeOfDbrcFile and cacheRec[:obj]) # cache version is ok
            retVal = cacheRec[:obj]
          else # cache out of date or in middle of loading by someone else (another thread?)
            retVal = nil
          end
        end
      else # no cache yet
        DBRC.cache = Hash.new { |hh,kk| hh[kk] = {} }
        retVal = nil
      end
      # If retVal still nil, either not cached yet or cache is out of data
      unless(retVal)
        retVal = self.readDbrcRecords(dbrcFile)
        DBRC.cache[dbrcFile][:mtime] = File.mtime(dbrcFile)
        DBRC.cache[dbrcFile][:obj] = retVal
      end
    }
    return retVal
  end

  def self.readDbrcRecords(dbrcFile)
    retVal = nil
    dbrcFileOk = DBRC.check_file(dbrcFile)
    if(dbrcFileOk)
      retVal = Hash.new { |hh, kk| hh[kk] = {} }
      hostType = :internal  # All host types in DBRC file are "internal" now
      ff = File.open(dbrcFile, "r")
      ff.each_line { |line|
        if(line =~ /\S/)          # not a blank line
          if(line !~/^\s*#(?!#)/) # not a comment line
            fields = line.split(/\s+/)
            rec = { :hostType => hostType }
            rec[:key] = fields[0]
            # Host defaults to the host portion of the key field. This is really a FALLBACK since
            # the DRIVER string should have the host in ALL the various formats of DRIVER.
            # - Can be overridden via a host={actualHost} in the AVP.
            keyParts = rec[:key].split(':').map { |part| part.strip }
            rec[:host] = ( ( keyParts.size > 1 ) ? keyParts[1] : keyParts[0] ) # handle type:host keys and very old host only keys
            rec[:user] = fields[1]
            rec[:password]   = fields[2]
            rec[:driver]     = fields[3]
            driverFields     = parseDriver(rec[:driver])
            rec[:host]       = driverFields[:host] if( driverFields[:host].to_s =~ /\S/ ) # override host mentioned in key IFF have host={actualHost} override
            rec[:port]       = driverFields[:port]
            rec[:socket]     = driverFields[:socket]
            rec[:dbName]     = driverFields[:database]
            rec[:timeout]    = fields[4]
            rec[:max_reconn] = fields[5]
            rec[:interval]   = fields[6]
            rec[:dsn] = rec[:driver] + ":" + rec[:key]
            retVal[rec[:key]] = rec
          end
        end
      }
      ff.close()
    end
    return retVal
  end

  #+++++++++++++++++++++++++++++++++
  # Check ownership and permissions
  #+++++++++++++++++++++++++++++++++

  def self.check_file(dbrcFile)
    File.open(dbrcFile) { |ff|
      # Permissions MUST be set to 600
      unless((ff.stat.mode & 077) == 0)
        raise(BRL::DB::DBRCError, "\nERROR: Bad Permissions for dbrc file #{dbrcFile.inspect}", caller)
      end

      # Only the owner may use it
      unless(ff.stat.owned?)
        raise(BRL::DB::DBRCError, "\nERROR: Not Owner of dbrc file #{dbrcFile.inspect}", caller)
      end
    }
    return true
  end

  def initialize(dbrcFile=nil, key=nil, user=nil, gbInstanceKey=nil)
    dbrcFile = (ENV['DBRC_FILE'] || ENV['DB_ACCESS_FILE'] || '~/.dbrc') unless(dbrcFile)
    dbrcFile = "~/.dbrc" if(dbrcFile.to_s !~ /\S/)
    #
    @dbrc = File.expand_path(dbrcFile.strip)
    @key = key
    @user = user
    @hostType = :internal
    @gbInstanceKey = gbInstanceKey
    # Retrieve dbrc records from cache (DBRC.load() will read from cache or disk as needed)
    @dbrcRecs = DBRC.load(@dbrc)
    # Old way: will set some instance variables based on "key" (!!)
    get_info(@key) if(key)
  end

  # Override inspect to prevent printing of any user/password information if dbrc is used
  # in a composite object
  def inspect()
    return self.to_s.gsub(">", " @dbrc=#{@dbrc}>")
  end

  # Make the info in the given record hash the "active" data. Most common info is available via instance methods.
  def makeActive( dbrcRec )
    @user       = dbrcRec[:user]
    @password   = dbrcRec[:password]
    @driver     = dbrcRec[:driver]
    @timeout    = dbrcRec[:timeout]
    @max_reconn = dbrcRec[:max_reconn]
    @interval   = dbrcRec[:interval]
    @dsn        = dbrcRec[:dsn]
    @host       = dbrcRec[:host]
    @port       = dbrcRec[:port]
    @socket     = dbrcRec[:socket]
    @dbName     = @database = dbrcRec[:dbName]
    @dbName     = @database = dbrcRec[:database] if( dbrcRec[:database].to_s =~ /\S/ )
    driverFields = parseDriver( dbrcRec )
    @host       = driverFields[:host] if( driverFields[:host].to_s =~ /\S/ )
    @port       = driverFields[:port] if( driverFields[:port].to_s =~ /\S/ )
    @socket     = driverFields[:socket] if( driverFields[:socket].to_s =~ /\S/ )
    @dbName     = @database = driverFields[:database] if( driverFields[:database].to_s =~ /\S/ )
    @driverType = driverFields[:type]
    @driverSubType = driverFields[:subType]

    # Cast numerics
    @port       = ( ( @port.to_s =~ /^\d+$/ ) ? @port.to_s.to_i : nil )
    @timeout    = ( ( @timeout.to_s =~ /^\d+$/ ) ? @timeout.to_s.to_i : nil )
    @max_reconn = ( ( @max_reconn.to_s  =~ /^\d+$/ ) ? @max_reconn.to_s.to_i : nil )
    @interval   = ( ( @interval.to_s =~ /^\d+$/ ) ? @interval.to_s.to_i : nil )

    return self
  end

  #+++++++++++++++++++++++++++++++++++++++++++++++++++
  # Grab info out of the .dbrc file.  Ignore comments
  # - this method will set some instance variable based on "key" param
  #+++++++++++++++++++++++++++++++++++++++++++++++++++
  def get_info(key=@key)
    retVal = nil
    if(key)
      @dbrcRecs = DBRC.load(@dbrc)
      if(@dbrcRecs.key?(key))
        retVal = dbrcRec = @dbrcRecs[key]
        makeActive( dbrcRec )
      end
    else # no key configured or supplied
      raise(BRL::DB::DBRCError, "\nERROR: must provide the key (or set 'key' attribute) for the dbrc record you are interested in. Or use getRecordByHost() approach.")
    end
    return retVal
  end

  # Get record by host & record type (:api or :db), also matching optional user.
  # - Uses domain aliases if host as-is cannot find record.
  # - Assumes new key-naming standard of "API:{hostName}" and "DB:{hostName}".
  def getRecordByHost(hostName, recType, user=nil)
    retVal = nil
    if(hostName and recType)
      # Ensure loaded up-to-date version
      @dbrcRecs = DBRC.load(@dbrc)
      # Build standard key:
      key = "#{recType.to_s.upcase}:#{hostName.strip}"
      rec = nil
      if(@dbrcRecs.key?(key))
        rec = @dbrcRecs[key]
      else  # no rec, then we need to try the domain alias
        domainAlias = self.class.getDomainAlias(hostName)
        if(domainAlias)
          key = "#{recType.to_s.upcase}:#{domainAlias.strip}"
          rec = @dbrcRecs[key] if(@dbrcRecs.key?(key))
        end
      end
      # If have non-nil rec at this point (via hostName or its domainAlias), see if we need to match user
      if(rec and user)
        if(rec[:user] == user.strip)
          retVal = rec.deep_clone # don't give back internal record, dev might make edits/changes and the internal record is CACHED
        end
      elsif(rec)
        retVal = rec.deep_clone  # don't give back internal record, dev might make edits/changes and the internal record is CACHED
      else
        retVal = nil
      end
    end
    return retVal
  end

  def getRecordByHostForDb( hostName, recType, dbName )
    retVal = nil
    # First, get the standard type:host record, even if the "preferred" or typical database mentioned is NOT the one we want
    dbrcRec = getRecordByHost( hostName, recType )
    if( dbrcRec )
      # getRecordByHost() should be returning a duplicate for safety but to be sure
      #   we're not about to edit the internal cached copy:
      dbrcRec = dbrcRec.deep_clone
      # we replace mention of 'preferred/typical' db in various parts of the record
      dbrcRec[:dbName] = dbrcRec[:database] = dbName
      [ :driver, :dsn ].each { |field|
        dbrcRec[field].gsub!( /database=(?:[^=;]+)/, "database=#{dbName}" )
      }
      retVal = dbrcRec
    end

    return retVal
  end

  # Get record as a Hash of hostName => [ login, password, :internal ]
  # by host & record type (:api or :db), also matching optional user.
  # Or if you only provide the record type Symbol, get ALL records of that type as a host auth map.
  # - Basically same as getRecordByHost(), but returns in hostAuthMap format.
  # - Uses domain aliases if host as-is cannot find record.
  # - Assumes new key-naming standard of "API:{hostName}" and "DB:{hostName}".
  # @param [String,Symbol] hostNameOrRecType If String must also provide the @recType@ parameter. If Symbol, it is presumed to BE the
  #   the record type Symbol parameter and is used on its own.
  # @param [Symbol,nil] recType If hostNameOrRecType is a String then this parameter is required and is the record type Symbol.
  # @return [Hash] A host auth map hash with one entry if called with both @hostName@ and @recType@ or many entries
  #   if called with just hostNameOrRecType
  def getHostAuthMap(hostNameOrRecType, recType=nil, user=nil)
    retVal = nil
    if(hostNameOrRecType and recType)
      dbrcRec = getRecordByHost(hostNameOrRecType, recType, user)
      if(dbrcRec)
        canonicalAddress = self.class.canonicalAddress(dbrcRec[:host])
        retVal = {
          canonicalAddress => [ dbrcRec[:user], dbrcRec[:password], :internal ]
        }
      end
    elsif(hostNameOrRecType.is_a?(Symbol))
      retVal = {}
      @dbrcRecs.each_key { |kk|
        if(kk =~ /^#{Regexp.escape(hostNameOrRecType.to_s.upcase)}:/)
          dbrcRec = @dbrcRecs[kk]
          canonicalAddress = self.class.canonicalAddress(dbrcRec[:host])
          retVal[canonicalAddress] = [ dbrcRec[:user], dbrcRec[:password], :internal ]
        end
      }
    end
    return retVal
  end

  # Parse the driver string obtained from a dbrc record Hash.
  # @param [Hash] dbrcRec The DBRC record of interest, as a Hash (like returned by {#getRecordByHost} etc)
  # @return [Hash] The extracted driver info. Some common options are (there may be more for more generic things):
  #   @option [String] :host The host to connect to, if present.
  #   @option [Fixnum] :port The port to connect to, if present.
  #   @option [String] :socket The socket to connect to, if present.
  #   @option [String] :db The database name to use.
  #   @option [String] :type The general type of driver/connection.
  #   @option [STring] :subType The general sub-type or implementation.
  def parseDriver( dbrcRec )
    driver = dbrcRec[:driver]
    return self.class.parseDriver( driver )
  end

  def self.parseDriver( driver )
    retVal = { :host => nil, :port => nil, :socket => nil, :db => nil, :type => nil, :subType => nil }
    driverFields = driver.to_s.split(/:/)
    if( driverFields.size >= 3 )
      retVal[:type] = driverFields[0].strip
      retVal[:subType] = driverFields[1].strip

      # Extract various possible info, which depends on driver format
      if(driverFields.size >= 4) # then old style driver string: type:subtype:database:host
        retVal[:database] = driverFields[2].strip
        retVal[:host] = driverFields[3].strip
      else # better new NVP style
        thirdField = driverFields[2].to_s.strip
        if( thirdField =~ /=/ ) # then 3-col driver string with AVPs in 3rd col. Good.
          nvpStrs = thirdField.split(/\;/).map { |ss| ss.strip }
          nvpStrs.each { |nvpStr|
            name, value = *nvpStr.split(/=/).map { |ss| ss.strip }
            if(name and !name.empty?)
              retVal[name.to_sym] = value
            end
          }
        else # assume 3-col driver with just host in 3rd col. No AVPs.
          retVal[:host] = thirdField.strip
        end
      end
    else # bad record
      raise IndexError, "BAD DBRC RECORD (driver string): The driver string provided is INVALID. It must have a MINIMUM of three (3) colon-delimited fields: TYPE:SUBTYPE:HOST_OR_AVPS. This driver string has #{driverFields.size} fields, and needs to be fixed:\n\n    #{driver.inspect}\n\n"
    end
    return retVal
  end

  # Extract the desired info from the driver string present in the DBRC record.
  # @param [Symbol] The driver info desired, as a Symbol. See {#parseDriver} for some common options.
  # @param [Hash] dbrcRec The DBRC record of interest, as a Hash (like returned by {#getRecordByHost} etc)
  # @return [String, Fixnum, nil] The value of the driver information.
  def driverField( driverInfo, dbrcRec )
    driverFields = parseDriver( dbrcRec )
    return driverFields[driverInfo]
  end

  ###############
  # private     #
  ###############
  def getValue(key, field)
    retVal = nil
    @dbrcRecs = DBRC.load(@dbrc)
    retVal = dbrcRecs[key][field] if(dbrcRecs and !dbrcRecs[key].nil?)
    return retVal
  end

  def isInternal?(key=@key)
    return (getValue(key, :hostType) == :internal) ? true : false
  end

  def isExternal?(key=@key)
    return !isInternal?(key)
  end
end # class DBRC
end ; end # module BRL ; module DB
