#!/usr/bin/env ruby
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv

# A class for creating non-wig formatted lines (bed, bedGraph, lff, gff, gff3, gtf and psl)
# The class methods in this class will be used as C functions by the hdhv inline C functions to create non-wig formatted lines
class MakeNonWigLine

  def self.makeNonWigLineWithGFloat()
    retVal = ""
    retVal =  "
                int makeNonWigLineWithGFloat(guchar *buffer, int retType, long startCoord, long endCoord, char *chr, char *ctype, char *csubtype, int scaleScores, gfloat score, double trackMin, double scaleFactor)
                {
                  int ret ;
                  switch(retType)
                  {
                    case 1 : //bed : starts with 0
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n\", chr, startCoord - 1, endCoord, score); 
                      else
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%.6g\\t+\\n\", chr, startCoord - 1, endCoord, round((score - trackMin) / scaleFactor));
                      break ;
                    case 2 : //bedGraph : starts with 0
                      ret = sprintf(buffer, \"%s\\t%d\\t%d\\t%.6g\\n\", chr, startCoord - 1, endCoord, score);
                      break ;
                    case 3 : //lff
                      ret = sprintf(buffer, \"High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.6g\\n\", chr,
                              startCoord, endCoord, ctype, csubtype, chr, startCoord, endCoord, score);
                      break ;
                    case 4 : //gff
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 5 : //gff3
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 6 : //gtf
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord + 1, endCoord, score, chr, startCoord, endCoord, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.6g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord, chr, startCoord, endCoord);
                      break ;
                    case 7 : //psl
                      ret = sprintf(buffer, \"1\\t0\\t0\\t0\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t1\\t%d\\t%d\\t%s\\t1\\t%d\\t%d\\t1\\t1,\\t%d\\t%d\\n\",
                                      chr, startCoord, startCoord, startCoord, startCoord, chr, startCoord, startCoord,
                                      startCoord, startCoord);
      
                      break ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeNonWigLineWithGDouble()
    retVal = ""
    retVal =  "
                int makeNonWigLineWithGDouble(guchar *buffer, int retType, long startCoord, long endCoord, char *chr, char *ctype, char *csubtype, int scaleScores, gdouble score, double trackMin, double scaleFactor)
                {
                  int ret ;
                  switch(retType)
                  {
                    case 1 : //bed : starts with 0
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n\", chr, startCoord - 1, endCoord, score); 
                      else
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%.16g\\t+\\n\", chr, startCoord - 1, endCoord, round((score - trackMin) / scaleFactor));
                      break ;
                    case 2 : //bedGraph : starts with 0
                      ret = sprintf(buffer, \"%s\\t%d\\t%d\\t%.16g\\n\", chr, startCoord - 1, endCoord, score);
                      break ;
                    case 3 : //lff
                      ret = sprintf(buffer, \"High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.16g\\n\", chr,
                              startCoord, endCoord, ctype, csubtype, chr, startCoord, endCoord, score);
                      break ;
                    case 4 : //gff
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gdouble)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 5 : //gff3
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gdouble)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 6 : //gtf
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord + 1, endCoord, score, chr, startCoord, endCoord, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.16g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord, chr, startCoord, endCoord);
                      break ;
                    case 7 : //psl
                      ret = sprintf(buffer, \"1\\t0\\t0\\t0\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t1\\t%d\\t%d\\t%s\\t1\\t%d\\t%d\\t1\\t1,\\t%d\\t%d\\n\",
                                      chr, startCoord, startCoord, startCoord, startCoord, chr, startCoord, startCoord,
                                      startCoord, startCoord);
      
                      break ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeNonWigLineWithGuInt8()
    retVal = ""
    retVal =  "
                int makeNonWigLineWithGuInt8(guchar *buffer, int retType, long startCoord, long endCoord, char *chr, char *ctype, char *csubtype, int scaleScores, gfloat score, double trackMin, double scaleFactor)
                {
                  int ret ;
                  switch(retType)
                  {
                    case 1 : //bed : starts with 0
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%.3g\\t+\\n\", chr, startCoord - 1, endCoord, score); 
                      else
                        ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%d\\t+\\n\", chr, startCoord - 1, endCoord, (guint8)round((score - trackMin) / scaleFactor));
                      break ;
                    case 2 : //bedGraph : starts with 0
                      ret = sprintf(buffer, \"%s\\t%d\\t%d\\t%.3g\\n\", chr, startCoord - 1, endCoord, score);
                      break ;
                    case 3 : //lff
                      ret = sprintf(buffer, \"High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%.3g\\n\", chr,
                              startCoord, endCoord, ctype, csubtype, chr, startCoord, endCoord, score);
                      break ;
                    case 4 : //gff
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 5 : //gff3
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord);
                      break ;
                    case 6 : //gtf
                      if(scaleScores == 0)
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord + 1, endCoord, score, chr, startCoord, endCoord, chr, startCoord, endCoord);
                      else
                        ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%.3g\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord, endCoord, (gfloat)((score - trackMin) / scaleFactor),
                                      chr, startCoord, endCoord, chr, startCoord, endCoord);
                      break ;
                    case 7 : //psl
                      ret = sprintf(buffer, \"1\\t0\\t0\\t0\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t1\\t%d\\t%d\\t%s\\t1\\t%d\\t%d\\t1\\t1,\\t%d\\t%d\\n\",
                                      chr, startCoord, startCoord, startCoord, startCoord, chr, startCoord, startCoord,
                                      startCoord, startCoord);
      
                      break ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  def self.makeNonWigLineWithEmptyScoreValue()
    retVal = ""
    retVal =  "
                int makeNonWigLineWithEmptyScoreValue(guchar *buffer, int retType, long startCoord, long endCoord, char *chr, char *ctype, char *csubtype, char *score)
                {
                  int ret ;
                  switch(retType)
                  {
                    case 1 : //bed : starts with 0
                      ret = sprintf(buffer, \"%s\\t%d\\t%d\\t.\\t%s\\t+\\n\", chr, startCoord - 1, endCoord, score); 
                      break ;
                    case 2 : //bedGraph : starts with 0
                      ret = sprintf(buffer, \"%s\\t%d\\t%d\\t%s\\n\", chr, startCoord - 1, endCoord, score);
                      break ;
                    case 3 : //lff
                      ret = sprintf(buffer, \"High Density Score Data\\t%s:%d-%d\\t%s\\t%s\\t%s\\t%d\\t%d\\t+\\t.\\t%s\\n\", chr,
                              startCoord, endCoord, ctype, csubtype, chr, startCoord, endCoord, score);
                      break ;
                    case 4 : //gff
                      ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\t%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      break ;
                    case 5 : //gff3
                      ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\tName=%s:%d-%d\\n\", chr, ctype, csubtype, startCoord, endCoord, score, chr, startCoord, endCoord);
                      break ;
                    case 6 : //gtf
                      ret = sprintf(buffer, \"%s\\t%s\\t%s\\t%d\\t%d\\t%s\\t.\\t.\\tgene_id \\\"%s:%d-%d\\\"; transcript_id \\\"%s:%d-%d\\\"\\n\",
                                      chr, ctype, csubtype, startCoord + 1, endCoord, score, chr, startCoord, endCoord, chr, startCoord, endCoord);
                      break ;
                    case 7 : //psl
                      ret = sprintf(buffer, \"1\\t0\\t0\\t0\\t0\\t0\\t0\\t0\\t+\\t%s:%d-%d\\t1\\t%d\\t%d\\t%s\\t1\\t%d\\t%d\\t1\\t1,\\t%d\\t%d\\n\",
                                      chr, startCoord, startCoord, startCoord, startCoord, chr, startCoord, startCoord,
                                      startCoord, startCoord);
      
                      break ;
                  }
                  return ret ;
                }
                
              "
    return retVal
  end
  
  
end
end; end; end; end
