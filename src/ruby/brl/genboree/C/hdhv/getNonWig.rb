# Load libraries and env
require 'brl/C/CFunctionWrapper'
require 'brl/genboree/C/hdhv/makeNonWigLine'
require 'brl/genboree/C/hdhv/updateAggregates'
require 'brl/genboree/C/hdhv/miscFunctions'
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
# A C class for getting back hdhv data in non wiggle formats:
# 1) bed
# 2) bedGraph
# 3) lff
# 4) gff
# 5) gff3
# 6) gtf
# 7) psl
# [+scores+] A ruby string with binary content (scores)
# [+dataSpan+] No of bytes used to store one record (1, 2, 4, 8)
# [+numRecords+] No of records in the block to be processed
# [+denom+] Denominator to be used for wiggle formula
# [+scale+] Scale to be used for wiggle formula
# [+lowLimit+] Lower limit of the block to be processed (used only with wiggle formula)
# [+cBuffer+] An empty ruby string to save the output string
# [+chromAndTrackName+] chromsome:type:subtype
# [+startAndStop+] start and end coordinate of the block: [start, stop]
# [+optsArray+] various parameters for calculation of scores
# [+scaleFactor+]
# [+desiredSpan+]
# [+retType+]
# [+medArray+]
# [+globalArray+]
# [+returns+] 1 or 0 : indicating if the C function had to return control to the ruby side because the buffer was full; 1 indicates partial processing of block, 0 indicates complete processing
class GetNonWig
  include BRL::C

  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
    builder.include(CFunctionWrapper::MATH_HEADER_INCLUDE)
    builder.include(CFunctionWrapper::GLIB_HEADER_INCLUDE)
    builder.prefix(
      CFunctionWrapper.comparisonFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.medianFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.meanFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.maxFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.minFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.sumFunctions('gfloat', 'gdouble', 'guint8') +
      CFunctionWrapper.stdevFunctions('gfloat', 'gdouble', 'guint8') +
      MakeNonWigLine.makeNonWigLineWithGFloat() +
      MakeNonWigLine.makeNonWigLineWithGDouble() +
      MakeNonWigLine.makeNonWigLineWithGuInt8() +
      MakeNonWigLine.makeNonWigLineWithEmptyScoreValue() +
      UpdateAggregates.updateAggForGFloat() +
      UpdateAggregates.updateAggForGDouble() +
      UpdateAggregates.updateAggForGuInt8() +
      MiscFunctions.updateGlobalArray() +
      MiscFunctions.computeAggValueForGuint8() +
      MiscFunctions.computeAggValueForGfloat() +
      MiscFunctions.computeAggValueForGdouble() 
    )
    builder.c <<-EOC

      /* Compute the binary scores using wiggle formuala from UCSC for 'variableStep' data */
      int getNonWig(VALUE scores, int dataSpan, int numRecords, double denom, double scale, double lowLimit, VALUE cBuffer, VALUE chromAndTrackName, VALUE startAndStop,
      VALUE optsArray, double scaleFactor, int desiredSpan, int retType, VALUE medArray, VALUE globalArray) {
        /* Get pointers for ruby objects*/
        void *scr = RSTRING_PTR(scores) ;
        void *tempBuff = RSTRING_PTR(cBuffer) ;
        guchar *rubyStr = (guchar *)tempBuff ;
        void *medianArray = RSTRING_PTR(medArray) ;
        char *chrAndTrackName = STR2CSTR(chromAndTrackName) ;
        char *chr = strtok(chrAndTrackName, ":") ;
        char *ctype = strtok(NULL, ":") ;
        char *csubtype = strtok(NULL, ":") ;
        char *emptyVal = NULL ;
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
        int previousStop = FIX2LONG(rb_ary_entry(globalArray, 11)) ;
        int scaleScores = FIX2LONG(rb_ary_entry(optsArray, 0)) ;
        int spanAggFunction = FIX2LONG(rb_ary_entry(optsArray, 1)) ;
        char *emptyValue = STR2CSTR(rb_ary_entry(optsArray, 4)) ;
        int modLastSpan = FIX2LONG(rb_ary_entry(optsArray, 5)) ;
        long startLandmark = FIX2LONG(rb_ary_entry(optsArray, 6)) ;
        long chromLength = FIX2LONG(rb_ary_entry(optsArray, 7)) ; // Can be chromosome length or requested stop landmark
        if(strlen(emptyValue) > 0)
          emptyVal = emptyValue ;
        int start = FIX2LONG(rb_ary_entry(startAndStop, 0)) ;
        int stop = FIX2LONG(rb_ary_entry(startAndStop, 1)) ;
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
        int startCount = 0 ;
        int annosStart  = start - 1 ;
        int annosStop = start - 1 ;
        int addBlockHeader = 0 ;
        int startsWithNaN = 0 ;

        /* set up pointers and other constants */
        gfloat* floatVal = (gfloat *)scr ;
        guint32* nullCheck32 = (guint32 *)scr ;
        guint8* int8Val = (guint8 *)scr ;
        gfloat floatScore ;
        gdouble doubleScore ;
        gdouble* doubleVal = (gdouble *)scr ;
        guint32 nullForFloatScore = (guint32)4290772992 ;
        guint32 nullScore32 ;
        guint64 nullScore64 ;
        gfloat int8Score ;
        guint64 nullForDoubleScore = G_GUINT64_CONSTANT(18410152326737166336) ;
        guint8 nullForInt8Score = (guint8)(denom + 1) ;
        guint8 tempValue ;
        guint64* nullCheck64 = (guint64 *)scr ;
        
        /* Check if we need to add leading empty score values */
        /* This is possible if the start coord of the 'first' sorted block is larger than the requested start coord */
        if(coordTracker < start && addLeadingEmptyScores == 1)
        {
          // For no span specified
          if(desiredSpan == 0)
          {
            ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, coordTracker, start - 1, chr, ctype, csubtype, emptyVal) ;
            rubyStr += ret ;
            length += ret ;
          }
          else
          {
            coordTracker = windowStartTracker + (desiredSpan - 1) ;
            while(coordTracker < start)
            {
              ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, windowStartTracker, coordTracker, chr, ctype, csubtype, emptyVal) ;
              rubyStr += ret ;
              length += ret ;
              windowStartTracker = coordTracker + 1 ;
              coordTracker += desiredSpan ;
              if(length >= limit)
              {
                /* save global ruby stuff */
                RSTRING_LEN(cBuffer) = length;
                updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault. 
              }
            }
            trackWindowSize = 0 ;
          } 
        }
        
        /* if no span is specified */
        if(desiredSpan == 0)
        {
          if(emptyVal != NULL && windowStartFromPreviousBlock < start && addLeadingEmptyScores == 0 && start > previousStop)
          {
            windowStartTracker = windowStartFromPreviousBlock ;
            coordTracker =  start - 1 ;
            addLeadingEmptyScores = 1 ;
            ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, windowStartTracker, coordTracker, chr, ctype, csubtype, emptyVal) ;
            rubyStr += ret ;
            length += ret ;
          }
          if(addLeadingEmptyScores == 1)
          {
            addLeadingEmptyScores = 0 ;
            spanStart = windowStartTracker ;
            trackWindowSize = (coordTracker - windowStartTracker) - (coordTracker - start) ;
          }
          switch(dataSpan)
          {
            case 4 : //floatScore
              /* Iterate over all records */
              while(recordsProcessed < numRecords)
              {
                
                /* For the first record of the block */
                if(startCount == 0)
                {
                  startCount ++ ;
                }
                /* For the rest of the records */
                else
                {
                  /* start new record if previous score does not match current score */
                  if(floatScore != floatVal[recordsProcessed])
                  {
                    /* Jump over null scores */
                    if(nullScore32 != nullForFloatScore)
                    {
                      ret = makeNonWigLineWithGFloat(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, floatScore, trackMin, scaleFactor) ;
                      rubyStr += ret;
                      length += ret;
                      // check if nulls have to be replaced with emptyScoreValue
                      if(emptyVal == NULL)
                      {
                        if(nullCheck32[recordsProcessed] != nullForFloatScore)
                        {
                          annosStart = annosStop ;
                        }
                      }
                      else
                      {
                        annosStart = annosStop ;
                      }
                    }
                    else
                    {
                      if(emptyVal != NULL)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                        rubyStr += ret;
                        length += ret;
                      }
                      annosStart = annosStop;
                    }
                  }
                }
                floatScore = floatVal[recordsProcessed] ;
                nullScore32 = nullCheck32[recordsProcessed] ;
                annosStop ++ ;
                recordsProcessed ++ ;
                if(length > limit)
                {
                  break;
                }
              }
              if(nullScore32 != nullForFloatScore)
              {
                ret = makeNonWigLineWithGFloat(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, floatScore, trackMin, scaleFactor) ;
                length += ret;
              }
              else
              {
                if(emptyVal != NULL)
                {
                  ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                  length += ret ;
                }
              }
              spanStart = annosStop + 1 ;
              break ;
            case 8 : //doubleScore
              /* Iterate over all records */
              while(recordsProcessed < numRecords)
              {
                /* For the first record of the block */
                if(startCount == 0)
                {
                  startCount ++;
                }
                /* For the rest of the records */
                else
                {
                  /* start new record if previous score does not match current score */
                  if(doubleScore != doubleVal[recordsProcessed])
                  {
                    /* Jump over null scores */
                    if(nullScore64 != nullForDoubleScore)
                    {
                      ret = makeNonWigLineWithGDouble(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, doubleScore, trackMin, scaleFactor) ;
                      rubyStr += ret ;
                      length += ret ;
                      if(emptyVal == NULL)
                      {
                        if(nullCheck64[recordsProcessed] != nullForDoubleScore)
                        {
                          annosStart = annosStop;
                        }
                      }
                      else
                      {
                        annosStart = annosStop ;
                      }
                    }
                    else
                    {
                      if(emptyVal != NULL)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                        rubyStr += ret;
                        length += ret;
                      }
                      annosStart = annosStop;
                    }
                  }
                }
                doubleScore = doubleVal[recordsProcessed] ;
                nullScore64 = nullCheck64[recordsProcessed] ;
                annosStop ++ ;
                recordsProcessed ++;
                if(length > limit)
                {
                  break;
                }
              }
              if(nullScore64 != nullForDoubleScore)
              {
                ret = makeNonWigLineWithGDouble(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, doubleScore, trackMin, scaleFactor) ;
                length += ret;
              }
              else
              {
                if(emptyVal != NULL)
                {
                  ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                  length += ret ;
                }
              }
              spanStart = annosStop + 1 ;
              break ;
            case 1 : //int8Score
              /* Iterate over all records */
              while(recordsProcessed < numRecords)
              {
                /* For the first record of the block */
                if(startCount == 0)
                {
                  startCount ++;
                }
                /* For the rest of the records */
                else
                {
                  /* start new record if previous score does not match current score */
                  if((guint8)int8Score != int8Val[recordsProcessed])
                  {
                    /* Jump over null scores */
                    if((guint8)int8Score != nullForInt8Score)
                    {
                      ret = makeNonWigLineWithGuInt8(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, int8Score, trackMin, scaleFactor) ;
                      rubyStr += ret ;
                      length += ret ;
                      if(emptyVal == NULL)
                      {
                        if(int8Val[recordsProcessed] != nullForInt8Score)
                        {
                          annosStart = annosStop ;
                        }
                      }
                      else
                      {
                        annosStart = annosStop ;
                      }
                    }
                    else
                    {
                      if(emptyVal != NULL)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                      }
                      annosStart = annosStop;
                    }
                  }
                }
                int8Score = (gfloat)(lowLimit + (scale * (int8Val[recordsProcessed] / denom))) ;
                annosStop ++ ;
                recordsProcessed ++;
                if(length > limit)
                {
                  break;
                }
              }
              if((guint8)int8Score != nullForInt8Score)
              {
                ret = makeNonWigLineWithGuInt8(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, scaleScores, int8Score, trackMin, scaleFactor) ;
                length += ret ;
              }
              else
              {
                if(emptyVal != NULL)
                {
                  ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, annosStart + 1, annosStop, chr, ctype, csubtype, emptyVal) ;
                  length += ret ;
                }
              }
              spanStart = annosStop + 1 ;
              break ;
          }
        }
        else // For a specified span 
        {
          gfloat *arrayToSort = (gfloat *)medianArray ;
          gdouble *arrayToSortDouble = (gdouble *)medianArray ;
          guint8 *arrayToSortInt8 = (guint8 *)medianArray ;
          /* check to see if the window was complete in the previous block */
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
                    /* save the valid score */
                    if(nullCheck32[recordsProcessed] != nullForFloatScore)
                    {
                      if(spanAggFunction != 1)
                      {
                        updateAggForGFloat(spanAggFunction, floatVal[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
                      }
                      else
                      {
                        arrayToSort[numberOfRealScoresFromPreviousBlock] = floatVal[recordsProcessed] ;
                      }
                      numberOfRealScoresFromPreviousBlock ++ ;
                    }
                    start ++ ;
                    recordsProcessed ++ ;
                    trackWindowSize ++ ;
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
                case 8 : //doubleScore
                  while(recordsProcessed < numRecords)
                  {
                    /* save the valid score */
                    if(nullCheck64[recordsProcessed] != nullForDoubleScore)
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
                    trackWindowSize ++ ;
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
                case 1 : // int8Score
                  while(recordsProcessed < numRecords)
                  {
                    /* save the valid score */
                    if(int8Val[recordsProcessed] != nullForInt8Score)
                    {
                      if(spanAggFunction != 1)
                      {
                        updateAggForGuInt8(spanAggFunction, int8Val[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq, lowLimit, scale, denom) ;
                      }
                      else
                      {
                        arrayToSortInt8[numberOfRealScoresFromPreviousBlock] = (guint8)(lowLimit + (scale * (int8Val[recordsProcessed] / denom))) ;
                      }
                      numberOfRealScoresFromPreviousBlock ++ ;
                    }
                    start ++ ;
                    recordsProcessed ++ ;
                    trackWindowSize ++ ;
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
              }
              /* write out the record if the window/span is complete */
              if(trackWindowSize == desiredSpan)
              {
                if(numberOfRealScoresFromPreviousBlock > 0)
                {
                  
                  switch(dataSpan)
                  {
                    case 4 : ;
                      gfloat spanAggValue = computeAggValueForGfloat(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSort) ;
                      ret = makeNonWigLineWithGFloat(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValue, trackMin, scaleFactor) ;
                      break ;
                    case 8 : ;
                      gdouble spanAggValueDouble = computeAggValueForGdouble(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSortDouble) ;
                      ret = makeNonWigLineWithGDouble(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValueDouble, trackMin, scaleFactor) ;
                      break ;
                    case 1 : ;
                      guint8 spanAggValueInt8 = computeAggValueForGuint8(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSortInt8) ;
                      ret = makeNonWigLineWithGuInt8(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValueInt8, trackMin, scaleFactor) ;
                      break ;
                  }
                }
                else
                {
                  if(emptyVal != NULL)
                  {
                    ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, spanStart, start, chr, ctype, csubtype, emptyVal) ;
                    
                  }
                }
                rubyStr += ret ;
                length += ret ;
                addBlockHeader = 0 ;
                numberOfRealScores = 0 ;
                trackWindowSize = 0 ;
                spanSum = 0.0 ;
                spanCount = 0 ;
                spanSoq = 0.0 ;
                spanMax = trackMin ;
                spanMin = trackMax ;
                spanStart = start ;
              }
              else
              {
                numberOfRealScores = numberOfRealScoresFromPreviousBlock ;
                newStart = windowStartFromPreviousBlock ;
                spanStart = newStart ;
                 /* save global ruby stuff */
                RSTRING_LEN(cBuffer) = length;
                updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                return 0 ;
              }
            }
            /* write out the record */
            else
            {
              if(numberOfRealScoresFromPreviousBlock > 0)
              {
                switch(dataSpan)
                {
                  case 4 : ;
                    gfloat spanAggValue = computeAggValueForGfloat(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSort) ;
                    ret = makeNonWigLineWithGFloat(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValue, trackMin, scaleFactor) ;
                    break ;
                  case 8 : ;
                    gdouble spanAggValueDouble = computeAggValueForGdouble(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSortDouble) ;
                    ret = makeNonWigLineWithGDouble(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValueDouble, trackMin, scaleFactor) ;
                    break ;
                  case 1 : ;
                    guint8 spanAggValueInt8 = computeAggValueForGuint8(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScoresFromPreviousBlock, arrayToSortInt8) ;
                    ret = makeNonWigLineWithGuInt8(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, scaleScores, spanAggValueInt8, trackMin, scaleFactor) ;
                    break ;
                }
                rubyStr += ret ;
                length += ret ;
                
                /* If emptyScoreValue is provided, we will need to fill in the gap between the cuurent end coord and the next start coord */
                /* At this point, we can reuse the variables we used for filling in the leading emptyScoreValues */
                windowStartTracker = spanStart + desiredSpan ;
                coordTracker = windowStartTracker + (desiredSpan - 1) ;
                if(emptyVal != NULL &&  windowStartTracker < start && start > previousStop)
                {
                  addLeadingEmptyScores = 1 ;
                  while(coordTracker < start)
                  {
                    ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, windowStartTracker, coordTracker, chr, ctype, csubtype, emptyVal) ;
                    rubyStr += ret ;
                    length += ret ;
                    windowStartTracker = coordTracker + 1 ;
                    coordTracker += desiredSpan ;
                    if(length >= limit)
                    {
                      /* save global ruby stuff */
                      RSTRING_LEN(cBuffer) = length;
                      updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, windowStartTracker) ;
                      return 1 ; // We need to pass control to the ruby side now since our buffer is full and we don't want a seg fault. 
                    }
                  }
                }
              }
              else // No 'real' scores for the current window
              {
                if(emptyVal != NULL)
                {
                  ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, spanStart, spanStart + (desiredSpan - 1), chr, ctype, csubtype, emptyVal) ;
                  rubyStr += ret ;
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
                    ret = ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, windowStartTracker, coordTracker, chr, ctype, csubtype, emptyVal) ;
                    rubyStr += ret ;
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
              numberOfRealScores = 0 ;
              trackWindowSize = 0 ; // will be overwritten later if  addLeadingEmptyScores == 1 ;
              spanSum = 0.0 ;
              spanCount = 0 ;
              spanSoq = 0.0 ;
              spanMax = trackMin ;
              spanMin = trackMax ;
              spanStart = start ; // will be overwritten later if  addLeadingEmptyScores == 1 ;
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
                ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, windowStartTracker, coordTracker, chr, ctype, csubtype, emptyVal) ;
                rubyStr += ret ;
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
          }
          if(addLeadingEmptyScores == 1)
          {
            addLeadingEmptyScores = 0 ;
            spanStart = windowStartTracker ;
            trackWindowSize = (coordTracker - windowStartTracker) - (coordTracker - start) ;
            
          }
          // Now we loop over the data
          switch(dataSpan)
          {
            case 4 : //floatScore
              while(recordsProcessed < numRecords)
              {
                /* skip region if the first records for a window is a NaN until the first 'real' score is encountered */
                if(trackWindowSize == 0 && nullCheck32[recordsProcessed] == nullForFloatScore)
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
                if(nullCheck32[recordsProcessed] != nullForFloatScore)
                {
                  /* check if the current window started with a NaN , update start for the window if it did */
                  if(startsWithNaN == 1)
                  {
                    newStart = start ;
                    addBlockHeader = 1 ;
                    spanStart = newStart ;
                    startsWithNaN = 0 ;
                  }
                  if(spanAggFunction != 1)
                  {
                    updateAggForGFloat(spanAggFunction, floatVal[recordsProcessed], &spanSum, &spanMax, &spanMin, &spanCount, &spanSoq) ;
                  }
                  else
                  {
                    arrayToSort[numberOfRealScores] = floatVal[recordsProcessed] ;
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
                      if(retType != 7)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, spanStart, start, chr, ctype, csubtype, emptyVal) ;
                      }
                      else
                      {
                         ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                          spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                          desiredSpan, spanStart, spanStart);
                      }
                      rubyStr += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                      numberOfRealScores = 0 ;
                      trackWindowSize = 0 ;
                      spanSum = 0.0 ;
                      spanCount = 0 ;
                      spanSoq = 0.0 ;
                      spanMax = trackMin ;
                      spanMin = trackMax ;
                      spanStart = start + 1 ;
                    }
                  }
                  else
                  {
                    gfloat spanAggValue = computeAggValueForGfloat(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScores, arrayToSort) ;
                    if(retType != 7)
                    {
                      ret = makeNonWigLineWithGFloat(rubyStr, retType, spanStart, start, chr, ctype, csubtype, scaleScores, spanAggValue, trackMin, scaleFactor) ;
                    }
                    else
                    {
                      ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                        numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                        spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                        desiredSpan, spanStart, spanStart);
                    }
                    rubyStr += ret ;
                    length += ret ;
                    addBlockHeader = 0 ;
                    numberOfRealScores = 0 ;
                    trackWindowSize = 0 ;
                    spanSum = 0.0 ;
                    spanCount = 0 ;
                    spanSoq = 0.0 ;
                    spanMax = trackMin ;
                    spanMin = trackMax ;
                    spanStart = start + 1 ;
                  }
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
                if(trackWindowSize == 0 && nullCheck64[recordsProcessed] == nullForDoubleScore)
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
                if(nullCheck64[recordsProcessed] != nullForDoubleScore)
                {
                  /* check if the current window started with a NaN , update start for the window if it did */
                  if(startsWithNaN == 1)
                  {
                    newStart = start ;
                    addBlockHeader = 1 ;
                    spanStart = newStart ;
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
                      if(retType != 7)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, spanStart, start, chr, ctype, csubtype, emptyVal) ;
                      }
                      else
                      {
                         ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                          spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                          desiredSpan, spanStart, spanStart);
                      }
                      rubyStr += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                      numberOfRealScores = 0 ;
                      trackWindowSize = 0 ;
                      spanSum = 0.0 ;
                      spanCount = 0 ;
                      spanSoq = 0.0 ;
                      spanMax = trackMin ;
                      spanMin = trackMax ;
                      spanStart = start + 1 ;
                    }
                  }
                  else
                  {
                    gdouble spanAggValue = computeAggValueForGdouble(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScores, arrayToSortDouble) ;                   
                    if(retType != 7)
                    {
                      ret = makeNonWigLineWithGDouble(rubyStr, retType, spanStart, start, chr, ctype, csubtype, scaleScores, spanAggValue, trackMin, scaleFactor) ;
                    }
                    else
                    {
                      ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                        numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                        spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                        desiredSpan, spanStart, spanStart);
                    }
                    rubyStr += ret ;
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
                    spanStart = newStart ;
                    startsWithNaN = 0 ;
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
                      if(retType != 7)
                      {
                        ret = makeNonWigLineWithEmptyScoreValue(rubyStr, retType, spanStart, start, chr, ctype, csubtype, emptyVal) ;
                      }
                      else
                      {
                         ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                          numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                          spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                          desiredSpan, spanStart, spanStart);
                      }
                      rubyStr += ret ;
                      length += ret ;
                      addBlockHeader = 0 ;
                      numberOfRealScores = 0 ;
                      trackWindowSize = 0 ;
                      spanSum = 0.0 ;
                      spanCount = 0 ;
                      spanSoq = 0.0 ;
                      spanMax = trackMin ;
                      spanMin = trackMax ;
                      spanStart = start + 1 ;
                    }
                  }
                  else
                  {
                    guint8 spanAggValue = computeAggValueForGuint8(spanAggFunction, spanSum, spanCount, spanMax, spanMin, spanSoq, desiredSpan, numberOfRealScores, arrayToSortInt8) ; 
                    if(retType != 7)
                    {
                      ret = makeNonWigLineWithGuInt8(rubyStr, retType, spanStart, start, chr, ctype, csubtype, scaleScores, spanAggValue, trackMin, scaleFactor) ;
                    }
                    else
                    {
                      ret = sprintf(rubyStr, "%d\\t0\\t0\\t%d\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t%d\\t%d\\t%d\\t%s\\t%d\\t%d\\t%d\\t1\\t%d,\\t%d,\\t%d,\\n",
                                        numberOfRealScores, desiredSpan - numberOfRealScores, chr, spanStart, spanStart + (desiredSpan - 1), desiredSpan,
                                        spanStart, spanStart + (desiredSpan - 1), chr, desiredSpan, spanStart, spanStart + (desiredSpan - 1),
                                        desiredSpan, spanStart, spanStart);
                    }
                    rubyStr += ret ;
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
        }
        /* save global ruby stuff */
        RSTRING_LEN(cBuffer) = length;
        updateGlobalArray(&globalArray, recordsProcessed, spanStart, numberOfRealScores, trackWindowSize, spanSum, spanCount, spanMax, spanMin, spanSoq, numRecords, stop,
                          previousStop, addLeadingEmptyScores, coordTracker, spanTracker, spanStart) ;
        return 0 ;
      }
    EOC
  }
end
end # end Hdhv
end # end C
end # end Genboree
end # end BRL
