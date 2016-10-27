#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
#  A c class for formatting the scores into different formats
# This class is used with the 'IntersectHdhv' class
class YieldIntersectHdhv
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
    /* Allocate memory for storing wiggle records. This buffer will be reused every time the C classes for the wiggle formula are called */
    void yieldIntersectTracks(VALUE globalArray, VALUE medianArray, VALUE rubyString, int fstart, int fstop, int dataSpan, int spanAggFunction, int scaleScores,
                        VALUE chrom, double scaleFactor, int retType, VALUE type, VALUE subtype)
    {
      int length = 0 ;
      int ret  = 0 ;

      /* get pointers for ruby stuff */
      char *ctype = STR2CSTR(type) ;
      char *csubtype = STR2CSTR(subtype) ;
      void *rubySt = RSTRING_PTR(rubyString) ;
      guchar *rubyStr = (guchar *)rubySt ;
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
      char *chr = STR2CSTR(chrom) ;
      VALUE trackWideMin = rb_ary_entry(globalArray, 9) ;
      double trackMin = RFLOAT(trackWideMin)->value ;
      VALUE trackWideMax = rb_ary_entry(globalArray, 10) ;
      double trackMax = RFLOAT(trackWideMax)->value ;
      void *medArray = RSTRING_PTR(medianArray) ;
      gfloat *arrayToSort = (gfloat *)medArray ;
      gdouble *arrayToSortDouble = (gdouble *)medArray ;
      guint8 *arrayToSortInt8 = (guint8 *)medArray ;
      int annoLength = (fstop - fstart) + 1 ;

      switch(dataSpan)
      {
        case 4 : ;
          gfloat spanAggValue ;
          switch(spanAggFunction)
          {
            case 2 :
              spanAggValue = (gfloat)(spanSum / spanCount) ;
              break ;
            case 3 :
              spanAggValue = (gfloat)spanMax ;
              break ;
            case 4 :
              spanAggValue = (gfloat)spanMin ;
              break ;
            case 5 :
              spanAggValue = (gfloat)spanSum ;
              break ;
            case 6 :
              spanAggValue = (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
              break ;
            case 7 :
              spanAggValue = (gfloat)spanCount ;
              break ;
            case 8 :
              spanAggValue = (gfloat)(spanSum / annoLength) ;
              break ;
            default :
              if(numberOfRealScores == 1)
                spanAggValue = arrayToSort[0] ;
              else
                spanAggValue = calcMedianForGfloat(arrayToSort, numberOfRealScores) ;
              break ;
          }
          switch(retType)
          {
            case 1 : //fixedStep
              ret = sprintf(rubyStr, "%.6g\\n", spanAggValue) ;
              break ;
            case 2 : //variableStep
              ret = sprintf(rubyStr, "%d %.6g\\n", fstart, spanAggValue) ;
              break ;
            case 3 :
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n", chr, fstart - 1, fstop, spanAggValue);
              else
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n", chr, fstart - 1, fstop, round((spanAggValue - trackMin) / scaleFactor));
              break ;
            case 4 :
              ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%.6g\\n", chr, fstart - 1, fstop, spanAggValue);
              break ;
            case 5 :
              ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.6g\\n", chr,
                      fstart , fstop, ctype, csubtype, chr, fstart, fstop, spanAggValue);
              break ;
            case 6 :
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, spanAggValue, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 7 :
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, spanAggValue, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 8 :
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, spanAggValue, chr, fstart, fstop, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                              chr, fstart, fstop, chr, fstart, fstop);
              break ;
          }
          break ;
        case 8 : ;
          gdouble spanAggValueDouble ;
          switch(spanAggFunction)
          {
            case 2 : // mean
              spanAggValueDouble = (gdouble)(spanSum / spanCount) ;
              break ;
            case 3 : // max
              spanAggValueDouble = (gdouble)spanMax ;
              break ;
            case 4 : // min
              spanAggValueDouble = (gdouble)spanMin ;
              break ;
            case 5 : // sum
              spanAggValueDouble = (gdouble)spanSum ;
              break ;
            case 6 : // stdev
              spanAggValueDouble = (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
              break ;
            case 7 : // count
              spanAggValueDouble = (gdouble)spanCount ;
              break ;
            case 8 : // avgByLength
              spanAggValueDouble = (gdouble)(spanSum / annoLength) ;
              break ;
            default : // median
              if(numberOfRealScores == 1)
                spanAggValueDouble = arrayToSortDouble[0] ;
              else
                spanAggValueDouble = calcMedianForGdouble(arrayToSortDouble, numberOfRealScores) ;
              break ;

          }
          switch(retType)
          {
            case 1 : //fixedStep
              ret = sprintf(rubyStr, "%.16g\\n", spanAggValueDouble) ;
              break ;
            case 2 : //variableStep
              ret = sprintf(rubyStr, "%d %.16g\\n", fstart, spanAggValueDouble) ;
              break ;
            case 3 : // bed
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n", chr, fstart - 1, fstop, spanAggValueDouble);
              else
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n", chr, fstart - 1, fstop, round((spanAggValueDouble - trackMin) / scaleFactor));
              break ;
            case 4 : // bedGraph
              ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%.16g\\n", chr, fstart - 1, fstop, spanAggValueDouble);
              break ;
            case 5 : // lff
              ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.16g\\n", chr,
                      fstart , fstop, ctype, csubtype, chr, fstart, fstop, spanAggValueDouble);
              break ;
            case 6 : // gff
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, spanAggValueDouble, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 7 : // gff3
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, spanAggValueDouble, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 8 : // gtf
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, spanAggValueDouble, chr, fstart, fstop, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                              chr, fstart, fstop, chr, fstart, fstop);
              break ;
          }
          break ;
        case 1 : ;
          guint8 spanAggValueInt8 ;
          switch(spanAggFunction)
          {
            case 2 : // mean
              spanAggValueInt8 = (guint8)(spanSum / spanCount) ;
              break ;
            case 3 : // max
              spanAggValueInt8 = (guint8)spanMax ;
              break ;
            case 4 : // min
              spanAggValueInt8 = (guint8)spanMin ;
              break ;
            case 5 : // sum
              spanAggValueInt8 = (guint8)spanSum ;
              break ;
            case 6 : // stdev
              spanAggValueInt8 = (guint8)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
              break ;
            case 7 : // count
              spanAggValueInt8 = (guint8)spanCount ;
              break ;
            case 8 : // avgBylength
              spanAggValueInt8 = (guint8)(spanSum / annoLength) ;
              break ;
            default : // median
              if(numberOfRealScores == 1)
                spanAggValueInt8 = arrayToSortInt8[0] ;
              else
                spanAggValueInt8 = calcMedianForGuint8(arrayToSortInt8, numberOfRealScores) ;
              break ;
          }
          switch(retType)
          {
            case 1 : //fixedStep
              ret = sprintf(rubyStr, "%d\\n", spanAggValueInt8) ;
              break ;
            case 2 : //variableStep
              ret = sprintf(rubyStr, "%d %d\\n", fstart, spanAggValueInt8) ;
              break ;
            case 3 : // bed
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%d\\t+\\n", chr, fstart - 1, fstop, spanAggValueInt8);
              else
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%d\\t+\\n", chr, fstart - 1, fstop, round((spanAggValueInt8 - trackMin) / scaleFactor));
              break ;
            case 4 : // bedGraph
              ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%d\\n", chr, fstart - 1, fstop, spanAggValueInt8);
              break ;
            case 5 : // lff
              ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%d\\n", chr,
                      fstart , fstop, ctype, csubtype, chr, fstart, fstop, spanAggValueInt8);
              break ;
            case 6 : // gff
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (double)spanAggValueInt8, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 7 : // gff3
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (double)spanAggValueInt8, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, fstart, fstop, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                              chr, fstart, fstop);
              break ;
            case 8 : // gtf
              if(scaleScores == 0)
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, (double)spanAggValueInt8, chr, fstart, fstop, chr, fstart, fstop);
              else
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%f\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                              chr, ctype, csubtype, fstart, fstop, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                              chr, fstart, fstop, chr, fstart, fstop);
              break ;
          }
        }
        length += ret ;
        RSTRING_LEN(rubyString) = length ;
        numberOfRealScores = 0 ;
        spanSum = 0.0 ;
        spanCount = 0 ;
        spanSoq = 0.0 ;
        rb_ary_store(globalArray, 2, LONG2FIX(numberOfRealScores)) ;
        rb_ary_store(globalArray, 4, rb_float_new(spanSum)) ;
        rb_ary_store(globalArray, 5, LONG2FIX(spanCount)) ;
        rb_ary_store(globalArray, 6, rb_float_new(trackMin)) ;
        rb_ary_store(globalArray, 7, rb_float_new(trackMax)) ;
        rb_ary_store(globalArray, 8, rb_float_new(spanSoq)) ;
    }
    EOC
  }
end
end; end; end; end
