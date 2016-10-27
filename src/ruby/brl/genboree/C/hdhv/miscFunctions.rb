#!/usr/bin/env ruby

ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# An inline class with misc C functions 
class MiscFunctions

  # Updates the ruby array from the C side
  def self.updateGlobalArray()
    retVal =  "
                void updateGlobalArray(VALUE *globalArray, int recordsProcessed, int spanStart, int numberOfRealScores, long trackWindowSize, double spanSum, long spanCount,
                                      double spanMax, double spanMin, double spanSoq, int numRecords, int stop, int previousStop, int addLeadingEmptyScores, long coordTracker,
                                      long spanTracker, long windowStartTracker)
                {
                  rb_ary_store(*globalArray, 0, LONG2FIX(recordsProcessed)) ;
                  rb_ary_store(*globalArray, 1, LONG2FIX(spanStart)) ;
                  rb_ary_store(*globalArray, 2, LONG2FIX(numberOfRealScores)) ;
                  rb_ary_store(*globalArray, 3, LONG2FIX(trackWindowSize)) ;
                  rb_ary_store(*globalArray, 4, rb_float_new(spanSum)) ;
                  rb_ary_store(*globalArray, 5, LONG2FIX(spanCount)) ;
                  rb_ary_store(*globalArray, 6, rb_float_new(spanMax)) ;
                  rb_ary_store(*globalArray, 7, rb_float_new(spanMin)) ;
                  rb_ary_store(*globalArray, 8, rb_float_new(spanSoq)) ;
                  if(recordsProcessed == numRecords)
                    rb_ary_store(*globalArray, 11, LONG2FIX(stop)) ;
                  else
                    rb_ary_store(*globalArray, 11, LONG2FIX(previousStop)) ;
                  rb_ary_store(*globalArray, 12, LONG2FIX(addLeadingEmptyScores)) ;
                  rb_ary_store(*globalArray, 13, LONG2FIX(coordTracker)) ;
                  rb_ary_store(*globalArray, 14, LONG2FIX(spanTracker)) ;
                  rb_ary_store(*globalArray, 15, LONG2FIX(windowStartTracker)) ;
                }
                
              "
    return retVal
  end
  
  def self.makeWigLineForWindowForGfloat()
    
    retVal =  "
                int makeWigLineForWindowForGfloat(long spanAggFunction, guchar *temp, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq,
                                                int desiredSpan, int retType, int spanStart, gfloat *arrayToSort, int numberOfRealScores)
                {
                  int ret ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum / spanCount), retType, spanStart) ;
                      break ;
                    case 3 : // max
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanMax), retType, spanStart) ;
                      break ;
                    case 4 : // min
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanMin), retType, spanStart) ;
                      break ;
                    case 5 : // sum
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum), retType, spanStart) ;
                      break ;
                    case 6 : // stdev
                      ret = makeWigLineWithGFloat(temp, (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                      break ;
                    case 7 : // count
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanCount), retType, spanStart) ;
                      break ;
                    case 8 : // avgBylength
                      ret = makeWigLineWithGFloat(temp, (gfloat)(spanSum / desiredSpan), retType, spanStart) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                      {
                        ret = makeWigLineWithGFloat(temp, arrayToSort[0], retType, spanStart) ;
                      }
                      else if(numberOfRealScores > 1)
                      {
                        ret = makeWigLineWithGFloat(temp, calcMedianForGfloat(arrayToSort, numberOfRealScores), retType, spanStart) ;
                      }
                      break ;
                  }
                  return ret ;
                }
    
    
    
              "
    return retVal
  end
  
  def self.makeWigLineForWindowForGdouble()
    
    retVal =  "
                int makeWigLineForWindowForGdouble(long spanAggFunction, guchar *temp, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq,
                                                int desiredSpan, int retType, int spanStart, gdouble *arrayToSortDouble, int numberOfRealScores)
                {
                  int ret ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum / spanCount), retType, spanStart) ;
                      break ;
                    case 3 : // max
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanMax), retType, spanStart) ;
                      break ;
                    case 4 : // min
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanMin), retType, spanStart) ;
                      break ;
                    case 5 : // sum
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum), retType, spanStart) ;
                      break ;
                    case 6 : // stdev
                      ret = makeWigLineWithGDouble(temp, (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                      break ;
                    case 7 : // count
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanCount), retType, spanStart) ;
                      break ;
                    case 8 : // avgByLength
                      ret = makeWigLineWithGDouble(temp, (gdouble)(spanSum / desiredSpan), retType, spanStart) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                      {
                        ret = makeWigLineWithGDouble(temp, arrayToSortDouble[0], retType, spanStart) ;
                      }
                      else if(numberOfRealScores > 1)
                      {
                        ret = makeWigLineWithGDouble(temp, calcMedianForGdouble(arrayToSortDouble, numberOfRealScores), retType, spanStart) ;
                      }
                      break ;
                  }
                  return ret ;
                }
    
    
    
              "
    return retVal
  end
  
  def self.makeWigLineForWindowForGuint8()
    
    retVal =  "
                int makeWigLineForWindowForGuint8(long spanAggFunction, guchar *temp, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq,
                                                int desiredSpan, int retType, int spanStart, guint8 *arrayToSortInt8, int numberOfRealScores)
                {
                  int ret ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanSum / spanCount), retType, spanStart) ;
                      break ;
                    case 3 : // max
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanMax), retType, spanStart) ;
                      break ;
                    case 4 : // min
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanMin), retType, spanStart) ;
                      break ;
                    case 5 : // sum
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanSum), retType, spanStart) ;
                      break ;
                    case 6 : // stdev
                      ret = makeWigLineWithGuInt8(temp, (guint8)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))), retType, spanStart) ;
                      break ;
                    case 7 : // count
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanCount), retType, spanStart) ;
                      break ;
                    case 8 : // avgByLength
                      ret = makeWigLineWithGuInt8(temp, (guint8)(spanSum / desiredSpan), retType, spanStart) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                      {
                        ret = makeWigLineWithGuInt8(temp, arrayToSortInt8[0], retType, spanStart) ;
                      }
                      else if(numberOfRealScores > 1)
                      {
                        ret = makeWigLineWithGuInt8(temp, calcMedianForGuint8(arrayToSortInt8, numberOfRealScores), retType, spanStart) ;
                      }
                      break ;
                  }
                  return ret ;
                }
    
    
    
              "
    return retVal
  end
  
  def self.computeAggValueForGfloat()
    retVal = "
                gfloat computeAggValueForGfloat(int spanAggFunction, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq, int desiredSpan, long numberOfRealScores, gfloat *arrayToSort)
                {
                  gfloat spanAggValue ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      spanAggValue = (gfloat)(spanSum / spanCount) ;
                      break ;
                    case 3 : // max
                      spanAggValue = (gfloat)spanMax ;
                      break ;
                    case 4 : // min
                      spanAggValue = (gfloat)spanMin ;
                      break ;
                    case 5 : // sum
                      spanAggValue = (gfloat)spanSum ;
                      break ;
                    case 6 : // stdev
                      spanAggValue = (gfloat)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
                      break ;
                    case 7 : // count
                      spanAggValue = (gfloat)spanCount ;
                      break ;
                    case 8 : //avgByLength
                      spanAggValue = (gfloat)(spanSum / desiredSpan) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                      {
                        spanAggValue = arrayToSort[0] ;
                      }
                      else if(numberOfRealScores > 1)
                      {
                        spanAggValue = calcMedianForGfloat(arrayToSort, numberOfRealScores) ;
                      }
                      break ;
                  }
                  return spanAggValue ;
                }
    
              "
  end
  
  def self.computeAggValueForGdouble()
    retVal = "
                gdouble computeAggValueForGdouble(int spanAggFunction, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq, int desiredSpan, long numberOfRealScores, gdouble *arrayToSortDouble)
                {
                  gdouble spanAggValue ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      spanAggValue = (gdouble)(spanSum / spanCount) ;
                      break ;
                    case 3 : // max
                      spanAggValue = (gdouble)spanMax ;
                      break ;
                    case 4 : // min
                      spanAggValue = (gdouble)spanMin ;
                      break ;
                    case 5 : // sum
                      spanAggValue = (gdouble)spanSum ;
                      break ;
                    case 6 : // stdev
                      spanAggValue = (gdouble)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
                      break ;
                    case 7 : // count
                      spanAggValue = (gdouble)spanCount ;
                      break ;
                    case 8 : //avgByLength
                      spanAggValue = (gdouble)(spanSum / desiredSpan) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                        spanAggValue = arrayToSortDouble[0] ;
                      else if(numberOfRealScores > 1)
                        spanAggValue = calcMedianForGdouble(arrayToSortDouble, numberOfRealScores) ;
                      break ;
                  }
                  return spanAggValue ;
                }
    
              "
  end
  
  def self.computeAggValueForGuint8()
    retVal = "
                guint8 computeAggValueForGuint8(int spanAggFunction, double spanSum, long spanCount, double spanMax, double spanMin, double spanSoq, int desiredSpan, long numberOfRealScores, guint8 *arrayToSortInt8)
                {
                  guint8 spanAggValue ;
                  switch(spanAggFunction)
                  {
                    case 2 : // mean
                      spanAggValue = (guint8)(spanSum / spanCount) ;
                      break ;
                    case 3 : // max
                      spanAggValue = (guint8)spanMax ;
                      break ;
                    case 4 : // min
                      spanAggValue = (guint8)spanMin ;
                      break ;
                    case 5 : // sum
                      spanAggValue = (guint8)spanSum ;
                      break ;
                    case 6 : // stdev
                      spanAggValue = (guint8)(sqrt((spanSoq / spanCount) - ((spanSum / spanCount) * (spanSum / spanCount)))) ;
                      break ;
                    case 7 : // count
                      spanAggValue = (guint8)spanCount ;
                      break ;
                    case 8 : //avgByLength
                      spanAggValue = (guint8)(spanSum / desiredSpan) ;
                      break ;
                    default : // median
                      if(numberOfRealScores == 1)
                        spanAggValue = arrayToSortInt8[0] ;
                      else if(numberOfRealScores > 1)
                        spanAggValue = calcMedianForGuint8(arrayToSortInt8, numberOfRealScores) ;
                      break ;
                  }
                  return spanAggValue ;
                }
    
              "
  end
  
  def self.writeWigLineForAggFunction()
    retVal = "
                int writeWigLineForAggFunction(int dataSpan, long spanAggFunction, guchar *temp, double spanSum, long spanCount, double spanMax, double spanMin, int spanStart, int retType, double spanSoq,
                                             int desiredSpan, gfloat *arrayToSort, gdouble *arrayToSortDouble, guint8 *arrayToSortInt8, long numberOfRealScoresFromPreviousBlock)
                {
                  int ret ;
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
                      if(numberOfRealScoresFromPreviousBlock == 1)
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
                            ret = makeWigLineWithGuInt8(temp, arrayToSortInt8[0], retType, spanStart) ;
                            break ;
                        }
                      }
                      else if(numberOfRealScoresFromPreviousBlock > 1)
                      {
                        switch(dataSpan)
                        {
                          case 4 :
                            ret = makeWigLineWithGFloat(temp, calcMedianForGfloat(arrayToSort, numberOfRealScoresFromPreviousBlock), retType, spanStart) ;
                            break ;
                          case 8 :
                            ret = makeWigLineWithGDouble(temp, calcMedianForGdouble(arrayToSortDouble, numberOfRealScoresFromPreviousBlock), retType, spanStart) ;
                            break ;
                          case 1 :
                            ret = makeWigLineWithGuInt8(temp, calcMedianForGuint8(arrayToSortInt8, numberOfRealScoresFromPreviousBlock), retType, spanStart) ;
                            break ;
                        }
                      }
                      break ;
                  }
                  return ret ;
                }
            "
    return retVal
  end
  
end
end; end; end; end
