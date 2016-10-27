def get_document_id url,apiCaller

 uri = URI.parse(url+"?amount=1")
 apic = apiCaller
 apic.setRsrcPath(uri.path+"?"+uri.query)
 apic.put

 if apic.succeeded? 
  apic.parseRespBody()
  resp_json = apic.apiRespObj
  return resp_json["data"][0]["autoID"]["value"]
 else 
  raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"When trying to reserve document ids using #{uri.to_s}, the apicaller failed")
 end

end
