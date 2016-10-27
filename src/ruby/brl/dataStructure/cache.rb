#
# Authors: Andrew R Jackson

module BRL ; module DataStructure

  # A Cache-related exception class
  class CacheError < StandardError ; end

  # A wrapper class for a an object cached in memory and last used/inserted/updated at a certain time.
  class CachedObject
    # @return [Time] the last time the stored object was inserted/updated in the cache
    attr_accessor :insertTime
    # @return [Time] the last time the stored object was accessed/used; some caches will NOT
    #   update & maintain this when it's not needed, for speed/performance reasons. Mostly relevant
    #   to size-limited caches, so the entry with the longest time since last access can be removed to make room.
    attr_accessor :lastUseTime

    # CONSTRUCTOR
    # @param [Object] object the specific object being stored in the cache; the object wrapped by this CachedObject instance
    # @param [Time] insertTime the time the object was inserted into the cache
    def initialize(object, insertTime=Time.now)
      @lastUseTime = @insertTime = insertTime
      @object = object
    end

    # Gets the specific object wrapped by this CachedObject instance
    # @return [Object]
    def getObject()
      @lastUseTime = Time.now
      return @object
    end

    # Updates the 'lastUseTime' for this object, sort of like 'touch' does in Linux.
    # @return [Time] the time right now, which was used to 'touch' this object
    def touch()
      @lastUseTime = Time.now
    end
  end # END: class CachedObject

  # Size-limited object cache
  class LimitedCache
    attr_accessor :maxNumObjects

    def initialize(maxNumObjects)
      @maxNumObjects = maxNumObjects
      @cachedObjects = {}
    end

    def clear()
      @cachedObjects.clear()
    end

    def size()
      return @cachedObjects.length
    end

    def keys()
      return @cachedObjects.keys
    end

    def key?(key)
      return @cachedObjects.key?(key)
    end

    def getObject(key)
      return @cachedObjects.key?(key) ? @cachedObjects[key].getObject() : nil
    end

    def getLastUseTime(key)
      return @cachedObjects.key?(key) ? @cachedObjects[key].lastUseTime : nil
    end

    def getInsertTime(key)
      return @cachedObjects.key?(key) ? @cachedObjects[key].insertTime : nil
    end

    def cacheObject(key, object, insertTime=nil)
      retVal = object
      if(@cachedObjects.key?(key)) # then it is already in the cache
        # CASE 1: Have obj, not asked to consider updating. Do nothing.
        if( insertTime.nil? or (!insertTime.kind_of?(Time)))
          retVal = @cachedObjects[key].getObject()
        # CASE 2: Have obj, but it is at least as up-to-date as one provided. Do nothing.
        elsif(@cachedObjects[key].insertTime >= insertTime)
          retVal = @cachedObjects[key].getObject()
        # CASE 3: Have obj, but it is older than one provided. Replace.
        elsif(@cachedObjects[key].insertTime < insertTime)
          retVal = self.insertObject(key, object, insertTime)
        else
          raise CacheError, "\n\nERROR: have object in cache, but can't figure out what to do about adding new one.\n\n"
        end
      else # obj is not in the cache. Add it.
        retVal = self.insertObject(key, object, insertTime)
      end
      return retVal
    end

    def insertObject(key, object, insertTime=Time.now)
      # Remove an object if needed to maintain max size.
      self.unloadOldest() if(@cachedObjects.size + 1 > @maxNumObjects)
      cachedObject = CachedObject.new(object, insertTime)
      @cachedObjects[key] = cachedObject
      retVal = @cachedObjects[key].getObject()
    end

    # Unload handler that was used the longest time ago.
    def unloadOldest()
      unloadMeKey = @cachedObjects.keys.min { |aa,bb| @cachedObjects[aa].lastUseTime <=> @cachedObjects[bb].lastUseTime }
      @cachedObjects.delete(unloadMeKey)
    end

    alias_method :length, :size
  end # END: class LimitedCache

  # Size-limited cache of a file's contents
  class FileContentCache < LimitedCache
    def initialize(maxNumObjects)
      super(maxNumObjects)
    end

    def cacheFile(fileName)
      retVal = nil
      return retVal if(!File.exist?(fileName))
      fileMtime = File.stat(fileName).mtime

      if(@cachedObjects.key?(fileName)) # then it is already in the cache
        # CASE 1: Have file, but it is at least as up-to-date as one provided. Do nothing.
        if(@cachedObjects[key].getInsertTime() >= fileMtime)
          retVal = @cachedObjects[key].getObject()
        # CASE 2: Have file, but it is older than one provided. Replace.
        elsif(@cachedObjects[key].getInsertTime() < fileMtime)
          retVal = self.insertFile(fileName, fileMtime)
        else
          raise CacheError, "\n\nERROR: have file in cache, but can't figure out what to do about adding new one.\n\n"
        end
      else # file is not in the cache. Add it.
        retVal = self.insertFile(fileName, fileMtime)
      end
    end

    def insertFile(fileName, fileMtime=nil)
      retVal = @cachedObjects[fileName]
      return retVal if(!File.exist?(fileName))
      fileMtime = File.stat(fileName).mtime if(fileMtime.nil?)

      # First, get file content
      content = File.read(fileName)
      retVal = self.insertObject(fileName, content, fileMtime)
      return retVal
    end
  end # END class FileContentCache
end ; end
