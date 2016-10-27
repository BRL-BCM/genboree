#!/usr/bin/env ruby

require 'brl/genboree/hdhv'
require 'brl/genboree/graphics/zoomLevelUpdater'
require 'brl/sql/binning'

# Usage
# addZoomObj = BRL::Genboree::AddZoomLevels.new("genboree_r_ffcd153762307558f2b841826055aa96", "mre:1", dbu)
# addZoomObj.addZoomLevelInfo()

# Note that this should be used only for those high density tracks that have NO zoom level information



module BRL; module Genboree;

# This class adds zoom level information for eixsting high density tracks in Genboree
# using the hdhv library functions
# The constructor should be initialized every time for a new track
class AddZoomLevels

  attr_accessor :dbName, :trackName, :dbu, :frefHash
  attr_accessor :ftypeId
  # [+dbName+] full database name
  # [+trackName+] name of the track
  # [+dbu+] dbUtil object
  # [+returns+] nil
  def initialize(dbName, trackName, dbu)
    @dbName = dbName
    @trackName = trackName
    @dbu = dbu
    @frefHash = {} # Initialize it as a hash
    # make sure this track exists in the database:
    ftype = @dbu.selectFtypeByTrackName(@trackName)
    raise ArgumentError, "#{@trackName} does not exist in #{@dbName}", caller if(ftype.empty? or ftype.nil?)
    @ftypeId = ftype.first['ftypeid']
    allFrefRecords = @dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      @frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!@frefHash.has_key?(record['refName'])) 
    }
  end
  
  # Adds zoom level info for all the chromosomes for the track
  # [+returns+] nil
  def addZoomLevelInfo
    # Initialize all required variables
    orphan = nil
    bpCoord = nil
    chr = nil
    span = nil
    step = nil
    start = nil
    zoomObj = ZoomLevelUpdater.new(@dbu)
    # Iterate over all entry points and add zoom level info if data present for that entry point
    @frefHash.each_key { |chrom|
      $stderr.puts "processing chr: #{chrom}" 
      zoomObj = ZoomLevelUpdater.new(@dbu)
      zoomObj.ridLen = @frefHash[chrom][0]
      hdhvObj = BRL::Genboree::Hdhv.new(@dbName, @ftypeId)
      orphan = nil
      begin
        hdhvObj.getScoreByRid(@frefHash[chrom][1], nil, nil, 'bedGraph') { |chunk|
          chunk.each_line { |line|
            data = line.split(/\t/)
            start = data[1].to_i + 1
            stop = data[2].to_i
            score = data[3].to_f
            span = (stop - start) + 1
            zoomObj.addNewScoreForSpan(score, start, span)  
          }
          $stderr.print "."
        }        
        insertCount = 0
        arrayToInsert = []
        binner = BRL::SQL::Binning.new
        zoomObj.zoomLevelRecsHash.each_key { |res|
          zoomObj.zoomLevelRecsHash[res].each_key { |zStart|
            tempArray = zoomObj.zoomLevelRecsHash[res][zStart]
            #$stderr.puts tempArray
            arrayToInsert[insertCount] = [nil, tempArray[1], @ftypeId, @frefHash[chrom][1], binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3]), tempArray[2], tempArray[3], tempArray[4], tempArray[5], tempArray[6], tempArray[7], tempArray[8], tempArray[9], tempArray[10], tempArray[11]]
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
        $stderr.puts "\nchrom: #{chrom} processed\n"
      rescue Exception => err
        backT = err.backtrace.join("\n")
        $stderr.puts "HDHV error (chr: #{chrom}): #{err.message}\nBacktrace: #{backT}\n"
        next
      end
    }
  end
end
end; end