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
  attr_accessor :max_reconn, :timeout, :interval, :host
  attr_accessor :hostType # Internal or External ?
  attr_accessor :dbrcRecs # loaded hash-of-hashes from dbrc file
  alias_method :db, :key
  alias_method :db=, :key=

  # Because class-level variables are shared across ALL threads, this method
  # had to be written VERY carefully, assuming that at ANY point a different thread could interupt
  # and leave things in an inconsistent state. Therefore there is a bunch of testing to see if things
  # are really there and really populated with non-default values. These tests are fast.
  def self.load(dbrcFile=nil, domainAliasFile=ENV['DOMAIN_ALIAS_FILE'])
    dbrcFile = (ENV['DBRC_FILE'] || ENV['DB_ACCESS_FILE'] || '~/.dbrc') unless(dbrcFile)
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
            rec[:user] = fields[1]
            rec[:password]   = fields[2]
            rec[:driver]     = fields[3]
            driverFields     = rec[:driver].split(':')
            rec[:host]       = driverFields.last
            rec[:timeout]    = fields[4]
            rec[:max_reconn] = fields[5]
            rec[:interval]   = fields[6]
            rec[:dsn] = rec[:driver] + ":" + rec[:key]
            retVal[rec[:key]] = rec
            # Try to determine database name
            databaseDriverField = driverFields[2]
            if(databaseDriverField)
              if(databaseDriverField =~ /database=([^;]+)/) # then database=XX;host=YY or database=XX;socket=YY
                rec[:dbName] = $1
              elsif(databaseDriverField !~ /socket=/) # then probably non AVP style and just a database name
                rec[:dbName] = databaseDriverField.strip
              else # can't find the database name easily
                rec[:dbName] = nil
              end
            end
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
        @user       = dbrcRec[:user]
        @password   = dbrcRec[:password]
        @driver     = dbrcRec[:driver]
        @host       = dbrcRec[:host]
        @timeout    = dbrcRec[:timeout]
        @max_reconn = dbrcRec[:max_reconn]
        @interval   = dbrcRec[:interval]
        @dsn        = dbrcRec[:dsn]
        @dbName     = dbrcRec[:dbName]
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
          retVal = rec
        end
      elsif(rec)
        retVal = rec
      else
        retVal = nil
      end
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
