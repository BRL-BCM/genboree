#!/usr/bin/env ruby

require 'pp'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'

$VERBOSE = nil

module BRL ; module Genboree
  class GenboreeDBHelper
    # STRUCTS
    DbRec = Struct.new(:dbName, :ftypeid, :dbType)
    # CLASS VARIABLES
    @@dbu = nil
    # CONSTANTS
    ACCESS_LEVELS = "rwo" ;

    # Checks if the user has at least the minimum level of permission in the provided group
    # +userId+ - the userId
    # +groupId+ - the groupId
    # +minLevel+ - the minimum level of permission expressed as the single letter from the
    #              usergroup table ('r', 'w', 'o')
    # +dbu+ - the DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # _returns_ - true or false
    def self.checkUserAllowed(userId, groupId, minLevel, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      userAllowed = false # default is read-only role
      minLevelIdx = ACCESS_LEVELS.index(minLevel)
      unless(userId.nil? or groupId.nil? or minLevelIdx.nil?)
        usergroupAccessRow = dbu.getAccessByUserIdAndGroupId(userId, groupId)
        unless(usergroupAccessRow.nil? or usergroupAccessRow.empty?)
          usergroupAccess = usergroupAccessRow["userGroupAccess"]
          userLevelIdx = ACCESS_LEVELS.index(usergroupAccess)
          unless(userLevelIdx.nil?)
            userAllowed = (userLevelIdx >= minLevelIdx)
          end
        end
      end
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return userAllowed
    end

    # Get list of userDb-specific tracks (ftype rows); this will exclude any
    # tracks from the shared/template database.
    # +noComponents+ - [optional; default true] No Component nor Supercomponent tracks
    # +dbu+ - the DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # _returns_ - Array of DBI::Rows
    def self.selectAllUserSpecificFtypes(refSeqId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      allFtypes = []
      # Get all refseq DB names (userDB & shared/template DB)
      allDBNames = dbu.selectDBNamesByRefSeqID(refSeqId)
      allDBNames.map! { |row| row['databaseName'] } # array of DBI::Rows returned, get actual name String
      # Get the userDB refseq DB name
      userDBName = dbu.selectDBNameByRefSeqID(refSeqId)
      userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
      dbu.setNewDataDb(userDBName)
      # Get all ftype rows from userDB
      allFtypes = dbu.selectAllFtypes(noComponents)
      # Get all ftype rows from non-userDB refseqs
      nonUserDbNames = allDBNames.dup
      nonUserDbNames.delete_if { |xx| xx == userDBName }
      nonUserDbFtypes = []
      nonUserDbNames.each { |nonUserDbName|
        dbu.setNewDataDb(nonUserDbName)
        ftypeRows = dbu.selectAllFtypes(noComponents)
        nonUserDbFtypes += ftypeRows unless(ftypeRows.nil? or ftypeRows.empty?)
      }
      # Remove ftypes from userDB that are in non-userDB
      allFtypes.delete_if { |ftypeRow|
        retVal = false
        tname = "#{ftypeRow['fmethod']}:#{ftypeRow['fsource']}"
        nonUserDbFtypes.each { |nonUserDbFtypeRow|
          otherTName = "#{nonUserDbFtypeRow['fmethod']}:#{nonUserDbFtypeRow['fsource']}"
          if(tname == otherTName)
            retVal = true
            break
          end
        }
        retVal
      }
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return allFtypes
    end

    # Get list of ftype rows from userDb and shared/template DB, which the user has access to.
    # [+refSeqId+] Id of user-specific database to pull track info from
    # [+userId+]   User accessing this information
    # [+dbu+]     The DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # [+returns+] Hash of ftype rows keyed by track name (however, fmethod and fsource replaced by single
    #             "trackName" column). To support subsequent
    #             queries on the track, the 'dbNames' key will have an array of struct objects that
    #             specify each related database (dbRec.dbName) where the track NAME can be found
    #             and the ftypeid (dbRec.ftypeid) within the respective database. The first dbRec struct
    #             will be the user database so it can override content in the template/other databases
    #             Note: (TAC) The first dbRec struct might not be the userDb if the ftype record doesn't exist
    #                   in the userDb yet.
    def self.getAllAccessibleFtypes_fast(refSeqId, userId, noComponents=true, dbu=nil, includePartialEntities=false)
      dbu ||= GenboreeDBHelper.getDbUtil()
      origDataDbName = dbu.dataDbName
      retVal = Hash.new { |hh,trackName| hh[trackName] = { 'dbNames' => [] } }
      # Get all refseq DB names (userDB & shared/template DB), with isUseDb flag
      # - result table rows have columns 'databaseName' and 'isUserDb' (1=true, 0=false)
      allDBs = dbu.selectFlaggedDbNamesByRefSeqId(refSeqId)
      allDBs.each_index { |ii|
        allDBsRow = allDBs[ii]
        # Get current database to process (user or template)
        dbName = allDBsRow['databaseName']
        # Determine the dbType (user or shared)
        isUserDb = allDBsRow['isUserDb']
        dbType = (isUserDb == 1 ? :userDb : :sharedDb)
        # Make this database the active database
        dbu.setNewDataDb(dbName)
        # Get ALL info about accessible ftypes in this database
        # - This was being done with several select-all queries connected through several
        #   method calls that build special Hashes to track the info.
        # - Result table rows will have these columns:
        #   . ftypeid, fmethod, fsource, userId, permissionBits
        accessibleFtypeInfo = dbu.selectAllTrackAccessRecords_fast(noComponents, includePartialEntities)
        if(accessibleFtypeInfo)
          accessibleFtypeInfo.each { |row|
            # First: is this track accessible to the user?
            userIdCol = row['userId']
            if(userIdCol.nil? or (userIdCol == userId and BRL::Genboree::DBUtil.testPermissionBits(row['permissionBits']))) # Either NULL (all can access) or user has explicit access
              rowFtypeId = row['ftypeid']
              trkName = row['trackName']
              # Add entry to allFtypes
              allFtypesRec = retVal[trkName]
              allFtypesRec['ftypeid'] = rowFtypeId
              allFtypesRec['dbNames'] << DbRec.new(dbName, rowFtypeId, dbType)
            end
          }
        end
      }
      dbu.setNewDataDb(origDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return retVal
    end

    # WARNING: bit slower and a LOT more complex (more methods, more queries, more processing lines) than approach above
    # in getAllAccessibleFtypes_fast() version. Use that version if at all possible (will lose fmethod and fsource columns,
    # but gain "trackName" column already built for you).
    #
    # Get list of ftype rows from userDb and shared/template DB, which the user has access to.
    # [+refSeqId+] Id of user-specific database to pull track info from
    # [+userId+]   User accessing this information
    # [+dbu+]     The DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # [+returns+] Hash of ftype rows keyed by track name; to support subsequent
    #             queries on the track, the 'dbNames' key will have an array of struct objects that
    #             specify each related database (dbRec.dbName) where the track NAME can be found
    #             and the ftypeid (dbRec.ftypeid) within the respective database. The first dbRec struct
    #             will be the user database so it can override content in the template/other databases
    #             Note: (TAC) The first dbRec struct might not be the userDb if the ftype record doesn't exist
    #                   in the userDb yet.
    def self.getAllAccessibleFtypes(refSeqId, userId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      allFtypes = {}
      # Get all refseq DB names (userDB & shared/template DB)
      allDBs = dbu.selectDBNamesByRefSeqID(refSeqId)
      # Get the userDB refseq DB name (this has priority over shared/template dbs)
      userDBName = dbu.selectDBNameByRefSeqID(refSeqId)
      userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
      allDBs.sort! { |aa, bb| # make sure -user- database is at first of list
        if(aa['databaseName'] == userDBName)
          retVal = -1
        elsif(bb['databaseName'] == userDBName)
          retVal = 1
        else
          retVal = aa['databaseName'] <=> bb['databaseName']
        end
      }
      allDBs.each_index { |ii|
        uploadRow = allDBs[ii]
        dbName = uploadRow['databaseName']
        refseqRows = dbu.selectRefseqByDatabaseName(dbName)
        dbRefSeqId = refseqRows.first['refSeqId']
        refseqRows.clear()
        dbu.setNewDataDb(dbName)
        accessibleFtypeIds = GenboreeDBHelper.getAccessibleTrackIds(dbRefSeqId, userId, true, dbu)
        ftypeRows = dbu.selectAllFtypes()
        if(!ftypeRows.nil? and !ftypeRows.empty?)
          ftypeRows.each { |row|
            rowFtypeId = row['ftypeid']
            if(accessibleFtypeIds.key?(rowFtypeId)) # this track must be accessible by the user
              tname = "#{row['fmethod']}:#{row['fsource']}"
              # Flag the db type, so we can identify which is which
              dbType = (ii == 0) ? :userDb : :sharedDb
              dbRec = DbRec.new(dbName, rowFtypeId, dbType)
              unless(allFtypes.key?(tname))
                rowHash = row.to_h   # Cannot add columns to DBI::Row objects, so convert to Hash and use that
                rowHash['dbNames'] = [ dbRec ]
                allFtypes[tname] = rowHash
              else # already have this track in there, just append another dbName where it can be found
                allFtypes[tname]['dbNames'] << dbRec
              end
            end
          }
        end
      }
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return allFtypes
    end

    # Get list of ftype rows from userDb and shared/template DB, independent of a particular user
    # [+refSeqId+] Id of user-specific database to pull track info from
    # [+dbu+]     The DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # [+returns+] As for getAllAccessibleFtypes(), returns hash of ftype rows keyed by track name; to support subsequent
    #             queries on the track, the 'dbNames' key will have an array of struct objects that
    #             specify each related database (dbRec.dbName) where the track NAME can be found
    #             and the ftypeid (dbRec.ftypeid) within the respective database. The first dbRec struct
    #             will be the user database so it can override content in the template/other databases
    #             Note: (TAC) The first dbRec struct might not be the userDb if the ftype record doesn't exist
    #                   in the userDb yet.
    def self.getAllFtypes(refSeqId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      allFtypes = {}
      # Get all refseq DB names (userDB & shared/template DB)
      allDBs = dbu.selectDBNamesByRefSeqID(refSeqId)
      # Get the userDB refseq DB name (this has priority over shared/template dbs)
      userDBName = dbu.selectDBNameByRefSeqID(refSeqId)
      userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
      allDBs.sort! { |aa, bb| # make sure -user- database is at first of list
        if(aa['databaseName'] == userDBName)
          retVal = -1
        elsif(bb['databaseName'] == userDBName)
          retVal = 1
        else
          retVal = aa['databaseName'] <=> bb['databaseName']
        end
      }
      allDBs.each { |uploadRow|
        dbName = uploadRow['databaseName']
        refseqRows = dbu.selectRefseqByDatabaseName(dbName)
        dbRefSeqId = refseqRows.first['refSeqId']
        refseqRows.clear()
        dbu.setNewDataDb(dbName)
        ftypeRows = dbu.selectAllFtypes()
        ftypeRows.each { |row|
          tname = "#{row['fmethod']}:#{row['fsource']}"
          # Flag the db type, so we can identify which is which
          dbType = (dbName == userDBName) ? :userDb : :sharedDb
          dbRec = DbRec.new(dbName, row['ftypeid'], dbType)
          unless(allFtypes.key?(tname))
            rowHash = row.to_h   # Cannot add columns to DBI::Row objects, so convert to Hash and use that (if row is a Hash [Mysql2], then brl/util/util ensures Hash#to_h works)
            rowHash['dbNames'] = [ dbRec ]
            allFtypes[tname] = rowHash
          else # already have this track in there, just append another dbName where it can be found
            allFtypes[tname]['dbNames'] << dbRec
          end
        }
        ftypeRows.clear()
      }
      allDBs.clear()
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return allFtypes
    end

    # Gets all the track access info for a given database, organized in a hierarchical
    # data structure useful for quick querying and manipulation.
    # Recall that if a track has no users in its userId list, then ALL users can access the track.
    # +refSeqId+ - the refSeqId of the user database to get access info from
    # +noComponents+ - [optional; default true] No Component nor Supercomponent tracks
    # +dbu+ - the DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # _returns_ - {ftypeid}=>{ :name=>"type:subtype", :userIds=>{userId}}
    def self.getAllTrackAccessInfo(refSeqId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      ftypeAccess = Hash.new {|hh,kk| hh[kk] = { :name => nil, :userIds => {} } }
      ftypes = {} # ftypeId => "type:subtype"
      # Get the userDB refseq DB name
      userDBName = dbu.selectDBNameByRefSeqID(refSeqId)
      userDBName = userDBName.first['databaseName'] # array of DBI::Rows returned, get actual name String
      dbu.setNewDataDb(userDBName)
      # Get all ftype rows from userDB & store in hash
      allFtypeRows = dbu.selectAllFtypes(noComponents)
      if(!allFtypeRows.nil? and !allFtypeRows.empty?)
        allFtypeRows.each { |row|
          trackName = "#{row['fmethod']}:#{row['fsource']}"
          ftypes[row['ftypeid']] = trackName
          # Add all tracks that has no ftypeAccess records...later some may be restricted as we consider ftypeAccess records
          ftypeAccess[row['ftypeid']][:name] = trackName
          ftypeAccess[row['ftypeid']][:userIds] = {}
        }
        allFtypeRows.clear()
      end
      # Get all ftypeAccess rows from userDB & store in data structure
      allFtypeAccessRows = dbu.selectAllTrackAccessRecords()
      allFtypeAccessRows.each { |row|
        ftypeAccess[row['ftypeid']][:userIds][row['userId']] = row['permissionBits']
      }
      allFtypeAccessRows.clear()
      ftypes.clear()
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return ftypeAccess
    end

    # Gets a simple hash of all the track NAMES the userId has access to within
    # database id refSeqId.
    # +refSeqId+ - the refSeqId of the user database to get access info from
    # +userId+ - the userId of the user for whom we want to get the accessible track list
    # +dbu+ - the DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # _returns_ - {trackName => true} # for each trackName the userId has access to
    def self.getAccessibleTrackNames(refSeqId, userId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      accessibleTracks = {}
      # Get ftypeAccess records
      ftypeAccess = GenboreeDBHelper.getAllTrackAccessInfo(refSeqId, noComponents, dbu)
      ftypeAccess.each_key { |ftypeId|
        trackName = ftypeAccess[ftypeId][:name]
        if( ftypeAccess[ftypeId][:userIds].empty? or
            (ftypeAccess[ftypeId][:userIds].key?(userId) and
            BRL::Genboree::DBUtil.testPermissionBits(ftypeAccess[ftypeId][:userIds][userId]))
          ) # then either everyone has access or this specific user does
          accessibleTracks[trackName] = true
        end
      }
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return accessibleTracks
    end

    # Gets a simple hash of all the track FTYPEIDS the userId has access to within
    # database id refSeqId.
    # +refSeqId+ - the refSeqId of the user database to get access info from
    # +userId+ - the userId of the user for whom we want to get the accessible track list
    #          - if negative, then some kind of admin/superuser access and all tracks are accessible
    # +dbu+ - the DbUtil instance to use ; if nil, then will try to (re)use the one in @@dbu
    # _returns_ - {ftypeId => true} # for each trackName the userId has access to
    def self.getAccessibleTrackIds(refSeqId, userId, noComponents=true, dbu=nil)
      dbu ||= GenboreeDBHelper.getDbUtil()
      oldDataDbName = dbu.dataDbName
      accessibleTracks = {}
      # Get ftypeAccess records
      ftypeAccess = GenboreeDBHelper.getAllTrackAccessInfo(refSeqId, noComponents, dbu)
      ftypeAccess.each_key { |ftypeId|
        if( userId.to_i < 0 or
            ftypeAccess[ftypeId][:userIds].empty? or
            ( ftypeAccess[ftypeId][:userIds].key?(userId) and
              BRL::Genboree::DBUtil.testPermissionBits(ftypeAccess[ftypeId][:userIds][userId])
            )
          ) # then either everyone has access or this specific user does or we are the super user
          accessibleTracks[ftypeId] = true
        end
      }
      ftypeAccess.clear()
      dbu.setNewDataDb(oldDataDbName) unless(@@dbu.equal?(dbu))   # restore original data database name unless we've been using @@dbu
      return accessibleTracks
    end

    # --------------------------------------------------------------------------
    # HELPERS
    # --------------------------------------------------------------------------
    # Makes a DbUtil instance for use by the class methods here, unless already created.
    # Otherwise just returns the existing DbUtil. Will reuse, unless caller
    # provides their own dbu to the class method.
    # _returns_ - DbUtil instance.
    def self.getDbUtil()
      if(@@dbu.nil?)
        # Get Genboree configuration
        genbConfig = GenboreeConfig.load()
        # Make a DbUtil instance to use
        @@dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil)
      end
      return @@dbu
    end

    def self.logError(msg, err, *vars)
      return BRL::Genboree::GenboreeUtil.logError(msg, err, *vars)
    end
  end # END: class GenboreeDBHelper
end ; end # module BRL ; module Genboree
