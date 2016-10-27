#!/usr/bin/env ruby

require 'brl/util/util'
require 'sqlite3'

# This class implements zoom level creation and updating. You stream new
# base-scores through it and it will update existing zoom records or create
# new zoom records if there are no zoom records currently covering the base-score.
#
# Basic use of this class is:
# 1. instantiate
# 2. reuse instance, doing 1 chr at a time:
#   a. clearZoomData() - clear out data from previous chr
#   b. getZoomLevelRecsByRid(rid) - populate internal zoomLeveles Hash and the SQLite R*Tree zoom level index from MySQL
#   c. addNewScore() - call for EACH new base-score datum in file
#   d. writeBackZoomLevelRecords() - batching & minimal write back to MySQL of changed & new zoomLevels records
# 3. cleanup() - clean up when ALL done
class ZoomLevelUpdater
  attr_accessor :newId, :zoomLevelRecsHash, :rid, :ridLen

  def initialize()
    @newId = -1
    #------------------------------------------------------------------
    # IMPORTANT ASPECT: INDEX THE PARTIAL MySQL zoomLevels RECORDS BY id
    #------------------------------------------------------------------
    # Because our in-memory R*Tree will use "id" as the foreign key, this
    # allows us to find affected zoomLevels records quickly so they can be modified
    # properly with the new scores.
    #------------------------------------------------------------------
    @zoomLevelRecsHash = {}   # We must have a Hash of the actual zoomLevels record info keyed by "id"
    #------------------------------------------------------------------
    # IMPORTANT ASPECT: CREATE R*Tree INDEX OF THE ZOOM LEVEL RECORDS
    #------------------------------------------------------------------
    # We will be querying this tree over and over to find regions containing
    # a specific base-pair (which has a score in our input file). Querying this
    # tree will give either (a) NO records [no existing data anywhere near that base],
    # (b) 1 record [should be the low-res one; existing data nearby but not within 10k],
    # or (c) 2 records [there is existing data within 10k of that base]
    #
    # We will be querying this tree many millions of times...once per base-score.
    # Making this efficient is worth some thinking (although don't trade more
    # Ruby instructions for SQLite3 effort necessarily)
    #------------------------------------------------------------------
    # Put zoom-levels into R*Tree searchable in-memory database so we can
    # quickly find zoom-levels affected by a score update (if any).
    # * "id" in our RAM database will be the "id" from the MySQL zoomLevels table
    # * Because of how SQLite3's R*Tree index works, we NEED the zoomLevelRecsHash to be keyed by
    #   the same id that SQLite3 will use; it's our only connection to the zoomLevels records
    # * Note: must use SQLite3 *efficiently*. It's not the fastest DB in the world when used inappropriately,
    #   so need to be smart and then it will be quite fast for what we want to do:
    #   - prepare stmts ONCE (across all chrs and all blocks of scores) and reuse them
    #   - prepare database ONCE and use throughout program
    #   - create r*tree table ONCE and reuse via a "trucate" sql stmt "DELETE FROM zoomIndex" when we switch chrs
    # * Note: SQLite3 table with millions of records is a bit slow. That's why we do 1 chr worth of zoomLevels at a
    #   time. 10,000's of records is a nice sweet spot. Yay.
    #------------------------------------------------------------------
    # 1st, create the database in memory:
    @ziDb = SQLite3::Database.new(":memory:")
    @ziDb.results_as_hash = true # Note: results as array didn't seem to help even 0.1 sec
    @ziDb.type_translation = false # Ensure that we'll handle any type conversion ourselves on an as-needed basis
    @ziDb.synchronous = 0
    @ziDb.temp_store = 2
    # 2nd, create a virtual table with rtree index. Virtual tables are used by SQLite3 extensions (like R*Tree) to implement special features.
    @ziDb.execute( "create virtual table zoomIndex using rtree(id, start, stop) " ) { |rs| }
    # 3rd, prepare the truncate stmt:
    @ziTruncateStmt = @ziDb.prepare( "delete from zoomIndex" ) # <-- no where clause...SQLite optimizes this delete so it is O(1) not O(N)
    # 4th, prepare the insert zoomIndex record stmt:
    # - r*tree tables must have an id column and then 1+ coordinate columns. And that's it.
    @ziInsertStmt = @ziDb.prepare( "insert into zoomIndex values (?, ?, ?)" )
    # 5th, prepare the select zoomIndex records stmt:
    @ziSelectStmt = @ziDb.prepare( "select * from zoomIndex where start <= ? and stop >= ?" )
  end

  # Use this to reuse the object for another chromosome's zoomLevels records:
  def clearZoomData()
    @ziTruncateStmt.execute() { |rs| }
    @zoomLevelRecsHash.clear()
  end

  # Get existing zoomLevels data from MySQL for current chr. Only partial record data is needed.
  # - here the data is fake
  # - ridLen is particularly important so new zoom levels can properly stop at end of chr
  def getZoomLevelRecsByRid(rid, ridLen)
    @rid, @ridLen = rid, ridLen
    #------------------------------------------------------------------
    # QUERY MySQL USER DATABASE'S zoomLevels TABLE FOR *ALL* zoomLevels RECORDS
    # FOR A SPECIFIC CHR (by rid)
    #------------------------------------------------------------------
    # Here, fake MySQL result rows from querying "zoomLevels" table to get ALL zoom-levels
    # on the specific chr.
    # * NOTE: Not all regions of the chr may have zoom-level records, depending on density of previous data
    # * NOTE: For a 250 million bp chr, there will be a MAXIMUM of
    #   (250M/100,000 + 250M/10,000 = 27,500) records. Suitable for storing in memory.
    # * NOTE: We don't need all the columns in memory, even if some (like "bin") are needed
    #   for querying. We should just get:
    #   - id
    #   - level
    #   - start, stop
    #   - scoreCount, scoreSum, scoreMax, scoreMin, scoreSumOfSquares
    # * GOOD APPROACH:
    #   - Get these partial zoomLevels records
    #   - For existing zoomLevels records, update their score* fields as we see new data
    #   - For new zoomLevels records, add them to the set of records
    #   - When done with data from current chr, post the new & modified records back to the database;
    #     put records back 4000 at a time via a batch update/insert or whatever amount makes sense.
    #     . may want to 'flag' zoomLevels records that have been modified or inserted to make
    #       prep of the updates vs inserts vs unchanged-don't-waste-time easier.
    #   - A Class to do this would make sense...data can come from anywhere (wig, lff, other), but class is
    #     as class does.
    # HERE WE GENERATE FAKE RESULTS OF SUCH A MySQL QUERY AGAINST zoomLevels:
    #------------------------------------------------------------------
    # FAKE zoomLevels record generation:
    # Find number of 100k regions on chr. Don't miss the partial region at the end of the chr! It will be smaller than others though.
    numLowResRegions = (SCORE_DATA.chrLen / 100_000.0).ceil
    idCount = 0
    numLowResRegions.times { |ii|
      next if(rand() < 0.2) # Simulate "real" scenario: Randomly skip 20% of regions...they don't have data yet, say
      idCount += 1
      # - MUST coordinate type of "id" with SQLite (it will be a String when QUERIED) and its use in @zoomLevelRecsHash:
      newId = idCount.to_s
      # Add 100k rec
      rstart = (ii * 100_000) + 1
      rstop = rstart + 100_000 - 1
      rstop = SCORE_DATA.chrLen if(rstop > @ridLen) # Fix for last region on chr
      # Completely fake zoomLevels records...real one comes from database:
      # [id, level, start, stop, scoreCount, scoreSum, scoreMax, scoreMin, scoreSumofSquares, flag]
      @zoomLevelRecsHash[newId] = [ newId, 5, rstart, rstop, rand(100_000), rand(5_000), rand(1000), rand(20), rand(300), :unmodified ]
      @ziInsertStmt.execute(idCount, rstart, rstop) { |rs| }
      # Add the high-res 10krecs within this zoom region
      10.times { |jj|
        next if(rand() < 0.25) # Simulate "real" scenario: Randomly skip 25% of 10k recs
        idCount += 1
        # - MUST coordinate type of "id" with SQLite (it will be a String when QUERIED) and its use in @zoomLevelRecsHash:
        newId = idCount.to_s
        hrstart = rstart + (jj * 10_000)
        hrstop = hrstart + 10_000 - 1
        hrstop = SCORE_DATA.chrLen if(hrstop > @ridLen)
        break if(hrstop == @ridLen) # can't fit the full 10 10k regions
        # Completely fake zoomLevels records...real one comes from database:
        # [id, level, start, stop, scoreCount, scoreSum, scoreMax, scoreMin, scoreSumofSquares, flag]
        @zoomLevelRecsHash[newId] = [ newId, 5, hrstart, hrstop, rand(10_000), rand(5_000), rand(1000), rand(20), rand(300), :unmodified ]
        @ziInsertStmt.execute(idCount, hrstart, hrstop) { |rs| }
      }
    }
    return
  end

  # Add a new base-score (from file say) to appropriate zoom levels.
  # - update existing zoom levels
  # - create missing zoom levels if no existing zoom regions cover the new base-score
  # We need to find the existing zoomLevels records, if any, covering the
  # base for each score. We do that with a query on SQLite zoomIndex table.
  # Once we find the records, we create any that are missing and update any that
  # already exist with the new score info.
  # - Spending some effort timing this process will pay off since its done
  #   for each new score.
  # - The time might be significantly spent in the Ruby parts, not just the
  #   SQLite querying part (although I expect that's hefty)
  # * NOTE: for any given score, there should be at most 1 record per zoom level
  # * For each zoom level record found, update it.
  # * For each missing zoom level records, insert a new one.
  def addNewScore(score, bpCoord)
    saw10k, saw100k = false, false # flags to tell which zoomLevel records we've seen...we don't know which will come first, 10k or 100k
    # Find zoomIndex records this score touches via SQL query of in-memory database
    @ziSelectStmt.execute(bpCoord, bpCoord) { |rs|
      if(DO_NON_ZOOMINDEX_WORK)
        if(rs.eof?) # then no existing zoom level records covering this base. Add them.
          # Need to make a NEW 100_000 zoomLevels record and a 10_000 zoomLevels record
          # 100k:
          self.makeZoomLevelRec(score, bpCoord, 100_000)
          # 10k:
          self.makeZoomLevelRec(score, bpCoord, 10_000)
        else # either 1 [lo res] or 2 [hi and lo res] existing zoom level records cover this base
          # Loop over the matching zoomIndex records and process each
          while(ziRow = rs.next())
            zoomLevelRec = zoomLevelRecsHash[ziRow["id"]]
            # Track which zoomLevels we found records for. We'll know to create 10k if it's missing and detect error situation.
            if(zoomLevelRec[1] == 4)
              saw10k = true
            elsif(zoomLevelRec[1] == 5)
              saw100k = true
            end
            # UPDATE this existing zoomLevels record
            self.updateZoomLevelRec(zoomLevelRec, score, bpCoord)
          end

          # Did we see both 100k and 10k record? If 10k missing, then make it. If 100k missing, then ERROR!
          if(saw100k and !saw10k)
            # Need to make a NEW 10_000 zoomlevels record
            newZoomRec = makeZoomLevelRec(score, bpCoord, 10_000)
          elsif(saw10k and !saw100k)
            raise "ERROR: found 10k zoomLevels record without a 100k zoomLevels record. WTF?"
          end
        end
      end
    }
    return
  end

  # Write updated & new zoom level data to MySQL
  # - do NOT do wasteful work; don't involve records marked as :unmodified
  # - DO fix all the -ve "id" :new zoom level records to have nil "id" so MySQL gives them appropriate ids
  # - DO INSERT or UPDATE ~4000 records in a single batch SQL
  # - :modified == UPDATE, :new = INSERT
  def writeBackZoomLevelRecords()
    # TODO
  end

  # Clean up at end of all processing is a good practice
  def cleanup()
    @zoomLevelRecsHash.clear()
    @ziDb.close() rescue Exception
  end

  #------------------------------------------------------------------
  # INTERNAL HELPER METHODS
  #------------------------------------------------------------------
  # Update in-memory zoomLevels record's data
  def updateZoomLevelRec(zoomLevelRec, score, bpCoord)
    # If new this batch, leave as new, else mark pre-existing zoom level as modified
    flag = ( (zoomLevelRec[9] == :new) ? :new : :modified )
    count = (zoomLevelRec[4] += 1)    # save new count to AVOID calling []() method again below ([] is expensive!)
    sum = (zoomLevelRec[5] += score)  # save new sum to AVOID calling []() method again below ([] is expensive!)
    zoomLevelRec[6] = score if(zoomLevelRec[5] > score)
    zoomLevelRec[7] = score if(zoomLevelRec[6] < score)
    zoomLevelRec[8] += (score - (sum.to_f / count))  # update for sum-of-squares
    return zoomLevelRec
  end

  # Create a NEW zoomLevel and insert it into data structures
  def makeZoomLevelRec(score, bpCoord, zlSpan)
    # Calc start of zoom region covering bpCoord.
    zlStart = (zlSpan * (bpCoord / zlSpan))
    zlStop = zlStart + zlSpan - 1
    zlStop = SCORE_DATA.chrLen if(zlStop > @ridLen)
    # If we're making a completely new zoom level record, then "id" field
    # is -ve b/c I need a unique id for the Hash and SQLite table, but when inserted back
    # to MySQL I'd set any -ve ids to "nil" in my inserts, so MySQL can do the right thing.
    # This saves me unnecessary querying of MySQL for max id and the many many bugs that
    # come with parallel processes (the max id is never the max id when multiple imports can
    # run at once)
    @newId -= 1
    # - MUST coordinate type of "id" with SQLite (it will be a String) and its use in @zoomLevelRecsHash:
    id = @newId.to_s
    # Flag is :new, so we can easily do an SQL "INSERT" for this vs "UPDATE" for existing ones when put back to MySQL
    newZoomRec = [ id, Math.log10(zlSpan).to_i, zlStart, zlStop, 1, score, score, score, 0.0, :new ]
    # Add to Hash of full records
    @zoomLevelRecsHash[id] = newZoomRec
    # Add to R*Tree index
    @ziInsertStmt.execute(@newId, newZoomRec[2], newZoomRec[3]) { |rs| } # <= avoid closing result set
    return newZoomRec
  end
