class TheRegistrar

 attr_accessor :config
 attr_accessor :decoder
 attr_accessor :apiCaller
 
 def initialize config,decoder,apiCaller
     @config,@decoder,@apiCaller, = config,decoder,apiCaller
 end

 def match_hgvs_to_pattern hgvs_in, var_ins, pat_ins
  
  pat_ins_pat = Regexp.new(pat_ins) 
  succeded = true
  temp_parsed = hgvs_in.match(pat_ins_pat).captures rescue succeded = false
  if succeded == true
   temp_a = Hash.new()
   abc = var_ins.split(",")
   (0...abc.size).each do |j|
     temp_a[abc[j]] = temp_parsed[j]
   end
   return succeded,temp_a 
  else
   return succeded,nil
  end
 end

 def parseHGVS(hgvs)
    # inside parse HGVS
    # code to generate key arrays required to parse hgvs
    # the decoder data is parsed for uniform structure
    vars   = Array.new()
    pats   = Array.new()
    type   = Array.new()
    nature = Array.new()
    intron = Array.new()
    utr5   = Array.new()
    utr3   = Array.new()
    allele_name_type = Array.new()
    aa_change_type = Array.new()

    total = @decoder["id"]["properties"]["Decoders"]["value"]
    
    $stderr.puts "Start generating arrays from the hash for #{total} patterns"

    (0...total).each do |i|
      $stderr.puts "generating array for patterns #{i}"
      given = @decoder["id"]["properties"]["Decoders"]["items"][i]["Decoder"] 
      vars   << given["properties"]["variables"]["value"]
      pats   << given["properties"]["patterns"]["value"]
      type   << given["properties"]["type"]["value"]
      nature << given["properties"]["nature"]["value"]
      intron << given["properties"]["intron"]["value"]
      utr5   << given["properties"]["5UTR"]["value"]
      utr3   << given["properties"]["3UTR"]["value"]
      allele_name_type << given["properties"]["nameType"]["value"]
      aa_change_type << given["properties"]["aminoacidChangeType"]["value"]
    end

    # Arrays are ready to match
    # send this arrays and hgvs to find the matching ones
    found,back,mtype,mnature,mintron,mutr5,mutr3,mhgvs,mallele_name_type,maa_change_type = 
        match_hgvs_to_all_patterns(hgvs,vars,pats,type,nature,intron,utr5,utr3,allele_name_type,aa_change_type)

    # if match is found then,
    if found == true
         
          if mtype == "transcript"
              out = Allele.generic_constructor(back,mtype,mnature,mintron,mutr5,mutr3,mhgvs,mallele_name_type,nil,@config,@apiCaller)
              # is the allele registered?
              status,registered_simple_allele_uri = out.check_reg_status(@config,@apiCaller)
              # convert transcript allele to genomic allele
              t2genomic_hgvs = out.get_genomic_allele
              # put log
              $stderr.puts "The genomic allele is here #{t2genomic_hgvs}"
              # parse genomice allele
              t2g_found,t2g_back,t2g_type,t2g_nature,t2g_intron,t2g_utr5,t2g_utr3,t2g_hgvs,t2g_allele_name_type,t2g_aa_change_type = match_hgvs_to_all_patterns(t2genomic_hgvs,vars,pats,type,nature,intron,utr5,utr3,allele_name_type,aa_change_type)

              # if the genomic allele is parsed
                if t2g_found == true
                   t2g_out = Allele.genomic_constructor(t2g_back,t2g_type,t2g_nature,t2g_intron,t2g_utr5,t2g_utr3,t2g_hgvs,t2g_allele_name_type,nil,@config,@apiCaller) 
                else
                   raise BRL::Genboree::GenboreeError.new(:'Bad Request',"The genomic allele, represented as #{t2genomic_hgvs} generated from transcript allele #{hgvs} could not be parsed with HGVS decoder")
                end

              # Is the genomic allele registered?
              t2g_status, t2g_registered_simple_allele_uri = t2g_out.check_reg_status(@config,@apiCaller)
    
              # put log
              $stderr.puts "The transcript allele is registered? ans = #{status}. The genomic allele registered? ans = #{t2g_status}"
    
              # ... The decision process starts here ... #

              # operate differently using status and t2g_status
              if status == true and t2g_status == true
                  # This will happen when both the transcript and genomic allele is registered
                  # Update the canonical allele uri of current simple allele using matched simple allele
                  out.update_ca_uri_using_simple_allele_uri(registered_simple_allele_uri,@config,@apiCaller)
                  # Return that canonical allele uri
                  return out.canonicalAllele
              elsif status == true and t2g_status == false
                  # Ending up here means the transcript is registered by not genomic allele
                  # If all the register go throug this pipeline then this should not happen
                  # raise an error if it happens
                  raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"This ideally should not happen. The transcript allele is registred by genomic allele is not registered. Please contact the administrator.")
              elsif status == false and t2g_status == true
                  # you will end up here if the transcript allele is not registered but generated genomic allele is
                  $stderr.puts "simple allele not registered but canonical allele is"
                  # get the canonical allele uri using t2g_registered_uri
                  # assign it to the simple allele properties
                  # register simple allele
                  # change the uri of new simple allele to existing canonical allele uri
                  $stderr.puts "calling update_ca_uri_using_simple_allele_uri"
                  # first of all take the canonical allele uri from registered transcript allele and update transcript allele
                  # now the canonical allele of transcript simple allele has already registered canonnical allele uri
                  out.update_ca_uri_using_simple_allele_uri(t2g_registered_simple_allele_uri,@config,@apiCaller)
                  # please register simple allele
                  $stderr.puts "registering transcript simple allele"
                  out.register_simple_allele(@config, @apiCaller)
                  # log
                  $stderr.puts "Updating canonical allele document to include the new simple allele"
                  # now get the registered canonical allele hash updat for the present transcript simple allele
                  updated_hash = out.ca_from_api_call(@config, @apiCaller)
                  # now that the updated hash is available, send the updated canonical allele back to KB
                  register_canonical_allele_using_hash(updated_hash, @config, @apiCaller)
                  # finally, return the uri of canonical allele
                  return out.canonicalAllele 
              elsif status == false and t2g_status == false
                  # If neither the transcript not genomic allele is registered
                  $stderr.puts "generating canonical allele"
                  # generate canonical alle document using genomic allele URI
                  t2g_out.generate_canonical_allele
                  # canonical_allele_instance becomes available now
                  # log
                  $stderr.puts "printing canonical allele"
                  $stderr.puts "printing subject of another simple allele"
                  $stderr.puts out.subject
                  # add transcript allele to related simple alleles of canonical allele
                  t2g_out.canonical_allele_instance.add_related_simple_allele(out.subject,"false")
                  $stderr.puts "Added related simple allele"
                  # register canonical allele
                  t2g_out.register_canonical_allele(@config,@apiCaller)
                  # update simple alleles for this canonical allele uri
                  out.update_ca_uri_using_uri(t2g_out.canonical_allele_instance.Subject) 
                  t2g_out.update_ca_uri_using_uri(t2g_out.canonical_allele_instance.Subject)
                  # register simple alleles
                  out.register_simple_allele(@config,@apiCaller)
                  t2g_out.register_simple_allele(@config,@apiCaller)
                  # log
                  $stderr.puts JSON.pretty_generate out.generate_hash
                  $stderr.puts JSON.pretty_generate t2g_out.generate_hash
                  $stderr.puts JSON.pretty_generate t2g_out.canonical_allele_instance.to_hash
                  $stderr.puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                  return out.canonicalAllele 
              else
                  raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Could not identifiy current registered status of allele")
              end
          elsif mtype == "genomic"
              # generate genomic allele
              out = Allele.genomic_constructor(back,mtype,mnature,mintron,mutr5,mutr3,mhgvs,mallele_name_type,nil,@config,@apiCaller) 
              # check the registration status of genomic allele
              status,registered_uri = out.check_reg_status(@config,@apiCaller)
              # if already registered then get canonical uri of registered allele and send  back
              # if status = false then register simple allele 
              # and canonical allele
              if status == false
                 # generate canonical alle document
                 out.generate_canonical_allele
                 # registere canonical allel
                 out.register_canonical_allele(@config,@apiCaller)
                 # update canonical allele uri in genomic simple allele
                 out.update_ca_uri_using_uri(out.canonical_allele_instance.Subject)
                 # Register simple allele
                 out.register_simple_allele(@config, @apiCaller)
                 return  out.canonicalAllele
              else 
                 # get canonical uri of registered allele
                 # update the canonical allele 
                 out.update_ca_uri_using_simple_allele_uri(registered_uri,@config,@apiCaller)
                 # send it back
                 return out.canonicalAllele 
              end
          #elsif type[i] == "amino-acid"
          elsif mtype == "amino-acid"
                 # if amino acid found
                 mtype = "amino acid"
                 # generate amino acid allele
                 out = Allele.aminoacid_constructor(back,mtype,mnature,mintron,mutr5,mutr3,mhgvs,mallele_name_type,maa_change_type,@config,@apiCaller)
                 # just register it
                 status,registered_uri = out.check_reg_status(@config,@apiCaller)
                 if status == false
                   out.generate_canonical_allele
                   out.register_canonical_allele(@config,@apiCaller)
                   out.update_ca_uri_using_uri(out.canonical_allele_instance.Subject)
                   out.register_simple_allele(@config, @apiCaller)
                 end
                 if status == true
                   out.update_ca_uri_using_simple_allele_uri(registered_uri,@config,@apiCaller)
                 end
                 #out.register_allele(status, registered_uri, @config, @apiCaller)
                 return out.canonicalAllele 
    
          else
                 raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Type of allele #{type[i]} is not recognized #{hgvs}")
          end
    
    else
    raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Failed to generate simple allele for #{hgvs}. This might be mostly because I  don't know how to extract information from this string. It whould be best to include that information in HGVS decoder")
   end
 end
end
