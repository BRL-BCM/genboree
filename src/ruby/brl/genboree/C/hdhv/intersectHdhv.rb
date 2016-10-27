#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# A C class for intersecting high density tracks with non high density annotations
# This class keeps track of the aggregations
class IntersectHdhv
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib, :zlib))
    builder.include CFunctionWrapper::LIMITS_HEADER_INCLUDE
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::MATH_HEADER_INCLUDE
    builder.include CFunctionWrapper::ZLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::ASSERT_HEADER_INCLUDE
    builder.c <<-EOC
    void intersectTracks(VALUE scores, VALUE globalArray, VALUE medianArray, int fstart, int fstop, int blockStart, int blockStop, int dataSpan, int spanAggFunction,
                         VALUE denomscalelowLimit, int medianLimit)
    {
      /* get pointers for ruby stuff */
      void *binScores = RSTRING_PTR(scores) ;
      long numberOfRealScores = FIX2LONG(rb_ary_entry(globalArray, 2)) ;
      VALUE spanSumRuby = rb_ary_entry(globalArray, 4) ;
      double spanSum = RFLOAT(spanSumRuby)->value ;
      long spanCount = FIX2LONG(rb_ary_entry(globalArray, 5)) ;
      VALUE spanMaxRuby = rb_ary_entry(globalArray, 6) ;
      double spanMax = RFLOAT(spanMaxRuby)->value ;
      VALUE spanMinRuby = rb_ary_entry(globalArray, 7) ;
      double spanMin = RFLOAT(spanMinRuby)->value ;
      VALUE spanSoqRuby = rb_ary_entry(globalArray, 8) ;
      double spanSoq = RFLOAT(spanSoqRuby)->value ;
      VALUE denominator = rb_ary_entry(denomscalelowLimit, 0) ;
      double denom = RFLOAT(denominator)->value ;
      VALUE scal = rb_ary_entry(denomscalelowLimit, 1) ;
      double scale = RFLOAT(scal)->value ;
      VALUE lowLim = rb_ary_entry(denomscalelowLimit, 2) ;
      double lowLimit = RFLOAT(lowLim)->value ;

      /* Initialize variables */
      int bpStart ;
      int bpStop ;
      int numRecords ;
      int recProcessed = 0 ;
      guint32 nullForFloatScore = (guint32)4290772992 ;
      guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
      guint8 nullForInt8Score = (guint8)(denom + 1) ;
      gfloat *floatScore = (gfloat *)binScores ;
      guint32 *nullCheck32 = (guint32 *)binScores ;
      gdouble *doubleScore = (gdouble *)binScores ;
      guint64 *nullCheck64 = (guint64 *)binScores ;
      guint8 *int8Score = (guint8 *)binScores ;
      void *medArray = RSTRING_PTR(medianArray) ;
      gfloat *arrayToSort = (gfloat *)medArray ;
      gdouble *arrayToSortDouble = (gdouble *)medArray ;
      guint8 *arrayToSortInt8 = (guint8 *)medArray ;
      if(fstart >= blockStart)
      {
        switch(dataSpan)
        {
          case 4 : //floatScore
            floatScore += (fstart - blockStart) ;
            nullCheck32 += (fstart - blockStart) ;
            break ;
          case 8 : //doubleScore
            doubleScore += (fstart - blockStart) ;
            nullCheck64 += (fstart - blockStart) ;
            break ;
          case 1 : //int8Score
            int8Score += (fstart - blockStart) ;
            break ;
        }
        bpStart = fstart ;
      }
      else
      {
        bpStart = blockStart ;
      }
      if(fstop <= blockStop)
      {
        bpStop = fstop ;
      }
      else
      {
        bpStop = blockStop ;
      }
      numRecords = (bpStop - bpStart) + 1 ;

      /* go through required records */
      switch(dataSpan)
      {
        case 4 : //floatScore
          while(recProcessed < numRecords)
          {
            if(*nullCheck32 != nullForFloatScore)
            {
              switch(spanAggFunction)
              {
                case 2 :  // mean
                  spanSum += *floatScore ;
                  spanCount ++ ;
                  break ;
                case 3 :  // max
                  spanMax = *floatScore > spanMax ? *floatScore : spanMax ;
                  break ;
                case 4 :  // min
                  spanMin = *floatScore < spanMin ? *floatScore : spanMin ;
                  break ;
                case 5 :  // sum
                  spanSum += *floatScore ;
                  break ;
                case 6 :  // stdev
                  spanSoq += *floatScore * *floatScore ;
                  spanSum += *floatScore ;
                  spanCount ++ ;
                  break ;
                case 7 :  // count
                  spanCount ++ ;
                  break ;
                case 8 : // avgByLength
                  spanSum += *floatScore ;
                  break ;
                default : // median (spanAggFunction should be 1)
                  if(numberOfRealScores < medianLimit)
                  {
                    arrayToSort[numberOfRealScores] = *floatScore ;
                  }
                  break ;
              }
              if(numberOfRealScores < medianLimit)
              {
                numberOfRealScores ++ ;
              }
            }
            recProcessed ++ ;
            if(recProcessed < numRecords)
            {
              floatScore += 1 ;
              nullCheck32 += 1 ;
            }
          }
          break ;
        case 8 : //doubleScore
          while(recProcessed < numRecords)
          {
            if(*nullCheck64 != nullForDoubleScore)
            {
              switch(spanAggFunction)
              {
                case 2 :  // mean
                  spanSum += *doubleScore ;
                  spanCount ++ ;
                  break ;
                case 3 :  // max
                  spanMax = *doubleScore > spanMax ? *doubleScore : spanMax ;
                  break ;
                case 4 :  // min
                  spanMin = *doubleScore < spanMin ? *doubleScore : spanMin ;
                  break ;
                case 5 :  // sum
                  spanSum += *doubleScore ;
                  break ;
                case 6 :  // stdev
                  spanSoq += *doubleScore * *doubleScore ;
                  spanSum += *doubleScore ;
                  spanCount ++ ;
                  break ;
                case 7 :  // count
                  spanCount ++ ;
                  break ;
                case  8: // avgByLength
                  spanSum += *doubleScore ;
                  break ;
                default : // median (spanAggFunction should be 1)
                  if(numberOfRealScores < medianLimit)
                    arrayToSortDouble[numberOfRealScores] = *doubleScore ;
                  break ;
              }
              numberOfRealScores ++ ;
            }
            recProcessed ++ ;
            if(recProcessed < numRecords)
            {
              doubleScore += 1 ;
              nullCheck64 += 1 ;
            }
          }
          break ;
        case 1 : //int8Score
          while(recProcessed < numRecords)
          {
            if(*int8Score != nullForInt8Score)
            {
              switch(spanAggFunction)
              {
                case 2 :  // mean
                  spanSum += (double)(lowLimit + (scale * (*int8Score / denom))) ;
                  spanCount ++ ;
                  break ;
                case 3 :  // max
                  spanMax = (double)(lowLimit + (scale * (*int8Score / denom))) > spanMax ? (double)(lowLimit + (scale * (*int8Score / denom))) : spanMax ;
                  break ;
                case 4 :  // min
                  spanMin = (double)(lowLimit + (scale * (*int8Score / denom))) < spanMin ? (double)(lowLimit + (scale * (*int8Score / denom))) : spanMin ;
                  break ;
                case 5 :  // sum
                  spanSum += (double)(lowLimit + (scale * (*int8Score / denom))) ;
                  break ;
                case 6 :  // stdev
                  spanSoq += (double)(lowLimit + (scale * (*int8Score / denom))) * (double)(lowLimit + (scale * (*int8Score / denom))) ;
                  spanSum += (double)(lowLimit + (scale * (*int8Score / denom))) ;
                  spanCount ++ ;
                  break ;
                case 7 :  // count
                  spanCount ++ ;
                  break ;
                case 8 : // avgByLength
                  spanSum += (double)(lowLimit + (scale * (*int8Score / denom))) ;
                  break ;
                default : // median (spanAggFunction should be 1)
                  if(numberOfRealScores < medianLimit)
                    arrayToSortInt8[numberOfRealScores] = (guint8)(lowLimit + (scale * (*int8Score / denom))) ;
                  break ;
              }
              numberOfRealScores ++ ;
            }
            recProcessed ++ ;
            if(recProcessed < numRecords)
            {
              int8Score += 1 ;
            }
          }
          break ;
      }
      // save global ruby stuff
      rb_ary_store(globalArray, 2, LONG2FIX(numberOfRealScores)) ;
      rb_ary_store(globalArray, 4, rb_float_new(spanSum)) ;
      rb_ary_store(globalArray, 5, LONG2FIX(spanCount)) ;
      rb_ary_store(globalArray, 6, rb_float_new(spanMax)) ;
      rb_ary_store(globalArray, 7, rb_float_new(spanMin)) ;
      rb_ary_store(globalArray, 8, rb_float_new(spanSoq)) ;
    }
    EOC
  }
end
end; end; end; end
