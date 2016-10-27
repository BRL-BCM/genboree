class Allele
 def check_reg_status config, apiCaller
   $stderr.puts "Checking the registration status of parsed allele"
  # run first query where only allele names are matched
   props=["SimpleAllele.Subject.alleleNames.[].alleleName"]
   uri = "#{config.simpleAllele_path}/docs?matchProps=#{CGI.escape(props.join(","))}&matchValue=#{CGI.escape(self.allele_hgvs)}&detailed=false"
   uri = URI.parse(uri)
   $stderr.puts "This is the First query uri #{uri.to_s}"
   apic = apiCaller
   #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
   apic.setRsrcPath(uri.path+"?"+uri.query)
   apic.get
   apic.parseRespBody()
   resp_json = apic.apiRespObj

   $stderr.puts "First query results goes here:"
   $stderr.puts JSON::pretty_generate resp_json
   $stderr.puts "First query results end here:"

   if resp_json["status"]["msg"] != "OK"
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"API call failed. The received response goes here #{resp_json.to_json}")
   elsif resp_json["data"].size > 1
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Query 1 Response => More than one document matches, please arrange for resolution, this should not happen ideally")
   elsif resp_json["data"].size == 1
     $stderr.puts "Query 1 response look normal and found one registered allele"
     docid = resp_json["data"][0]["SimpleAllele"]["value"]
     uri = "#{config.simpleAllele_path}/doc/#{CGI.escape(docid)}?detailed=true"
     uri = URI.parse(uri)
     apic = apiCaller
     apic.setRsrcPath(uri.path+"?"+uri.query)
     #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
     #apic.initInternalRequest($rackEnv, $domainAlias)
     apic.get
      apic.parseRespBody()
      resp_json_2 = apic.apiRespObj
     $stderr.puts "Returning value to calling function with answer = true and document id of found simple allele"
     return answer=true,uri=resp_json_2["data"]["SimpleAllele"]["value"]
   else
     $stderr.puts "First query retrieved no results, meaning, the simple allele is not registered, but to make sure a second query will be run"
   end
   # if protein allele then don't go to second query just send the response back
   #puts self.refSeqType
   if self.refSeqType != "amino acid" and self.alternateAllele.nil? == false and self.intronic == "FALSE"
     $stderr.puts "Currently the second query is only for genomic/transcript alelle"
     #  If reached so far then run another query
     props=["SimpleAllele.Subject.simpleAlleleType","SimpleAllele.Subject.allele","SimpleAllele.Subject.primaryNucleotideChangeType","SimpleAllele.Subject.referenceCoordinate.referenceSequence","SimpleAllele.Subject.referenceCoordinate.start","SimpleAllele.Subject.referenceCoordinate.end"]
     # puts self.refSeqType,self.alternateAllele,self.mutationType,self.refSeqURI,self.alleleStart,self.alleleEnd
     vals=[self.refSeqType,self.alternateAllele,self.mutationType,self.refSeqURI,self.alleleStart.to_i,self.alleleEnd.to_i]

     queryName="SAQuery2"

     uri = "#{config.simpleAllele_path}/docs?matchQuery=#{CGI.escape(queryName)}&propPaths=#{CGI.escape(props.join(","))}&propValues=#{CGI.escape(vals.join(","))}&detailed=false"

     uri = URI.parse(uri)
     $stderr.puts "This is the uri of query to be sent:"
     $stderr.puts uri.to_s
     apic = apiCaller
     apic.setRsrcPath(uri.path+"?"+uri.query)
     #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
     #apic.initInternalRequest($rackEnv, $domainAlias)
     apic.get
     apic.parseRespBody()
     resp_json = apic.apiRespObj
     $stderr.puts "The query response goes below:"
     $stderr.puts JSON::pretty_generate resp_json
     $stderr.puts "The query response ends here"
     $stderr.puts "$$$$$$$$$$$$$$$$$$$$$$$"

     if resp_json["status"]["msg"] != "OK"
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"API call failed. The received response goes here #{resp_json.to_json}")
     elsif
       resp_json["data"].size > 1
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Query 2: response => More than one document matches, please arrange for resolution, this should not happen ideally")
     elsif
       $stderr.puts "Match found with second query:"
       resp_json["data"].size == 1
       docid = resp_json["data"][0]["SimpleAllele"]["value"]
       uri = "#{config.simpleAllele_path}/doc/#{CGI.escape(docid)}?detailed=true"
       uri = URI.parse(uri)
       apic = apiCaller
       apic.setRsrcPath(uri.path+"?"+uri.query)
       #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
       #apic.initInternalRequest($rackEnv, $domainAlias)
       apic.get
        apic.parseRespBody()
        resp_json_2 = apic.apiRespObj
       $stderr.puts "returning answer = true to the calling function with document id of new simple allele:"
       return answer=true,uri=resp_json_2["data"]["SimpleAllele"]["value"]
     end
   end
   $stderr.puts "returning answer = false to the calling function with doc_id = nil"
   return answer=false,uri=nil
 end
end
