#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/checkSumUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

skipLock = false
if(ARGV.size > 0)
  skipLock = true
end
begin
  genbConf = BRL::Genboree::GenboreeConfig.load
  gotLock = true # Assume we have lock
  lockFile = nil
  unless(skipLock) # Try to get a lock if skipLock is not provided
    lockFile = File.open("#{genbConf.gbLockFileDir}#{genbConf.staticFilesLockFile}", "a+")
    gotLock = lockFile.getLock(1280, 2, true, false)
  end
  if(gotLock)
    apiCaller = ApiCaller.new("valine.brl.bcmd.bcm.edu", "/REST/v1/grp/Epigenomics%20Roadmap%20Repository/db/Release%205%20Repository/trks?class=High%20Density%20Score%20Data", "paithank", "qppofa82")
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting track list...")
    apiCaller.get()
    resp = apiCaller.parseRespBody
    retVal = resp['data']
    ff = File.open("trackList.txt", "w")
    retVal.each { |trk|
      ff.puts "#{trk['text'].inspect}"  
    }
    ff.close
    spans = [100000, 10000, 1000]
    roiList = genbConf.ROITrackList_hg19
    rois = []
    roiList.each { |roi|
      rois << CGI.escape(roi)
    }
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "ROI List: #{rois.inspect}")
    roiMapHash = {}
    rois.each { |roi|
      roiMapHash[roi] = "/REST/v1/grp/Microarray%20Repository/db/Microarray%20Repository%20-%20hg19/trk/#{roi}"  
    }
    aggFuncs = ['avg', 'avgByLength', 'max', 'med', 'stdev']
    
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Looping over all spans...")
    # Do spans:
    spans.each { |span|
      aggFuncs.each { |func|
        retVal.each { |trk|
          fileName = nil
          if(func == 'avgByLength')
            fileName = "#{span}bp%20span/By%20AvgByLength/#{CGI.escape(trk['text'])}.fwig.bz2"
          elsif(func == 'med')
            fileName = "#{span}bp%20span/By%20Median/#{CGI.escape(trk['text'])}.fwig.bz2"
          else
            fileName = "#{span}bp%20span/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.fwig.bz2"
          end
          if(!File.exists?(fileName))
            ff = nil
            openFile = nil
            if(func == 'avgByLength')
              `mkdir -p #{span}bp%20span/By%20AvgByLength`
              openFile = "#{span}bp%20span/By%20AvgByLength/#{CGI.escape(trk['text'])}.fwig"
            elsif(func == 'med')
              `mkdir -p #{span}bp%20span/By%20Median`
              openFile = "#{span}bp%20span/By%20Median/#{CGI.escape(trk['text'])}.fwig"
            else
              `mkdir -p #{span}bp%20span/By%20#{func.capitalize}`
              openFile = "#{span}bp%20span/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.fwig"
            end
            ff = File.open(openFile, "w")
            apiCaller = ApiCaller.new("valine.brl.bcmd.bcm.edu", "/REST/v1/grp/Epigenomics%20Roadmap%20Repository/db/Release%205%20Repository/trk/#{CGI.escape(trk['text'])}/annos?format=fwig&spanAggFunction=#{func}&emptyScoreValue=n/a&addCRC32Line=true&span=#{span}", "paithank", "qppofa82")
            apiCaller.get() { |chunk| ff.print chunk }
            ff.close
            adler32 = BRL::Util::CheckSumUtil.getAdler32CheckSum(openFile)
            if(adler32)
              BRL::Util::CheckSumUtil.stripAdler32(openFile)
              currDir = Dir.pwd
              if(func == 'avgByLength')
                Dir.chdir("#{span}bp%20span/By%20AvgByLength")
              elsif(func == 'med')
                Dir.chdir("#{span}bp%20span/By%20Median")
              else
                Dir.chdir("#{span}bp%20span/By%20#{func.capitalize}")
              end
              `pbzip2 -p5 -c #{CGI.escape(trk['text'])}.fwig > .#{CGI.escape(trk['text'])}.fwig.bz2`
              `rm  #{CGI.escape(trk['text'])}.fwig`
              `mv .#{CGI.escape(trk['text'])}.fwig.bz2 #{CGI.escape(trk['text'])}.fwig.bz2`
              Dir.chdir(currDir)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done: trk: #{trk['text'].inspect} for aggFunc: #{func.inspect} for span: #{span.inspect}")
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Track: #{trk['text'].inspect} for aggFunc: #{func.inspect} for span: #{span.inspect} does not have adler32 checksum. Skipping...")
            end
          end
        }  
      }
    }
    
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Looping over all ROIs...")
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
            fileName = "#{roi}/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.bedGraph.bz2"
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
              `mkdir -p #{roi}/By%20#{func.capitalize}`
              openFile = "#{roi}/By%20#{func.capitalize}/#{CGI.escape(trk['text'])}.bedGraph"
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
                Dir.chdir("#{roi}/By%20#{func.capitalize}")
              end
              `pbzip2 -p2 -c #{CGI.escape(trk['text'])}.bedGraph > .#{CGI.escape(trk['text'])}.bedGraph.bz2`
              `rm #{CGI.escape(trk['text'])}.bedGraph`
              `mv .#{CGI.escape(trk['text'])}.bedGraph.bz2 #{CGI.escape(trk['text'])}.bedGraph.bz2`
              Dir.chdir(currDir)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done: trk: #{trk['text'].inspect} for aggFunc: #{func.inspect} for roi: #{roi.inspect}")
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Track: #{trk['text'].inspect} for aggFunc: #{func.inspect} for span: #{roi.inspect} does not have adler32 checksum. Skipping...")
            end
          end
        }  
      }
    }
    
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting files not in the list...")
    # Lastly, loop over all the relevant dirs and nuke the files that are not in the list
    spanHash = {}
    retVal.each { |trk|
      spanHash["#{CGI.escape(trk['text'])}.fwig.bz2"] = true 
    }
    spans.each { |span|
      aggFuncs.each { |func|
        checkDir = nil
        if(func == 'avgByLength')
          checkDir = "#{span}bp%20span/By%20AvgByLength"
        elsif(func == 'med')
          checkDir = "#{span}bp%20span/By%20Median"
        else
          checkDir = "#{span}bp%20span/By%20#{func.capitalize}"
        end
        Dir.entries(checkDir) { |file|
          next if(file == '.' or file == '..')
          if(!spanHash.has_key?(file))
            rmFile = "#{checkDir}/#{file}" 
            $stderr.puts "Removing file: #{rmFile}"
            `rm  #{rmFile}` 
          end
        }
      }
    }
    
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
          checkDir = "#{roi}/By%20#{func.capitalize}"
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
  else
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not get lock...")
  end
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
ensure
  if(lockFile and lockFile.is_a?(IO))
    lockFile.releaseLock()
    lockFile.close()
  end
end