#!/usr/bin/env ruby
require 'cgi'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/genboreeUtil'
include BRL::Genboree::REST
remcMap = {
  "BI"=>"broad",
  "UCSD"=>"ucsd",
  "UCSF-UCD-UBC"=>"ucsf",
  "UW"=>"uw"
}

trackData = Array.new

tfh = File.open(ARGV[1], "r")
  while(!tfh.eof?)
    line=tfh.readline
    splitLine = line.chomp.split(/\t/)
    trackHash = Hash.new
    trackHash["remc"] = remcMap[splitLine[0]]
    trackHash["sample"] = splitLine[1]
    trackHash["expt"] = splitLine[2]
    trackHash["tracks"] = splitLine[3]
    trackData << trackHash
  end
tfh.close


gbKey = '9JwN9'
apiCaller = ApiCaller.new("genboree.org", '' )
apiCaller.setRsrcPath("/REST/v1/epigenomeAtlas/graphics/geneName/{geneName}?format=SCORE_CHART_PNG&scrTrack={strk}&remc={remc}&sample={sample}&experiment={experiment}&gbKey=#{gbKey}")
gfh = File.open(ARGV[0], "r")
while(!gfh.eof?)
  geneName = gfh.readline.chomp
  trackData.each{|th|
    th["tracks"].split(/,/).each{|trackName|
      hr = apiCaller.get({:geneName => geneName, :strk => trackName, :remc => trackHash["remc"], :sample => trackHash["sample"], :experiment => trackHash["expt"]})
      if(!apiCaller.succeeded?) then
        puts "Error: #{geneName} #{trackName}"
        puts apiCaller.respBody
        end
      }
    }
end
gfh.close



