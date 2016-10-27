#!/usr/bin/env ruby

# Load libraries and env
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/C/hdhv/makeWigLine'
require 'brl/genboree/C/hdhv/updateAggregates'
require 'brl/genboree/C/hdhv/makeNonWigLine'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# An inline C class for aggregating and printing collapsed scores for high density high volume (HDHV) data
# [+returns+] 1 or 0 : indicating if the window/span had any 'real' scores or not. 1 indicates all NaNs (empty window)
class PrintCollapsedScores
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib, :zlib))
    builder.include CFunctionWrapper::LIMITS_HEADER_INCLUDE
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::MATH_HEADER_INCLUDE
    builder.prefix(
      CFunctionWrapper.comparisonFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.medianFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.meanFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.maxFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.minFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.sumFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.stdevFunctions('gfloat', 'gdouble', 'guint8') +
      MakeWigLine.makeWigLineWithGFloat() +
      MakeWigLine.makeWigLineWithGDouble() +
      MakeWigLine.makeWigLineWithGuInt8() +
      MakeWigLine.makeWigLineWithEmptyScoreValue() +
      UpdateAggregates.updateAggForGFloat() +
      UpdateAggregates.updateAggForGDouble() +
      UpdateAggregates.updateAggForGuInt8() +
      MakeNonWigLine.makeNonWigLineWithGFloat() +
      MakeNonWigLine.makeNonWigLineWithGDouble() +
      MakeNonWigLine.makeNonWigLineWithGuInt8() +
      MakeNonWigLine.makeNonWigLineWithEmptyScoreValue() 
    )
    builder.c <<-EOC
    /* An inline C function for aggregating and printing collapsed scores for HDHV data  */
    int printScores(VALUE cBuffer, VALUE preCollapseBuffer, VALUE countBuff, VALUE attributeArr, VALUE optsArray, VALUE reqRegion,
                    VALUE chrom, long windowStart, VALUE emptyScoreValue, VALUE globalArray, VALUE medianBuffer, int retType, VALUE trackType, VALUE trackSubType, VALUE scaleInfo)
    {
      /* Initialize variables */
      int base = 0 ;
      int nonNaNScores = 0 ;
      int ret ;
      int length = 0 ;
      
      /* Get pointers for ruby objects */
      void *preCBuffer = RSTRING_PTR(preCollapseBuffer) ;
      void *countB = RSTRING_PTR(countBuff) ;
      guint32 *countBuffer = (guint32 *)countB ;
      void *tempBuff = RSTRING_PTR(cBuffer) ;
      guchar *outBuffer = (guchar *)tempBuff ;
      void *medianBuff = RSTRING_PTR(medianBuffer) ;
      long dataSpan = FIX2LONG(rb_ary_entry(attributeArr, 0)) ;
      long denom = FIX2LONG(rb_ary_entry(attributeArr, 1)) ;
      long desiredSpan = FIX2LONG(rb_ary_entry(optsArray, 0)) ;
      long spanAggFunction = FIX2LONG(rb_ary_entry(optsArray, 1)) ;
      long modLastSpan = FIX2LONG(rb_ary_entry(optsArray, 2)) ;
      char *emptyScoreVal = STR2CSTR(emptyScoreValue) ;
      char *emptyVal = NULL ;
      if(strlen(emptyScoreVal) > 0)
      {
        emptyVal = emptyScoreVal ;
      }
      char *chr = STR2CSTR(chrom) ;
      char *ctype = STR2CSTR(trackType) ;
      char *csubtype = STR2CSTR(trackSubType) ;
      long startLandmark = FIX2LONG(rb_ary_entry(reqRegion, 0)) ;
      long stopLandmark = FIX2LONG(rb_ary_entry(reqRegion, 1)) ;
      VALUE spanSumRuby = rb_ary_entry(globalArray, 4) ;
      double spanSum = RFLOAT(spanSumRuby)->value ;
      long spanCount = FIX2LONG(rb_ary_entry(globalArray, 5)) ;
      VALUE spanMaxRuby = rb_ary_entry(globalArray, 6) ;
      double spanMax = RFLOAT(spanMaxRuby)->value ;
      VALUE spanMinRuby = rb_ary_entry(globalArray, 7) ;
      double spanMin = RFLOAT(spanMinRuby)->value ;
      VALUE spanSoqRuby = rb_ary_entry(globalArray, 8) ;
      double spanSoq = RFLOAT(spanSoqRuby)->value ;
      VALUE trackWideMin = rb_ary_entry(globalArray, 9) ;
      double trackMin = RFLOAT(trackWideMin)->value ;
      VALUE trackWideMax = rb_ary_entry(globalArray, 10) ;
      double trackMax = RFLOAT(trackWideMax)->value ;
      int scaleScores = FIX2LONG(rb_ary_entry(scaleInfo, 0)) ;
      VALUE scaleFac = rb_ary_entry(scaleInfo, 1) ;
      double scaleFactor = RFLOAT(scaleFac)->value ;
      guint32 nullForFloatScore = (guint32)4290772992 ;
      guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
      guint8 nullForInt8Score = (guint8)(denom + 1) ;
      char *preC = (char *)preCBuffer ;
      char *cB = (char *)countB ;
      gfloat *preCBuff = (gfloat *)preCBuffer ;
      gfloat *medBuffer = (gfloat *)medianBuff ;
      gdouble *preCBuffDouble = (gdouble *)preCBuffer ;
      gdouble *medBufferDouble = (gdouble *)medianBuff ;
      int windowEnd = windowStart + (desiredSpan - 1) ;
      
      // For modulus last span option, need to check if window end is going beyond the requested region
      if(modLastSpan == 1)
      {
        windowEnd = windowEnd > stopLandmark ? stopLandmark : windowEnd ;
      }
      
      /* Depending on the data/storage type, we need to cast postCollapseBuffer and preCollapseBuffer appropriately */
      switch(dataSpan)
      {
        case 4 : ;// floatScore
        
          /* loop over and perform aggregation */
          base = 0 ;
          while(base < desiredSpan)
          {
            if(countBuffer[base] >= 1)
            {
              if(spanAggFunction != 1)
              {
                updateAggForGFloat(spanAggFunction, (gfloat)(preCBuff[base] / countBuffer[base]), &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
              }
              else
              {
                medBuffer[base] = (gfloat)(preCBuff[base] / countBuffer[base]) ;
              }
              nonNaNScores += 1 ;
            }
            base += 1 ;
          }
          
          /* return if no 'real' scores found */
          if(nonNaNScores == 0)
          {
            if(emptyVal == NULL)
            {
              return 1 ;
            }
            else
            {
              if(retType <= 2)
              {
                ret = makeWigLineWithEmptyScoreValue(outBuffer, emptyVal, retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;// adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithEmptyScoreValue(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, emptyVal) ;
              }
              RSTRING_LEN(cBuffer) = ret ;
              return 0 ;
            }
          }
          
          /* Finally print the score to the buffer */
          switch(spanAggFunction)
          {
            case 2 : // mean
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum / spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;// adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum / spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 3 : // max
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanMax), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanMax), trackMin, scaleFactor) ;
              }
              break ;
            case 4 : // min
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanMin), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanMin), trackMin, scaleFactor) ;
              }
              break ;
            case 5 : // sum
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum), trackMin, scaleFactor) ;
              }
              break ;
            case 6 : // stdev
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), trackMin, scaleFactor) ;
              }
              break ;
            case 7 : // count
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 8 : // avgBylength
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum / desiredSpan), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum / desiredSpan), trackMin, scaleFactor) ;
              }
              break ;
            default : // median
              if(nonNaNScores == 1)
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGFloat(outBuffer, medBuffer[0], retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, medBuffer[0], trackMin, scaleFactor) ;
                }
              }
              else 
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGFloat(outBuffer, calcMedianForGfloat(medBuffer, nonNaNScores), retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, calcMedianForGfloat(medBuffer, nonNaNScores), trackMin, scaleFactor) ;
                }
              }
              break ;
          }
          length += ret ;
          
          /* reset the window buffers to 0 */
          memset(preC, 0, desiredSpan * sizeof(gfloat)) ;
          memset(cB, 0, desiredSpan * sizeof(guint32)) ;
          break ;
        
        case 8 : ;// doubleScore
         
          
          /* loop over and perform aggregation */
          base = 0 ;
          while(base < desiredSpan)
          {
            if(countBuffer[base] >= 1)
            {
              if(spanAggFunction != 1)
              {
                updateAggForGDouble(spanAggFunction, (gdouble)(preCBuffDouble[base] / countBuffer[base]), &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
              }
              else
              {
                medBufferDouble[base] = (gdouble)(preCBuffDouble[base] / countBuffer[base]) ;
              }
              nonNaNScores += 1 ;
            }
            base += 1 ;
          }
          
          /* return if no 'real' scores found */
          if(nonNaNScores == 0)
          {
            if(emptyVal == NULL)
            {
              return 1 ;
            }
            else
            {
              if(retType <= 2)
              {
                ret = makeWigLineWithEmptyScoreValue(outBuffer, emptyVal, retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;// adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithEmptyScoreValue(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, emptyVal) ;
              }
              RSTRING_LEN(cBuffer) = ret ;
              return 0 ;
            }
          }
          
          /* Finally print the score to the buffer */
          switch(spanAggFunction)
          {
            case 2 : // mean
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanSum / spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ; // adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanSum / spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 3 : // max
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanMax), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanMax), trackMin, scaleFactor) ;
              }
              break ;
            case 4 : // min
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanMin), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanMin), trackMin, scaleFactor) ;
              }
              break ;
            case 5 : // sum
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanSum), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanSum), trackMin, scaleFactor) ;
              }
              break ;
            case 6 : // stdev
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), trackMin, scaleFactor) ;
              }
              break ;
            case 7 : // count
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 8 : // avgBylength
              if(retType <= 2)
              {
                ret = makeWigLineWithGDouble(outBuffer, (gdouble)(spanSum / desiredSpan), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gdouble)(spanSum / desiredSpan), trackMin, scaleFactor) ;
              }
              break ;
            default : // median
              if(nonNaNScores == 1)
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGDouble(outBuffer, medBufferDouble[0], retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, medBufferDouble[0], trackMin, scaleFactor) ;
                }
              }
              else 
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGDouble(outBuffer, calcMedianForGdouble(medBufferDouble, nonNaNScores), retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGDouble(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, calcMedianForGdouble(medBufferDouble, nonNaNScores), trackMin, scaleFactor) ;
                }
              }
              break ;
          }
          length += ret ;
          
          /* reset the window buffers to 0 */
          memset(preC, 0, desiredSpan * sizeof(gdouble)) ;
          memset(cB, 0, desiredSpan * sizeof(guint32)) ;
          break ;
        
        case 1 : ;// int8Score
           /* loop over and perform aggregation */
          base = 0 ;
          while(base < desiredSpan)
          {
            if(*countBuffer >= 1)
            {
              if(spanAggFunction != 1)
              {
                updateAggForGFloat(spanAggFunction, (gfloat)(preCBuff[base] / countBuffer[base]), &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
              }
              else
              {
                medBuffer[base] = (gfloat)(preCBuff[base] / countBuffer[base]) ;
              }
              nonNaNScores += 1 ;
            }
            base += 1 ;
          }
          
          /* return if no 'real' scores found */
          if(nonNaNScores == 0)
          {
            if(emptyVal == NULL)
            {
              return 1 ;
            }
            else
            {
              if(retType <= 2)
              {
                ret = makeWigLineWithEmptyScoreValue(outBuffer, emptyVal, retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;// adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithEmptyScoreValue(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, emptyVal) ;
              }
              RSTRING_LEN(cBuffer) = ret ;
              return 0 ;
            }
          }
          
          /* Finally print the score to the buffer */
          switch(spanAggFunction)
          {
            case 2 : // mean
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum / spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;// adjust retType to match the cases for outputting non wig formats 
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum / spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 3 : // max
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanMax), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanMax), trackMin, scaleFactor) ;
              }
              break ;
            case 4 : // min
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanMin), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanMin), trackMin, scaleFactor) ;
              }
              break ;
            case 5 : // sum
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum), trackMin, scaleFactor) ;
              }
              break ;
            case 6 : // stdev
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), trackMin, scaleFactor) ;
              }
              break ;
            case 7 : // count
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanCount), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanCount), trackMin, scaleFactor) ;
              }
              break ;
            case 8 : // avgBylength
              if(retType <= 2)
              {
                ret = makeWigLineWithGFloat(outBuffer, (gfloat)(spanSum / desiredSpan), retType, windowStart) ;
              }
              else
              {
                retType -= 2 ;
                ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, (gfloat)(spanSum / desiredSpan), trackMin, scaleFactor) ;
              }
              break ;
            default : // median
              if(nonNaNScores == 1)
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGFloat(outBuffer, medBuffer[0], retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, medBuffer[0], trackMin, scaleFactor) ;
                }
              }
              else 
              {
                if(retType <= 2)
                {
                  ret = makeWigLineWithGFloat(outBuffer, calcMedianForGfloat(medBuffer, nonNaNScores), retType, windowStart) ;
                }
                else
                {
                  retType -= 2 ;
                  ret = makeNonWigLineWithGFloat(outBuffer, retType, windowStart, windowEnd, chr, ctype, csubtype, scaleScores, calcMedianForGfloat(medBuffer, nonNaNScores), trackMin, scaleFactor) ;
                }
              }
              break ;
          }
          length += ret ;
          
          /* reset the window buffers to 0 */
          memset(preC, 0, desiredSpan * sizeof(gfloat)) ;
          memset(cB, 0, desiredSpan * sizeof(guint32)) ;
          break ;
        
      }
      /* save global ruby objects */
      spanMax = trackMin ;
      spanMin = trackMax ;
      spanSoq = 0.0 ;
      spanSum = 0.0 ;
      spanCount = 0 ;
      RSTRING_LEN(cBuffer) = length;
      rb_ary_store(globalArray, 4, rb_float_new(spanSum)) ;
      rb_ary_store(globalArray, 5, LONG2FIX(spanCount)) ;
      rb_ary_store(globalArray, 6, rb_float_new(spanMax)) ;
      rb_ary_store(globalArray, 7, rb_float_new(spanMin)) ;
      rb_ary_store(globalArray, 8, rb_float_new(spanSoq)) ;
      return 0;
    }
    EOC
  }
  
end
end; end ; end; end 