end

#------------------------------------------------------------------
#------------------------------------------------------------------
# TEST & TIME:
#------------------------------------------------------------------
t1 = nil    # timing var
# Do we just want to time the impact of the SQLite3 R*Tree usage, or
# do we actually want to do some of the sort of "work" that will need to be
# done based on what zoom levels exist for the base-score?
DO_NON_ZOOMINDEX_WORK = true

#------------------------------------------------------------------
# GENERATE FAKE-DATA (some of the scores read from wig file)
#------------------------------------------------------------------
t1 = Time.now
# Fake incoming score data, must be on a specific chr, with start & stop
ScoreData = Struct.new(:chr, :chrLen, :chrStart, :scores)
NUM_SCORES = 1_000_000
rid = 47 # <= whatever
# Deliberately make start base for this bunch-o-scores and the chrLen non-even/non-nice:
SCORE_DATA = ScoreData.new("chr2", 210_007_123, 112_567_890, [])
NUM_SCORES.times { |ii|
  SCORE_DATA.scores << rand(100)
}
$stderr.puts "#{Time.now} STATUS: generated #{NUM_SCORES} scores (#{"%0.3f" % (Time.now - t1)} secs)"

#------------------------------------------------------------------
# Instantiate ZoomLevelUpdater
#------------------------------------------------------------------
zoomUpdater = ZoomLevelUpdater.new()

