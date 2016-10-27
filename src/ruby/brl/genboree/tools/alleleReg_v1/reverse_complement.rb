# given a DNA sequence in a string return its reverse complement  
def reverse_complement(seq) 
  if seq.tr("ACGT","""").size  != 0
   raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"While generating reverse complement of reference or alternate allele, program encountered characters other than A,C,G,T")
  else 
   return seq.reverse().tr!('ATCG','TAGC')
  end
end
