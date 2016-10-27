#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
#  A c class for getting scores for an annotation based on the requested aggregate function
class GetScore
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib, :zlib))
    builder.include CFunctionWrapper::LIMITS_HEADER_INCLUDE
    builder.include CFunctionWrapper::GLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::MATH_HEADER_INCLUDE
    builder.include CFunctionWrapper::ZLIB_HEADER_INCLUDE
    builder.include CFunctionWrapper::ASSERT_HEADER_INCLUDE
    builder.prefix(
      CFunctionWrapper.comparisonFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.medianFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.meanFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.maxFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.minFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.sumFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.stdevFunctions('gfloat', 'gdouble', 'guint8')
    )
    builder.c <<-EOC
    void getScore(VALUE annoSum, long annoCount, VALUE medianString, VALUE annoMax, VALUE annoMin, VALUE annoSoq, VALUE valueString, int dataSpan, int spanAggFunction, int numberOfRealScores, int scaleScores, double scaleFactor, double trackMin)
    {
      int length = 0 ;
      int ret  = 0 ;
      /* get pointers for ruby stuff */
      void *valString = RSTRING_PTR(valueString) ;
      guchar *valStr = (guchar *)valString ;
      double sum = RFLOAT(annoSum)->value ;
      double max = RFLOAT(annoMax)->value ;
      double min = RFLOAT(annoMin)->value ;
      double soq = RFLOAT(annoSoq)->value ;
      void *medArray = RSTRING_PTR(medianString) ;
      gfloat *arrayToSort = (gfloat *)medArray ;
      gdouble *arrayToSortDouble = (gdouble *)medArray ;
      guint8 *arrayToSortInt8 = (guint8 *)medArray ;
      long annoLength = annoCount ;
      gfloat spanAggValue ;
      gdouble spanAggValueDouble ;
      guint8 spanAggValueInt8 ;
      switch(dataSpan)
      {
        case 4 :
          switch(spanAggFunction)
          {
            case 2 :
              spanAggValue = (gfloat)(sum / annoCount) ;
              break ;
            case 3 :
              spanAggValue = (gfloat)max ;
              break ;
            case 4 :
              spanAggValue = (gfloat)min ;
              break ;
            case 5 :
              spanAggValue = (gfloat)sum ;
              break ;
            case 6 :
              spanAggValue = (gfloat)(sqrt((soq / annoCount) - ((sum / annoCount) * (sum / annoCount)))) ;
              break ;
            case 7 :
              spanAggValue = (gfloat)annoCount ;
              break ;
            case 8 :
              spanAggValue = (gfloat)(sum / annoLength) ;
              break ;
            default :
              if(numberOfRealScores == 1)
                spanAggValue = arrayToSort[0] ;
              else
                spanAggValue = calcMedianForGfloat(arrayToSort, numberOfRealScores) ;
              break ;
          }
        case 8 :
          switch(spanAggFunction)
          {
            case 2 : // mean
              spanAggValueDouble = (gdouble)(sum / annoCount) ;
              break ;
            case 3 : // max
              spanAggValueDouble = (gdouble)max ;
              break ;
            case 4 : // min
              spanAggValueDouble = (gdouble)min ;
              break ;
            case 5 : // sum
              spanAggValueDouble = (gdouble)sum ;
              break ;
            case 6 : // stdev
              spanAggValueDouble = (gdouble)(sqrt((soq / annoCount) - ((sum / annoCount) * (sum / annoCount)))) ;
              break ;
            case 7 : // count
              spanAggValueDouble = (gdouble)annoCount ;
              break ;
            case 8 : // avgByLength
              spanAggValueDouble = (gdouble)(sum / annoLength) ;
              break ;
            default : // median
              if(numberOfRealScores == 1)
                spanAggValueDouble = arrayToSortDouble[0] ;
              else
                spanAggValueDouble = calcMedianForGdouble(arrayToSortDouble, numberOfRealScores) ;
              break ;
          }
        case 1 :
          switch(spanAggFunction)
          {
            case 2 : // mean
              spanAggValueInt8 = (guint8)(sum / annoCount) ;
              break ;
            case 3 : // max
              spanAggValueInt8 = (guint8)max ;
              break ;
            case 4 : // min
              spanAggValueInt8 = (guint8)min ;
              break ;
            case 5 : // sum
              spanAggValueInt8 = (guint8)sum ;
              break ;
            case 6 : // stdev
              spanAggValueInt8 = (guint8)(sqrt((soq / annoCount) - ((sum / annoCount) * (sum / annoCount)))) ;
              break ;
            case 7 : // count
              spanAggValueInt8 = (guint8)annoCount ;
              break ;
            case 8 : // avgBylength
              spanAggValueInt8 = (guint8)(sum / annoLength) ;
              break ;
            default : // median
              if(numberOfRealScores == 1)
                spanAggValueInt8 = arrayToSortInt8[0] ;
              else
                spanAggValueInt8 = calcMedianForGuint8(arrayToSortInt8, numberOfRealScores) ;
              break ;
          }
      }
      if(dataSpan == 4)
      {
        /* 'bed' needs to be scaled between 0 and 1000 by default. */
        if(scaleScores == 0)
        {
          ret = sprintf(valStr, "%.6g", spanAggValue) ;
        }
        else
        {
          ret = sprintf(valStr, "%.6g", round((spanAggValue - trackMin) / scaleFactor)) ;
        }
      }
      else if(dataSpan == 8)
      {
        if(scaleScores == 0)
        {
          ret = sprintf(valStr, "%.16g", spanAggValueDouble) ;
        }
        else
        {
          ret = sprintf(valStr, "%.16g", round((spanAggValueDouble - trackMin) / scaleFactor)) ;
        }
      }
      else
      {
        if(scaleScores == 0)
        {
          ret = sprintf(valStr, "%d", spanAggValueInt8) ;
        }
        else
        {
          ret = sprintf(valStr, "%d", round((spanAggValueInt8 - trackMin) / scaleFactor)) ;
        }
      }
      length += ret ;
      RSTRING_LEN(valueString) = length ;
    }
    EOC
  }
end
end; end; end; end
