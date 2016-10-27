class Allele
 def update_ca_uri_using_simple_allele_uri registered_simple_allele_uri,config,apiCaller
  $stderr.puts "Updating canonical allele URI in simple allele using already registered simple allele"

  $stderr.puts registered_simple_allele_uri

  $stderr.puts "Sending get request to canonical allele property"
  uri = "#{config.simpleAllele_path}/doc/#{registered_simple_allele_uri}/prop/SimpleAllele.Subject.canonicalAllele"
  uri = URI.parse(uri)
  apic = apiCaller
  apic.setRsrcPath(uri.path)
  apic.get

  if apic.succeeded?
   $stderr.puts "API call to get canonical uri of already registered allele succeeded"
    apic.parseRespBody()
    response_json = apic.apiRespObj
   self.canonicalAllele = response_json["data"]["value"]
  else
   $stderr.puts uri.to_s
   raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Cannot get the document to get canoncial allele URI")
  end

 end
end
