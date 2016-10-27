#!/usr/bin/env ruby
require 'brl/util/checkSumUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST
apiCaller = ApiCaller.new("valine.brl.bcmd.bcm.edu", "/REST/v1/grp/Epigenomics%20Roadmap%20Repository/db/Release%205%20Repository/trks?class=High%20Density%20Score%20Data", "paithank", "qppofa82")
apiCaller.get()
resp = apiCaller.parseRespBody
retVal = resp['data']
ff = File.open("trackList_27_withoutMedian.txt", "w")
retVal.each { |trk|
  ff.puts "#{trk['text'].inspect}"  
}
ff.close
rois = ['Human%3AMethylation27']
roiMapHash =  {
                "Human%3AMethylation27" => "/REST/v1/grp/Microarray%20Repository/db/Microarray%20Repository%20-%20hg19/trk/Human%3AMethylation27"
              }
aggFuncs = ['avgByLength', 'med', 'max']


# Next do ROIs
rois.each { |roi|
  aggFuncs.each { |func|
    retVal.each { |trk|
      roiTrack = roiMapHash[roi]  
      fileName = nil
      if(func == 'avgByLength')
        fileName = "#{roi}/By%20AvgByLength/#{CGI.escape(trk['text'])}.bedGraph.bz2"
      elsif(func == 'med')
        fileName = "#{roi}/By%20Median/#{CGI.escape(trk['text'])}.bedGraph.bz2"
      else
        fileName = "#{roi}/BedGraph/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.bedGraph.bz2"
      end
      if(!File.exists?(fileName))
        ff = nil
        openFile = nil
        if(func == 'avgByLength')
          `mkdir -p #{roi}/By%20AvgByLength`
          openFile = "#{roi}/By%20AvgByLength/#{CGI.escape(trk['text'])}.bedGraph"
        elsif(func == 'med')
          `mkdir -p #{roi}/By%20Median`
          openFile = "#{roi}/By%20Median/#{CGI.escape(trk['text'])}.bedGraph"
        else
          `mkdir -p #{roi}/BedGraph/By%20#{func.capitalize}`
          openFile = "#{roi}/BedGraph/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.bedGraph"
        end
        ff = File.open(openFile, "w")
        apiCaller = ApiCaller.new("valine.brl.bcmd.bcm.edu", "#{roiTrack}/annos?format=bedGraph&spanAggFunction=#{func}&emptyScoreValue=n/a&scoreTrack={scrTrack}&addCRC32Line=true", "paithank", "qppofa82")
        hr = apiCaller.get(
                     {
                       :scrTrack => "#{trk['refs']['Txt_JSON.XML.YAML']}"
                     }
                   ) { |chunk| ff.print chunk }
        ff.close
        adler32 = BRL::Util::CheckSumUtil.getAdler32CheckSum(openFile)
        if(adler32)
          BRL::Util::CheckSumUtil.stripAdler32(openFile)
          currDir = Dir.pwd
          if(func == 'avgByLength')
            Dir.chdir("#{roi}/By%20AvgByLength")
          elsif(func == 'med')
            Dir.chdir("#{roi}/By%20Median")
          else
            Dir.chdir("#{roi}/BedGraph/By%20#{func.capitalize}")
          end
          Dir.chdir(currDir)
          $stderr.puts "Done: trk: #{trk['text'].inspect} for aggFunc: #{func.inspect} for roi: #{roi.inspect} "
        else
          $stderr.puts "ERROR: trk: #{trk['text'].inspect} for aggFunc: #{func.inspect} for roi: #{roi.inspect} does not have adler32 check sum value"
        end
      end
    }  
  }
}

# Lastly, loop over all the relevant dirs and nuke the files that are not in the list

roiHash = {}
retVal.each { |trk|
  roiHash["#{CGI.escape(trk['text'])}.bedGraph.bz2"] = true 
}
rois.each { |roi|
  aggFuncs.each { |func|
    checkDir = nil
    if(func == 'avgByLength')
      checkDir = "#{roi}/By%20AvgByLength"
    elsif(func == 'med')
      checkDir = "#{roi}/By%20Median"
    else
      checkDir = "#{roi}/BedGraph/By%20#{func.capitalize}"
    end
    Dir.entries(checkDir) { |file|
      next if(file == '.' or file == '..')
      if(!roiHash.has_key?(file))
        rmFile = "#{checkDir}/#{file}"
        $stderr.puts "Removing file: #{rmFile}"
        `rm  #{rmFile}` 
      end
    }
  }
}
