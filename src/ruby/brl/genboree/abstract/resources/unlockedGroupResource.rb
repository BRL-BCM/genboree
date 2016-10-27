#!/usr/bin/env ruby

require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/rest/resources/database'
require 'brl/genboree/rest/resources/group'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/entityList'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract

module Resources

  # An unlocked group resource is a data resource that may be exposed without Genboree authentication
  # most commonly used for tracks or databases
  #
  # This class manages the data stored in the tables unlockedGroupResources and unlockedGroupResourceParents
  #
  # Resource Types:
  #  - database => refers to table 'refseq' and the primary key is 'refseq.refSeqId'
  #  - track => refers to table 'ftype' and the primary key is 'ftype.ftypeid', also requires parent refSeqId
  #  - project => refers to table 'projects' and the primary key is 'projects.id'
  #
  # Unlocked data is hierarchcal, meaning that if a database is unlocked, any data element within it, like a track, is also unlocked.
  #
  # Therefore the following cases are possible
  #  - an unlocked database would just have a record for the database
  #  - a track would have a track record in unlockedGroupResources and database record in unlockedGroupResourceParents
  class UnlockedGroupResource

    # ------------------------------------------------------------------
    # KEY METHODS. SOME NEW.
    # - The old methods require too much code be implemented to support
    #   unlocking of different resource types. And they are dependent on there
    #   being a MySQL table record with an id for the resource...which (a) is a huge
    #   code cost and pain, and (b) may not be the case (like collections in KBs!)
    # - Rather, by employing these new ones, any entity under a group (for security) can be
    #   unlocked, even ones we haven't added yet! Or ones that have no MySQL tables like collections in KBs!
    # ------------------------------------------------------------------

    # Checks if there is any unlocked resource having @key@ which would give access to the resource
    #   indicated by @rsrcPath@. This includes not only @rsrcPath@ itself, but any of its parent resources
    #   if any of them are unlocked and their key is @key@. Unlocking is hierarchical.
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [String, URI] rsrcPath A string or {URI} object containing the path to the resource
    #   you want to know if access is allowed via @key@
    # @param [String] key The unlock key; can be @nil@ if attempting access to @rsrcPath@ is publicly unlocked
    #   (i.e. its key is "automatically discoverable"). If present, presumably the key that was provided with the resource.
    #   Either it is the key for that rsrcPath specifically or for one of the parents of rsrcPath, OR that @rsrcPath@ is
    #   publicly unlocked, OR a parent of that @rsrcPath@ is publicly unlocked.
    def self.hasAccessViaKey(dbu, rsrcPath, key=nil)
      retVal = false
      # Ensure we're working off of just the path part.
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      # First try via key, if provided
      if(key)
        resourceRows = dbu.selectUnlockedResourcesAboveRsrcWithKey(rsrcPath, key)
      else
        resourceRows = nil
      end
      # If haven't got access via key, try via publicly accessible key
      unless(resourceRows and !resourceRows.empty?)
        resourceRows = dbu.selectPubliclyUnlockedResourcesAboveRsrc(rsrcPath)
      end
      retVal = (resourceRows and !resourceRows.empty?)
      return retVal
    end

    # Get any publicly accessible key ("automatically discoverable") key which grants
    #   access to @rsrcPath@, if any. If there is no key for @rsrcPath@ itself, then
    #   any parent key will do--this method will attempt to give the top-most parent's key
    #   (which should be the shortest resource uri)
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [String, URI] rsrcPath A string or {URI} object containing the path to the resource
    #   you want to know if access is allowed via @key@
    # @return [String, nil] A public key granting access or @nil@ if there isn't one.
    def self.getAnyPublicKey(dbu, rsrcPath)
      retVal = nil
      # Ensure we're working off of just the path part.
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      resourceRows = dbu.selectPubliclyUnlockedResourcesAboveRsrc(rsrcPath)
      if(resourceRows and !resourceRows.empty?)
        # First, try our rsrcPath explicitly
        resourceRow = resourceRows.find { |row| row["resourceUri"] == rsrcPath }
        if(resourceRow)
          retVal = resourceRow["unlockKey"]
        else # no exact match, but maybe some parent?
          # Doesn't really matter which public-unlocked parent grants access
          # - heuristic: try for shortest (should be top-most) parent?
          resourceRow = resourceRows.sort { |aa, bb|
            xx, yy = aa["resourceUri"], bb["resourceUri"]
            cmpVal = (xx.size <=> yy.size)
            cmpVal = (xx <=> yy) if((cmpVal == 0))
            cmpVal
          }.first
          retVal = resourceRow["unlockKey"]
        end
      end
      return retVal
    end

    # Get info for all unlocked resources UNDER a given parent resource, including
    #   the parent itself.
    # @note If @rsrcPath@ is the path to a group, this is the same as calling {self.getUnlockedResourcesForGroupId}
    #   with that group's id.
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [String, URI] rsrcPath A string or {URI} object containing the path to the parent resource
    #   for which you want all unlocked child resources on record.
    # @return [Array<Hash>] A list of info records (as {Hash}es)--one per unlocked resource record--containing info in the
    #   keys: @'type'@, @'key'@, @'uri'@, @'public'@, @'id'@
    def self.getUnlockedResourcesUnderRsrc(dbu, rsrcPath)
      resourceRows = dbu.selectUnlockedResourcesUnderRsrc(rsrcPath)
      resources = [] # Array of all resources
      resourceHash = {}
      resourceRows.each { |row|
        resourceHash = {}
        resourceHash['type']    = row['resourceType']
        resourceHash['id']      = row['resource_id']
        resourceHash['key']     = row['unlockKey']
        resourceHash['public']  = row['public']
        resourceHash['uri']     = row['resourceUri']
        resources << resourceHash
      }
      return resources
    end


    # Get info  for all unlocked resources ABOVE a given child resource. This includes the resource itself.
    #   Because unlocking is hierarchical and unlocking a parent unlockes everything below it.
    #   So these records are all ones that can possibly give access to the resource at @rsrcPath@, IF
    #   the matching key were provided.
    # @see hasAccessViaKey For a method which will consider all records involving parents IF the given
    #   key matches the parent's key.
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [String, URI] rsrcPath The path to the resource above which you want to find all
    #   unlocked resources. Regardless of whether it is a full URL string, a string path, or a URI object,
    #   just the PATH portion will be used as part of a prefix search.
    # @return [Array<Hash>] A list of info records (as {Hash}es)--one per unlocked resource record--containing info in the
    #   keys: @'type'@, @'key'@, @'uri'@, @'public'@, @'id'@
    def self.getUnlockedResourcesAboveRsrc(dbu, rsrcPath)
      resourceRows = dbu.selectUnlockedResourcesAboveRsrc(rsrcPath)
      resources = [] # Array of all resources
      resourceHash = {}
      resourceRows.each { |row|
        resourceHash = {}
        resourceHash['type']    = row['resourceType']
        resourceHash['id']      = row['resource_id']
        resourceHash['key']     = row['unlockKey']
        resourceHash['public']  = row['public']
        resourceHash['uri']     = row['resourceUri']
        resources << resourceHash
      }
      return resources
    end

    # Get info for all unlocked resources UNDER a given group using the group id.
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [Fixnum] groupId The id of the group to get the unlocked resources for.
    # @return [Array<Hash>] A list of info records (as {Hash}es)--one per unlocked resource record--containing info in the
    #   keys: @'type'@, @'key'@, @'uri'@, @'public'@, @'id'@. Will also return some info in @'parents'@ if present. Sorry.
    def self.getUnlockedResourcesForGroupId(dbu, groupId)
      resourceRows = dbu.selectUnlockedResources(groupId)
      resources = [] # Array of all resources
      resourceHash = {}
      resourceRows.each { |row|
        resourceHash = {}
        resourceHash['type'] = row['resourceType']
        resourceHash['id'] =  row['resource_id']
        resourceHash['key'] = row['unlockKey']
        resourceHash['public'] = row['public']
        resourceHash['uri'] = row['resourceUri']
        parentResources = dbu.selectParentResourcesByUnlockId(row['id'])
        if(!parentResources.nil? and !parentResources.empty?)
          resourceHash['parents'] = []
          parentResource = {}
          parentResources.each { |parentRow|
            parentResource['type'] = parentRow['resourceType']
            parentResource['id'] = parentRow['resource_id']
            resourceHash['parents'] << parentResource
          }
        end
        resources << resourceHash
      }
      return resources
    end

    # Unlock a resource within a group (including a group itself).
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [Fixnum] groupId The id of the group to get the unlocked resources for.
    # @param [String] rsrcType The standard resource type for the resource mentioned in @rsrcPath@
    # @param [String,URI] rsrcPath The resource path to unlock. Only the path portion will be used.
    # @param [Boolean] isPublic Whether or not to make the key "automatically discoverable" (i.e. a "public key").
    # @param [Boolean] regenKey Whether or not force regeneration of any existing key for this
    #   resource. If false (default), this method does nothing and returns the existing key. If true,
    #   a new key is generated for the resource.
    # @param [Fixnum] rsrcId Obsolete. Don't use. Backward compatibility only. Sets the @resourceID@
    #   column in the table. BAD APPROACH.
    # @return [String] The unlock key for the resource.
    def self.unlockResource(dbu, groupId, rsrcType, rsrcPath, isPublic=false, regenKey=false, rsrcId=nil)
      unlockKey = nil
      # Looks like we have a real groupId and something usable for rsrcPath?
      if(groupId.to_i > 0 and (rsrcPath.is_a?(URI) or !rsrcPath.empty?))
        # Ensure we're working off of just the path part.
        if(rsrcPath.is_a?(String))
          uri = URI.parse(rsrcPath)
          rsrcPath = uri.path
        else # must be a URI object
          rsrcPath = rsrcPath.path
        end
        # Is there an unlock key already in place for rsrcPath? (by exact match)
        rows = dbu.selectUnlockedResourcesByPath(rsrcPath)
        if(rows and !rows.empty?) # then yes, there is a key already
          unless(regenKey)
            # Keep existing key.
            row = rows.first
            unlockKey = row['unlockKey']
            # Ensure public aspect gets updated in this case (may stay same, may not; set and forget)
            dbu.setGroupResourcePublicFlagById(row['id'], isPublic)
          else
            # Remove existing record if asked to regenerate the key
            # - we could do an update as well
            # - but this way we ensure we clean out any duplicates that snuck in
            numDeleted = dbu.deleteUnlockedResourceByPath(rsrcPath)
            if(numDeleted != rows.size)
              raise "ERROR: could not delete existing unlock record for #{rsrcPath.inspect} even though there are #{rows.size} records for this URI and regenKey = #{regenKey.inspect}"
            end
            unlockKey = nil
          end
        end
        # If have key, we're done (was pre-existing) else generate
        unless(unlockKey)
          # Generate a key
          unlockKey = rsrcPath.to_s.generateUniqueString().xorDigest(8)
          # Insert record
          numInserted = dbu.insertUnlockedGroupResourceByPath(groupId, rsrcType, unlockKey, rsrcPath, isPublic, rsrcId)
          if(numInserted != 1)
            raise "ERROR: could not insert new unlocked group resource record for #{rsrcPath.inspect} of type #{rsrcType.inspect}."
          end
        end
      else
        raise ArgumentError, "Bad group id argument #{groupId.inspect} or resource path (#{rsrcPath.inspect}). Cannot unlock."
      end
      return unlockKey
    end

    # Re-lock a resource by deleting the record for it, by exact match on its @rsrcPath@.
    #   This does NOT remove all possible keys that may give access to the resource. For example,
    #   If a PARENT resource is unlocked, it will continue to give access to any resource under it vai
    #   its unlock key. (see {self.recursiveLockGroup)
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [String,URI] rsrcPath The resource path to unlock. Only the path portion will be used.
    # @return [Boolean] Indicating whether locking was successful or not.
    def self.lockResource(dbu, rsrcPath)
      # Ensure we're working off of just the path part.
      if(rsrcPath.is_a?(String))
        uri = URI.parse(rsrcPath)
        rsrcPath = uri.path
      else # must be a URI object
        rsrcPath = rsrcPath.path
      end
      numDeleted = dbu.deleteUnlockedResourceByPath(rsrcPath)
      if(numDeleted >= 1)
        retVal = true
      else
        retVal = false
      end
      return retVal
    end

    # Re-locks ALL resources within a group, including the group itself. i.e. removes all
    #   records for resources within that group.
    # @param [BRL::Genboree::DbUtil] dbu Connected {DbUtil} object ready to query main Genboree database.
    # @param [Fixnum] groupId The id of the group to recursively re-lock
    # @return [Fixnum] The number of records removed (relocked)
    def self.recursiveLockGroup(dbu, groupId)
      numDeleted = dbu.deleteUnlockedGroupResourcesByGroupId(groupId)
      return numDeleted
    end


    # ------------------------------------------------------------------
    # OLD METHODS.
    # - Avoid.
    # - Especially if involves resourceId and/or the parents table. Not needed. Bad.
    # ------------------------------------------------------------------

    # This method is where the unlockedGroupResources.unlockKey is created
    # It creates a random string 8 characters long containing 0-9a-z
    # [+returns+] key
    def self.generateKey(str=nil)
      key = ''
      if(str.is_a?(String))
        key = str.generateUniqueString().xorDigest(8)
      else # ~random key ; hopefully unique
        8.times { key += rand(36).to_s(36) }
      end
      return key
    end

    def self.getIdForGroup(dbu, groupName)
      groupRows = dbu.selectGroupByName(groupName)
      groupId = groupRows.first['groupId'] if(!groupRows.nil? and !groupRows.empty?)
      return groupId
    end

    def self.getIdsForDatabase(dbu, groupName, databaseName)
      groupId = self.getIdForGroup(dbu, groupName)
      refSeqRows = dbu.selectRefseqByNameAndGroupId(databaseName, groupId)
      refSeqId = refSeqRows.first['refSeqId'] if(!refSeqRows.nil? and !refSeqRows.empty?)
      return [groupId, refSeqId]
    end

    def self.getIdsForTrack(dbu, groupName, databaseName, trackName)
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      # If the track is from a shared db, the ftype record may not exist yet, best to use the Track object to manage this
      fmethod, fsource = trackName.split(':')
      trackObj = BRL::Genboree::Abstract::Resources::Track.new(dbu, refSeqId, fmethod, fsource)
      ftypeId = trackObj.getLocalFtypeId()
      return [groupId, refSeqId, ftypeId]
    end

    def self.getIdsForDbChildRsrcs(dbu, groupName, databaseName, rsrcName, rsrcType)
      rsrcId = nil
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      if(rsrcType == 'track') # Call the older non-generic method
        groupId, refSeqId, rsrcId = self.getIdsForTrack(dbu, groupName, databaseName, rsrcName)
      else
        # Connect to the database of interest to get the rsrc id
        refSeqRecs = dbu.selectRefseqByNameAndGroupId(databaseName, groupId)
        fullDbName = refSeqRecs.first['databaseName']
        dbu.setNewDataDb(fullDbName)
        tableName = Abstraction::EntityList::ENTITY_TYPE_TO_TABLE_NAME[Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TYPE[rsrcType]]
        recs = dbu.selectByFieldAndValue(:userDB, tableName, 'name', rsrcName, "ERROR: #{self.class}##{__method__}():")
        rsrcId = recs.first['id']
      end
      return [groupId, refSeqId, rsrcId]
    end

    # Get the unlock Key for a track
    #
    # NOTE: This method will return nil if there isn't a key for the track
    #       There may be a key for the database which will access the track,
    #       but this method won't get it, use getHighestKeyForTrackById
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+trackName+]     Name of the track (method:source)
    # [+returns+]       The shared key for the specified track
    def self.getKeyForTrack(dbu, groupName, databaseName, trackName)
      groupId, refSeqId, ftypeId = getIdsForTrack(dbu, groupName, databaseName, trackName)
      key = self.getKeyForTrackById(dbu, groupId, refSeqId, ftypeId)
      return key
    end

    # Get the unlock Key for a track.
    #
    # NOTE: This method will return nil if there isn't a key for the track
    #       There may be a key for the database which will access the track,
    #       but this method won't get it, use getHighestKeyForTrackById
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+ftypeId+]       Id of the track
    # [+returns+]       The shared key for the specified track
    def self.getKeyForTrackById(dbu, groupId, refSeqId, ftypeId)
      key = nil
      if(groupId.to_i > 0 and refSeqId.to_i > 0 and ftypeId.to_i > 0)
        keyRows = dbu.selectUnlockKeyByResourceWithParent(groupId, 'track', ftypeId, 'database', refSeqId)
        key = (!keyRows.nil? and !keyRows.empty?) ? keyRows.first['unlockKey'] : nil
      else
        raise ArgumentError
      end
      return key
    end

    # Get the highest level unlock Key for a track,
    #  Either group level, database level or track level, in that order, which ever exists.
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+trackName+]     Name of the track (method:source)
    # [+returns+]       The shared key for the specified track
    def self.getHighestKeyForTrackByName(dbu, groupName, databaseName, trackName)
      key = nil
      key = self.getHighestKeyForDatabaseByName(dbu, groupName, databaseName)
      key = self.getKeyForTrack(dbu, groupName, databaseName, trackName) if(key.nil?)
      return key
    end

    # Get the highest level unlock Key for a track,
    #  Either group level, database level or track level, in that order, which ever exists.
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+ftypeId+]       Id of the track
    # [+returns+]       The shared key for the specified track
    def self.getHighestKeyForTrackById(dbu, groupId, refSeqId, ftypeId)
      key = nil
      key = self.getHighestKeyForDatabaseById(dbu, groupId, refSeqId)
      key = self.getKeyForTrackById(dbu, groupId, refSeqId, ftypeId)
      return key
    end

    # Adds a track record to unlockedGroupResources and a database record to unlockedGroupParentResources
    # making it available as an unlocked resource
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+trackName+]     Name of the track (method:source)
    # [+returns+]       Number of rows
    def self.unlockTrack(dbu, groupName, databaseName, trackName, isPublic=false)
      groupId, refSeqId, ftypeId = getIdsForTrack(dbu, groupName, databaseName, trackName)
      self.unlockTrackById(dbu, groupId, refSeqId, ftypeId, isPublic)
    end

    def self.unlockDbChildRsrc(dbu, groupName, databaseName, rsrcName, rsrcType, isPublic=false)
      groupId, refSeqId, rsrcId = getIdsForDbChildRsrcs(dbu, groupName, databaseName, rsrcName, rsrcType)
      self.unlockDbChildRsrcById(dbu, groupId, refSeqId, rsrcId, rsrcName, rsrcType, isPublic)
    end

    def self.unlockDbChildRsrcById(dbu, groupId, refSeqId, rsrcId, rsrcName, rsrcType, isPublic=false)
      if(groupId.to_i > 0 and refSeqId.to_i > 0 and rsrcId.to_i > 0)
        # generate and save the key
        unlockKey = generateKey()
        resourceUri = self.generateDbChildRsrcUri(dbu, groupId, refSeqId, rsrcName, rsrcType)
        # add or update the rsrc record
        # See if the record already exists and if so, update it
        rows = dbu.selectUnlockKeyByResourceWithParent(groupId, rsrcType, rsrcId, 'database', refSeqId)
        # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
        # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
        if(rows and !rows.empty? and rows.first['resourceUri'] != resourceUri)
          # Remove old record with out-of-date resourceUri, using the ids we have
          lockDbChildRsrcById(dbu, groupId, refSeqId, rsrcId)
          # But we'll keep the existing unlock key in this case and thus reuse it in the replacement records
          unlockKey = rows.first['unlockKey']
        end
        # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
        # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
        if(!rows.nil? and !rows.empty? and rows.first['resourceUri'] == resourceUri) # update
          # Can't use this method because there will be stranded parent records
          dbu.updateGroupResourceById(rows.first['id'], unlockKey)
          dbu.setGroupResourcePublicFlagById(rows.first['id'], isPublic)
        else # insert new (or replacement)
          dbu.insertUnlockedGroupResource(groupId, rsrcType, rsrcId, unlockKey, resourceUri, isPublic)
          # get insert_id
          insertId = dbu.genbDbh.func('insert_id')
          # add database parent record
          dbu.insertUnlockedGroupResourceParent(insertId, 'database', refSeqId)
        end
      else
        raise ArgumentError
      end
    end

    # Adds a track record to unlockedGroupResources and a database record to unlockedGroupParentResources
    # making it available as an unlocked resource
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+ftypeId+]       Id of the track
    # [+returns+]       Number of rows
    def self.unlockTrackById(dbu, groupId, refSeqId, ftypeId, isPublic=false)
      if(groupId.to_i > 0 and refSeqId.to_i > 0 and ftypeId.to_i > 0)
        # generate and save the key
        unlockKey = generateKey()
        resourceUri = self.generateTrackUri(dbu, groupId, refSeqId, ftypeId)
        # add or update the track record
        # See if the record already exists and if so, update it
        rows = dbu.selectUnlockKeyByResourceWithParent(groupId, 'track', ftypeId, 'database', refSeqId)
        # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
        # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
        if(rows and !rows.empty? and rows.first['resourceUri'] != resourceUri)
          # Remove old record with out-of-date resourceUri, using the ids we have
          lockTrackById(dbu, groupId, refSeqId, ftypeId)
          # But we'll keep the existing unlock key in this case and thus reuse it in the replacement records
          unlockKey = rows.first['unlockKey']
        end
        # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
        # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
        if(!rows.nil? and !rows.empty? and rows.first['resourceUri'] == resourceUri) # update
          # Can't use this method because there will be stranded parent records
          dbu.updateGroupResourceById(rows.first['id'], unlockKey)
          dbu.setGroupResourcePublicFlagById(rows.first['id'], isPublic)
        else # insert new (or replacement)
          dbu.insertUnlockedGroupResource(groupId, 'track', ftypeId, unlockKey, resourceUri, isPublic)
          # get insert_id
          insertId = dbu.genbDbh.func('insert_id')
          # add database parent record
          dbu.insertUnlockedGroupResourceParent(insertId, 'database', refSeqId)
        end
      else
        raise ArgumentError
      end
    end

    # Removes the track record from unlockedGroupResources and it's corresponding database record from unlockedGroupResourceParents
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+trackName+]     Name of the track (method:source)
    # [+returns+]       Number of rows
    def self.lockTrack(dbu, groupName, databaseName, trackName)
      groupId, refSeqId, ftypeId = getIdsForTrack(dbu, groupName, databaseName, trackName)
      return dbu.deleteUnlockedGroupResourceWithParent(groupId, 'track', ftypeId, 'database', refSeqId)
    end

    def self.lockDbChildRsrc(dbu, groupName, databaseName, rsrcName, rsrcType)
      groupId, refSeqId, rsrcId = getIdsForDbChildRsrcs(dbu, groupName, databaseName, rsrcName, rsrcType)
      return dbu.deleteUnlockedGroupResourceWithParent(groupId, rsrcType, rsrcId, 'database', refSeqId)
    end

    # Removes the track record from unlockedGroupResources and it's corresponding database record from unlockedGroupResourceParents
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+ftypeId+]       Id of the track
    # [+returns+]       Number of rows
    def self.lockTrackById(dbu, groupId, refSeqId, ftypeId )
      if(groupId.to_i > 0 and refSeqId.to_i > 0 and ftypeId.to_i > 0)
        dbu.deleteUnlockedGroupResourceWithParent(groupId, 'track', ftypeId, 'database', refSeqId)
      else
        raise ArgumentError
      end
    end

    def self.lockDbChildRsrcById(dbu, groupId, refSeqId, rsrcId, rsrcType )
      if(groupId.to_i > 0 and refSeqId.to_i > 0 and rsrcId.to_i > 0)
        dbu.deleteUnlockedGroupResourceWithParent(groupId, rsrcType, rsrcId, 'database', refSeqId)
      else
        raise ArgumentError
      end
    end

    # Get the unlock Key for a database
    #
    # NOTE: This method will return nil if there isn't a key for the database
    #       There may be a key for the group which will unlock the database
    #       but this method won't get it, use getHighestKeyForDatabasekById
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+returns+]       The shared key for the specified track
    def self.getKeyForDatabaseByName(dbu, groupName, databaseName)
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      key = self.getKeyForDatabaseById(dbu, groupId, refSeqId)
      return key
    end

    # Get the unlock Key for a database
    #
    # NOTE: This method will return nil if there isn't a key for the database
    #       There may be a key for the group which will unlock the database
    #       but this method won't get it, use getHighestKeyForDatabasekById
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+returns+]       The shared key for the specified track
    def self.getKeyForDatabaseById(dbu, groupId, refSeqId)
      key = nil
      if(!groupId.nil? and !refSeqId.nil?)
        keyRows = dbu.selectUnlockKeyByResource(groupId, 'database', refSeqId)
        key = (!keyRows.nil? and !keyRows.empty?) ? keyRows.first['unlockKey'] : nil
      end
      return key
    end

    # Get an unlock Key for a database
    #   Either group level key or database level, in that order, whichever exists
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+returns+]       The shared key for the specified track
    def self.getHighestKeyForDatabaseByName(dbu, groupName, databaseName)
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      key = self.getHighestKeyForDatabaseById(dbu, groupId, refSeqId)
      return key
    end

    # Get an unlock Key for a database
    #   Either group level key or database level, in that order, whichever exists
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      Id of the database
    # [+returns+]       The shared key for the specified track
    def self.getHighestKeyForDatabaseById(dbu, groupId, refSeqId)
      key = nil
      if(!groupId.nil? and !refSeqId.nil?)
        key = self.getKeyForGroupById(dbu, groupId)
        if(key.nil?)
          keyRows = dbu.selectUnlockKeyByResource(groupId, 'database', refSeqId)
          key = (!keyRows.nil? and !keyRows.empty?) ? keyRows.first['unlockKey'] : nil
        end
      end
      return key
    end

    # Get the unlock Key for a group
    #
    # NOTE: This method will return nil if there isn't a key for the group
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+returns+]       The shared key for the specified track
    def self.getKeyForGroupByName(dbu, groupName)
      groupRows = dbu.selectGroupByName(groupName)
      groupId = groupRows.first['groupId'] if(!groupRows.nil? and !groupRows.empty?)
      key = self.getKeyForGroupById(dbu, groupId)
      return key
    end

    # Get an unlock Key for a Group
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+returns+]       The shared key for the specified track
    def self.getKeyForGroupById(dbu, groupId)
      key = nil
      if(!groupId.nil?)
        keyRows = dbu.selectUnlockKeyByResource(groupId, 'group', groupId) # groupId is redundant here, but required
        key = (!keyRows.nil? and !keyRows.empty?) ? keyRows.first['unlockKey'] : nil
      end
      return key
    end

    # Adds a record to unlockedGroupResources
    #
    # making the database available as an unlocked resource
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+returns+]
    def self.unlockDatabase(dbu, groupName, databaseName, isPublic=false)
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      self.unlockDatabaseById(dbu, groupId, refSeqId, isPublic)
    end

    # Adds a record to unlockedGroupResources
    #
    # making the database available as an unlocked resource
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      refSeqId of the database
    # [+returns+]
    def self.unlockDatabaseById(dbu, groupId, refSeqId, isPublic=false)
      if(groupId.to_i > 0 and refSeqId.to_i > 0)
        groupRefSeqRows = dbu.selectGroupRefSeq(groupId, refSeqId)
        if(!groupRefSeqRows.nil? and !groupRefSeqRows.empty?)
          # generate and save the key
          unlockKey = generateKey()
          resourceUri = self.generateDatabaseUri(dbu, groupId, refSeqId)
          # Check that the record already exists
          rows = dbu.selectUnlockKeyByResource(groupId, 'database', refSeqId)
          # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
          # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
          if(rows and !rows.empty? and rows.first['resourceUri'] != resourceUri)
            # Remove old record with out-of-date resourceUri, using the ids we have
            lockDatabaseById(dbu, groupId, refSeqId)
            # But we'll keep the existing unlock key in this case and thus reuse it in the replacement records
            unlockKey = rows.first['unlockKey']
          end
          # Now we need to either update existing row--where the resourceUri matches--or put in a new record if not there if needing to replace a renamed resource
          if(!rows.nil? and !rows.empty? and rows.first['resourceUri'] == resourceUri) # update
            # Can't use this method because there will be stranded parent records
            dbu.updateGroupResourceById(rows.first['id'], unlockKey)
            dbu.setGroupResourcePublicFlagById(rows.first['id'], isPublic)
          else # insert/replace
            dbu.insertUnlockedGroupResource(groupId, 'database', refSeqId, unlockKey, resourceUri, isPublic)
          end
        else
          raise ArgumentError('group does not belong to database')
        end
      else
        raise ArgumentError
      end
    end

    def self.generateGroupUri(dbu, groupId)
      groupRows = dbu.selectGroupById(groupId)
      groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
      uri = BRL::REST::Resources::Group.getPath(groupName)
      return uri
    end

    def self.generateDatabaseUri(dbu, groupId, refSeqId)
      groupRows = dbu.selectGroupById(groupId)
      groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
      refSeqRows = dbu.selectRefseqById(refSeqId)
      databaseName = refSeqRows.first['refseqName'] if(!refSeqRows.nil? and !refSeqRows.empty?)
      uri = BRL::REST::Resources::Database.getPath(groupName, databaseName)
      return uri
    end

    def self.generateTrackUri(dbu, groupId, refSeqId, ftypeId)
      groupRows = dbu.selectGroupById(groupId)
      groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
      refSeqRows = dbu.selectRefseqById(refSeqId)
      databaseName = refSeqRows.first['refseqName'] if(!refSeqRows.nil? and !refSeqRows.empty?)
      trackRows = dbu.selectFtypesByIds([ftypeId])
      trackName = "#{trackRows.first['fmethod']}:#{trackRows.first['fsource']}" if(!trackRows.nil? and !trackRows.empty?)
      uri = BRL::REST::Resources::Track.getPath(groupName, databaseName, trackName)
      return uri
    end

    def self.generateDbChildRsrcUri(dbu, groupId, refSeqId, rsrcName, rsrcType)
      groupRows = dbu.selectGroupById(groupId)
      groupName = groupRows.first['groupName'] if(!groupRows.nil? and !groupRows.empty?)
      refSeqRows = dbu.selectRefseqById(refSeqId)
      databaseName = refSeqRows.first['refseqName'] if(!refSeqRows.nil? and !refSeqRows.empty?)
      gc = BRL::Genboree::GenboreeConfig.load
      rsrcNameToUseInUrl =nil
      if(rsrcType == 'file')
        rsrcNameToUseInUrl = rsrcName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      else
        rsrcNameToUseInUrl = CGI.escape(rsrcName)
      end
      return "/REST/v1/grp/#{CGI.escape(groupName)}/db/#{CGI.escape(databaseName)}/#{rsrcType}/#{rsrcNameToUseInUrl}"
    end

    # Removes the database from the unlockedGroupResources table
    #
    # [+dbu+]           DBUtil instance
    # [+groupName+]     Name of the Genboree Group
    # [+databaseName+]  Name of the database (refseqName)
    # [+returns+]
    def self.lockDatabase(dbu, groupName, databaseName)
      groupId, refSeqId = self.getIdsForDatabase(dbu, groupName, databaseName)
      self.lockDatabaseById(dbu, groupId, refSeqId)
    end

    # Removes the database from the unlockedGroupResources table
    #
    # [+dbu+]           DBUtil instance
    # [+groupId+]       Id of the Genboree Group
    # [+refSeqId+]      refSeqId of the database (refseqName)
    # [+returns+]
    def self.lockDatabaseById(dbu, groupId, refSeqId)
      if(groupId.to_i > 0 and refSeqId.to_i > 0)
        # delete database record
        dbu.deleteUnlockedGroupResource(groupId, 'database', refSeqId)
      else
        raise ArgumentError
      end
    end

    def self.lockGroup(dbu, groupName)
      groupId = self.getIdForGroup(dbu, groupName)
      self.lockGroupById(dbu, groupId)
    end

    def self.lockGroupById(dbu, groupId)
      if(groupId.to_i > 0)
        dbu.deleteUnlockedGroupResource(groupId, 'group', groupId)
      else
        raise ArgumentError
      end
    end

    def self.unlockGroup(dbu, groupName, isPublic=false)
      groupId = self.getIdForGroup(dbu, groupName)
      self.unlockGroupById(dbu, groupId)
    end

    def self.unlockGroupById(dbu, groupId, isPublic=false)
      if(groupId.to_i > 0)
        # generate and save the key
        unlockKey = generateKey()
        resourceUri = self.generateGroupUri(dbu, groupId)
        # Check that the record already exists
        rows = dbu.selectUnlockKeyByResource(groupId, 'group', groupId)
        # If there's a row in there for these ids but the resourceUri column doesn't match anymore (e.g. was renamed or something)
        # then remove the existing row(s) using the ids prior to insert/update (to avoid unique key violations)
        if(rows.first['resourceUri'] != resourceUri)
          # Remove old record with out-of-date resourceUri, using the ids we have
          lockGroupById(dbu, groupId)
            # But we'll keep the existing unlock key in this case and thus reuse it in the replacement records
            unlockKey = rows.first['unlockKey']
        end
        # Now we need to either update existing row--where the resourceUri matches--or put in a new record if not there if needing to replace a renamed resource
        if(!rows.nil? and !rows.empty? and rows.first['resourceUri'] == resourceUri) # update
          dbu.updateGroupResourceById(rows.first['id'], unlockKey)
          dbu.setGroupResourcePublicFlagById(rows.first['id'], isPublic)
        else # insert/replace
          dbu.insertUnlockedGroupResource(groupId, 'group', groupId, unlockKey, resourceUri, isPublic)
        end
      else
        raise ArgumentError
      end
    end
  end
end ; end ; end ; end
