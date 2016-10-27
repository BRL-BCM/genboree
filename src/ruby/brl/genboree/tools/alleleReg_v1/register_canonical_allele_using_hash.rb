def register_canonical_allele_using_hash(in_hash,config, apiCaller)

   docid = in_hash["CanonicalAllele"]["value"]

   uri = "#{config.canonicalAllele_path}/doc/#{CGI.escape(docid)}"
   uri = URI.parse(uri)

   # first see if the document id is already taken
   apic = apiCaller
   apic.setRsrcPath(uri.path)
   apic.put(in_hash.to_json)

   if apic.succeeded? == true
    $stderr.puts "The put request for canonical allele from hash succeded"
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
