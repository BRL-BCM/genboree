#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/util/checkSumUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/abstract/resources/bedFile'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

if(ARGV.size < 2)
  $stderr.puts("Usage: createRoiFiles.rb [scorerefseqid] [aggFunction] (skipLock)")
end
refseqId = ARGV[0]
aggFunction = ARGV[1]
# The ROI db is always the same: (May need to change it if running on a different machine)
roiRefSeqId = 2498
roiDB = "genboree_r_2a7569a770d141f70a56eb86706d5a22"
aggFunctionHash = {
                    "avg" => nil,
                    "avgByLength" => nil,
                    "med" => nil,
                    "max" => nil,
                    "stdev" => nil,
                    "all" => nil
                  }
skipLock = false
if(ARGV.size > 2)
  skipLock = true
end
begin
  genbConf = BRL::Genboree::GenboreeConfig.load
  dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
  refseqRec = dbu.selectRefseqById(refseqId)
  databaseName = refseqRec.first['databaseName']
  refseqName = refseqRec.first['refseqName']
  groupRefSeq = dbu.selectGroupRefSeqByRefSeqId(refseqId)
  groupId = groupRefSeq.first['groupRefSeqId']
  groupRec = dbu.selectGroupById(groupId)
  groupName = groupRec.first['groupName']
  workingDir = "/usr/local/brl/data/genboree/files/grp/#{CGI.escape(groupName)}/db/#{CGI.escape(refseqName)}"
  `mkdir -p #{workingDir}`
  Dir.chdir(workingDir)
  gotLock = true # Assume we have lock
  lockFile = nil
  unless(skipLock) # Try to get a lock if skipLock is not provided
    lockFile = File.open("#{genbConf.gbLockFileDir}#{genbConf.allRoisLockFile}", "a+")
    gotLock = lockFile.getLock(1280, 2, true, false)
  end
  if(gotLock)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting score track list...")
    dbu.setNewDataDb(databaseName)
    allFtypes = dbu.selectAllFtypes()
    scoreTrkList = []
    allFtypes.each { |trk|
      scoreTrkList << "#{trk['fmethod']}:#{trk['fsource']}" if(dbu.isHDHV?(trk['ftypeid']))
    }
    rois = []
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Getting roi track list...")
    dbu.setNewDataDb(roiDB)
    roiRecs = dbu.selectTracksAvpMap(["gbROITrack"], nil)
    rois = []
    recs.each { |rec|
      rois.push(CGI.escape(rec[0]))
    }
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "ROI List: #{rois.inspect}")
    roiMapHash = {}
    rois.each { |roi|
      roiMapHash[roi] = "/REST/v1/grp/ROI%20Repository/db/ROI%20Repository%20-%20hg19/trk/#{roi}" # May need to change if roi db changes
    }
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Looping over all ROIs...")
    aggFuncs = []
    if(aggFunction == 'all')
      aggFuncs = [
                    "avg",
                    "avgByLength",
                    "med",
                    "max",
                    "stdev"
                  ]
    else
      aggFuncs << aggFunction
    end
    rois.each { |roi|
      aggFuncs.each { |func|
        scoreTrkList.each { |trk|
          roiTrack = roiMapHash[roi]
          fileName = nil
          if(func == 'avgByLength')
            fileName = "#{roi}/By%20AvgByLength/#{CGI.escape(trk)}.bedGraph.bz2"
          elsif(func == 'med')
            fileName = "#{roi}/By%20Median/#{CGI.escape(trk)}.bedGraph.bz2"
          else
            fileName = "#{roi}/By%20#{func.capitalize}/#{CGI.escape(trk)}.bedGraph.bz2"
          end
          if(!File.exists?(fileName))
            ff = nil
            openFile = nil
            if(func == 'avgByLength')
              `mkdir -p #{roi}/By%20AvgByLength`
              openFile = "#{roi}/By%20AvgByLength/#{CGI.escape(trk)}.bedGraph"
            elsif(func == 'med')
              `mkdir -p #{roi}/By%20Median`
              openFile = "#{roi}/By%20Median/#{CGI.escape(trk)}.bedGraph"
            else
              `mkdir -p #{roi}/By%20#{func.capitalize}`
              openFile = "#{roi}/By%20#{func.capitalize}/#{CGI.escape(trk)}.bedGraph"
            end
            formatOptions = {
                              "spanAggFunction" => func,
                              "emptyScoreValue" => "n/a",
                              "scoreTrack" => "http://#{genbConf.machineName}/REST/v1/grp/#{CGI.escape(groupName)}/db/#{CGI.escape(refseqName)}/trk/#{CGI.escape(trk)}",
                              "addCRC32Line" => "true"
                            }
            annoFileObj = BRL::Genboree::Abstract::Resources::BedGraphFile.new(dbu, nil, true, @formatOptions)
            roiTrackRec = dbu.selectFtypeByTrackName(CGI.unescape(roi))
            annoFileObj.setFtypeId(roiTrackRec.first['ftypeid'], roiRefSeqId, nil)
            ff = File.open(openFile, "w")
            annoFileObj.each { |chunk| ff.write(chunk) }
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
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done: trk: #{trk.inspect} for aggFunc: #{func.inspect} for roi: #{roi.inspect}")
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Track: #{trk.inspect} for aggFunc: #{func.inspect} for span: #{roi.inspect} does not have adler32 checksum. Skipping...")
            end
          end
        }
      }
    }

    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting files not in the list...")
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
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Releasing lock...")
    lockFile.releaseLock()
    lockFile.close()
  end
end
