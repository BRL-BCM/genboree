#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/util/util'
require 'brl/dataStructure/cache' # for CacheObject wrapper and CacheError exception class
require 'brl/dataStructure/singletonCache'

# @author Andrew R Jackson

module BRL ; module DataStructure

  # A global, process-wide cache of a file's contents. Actually a cache-of-caches.
  # The cacheName is used to specify a cache of content keyed by file path; it can
  # be used to name collections of cached files that have something in common. For examples:
  # :menuConfFiles, :toolConfFiles, etc.
  #
  # This is basically the SingletonCache class using file mtimes for the insertTimes
  # where appropriate
  class SingletonFileContentCache < SingletonCache

    # Set up the 'class instance' variables. By using class-instance variables [yes, WTF]
    # for this, we implement the singleton pattern without the getIntance() approach of Java or whatever.
    # The class is its own singleton.
    class << self
      # Set up class instance variables
      attr_accessor :cachedObjects
      # Cache-of-caches
      SingletonFileContentCache.cachedObjects = Hash.new {|hh, cacheName| hh[cacheName] = {} }
    end

    # @see #getObject
    def self.getContent(cacheName, filePath)
      return self.getObject(cacheName, filePath)
    end

    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache from which
    #   to get the file contents stored at 'filePath'.
    # @param [Object] filePath The file to use to get the stored content, if any
    # @return [Object,nil] the stored file content for 'filePath', if any
    def self.getObject(cacheName, filePath)
      # Before trying to get the stored contents of filePath, if any, we need
      # to ensure we have the most up-to-date contents stored for that file.
      # We'll use cacheFile() to do this; it will only update the cache if
      # it looks like the file may have new contents, else it just returns what's
      # already stored.
      self.cacheFile(cacheName, filePath)
      # Now retrieve contents of filePath, of which we have the most up-to-date version in memory.
      cacheEntry = self.cachedObjects[cacheName][filePath]
      return ( cacheEntry.is_a?(BRL::DataStructure::CachedObject) ? cacheEntry.getObject() : nil )
    end

    # This is used to cache/store/update the file content IF it is not currently stored
    # or IF the stored version is out-of-date (its insertTime is older than the mtime of the file at filePath).
    # If you want to force insertion, use the #insertObject method.
    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache in which to cache the new object.
    # @param [Object] filePath The path to the file whose content should be cached. This will be the key.
    # @return [Object] The stored content of the file at filePath. Either the currently stored content if already present or
    #   if at least as new as newInsertTime, or the newly-read content if there is no stored content yet for filePath
    #   or it is out-of-date w.r.t. the file's mtime.
    def self.cacheFile(cacheName, filePath)
      retVal = nil
      # If not given filePath as String, assume File-like and use it to get actual filePath
      unless(filePath.is_a?(String))
        origFilePath = filePath
        filePath = filePath.path
      end
      # Path for doing Ruby File methods on (can't handle ~/ and such)
      readFilePath = File.expand_path(filePath)

      # If file exists, we can cache contents. Else nothing to do.
      if(File.readable?(readFilePath))
        # Get mtime of file, for use as insertTime
        fileMtime = File.stat(readFilePath).mtime
        # We don't want to read the file again unnecessarily, so use fileMtime to
        # determine if will be updating the cache at all or not.
        cache = self.cachedObjects[cacheName]
        cacheEntry = cache[filePath]
        if(cacheEntry.is_a?(BRL::DataStructure::CachedObject)) # then it is already in the cache
          # CASE 1: Have file, but it is at least as up-to-date as one provided. Do not update; return stored contents.
          if(cacheEntry.insertTime >= fileMtime)
            retVal = cacheEntry.getObject()
          # CASE 2: Have file, but it is older than one provided. Replace stored contents with newer version.
          else # cacheEntry.insertTime < fileMtime)
            retVal = self.insertFile(cacheName, filePath, fileMtime)
          end
        else # file is not in the cache yet at all. Add it.
          retVal = self.insertFile(cacheName, filePath, fileMtime)
        end
      end
      return retVal
    end

    # Forcibly insert/update stored file content into a cache even if already present for 'filePath'.
    # @param [Object] cacheName The 'name' [preferably a Symbol] of the cache in which to cache the new file content.
    # @param [Object] filePath The path to the file whose content should be cached. This will be the key.
    # @param [Time,nil] fileMtime For use outside this class, it is appropriate NOT to provide this optional argument;
    #   in which case, the appropriate mtime of the file will be determined and used to store/update the cache contents.
    #   If provided, the @Time@ object will be used as the mtime of the file when storing it in the cache instead of
    #   figuring it out on the fly; used in this class's code to save time when we already have the mtime.
    # @return [Object] The stored contents of the file at filePath.
    def self.insertFile(cacheName, filePath, fileMtime=nil)
      retVal = nil
      # If not given filePath as String, assume File-like and use it to get actual filePath
      unless(filePath.is_a?(String))
        origFilePath = filePath
        filePath = filePath.path
      end
      # Path for doing Ruby File methods on (can't handle ~/ and such)
      readFilePath = File.expand_path(filePath)

      # If file exists, we can cache contents. Else nothing to do.
      if(File.readable?(readFilePath))
        # Get the mtime of the file if not provided
        fileMtime = File.stat(readFilePath).mtime if(fileMtime.nil?)
        # First, get file content [via interface method for easy sub-classing]
        content = self.getFileContent(readFilePath)
        # Use inherited insertObject() method to store content of file
        retVal = self.insertObject(cacheName, filePath, content, fileMtime)
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------

    # @note Genboree SingletonFileContentCache interface method. Sub-classes likely will override to
    #   process file contents after reading it in. Here it is just read in as a big String.
    # @param [String,File] filePath The path to the file whose content will be read.
    # @return [String,nil] the contents of the file, if any
    # @raise [Exception] especially IO-related exceptions if filePath is bogus in some way.
    def self.getFileContent(filePath)
      retVal = nil
      # If not given filePath as String, assume File-like and use it to get actual filePath
      if(filePath.is_a?(String))
        filePath = File.expand_path(filePath)
      else
        origFilePath = filePath
        filePath = File.expand_path(filePath.path)
      end
      if(File.readable?(filePath))
        retVal = File.read(filePath)
      end
      return retVal
    end
  end # class SingletonFileContentCache
end ; end # module BRL ; module DataStructure
