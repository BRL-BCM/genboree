require 'cgi'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require "brl/genboree/genboreeUtil"
require 'brl/genboree/genboreeContext'
require "brl/genboree/rest/apiCaller"
require 'brl/genboree/abstract/resources/user'
require "brl/genboree/rest/helpers/databaseApiUriHelper"
require 'mechanize'


module BRL;module Genboree;module GeneViewer
  class GBTrackUtil
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    ENTITY2STRINGS = {
      :trk =>         { :apiSingular => "trk", :apiPlural => "trks", :labelSingular => "track", :labelPlural => "tracks" },
      :sample =>      { :apiSingular => "sample", :apiPlural => "samples", :labelSingular => "sample", :labelPlural => "samples" },
      :study =>       { :apiSingular => "study", :apiPlural => "studies", :labelSingular => "study", :labelPlural => "studies" },
      :run =>         { :apiSingular => "run", :apiPlural => "runs", :labelSingular => "run", :labelPlural => "runs" },
      :experiment =>  { :apiSingular => "experiment", :apiPlural => "experiments", :labelSingular => "experiment", :labelPlural => "experiments" },
      :publication => { :apiSingular => "publication", :apiPlural => "publications", :labelSingular => "publication", :labelPlural => "publications" },
      :anno =>        { :apiSingular => "anno", :apiPlural => "annos", :labelSingular => "anno", :labelPlural => "annos" }
    }
    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------
    attr_accessor :rackEnv
    attr_accessor :machineNameAlias
    attr_accessor :entityType

    def initialize(authMap=nil)
      @authMap = authMap
      getCredentials()
      @rackEnv = nil
      @machineNameAlias = nil
      @dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new("")
    end
    
    def getCredentials
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @dbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
    end

    def createTwoLevelHierarchy(entityAttrList)
      hierHash = Hash.new { |hh, kk| hh[kk] = Hash.new { |jj, mm| jj[mm] = [] } }
      entityAttrList.each { |tt|
        hierHash[tt[0]][tt[1]] << tt[2 .. -1]
      }
      return hierHash
    end
    
    def getDbUriGbKey(dbUri)
      return getGbKey(@dbHelper.extractHost(dbUri),@dbHelper.grpApiUriHelper.extractName(dbUri),@dbHelper.extractName(dbUri))
    end
    
    #def getGbKey(host, grp, db)
    #  getCredentials()
    #  grpPath = "/REST/v1/grp/#{CGI.escape(grp)}"
    #  dbPath = "#{grpPath}/db/#{CGI.escape(db)}"
    #  apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{grpPath}/unlockedResources", @dbrc.user, @dbrc.password)
    #  apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
    #  apiCaller.get
    #  if(apiCaller.succeeded?)
    #    apiCaller.parseRespBody
    #    apiCaller.apiDataObj.each { |hh|
    #      if(URI.parse(hh["url"]).path == dbPath) then return hh["key"] end
    #    }
    #    return nil
    #  else
    #    $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} Unable to get unlocked resources from #{host}/grp/#{grp}/db/#{db}\n#{apiCaller.respBody}")
    #    return nil
    #  end
    #end
    
    def getGbKey(host, grp, db)
      dbPath = "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/gbKey"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, dbPath, @authMap)
      apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
      apiCaller.get
      if(apiCaller.succeeded?)
        apiCaller.parseRespBody
        return apiCaller.apiDataObj["text"]
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} Unable to get gbKey for #{host}/grp/#{grp}/db/#{db}\n#{apiCaller.respBody}")
        return nil
      end
    end
    
    def getMultiSortOrder(dbList, rankTable, sortHash)
      
      maxRank = 0
      countBase = 0
      dbList.each { |dd|
        rsrcPath = "#{@dbHelper.extractPath(dd)}/{rankTable}?#{URI.parse(dd).query}&detailed=true"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(dd), rsrcPath, @authMap)
        apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
        apiCaller.get(:rankTable => rankTable)
        if(apiCaller.succeeded?) then
          apiCaller.parseRespBody()
          apiCaller.apiDataObj.each { |dd|
            nRank = dd["avpHash"]["gbRank"]
            if(sortHash.has_key?(dd["name"]) and nRank =~ /\d+/ and sortHash[dd["name"]].to_i < 0)
              nRank = nRank.to_i
              sortHash[dd["name"]] = countBase + nRank
              maxRank = nRank if(maxRank < nRank)
            end
          }
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR",apiCaller.respBody)
          
        end
        countBase = maxRank
      }
      return sortHash
    end

    def getSortOrder(host,grp,db,rankTable,sortHash)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/{rankTable}?detailed=true", @dbrc.user, @dbrc.password) #TD
      apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
      apiCaller.get(:rankTable => rankTable)
      if(apiCaller.succeeded?)
        apiCaller.parseRespBody()
        apiCaller.apiDataObj.each { |dd|
          if(sortHash.has_key?(dd["name"]) and dd["avpHash"]["gbRank"]=~/\d+/)
            sortHash[dd["name"]] = dd["avpHash"]["gbRank"]
          end
        }
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} Unable to get sort orders from /grp/#{@grp}/db/#{@db}\n#{apiCaller.respBody}")
      end
      return sortHash
    end

    def cgiVarValue(cgiHash, varName, defaultValue)
      if(cgiHash[varName].nil? or cgiHash[varName].empty?)
        return defaultValue
      else
        return CGI.unescape(cgiHash[varName].strip)
      end
    end

    def sortedMerge(sortHash)
      pvals = sortHash.select{|k,v| v.to_i > 0}.sort{|a,b| a[1].to_i<=>b[1].to_i}.map{|xx| xx[0]}
      nvals = sortHash.select{|k,v| v.to_i < 0}.sort{|a,b| a[1].to_i<=>b[1].to_i}.map{|xx| xx[0]}
      return pvals+nvals
    end

    def getVersionForDB(dbURI)
      
      rsrcPath = "#{@dbHelper.extractPath(dbURI)}/version?#{URI.parse(dbURI).query}"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(dbURI), rsrcPath, @authMap)
      apiCaller.get
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        return apiCaller.apiDataObj["text"]
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} apiCaller could not get version for #{dbURI}\n#{apiCaller.respBody}")
        return(nil)
      end
    end

    # ARJ: now uses generic version (getAttrMapApiCaller()) to do actual work ; present ofr backward-compatibility only
    def getAllTracks(host, grp, db, attrList, minNum=nil)
      return getAttrMapApiCaller(:trk, host, grp, db, attrList, minNum)
    end

    # ARJ: generic version of getAllTracks()
    # Core method, many methods below make use of this
    def getAttrMapApiCaller(entityType, host, grp, db, attrList, minNum=nil)
      minNum = attrList.length if(minNum.nil?)
      entStr = ENTITY2STRINGS[entityType][:apiPlural]
      rsrcPath = "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/{entStr}/attributes/map?attributeList={attrList}&minNumAttributes={minNum}"
      #apiCaller = BRL::Genboree::REST::ApiCaller.new(host, rsrcPath, @dbrc.user, @dbrc.password)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, rsrcPath, @authMap)
      apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
      apiCaller.get( { :entStr => entStr, :attrList => attrList, :minNum => minNum})
      return apiCaller
    end

    # ARJ: generic version of arrangeTracks()
    def arrangeEntities(attrList, entities)
      entityList = Array.new()
      entities.each { |tt|
        tempHash = Hash.new()
        avps = tt[1]
        attrList.each { |aa|
          tempHash[aa] = avps[aa]
        }
        tempHash["name"] = tt[0]
        entityList << tempHash
      }
      return entityList
    end
    alias :arrangeTracks :arrangeEntities # ARJ: now uses generic version (arrangeEntities()) ; present for backward-compatibility only

    # ARJ: generic version of arrageTracksMulti()
    def arrangeEntitiesMulti(attrList, entries)
      entityList = Hash.new()
      entries.each_key { |db|
        entityList[db] = Hash.new
        entries[db].each { |tt|
          entityList[db][tt[0]] = Hash.new
          avps = tt[1]
          attrList.each { |aa|
            entityList[db][tt[0]][aa] = avps[aa]
          }
        }
      }
      return entityList
    end
    alias :arrangeTracksMulti :arrangeEntitiesMulti

    # ARJ: now uses generic version to do actual work ; present for backward-compatibility only
    def getTrackListAttributes(host,grp, db, trackNames, attrNames)
      return getEntityListAttributes(:trk, host, grp, db, trackNames, attrNames)
    end

    # ARJ: generic version of getTrackListAttributes()
    def getEntityListAttributes(entityType, host, grp, db, entityNames, attrNames)
      entityNames = [entityNames] if(!entityNames.is_a?(Array))
      attrNames = [attrNames] if(!attrNames.is_a?(Array))
      apiCaller = getAttrMapApiCaller(entityType, host, grp, db, attrNames, 0)
      results = []
      if(apiCaller.succeeded?)
        apiCaller.parseRespBody
        entityNames.each { |tt|
          temp = [tt]
          avps = apiCaller.apiDataObj[tt]
          attrNames.each { |aa|
            temp << avps[aa]
          }
          results << temp
        }
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} apiCaller could not get entities details from grp #{grp} and db #{db}\n#{apiCaller.respBody}")
      end
      return results
    end
    

    def getDatabaseAttributes(dbList, attrList,minNum=nil)
      results =[]
      dbList = [dbList] if(!dbList.is_a?(Array))
      attrList = [attrList] if(!attrList.is_a?(Array))
      if(minNum.nil?) then minNum = attrList.length end
      dbList.each { |db|
        rsrcPath = "#{@dbHelper.extractPath(db)}/attributes/map?attributeList={attrList}&minNumAttributes={minNum}"        
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(db), rsrcPath, @authMap)
        apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
        apiCaller.get({ :attrList => attrList, :minNum => minNum})
        if(apiCaller.succeeded?)
          apiCaller.parseRespBody
          results << apiCaller.apiDataObj.entries.first[1]
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR",apiCaller.respBody)          
        end
      }
      return results
    end
    
    def getDBDescriptions(dbList)
      dbDescs = []
      dbList.each { |db|
        dbDescs << getDBDescription(db)
      }
      return dbDescs
    end
    
    def getDBDescription(db)
        result = nil
        rsrcPath = "#{@dbHelper.extractPath(db)}/description?#{URI.parse(db).query}"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(db), rsrcPath, @authMap)
        apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
        apiCaller.get()
        if(apiCaller.succeeded?)
          apiCaller.parseRespBody
          result = apiCaller.apiDataObj["text"]
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR",apiCaller.respBody)
        end
      return result
    end
    
    # ARJ: now uses generic version ; present for backward-compatibility only
    def getAllTracksAndValues(host, grp, db, attrList, attrValueList=nil)
      return getAllEntitiesAndValues(:trk, host, grp, db, attrList, attrValueList)
    end

    def getAllEntitiesAndValues(entityType, host, grp, db, attrList, attrValueList=nil)
      retVal = nil
      apiCaller = getAttrMapApiCaller(entityType, host, grp, db, attrList)
      if(apiCaller.succeeded?)
        apiCaller.parseRespBody
        if(attrValueList.nil? or attrValueList.empty?)
          retVal = arrangeEntities(attrList, apiCaller.apiDataObj.entries)
        else
          entityList = []
          apiCaller.apiDataObj.each { |aa|
            entityList << aa if(attrValueList.include?(attrList.map{ |xx| aa[1][xx]} ))
          }

          retVal =  arrangeEntities(attrList, entityList)
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} apiCaller could not get entity details from grp #{grp} and db #{db}\n#{apiCaller.respBody}")
        retVal = nil
      end
      return retVal
    end

    # ARJ: now uses generic version ; present for backward-compatibility only
    def getTrackListAttributesMulti(db, trackNames, attrNames)
      return getEntityListAttributesMulti(:trk, db, trackNames, attrNames)
    end

    # ARJ: generic version fo getTrackListAttributesMulti()
    def getEntityListAttributesMulti(entityType, db, entityNames, attrNames)
      entityNames = [entityNames] if(!entityNames.is_a?(Array))
      attrNames = [attrNames] if(!attrNames.is_a?(Array))
      entityList = getAllEntitiesAndValuesMulti(entityType, [db], attrNames)
      results = {}
      entityNames.each { |tt|
        results[tt] = entityList[db][tt]
      }
      return results
    end

    # ARJ: now uses generic version to do actual work ; presnet for backward-compatibility only
    def getAllTracksMulti(dbList, attrList, minNum=nil)
      return getAllEntitiesMulti(:trk, dbList, attrList, minNum)
    end
    
    
    
    # ARJ: generic version of getAllTracksMulti()
    def getAllEntitiesMulti(entityType, dbList, attrList, minNum=nil)
      minNum = attrList.length if(minNum.nil?)
      entStr = ENTITY2STRINGS[entityType][:apiPlural]
      
      entityList = Hash.new() { |hh,kk| hh[kk] = [] }
      dbList.each { |db|
        rsrcPath = "#{@dbHelper.extractPath(db)}/{entStr}/attributes/map?#{URI.parse(db).query}&attributeList={attrList}&minNumAttributes={minNum}"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(db), rsrcPath, @authMap)
        apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
        apiCaller.get( {:attrList => attrList, :minNum => attrList.length, :entStr => entStr } )
        if(apiCaller.succeeded?)
          jp = JSON.parse(apiCaller.respBody)
          entityList[db] = jp["data"].entries
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR",apiCaller.respBody)
        end
      }
      
      return entityList
    end



    # ARJ: this original assumed we wanted track attributes only.
    # ARJ: now makes use of a generic version
    def getAllAttrValues(host, grp, db, attrName)
      return getAllAttrValuesForEntityType(:trk, host, grp, db, attrName)
    end

    # ARJ: generic version of getAllAttrValues()
    def getAllAttrValuesForEntityType(entityType, host, grp, db, attrName)
      retVal = nil
      apiCaller = getAttrMapApiCaller(entityType, host, grp, db, [attrName])
      valueHash = Hash.new(0)
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        apiCaller.apiDataObj.entries.each { |tt|
          valueHash[tt[1][attrName]] += 1
        }
        retVal = valueHash.keys
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} apiCaller could not get attrValues from grp #{grp} and db #{db} for attribute #{attrName}\n#{apiCaller.respBody}")
        retVal = nil
      end
      return retVal
    end

    def getEntityByAttrValueFromDB(entityType,dbURI,attrNames,attrValues)
      if(!attrNames.is_a?(Array)) then attrNames = attrNames.split(/,/) end
      if(!attrValues.is_a?(Array)) then attrValues = attrValues.split(/,/) end
      eav = getAllEntitiesAndValuesMulti(entityType, [dbURI], attrNames, [attrValues])
      dbPrefix = "#{@dbHelper.extractPureUri(dbURI)}"
      dbSuffix = URI.parse(dbURI).query
      if(!eav.nil? and eav.has_key?(dbURI)) then
        return eav[dbURI].keys.map{|xx| "#{dbPrefix}/trk/#{CGI.escape(xx)}?#{dbSuffix}"}
      else
        return nil
      end
    end
    # ARJ: this original assumed we wanted track attributes only.
    # ARJ: now makes use of a generic version
    def getAllAttrValuesMulti(dbList, attrName)
      return getAllAttrValuesMultiForEntityType(:trk, dbList, attrName)
    end

    # ARJ: generic version of getAllAttrValuesMulti()
    def getAllAttrValuesMultiForEntityType(entityType, dbList, attrName)
      entityList = getAllEntitiesMulti(entityType, dbList, [attrName])
      valueHash = Hash.new(0)
      entityList.each_key { |db|
        entityList[db].each { |aa|
          valueHash[aa[1][attrName]] += 1
        }
      }
      return valueHash.keys
    end

    # ARJ: now makes use of a generic version
    def getAllTracksAndValuesMulti(dbList, attrList, attrValueList=nil)
      return getAllEntitiesAndValuesMulti(:trk, dbList, attrList, attrValueList)
    end

    # ARJ: generic version of
    def getAllEntitiesAndValuesMulti(entityType, dbList, attrList, attrValueList=nil)      
      entityList = getAllEntitiesMulti(entityType, dbList, attrList, attrList.length)      
      filterList = nil
      if(attrValueList.nil? or attrValueList.empty?)
        filterList = entityList
      else
        filterList = {}
        entityList.each_key { |db|
          filterList[db] = []
          entityList[db].each { |aa|            
            if(attrValueList.include?(attrList.map{|xx| aa[1][xx]}))
              filterList[db] << aa
            end
          }
        }
      end
      return arrangeTracksMulti(attrList,filterList)
    end

    def getTracksForSamples(sampleNameList,trackdbList,trackAttrName)
      trackDetails = getAllEntitiesAndValuesMulti(:trk, trackdbList, [trackAttrName])
      
      results = Hash.new{ |hh,kk| hh[kk] = [] }
      trackDetails.each_key{|db|
        dbq = URI.parse(db).query
        trackDetails[db].each_key{|entity|
          sampleName = trackDetails[db][entity][trackAttrName]
          if(sampleNameList.member?(sampleName)) then
            results[sampleName] << "#{@dbHelper.extractPureUri(db)}/trk/#{CGI.escape(entity)}?#{dbq}"
          end
        }
      }
      return results
    end

    # ------------------------------------------------------------------
    # Very track-specific methods. Mainly for EDACC specific support right now.
    # ------------------------------------------------------------------
    # grid specific
    def getGroupedTracks(host, grp,db,attrList,attrValueList,groupByAttrs =[],outputAttrs=[])
      #getGroupedTracks
      outputList = {}
      if(groupByAttrs.empty?) then
        groupByAttrs = attrList
      else
        groupByAttrs = attrList+groupByAttrs
      end
      if(outputAttrs.empty?) then outputAttrs = ["geoAccession"] end
      queryAttrs = groupByAttrs+outputAttrs
      apiCaller = getAllTracks(host, grp,db,queryAttrs,groupByAttrs.length)
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        apiCaller.apiDataObj.each{|tt|
          trackName = tt[0]
          attrHash = tt[1]
          valueList = attrList.map{|xx| attrHash[xx]}
          if(attrValueList.member?(valueList)) then
            prevHash = outputList
            groupByAttrs.each{|xx|
              if(!prevHash.has_key?(attrHash[xx])) then prevHash[attrHash[xx]] = Hash.new end
              prevHash = prevHash[attrHash[xx]]
            }
            prevHash[trackName] = {}
            outputAttrs.each{|xx| prevHash[trackName][xx] = attrHash[xx]}
          end
        }
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","#{Time.now} apiCaller could not get track attribute values from grp #{grp} and db #{db}\n#{apiCaller.respBody}")
      end
      return outputList
    end
    
    # grid specific
    def renderMetadata(resultList, classNames,trackNames = [])
      geoPrefix = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc="
      buff = StringIO.new
      buff << "<ul>"
      resultList.keys.sort{|aa,bb| aa.to_s.downcase <=> bb.to_s.downcase}.each{|kk|
        cl = 0
        buff << "<li><span class=\"#{classNames[cl]}\">#{kk}</span></li>\n"
        assay = resultList[kk]
        assay.keys.sort{|aa,bb| aa.to_s.downcase <=> bb.to_s.downcase}.each{|ll|
          cl = 1
          buff << "<li><span class=\"#{classNames[cl]}\">#{ll}</span></li>\n"
          source = assay[ll]
          source.keys.sort{|aa,bb| aa.to_s.downcase <=> bb.to_s.downcase}.each{|mm|
            cl = 2
            buff << "<li><span class=\"#{classNames[cl]}\">#{mm}</span></li>\n"
            type = source[mm]
            type.keys.sort{|aa,bb| aa.to_s.downcase <=> bb.to_s.downcase}.each{|tt|
              if(trackNames.empty? or trackNames.member?(tt)) then
                cl = 3
                buff << "<li><span class=\"#{classNames[cl]}\">#{tt}&nbsp;&nbsp;"
                geoId = type[tt]
                if(geoId["geoAccession"].nil? or geoId["geoAccession"].empty?) then
                  buff << " - Coming soon!"
                else
                  buff << " - <a href=\"#{geoPrefix}#{geoId["geoAccession"]}\">#{geoId["geoAccession"]}</a>"
                end
                buff << "</span></li>\n"
              end
            }
          }
        }
      }
      buff << "</ul>"
      return buff.string
    end
    
    # Get values of specified attributes from resp. databases.
    # nil if attribute doesn't exist for any track. Only tracks which have all the attributes present will be returned. Tracks are not pre-specified
    # return format is {db =>[{trkName=>{attrName=>attrVal}}]}
    # e.g. gb.getTracksFromAttrList(["http://10.15.5.109/REST/v1/grp/raghuram_group/db/datafreeze4"],["eaSampleType","eaAssayType"])
    def getTracksFromAttrList(dbList,attrList)
      returnHash = {}
      dbList.each {|db|
        rsrcPath = "#{@dbHelper.extractPath(db)}/trks/attributes/map?#{URI.parse(db).query}&attributeList={attrList}&minNumAttributes={minNum}"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@dbHelper.extractHost(db), rsrcPath, @authMap)
        apiCaller.initInternalRequest(@rackEnv, @machineNameAlias) if(@rackEnv)
        apiCaller.get({:attrList => attrList, :minNum => attrList.length})
        if(apiCaller.succeeded?)
       apiCaller.parseRespBody()
          returnHash[db] = apiCaller.apiDataObj
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR",apiCaller.respBody)
        end
      }
      return returnHash
    end
    
    # Get tracks certain values for certain attributes. Only tracks whose values for all attributes match the supplied value tuples will be returned.attrVals is an array of arrays
    # returned attrValues are in same order as supplied attrList
    # return format is {db =>[{trkName=>[attrVals]}]}
    # e.g. gb.getTracksByAttrValues(["http://10.15.5.109/REST/v1/grp/raghuram_group/db/datafreeze4"],["eaAssayType","eaSampleType"],[["DNase Hypersensitivity","Fetal Thymus"]])
    def getTracksByAttrValues(dbList,attrList,attrVals)
      result = getTracksFromAttrList(dbList,attrList)
      returnHash = {}
      result.each_key{|db|
        returnHash[db] = {}
        result[db].each_key{|track|
          currList = attrList.map{|xx| result[db][track][xx]}
          if(attrVals.include?(currList)) then
            returnHash[db][track] = currList
          end
          }
        }
      return returnHash
    end
    
    def getTrackGrid(dbList,xattr,yattr)
      result = getTracksFromAttrList(dbList,[xattr,yattr])
      xc = -1; yc =-1;
      xind = Hash.new;yind = Hash.new
      xvals = [];yvals = [];
      grid = []
      result.each_key{|db|
        result[db].each_key{|track|
          xval = result[db][track][xattr]
          yval = result[db][track][yattr]
          if(!xind.has_key?(xval)) then xc+=1; xind[xval] = xc; xvals << xval end
          if(!yind.has_key?(yval)) then yc+=1; yind[yval] = yc; yvals << yval end
          if(grid[yind[yval]].nil?) then grid[yind[yval]] = [] end
          if(grid[yind[yval]][xind[xval]].nil?) then grid[yind[yval]][xind[xval]] = 0; end
          grid[yind[yval]][xind[xval]] += 1
          }
        }
      puts grid.inspect
    end

  end
end;end;end
