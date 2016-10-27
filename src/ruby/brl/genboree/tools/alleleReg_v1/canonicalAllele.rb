class Identifier
 # default constructor
 attr_accessor  :use, :label, :system, :value
 def initialize(use="official",label=nil,system=nil,value=nil)
    @use,@label,@system,@value=
      use,label,system,value
 end
 def to_hash
      temp_hash = {"identifier" =>
                    {
                   "value" => "ID"+("%012d" % rand(1000000000000)).to_s,
                   "properties" => {
                     "use" =>    { "value" => @use},
                     "label" =>  { "value" => @label},
                     "system" => { "value" => @system},
                     "value" =>  { "value" => @value}
                    }
                   }
                  }
      return temp_hash
 end
end

class Replacement
 attr_accessor :replacementType, :split, :target
 def initialize(in_hash)
  @replacementType = in_hash["replacementType"] ||= nil
  @split           = in_hash["split"] ||= nil
  @target          = in_hash["target"] ||= nil
 end
 def to_hash
  return {
      "replacement" => {
        "value" => "RP"+("%012d" % rand(1000000000000)).to_s,
        "properties" => {
          "replacementType"  => {"value" => @replacementType},
          "split"            => {"value" => @split},
          "target"           => {"value" => @target}
        }
      }
  }
  #abc = ""
 end
end

class RelatedSimpleAllele
 attr_accessor :simpleAllele,  :preferred
 def initialize in_hash
  @simpleAllele = in_hash["simpleAllele"]
  @preferred 	= in_hash["preferred"] ||= "true"
 end
 def to_hash
  return {
     "relatedSimpleAllele" => {
       "value" => "RSA"+("%012d" % rand(1000000000000)).to_s,
       "properties" => {
        "simpleAllele" => {"value" => @simpleAllele},
        "preferred" => {"value" => @preferred}
       }
     }
  }
 end
end

class Nested
 attr_accessor :nested
 def initialize in_hash
   @nested = in_hash["nested"]
 end
 def to_hash
   return {
         "nested" => {
           "value" => @nested
        }
   }
 end
end

class CanonicalAllele
 attr_accessor  :CanonicalAllele, :Subject, :version
 attr_accessor  :active, :canonicalAlleleType
 attr_accessor  :comlexity
 attr_accessor  :composite
 attr_accessor  :identifiers,:relatedIdentifiers,:RelatedSimpleAlleles
 attr_accessor  :nests, :replacements
 attr_accessor  :ca_hash

 def initialize(in_hash)
  @CanonicalAllele       = in_hash["CanonicalAllele"]
  @Subject              = in_hash["Subject"]
  @version              = in_hash["version"]  ||= 1.to_s
  @active               = in_hash["active"] ||= true
  @canonicalAlleleType  = in_hash["canonicalAlleleType"]
  @complexity           = in_hash["complexity"] ||= "simple"
  @composite            = in_hash["composite"] ||= nil
  @identifiers          = in_hash["identifiers"]  ||= nil
  @relatedIdentifiers   = in_hash["relatedIdentifiers"] ||= []
  @RelatedSimpleAlleles = in_hash["RelatedSimpleAlleles"] ||= []
  @nests                = in_hash["nests"] ||= []
  @replacements         = in_hash["replacements"] ||= []
 end
 def to_hash
  return{
    "CanonicalAllele" => {
       "value" =>  @CanonicalAllele,
       "properties" => {
         "Subject" => {
           "value" => @Subject,
           "properties" => {
              "version" => {"value" => @version},
              "active" => {"value" => @active},
              "canonicalAlleleType" => {"value" => @canonicalAlleleType},
              "complexity" => {"value" => @complexity},
              "composite" => {"value" => @composite},
              "identifiers" => {"value" => nil , "items" => @identifiers},
              "relatedIdentifiers" => {"value" => nil, "items" => @relatedIdentifiers},
              "relatedSimpleAlleles" => {"value" => nil,"items" => @RelatedSimpleAlleles},
              "nests" => {"items" => @nests},
              "replacements" => {"items" => @replacements},
           }
         }
       }
    }
  }
 end
 #def register_canonical_allele config,apiCaller
 #  $stderr.puts "In register_canonical_allele method of class CanonicalAllele"
 #  $stderr.puts "Cleaning canonical allele hash before sending put request"
 #  temp_hash = self.to_hash
 #  genbkb_hash_delete_null temp_hash
 #  follow_genbkb_hash_delete_null temp_hash
 #  self.ca_hash = temp_hash


 #  uri = "#{config.canonicalAllele_path}/doc/#{CGI.escape(self.CanonicalAllele)}"
 #  uri = URI.parse(uri)

 #  $stderr.puts "Here goes the uri to send put request"
 #  $stderr.puts uri.to_s

 #  # first see if the document id is already taken
 #  $stderr.puts "Before sending put request making sure that there is nothing already there"
 #  apic = apiCaller
 #  apic.setRsrcPath(uri.path)
 #  #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path,hostauthmap)
 #  #apic.initInternalRequest($rackEnv, $domainAlias)
 #  apic.get
 #  apic.parseRespBody()
 #  resp_json = apic.apiRespObj

 #  if resp_json["status"]["msg"] == "OK" and resp_json["data"] != 0
 #    raise "The document id is already been taken,change document id and try again"
 #  end
 #  $stderr.puts "The uri to put new canonical allele looks available, sending put request"

 #  # now send put request!
 #  apic = apiCaller
 #  apic.setRsrcPath(uri.path)
 #  #apic = BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path,hostauthmap)
 #  #apic.initInternalRequest($rackEnv, $domainAlias)
 #  apic.put(self.ca_hash.to_json)

 #  #puts JSON::pretty_generate self.ca_hash
 #  #puts apic.inspect

 #  if apic.succeeded? == true
 #   $stderr.puts "The put request is suceeded, your canonical allele is now registered"
 #   $stderr.puts "Here goes your document"
 #   apic.parseRespBody()
 #   resp_json = apic.apiRespObj
 #   $stderr.puts JSON::pretty_generate resp_json
 #   return uri.to_s
 #  else
 #   raise "The API put request for canonical allele did not get through the log is given #{JSON::pretty_generate resp_json}"
 #  end

 #end
end
