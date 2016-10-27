#!/usr/bin/env ruby

# This script updates the new 'numScores' column in blockLevelDataInfo table
# NOTES: this script must be run from a directory that is not world or group
# readable or writable because of the rubyinline code.

require "rubygems"
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/hdhv'
require 'zlib'
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
ENV['DBRC_FILE']
ENV['PATH']

# C class for quickly going through the binary data and returning back the number
# of non NaN scores for each record in the 'blockLevelDataInfo' table
class AddNumScores

  include BRL::C

  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
    builder.include(CFunctionWrapper::MATH_HEADER_INCLUDE)
    builder.include(CFunctionWrapper::GLIB_HEADER_INCLUDE)
    builder.c <<-EOC

    /* Allocate memory for storing wiggle records. This buffer will be reused every time the C classes for the wiggle formula are called */
    int returnRealScores(VALUE scores, int numRecords, int dataSpan)
    {
      void *scr = RSTRING_PTR(scores);
      int nonNanValues = 0;
      if(dataSpan == 4)
      {
        guint32 *nullDetect = (guint32 *)scr;
        guint32 nullForFloatScore = (guint32)4290772992;
        int i = 0;
        while(i < numRecords)
        {
          if(*nullDetect != nullForFloatScore)
          {
            nonNanValues ++;
          }
          nullDetect ++;
          i ++;
        }
      }

      else if(dataSpan == 8)
      {
        guint64 *nullDetect = (guint64 *)scr;
        guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336);
        int i;
        for(i = 0; i < numRecords; i++)
        {
          if(*nullDetect != nullForDoubleScore)
          {
            nonNanValues += 1;
          }
          nullDetect ++;
        }
      }
      return nonNanValues;
    }
    EOC
  }
end

