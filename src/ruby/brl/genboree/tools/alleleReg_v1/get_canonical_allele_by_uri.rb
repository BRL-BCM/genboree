class Allele
 def get_canonical_allele_by_uri(config, apiCaller)

   doc_url = self.canonicalAllele.split("/").last

   uri = "#{config.canonicalAllele_path}/doc/#{CGI.escape(doc_url)}"
   uri = URI.parse(uri)
   apic = apiCaller
   apic.setRsrcPath(uri.path)
   apic.get

   #given_hash = apic.parseRespBody["data"]
   #new_rsa = RelatedSimpleAllele.new({"simpleAllele" => self.subject, "preferred"=>"false"}).to_hash
   #given_hash["CanonicalAllele"]["properties"]["Subject"]["properties"]["relatedSimpleAlleles"]["items"].push(new_rsa)

   #$stderr.puts JSON.pretty_generate given_hash

   if apic.succeeded? 
     return(apic.parseRespBody["data"])
   else 
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"The api request to get the canonical allele failed")
   end

 end
end
