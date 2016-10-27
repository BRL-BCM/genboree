#!/usr/bin/env ruby

ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# A class for updating aggregates
# The class methods in this class will be used as C functions by the hdhv inline C functions to update the reqiured aggregates requested via the 'spanAggFunction' parameter
# Median is not included since it cannot be computed online
# ToDO: try to make the aggregates into globals to avoid dereferencing 
class UpdateAggregates

  def self.updateAggForGFloat()
    retVal = ""
    retVal =  "
                void updateAggForGFloat(int spanAggFunction, gfloat score, double *spanSum, double *spanMax, double *spanMin, long *spanCount, double *spanSoq)
                {
                  switch(spanAggFunction)
                  {
                    case 2 :  // mean
                      *spanSum += score ;
                      *spanCount += 1 ;
                      break ;
                    case 3 :  // max
                      *spanMax = score > *spanMax ? score : *spanMax ;
                      break ;
                    case 4 :  // min
                      *spanMin = score < *spanMin ? score : *spanMin ;
                      break ;
                    case 5 :  // sum
                      *spanSum += score ;
                      break ;
                    case 6 :  // stdev
                      *spanSoq += score * score ;
                      *spanSum += score ;
                      *spanCount += 1 ;
                      break ;
                    case 7 :  // count
                      *spanCount += 1 ;
                      break ;
                    case 8 : // avgByLength
                      *spanSum += score ;
                      break ;
                  }
                }
                
              "
    return retVal
  end
  
  def self.updateAggForGDouble()
    retVal = ""
    retVal =  "
                void updateAggForGDouble(int spanAggFunction, gdouble score, double *spanSum, double *spanMax, double *spanMin, long *spanCount, double *spanSoq)
                {
                  switch(spanAggFunction)
                  {
                    case 2 :  // mean
                      *spanSum += score ;
                      *spanCount += 1 ;
                      break ;
                    case 3 :  // max
                      *spanMax = score > *spanMax ? score : *spanMax ;
                      break ;
                    case 4 :  // min
                      *spanMin = score < *spanMin ? score : *spanMin ;
                      break ;
                    case 5 :  // sum
                      *spanSum += score ;
                      break ;
                    case 6 :  // stdev
                      *spanSoq += score * score ;
                      *spanSum += score ;
                      *spanCount += 1 ;
                      break ;
                    case 7 :  // count
                      *spanCount += 1 ;
                      break ;
                    case 8 : // avgByLength
                      *spanSum += score ;
                      break ;
                  }
                }
                
              "
    return retVal
  end
  
  def self.updateAggForGuInt8()
    retVal = ""
    retVal =  "
                void updateAggForGuInt8(int spanAggFunction, guint8 score, double *spanSum, double *spanMax, double *spanMin, long *spanCount, double *spanSoq, double lowLimit, double scale, double denom)
                {
                  // Cast into double since 'spanSum, spanMin, etc' are all doubles. Will cast back into guint8 when printing into buffer
                  switch(spanAggFunction)
                  {
                    case 2 :  // mean
                      *spanSum += (double)(lowLimit + (scale * (score / denom))) ;
                      *spanCount += 1;
                      break ;
                    case 3 :  // max
                      *spanMax = (double)(lowLimit + (scale * (score / denom))) > *spanMax ? (double)(lowLimit + (scale * (score / denom))) : *spanMax ;
                      break ;
                    case 4 :  // min
                      *spanMin = (double)(lowLimit + (scale * (score / denom))) < *spanMin ? (double)(lowLimit + (scale * (score / denom))) : *spanMin ;
                      break ;
                    case 5 :  // sum
                      *spanSum += (double)(lowLimit + (scale * (score / denom))) ;
                      break ;
                    case 6 :  // stdev
                      *spanSoq += (double)((lowLimit + (scale * (score / denom))) * (lowLimit + (scale * (score / denom)))) ;
                      *spanSum += (double)(lowLimit + (scale * (score / denom))) ;
                      *spanCount += 1;
                      break ;
                    case 7 :  // count
                      *spanCount += 1;
                      break ;
                    case 8 : // avgBylength
                      *spanSum += (double)(lowLimit + (scale * (score / denom))) ;
                      break ;
                  }
                }
                
              "
    return retVal
  end
  
end
end; end; end; end