# Script begins from here
gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
dbs = dbu.selectAllDbNamesFromRefseq
# Go through each database
dbs.each { |db|
  begin
    dbName = db['databaseName']
    dbu.setNewDataDb(dbName)
    dbu.connectToDataDb # caching enabled, but will force each *user data* dbh closed as we are done with them below
    $stderr.puts "connected to db: #{dbName}"
    # get all entry points for the database
    frefHash = Hash.new
    allFrefRecords = dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!frefHash.has_key?(record['refName']))
    }
    dir = dbu.selectValueFmeta('RID_SEQUENCE_DIR')
    if(dir and !dir.empty?)
      dir = dir.first['fvalue']
      tracks = dbu.selectAllFtypes
      # Go through each track
      tracks.each { |track|
        begin
          ftypeId = track['ftypeid'].to_i
          recordType = dbu.getTrackRecordType(ftypeId)
          if(!recordType.empty? and (recordType[0][0] == 'floatScore' or recordType[0][0] == 'doubleScore'))
            dataSpan = (recordType[0][0] == 'floatScore' ? 4 : 8)
            $stderr.puts "processing track: #{track['fmethod']}:#{track['fsource']}"
            $stderr.puts "NOTE: record type is double score!" if(recordType[0][0] == 'doubleScore')
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
              addScoreObj = AddNumScores.new()
              $stderr.puts "\nprocessing chrom: #{chrom}"
              dbu.selectBlockLevelDataInfoByFtypeIdAndRid(ftypeId, frefHash[chrom][1], BLOCKSIZE=10_000) {|blockLevelRec|
                repArray = []
                repCount = 0
                blockLevelRec.size.times { |blockRec|
                  offset = blockLevelRec[blockRec]['offset'].to_i
                  byteLength = blockLevelRec[blockRec]['byteLength'].to_i
                  numRecords = blockLevelRec[blockRec]['numRecords'].to_i
                  start = blockLevelRec[blockRec]['fstart'].to_i
                  stop = blockLevelRec[blockRec]['fstop'].to_i
                  span = blockLevelRec[blockRec]['gbBlockBpSpan'].nil? ? nil : blockLevelRec[blockRec]['gbBlockBpSpan'].to_i
                  step = blockLevelRec[blockRec]['gbBlockBpStep'].nil? ? nil : blockLevelRec[blockRec]['gbBlockBpStep'].to_i
                  scale = blockLevelRec[blockRec]['gbBlockScale'].nil? ? nil : blockLevelRec[blockRec]['gbBlockScale'].to_f
                  lowLimit = blockLevelRec[blockRec]['gbBlockLowLimit'].nil? ? nil : blockLevelRec[blockRec]['gbBlockLowLimit'].to_f
                  if(!fileHash.has_key?(blockLevelRec[blockRec]['fileName']))
                    fileReader = BRL::Util::TextReader.new("#{dir}/#{blockLevelRec[blockRec]['fileName']}")
                    fileHash[blockLevelRec[blockRec]['fileName']] = nil
                    fileReader.seek(offset)
                    if(byteLength > 16_000_000)
                      buffer = fileReader.read(byteLength)
                      byteRead = byteLength
                    else
                      buffer = fileReader.read(16_000_000)
                      byteRead = buffer.size
                    end
                    bufferOffset = 0
                    inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                    numScores = addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                    startOffset = offset
                    repArray[repCount] = [blockLevelRec[blockRec]['id'].to_i, blockLevelRec[blockRec]['fileName'], offset, byteLength, numRecords, numScores,
                                          blockLevelRec[blockRec]['rid'].to_i, ftypeId, blockLevelRec[blockRec]['fstart'].to_i, blockLevelRec[blockRec]['fstop'].to_i,
                                          blockLevelRec[blockRec]['fbin'].to_f, span, step, scale, lowLimit]
                    repCount += 1
                  else
                    numScores = 0
                    if((startOffset + byteRead) > (offset + byteLength))
                      bufferOffset = bufferOffset + (offset - previousOffset)
                      inflatedBuffer = zInflater.inflate(buffer[bufferOffset, byteLength])
                      numScores = addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                    else
                      fileReader.seek(offset)
                      buffer = ''
                      if(byteLength > 16_000_000)
                        buffer << fileReader.read(byteLength)
                        byteRead = byteLength
                      else
                        buffer = fileReader.read(16_000_000)
                        byteRead = buffer.size
                      end
                      bufferOffset = 0
                      inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                      numScores = addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                      startOffset = offset
                    end
                    repArray[repCount] = [blockLevelRec[blockRec]['id'].to_i, blockLevelRec[blockRec]['fileName'], offset, byteLength, numRecords, numScores,
                                          blockLevelRec[blockRec]['rid'].to_i, ftypeId, blockLevelRec[blockRec]['fstart'].to_i, blockLevelRec[blockRec]['fstop'].to_i,
                                          blockLevelRec[blockRec]['fbin'].to_f, span, step, scale, lowLimit]
                    repCount += 1
                  end
                  zInflater.reset()
                  previousOffset = offset
                }
                dbu.replaceBlockLevelDataInfoRecords(repArray, repCount) if(!repArray.nil? and !repArray.empty?)
                repArray.clear
                $stderr.print(".")
              }
              $stderr.puts "\nchrom: #{chrom} processed\n"
            }
            $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} done"
          elsif(!recordType.empty? and recordType[0][0] == 'int8Score')
            $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} has recordType: int8Score. Skipping. Wib track?"
          end
        rescue Exception => errTrack
          $stderr.puts "error with track: #{track['fmethod']}:#{track['fsource']} in db: #{dbName}. ERROR: #{errTrack}"
          next
        end
      }
    else
      $stderr.puts "error with db: #{dbName}. No RID_SEQUENCE_DIR in fmeta? No sequence data and/or no hdhv data."
    end
  rescue Exception => err
    # skip to the next database
    $stderr.puts "error with db: #{dbName}. ERROR: #{err}.\n#{err.backtrace.join("\n")}"
    next
  end
  # because cached, set the "forceClosed" arg to true when closing:
  closedOk = dbu.closeDbh(dbu.dataDbh, true)
  $stderr.puts "db: #{dbName} done (closed ok? #{closedOk})"
  $stderr.puts "db: #{dbName} done"
}
$stderr.puts "all done"
