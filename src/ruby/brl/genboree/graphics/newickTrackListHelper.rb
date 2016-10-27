#!/usr/bin/env ruby

require 'Newick'
require 'brl/genboree/graphics/graphlanViewer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'popen4'



module BRL;module Genboree; module Graphics
class NewickTrackListHelper
  @fileHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
  def self.getAsciiNewickTree(newickString,numDashes=3)
    newickTree = NewickTree.new(newickString)
    newickScaler = BRL::Genboree::Graphics::NewickScaler.new(newickString)
    maxTreeDepth = newickScaler.getMaxTreeDepth()
    maxLeafNameLength = newickScaler.getLongestNodeNameLength()
    leafCount = newickScaler.getLeafCount()
    treeWidth = maxLeafNameLength+3 + maxTreeDepth*(numDashes+1)
    treeHeight = 2*leafCount*13
    treeCmd = "nw_topology -|nw_display -S -w #{treeWidth} -"
    sout = nil;sin = nil;serr = nil;treeString=nil;
    exitStatusObj= POpen4.popen4(treeCmd){|sout,serr,sin,pid|
      sin.print(newickString)
      sin.close();
      treeString = sout.read
      serr = serr.read
    }
    if(exitStatusObj.success?) then
      return {:width => treeWidth,:height =>treeHeight,:tree => treeString}
    else
      errMsg = "Could not generate ascii tree\nstderr:#{serr.inspect}\nexitCode:#{exitStatusObj.exitstatus}"
      raise(errMsg)
    end
  end
  
  # Given a newick file URI retrieve the newick tree as a string
  def self.getNewickTree(newickFileInput,apiCaller,leavesOnly = false)
    begin
    apiCaller.setHost(@fileHelper.extractHost(newickFileInput))
    rsrcPath = "#{@fileHelper.extractPath(newickFileInput)}/data"
    gbKey = @fileHelper.extractGbKey(newickFileInput)
    rsrcPath << "?gbKey=#{gbKey}" if (gbKey)
    apiCaller.setRsrcPath(rsrcPath)
    newickStringMaxSize = 250_000_000
    newickString = ""
    newickStringSize = 0
    apiCaller.get(){|chunk|
      newickString << chunk
      newickStringSize += chunk.length
      raise "NewickTree file #{newickFileInput} is larger than #{newickFileMaxSize} bytes. Unable to process." if (newickStringSize > newickStringMaxSize)
    }
    newickTree = NewickTree.new(newickString)
    
    if(leavesOnly)
      return {:success => true,:leaves => newickTree.taxa}
  else
    return {:success => true,:tree => newickString}
  end
  rescue => err
    return {:success => false,:msg => err.message}
  end
end

  def self.createSelectList(asciiTree)
    selectList = []
    lineValue = nil
    validCount = 0
    asciiTree.each_line{|line|
      validLine = false
      line.chomp!.gsub!(/\s+$/,"")
      if(line =~ /\+\s*(\w.*)$/) then
        lineValue = $~[1]
        validCount += 1
        validLine = true
      elsif(line =~ /\S/)
        lineValue = ""
        validLine = true
      end
      if(validLine)
      lineLabel = line.gsub(/ /,"&nbsp;")
      selectList << {:label => lineLabel, :value => lineValue}
        end
    }
    return {:count=>validCount,:selectList => selectList}
  end

# Given a trackmap file URI retrieve the file and generate hashes mapping newick-safe
# names to tracknames and their track uris
def self.getTrackMapHash(trackMapFile,apiCaller)
  begin
      apiCaller.setHost(@fileHelper.extractHost(trackMapFile))
      rsrcPath = "#{@fileHelper.extractPath(trackMapFile)}/data"
      gbKey = @fileHelper.extractGbKey(trackMapFile)
      rsrcPath << "?gbKey=#{gbKey}" if(gbKey)
      apiCaller.setRsrcPath(rsrcPath)
      trackMapMaxSize = 250_000_000
      trackMapString = ""
      trackMapSize = 0
      apiCaller.get(){|chunk|
        trackMapString << chunk
        trackMapSize += chunk.length
        raise "Track Map file #{@fileHelper.extractName(trackMapFile)} is larger than #{trackMapMaxSize} bytes. Unable to process." if (trackMapSize > trackMapMaxSize)
      }
      trackNameMap = {}
      trackUriMap = {}
      trackMapString.each_line{|line|
        sl = line.chomp.split(/\t/)
        trackNameMap[sl[1]] = sl[0]
        trackUriMap[sl[0]] = sl[2]
      }
      return {:success => true,:trackMaps => {:nameMap => trackNameMap,:uriMap => trackUriMap}}
  rescue => err
    return {:success => false,:msg => err.message}
  end
end

# Given a newick file URI retrieve the trackmap file uri it points to
# through an attribute
  def self.getTrackMapFile(newickFileInput,apiCaller)
    begin
    trackMapAttrName = "TrackMapFile"
    trackNameMap = {}
    trackUriMap = {}
    apiCaller.setHost(@fileHelper.extractHost(newickFileInput))
    attrPath = "#{@fileHelper.extractPath(newickFileInput)}/attribute/{attr}/value"
    gbKey = @fileHelper.extractGbKey(newickFileInput)
    attrPath << "?gbKey=#{gbKey}" if (gbKey)
    apiCaller.setRsrcPath(attrPath)
    apiCaller.get({:attr => trackMapAttrName})
    if !(apiCaller.succeeded?) then
      $stderr.puts apiCaller.respBody().inspect
      @errMsg = "Unable to obtain value of attribute #{trackMapAttrName} of file #{@fileHelper.extractName(newickFileInput)}"
      raise @errMsg
    else
      apiCaller.parseRespBody()
      trackMapURI = apiCaller.apiDataObj["text"]
      return {:success => true,:uri => trackMapURI}
    end
    #return {:success => true,:treeMaps => {:nameMap => trackNameMap,:uriMap => trackUriMap}}
  rescue => err
    return {:success => false,:msg => err.message}
  end
  end
  
end

end;end;end

#    retrieveTrackMapFile("http://10.15.5.109/REST/v1/grp/raghuram_group/db/datafreeze4/file/EpigenomicExpHeatmap/EpigenomeExpHeatmap2013-08-23-11%3A48%3A09/newick/columns.newick.txt")
#createLeafSelectList("http://10.15.5.109/REST/v1/grp/raghuram_group/db/datafreeze4/file/EpigenomicExpHeatmap/EpigenomeExpHeatmap2013-08-23-11%3A48%3A09/newick/columns.newick.txt")
#treeFile="blah"
#fh=File.open(treeFile,"w")
#fh.print BRL::Genboree::Graphics::NewickScaler.removeTrackColons(File.read(ARGV[0]))
#fh.close
#maxTreeDepth = BRL::Genboree::Graphics::NewickScaler.getMaxTreeDepth(treeFile)
#maxLeafNameLength = BRL::Genboree::Graphics::NewickScaler.getLongestNodeNameLength(treeFile)
#leafCount = BRL::Genboree::Graphics::NewickScaler.getLeafCount(treeFile)
#
#
#numDashes = 3
#treeWidth = maxLeafNameLength+3 + maxTreeDepth*(numDashes+1)
#treeHeight = 2*leafCount*13
#system("nw_topology -I #{treeFile}|nw_display -S -w #{treeWidth} - > blahTree")
#treeWidth *= 8
