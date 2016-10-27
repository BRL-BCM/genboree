#!/usr/bin/env ruby
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# A class for creating wig formatted lines (fixedStep/variableStep)
# The class methods in this class will be used as C functions by the hdhv inline C functions to create wig formatted lines
class MakeWigLine

  def self.makeWigLineWithGFloat()
    retVal = ""
    retVal =  "
                int makeWigLineWithGFloat(guchar* buffer, gfloat score, int retType, long coord)
                {
                  int ret ;
                  if(retType == 1)
                  {
                    ret = sprintf(buffer, \"%.6g\\n\", score) ;
                  }
                  else
                  {
                    ret = sprintf(buffer, \"%d %.6g\\n\", coord, score) ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeWigLineWithGDouble()
    retVal = ""
    retVal =  "
                int makeWigLineWithGDouble(guchar* buffer, gdouble score, int retType, long coord)
                {
                  int ret ;
                  if(retType == 1)
                  {
                    ret = sprintf(buffer, \"%.16g\\n\", score) ;
                  }
                  else
                  {
                    ret = sprintf(buffer, \"%d %.16g\\n\", coord, score) ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeWigLineWithGuInt8()
    retVal = ""
    retVal =  "
                int makeWigLineWithGuInt8(guchar* buffer, gfloat score, int retType, long coord)
                {
                  int ret ;
                  if(retType == 1)
                  {
                    ret = sprintf(buffer, \"%.3g\\n\", score) ;
                  }
                  else
                  {
                    ret = sprintf(buffer, \"%d %.3g\\n\", coord, score) ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeWigLineWithEmptyScoreValue()
    retVal = ""
    retVal =  "
                int makeWigLineWithEmptyScoreValue(guchar* buffer, char* score, int retType, long coord)
                {
                  int ret ;
                  if(retType == 1)
                  {
                    ret = sprintf(buffer, \"%s\\n\", score) ;
                  }
                  else
                  {
                    ret = sprintf(buffer, \"%d %s\\n\", coord, score) ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  
end
end; end; end; end
