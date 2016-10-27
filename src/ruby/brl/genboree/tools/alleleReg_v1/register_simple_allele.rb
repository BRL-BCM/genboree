class Allele
 def register_simple_allele(config, apiCaller)

   $stderr.puts "The allele is not registered, will attempt to register!"
   $stderr.puts "Cleaning the simple allele hash/json!"

   self.generate_hash

   $stderr.puts JSON.pretty_generate self.allele_hash

   genbkb_hash_delete_null self.allele_hash
   follow_genbkb_hash_delete_null self.allele_hash

   $stderr.puts "Get the document id of simple allele to send put request"
   docid = self.allele_hash["SimpleAllele"]["value"]

   $stderr.puts "This is the doc id of already registered simple allele #{docid}"
   # get the uri of new resource where  put request will be made
   uri = "#{config.simpleAllele_path}/doc/#{CGI.escape(docid)}"
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

   $stderr.puts "Sending put request for allele"

   apic = apiCaller
   apic.setRsrcPath(uri.path)

   apic.put(self.allele_hash.to_json)

   if apic.succeeded? == true
    $stderr.puts "The put request is suceeded, your allele is now registered"
    $stderr.puts "Here goes your document"
    apic.parseRespBody()
    resp_json = apic.apiRespObj
    $stderr.puts JSON::pretty_generate resp_json
    $stderr.puts "Document concluded"
   else
    apic.parseRespBody()
    resp_json = apic.apiRespObj
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Put request of simple allele failed: Log followed #{resp_json}}")
   end

 end
end
