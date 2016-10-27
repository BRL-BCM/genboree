#!/usr/bin/env ruby

# This script updates the 'ftypeCount' table for HD tracks with the number of non NaN scores for that track
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

# A c class to expand zlib streams using C.
# This will prevent creating too many ruby strings (for each of the expand)
class ExpandZlibBlocks
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib, :zlib))
    builder.include CFunctionWrapper::LIMITS_HEADER_INCLUDE
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::MATH_HEADER_INCLUDE
    builder.include CFunctionWrapper::ZLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::ASSERT_HEADER_INCLUDE
    builder.c <<-EOC
    /* Allocate memory for storing wiggle records. This buffer will be reused every time the C classes for the wiggle formula are called */
    void expandBlock(VALUE compressedBlock, VALUE expandedBlock, int span, int numRecords, int byteLength, int bufferOffset)
    {
      int decompressedBlockSize = span * numRecords ;
      int ret ;
      z_stream strm ;
      /* Get pointers for ruby stuff */
      void *comprBlock = RSTRING_PTR(compressedBlock) ;
      void *expandBlock = RSTRING_PTR(expandedBlock) ;
      char *compBlock = (char *)comprBlock ;
      char *decompressedBlock = (char *)expandBlock ;
      compBlock += bufferOffset ;
      // Initialize zlib variables
      strm.zalloc = Z_NULL ;
      strm.zfree = Z_NULL ;
      strm.opaque = Z_NULL ;
      strm.avail_in = 0 ; 
      strm.next_in = Z_NULL ;
      ret = inflateInit(&strm) ;
      if(ret != Z_OK){
        fprintf(stderr, "zlib_Error_1: %d", ret) ;
        exit(EXIT_FAILURE) ;
      }
      // Inflate zlib stream
      // decompress until deflate stream ends 
      do {
        strm.avail_in = byteLength ;
        strm.next_in = compBlock ;
        // run inflate() on input until output buffer not full
        do {
          strm.avail_out = decompressedBlockSize ;
          strm.next_out = decompressedBlock ;
          ret = inflate(&strm, Z_NO_FLUSH) ;
          assert(ret != Z_STREAM_ERROR) ;  //state not clobbered
          switch (ret) {
            case Z_NEED_DICT:
              ret = Z_DATA_ERROR ;     // and fall through 
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
              (void)inflateEnd(&strm) ;
            fprintf(stderr, "zlib_Error_2: %d", ret) ;
            exit(EXIT_FAILURE) ;
          }
        } while (strm.avail_out == 0) ;
      } while (ret != Z_STREAM_END) ;
      (void)inflateEnd(&strm) ;
      RSTRING_LEN(expandedBlock) = decompressedBlockSize ;
    }
    EOC
  }
end

# A C Class for allocating memory using the 'malloc' function in C
# This class can be used for efficiently allocating memory for a block of
# high density data which ruby can use
# [+span+] byte span for each record
# [+blockSize+] No of records in the block
# [+returns+] An empty ruby string with size = span * blockSize
class CreateBuffer
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base))
    builder.c <<-EOC
    /* Allocate memory for storing wiggle records. This buffer will be reused every time the C classes for the wiggle formula are called */
    VALUE createBuffer(int span, int blockSize)
    {
      /* Allocating memory*/
      int sizeOfBuffer = (span * blockSize) ;
      char* buff = (char *)malloc(sizeOfBuffer) ;
      VALUE buffer = rb_str_new(buff, sizeOfBuffer) ;
      free(buff) ;
      return buffer ;
    }
    EOC
  }
end

# Script begins from here
gc = BRL::Genboree::GenboreeConfig.load
dbu = BRL::Genboree::DBUtil.new("#{gc.dbrcKey}", nil, nil)
dbs = dbu.selectAllDbNamesFromRefseq
#dbs = ['genboree_r_ffcd153762307558f2b841826055aa96']
zInflator = ExpandZlibBlocks.new()
addScoreObj = AddNumScores.new()
expandBufferObj = CreateBuffer.new()
expandBuffer = expandBufferObj.createBuffer(4, 2_000_000)
expandBufferSize = 8_000_000
# Go through each database
dbs.each { |db|
  begin
    dbName = db['databaseName']
    #dbName = db
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
            numScores = 0
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
              #zInflater = Zlib::Inflate.new()
              $stderr.puts "\nprocessing chrom: #{chrom}"
              dbu.selectBlockLevelDataInfoByFtypeIdAndRid(ftypeId, frefHash[chrom][1], BLOCKSIZE=10_000) {|blockLevelRec|
                blockLevelRec.size.times { |blockRec|
                  offset = blockLevelRec[blockRec]['offset'].to_i
                  byteLength = blockLevelRec[blockRec]['byteLength'].to_i
                  if(byteLength < 1)
                    $stderr.puts "Warning. byteLength < 1. skipping.."
                    next
                  end
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
                    #inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                    if(dataSpan * numRecords > expandBufferSize)
                      expandBuffer = expandBufferObj.createBuffer(dataSpan, numRecords)
                      expandBufferSize = dataSpan * numRecords
                    end
                    zInflator.expandBlock(buffer, expandBuffer, dataSpan, numRecords, byteLength, bufferOffset)
                    #numScores += addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                    numScores += addScoreObj.returnRealScores(expandBuffer, numRecords, dataSpan)
                    startOffset = offset
                  else
                    if((startOffset + byteRead) > (offset + byteLength))
                      bufferOffset = bufferOffset + (offset - previousOffset)
                      #inflatedBuffer = zInflater.inflate(buffer[bufferOffset, byteLength])
                      #numScores += addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                      if(dataSpan * numRecords > expandBufferSize)
                        expandBuffer = expandBufferObj.createBuffer(dataSpan, numRecords)
                        expandBufferSize = dataSpan * numRecords
                      end
                      zInflator.expandBlock(buffer, expandBuffer, dataSpan, numRecords, byteLength, bufferOffset)
                      numScores += addScoreObj.returnRealScores(expandBuffer, numRecords, dataSpan)
                    else
                      fileReader.seek(offset)
                      buffer = ''
                      if(byteLength > 16_000_000)
                        buffer = fileReader.read(byteLength)
                        byteRead = byteLength
                      else
                        buffer = fileReader.read(16_000_000)
                        byteRead = buffer.size
                      end
                      bufferOffset = 0
                      #inflatedBuffer = zInflater.inflate(buffer[0, byteLength])
                      #numScores += addScoreObj.returnRealScores(inflatedBuffer, numRecords, dataSpan)
                      if(dataSpan * numRecords > expandBufferSize)
                        expandBuffer = expandBufferObj.createBuffer(dataSpan, numRecords)
                        expandBufferSize = dataSpan * numRecords
                      end
                      zInflator.expandBlock(buffer, expandBuffer, dataSpan, numRecords, byteLength, bufferOffset)
                      numScores += addScoreObj.returnRealScores(expandBuffer, numRecords, dataSpan)
                      startOffset = offset
                    end
                  end
                  #zInflater.reset()
                  previousOffset = offset
                }
                $stderr.print "."
              }
              $stderr.puts "\nchrom: #{chrom} processed\n"
            }
            dbu.updateNumberOfAnnotationsByFtypeid(ftypeId, numScores)
            $stderr.puts "track: #{track['fmethod']}:#{track['fsource']} (ftypeid: #{ftypeId}). numScores: #{numScores}. Done"
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
