require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'

module BRL ; module Genboree ; module REST ; module Helpers
  class FileEntityListApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/files/entityList/([^/\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/files/entityList/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off

    attr_accessor :dbApiUriHelper
    attr_accessor :grpApiUriHelper

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @dbApiUriHelper = @grpApiUriHelper = nil
      super(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @dbApiUriHelper = DatabaseApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@dbApiUriHelper)
      @grpApiUriHelper = @dbApiUriHelper.grpApiUriHelper unless(@grpApiUriHelper)
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      reusableComponents.each_key { |compType|
      super(reusableComponents)
        case compType
        when :dbApiUriHelper
          @dbApiUriHelper = reusableComponents[compType]
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        end
      }
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      # Call clear() on track abstraction objects
      if(!@cache.nil?)
        @cache.each_key { |uri|
          sampleObj = @cache[uri][:abstraction]
          sampleObj.clear() if(sampleObj and sampleObj.respond_to?(:clear))
        }
      end
      super()
      @dbApiUriHelper.clear() if(@dbApiUriHelper)
      @dbApiUriHelper = nil
      # grpApiUriHelper is cleared by dbApiUriHelper from whence it came
      @grpApiUriHelper = nil
    end


    # Does this resource actually exist? Tracks can exist either in user
    # database or the template database...need to override this method.
    def exists?(uri)
      exists = false
      if(uri)
        # First, try from cache
        exists = getCacheEntry(uri, :exists)
        if(exists.nil?) # then test manually
          name = extractName(uri)
          if(name)
            setNewDataDb(uri)
            retVal = @dbu.selectBioSampleByName(name)
            exists = true if(!retVal.nil? and !retVal.empty?)
          end
        end
      end
      return exists
    end


    # Db version for database this track is in
    def dbVersion(uri)
      return @dbApiUriHelper.dbVersion(uri)
    end

    # Is this track's db version equal to versionStr?
    def dbVersionEquals?(uri, versionStr)
      return @dbApiUriHelper.dbVersionEquals?(uri, versionStr)
    end

    # Do ALL tracks' db versions match?
    def dbsVersionMatch?(uris)
      return @dbApiUriHelper.dbsVersionMatch?(uris)
    end

    # Get trackName => dbVersion hash
    def dbVersionsHash(uris)
      return @dbApiUriHelper.dbVersionsHash(uris)
    end




    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    # Set the database as the active data db in the handle
    def setNewDataDb(uri)
      retVal = false
      if(uri)
        # Get name of database
        refSeqId = @dbApiUriHelper.id(uri)
        # Get MySQL database name
        databaseNameRows = @dbu.selectDBNameByRefSeqID(refSeqId)
        if(databaseNameRows and !databaseNameRows.empty?)
          databaseName = databaseNameRows.first['databaseName']
          # Set as active data db in handle
          @dbu.setNewDataDb(databaseName)
          retVal = true
        end
      end
      return retVal
    end


  end # class TrackApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
