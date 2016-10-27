#!/usr/bin/env ruby

# This script adds zoom level info to all existing tracks in all existing databases

require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/graphics/zoomLevelUpdater'
require 'brl/sql/binning'
# C class for quickly going through the binary data and returning 
class ReturnScores
  
  include BRL::C

  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
    builder.include(CFunctionWrapper::MATH_HEADER_INCLUDE)
    builder.include(CFunctionWrapper::GLIB_HEADER_INCLUDE)
    builder.c <<-EOC

    /* Allocate memory for storing wiggle records. This buffer will be reused every time the C classes for the wiggle formula are called */
    double returnRealScores(VALUE scores, int position)
    {
      void *scr = RSTRING_PTR(scores);
      //double nanVal = 4290772992.0000;
      guint32 *nullCheck32 = (guint32 *)scr;  
      gfloat *gfloatPtr = (gfloat *)scr;
      gfloatPtr += position;
      nullCheck32 += position;
      if(*nullCheck32 != (guint32)4290772992)
      {
        return (double)(*gfloatPtr);
      }
      else
      {
        //return nanVal;
        return 4290772992.0000;
      }
    }
    EOC
  }
end

gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
dbs = dbu.selectAllDbNamesFromRefseq
dbs = ['genboree_r_e5b1f99c9a3d81f81a4776544872fbd6']
dbs.each { |db|
  begin
  #dbName = db['databaseName']
  dbName = db
  dbu.setNewDataDb(dbName)
  dbu.connectToDataDb
  $stderr.puts "connected to db: #{dbName}"
  # get all entry points for the database
  frefHash = Hash.new
  allFrefRecords = dbu.selectAllRefNames()
  allFrefRecords.each { |record|
    frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!frefHash.has_key?(record['refName']))
  }
  dir = dbu.selectValueFmeta('RID_SEQUENCE_DIR')
  dir = dir.first['fvalue']
  tracks = dbu.selectAllFtypes
  tracks.each { |track|
    begin
      ftypeId = track['ftypeid'].to_i
      recordType = dbu.getTrackRecordType(ftypeId)
      if(!recordType.empty? and (recordType[0][0] == 'floatScore' or recordType[0][0] == 'doubleScore')) #Only add zoom level info if track is hdhv
        $stderr.puts "processing track: #{track['fmethod']}:#{track['fsource']}"
        $stderr.puts "NOTE: record type is double score!" if(recordType[0][0] == 'doubleScore')
        dataSpan = (recordType[0][0] == 'floatScore' ? 4 : 8)
        # iterate over each chromosome
        frefHash.each_key { |chrom|
          fileHash = {}
          fileReader = nil
          startOffset = 0
          buffer = ''
          bufferOffset = 0
          buffIO = nil
          previousOffset = 0
          byteRead = 0
          inflatedBuffer = nil
          zInflater = Zlib::Inflate.new()
          zoomObj = ZoomLevelUpdater.new(dbu)
          zoomObj.ridLen = frefHash[chrom][0]
          retScoreObj = ReturnScores.new()
          $stderr.puts "\nprocessing chrom: #{chrom}"
          dbu.selectBlockLevelDataInfoByFtypeIdAndRid(ftypeId, frefHash[chrom][1], BLOCKSIZE=30_000) {|blockLevelRec|
            repArray = []
            repCount = 0
            blockLevelRec.size.times { |blockRec|
              offset = blockLevelRec[blockRec]['offset'].to_i
              byteLength = blockLevelRec[blockRec]['byteLength'].to_i
              numRecords = blockLevelRec[blockRec]['numRecords'].to_i
              start = blockLevelRec[blockRec]['fstart'].to_i
              stop = blockLevelRec[blockRec]['fstop'].to_i
              if(!fileHash.has_key?(blockLevelRec[blockRec]['fileName']))
                fileReader = BRL::Util::TextReader.new("#{dir}/#{blockLevelRec[blockRec]['fileName']}")
                fileHash[blockLevelRec[blockRec]['fileName']] = nil
                fileReader.seek(offset)
                if(byteLength > 32_000)
                  buffer = fileReader.read(byteLength)
                  byteRead = byteLength
                else
                  buffer = fileReader.read(32_000)
                  byteRead = buffer.size
                end
                bufferOffset = 0
                inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                numRecords.times { |ii|
                  #score = retScoreObj.returnRealScores(inflatedBuffer, ii)
                  score = 4.0
                  zoomObj.addNewScore(score, start) if(score != 4290772992.0000)
                  start += 1
                }
                startOffset = offset
              else
                numScores = 0
                if((startOffset + byteRead) > (offset + byteLength))
                  bufferOffset = bufferOffset + (offset - previousOffset)
                  inflatedBuffer = zInflater.inflate(buffer[bufferOffset, byteLength])
                  numRecords.times { |ii|
                    #score = retScoreObj.returnRealScores(inflatedBuffer, ii)     
                    score = 5.9
                    zoomObj.addNewScore(score, start) if(score != 4290772992.0000)
                    start += 1
                  }
                else
                  fileReader.seek(offset)
                  buffer = ''
                  if(byteLength > 32_000)
                    buffer << fileReader.read(byteLength)
                    byteRead = byteLength
                  else
                    buffer = fileReader.read(32_000)
                    byteRead = buffer.size
                  end
                  bufferOffset = 0
                  inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                  numRecords.times { |ii|
                    score = 2.3
                    #score = retScoreObj.returnRealScores(inflatedBuffer, ii)     
                    zoomObj.addNewScore(score, start) if(score != 4290772992.0000)
                    start += 1
                  }
                  startOffset = offset
                end
              end
              zInflater.reset()
              previousOffset = offset
            }
            $stderr.print(".")
          }
          insertCount = 0
          arrayToInsert = []
          binner = BRL::SQL::Binning.new
          zoomObj.zoomLevelRecsHash.each_key { |res|
            zoomObj.zoomLevelRecsHash[res].each_key { |zStart|
              tempArray = zoomObj.zoomLevelRecsHash[res][zStart]
              arrayToInsert[insertCount] = [nil, tempArray[1], ftypeId, frefHash[chrom][1], binner.bin(BRL::SQL::MIN_BIN, tempArray[2], tempArray[3]), tempArray[2], tempArray[3], tempArray[4], tempArray[5], tempArray[6], tempArray[7], tempArray[8]]
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
          $stderr.puts "\nchrom: #{chrom} processed\n"
        }
        $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} done"
      elsif(!recordType.empty? and recordType[0][0] == 'int8Score')
        $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} has recordType: int8Score"
      elsif(recordType.empty?)
        $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} is not a HDHV track. skipping..."
      end
    rescue Exception => errTrack
      $stderr.puts "error with track: #{track['fmethod']}:#{track['fsource']} in db: #{dbName}. ERROR: #{errTrack}"
      next
    end
  }
  rescue Exception => err
    # skip to the next database
    $stderr.puts "error with db: #{dbName}. ERROR: #{err}. Not user db?"
    next
  end
  $stderr.puts "db: #{dbName} done"
}
$stderr.puts "all done"