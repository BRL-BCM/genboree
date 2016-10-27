class Allele
 def register_canonical_allele(config, apiCaller)

   $stderr.puts "Generating and cleaning the canonical allele hash/json!"
   ca_hash = self.canonical_allele_instance.to_hash
   $stderr.puts JSON.pretty_generate ca_hash
   genbkb_hash_delete_null ca_hash
   follow_genbkb_hash_delete_null ca_hash
   $stderr.puts "Get the document id of canonical allele to send put request"
   docid = ca_hash["CanonicalAllele"]["value"]
   $stderr.puts "This is the doc id of canonical allele to be registered #{docid}"
   # get the uri of new resource where  put request will be made
   uri = "#{config.canonicalAllele_path}/doc/#{CGI.escape(docid)}"
   $stderr.puts "This is the URI to send put request #{docid}"
   uri = URI.parse(uri)
   # first see if the document id is already taken
   apic = apiCaller
   apic.setRsrcPath(uri.path)
   apic.get
    apic.parseRespBody()
    resp_json = apic.apiRespObj
   if resp_json["status"]["msg"] == "OK" and resp_json["data"] != 0
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"The document id is already been taken,change document id and try again")
   end
   $stderr.puts "Sending put request for canonical allele"
   apic = apiCaller
   apic.setRsrcPath(uri.path)
   apic.put(ca_hash.to_json)
   if apic.succeeded? == true
    $stderr.puts "The put request for canonical allele is suceeded, your allele is now registered"
    $stderr.puts "Here goes your document"
    apic.parseRespBody()
    resp_json = apic.apiRespObj
    $stderr.puts JSON::pretty_generate resp_json
    $stderr.puts "Document concluded"
   else
    apic.parseRespBody()
    resp_json = apic.apiRespObj
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Put request of canonical allele failed: Log followed #{resp_json}")
   end
 end
end
