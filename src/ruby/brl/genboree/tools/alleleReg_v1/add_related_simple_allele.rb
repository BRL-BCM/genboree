class CanonicalAllele
 attr_accessor :add_related_simple_allele
 def add_related_simple_allele simple_allele_uri,preferred

   abc = RelatedSimpleAllele.new({"simpleAllele"=>simple_allele_uri,"preferred" => preferred}).to_hash

   self.RelatedSimpleAlleles.push(abc)
 end
end


