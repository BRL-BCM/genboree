#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/checkSumUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


if(ARGV.size < 1)
  $stderr.puts "Usage: createRawTracks_roi.rb 'groupName' 'dbName' [format] [skipLock]"
  exit(1)
end
groupName = CGI.escape(ARGV[0])
dbName = CGI.escape(ARGV[1])
format = ARGV[2]
skipLock = false
if(ARGV.size > 3)
  skipLock = true
end
begin
  Dir.chdir("/usr/local/brl/data/genboree/files/grp/#{groupName}/db/#{dbName}")
  genbConf = BRL::Genboree::GenboreeConfig.load
  gotLock = true # Assume we have lock
  lockFile = nil
  unless(skipLock) # Try to get a lock if skipLock is not provided
    lockFile = File.open("#{genbConf.gbLockFileDir}#{genbConf.rawFilesLockFile}", "a+")
    gotLock = lockFile.getLock(1280, 2, true, false)
  end
  if(gotLock)
    # Get all the tagged tracks
    rois = []
    apiCaller = ApiCaller.new('valine.brl.bcmd.bcm.edu', "/REST/v1/grp/#{groupName}/db/#{dbName}/trks?detailed=true", "paithank", "qppofa82")
    apiCaller.get()
    resp = apiCaller.parseRespBody['data']
    resp.each { |trk|
      attr = trk['attributes']
      attr.each_key { |key|
        if(key == 'gbROITrack')
          rois.push(CGI.escape(trk['name']))
        end
      }
    }
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "ROI List: #{rois.inspect}")
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Looping over all ROIs...")
    `mkdir -p Raw%20Data`
    Dir.chdir("Raw%20Data")
    # Next do ROIs
    rois.each { |roi|
      fileName = "#{roi}.#{format}.bz2"
      if(!File.exists?(fileName))
        openFile = "#{roi}.#{format}"
        ff = File.open(openFile, "w")
        apiCaller = ApiCaller.new("valine.brl.bcmd.bcm.edu", "/REST/v1/grp/#{groupName}/db/#{dbName}/trk/#{roi}/annos?format=#{format}&addCRC32Line=true&ucscScaling=false", "paithank", "qppofa82")
        hr = apiCaller.get() { |chunk| ff.print chunk }
        ff.close
        adler32 = BRL::Util::CheckSumUtil.getAdler32CheckSum(openFile)
        if(adler32)
          BRL::Util::CheckSumUtil.stripAdler32(openFile)
          currDir = Dir.pwd
          `pbzip2 -p2 -c #{roi}.#{format} > .#{roi}.#{format}.bz2`
          `rm #{roi}.#{format}`
          `mv .#{roi}.#{format}.bz2 #{roi}.#{format}.bz2`
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done: trk: #{roi}")
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Track: #{roi.inspect} does not have adler32 checksum. Skipping...")
        end
      end
    }

    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting files not in the list...")
    # Lastly, nuke files that are not in the list
    roiHash = {}
    rois.each { |trk|
      roiHash["#{trk}.#{format}"] = nil
    }
    Dir.entries(".") { |file|
      next if(file == '.' or file == '..')
      if(!roiHash.has_key?(file))
        $stderr.puts "Removing file: #{file}"
        `rm #{file}`
      end
    }
  else
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Could not get lock. Quitting...")
  end
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
  $stderr.debugPuts(__FILE__, __method__, "Backtrace:\n", err.backtrace.join("\n"))
ensure
  if(lockFile and lockFile.is_a?(IO))
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Releasing lock...")
    lockFile.releaseLock()
    lockFile.close()
  end
end
