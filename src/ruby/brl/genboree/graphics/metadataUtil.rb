require 'cgi'
require 'open-uri'
require 'brl/util/util'
require "brl/genboree/genboreeUtil"
require 'brl/genboree/genboreeContext'
require "brl/genboree/rest/apiCaller"
require 'mechanize'


module BRL;module Genboree;module Pathways;
  class MetadataUtil
    RemcMap={
    "BI"=>"Broad",
    "UCSD"=>"UCSD",
    "UCSF-UBC"=>"UCSF-UBC",
    "UCSF-UCD-UBC"=>"UCSF-UBC",
    "UW"=>"UW"
  }

  RemcGSMMap={
    "UCSD"=>"GSE16256",
    "UCSF-UBC"=>"GSE16368",
    "UCSF-UCD-UBC"=>"GSE16368",
    "UW"=>"GSE18927",
    "BI"=>"GSE17312"
  }

  ColumnMap=
  {
    "remc" => 0,
    "sample" => 1,
    "expt" => 2,
    "track" => 3,
    "gsm" => 4
  }

  GeoPrefix = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc="

  def self.checkMembers(inputArray,inputList)
   # $stderr.puts inputArray.inspect
    #$stderr.puts inputList.inspect
    resultArray = []
    inputArray.each_with_index{|elem, ii|
      if(!inputList[ii].nil?)
        resultArray << (inputList[ii].empty? or inputList[ii].member?(elem))
      else
        resultArray << true
      end

      }
    return !resultArray.member?(false)
  end



    def self.getTrackNameList(group,database,typeSubtypeArray)
      returnHash = {}
      genbConf = BRL::Genboree::GenboreeConfig.load()
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
      dbrc = suDbDbrc
      dbrc.user = dbrc.user.dup.untaint
      dbrc.password = dbrc.password.dup.untaint
      apiCaller = BRL::Genboree::REST::ApiCaller.new("genboree.org","/REST/v1/grp/{grp}/db/{db}/trks",dbrc.user,dbrc.password)
      hr = apiCaller.get({ :grp => group, :db => database})
      apiCaller.parseRespBody
      apiCaller.apiDataObj.each{|dataObj|
        if(dataObj["text"]!~/\sRC$/) then
        comboKey = dataObj["text"].gsub(/\s.*$/,"")
        unless !(typeSubtypeArray.member?(comboKey))
          returnHash[comboKey] = Array.new unless (returnHash.has_key?(comboKey))
          returnHash[comboKey] << dataObj["text"]
        end
        end
        }
      return returnHash
    end


    def self.getConcatMetadata(linesArray,gFieldNames,qFieldNames,qFieldVals,outputFields)
      gFieldCoords = gFieldNames.map{|xx| ColumnMap[xx]}
      qFieldCoords = qFieldNames.map{|xx| ColumnMap[xx]}
      returnHash = {}
      ## List of tracks
      linesArray.each{|line|
        splitLine = line.chomp.split(/\t/)
        #$stderr.puts "here #{splitLine[ColumnMap["track"]]}"
        vals = splitLine.values_at(*qFieldCoords)
        if(checkMembersConcat(vals,qFieldVals)) then
          splitLine[ColumnMap["remc"]] = RemcMap[splitLine[ColumnMap["remc"]]]
          splitLine[ColumnMap["track"]] = CGI.unescape(splitLine[ColumnMap["track"]])

          if(splitLine[ColumnMap["gsm"]] !~ /\S/) then
            splitLine[ColumnMap["gsm"]] = " - Coming Soon!"
          else
            splitLine[ColumnMap["gsm"]] = " - <a href=\"#{GeoPrefix}#{splitLine[ColumnMap["gsm"]]}\">#{splitLine[ColumnMap["gsm"]]}</a>"
          end
          outVals = splitLine
          outVals = splitLine.values_at(*(outputFields.map{|xx| ColumnMap[xx]})) unless (outputFields.empty?)
          keyVals = splitLine.values_at(*gFieldCoords)
          prevHash = returnHash
          keyVals[0 .. -2].each{|kk|
            prevHash[kk] = Hash.new unless (prevHash.has_key?(kk))
            prevHash = prevHash[kk]
          }
          #puts prevHash.inspect
          prevHash[keyVals[-1]] = [] unless prevHash.has_key?(keyVals[-1])
          prevHash[keyVals[-1]] << outVals
          #puts prevHash.inspect
        end
      }
      return returnHash
    end


    def self.getMetadata(linesArray,gFieldNames,qFieldNames,qFieldVals,outputFields)
      gFieldCoords = gFieldNames.map{|xx| ColumnMap[xx]}
      qFieldCoords = qFieldNames.map{|xx| ColumnMap[xx]}
      returnHash = {}
      ## List of tracks
      linesArray.each{|line|
        splitLine = line.chomp.split(/\t/)
        #$stderr.puts "here #{splitLine[ColumnMap["track"]]}"
        vals = splitLine.values_at(*qFieldCoords)
        if(checkMembers(vals,qFieldVals)) then
          splitLine[ColumnMap["remc"]] = RemcMap[splitLine[ColumnMap["remc"]]]
          splitLine[ColumnMap["track"]] = CGI.unescape(splitLine[ColumnMap["track"]])

          if(splitLine[ColumnMap["gsm"]] !~ /\S/) then
            splitLine[ColumnMap["gsm"]] = " - Coming Soon!"
          else
            splitLine[ColumnMap["gsm"]] = " - <a href=\"#{GeoPrefix}#{splitLine[ColumnMap["gsm"]]}\">#{splitLine[ColumnMap["gsm"]]}</a>"
          end
          outVals = splitLine
          outVals = splitLine.values_at(*(outputFields.map{|xx| ColumnMap[xx]})) unless (outputFields.empty?)
          keyVals = splitLine.values_at(*gFieldCoords)
          prevHash = returnHash
          keyVals[0 .. -2].each{|kk|
            prevHash[kk] = Hash.new unless (prevHash.has_key?(kk))
            prevHash = prevHash[kk]
          }
          #puts prevHash.inspect
          prevHash[keyVals[-1]] = [] unless prevHash.has_key?(keyVals[-1])
          prevHash[keyVals[-1]] << outVals
          #puts prevHash.inspect
        end
      }
      return returnHash
    end

    def self.getMetadataJSON(linesArray,fieldNames,fieldValues,outputFields)
      return self.getMetadata(linesArray,fieldNames,fieldValues,outputFields).to_json
    end

    def self.renderMetadata(linesArray,gfieldNames,qfieldNames,qfieldValues,outputFields, classNames)
      @classNames = classNames
      result = self.getMetadata(linesArray,gfieldNames,qfieldNames,qfieldValues,outputFields)
      @buff = StringIO.new
      @buff << "<ul>"
      fillBuff(result,0)
      @buff << "</ul>"
      return @buff.string
    end

    def self.fillBuff(coll, classNameIndex)
      if(coll.is_a?(Array)) then
        coll.each{|elem|
          @buff<< "<li><span class=\"#{@classNames[classNameIndex]}\">"
          elem.each{|item|
            @buff << " #{CGI.unescape(item)} "
            }
          @buff << "</span></li>\n"
          }
      else
        coll.keys.sort.each{|key|
          @buff<< "<li><span class=\"#{@classNames[classNameIndex]}\">#{key}</span></li>\n"
          fillBuff(coll[key],classNameIndex+1)
        }
      end
    end


  end

end;end;end
