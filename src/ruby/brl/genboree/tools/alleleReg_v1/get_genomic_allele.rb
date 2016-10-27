class Allele
def get_genomic_allele
 $stderr.puts "Inside get genomic allele!"
 # check if genomic or amino-acid allele
 # if so raise error
 # if transcript then use appropriate self.genomicStart/End/ref/Alt allele information to generate hg38 alleles
 # if indel please normalize 
 # update self.genomicStart, self.genomicEnd, ref/alt of genomic allele
 # @mutationType=
 case self.mutationType
   when "SO:1000002^substitution"
    type = "s"
   when "SO:0000159^deletion"
    type = "d"
   when "SO:0000667^insertion"
    type = "i"
   when "SO:1000032^indel"
    type = "d"
   else 
    raise BRL::Genboree::GenboreeError.new(:'Not Implemented',"while generating genomic alleles from transcript alleles, to generate allele name, one has to convert zero based coordinates to one based coordinates. The procedure of converting zero and one based coordinate is dependent upon type of mutation. Currently, the overall functionality is implementd when mutation type is SO:1000002^substitution, SO:0000159^deletion, SO:0000667^insertion or SO:1000032^indel. The mutationType of current allele is none of them. That is why the further steps will not work")
 end

 startc,endc = zeroToOne(type, self.startGenomic, self.endGenomic)

 $stderr.puts "step1"
 $stderr.puts self.referenceAllele
 $stderr.puts self.alternateAllele
# :referenceAllele,:alternateAllele,

 genomic_reference = self.referenceAllele 
 genomic_alternate = self.alternateAllele

 $stderr.puts "step2"
 $stderr.puts t2g_alignment_oritentation
 $stderr.puts genomic_reference
 $stderr.puts genomic_alternate

 #if (self.startGenomic > self.endGenomic) != (self.alleleStart > self.alleleEnd)
 if t2g_alignment_oritentation == true
     #self.reference
   if self.referenceAllele.nil? == false
     genomic_reference = reverse_complement(self.referenceAllele)
   end
   if self.alternateAllele.nil? == false
     genomic_alternate = reverse_complement(self.alternateAllele)
   end
 end
 $stderr.puts genomic_reference
 $stderr.puts genomic_alternate
 $stderr.puts "step3"

 genomic_hgvs = make_hgvs(startc,endc,
                          self.mutationType,self.referenceGenomicId,
                          genomic_reference,genomic_alternate,"g")

 $stderr.puts "step4"
 $stderr.puts genomic_hgvs
 return genomic_hgvs

 #puts startc,endc
 # convert zero based on one based system
 #puts self.endGenomic
 #puts self.referenceGenomic
 #puts self.alleleNameType
 #@startGenomic, @endGenomic, @referenceGenomic,@alleleNameType,
end
end
