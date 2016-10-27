#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/util/util'
require 'brl/dataStructure/cache' # for CacheObject wrapper and CacheError exception class

# @author Andrew R Jackson

module BRL ; module DataStructure

  # A global, process-wide cache. Actually a cache-of-caches. Each
  #   cache handled by this singleton has a "cache name" (preferably a Symbol)
  #   which is used to specify which cache to operate one.
  class SingletonCache

    # Set up the 'class instance' variables. By using class-instance variables [yes, WTF]
    # for this, we implement the singleton pattern without the getIntance() approach of Java or whatever.
    # The class is its own singleton.
    class << self
      # Set up class instance variables
      attr_accessor :cachedObjects
      # Cache-of-caches
      SingletonCache.cachedObjects = Hash.new {|hh, cacheName| hh[cacheName] = {} }
    end

    # Clear the indicated cache or the entire cache-of-caches if no specific one indicated.
    # @param [Object,nil] cacheName The 'name' [preferably a Symbol] of the cache to clear.
    #   If @nil@ then ALL caches are cleared!
    # @return The result of calling clear() on the cache.
    def self.clear(cacheName=nil)
      if(cacheName)
        self.cachedObjects[cacheName].clear()
      else
        self.cachedObjects.each_key { |cacheName| self.cachedObjects[cacheName].clear() }
        self.cachedObjects.clear()
      end
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache to get the size for.
    # @return [Fixnum] The size of the indicated cache.
    def self.size(cacheName)
      return self.cachedObjects[cacheName].size
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache to get the keys of.
    # @return [Array] The keys in the indicated cache
    def self.keys(cacheName)
      return self.cachedObjects[cacheName].keys
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache to test for presence of 'key'
    # @param [Object] key The key to test the presence of in the indicated cache
    # @return [boolean] indicating if the key is persent in the indicated cache
    def self.key?(cacheName, key)
      return self.cachedObjects[cacheName].key?(key)
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache from which to get the object at 'key'
    # @param [Object] key The key to use to get the stored object, if any
    # @return [Object,nil] the stored object at 'key', if any
    def self.getObject(cacheName, key)
      cacheEntry = self.cachedObjects[cacheName][key]
      return ( cacheEntry.is_a?(BRL::DataStructure::CachedObject) ? cacheEntry.getObject() : nil )
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache to get the insert time from using 'key'
    # @param [Object] key The key to use to get the insertTime, if any
    # @return [Time,nil] the insertTime for the object at 'key', if any
    def self.getInsertTime(cacheName, key)
      cacheEntry = self.cachedObjects[cacheName][key]
      return ( cacheEntry.is_a?(BRL::DataStructure::CachedObject) ? cacheEntry.insertTime : nil )
    end

    # This is used to cache/store/update the object IF it is not currently stored
    # or IF the stored version is out-of-date (its insertTime is < newInsertTime).
    # If you want to force insertion, use the #insertObject method.
    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache in which to cache the new object.
    # @param [Object] key The key to use to store the object
    # @param [Object] object The object to store
    # @param [Time,nil] newInsertTime The new insertion time which, IF provided, it will be used
    #   as the time associated with the key-value pair. If there is NO value stored at key, then
    #   key-value is added with @newInsertTime@ as the insert time. If there IS a value already
    #   stored for key, it is only updated if the stored insertTime is older than @newInsertTime@.
    #   i.e. newInsertTime is the insert time associated with the key-value arguments provided.
    # @return [Object] The stored object. Either the currently stored object if already present or
    #   if at least as new as newInsertTime, or the 'object' argument if there is no stored object yet
    #   or it is out-of-date w.r.t. newInsertTime.
    def self.cacheObject(cacheName, key, object, newInsertTime=nil)
      retVal = object
      cache = self.cachedObjects[cacheName]
      cacheEntry = cache[key]
      if(cacheEntry.is_a?(BRL::DataStructure::CachedObject)) # then it is already in the cache
        # CASE 1: Have obj stored already, not asked to consider updating. Do nothing.
        if(!newInsertTime.is_a?(Time))
          retVal = cacheEntry.getObject()
        # CASE 2: Have obj stored already, but it is at least as up-to-date as one provided. Do nothing.
        elsif(cacheEntry.insertTime >= newInsertTime)
          retVal = cacheEntry.getObject()
        # CASE 3: Have obj, but it is older than one provided. Replace.
        elsif(cacheEntry.insertTime < newInsertTime)
          retVal = self.insertObject(cacheName, key, object, newInsertTime)
        else
          raise CacheError, "\n\nERROR: have object in cache, but can't figure out what to do about adding new one.\n\n"
        end
      else # obj is not in the cache. Add it.
        retVal = self.insertObject(cacheName, key, object, newInsertTime)
      end
      return retVal
    end

    # Forcibly insert an object into a cache even if already present for 'key'.
    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache in which to cache the new object.
    # @param [Object] key The key to use to store the object
    # @param [Object] object The object to store
    # @param [Time] insertTime If provided, it will be the insert time of the stored object. By default
    #   it is @Time.now@ but some uses may require control over what that insert time should be (e.g. maybe
    #   it should make the mtime of a file on disk or something). If @nil@, assumes @Time.now@ is intended.
    # @return [Object] The stored object.
    def self.insertObject(cacheName, key, object, insertTime=Time.now)
      insertTime ||= Time.now
      cachedObject = BRL::DataStructure::CachedObject.new(object, insertTime)
      cache = self.cachedObjects[cacheName]
      cache[key] = cachedObject
      retVal = cache[key].getObject()
    end
  end # class SingletonCache
end ; end # module BRL ; module DataStructure
