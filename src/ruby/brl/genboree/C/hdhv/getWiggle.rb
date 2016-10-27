#!/usr/bin/env ruby

# Load libraries and env
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/C/hdhv/makeWigLine'
require 'brl/genboree/C/hdhv/updateAggregates'
require 'brl/genboree/C/hdhv/miscFunctions'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# An inline C class for getting back High Density High Volume (HDHV) data stored in Genboree as 'wiggle' (fixedStep/variableStep) format
# returns 'variableStep' or 'fixedStep'
# [+scores+] A ruby string with binary content (scores)
# [+dataSpan+] No of bytes used to store one record (1, 2, 4, 8)
# [+numRecords+] No of records in the block to be processed
# [+denom+] Denominator to be used for wiggle formula
# [+scale+] Scale to be used for wiggle formula
# [+lowLimit+] Lower limit of the block to be processed (used only with wiggle formula)
# [+cBuffer+] An empty ruby string to save the output string
# [+chrom+] chromsome
# [+startAndStop+] start and end coordinates of the block
# [+retType+] 1 (fixedStep) or 2 (variableStep)
# [+bpSpan+] bpSpan of the block (not used anymore: always going to be 1)
# [+optsArray+] ruby options array
# [+medArray+] buffer allocated for median calculation
# [+globalArray+] ruby array for tracking certain global variables
# [+emptyScoreValue+] value to be used in case of NaN scores (will be empty if not to be used)
# [+returns+] 1 or 0 : indicating if the C function had to return control to the ruby side because the buffer was full; 1 indicates partial processing of block, 0 indicates complete processing
class GetWiggle
  ############### The following flags are required for debugging:################
  #Config::CONFIG['CFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['CCDLFLAGS'] = ' -fPIC -g '
  #Config::CONFIG['DLDFLAGS'] = ' -g '
  #Config::CONFIG['LDSHARED'] = 'gcc -g -shared '
  #Config::CONFIG['STRIP'] = ''
  #Config::CONFIG['LDFLAGS'] = " -g #{Config::CONFIG['LDFLAGS']} "
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
      MakeWigLine.makeWigLineWithEmptyScoreValue() +
      UpdateAggregates.updateAggForGFloat() +
      UpdateAggregates.updateAggForGDouble() +
      UpdateAggregates.updateAggForGuInt8() +
      MiscFunctions.updateGlobalArray() +
      MiscFunctions.writeWigLineForAggFunction() +
      MiscFunctions.makeWigLineForWindowForGfloat() +
      MiscFunctions.makeWigLineForWindowForGdouble() +
      MiscFunctions.makeWigLineForWindowForGuint8
    )
    builder.c <<-EOC
      int getRawScoresAsString(VALUE scores, int dataSpan, int numRecords, double denom, double scale, double lowLimit, VALUE cBuffer, VALUE chrom, VALUE startAndStop,
                                int retType, int bpSpan, VALUE optsArray, VALUE medArray, VALUE globalArray, VALUE emptyScoreValue)
      {
         /* Get pointers for ruby objects */
        void *scr = RSTRING_PTR(scores) ;
        void *tempBuff = RSTRING_PTR(cBuffer) ;
        guchar *temp = (guchar *)tempBuff ;
        void *medianArray = RSTRING_PTR(medArray) ;
        char *chr = STR2CSTR(chrom) ;
        int recordsProcessed = (int)FIX2LONG(rb_ary_entry(globalArray, 0)) ;
        long windowStartFromPreviousBlock =  FIX2LONG(rb_ary_entry(globalArray, 1)) ;
        long numberOfRealScoresFromPreviousBlock = FIX2LONG(rb_ary_entry(globalArray, 2)) ;
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
        long desiredSpan = FIX2LONG(rb_ary_entry(optsArray, 0)) ;
        long spanAggFunction = FIX2LONG(rb_ary_entry(optsArray, 1)) ;
        long posScoresOnly = FIX2LONG(rb_ary_entry(optsArray, 2)) ;
        long negScoresOnly = FIX2LONG(rb_ary_entry(optsArray, 3)) ;
        long endSpan = FIX2LONG(rb_ary_entry(optsArray, 4)) ;
        long chromLength = FIX2LONG(rb_ary_entry(optsArray, 5)) ; // May or may not actually be chromLength (can also refer to landmark end coordinate)
        long modLastSpan = FIX2LONG(rb_ary_entry(optsArray, 6)) ;
        long startLandmark = FIX2LONG(rb_ary_entry(optsArray, 7)) ;
        int colCoverage = FIX2LONG(rb_ary_entry(optsArray, 8)) ;
        char *emptyScoreVal = STR2CSTR(emptyScoreValue) ;
        char *emptyVal = NULL ;
        if(strlen(emptyScoreVal) > 0)
          emptyVal = emptyScoreVal ;
        int start = FIX2LONG(rb_ary_entry(startAndStop, 0)) ;
        int stop = FIX2LONG(rb_ary_entry(startAndStop, 1)) ;
        int previousStop = FIX2LONG(rb_ary_entry(globalArray, 11)) ;
        int addLeadingEmptyScores = FIX2LONG(rb_ary_entry(globalArray, 12)) ; // Variable to track if the leading empty score values have been added
        long coordTracker = FIX2LONG(rb_ary_entry(globalArray, 13)) ;
        long spanTracker = FIX2LONG(rb_ary_entry(globalArray, 14)) ;
        long windowStartTracker = FIX2LONG(rb_ary_entry(globalArray, 15)) ;

        /* Initialize variables */
        int ii = 0 ;
        int ret ;
        int addBlock = 0 ;
        int length = 0 ;
        int limit = 1000000 ;
        int newStart = start;
        int numberOfRealScores = 0 ;
        int spanStart = start ;
        int annosStart = start ;
        int addBlockHeader = 0 ; /* changes to 1 if the previous window had no 'real' scores (all NaN) or starts with a NaN */

        /* set up pointers and other constants */
        gfloat* floatVal = (gfloat *)scr ;
        gdouble* doubleVal = (gdouble *)scr ;
        guint8* int8Val = (guint8 *)scr ;
        guint32 nullForFloatScore = (guint32)4290772992 ;
        guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
        guint8 nullForInt8Score = (guint8)(denom + 1) ;
        gfloat tempValue ;
        guint32* nullChecker = (guint32 *)scr ;
        guint64* nullChecker64 = (guint64 *)scr ;
        
        /*
            Check if we need to add empty score values. This is possible if the start coord of the 'first' sorted block is
            larger than the requested start coord. Also possible if we were trying to fill up the gap between two blocks and
            ran out of buffer in the previous iteration of the function.

        */
        if(windowStartTracker < start && addLeadingEmptyScores == 1)
        {

          coordTracker = windowStartTracker + (desiredSpan - 1) ;
          while(coordTracker < start)
          {
            ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, windowStartTracker) ;
            temp += ret ;
            length += ret ;
            windowStartTracker = coordTracker + 1 ;
            coordTracker += desiredSpan ;
            if(length >= limit)
            {
              /* save global ruby stuff */
              RSTRING_LEN(cBuffer) = length ;
              updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
              return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault.
            }
            trackWindowSize = 0 ;
          }
        }

        /* For a requested span size of 1 */
        if(desiredSpan == 1)
        {
          if(retType == 1)
          {
            newStart = 0 ; // to add block headers from the ruby side
          }
          if(emptyVal != NULL && windowStartFromPreviousBlock < start && addLeadingEmptyScores == 0 && start > previousStop)
          {
            windowStartTracker = windowStartFromPreviousBlock ;
            coordTracker =  windowStartTracker + (desiredSpan - 1) ;
            addLeadingEmptyScores = 1 ;
            while(coordTracker < start)
            {

              ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, windowStartTracker) ;
              temp += ret ;
              length += ret ;
              windowStartTracker = coordTracker + 1 ;
              coordTracker += desiredSpan ;
              if(length >= limit)
              {
                RSTRING_LEN(cBuffer) = length ;
                updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault.
              }
              trackWindowSize = 0 ;
            }
          }
          if(start <= previousStop) // overlapping blocks
          {
            addBlockHeader = 1 ;
          }
          if(addLeadingEmptyScores == 1)
          {
            addLeadingEmptyScores = 0 ;
            spanStart = windowStartTracker ;
            trackWindowSize = (coordTracker - windowStartTracker) - (coordTracker - start) ;
          }
          switch(dataSpan)
          {
            case 4 : // floatScore
              while(recordsProcessed < numRecords)
              {
                /* Jump over Nan values */
                if(nullChecker[recordsProcessed] == nullForFloatScore)
                {
                  if(emptyVal == NULL)
                    addBlock = 1 ;
                  else
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, start) ;
                    temp += ret ;
                    length += ret ;
                  }
                }
                else
                {
                  /* only add block header for fixed step */
                  if(addBlock == 1 && retType == 1)
                  {
                    ret = sprintf(temp, "fixedStep chrom=%s start=%d step=1 span=1\\n", chr, start) ;
                    temp += ret ;
                    length += ret ;
                    addBlock = 0 ;
                  }
                  ret = makeWigLineWithGFloat(temp, floatVal[recordsProcessed], retType, start) ;
                  temp += ret ;
                  length += ret ;
                }
                recordsProcessed ++ ;
                start += bpSpan ;
                if(length >= limit)
                {
                  break ;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              spanStart = start ;
              break ;
            case 8 : // doubleScore
              while(recordsProcessed < numRecords)
              {
                if(nullChecker64[recordsProcessed] == nullForDoubleScore)
                {
                  if(emptyVal == NULL)
                    addBlock = 1 ;
                  else
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, start) ;
                    temp += ret ;
                    length += ret ;
                  }
                }
                else
                {
                  if(addBlock == 1 && retType == 1)
                  {
                    temp += ret  ;
                    length += ret ;
                    addBlock = 0 ;
                  }
                  ret = makeWigLineWithGDouble(temp, doubleVal[recordsProcessed], retType, start) ;
                  temp += ret ;
                  length += ret ;
                }
                recordsProcessed ++ ;
                start += bpSpan ;
                if(length >= limit)
                {
                  break ;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              spanStart = start ;
              break ;
            case 1 : // int8Score
              while(recordsProcessed < numRecords)
              {
                if(int8Val[recordsProcessed] == nullForInt8Score)
                {
                  if(emptyVal == NULL)
                    addBlock = 1 ;
                  else
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, start) ;
                    temp += ret ;
                    length += ret ;
                  }
                }
                else
                {
                  if(addBlock == 1 && retType == 1)
                  {
                    ret = sprintf(temp, "fixedStep chrom=%s start=%d step=1 span=1\\n", chr, start) ;
                    temp += ret  ;
                    length += ret ;
                    addBlock = 0 ;
                  }
                  tempValue = (gfloat)(lowLimit + (scale * (int8Val[recordsProcessed] / denom))) ;
                  ret = makeWigLineWithGuInt8(temp, tempValue, retType, start) ;
                  temp += ret ;
                  length += ret ;
                }
                recordsProcessed ++ ;
                start += bpSpan ;
                if(length >= limit)
                {
                  break ;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              spanStart = start ;
              break ;
          }
        }
        /* Use a different approach for a requested span of greater than 1 */
        /* Although this approach will also work for a requested span of 1, it is more suitable for larger spans and might be slower for a span of 1 */
        else
        {
          int startsWithNaN = 0 ; /* changes to 1 if window starts with NaN */
          gfloat *arrayToSort = (gfloat *)medianArray ;
          gdouble *arrayToSortDouble = (gdouble *)medianArray ;
          guint8 *arrayToSortInt8 = (guint8 *)medianArray ;
          /* check if window (span) was complete in previous block, if not complete it */
          /* 'trackWindowSize' will always be 0 for the first block of the requested region */
          if(trackWindowSize != 0)
          {
            spanStart = windowStartFromPreviousBlock ;
            /* if the start coord from previous window + span - 1 is greater than or equal to the start coord of the new block, we need to merge both windows */
            if(windowStartFromPreviousBlock + (desiredSpan - 1) >= start && start > previousStop)
            {
              if(emptyVal != NULL)
              {
                trackWindowSize += (start - previousStop) - 1 ;
              }
              switch(dataSpan)
              {
                case 4 : //floatScore
                  while(recordsProcessed < numRecords)
                  {
                    if(nullChecker[recordsProcessed] != nullForFloatScore)
                    {
                      switch(spanAggFunction)
                      {
                        case 2 :  // mean
                          spanSum += floatVal[recordsProcessed] ;
                          spanCount += 1 ;
                          break ;
                        case 3 :  // max
                          spanMax = floatVal[recordsProcessed] > spanMax ? floatVal[recordsProcessed] : spanMax ;
                          break ;
                        case 4 :  // min
                          spanMin = floatVal[recordsProcessed] < spanMin ? floatVal[recordsProcessed] : spanMin ;
                          break ;
                        case 5 :  // sum
                          spanSum += floatVal[recordsProcessed] ;
                          break ;
                        case 6 :  // stdev
                          spanSoq += floatVal[recordsProcessed] * floatVal[recordsProcessed] ;
                          spanSum += floatVal[recordsProcessed] ;
                          spanCount += 1 ;
                          break ;
                        case 7 :  // count
                          spanCount += 1 ;
                          break ;
                        case 8 : // avgByLength
                          spanSum += floatVal[recordsProcessed] ;
                          break ;
                        default : //median
                          arrayToSort[numberOfRealScoresFromPreviousBlock] = floatVal[recordsProcessed] ;
                          break ;
                      }
                      numberOfRealScoresFromPreviousBlock ++ ;
                    }
                    start ++ ;
                    recordsProcessed ++ ;
                    trackWindowSize ++ ;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      recordsProcessed = numRecords ; // We don't want to process any more records
                      break ;
                    }
                    if(trackWindowSize == desiredSpan)
                    {
                      break ;
                    }
                  }
                  break ;
                case 8 : //doubleScore
                  while(recordsProcessed < numRecords)
                  {
                    if(nullChecker64[recordsProcessed] != nullForDoubleScore)
                    {
                      if(spanAggFunction != 1)
                      {
                        updateAggForGDouble(spanAggFunction, doubleVal[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
                      }
                      else
                      {
                        arrayToSortDouble[numberOfRealScoresFromPreviousBlock] = doubleVal[recordsProcessed] ;
                      }
                      numberOfRealScoresFromPreviousBlock ++ ;
                    }
                    start ++ ;
                    recordsProcessed ++ ;
                    trackWindowSize ++;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      recordsProcessed = numRecords ;
                      break ;
                    }
                    if(trackWindowSize == desiredSpan)
                    {
                      break ;
                    }
                  }
                  break ;
                case 1 : //int8Score
                  while(recordsProcessed < numRecords)
                  {
                    if(int8Val[recordsProcessed] != nullForInt8Score)
                    {
                      if(spanAggFunction != 1)
                      {
                        updateAggForGuInt8(spanAggFunction, int8Val[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq, lowLimit, scale, denom) ;
                      }
                      else
                      {
                        arrayToSort[numberOfRealScoresFromPreviousBlock] = (gfloat)(lowLimit + (scale * (int8Val[recordsProcessed] / denom))) ; //Use gfloats for int8.
                      }
                      numberOfRealScoresFromPreviousBlock ++ ;
                    }
                    start ++ ;
                    recordsProcessed ++ ;
                    trackWindowSize ++;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      recordsProcessed = numRecords ;
                      break ;
                    }
                    if(trackWindowSize == desiredSpan)
                      break ;
                  }
                  break ;
              }
              /* write out record if the desired span is met */
              if(trackWindowSize == desiredSpan)
              {
                if(numberOfRealScoresFromPreviousBlock > 0)
                {
                  ret = writeWigLineForAggFunction(dataSpan, spanAggFunction, temp, spanSum, spanCount, spanMax, spanMin, spanStart, retType, spanSoq,
                                                  desiredSpan, arrayToSort, arrayToSortDouble, arrayToSortInt8, numberOfRealScoresFromPreviousBlock) ;
                  
                }
                else
                {
                  if(emptyVal != NULL)
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
                  }
                }
                temp += ret ;
                length += ret ;
                
                /* set values back */
                trackWindowSize = 0 ;
                numberOfRealScores = 0 ;
                spanSum = 0.0 ;
                spanCount = 0 ;
                spanSoq = 0.0 ;
                spanMax = trackMin ;
                spanMin = trackMax ;
                spanStart = start ;
              }
              /* save the number of 'real scores' and the 'start coordinate' for the window for next block */
              else
              {
                numberOfRealScores = numberOfRealScoresFromPreviousBlock ;
                newStart = windowStartFromPreviousBlock ;
                spanStart = newStart ;
                /* add block header for next block if, required */
                if((addBlockHeader == 1 && trackWindowSize != 0 && retType == 1) || (start > chromLength && trackWindowSize != 0 && retType == 1 && modLastSpan == 1))
                {
                  if(start <= chromLength)
                    ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, spanStart, desiredSpan, desiredSpan) ;
                  else
                    ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, spanStart, (start - spanStart), (start - spanStart)) ;
                  length += ret ;
                }
                /* add block header for variableStep for last record (so that it does not hang from the end) */
                if(start > chromLength && trackWindowSize != 0 && retType != 1 && modLastSpan == 1 )
                {
                  ret = sprintf(temp, "variableStep chrom=%s span=%d\\n", chr, (start - spanStart)) ;
                  length += ret ;
                }
                 /* save global ruby stuff */
                RSTRING_LEN(cBuffer) = length ;
                updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, spanStart) ;
                return 0 ;
              }
            }
            /* Write out the record, we cannot merge the blocks.  We will either start a new block from the current blockLevelDataInfo record
              or if 'emptyScoreValue' is present, we will fill up the gap between where we are right now and the next record with that value
            */
            else
            {
              if(numberOfRealScoresFromPreviousBlock > 0) // We have 'real' data for the current window/span
              {
                ret = writeWigLineForAggFunction(dataSpan, spanAggFunction, temp, spanSum, spanCount, spanMax, spanMin, spanStart, retType, spanSoq,
                                                  desiredSpan, arrayToSort, arrayToSortDouble, arrayToSortInt8, numberOfRealScoresFromPreviousBlock) ;
                temp += ret ;
                length += ret ;
                /* If emptyScoreValue is provided, we will need to fill in the gap between the current end coord and the next start coord */
                /* At this point, we can reuse the variables we used for filling in the leading emptyScoreValues */
                windowStartTracker = spanStart + desiredSpan ;
                coordTracker = windowStartTracker + (desiredSpan - 1) ;
                if(windowStartTracker < start && emptyVal != NULL && start > previousStop)
                {
                  addLeadingEmptyScores = 1 ;
                  while(coordTracker < start)
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, windowStartTracker) ;
                    temp += ret ;
                    length += ret ;
                    windowStartTracker = coordTracker + 1 ;
                    coordTracker += desiredSpan ;
                    if(length >= limit)
                    {
                      /* save global ruby stuff */
                      RSTRING_LEN(cBuffer) = length ;
                      updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                      return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault.
                    }
                  }
                }
                if(emptyVal == NULL)
                {
                  addBlockHeader = 1 ;
                }
              }
              else // We do not have any 'real' scores for the current window
              {
                if(emptyVal != NULL)
                {
                  ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
                  temp += ret ;
                  length += ret ;
                }
                /* If emptyScoreValue is provided, we will need to fill in the gap between the cuurent end coord and the next start coord */
                /* At this point, we can reuse the variables we used for filling in the leading emptyScoreValues */
                windowStartTracker = spanStart + desiredSpan ;
                coordTracker = windowStartTracker + (desiredSpan - 1) ;
                if(windowStartTracker < start && emptyVal != NULL && start > previousStop)
                {
                  addLeadingEmptyScores = 1 ;
                  while(coordTracker < start)
                  {
                    ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, windowStartTracker) ;
                    temp += ret ;
                    length += ret ;
                    windowStartTracker = coordTracker + 1 ;
                    coordTracker += desiredSpan ;
                    if(length >= limit)
                    {
                      /* save global ruby stuff */
                      RSTRING_LEN(cBuffer) = length ;
                      updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                      return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault.
                    }
                  }
                }
              }
              // reset global variables
              trackWindowSize = 0 ; // will be overwritten later if  addLeadingEmptyScores == 1 ;
              spanStart = start ; // will be overwritten later if  addLeadingEmptyScores == 1 ;
              spanSum = 0.0 ;
              spanCount = 0 ;
              spanSoq = 0.0 ;
              spanMax = trackMin ;
              spanMin = trackMax ;
              if(start <= previousStop)
              {
                addBlockHeader = 1 ;
              }
            }
          }
          else
          {
            if(emptyVal != NULL && windowStartFromPreviousBlock < start && addLeadingEmptyScores == 0 && start > previousStop)
            {
              windowStartTracker = windowStartFromPreviousBlock ;
              coordTracker =  windowStartTracker + (desiredSpan - 1) ;
              addLeadingEmptyScores = 1 ;
              while(coordTracker < start)
              {
                ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, windowStartTracker) ;
                temp += ret ;
                length += ret ;
                windowStartTracker = coordTracker + 1 ;
                coordTracker += desiredSpan ;
                if(length >= limit)
                {
                  RSTRING_LEN(cBuffer) = length ;
                  updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                  return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault.
                }
              }
            }
            if(start <= previousStop)
            {
              addBlockHeader = 1 ;
            }
          }
          if(addLeadingEmptyScores == 1)
          {
            addLeadingEmptyScores = 0 ;
            spanStart = windowStartTracker ;
            trackWindowSize = (coordTracker - windowStartTracker) - (coordTracker - start) ;
          }
          // Now we actually loop over the data 
          switch(dataSpan)
          {
            case 4 : //floatScore
              while(recordsProcessed < numRecords)
              {
                /* skip region if the first records for a window is a NaN until the first 'real' score is encountered */
                if(trackWindowSize == 0 && nullChecker[recordsProcessed] == nullForFloatScore)
                {
                  if(emptyVal == NULL)
                  {
                    startsWithNaN = 1 ;
                    recordsProcessed ++ ;
                    start ++ ;
                    ii ++ ;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      break ;
                    }
                    continue ;
                  }
                }
                /* save the valid score */
                if(nullChecker[recordsProcessed] != nullForFloatScore)
                {
                  /* check if the current window started with a NaN , update start for the window if it did */
                  if(startsWithNaN == 1)
                  {
                    newStart = start ;
                    addBlockHeader = 1 ;
                    spanStart = newStart ;
                    startsWithNaN = 0 ;
                  }
                  // Do not make function calls for each base. This may make things slower
                  switch(spanAggFunction)
                  {
                    case 2 :  // mean
                      spanSum += floatVal[recordsProcessed] ;
                      spanCount += 1 ;
                      break ;
                    case 3 :  // max
                      spanMax = floatVal[recordsProcessed] > spanMax ? floatVal[recordsProcessed] : spanMax ;
                      break ;
                    case 4 :  // min
                      spanMin = floatVal[recordsProcessed] < spanMin ? floatVal[recordsProcessed] : spanMin ;
                      break ;
                    case 5 :  // sum
                      spanSum += floatVal[recordsProcessed] ;
                      break ;
                    case 6 :  // stdev
                      spanSoq += floatVal[recordsProcessed] * floatVal[recordsProcessed] ;
                      spanSum += floatVal[recordsProcessed] ;
                      spanCount += 1 ;
                      break ;
                    case 7 :  // count
                      spanCount += 1 ;
                      break ;
                    case 8 : // avgByLength
                      spanSum += floatVal[recordsProcessed] ;
                      break ;
                    default : //median
                      arrayToSort[numberOfRealScores] = floatVal[recordsProcessed] ;
                      break ;
                  }
                  numberOfRealScores ++ ;
                }

                /* process the saved scores when the window is full */
                if(trackWindowSize == desiredSpan - 1)
                {
                  /* go to next window if window is only filled with NaNs */
                  if(numberOfRealScores == 0)
                  {
                    if(emptyVal == NULL)
                    {
                      newStart = start + 1 ;
                      addBlockHeader = 1 ;
                      spanStart = newStart ;
                    }
                    else
                    {
                      ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
                      temp += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                    }
                  }
                  else
                  {
                    /* add block header if required */
                    if(addBlockHeader == 1 && retType == 1)
                    {
                      ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, spanStart, desiredSpan, desiredSpan) ;
                      temp += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                    }
                    ret = makeWigLineForWindowForGfloat(spanAggFunction, temp, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, retType, spanStart, arrayToSort, numberOfRealScores) ;
                    temp += ret ;
                    length += ret ;
                    addBlockHeader = 0 ;
                  }
                  numberOfRealScores = 0 ;
                  trackWindowSize = 0 ;
                  spanSum = 0.0 ;
                  spanCount = 0 ;
                  spanSoq = 0.0 ;
                  spanMax = trackMin ;
                  spanMin = trackMax ;
                  spanStart = start + 1 ;
                }
                else
                {
                  trackWindowSize ++ ;
                }
                start ++ ;
                recordsProcessed ++ ;
                ii ++ ;
                if(length >= limit)
                {
                  break;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              break ;
            case 8 : //doubleScore
              while(recordsProcessed < numRecords)
              {
                /* skip region if the first records for a window is a NaN until the first 'real' score is encountered */
                if(trackWindowSize == 0 && nullChecker64[recordsProcessed] == nullForDoubleScore)
                {
                  if(emptyVal == NULL)
                  {
                    startsWithNaN = 1 ;
                    recordsProcessed ++ ;
                    start ++ ;
                    ii ++ ;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      break ;
                    }
                    continue ;
                  }
                }
                /* save the valid score */
                if(nullChecker64[recordsProcessed] != nullForDoubleScore)
                {
                  /* check if the current window started with a NaN , update start for the window if it did */
                  if(startsWithNaN == 1)
                  {
                    newStart = start ;
                    spanStart = newStart ;
                    addBlockHeader = 1 ;
                    startsWithNaN = 0 ;
                  }
                  if(spanAggFunction != 1)
                  {
                    updateAggForGDouble(spanAggFunction, doubleVal[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
                  }
                  else
                  {
                    arrayToSortDouble[numberOfRealScores] = doubleVal[recordsProcessed] ;
                  }
                  numberOfRealScores ++ ;
                }
                /* process the saved scores when the window is full */
                if(trackWindowSize == desiredSpan - 1)
                {
                  /* go to next window if window is only filled with NaNs */
                  if(numberOfRealScores == 0)
                  {
                    if(emptyVal == NULL)
                    {
                      newStart = start + 1 ;
                      addBlockHeader = 1 ;
                      spanStart = newStart ;
                    }
                    else
                    {
                      ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
                      temp += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                    }
                  }
                  else
                  {
                    /* add block header if required */
                    if(addBlockHeader == 1 && retType == 1)
                    {
                      ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, newStart, desiredSpan, desiredSpan) ;
                      temp += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                    }
                    ret = makeWigLineForWindowForGdouble(spanAggFunction, temp, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, retType, spanStart, arrayToSortDouble, numberOfRealScores) ;
                    temp += ret ;
                    length += ret ;
                    addBlockHeader = 0 ;
                  }
                  numberOfRealScores = 0 ;
                  trackWindowSize = 0 ;
                  spanSum = 0.0 ;
                  spanCount = 0 ;
                  spanSoq = 0.0 ;
                  spanMax = trackMin ;
                  spanMin = trackMax ;
                  spanStart = start + 1 ;
                }
                else
                {
                  trackWindowSize ++ ;
                }
                start ++ ;
                recordsProcessed ++ ;
                ii ++ ;
                if(length >= limit)
                {
                  break;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              break ;
            case 1 : //int8Score
              while(recordsProcessed < numRecords)
              {
                /* skip region if the first records for a window is a NaN until the first 'real' score is encountered */
                if(trackWindowSize == 0 && int8Val[recordsProcessed] == nullForInt8Score)
                {
                  if(emptyVal == NULL)
                  {
                    startsWithNaN = 1 ;
                    recordsProcessed ++ ;
                    start ++ ;
                    ii ++ ;
                    if(start > chromLength && modLastSpan == 1)
                    {
                      break ;
                    }
                    continue ;
                  }
                }
                /* save the valid score */
                if(int8Val[recordsProcessed] != nullForInt8Score)
                {
                  /* check if the current window started with a NaN , update start for the window if it did */
                  if(startsWithNaN == 1)
                  {
                    newStart = start ;
                    addBlockHeader = 1 ;
                    startsWithNaN = 0 ;
                    spanStart = newStart ;
                  }
                  if(spanAggFunction != 1)
                  {
                    updateAggForGuInt8(spanAggFunction, int8Val[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq, lowLimit, scale, denom) ;
                  }
                  else
                  {
                    arrayToSortInt8[numberOfRealScores] = (guint8)(lowLimit + (scale * (int8Val[recordsProcessed] / denom))) ; 
                  }
                  numberOfRealScores ++ ;
                }
                /* process the saved scores when the window is full */
                if(trackWindowSize == desiredSpan - 1)
                {
                  /* go to next window if window is only filled with NaNs */
                  if(numberOfRealScores == 0)
                  {
                    if(emptyVal == NULL)
                    {
                      newStart = start + 1 ;
                      addBlockHeader = 1 ;
                      spanStart = newStart ;
                    }
                    else
                    {
                      ret = makeWigLineWithEmptyScoreValue(temp, emptyVal, retType, spanStart) ;
                      temp += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                    }
                  }
                  else
                  {
                    /* add block header if required */
                    if(addBlockHeader == 1 && retType == 1)
                    {
                      ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, newStart, desiredSpan, desiredSpan) ;
                      temp += ret ;
                      length += ret ;
                    }
                    ret = makeWigLineForWindowForGuint8(spanAggFunction, temp, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, retType, spanStart, arrayToSortInt8, numberOfRealScores) ;
                    temp += ret ;
                    length += ret ;
                    addBlockHeader = 0 ;
                  }
                  numberOfRealScores = 0 ;
                  trackWindowSize = 0 ;
                  spanSum = 0.0 ;
                  spanCount = 0 ;
                  spanSoq = 0.0 ;
                  spanMax = trackMin ;
                  spanMin = trackMax ;
                  spanStart = start + 1 ;
                }
                else
                {
                  trackWindowSize ++ ;
                }
                start ++ ;
                recordsProcessed ++ ;
                ii ++ ;
                if(length >= limit)
                {
                  break;
                }
                if(start > chromLength && modLastSpan == 1)
                {
                  break ;
                }
              }
              break ;

          }
          /* add block header for next block if, required */
          if((addBlockHeader == 1 && trackWindowSize != 0 && retType == 1) || (start > chromLength && trackWindowSize != 0 && retType == 1 && modLastSpan == 1) )
          {
            if(start <= chromLength)
              ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, spanStart, desiredSpan, desiredSpan) ;
            else
              ret = sprintf(temp, "fixedStep chrom=%s start=%d span=%d step=%d\\n", chr, spanStart, (start - spanStart), (start - spanStart)) ;
            length += ret ;
          }
          /* add block header for variableStep for last record (so that it does not hang from the end) */
          if(start > chromLength && trackWindowSize != 0 && retType != 1 && modLastSpan == 1 )
          {
            ret = sprintf(temp, "variableStep chrom=%s span=%d\\n", chr, (start - spanStart)) ;
            length += ret ;
          }
        }

        /* save global ruby stuff */
        RSTRING_LEN(cBuffer) = length ;
        updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, spanStart) ;
        return 0 ;
      }
    EOC
  }
end
end; end; end; end
