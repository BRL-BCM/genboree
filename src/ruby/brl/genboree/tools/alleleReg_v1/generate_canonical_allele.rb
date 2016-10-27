class Allele

 attr_accessor :canonical_allele_instance

 def generate_canonical_allele
  $stderr.puts "In find_canonical_allele"
  $stderr.puts "Currently no extra efforts put foward to find canonical allele extensively"
  $stderr.puts "Just a new canonical allele is generated and sent to registration"

  # Currently just intialize canonical allele
  # Send put request

  #canonical_allele_doc_id   =  self.doc_id
  #canonical_allele_doc_id   =  canonical_allele_doc_id.gsub("SA","CA")
  canonical_allele_doc_id = get_document_id @config.canonicalAllele_path+"/model/prop/CanonicalAllele/autoIDs",self.apiCaller

  $stderr.puts "Determining type of canonical allele"
  if self.refSeqType == "genomic" 
    ca_type = "nucleotide"
  elsif self.refSeqType == "transcript"
    ca_type = "nucleotide"
  elsif self.refSeqType == "amino acid"
    ca_type = "amino-acid"
  else
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Cannot understand the simple allele change type of simple allele")
  end

  $stderr.puts "Initializing identifiers"
  ids = [] 
  ids.push(Identifier.new(use="official",
                          label=canonical_allele_doc_id,
                          system="http://reg.genome.network/allele/",
                          value=canonical_allele_doc_id).to_hash)

  related_simple_alleles =[]

  $stderr.puts "Initializing related simple alleles"
  related_simple_alleles.push(RelatedSimpleAllele.new({
                                       "simpleAllele" => self.subject,
                                       "preferred" => true}
                                       ).to_hash)
  #puts temp
  #related_simple_alleles.push(temp)

  $stderr.puts "Initializing canonical allele"
  abc = CanonicalAllele.new(
                           {
                           "CanonicalAllele" => canonical_allele_doc_id,
                           "Subject" => "http://reg.genome.network/allele/"+canonical_allele_doc_id, 
                           "version" => 1.to_s,
                           "RelatedSimpleAlleles" => related_simple_alleles,
                           "identifiers" => ids,
                           "canonicalAlleleType" => ca_type
                           }
                          )

   
  @canonical_allele_instance = abc
 end
end
