#!/usr/bin/env ruby


# This script adds zoom level info to all existing tracks (non HD) in all existing databases
# Notes: use the latest version of dbUtil
# Additionally, this script must be run from a directory that is not world or group
# readable or writable because of the rubyinline code.

require "rubygems"
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/graphics/zoomLevelUpdater'
require 'brl/sql/binning'
gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
dbs = dbu.selectAllDbNamesFromRefseq
#dbs = ["genboree_r_ffcd153762307558f2b841826055aa96"]
dbs.each { |db|
  begin
  dbName = db['databaseName']
  #dbName = db
  dbu.setNewDataDb(dbName)
  dbu.connectToDataDb
  $stderr.puts "connected to db: #{dbName}"
  allFrefRecords = dbu.selectAllRefNames()
  frefHash = {}
  allFrefRecords.each { |record|
    frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!frefHash.has_key?(record['refName']))
  }
  tracks = dbu.selectAllFtypes
  zoomObj = nil
  tracks.each { |track|
    begin
      ftypeId = track['ftypeid'].to_i
      isHDHV = dbu.isHDHV?(ftypeId)
      if(!isHDHV) #Only add zoom level info if track is non HDHV
        $stderr.puts "processing track: #{track['fmethod']}:#{track['fsource']}"
        # go through each rid
        frefHash.each_key { |chrom|
          $stderr.puts "\nprocessing chr: #{chrom}"
          zoomObj = ZoomLevelUpdater.new(dbu)
          zoomObj.ridLen = frefHash[chrom][0]
          dbu.selectStartStopAndScoreByFtypeIdAndRid(ftypeId, frefHash[chrom][1]){ |scoreRecs|
            scoreRecs.each {|rec|  
              zoomObj.addNewScoreForSpan(rec['fscore'].to_f, rec['fstart'].to_i, (rec['fstop'] - rec['fstart']) + 1)
            }
            $stderr.print "."
          }
          insertCount = 0
          arrayToInsert = []
          binner = BRL::SQL::Binning.new
          zoomObj.zoomLevelRecsHash.each_key { |res|
            zoomObj.zoomLevelRecsHash[res].each_key { |zStart|
              tempArray = zoomObj.zoomLevelRecsHash[res][zStart]
              arrayToInsert[insertCount] = [nil, tempArray[1], ftypeId, frefHash[chrom][1], binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3]), tempArray[2], tempArray[3], tempArray[4], tempArray[5], tempArray[6], tempArray[7], tempArray[8], tempArray[9], tempArray[10], tempArray[11]]
              insertCount += 1
              if(insertCount == 4000)
                dbu.replaceZoomLevelRecords(arrayToInsert, 4000)
                arrayToInsert.clear()
                insertCount = 0
              end
            }
          }
          # Insert any remaining  records
          if(!arrayToInsert.empty?)
            dbu.replaceZoomLevelRecords(arrayToInsert, arrayToInsert.size)
            arrayToInsert.clear()
            insertCount = 0
          end
          zoomObj.clearZoomData
          $stderr.puts "\nprocessed chr: #{chrom}"
        }
      end
    rescue Exception => errTrack
      $stderr.puts "error with track: #{track['fmethod']}:#{track['fsource']} in db: #{dbName}. ERROR: #{errTrack}.\n#{errTrack.backtrace.join("\n")}"
      next
    end
  }
  rescue Exception => err
    # skip to the next database
    $stderr.puts "error with db: #{dbName}. ERROR: #{err}.\n#{err.backtrace.join("\n")}"
    next
  end
  $stderr.puts "db: #{dbName} done"
}
$stderr.puts "all done"
