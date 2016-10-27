#!/usr/bin/env ruby
ENV['INLINEDIR'] = '.' unless(ENV['INLINEDIR'])
require 'inline'
module BRL; module Genboree; module C; module Hdhv
class TestBinScores
  include BRL::C
  inline { |builder|
    builder.add_compile_flags(CFunctionWrapper.compileFlags(:base, :math, :glib))
    builder.c <<-EOC
    void testBinScores(VALUE binScores, int dataSpan, int numRec)
    {
      char *bin = (char *)(void *)RSTRING_PTR(binScores) ;
      int length = RSTRING_LEN(binScores) ;
      fprintf(stderr, "Address of binScores at the beginning of getBackScores(): %ld; Length: %d\\n", (long)bin, length) ;
      int ii = 0 ;
      char check ;
      int bytes = dataSpan * numRec ;
      fprintf(stderr, "going to start looping over binScores (bytes): %d\\n", bytes) ;
      for(ii = 0; ii < bytes; ii ++)
      {
        //fprintf(stderr, "%d\t", ii) ;
        check = bin[ii] ;
      }
      fprintf(stderr, "Last char (binScores): %c\\n", check) ;
    }
    EOC
  }
end

end; end; end; end
