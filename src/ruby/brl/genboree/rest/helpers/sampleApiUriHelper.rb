require 'uri'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/wrapperApiCaller'

module BRL ; module Genboree ; module REST ; module Helpers
  class SampleApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/(?:bioSample|sample)/([^/\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/(?:bioSample|sample)/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off

    attr_accessor :dbApiUriHelper
    attr_accessor :grpApiUriHelper
    attr_accessor :containers2Children

    alias expandSampleContainers expandContainers

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @dbApiUriHelper = @grpApiUriHelper = nil

      # NOTE classifySampleUris requires that the first match group of all these uris is their name
      # provide a set of REGEXP to identify sample and sample-containing URIs
      @SAMPLE_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/sample/([^\?]+)}
      @SAMPLE_ENTITY_LIST_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/samples/entityList/([^/\?]+)}
      @SAMPLE_SET_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/sampleSet/([^/\?]+)}
      @SAMPLE_FOLDER_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/(bioSamples|samples)} # | to support future migration to "samples"
      @DB_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/([^/\?]+)(?!/)}

      # set the order these regexp should be matched in (generally most-specific to least-specific)
      @typeOrder = [:sample, :sample_set, :sample_list, :sample_folder, :database]

      # associate type symbols to their associated regexps
      @type2Regexp = {
        :sample => @SAMPLE_REGEXP,
        :sample_set => @SAMPLE_SET_REGEXP,
        :sample_list => @SAMPLE_ENTITY_LIST_REGEXP,
        :sample_folder => @SAMPLE_FOLDER_REGEXP,
        :database => @DB_REGEXP
      }

      # associate type symbols to a method that can be used to extract samples from that type
      # if type doesnt have a key, nothing to do -- just use the uri (case of sample uri)
      @type2Method = {
        :sample_set => :getSamplesInSet,
        :sample_list => :getSamplesInList,
        :sample_folder => :getSamplesInFolder,
        :database => :getSamplesInDb
      }

      # provide a cache for an association between container uris and their contents/children
      @containers2Children = Hash.new([])

      super(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @dbApiUriHelper = DatabaseApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@dbApiUriHelper)
      @grpApiUriHelper = @dbApiUriHelper.grpApiUriHelper unless(@grpApiUriHelper)
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      super(reusableComponents)
      reusableComponents.each_key { |compType|
        case compType
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        when :dbApiUriHelper
          @dbApiUriHelper = reusableComponents[compType]
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
      @containers2Children = Hash.new([])
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

    # Expand a sample set uri to its child sample uris
    # @param [String] setUri uri to sample set to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] sample uris whose parent is setUri
    # @raise [RuntimeError] if API server is down
    def getSamplesInSet(setUri, userId)
      sampleUris = []
      uriObj = URI.parse(setUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']['sampleList']
        resp.each{ |sampleDetail|
          sampleUri = sampleDetail['refs'][BRL::Genboree::REST::Data::BioSampleEntity::REFS_KEY]
          sampleUris << sampleUri
        }
      else
        raise "URI: #{setUri.inspect} was inaccessible to the API caller."
      end
      return sampleUris
    end

    # Expand a list uri to its child sample uris
    # @param [String] listUri uri to sample entity list to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] sample uris whose parent is listUri
    # @raise [RuntimeError] if API server is down
    def getSamplesInList(listUri, userId)
      sampleUris = []
      uriObj = URI.parse(listUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |sampleDetail|
          sampleUri = sampleDetail['url']
          sampleUris << sampleUri
        }
      else
        raise "URI: #{listUri.inspect} was inaccessible to the API caller."
      end
      return sampleUris
    end

    # Expand a database uri to its child sample uris
    # @param [String] dbUri uri to database to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] sample uris whose parent is dbUri
    # @raise [RuntimeError] if API server is down
    def getSamplesInDb(dbUri, userId)
      sampleUris = []
      uriObj = URI.parse(dbUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}/samples?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |sampleDetail|
          sampleUri = sampleDetail['refs'][BRL::Genboree::REST::Data::BioSampleEntity::REFS_KEY]
          sampleUris << sampleUri
        }
      else
        raise "URI: #{dbUri.inspect} was inaccessible to the API caller."
      end
      return sampleUris
    end

    # Expand a folder uri to its child sample uris
    # @param [String] dbUri uri to database to expand
    # @param [Fixnum] userId the user ID number in the Genboree database (for credentials)
    # @return [Array<String>] sample uris whose parent is folderUri
    # @raise [RuntimeError] if API server is down
    def getSamplesInFolder(folderUri, userId)
      sampleUris = []
      uriObj = URI.parse(folderUri)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path.chomp('?')}?detailed=true", userId)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        resp = apiCaller.parseRespBody()['data']
        resp.each{ |sampleDetail|
          sampleUri = sampleDetail['refs'][BRL::Genboree::REST::Data::BioSampleEntity::REFS_KEY]
          sampleUris << sampleUri
        }
      else
        raise "URI: #{folderUri.inspect} was inaccessible to the API caller."
      end
      return sampleUris
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
