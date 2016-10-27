#!/usr/bin/env ruby
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
class TestSegFault
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
    builder.c <<-EOC
    void testSegFault(VALUE binScores, VALUE tempBinScores, VALUE tempBinScores2)
    {
      long binScoresLength = RSTRING_LEN(binScores) ;
      long tempBinScoresLength = RSTRING_LEN(tempBinScores) ;
      long tempBinScores2Length = RSTRING_LEN(tempBinScores2) ;
      
      fprintf(stderr, "length of binScores: %d\\n", binScoresLength) ;
      fprintf(stderr, "length of tempBinScores: %d\\n", tempBinScoresLength) ;
      fprintf(stderr, "length of tempBinScores2: %d\\n", tempBinScores2Length) ;
      
      char *binS = (char *)(void *)RSTRING_PTR(binScores) ;
      char *tbinS = (char *)(void *)RSTRING_PTR(tempBinScores) ;
      char *tbinS2 = (char *)(void *)RSTRING_PTR(tempBinScores2) ;
      
      long binScoresStartAddress = (long)(binS) ;
      long tempBinScoresStartAddress = (long)(tbinS) ;
      long tempBinScores2StartAddress = (long)(tbinS2) ;
      
      long binScoresPosStopAddress = binScoresStartAddress + binScoresLength ;
      long binScoresNegStopAddress = binScoresStartAddress - binScoresLength ;
      
      long tempBinScoresPosStopAddress = tempBinScoresStartAddress + tempBinScoresLength ;
      long tempBinScoresNegStopAddress = tempBinScoresStartAddress - tempBinScoresLength ;
      
      long tempBinScores2PosStopAddress = tempBinScores2StartAddress + tempBinScores2Length ;
      long tempBinScores2NegStopAddress = tempBinScores2StartAddress - tempBinScores2Length ;
      
      fprintf(stderr, "range (binScores): %ld-%ld-%ld\\n", binScoresNegStopAddress, binScoresStartAddress, binScoresPosStopAddress) ;
      fprintf(stderr, "range (tempBinScores): %ld-%ld-%ld\\n", tempBinScoresNegStopAddress, tempBinScoresStartAddress, tempBinScoresPosStopAddress) ;
      fprintf(stderr, "range (tempBinScores2): %ld-%ld-%ld\\n",tempBinScores2NegStopAddress,  tempBinScores2StartAddress, tempBinScores2PosStopAddress) ;
    }
    EOC
  }
end

end; end; end; end
