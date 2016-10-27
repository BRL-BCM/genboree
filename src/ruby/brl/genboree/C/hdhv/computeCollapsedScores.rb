#!/usr/bin/env ruby
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# An inline C class for computing collapsed scores for high density high volume (HDHV) data
class ComputeCollapsedScores
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib, :zlib))
    builder.include CFunctionWrapper::LIMITS_HEADER_INCLUDE
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::MATH_HEADER_INCLUDE
    builder.c <<-EOC
    /* An inline C function to compute collapsed scores for HDHV data  */
    void computeScores( VALUE preCollapseBuffer, VALUE countBuff, VALUE scoreBuffer, VALUE attributeArr, VALUE blockInfo,
        VALUE optsArray, VALUE reqRegion, VALUE chrom, long windowStart, VALUE emptyScoreValue)
    {
      /* Initialize variables */
      int numRecords  ;
      int recordsProcessed = 0 ;
      long windowEnd ;
      int realScores = 0 ;
      
      /* Get pointers for ruby objects */
      void *preCBuffer = RSTRING_PTR(preCollapseBuffer) ;
      void *countB = RSTRING_PTR(countBuff) ;
      guint32 *countBuffer = (guint32 *)countB ;
      void *scrBuffer = RSTRING_PTR(scoreBuffer) ;
      long dataSpan = FIX2LONG(rb_ary_entry(attributeArr, 0)) ;
      long denom = FIX2LONG(rb_ary_entry(attributeArr, 1)) ;
      long blockStart = FIX2LONG(rb_ary_entry(blockInfo, 0)) ;
      long blockStop = FIX2LONG(rb_ary_entry(blockInfo, 1)) ;
      long blockScale = FIX2LONG(rb_ary_entry(blockInfo, 2)) ;
      long blockLowLimit = FIX2LONG(rb_ary_entry(blockInfo, 3)) ;
      long desiredSpan = FIX2LONG(rb_ary_entry(optsArray, 0)) ;
      long spanAggFunction = FIX2LONG(rb_ary_entry(optsArray, 1)) ;
      long modLastSpan = FIX2LONG(rb_ary_entry(optsArray, 2)) ;
      long startLandmark = FIX2LONG(rb_ary_entry(reqRegion, 0)) ;
      long stopLandmark = FIX2LONG(rb_ary_entry(reqRegion, 1)) ;
      
      // floatScore pointers
      gfloat *preCBuff = (gfloat *)preCBuffer ;
      gfloat *scrBuff = (gfloat *)scrBuffer ;
      guint32 *nullCheck = (guint32 *)scrBuffer ;
      guint32 nullForFloatScore = (guint32)4290772992 ;
      
      // doubleScore pointers
      gdouble *preCBuffDouble = (gdouble *)preCBuffer ;
      gdouble *scrBuffDouble = (gdouble *)scrBuffer ;
      guint64 *nullCheckDouble = (guint64 *)scrBuffer ;
      guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
      
      //int8Score pointers
      guint8 *scrBuffInt8 = (guint8 *)scrBuffer ;
      guint8 *nullCheckInt8 = (guint8 *)scrBuffer ;
      guint8 nullForInt8Score = (guint8)(denom + 1) ;
      
      /* Depending on the data/storage type, we need to cast the score buffer and preCollapseBuffer appropriately */
      switch(dataSpan)
      {
        case 4 :  // floatScore
          
          /* Need to make sure that we are updating the right bases */
          if(windowStart < blockStart)
          {
            preCBuff = preCBuff + (blockStart - windowStart) ;
            countBuffer = countBuffer + (blockStart - windowStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = ((windowEnd - windowStart) + 1) - (blockStart - windowStart) ;
          }
          else if(windowStart > blockStart)
          {
            scrBuff = scrBuff + (windowStart - blockStart) ;
            nullCheck = nullCheck + (windowStart - blockStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          else //equal
          {
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          
          /* walk over required bases and update the buffers */
          while(recordsProcessed < numRecords)
          {
            if(*nullCheck != nullForFloatScore)
            {
              realScores += 1 ;
              *preCBuff += *scrBuff ;
              *countBuffer += 1 ;  
            }
            recordsProcessed += 1 ;
            if(recordsProcessed < numRecords)
            {
              preCBuff ++ ;
              countBuffer ++ ;
              nullCheck ++ ;
              scrBuff ++ ;
            }
          }
          break ;
        
        case 8 : // doubleScore
          /* Need to make sure that we are updating the right bases */
          if(windowStart < blockStart)
          {
            preCBuffDouble = preCBuffDouble + (blockStart - windowStart) ;
            countBuffer = countBuffer + (blockStart - windowStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = ((windowEnd - windowStart) + 1) - (blockStart - windowStart) ;
          }
          else if(windowStart > blockStart)
          {
            scrBuffDouble = scrBuffDouble + (windowStart - blockStart) ;
            nullCheckDouble = nullCheckDouble + (windowStart - blockStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          else //equal
          {
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          
          /* walk over required bases and update the buffers */
          while(recordsProcessed < numRecords)
          {
            if(*nullCheckDouble != nullForDoubleScore)
            {
              realScores += 1 ;
              *preCBuffDouble += *scrBuffDouble ;
              *countBuffer += 1 ;  
            }
            recordsProcessed += 1 ;
            if(recordsProcessed < numRecords)
            {
              preCBuffDouble ++ ;
              countBuffer ++ ;
              nullCheckDouble ++ ;
              scrBuffDouble ++ ;  
            }
          }
          
          break ;
        
        case 1 : // int8Score
          /* Need to make sure that we are updating the right bases */
          if(windowStart < blockStart)
          {
            preCBuff = preCBuff + (blockStart - windowStart) ;
            countBuffer = countBuffer + (blockStart - windowStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = ((windowEnd - windowStart) + 1) - (blockStart - windowStart) ;
          }
          else if(windowStart > blockStart)
          {
            scrBuffInt8 = scrBuffInt8 + (windowStart - blockStart) ;
            nullCheck = nullCheck + (windowStart - blockStart) ;
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          else //equal
          {
            windowEnd = windowStart + (desiredSpan - 1) ;
            windowEnd = windowEnd <= blockStop ? windowEnd : blockStop ;
            numRecords = (windowEnd - windowStart) + 1 ; 
          }
          
          /* walk over required bases and update the buffers */
          while(recordsProcessed < numRecords)
          {
            if(*nullCheckInt8 != nullForInt8Score)
            {
              realScores += 1 ;
              *preCBuff += (gfloat)(blockLowLimit + (blockScale * (*scrBuffInt8 / denom))) ;
              *countBuffer += 1 ;  
            }
            recordsProcessed += 1 ;
            if(recordsProcessed < numRecords)
            {
              preCBuff ++ ;
              countBuffer ++ ;
              nullCheckInt8 ++ ;
              scrBuffInt8 ++ ;  
            }
          }
          break ;
      }
    }
    EOC
  }
  
end
end; end ; end; end 