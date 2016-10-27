#!/usr/bin/env ruby
require 'optparse'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/hdhv'

if(ARGV.size < 1)
  $stderr.puts "Usage: checkHDTracks.rb [refseqId]" 
  exit(1)
end
refseqId = ARGV[0]
refseqIdDir = "/usr/local/brl/data/genboree/ridSequences/#{refseqId}"
if(!File.directory?(refseqIdDir))
  $stderr.puts "#{refseqIdDir.inspect} does not exist"
  exit(1)
end
begin
  gc = BRL::Genboree::GenboreeConfig.load
  dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
  resp = dbu.selectRefseqById(refseqId)
  dbName = resp[0]['databaseName']
  dbu.setNewDataDb(dbName)
  dbu.connectToDataDb() # caching enabled, but will force each *user data* dbh closed as we are done with them below
  $stderr.puts "connected to db: #{dbName}"
  tracks = dbu.selectAllFtypes
  frefHash = {}
  allFrefRecords = dbu.selectAllRefNames()
  allFrefRecords.each { |record|
    frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!frefHash.has_key?(record['refName']))
  }
  tracks.each { |track|
    corrupted = false
    ftypeId = track['ftypeid'].to_i
    #next if(ftypeId != 1154)
    recordType = dbu.getTrackRecordType(ftypeId)
    if(!recordType.empty? and (recordType.first['value'] == 'floatScore' or recordType.first['value'] == 'doubleScore' or recordType.first['value'] == 'int8Score')) #Only process if track is hdh
      $stderr.puts "Processing track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId})"
      # Check if there is more than 1 bin file (may or may not be a problem)
      if(dbu.selectDistinctFileNamesByFtypeId(ftypeId).size > 1)
        $stderr.puts "Warning: Track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}) has more than 1 .bin file...)"
        frefHash.each_key { |key|
          hdhv = BRL::Genboree::Hdhv.new(dbName, ftypeId)
          begin
            hdhv.getScoreByRid(frefHash[key][1], 1, frefHash[key][0], 'fixedStep', nil, optsHash = {'spanAggFunction' => :avg, 'desiredSpan' => 100000}) { |chunk| }
          rescue => err
            corrupted = true
            $stderr.puts "Track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}) is corrupted...\nError: #{err}"
          end
          break if(corrupted)
        }
      elsif(dbu.selectDistinctFileNamesByFtypeId(ftypeId).size < 1)
        $stderr.puts "Warning: Track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}) has no .bin file... (No Data??)"
        # Check if there are zoom levels: something wrong if it does
        zoomRecs = dbu.checkIfTrackHasZoomInfo(ftypeId)        
        $stderr.puts "Warning: Track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}) has zoom level records... (Incomplete data upload??)" if(!zoomRecs.nil? and !zoomRecs.empty?)
      else
        frefHash.each_key { |key|
          hdhv = BRL::Genboree::Hdhv.new(dbName, ftypeId)
          begin
            hdhv.getScoreByRid(frefHash[key][1], 1, frefHash[key][0], 'fixedStep', nil, optsHash = {'spanAggFunction' => :avg, 'desiredSpan' => 100000}) { |chunk| }
          rescue => err
            corrupted = true
            $stderr.puts "Track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}) is corrupted...\nError: #{err}"
          end
          break if(corrupted)
        }
      end
    else
      $stderr.puts "Skipping Track #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}), because recordType is #{recordType.inspect}"
    end
  }
rescue => err
  $stderr.puts err
  $stderr.puts err.backtrace.join("\n")
  exit(1)
end


$stderr.puts "All Done"
