#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/C/hdhv/makeWigLine'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# An inline C class for returning the last record (for wig formats)
class YieldLastChunkForWig
  Config::CONFIG['CFLAGS'] = ' -fPIC -g '
  Config::CONFIG['CCDLFLAGS'] = ' -fPIC -g '
  Config::CONFIG['DLDFLAGS'] = ' -g '
  Config::CONFIG['LDSHARED'] = 'gcc -g -shared '
  Config::CONFIG['STRIP'] = ''
  Config::CONFIG['LDFLAGS'] = " -g #{Config::CONFIG['LDFLAGS']} "
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
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
      MakeWigLine.makeWigLineWithEmptyScoreValue()
    )
    builder.c <<-EOC
      /* function for yielding the last record for wig format */
      void returnLastChunk(VALUE rubyString, VALUE scoreArray, int numberOfRealScores, int spanAggFunction, int dataSpan, int retType, VALUE globalArray
                          , VALUE emptyScoreValue, int stopLandmark, int desiredSpan, int modLastSpan, VALUE chrom)
      {
        /* Initialize variables */
        int length = 0 ;
        int ret = 0 ;

        /* get pointers for ruby objects */
        void *scrArray = RSTRING_PTR(scoreArray) ;
        void *rubyStr = RSTRING_PTR(rubyString) ;
        guchar *temp = (guchar *)rubyStr ;
        long spanStart = FIX2LONG(rb_ary_entry(globalArray, 1)) ;
        int trackWindowSize = FIX2LONG(rb_ary_entry(globalArray, 3)) ;
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
        guint8 *arrayToSortInt8 = (guint8 *)scrArray ;
        gdouble *arrayToSortDouble = (gdouble *)scrArray ;
        gfloat *arrayToSort = (gfloat *)scrArray ;
        char *emptyValue = STR2CSTR(emptyScoreValue) ;
        char * emptyVal = NULL ;
        char *chr = STR2CSTR(chrom) ;
        int endCoord = spanStart + (desiredSpan - 1) ;
        if(strlen(emptyValue) > 0)
          emptyVal = emptyValue ;
        if(numberOfRealScores > 0)
        {
          switch(spanAggFunction)
          {
            case 2 : // mean
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum / spanCount), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum / spanCount), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanSum / spanCount), retType, spanStart) ;
                  break ;
              }
              break ;
            case 3 : // max
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanMax), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanMax), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanMax), retType, spanStart) ;
                  break ;
              }
              break ;
            case 4 : // min
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanMin), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanMin), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanMin), retType, spanStart) ;
                  break ;
              }
              break ;
            case 5 : // sum
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanSum), retType, spanStart) ;
                  break ;
              }
              break ;
            case 6 : // stdev
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                  break ;
              }
              break ;
            case 7 : // count
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanCount), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanCount), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanCount), retType, spanStart) ;
                  break ;
              }
              break ;
            case 8 : // avgBylength
              switch(dataSpan)
              {
                case 4 : //floatScore
                  ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum / desiredSpan), retType, spanStart) ;
                  break ;
                case 8 : //doubleScore
                  ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum / desiredSpan), retType, spanStart) ;
                  break ;
                case 1 : //int8Score
                  ret = makeWigLineWithGuInt8(temp, (gfloat)(spanSum / desiredSpan), retType, spanStart) ;
                  break ;
              }
              break ;
            default : // median
              if(numberOfRealScores == 1)
              {
                switch(dataSpan)
                {
                  case 4 : //floatScore
                    ret = makeWigLineWithGFloat(temp, arrayToSort[0], retType, spanStart) ;
                    break ;
                  case 8 : //doubleScore
                    ret = makeWigLineWithGDouble(temp, arrayToSortDouble[0], retType, spanStart) ;
                    break ;
                  case 1 : //int8Score
                    ret = makeWigLineWithGuInt8(temp, arrayToSort[0], retType, spanStart) ;
                    break ;
                }
              }
              else if(numberOfRealScores > 1)
              {
                switch(dataSpan)
                {
                  case 4 :
                    ret = makeWigLineWithGFloat(temp, calcMedianForGfloat(arrayToSort, numberOfRealScores), retType, spanStart) ;
                    break ;
                  case 8 :
                    ret = makeWigLineWithGDouble(temp, calcMedianForGdouble(arrayToSortDouble, numberOfRealScores), retType, spanStart) ;
                    break ;
                  case 1 :
                    ret = makeWigLineWithGuInt8(temp, calcMedianForGfloat(arrayToSort, numberOfRealScores), retType, spanStart) ;
                    break ;
                }
              }
              break ;
          }
        }
        else
        {
          if(emptyVal != NULL && trackWindowSize != 0)
          {
            ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
          }
        }
        temp += ret ;
        length += ret ;
        RSTRING_LEN(rubyString) = length ;
      }
    EOC
  }

end
end; end; end; end
