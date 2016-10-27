def refseqToURI id_value, refseq_path, apiCaller

  props=["ReferenceSequence.Subject.identifiers.[].identifier.value"]
  vals=CGI.escape(id_value)

  uri = URI.parse("#{refseq_path}/docs?matchProps=#{CGI.escape(props.join(","))}&matchValue=#{vals}&detailed=false")

  apic = apiCaller
  apic.setRsrcPath(uri.path+"?"+uri.query)
  #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
  #apic.initInternalRequest($rackEnv, $domainAlias)
  apic.get
  apic.parseRespBody()
  resp_json = apic.apiRespObj

  if resp_json["status"]["msg"] != "OK"
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"API call failed. The received response goes here #{resp_json.to_json}")
  elsif
    resp_json["data"].size == 0
    raise BRL::Genboree::GenboreeError.new(:'Not Found',"The reference sequence with respect to which allele is defined is not registered in the database so far")
  elsif
    resp_json["data"].size > 1
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"More than one document matches, please arrange for resolution. See the response here #{resp_json.to_json}")
  else
    docid = resp_json["data"][0]["ReferenceSequence"]["value"]
    uri = URI.parse("#{refseq_path}/doc/#{CGI.escape(docid)}?detailed=true")
    apic = apiCaller
    apic.setRsrcPath(uri.path+"?"+uri.query)
    #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
    apic.get
    apic.parseRespBody()
    resp_json = apic.apiRespObj
    return resp_json["data"]["ReferenceSequence"]["properties"]["Subject"]["value"]
  end

end