#------------------------------------------------------------------
# "Retrieve" existing zoomLevels record from MySQL for this chr
#------------------------------------------------------------------
zoomUpdater.getZoomLevelRecsByRid(rid, SCORE_DATA.chrLen)
$stderr.puts  "#{Time.now} STATUS: done 'retrieving' fake zoomLevels data for chr2.\n" +
              "        chr2 has #{zoomUpdater.zoomLevelRecsHash.size} *existing* zoom level records\n" +
              "        out of a maximum of #{(SCORE_DATA.chrLen / 100_000.0).ceil + (SCORE_DATA.chrLen / 10_000.0).ceil} possible zoom level records. (#{"%0.3f" % (Time.now - t1)} secs)"

#------------------------------------------------------------------
# PROCESS SCORES FROM FILE
#------------------------------------------------------------------
# Go through scores in our current batch (this batch has millions of scores...maybe there are more in the file)
# and locate affected zoom level records.
# Main goal here is to see how long all this querying takes on the zoomIndex table we've prepped.
#------------------------------------------------------------------
t1 = Time.now
SCORE_DATA.scores.each_index { |ii|
  score = SCORE_DATA.scores[ii]
  bpCoord = SCORE_DATA.chrStart + ii  # <= whatever, I'm pretending I have NUM_SCORES contiguous base-scores starting at chrStart
  zoomUpdater.addNewScore(score, bpCoord)
}
$stderr.puts "#{Time.now} STATUS: did #{NUM_SCORES} queries to find relevant zoom levels for each score (#{"%0.3f" % (Time.now - t1)} secs)"
$stderr.puts "        AND did bunch of zoom record creation/updating for each score" if(DO_NON_ZOOMINDEX_WORK)

#------------------------------------------------------------------
# WRITE BACK NEW & UPDATED ZOOM LEVEL DATA TO MySQL
zoomUpdater.writeBackZoomLevelRecords()

#------------------------------------------------------------------
# GO TO NEXT CHR...
# When moving to next chromosome, truncate the zoomIndex table by doing:
zoomUpdater.clearZoomData()


#------------------------------------------------------------------
# ALL DONE
# When finished processing ALL scores, it is good practice to cleanup nicely:
zoomUpdater.cleanup()
exit(0)
