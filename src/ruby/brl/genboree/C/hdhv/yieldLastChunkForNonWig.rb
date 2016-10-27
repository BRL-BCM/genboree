#!/usr/bin/env ruby
require 'brl/C/CFunctionWrapper'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# A c class for yielding last chunk for non wiggle formats
class YieldLastChunkForNonWig
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
      CFunctionWrapper.stdevFunctions('gfloat', 'gdouble', 'guint8')
    )
    builder.c <<-EOC
      /* function for yielding last chunk of the string */
      void returnLastChunkForNonWig(VALUE rubyString, VALUE scoreArray, int numberOfRealScores, int spanAggFunction, int dataSpan, int retType, VALUE globalArray, VALUE chromLenAndDesiredSpan, VALUE trackName,
                                    int scaleScores, VALUE chrom, double scaleFactor, VALUE emptyScoreValue)
      {
        /* Initialize variables */
        int length = 0 ;
        int ret ;
        char *track = STR2CSTR(trackName) ;
        char *ctype = strtok(track, ":") ;
        char *csubtype = strtok(NULL, ":") ;
        char *chr = STR2CSTR(chrom) ;

        /* get pointers for ruby objects */
        void *scrArray = RSTRING_PTR(scoreArray) ;
        void *rubySt = RSTRING_PTR(rubyString) ;
        guchar *rubyStr = (guchar *)rubySt ;
        long spanStart = FIX2LONG(rb_ary_entry(globalArray, 1)) ;
        long trackWindowSize = FIX2LONG(rb_ary_entry(globalArray, 3)) ;
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
        long chromLen = FIX2LONG(rb_ary_entry(chromLenAndDesiredSpan, 0)) ;
        long desiredSpan = FIX2LONG(rb_ary_entry(chromLenAndDesiredSpan, 1)) ;
        int modLastSpan = FIX2LONG(rb_ary_entry(chromLenAndDesiredSpan, 2)) ;
        int start ;
        if(modLastSpan == 1)
          start = spanStart + (desiredSpan - 1) <= chromLen ? spanStart + (desiredSpan - 1) : chromLen ;
        else
          start = spanStart + (desiredSpan - 1) ;
        char *emptyValue = STR2CSTR(emptyScoreValue) ;
        char * emptyVal = NULL ;
        if(strlen(emptyValue) > 0)
          emptyVal = emptyValue ;
        if(numberOfRealScores > 0)
        {
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
                case 8 : // avgbylength
                 spanAggValue = (gfloat)(spanSum / desiredSpan) ;
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
                case 3 :
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n", chr, spanStart - 1, start, spanAggValue);
                  else
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n", chr, spanStart - 1, start, round((spanAggValue - trackMin) / scaleFactor));
                  break ;
                case 4 :
                  ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%.6g\\n", chr, spanStart - 1, start, spanAggValue);
                  break ;
                case 5 :
                  ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.6g\\n", chr,
                          spanStart , start, ctype, csubtype, chr, spanStart, start, spanAggValue);
                  break ;
                case 6 :
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValue, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 7 :
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValue, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 8 :
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, spanAggValue, chr, spanStart, start, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, (gfloat)((spanAggValue - trackMin) / scaleFactor),
                                  chr, spanStart, start, chr, spanStart, start);
                  break ;
                case 9 : //psl
                  ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, start, desiredSpan,
                                          spanStart, start, chr, desiredSpan, spanStart, start,
                                          desiredSpan, spanStart, spanStart);

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
                 case 8 : // avgbylength
                  spanAggValueDouble = (gdouble)(spanSum / desiredSpan) ;
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
                case 3 : // bed
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n", chr, spanStart - 1, start, spanAggValueDouble);
                  else
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n", chr, spanStart - 1, start, round((spanAggValueDouble - trackMin) / scaleFactor));
                  break ;
                case 4 : // bedGraph
                  ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%.16g\\n", chr, spanStart - 1, start, spanAggValueDouble);
                  break ;
                case 5 : // lff
                  ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.16g\\n", chr,
                          spanStart , start, ctype, csubtype, chr, spanStart, start, spanAggValueDouble);
                  break ;
                case 6 : // gff
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValueDouble, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 7 : // gff3
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValueDouble, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 8 : // gtf
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, spanAggValueDouble, chr, spanStart, start, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, (gdouble)((spanAggValueDouble - trackMin) / scaleFactor),
                                  chr, spanStart, start, chr, spanStart, start);
                  break ;
                case 9 : //psl
                  ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, start, desiredSpan,
                                          spanStart, start, chr, desiredSpan, spanStart, start,
                                          desiredSpan, spanStart, spanStart);

                  break ;
              }
              break ;
            case 1 : ;
              gfloat spanAggValueInt8 ;
              switch(spanAggFunction)
              {
                case 2 : // mean
                  spanAggValueInt8 = (gfloat)(spanSum / spanCount) ;
                  break ;
                case 3 : // max
                  spanAggValueInt8 = (gfloat)spanMax ;
                  break ;
                case 4 : // min
                  spanAggValueInt8 = (gfloat)spanMin ;
                  break ;
                case 5 : // sum
                  spanAggValueInt8 = (gfloat)spanSum ;
                  break ;
                case 6 : // stdev
                  spanAggValueInt8 = (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
                  break ;
                case 7 : // count
                  spanAggValueInt8 = (gfloat)spanCount ;
                  break ;
                 case 8 : // avgbylength
                  spanAggValueInt8 = (gfloat)(spanSum / desiredSpan) ;
                  break ;
                default : // median
                  if(numberOfRealScores == 1)
                    spanAggValueInt8 = arrayToSort[0] ;
                  else
                    spanAggValueInt8 = calcMedianForGfloat(arrayToSort, numberOfRealScores) ;
                  break ;
              }
              switch(retType)
              {
                case 3 : // bed
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%.3g\\t+\\n", chr, spanStart - 1, start, spanAggValueInt8);
                  else
                    ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%d\\t+\\n", chr, spanStart - 1, start, round((spanAggValueInt8 - trackMin) / scaleFactor));
                  break ;
                case 4 : // bedGraph
                  ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%.3g\\n", chr, spanStart - 1, start, spanAggValueInt8);
                  break ;
                case 5 : // lff
                  ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.3g\\n", chr,
                          spanStart , start, ctype, csubtype, chr, spanStart, start, spanAggValueInt8);
                  break ;
                case 6 : // gff
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValueInt8, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 7 : // gff3
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, spanAggValueInt8, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                                  chr, spanStart, start);
                  break ;
                case 8 : // gtf
                  if(scaleScores == 0)
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, spanAggValueInt8, chr, spanStart, start, chr, spanStart, start);
                  else
                    ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                  chr, ctype, csubtype, spanStart, start, (double)((spanAggValueInt8 - trackMin) / scaleFactor),
                                  chr, spanStart, start, chr, spanStart, start);
                  break ;
                case 9 : //psl
                  ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, start, desiredSpan,
                                          spanStart, start, chr, desiredSpan, spanStart, start,
                                          desiredSpan, spanStart, spanStart);

                  break ;
              }
          }
          length += ret ;
        }
        else
        {
          if(emptyVal != NULL && trackWindowSize != 0)
          {
            switch(retType)
            {
              case 3 : // bed
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t.\\t%s\\t+\\n", chr, spanStart - 1, start, emptyVal);
                break ;
              case 4 : // bedGraph
                ret = sprintf(rubyStr, "%s\\t%d\\t%d\\t%s\\n", chr, spanStart - 1, start, emptyVal);
                break ;
              case 5 : // lff
                ret = sprintf(rubyStr, "High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%s\\n", chr,
                        spanStart , start, ctype, csubtype, chr, spanStart, start, emptyVal);
                break ;
              case 6 : // gff
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\t%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, emptyVal, chr, spanStart, start);
                break ;
              case 7 : // gff3
                ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\tName=%s:%d-%d\\n", chr, ctype, csubtype, spanStart, start, emptyVal, chr, spanStart, start);
                break ;
              case 8 : // gtf
                  ret = sprintf(rubyStr, "%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\tgene_id \\"%s:%d-%d\\"; transcript_id \\"%s:%d-%d\\"\\n",
                                chr, ctype, csubtype, spanStart, start, emptyVal, chr, spanStart, start, chr, spanStart, start);
                break ;
              case 9 : //psl
                ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                        numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, start, desiredSpan,
                                        spanStart, start, chr, desiredSpan, spanStart, start,
                                        desiredSpan, spanStart, spanStart);

                break ;
            }
            length += ret ;
          }
        }
        RSTRING_LEN(rubyString) = length ;
      }
    EOC
  }

end
end ; end; end; end
