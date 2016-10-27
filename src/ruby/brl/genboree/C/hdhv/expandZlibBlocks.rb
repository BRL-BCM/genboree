#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# An inline C class to expand zlib streams using C.
# Used by the ruby side to uncompress each block of wig binary data
# [+returns+] 1 or 0: 1 for success or 0 for failed
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
    /* An inline C function to uncompress wig binary data streams */
    int expandBlock(VALUE compressedBlock, VALUE expandedBlock, int span, int numRecords, int byteLength, int bufferOffset)
    {
      /* Initialize variables */
      int decompressedBlockSize = span * numRecords ;
      int ret ;
      z_stream strm ;
      int retVal = 1 ;

      /* Get pointers for ruby stuff */
      void *comprBlock = RSTRING_PTR(compressedBlock) ;
      void *expandBlock = RSTRING_PTR(expandedBlock) ;
      char *compBlock = (char *)comprBlock ;
      char *decompressedBlock = (char *)expandBlock ;
      compBlock += bufferOffset ;

      // Initialize zlib specific variables
      strm.zalloc = Z_NULL ;
      strm.zfree = Z_NULL ;
      strm.opaque = Z_NULL ;
      strm.avail_in = 0 ;
      strm.next_in = Z_NULL ;
      ret = inflateInit(&strm) ;
      if(ret != Z_OK){
        fprintf(stderr, "zlib_Error_1: %d\\n", ret) ; // should be printed to thin/apache logs
        return 0 ;
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
          if(ret == Z_STREAM_ERROR)
          {
            retVal = 0 ;
            break ;
          }
          /* Make sure it was a successful decompression */
          switch (ret) {
            case Z_NEED_DICT:
              ret = Z_DATA_ERROR ;
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
              (void)inflateEnd(&strm) ;
              fprintf(stderr, "zlib_Error_2: %d\\n", ret) ; // should be printed to thin/apache logs
          }
          //fprintf(stderr, "ZLIB: avail.out: %d, decompressedBlockSize: %d\\n", strm.avail_out, decompressedBlockSize) ;
        } while (strm.avail_out == 0) ;
        if(retVal == 0)
        {
          break ;
        }
        //if(ret != Z_STREAM_END)
        //{
        //  fprintf(stderr, "zlib expand block did not encounter zstream end (retVal): %d\\n", ret) ;
        //}
      } while (ret != Z_STREAM_END) ;
      if(retVal == 1)
      {
       (void)inflateEnd(&strm) ;
        RSTRING_LEN(expandedBlock) = decompressedBlockSize ;
      }
      return retVal ;
    }
    EOC
  }
end
end; end; end; end
