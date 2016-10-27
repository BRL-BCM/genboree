#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'json'
require 'brl/util/util'
require 'brl/dataStructure/cache' # for CacheObject wrapper and CacheError exception class
require 'brl/dataStructure/singletonFileContentCache'

# @author Andrew R Jackson

module BRL ; module DataStructure

  # A global, process-wide cache of a JSON file's parsed contents. Actually a cache-of-caches.
  # The cacheName is used to specify a cache of content keyed by file path; it can
  # be used to name collections of cached JSON files that have something in common. For examples:
  # :menuConfFiles, :toolConfFiles, etc.
  #
  # This is basically the SingletonFileContentCache class but with an overridden getFileContent() method
  # which parsed the JSON content read from the file.
  class SingletonJsonFileCache < SingletonFileContentCache

    # Set up the 'class instance' variables. By using class-instance variables [yes, WTF]
    # for this, we implement the singleton pattern without the getIntance() approach of Java or whatever.
    # The class is its own singleton.
    class << self
      # Cache-of-caches
      SingletonJsonFileCache.cachedObjects = Hash.new {|hh, cacheName| hh[cacheName] = {} }
    end

    # @see #getObject
    def self.getJsonObject(cacheName, filePath)
      return self.getContent(cacheName, filePath)
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------

    # @note Genboree SingletonFileContentCache interface method. Sub-classes likely will override to
    #   process file contents after reading it in. Here the file content is parsed as JSON.
    # @param [String,File] jsonFilePath The path to the file whose content will be read.
    # @return [String,nil] the contents of the file, if any
    # @raise [JSON::ParserError, Exception] especially IO-related exceptions if filePath is bogus in some way
    #   or if the JSON in the file is malformed.
    def self.getFileContent(jsonFilePath)
      retVal = nil
      # If not given filePath as String, assume File-like and use it to get actual filePath
      unless(jsonFilePath.is_a?(String))
        origFilePath = jsonFilePath
        jsonFilePath = File.expand_path(jsonFilePath.path)
      end
      if(File.readable?(jsonFilePath))
        content = File.read(jsonFilePath)
        retVal = JSON.parse(content)
      end
      return retVal
    end
  end # class SingletonJsonFileCache
end ; end # module BRL ; module DataStructure
