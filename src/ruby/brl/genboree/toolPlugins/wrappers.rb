# Matthew Linnell
# January 30th, 2006
#-------------------------------------------------------------------------------
# Outside wrapper for new tools plugins, provides user/group context
#-------------------------------------------------------------------------------
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/util/emailer'
require 'brl/genboree/toolPlugins/util/util'
include BRL::Genboree
include BRL::Util
include BRL::Genboree::ToolPlugins

require 'pp'

module BRL ; module Genboree ; module ToolPlugins

  # Represents a "results" file passed back to the resultsWrapper.rhtml page
  class ResultFile
    attr_accessor :fullPath, :extension, :mtime

    def initialize(fullPath, extension)
      @fullPath = fullPath.dup.untaint
      @extension = extension.dup.untaint
      @mtime = File.mtime(@fullPath).untaint
    end

    def fileName()
      @fullPath =~ /\/?([^\/]+\.#{@extension})$/
      return $1
    end

    def baseFileName()
      @fullPath =~ /\/?([^\/]+)\.#{@extension}$/
      return $1
    end

    def to_s()
      return mtime.strftime("%Y-%m-%d %H:%M") + "&nbsp;&nbsp;-&nbsp;&nbsp;#{@fileName}"
    end
  end

  # OutWrapper used in outer most rhtml wrapper
  class OuterWrapper
    #-----------------------------------------------------------------------
    # * *Function*: Class method.  Returns array of DBI::Rows containing genboree groups
    #
    # * *Usage*   : <tt> OuterWrapper.getGroups( 1 ) </tt>
    # * *Args*    :
    #   - +user_id+ -> The integer value for the userId
    # * *Returns* :
    #   - +Array+ -> An array of DBI::Rows containing genboree groups
    # * *Throws* :
    #   - +none+
    #-----------------------------------------------------------------------
    def self.getGroups( user_id )
      databases = nil
      # Get group/database from user context
      begin
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        groups = @@dbu.getGroupNamesByUserId( user_id ) # internal DB name
      rescue => @err
        $stderr.puts '-'*50
        $stderr.puts @err
        $stderr.puts @err.backtrace
        $stderr.puts '-'*50
      end
      return groups.sort { |aa, bb| aa[1].downcase <=> bb[1].downcase }
    end

    #-----------------------------------------------------------------------
    # * *Function*: Class method.  Returns list of databases available to a given user & group
    #
    # * *Usage*   : <tt> OuterWrapper.getDatabases( 1, 32 ) </tt>
    # * *Args*    :
    #   - +user_id+ -> The integer value for the userId
    #   - +groupId+ -> The integer value for the groupId
    # * *Returns* :
    #   - +Array+ -> Returns an Array of DBI::Rows containing databases
    # * *Throws* :
    #   - +none+
    #-----------------------------------------------------------------------
    def self.getDatabases( userId, groupId )
      databases = nil
      # Get group/database from user context
      begin
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        databases = @@dbu.selectDBNamesByGroupAndUserId( userId, groupId ) # internal DB name
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return databases.sort { |aa, bb| aa[2].downcase <=> bb[2].downcase }
    end

    def self.getCurrUserDBName( refSeqId )
      userDBName = nil
      # Get group/database from user context
      begin
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        refseqRows = @@dbu.selectRefseqById( refSeqId )
        userDBName = refseqRows.first['refseqName']
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return userDBName
    end

    def self.getCurrGroupName( groupId )
      groupName = nil
      # Get group/database from user context
      begin
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        groupRows = @@dbu.selectGroupById( groupId )
        groupName = groupRows.first['groupName']
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return groupName
    end

    #-----------------------------------------------------------------------
    # * *Function*: Class method.  Returns list of existing experiment names given a groupId
    #
    # * *Usage*   : <tt> OuterWrapper.getExperimentNames( 32 ) </tt>
    # * *Args*    :
    #   - +groupId+ -> The integer value of the groupId for the group of interest
    # * *Returns* :
    #   - +Array+ -> An Array of Strings representing experiment names
    # * *Throws* :
    #   - +none+
    #-----------------------------------------------------------------------
    def self.getExperimentNames( groupId, refSeqId, tool )
      list = []
      uList = {}
      unless( groupId.nil? or refSeqId.nil? or tool.nil? or
              refSeqId.to_s.empty? or tool.empty?)
        resultsDir = "#{BRL::Genboree::ToolPlugins::RESULTS_PATH}/#{groupId}/#{refSeqId}/#{tool}/*"
        list = Dir[resultsDir.dup.untaint]
        list.each { |xx|
          xx =~ /\/([^\/\.]+)[^\/]*$/
          uList[$1] = nil
        }
      end
      return uList.keys
    end
  end

  # InnerWrapper is used as the inner most content wrapper.  This is used, for example, within the input.rhtml files.
  class InnerWrapper
    #-----------------------------------------------------------------------
    # * *Function*: Class method.  Returns an array of tracks (ftypes) available in a given refSeqId
    #
    # * *Usage*   : <tt> InnerWrapper.getTracks( 491 ) </tt>
    # * *Args*    :
    #   - +refSeqId+ -> The integer value for the refSeqId of interest
    #   - +userId+ -> Id of the user we want the track list for; with track-level access, not all users have access to all tracks
    # * *Returns* :
    #   - +Array+ -> An Array of DBI::Rows representing all available ftypes
    # * *Throws* :
    #   - +none+
    #-----------------------------------------------------------------------
    def self.getTracks( refSeqId, userId )
      tracks = {}
      # Get database specific information
      begin
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        # Get all anno DBs having tracks:
        dbNames = @@dbu.selectDBNamesByRefSeqID(refSeqId)
        # For each anno DB, get the track records, keyed by the track name
        # NOTE: the ftypeid for the track records (col 0) will be MEANINGLESS because of shared vs local anno DBs!!
        #       but hopefully, we don't care, we have the track names, which is what we want..
        dbNames.each { |dbNameRow|
          @@dbu.setNewDataDb( dbNameRow['databaseName'] )
          # Get list of tracks that this user can access in this database
          #accessibleTracks = BRL::Genboree::GenboreeDBHelper.getAccessibleTrackNames(refSeqId, userId, true, @@dbu)
          accessibleTracks = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(refSeqId, userId, true, @@dbu)
          tracks = accessibleTracks
        }
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return tracks
    end

    # This will no longer get attributes from tracks the user doesn't have access to
    def self.getAttributeMap(refSeqId, userId)
      t0 = Time.now
      attrMap = Hash.new {|hh,kk| hh[kk] = [] }
      begin
        # Get databases
        @@dbu = BRL::Genboree::ToolPlugins.connect()
        dbNames = @@dbu.selectDBNamesByRefSeqID(refSeqId)
        # Go through each database associated with refSeqId (in general: user db and a template db) and collect accessible track + attribute info
        dbNames.each { |dbNameRow|
          # get identities for the current database and make them active
          dbName = dbNameRow['databaseName']
          currDbRefseqRows = @@dbu.selectRefseqByDatabaseName(dbName)
          dbRefSeqId = currDbRefseqRows.first['refSeqId']
          @@dbu.setNewDataDb(dbName)
          # Get ftypes to attributes
          t1 = Time.now
          # Get ftype2attribute rows for current database
          ftypesWithAttributes = @@dbu.selectAttributesGroupedByTrack()
          t2 = Time.now
          # Get list of tracks that this user is allowed to access in this database
          accessibleTrackIds = BRL::Genboree::GenboreeDBHelper.getAccessibleTrackIds(dbRefSeqId, userId, true, @@dbu)
          # Get the ftypeids and the attNameIds, except for tracks this user can't access
          # - save the ftypeids and the attribute ids
          ftypeids = {}
          attNameIds = {}
          ftypesWithAttributes.each { |row|
            ftypeid = row['ftypeid']
            # Only keep names tracks and attrs the user has access to
            if(accessibleTrackIds.key?(ftypeid) and accessibleTrackIds[ftypeid])
              ftypeids[ftypeid] = nil
              attNameIds[row['attNameId']] = nil
            end
          }
          # Now get matching names for saved ftypeids
          t1 = Time.now
          ftypes = @@dbu.selectFtypesByIds(ftypeids.keys)
          t2 = Time.now
          # Now get attribute names for saved attribute ids
          attributes = @@dbu.selectAttributesByIds(attNameIds.keys)
          t1 = Time.now
          ftypeid2trackName = {} # cache
          attrId2attrName = {} # cache
          # Now loop over our association of ftypeids to their attribute ids and save accessible track *names* and the attribute *names* in those tracks
          ftypesWithAttributes.each { |row|
            ftypeid = row["ftypeid"]
            # Only add to track=>attrs map if user has access to track
            if(accessibleTrackIds.key?(ftypeid) and accessibleTrackIds[ftypeid])
              attNameId = row["attNameId"]
              trackName = (ftypeid2trackName[ftypeid] ||= extractTrackName(ftypeid, ftypes, ftypeid2trackName))
              attrName = (attrId2attrName[attNameId] ||= extractAttrName(attNameId, attributes, attrId2attrName))
              attrMap[trackName] << attrName
            end
          }
        }
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return attrMap
    end

    def self.extractTrackName(ftypeid, ftypes, cache)
      retVal = ''
      ftypes.each { |row|
        next unless(row["ftypeid"] == ftypeid)
        retVal = cache[ftypeid] = "#{row['fmethod']}:#{row['fsource']}"
        break
      }
      return retVal
    end

    def self.extractAttrName(attrNameId, attrs, cache)
      retVal = ''
      attrs.each { |row|
        next unless(row["attNameId"] == attrNameId)
        retVal = cache[attrNameId] = row["name"]
        break
      }
      return retVal
    end

    #-----------------------------------------------------------------------
    # * *Function*: Class method. Returns a list of filenames with absolute path to data for a given group.
    #
    # * *Usage*   : <tt> InnerWrapper.getDataByExtension( 23, "winnow_model" ) </tt>
    # * *Args*    :
    #   - +groupId+ -> The integer value for the groupId of interest
    #   - +fileExtension+ -> The file extension (the last string value after the last '.') of the data of interest.  For example, the winnow algorithm saves the trained model as experimentname.winnow_model
    #   - +dataLoc+ -> Optional.  The root path to the data repository
    # * *Returns* :
    #   - +Array+ -> An Array of file names with full paths to data for the given group
    # * *Throws* :
    #   - +none+
    #-----------------------------------------------------------------------
    # Looks up user data based on groupId and the expected fileExtension
    # For example, (mlinnell_group, winnow model) => (498, "winnow_model")
    def self.getDataByExtension( filePath, fileExtension )
      tmp = fileExtension.gsub(/\.\./, "") # Prevent directory path injection
      resultFiles = []
      begin
        fileList = Dir[ "#{filePath}/*.#{fileExtension}".dup.untaint ]
        fileList.each { |fileName|
          resultFiles << ResultFile.new(fileName, fileExtension)
        }
      rescue => @err
        $stderr.puts @err
        $stderr.puts @err.backtrace
      end
      return resultFiles
    end

    def self.getExpsWithResults(groupId, refSeqId, tool)
      expsWithResults = {}
      return expsWithResults if(	groupId.nil? or groupId == 0 or
                                  refSeqId.nil? or refSeqId == 0 or
                                  tool.nil? or tool.empty? or !BRL::Genboree::ToolPlugins::Tools.list().key?(tool.to_sym))
      actualResultsPath = "#{RESULTS_PATH}/#{groupId}/#{refSeqId}/#{tool}"
      toolClass = BRL::Genboree::ToolPlugins::Tools.list()[tool.to_sym]
      extList = BRL::Genboree::ToolPlugins::Util.getAllResultExtensions(toolClass)
      extList.each_key { |ext|
        resultFiles = BRL::Genboree::ToolPlugins::InnerWrapper.getDataByExtension( actualResultsPath, ext )
        resultFiles.each { |resultFile| # Keeps one representative file per Job
          expsWithResults[resultFile.baseFileName] = resultFile if( !expsWithResults.key?(resultFile.baseFileName) or (expsWithResults[resultFile.baseFileName].mtime < resultFile.mtime))
        }
      }
      return expsWithResults
    end
  end
end ; end ; end # BRL ; Genboree ; ToolPlugins
