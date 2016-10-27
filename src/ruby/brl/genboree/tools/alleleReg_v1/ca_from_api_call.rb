class Allele
 def ca_from_api_call config, apiCaller

  $stderr.puts "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
  $stderr.puts "inside ca_from_api_call"
  $stderr.puts self.canonicalAllele
  $stderr.puts "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"

  ca_hash = self.get_canonical_allele_by_uri(config,apiCaller)

  new_rsa = RelatedSimpleAllele.new({"simpleAllele" => self.subject, "preferred"=>"false"}).to_hash

  ca_hash["CanonicalAllele"]["properties"]["Subject"]["properties"]["relatedSimpleAlleles"]["items"].push(new_rsa)

  return ca_hash

 end
end
