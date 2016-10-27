require 'cgi'
require 'uri'
require 'open-uri'
require 'brl/util/util'
require "brl/genboree/genboreeUtil"
require 'brl/genboree/genboreeContext'
require "brl/genboree/rest/apiCaller"
require "brl/genboree/rest/helpers/databaseApiUriHelper"
require 'mechanize'


module BRL;module Genboree;module GeneViewer;
  class GBTrackUtil

    def self.createTwoLevelHierarchy(trackAttrList)
      hierHash = Hash.new
      trackAttrList.each{|tt|
        hierHash[tt[0]] = {} unless hierHash.has_key?(tt[0])
        hierHash[tt[0]][tt[1]] = [] unless hierHash[tt[0]].has_key?(tt[1])
        hierHash[tt[0]][tt[1]] << tt[2 .. -1]
      }
      return hierHash
    end

    def self.getGbKey(host,grp,db)
      self.getCredentials
      grpPath = "/REST/v1/grp/#{CGI.escape(grp)}"
      dbPath = "#{grpPath}/db/#{CGI.escape(db)}"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host,
      "#{grpPath}/unlockedResources",
      @dbrc.user,
      @dbrc.password)
      apiCaller.get
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        apiCaller.apiDataObj.each{|hh|
          if(URI.parse(hh["url"]).path == dbPath) then return hh["key"] end
        }
        return nil
      else
        $stderr.puts "#{Time.now} Unable to get unlocked resources from #{host}/grp/#{grp}/db/#{db}\n#{apiCaller.respBody}"
        return nil
      end
    end

    def self.getMultiSortOrder(dbList,rankTable, sortHash)
      self.getCredentials
      dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new("")
      maxRank = 0
      countBase = 0
      dbList.each{|dd|
        rsrcPath = "#{dbHelper.extractPath(dd)}/{rankTable}?#{URI.parse(dd).query}&detailed=true"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(dbHelper.extractHost(dd),rsrcPath, @dbrc.user,@dbrc.password)
        apiCaller.get(:rankTable => rankTable)
        if(apiCaller.succeeded?) then
          apiCaller.parseRespBody();
          apiCaller.apiDataObj.each{|dd|
            nRank = dd["avpHash"]["gbRank"]
            if(sortHash.has_key?(dd["name"]) and nRank =~ /\d+/ and sortHash[dd["name"]].to_i < 0) then
              nRank = nRank.to_i
              sortHash[dd["name"]] = countBase + nRank
              if(maxRank < nRank) then maxRank = nRank end
            end
          }
        end
        countBase = maxRank
      }
      return sortHash
    end


    def self.getSortOrder(host,grp,db,rankTable, sortHash)
      self.getCredentials
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host,
      "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/{rankTable}?detailed=true",
      @dbrc.user,
      @dbrc.password) #TD
      apiCaller.get(:rankTable => rankTable)
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody();
        apiCaller.apiDataObj.each{|dd|
          if(sortHash.has_key?(dd["name"]) and dd["avpHash"]["gbRank"]=~/\d+/) then
            sortHash[dd["name"]] = dd["avpHash"]["gbRank"]
          end
        }
      else
        $stderr.puts "#{Time.now} Unable to get sort orders from /grp/#{grp}/db/#{db}\n#{apiCaller.respBody}"
      end
      return sortHash
    end

    def self.cgiVarValue(cgiHash,varName,defaultValue)
      if(cgiHash[varName].nil? or cgiHash[varName].empty?) then
        return defaultValue
      else
        return CGI.unescape(cgiHash[varName].strip)
      end
    end

    def self.sortedMerge(sortHash)
      pvals = sortHash.select{|k,v| v.to_i > 0}.sort{|a,b| a[1].to_i<=>b[1].to_i}.map{|xx| xx[0]}
      nvals = sortHash.select{|k,v| v.to_i < 0}.sort{|a,b| a[1].to_i<=>b[1].to_i}.map{|xx| xx[0]}
      return pvals+nvals
    end

    def self.getCredentials
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      #@dbrc = BRL::DB::DBRC.new(@genbConf.dbrcFile, "API:#{@genbConf.machineName}")
      @dbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      @dbrc.user = @dbrc.user.dup.untaint
      @dbrc.password = @dbrc.password.dup.untaint
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{@dbrc.user} #{@dbrc.password}")
    end


    def self.getTrackListAttributes(host,grp, db, trackNames, attrNames)
      if(!trackNames.is_a?(Array)) then trackNames = [trackNames]; end
      if(!attrNames.is_a?(Array)) then attrNames = [attrNames]; end
      self.getCredentials
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host,
      "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/trk/{trk}/attribute/{attribute}/value",@dbrc.user,@dbrc.password)
      results = []
      trackNames.each{|tt|
        temp = [tt]
        attrNames.each{|aa|
          apiCaller.get(:trk=>tt,:attribute=>aa)
          if(apiCaller.succeeded?) then
            apiCaller.parseRespBody
            temp << apiCaller.apiDataObj["text"]
          else
            $stderr.puts "#{Time.now} apiCaller could not get track details from grp #{grp} and db #{db}\n#{apiCaller.respBody}"
            temp << nil
          end
        }
        results <<temp
      }
      return results
    end

    def escapeTrackURL(track)
      tHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new
      tName =  tHelper.extractName(track)
      grpName = tHelper.grpApiUriHelper.extractName(track)
      dbName = tHelper.dbApiUriHelper.extractName(track)
      tPath = tHelper.extractPath(track)
      tPath.gsub!(/grp\/[^\/]+\//,"grp/#{CGI.escape(grpName)}/")
      tPath.gsub!(/db\/[^\/]+\//,"db/#{CGI.escape(dbName)}/")
      tPath.gsub!(/track\/[^\/]+\//,"track/#{CGI.escape(tName)}/")
      return "http://#{tHelper.extractHost}#{tPath}"
    end



    def self.getGroupedTracks(host, grp,db,attrList,attrValueList,groupByAttrs =[],outputAttrs=[])
      #getGroupedTracks
      self.getCredentials
      outputList = {}
      if(groupByAttrs.empty?) then groupByAttrs = attrList
      else
        groupByAttrs = attrList+groupByAttrs
      end
      if(outputAttrs.empty?) then outputAttrs = ["geoAccession"] end
      queryAttrs = groupByAttrs+outputAttrs
      apiCaller = self.getAllTracks(host, grp,db,queryAttrs,groupByAttrs.length)
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
            outputAttrs.each{|xx| prevHash[trackName][xx] = attrHash[xx]}#self.getTrackListAttributes(host,grp, db, [trackName],xx)[0][1]}
            #outputList << outputAttrs.map{|xx| tt[1][xx]} + [tt[0]]
          end
        }
      else
        $stderr.puts "#{Time.now} apiCaller could not get track attribute values from grp #{grp} and db #{db}\n#{apiCaller.respBody}"
      end
      return outputList
    end

    def self.renderMetadata(resultList, classNames,trackNames = [])
      geoPrefix = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc="
      buff = StringIO.new
      buff << "<ul>"
      resultList.keys.sort.each{|kk|
        cl = 0
        buff<< "<li><span class=\"#{classNames[cl]}\">#{kk}</span></li>\n"
        ch = resultList[kk]
        ch.keys.sort.each{|ll|
          cl = 1
          buff<< "<li><span class=\"#{classNames[cl]}\">#{ll}</span></li>\n"
          ch = resultList[kk][ll]
          ch.keys.sort.each{|mm|
            cl = 2
            ch = resultList[kk][ll][mm]
            buff<< "<li><span class=\"#{classNames[cl]}\">#{mm}</span></li>\n"
            ch.keys.sort.each{|tt|
              if(trackNames.empty? or trackNames.member?(tt)) then
              cl = 3
              buff<< "<li><span class=\"#{classNames[cl]}\">#{tt}&nbsp;&nbsp;"
              ch = resultList[kk][ll][mm][tt]
              if(ch["geoAccession"].nil? or ch["geoAccession"].empty?) then
                buff << " - Coming soon!"
              else
                buff << " - <a href=\"#{geoPrefix}#{ch["geoAccession"]}\">#{ch["geoAccession"]}</a>"
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


    def self.arrangeTracksMulti(attrList,trackEntries)
      trackHash = Hash.new()
      trackList = Array.new()
      attrList.each{|aa| trackHash[aa] = Hash.new(0)}
      trackEntries.each_key{|db|
        trackEntries[db].each{|tt|
        tempHash = Hash.new()
        avps=tt[1]
        attrList.each{|aa|
          trackHash[aa][avps[aa]] += 1
          tempHash[aa] = avps[aa]
        }
        tempHash["name"] = tt[0]
        tempHash["db"] = db
        trackList << tempHash
        }
      }
      trackHash["tracks"] = trackList

      return trackHash
    end



    def self.arrangeTracks(attrList,trackEntries)
      trackList = Array.new()
      trackEntries.each{|tt|
        tempHash = Hash.new()
        avps=tt[1]
        attrList.each{|aa|
          tempHash[aa] = avps[aa]
        }
        tempHash["name"] = tt[0]
        trackList << tempHash
      }
      return trackList
    end

    def self.getAllTracks(host, grp,db,attrList,minNum = nil)
      self.getCredentials
      rsrcPath = "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/trks/attributes/map?attributeList={attrList}&minNumAttributes={minNum}"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host,rsrcPath,@dbrc.user,@dbrc.password)
      if(minNum.nil?) then minNum = attrList.length end
      apiCaller.get({:attrList=>attrList,:minNum=>minNum})
      return apiCaller
    end

    def self.getAllAttrValues(host, grp,db,attrName)

      apiCaller = self.getAllTracks(host, grp,db,[attrName])
      valueHash = Hash.new(0)
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        apiCaller.apiDataObj.entries.each{|tt|
          valueHash[tt[1][attrName]] += 1
        }
        return valueHash.keys
        else
          $stderr.puts "#{Time.now} apiCaller could not get attrValues from grp #{grp} and db #{db} for attribute #{attrName}\n#{apiCaller.respBody}"
        return nil
        end
    end

    def self.getAllTracksAndValues(host, grp,db,attrList, attrValueList=nil)
      #getAllTracksAndValues
      self.getCredentials
      apiCaller = self.getAllTracks(host, grp,db,attrList)
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody
        if(attrValueList.nil? or attrValueList.empty?) then
          return(arrangeTracks(attrList,apiCaller.apiDataObj.entries))
        else
          trackList = []
          apiCaller.apiDataObj.each{|aa|
              if(attrValueList.include?(attrList.map{|xx| aa[1][xx]})) then trackList << aa end
            }
          return arrangeTracks(attrList,trackList)
        end
      else
        $stderr.puts "#{Time.now} apiCaller could not get track details from grp #{grp} and db #{db}\n#{apiCaller.respBody}"
        return nil
      end
    end
    #not done

    def self.getMultiAttrTracksAndValues(dbList,attrList, attrValueList=nil)
      self.getCredentials
      dbHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new("")
      trackList = Hash.new(){|h,k| h[k]=[]}
      dbList.each{|db|
        rsrcPath = "#{dbHelper.extractPath(db)}/trks/attributes/map?#{URI.parse(db).query}&attributeList={attrList}&minNumAttributes={minNum}"
        apiCaller = BRL::Genboree::REST::ApiCaller.new(dbHelper.extractHost(db),rsrcPath, @dbrc.user,@dbrc.password)
        apiCaller.get({:attrList=>attrList,:minNum=>attrList.length})
        if(apiCaller.succeeded?) then
          apiCaller.parseRespBody
          if(attrValueList.nil? or attrValueList.empty?) then
            trackList[db] = apiCaller.apiDataObj.entries
          else
            apiCaller.apiDataObj.each{|aa|
              if(attrValueList.include?(attrList.map{|xx| aa[1][xx]})) then trackList[db] << aa end
            }
          end
        end
      }
      return arrangeTracksMulti(attrList,trackList)
    end
  end
end;end;end
