require 'uri'
require 'cgi'
require 'digest'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'

module BRL ; module Genboree ; module REST ; module Helpers

  # class that puts and gets api cache record to its dedicated database table
  class ApiCacheHelper

    # @param [String] rsrcPath Rest resource path without any query string 
    # @param [Hash] params Hash of all the name-value pairs provided in the request URI
    #   BRL::REST::Resources::GenboreeResource instance variable @nvPairs 
    def initialize(rsrcPath, params)
      @resPath = rsrcPath
      @apiCacheparams = params
    end


    
    # get the api cache record from its table - apiRespCache
    # @param [String] editTimeOrVersion last edit time of a source collection or the version of a document
    # @param [Hash] secNvPairs hash with name-value pairs of additional parameters associated with the resource path
    #  can include version number of views, query document, transformation document, etc
    # @return [Array<Hash>] retVal cached record 
    # @raise [Error] if connection to the database fails
    def getapiCache(editTimeOrVersion, secNvPairs={})
     retVal = nil
     #1. Get the sorted query string including the secondary keys (if any)
     normalizedNvPairs = normalizeEnvPairs()
     orderedQueryString = buildOrderedQueryStr(normalizedNvPairs, secNvPairs)
     #2. Build the id for the record
     md5 = Digest::MD5.new
     #3. construct cache path
     cachePath = "#{@resPath}?#{orderedQueryString}&versionId=#{CGI.escape(editTimeOrVersion)}"
     #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "CachePath - #{cachePath.inspect}")
     cacheId = md5.hexdigest(cachePath)
     #4. connect to the cache database
     genbConf = BRL::Genboree::GenboreeConfig.load()
     dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
     cacheDbrcKey = genbConf.cacheDbrcKey
     begin
        dbu.setNewOtherDb(cacheDbrcKey)
      rescue => err
        raise "CACHE_DB_ERROR, Failed to set connection to the other database with cacheDbrcKey - #{genbConf.cacheDbrcKey.inspect} \n #{err}"
      end
      begin
        retVal = dbu.selectApiRespById(cacheId)
      rescue => err
        raise "CACHE_GET_ERROR, Failed to get record for the cache resource path - #{cachePath.inspect}. \n #{err}"
      end
     return retVal
    end

    # Puts a cache record with the response object and other associated column values into the apiRespCache table
    # @param [String] apiResp Response as cached from BRL::Genboree::REST::EM::DeferrableBodies::DeferrableKbDocsBody
    # @param [String] editTimeOrVersion Last edit time of the collection or doc (version) of interest
    # @param [Hash] secNvPairs hash with name-value pairs of additional parameters associated with the resource path
    # @return [boolean] recordInserted
    def putapiCache(apiResp, editTimeOrVersion, secNvPairs={})
      recordInserted = true
      #1. Get the ordered query string including the secondary keys (if any)
      normalizedNvPairs = normalizeEnvPairs()
      orderedQueryString = buildOrderedQueryStr(normalizedNvPairs, secNvPairs)
      #2. Build the id for the record
      md5 = Digest::MD5.new
      cachePath = "#{@resPath}?#{orderedQueryString}&versionId=#{CGI.escape(editTimeOrVersion)}"
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "CachePath - #{cachePath.inspect}")
      cacheId = md5.hexdigest(cachePath)
      #3. connect to the database
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
      cacheDbrcKey = genbConf.cacheDbrcKey
      begin
        dbu.setNewOtherDb(cacheDbrcKey)
      rescue => err
         recordInserted = false
         raise "CACHE_DB_ERROR, Failed to set connection to the other database with cacheDbrcKey - #{genbConf.cacheDbrcKey.inspect} \n #{err}"
      end
      # once connected insert the rec
      # make secKey string
      secKey = ""
      seckeyList = []
      unless(secNvPairs.empty?)
        secNvPairs.each_key { |kk| seckeyList << "#{CGI.escape(kk)}=#{CGI.escape(secNvPairs[kk])}" }
        secKey = seckeyList.join("&")
      end
      begin
        dbu.insertRespCache(cacheId, cachePath, editTimeOrVersion, apiResp, secKey,  nil)
      rescue => err
         recordInserted = false
        raise "CACHE_PUT_ERROR, Failed to insert record for the cache resource path #{cachePath.inspect} .\n #{err}"
      end
      return recordInserted
    end

    # HELPER METHODS
    
    # Normalizes @apiCacheparams - Hash of all the name-value pairs provided in the request URI by removing gbTime, gbToken, etc
    # @return [Hash] retVal normalized name-value pairs
    def normalizeEnvPairs()
      retVal = {}
      unless(@apiCacheparams.empty?)
        retVal = Marshal.load(Marshal.dump(@apiCacheparams))
        # _dc is the parameter found in ajax request coming from extjs, a browser cache deactivating attribute.
        # This could appear in instances and is dynamic in every instance of the request made.
        ["gbTime", "gbToken", "gbLogin", "_dc"].each{ |keyToBeRemoved|
          retVal.delete(keyToBeRemoved) if(retVal.key?(keyToBeRemoved))
        }
      end
      return retVal
    end

    # Builds the querystring that forms the part of the apicache path
    # @param [Hash] normNvPairs hash that has the normalized @apiCacheparams. @see normalizeEnvPairs
    # @param [Hash] secPairs hash that has additional name-value pairs associated specifically with the 
    #   resource path
    def buildOrderedQueryStr(normNvPairs, secPairs={})
      retVal = ""
      pairKeys = []
      retValList = []
      # hash that has both normNvPairs and secPairs
      completeNvPairs = {}
      if(normNvPairs.is_a?(Hash) and secPairs.is_a?(Hash))
        completeNvPairs = normNvPairs.merge(secPairs)
        pairKeys = completeNvPairs.keys()
        #CGI escaped
        pairKeys.sort.each{|kk| 
          value = completeNvPairs[kk].is_a?(Array) ? completeNvPairs[kk].sort.join(",") : completeNvPairs[kk]
          retValList << "#{CGI.escape(kk)}=#{CGI.escape(value)}" 
        }
        retVal = retValList.join("&")
      end
      return retVal
    end

  end
end; end; end; end
