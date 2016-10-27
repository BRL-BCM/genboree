### This is a method to create hash for simple allele
class Allele
 def generate_hash #out
     #generate identifiers
     $stderr.puts "Generating identifier properties"
     identifiers = Array.new()
     identifiers[0] = {
                  "identifier" => {
                   "value" => nil,
                   "properties" => {
                      "system" =>
                         {"value" => "http://reg.genome.network/allele/"},
                      "value"  =>
                         {"value" => self.doc_id},
                      "label"  =>
                         {"value" => self.allele_hgvs}
                   }
                  }
                }
 
     refseqcoord_identifiers = Array.new()

     #refseqcoord_identifiers[0] = {
     #             "identifier" => {
     #              "value" => nil,
     #              "properties" => {
     #                 "system" =>
     #                    {"value" => "http://dummyurl"},
     #                 "value"  =>
     #                    {"value" => "dummy"},
     #                 "label"  =>
     #                    {"value" => "dummy"}
     #              }
     #             }
     #           }
 
     $stderr.puts "Generating allelename hash"
     #simpleAlleleType 
     tempalleleName = Array.new()
     tempalleleName[0] = Hash.new()
     tempalleleName[0] = { 
                           "alleleName" => {
                             "value" => self.allele_hgvs,
                             "properties" => {
                                  "nameType" => {"value" => self.alleleNameType},
                                  "preferred" => {"value" => "true"}
                             }
                           }
                         }
 
     $stderr.puts "creating return_hash"
     return_hash = {"SimpleAllele" => {
                     "value" => self.doc_id,
                     "properties" => {
                      "Subject" => {
                       "value" => self.subject,
                       "properties" => 
                       {
                         "identifiers" => {"items" => identifiers},
                         "simpleAlleleType" => {"value" => self.refSeqType},
                         "canonicalAllele" => {"value" => self.canonicalAllele},
                         "allele" => {"value" => self.alternateAllele},
                         "primaryNucleotideChangeType" => {"value" => self.mutationType } ,
                         "primaryAminoAcidChangeType" => {"value" => self.aminoacidChangeType } ,
                         "alleleNames" => { "items" => tempalleleName },
                         "referenceCoordinate" => 
                           { "value" => nil,
                             "properties" => {
                              "identifiers" => {"items" => refseqcoord_identifiers },
                              "referenceSequence" => {"value" => self.refSeqURI},
                              "start" => {"value" => self.alleleStart},
                              "end" => {"value" => self.alleleEnd},
                              "refAllele" => {"value" => self.referenceAllele}
                             }
                            }
                       }
                     }
                     }
                   }
              }
       
 
      return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"] = Hash.new()
      $stderr.puts "creating other properties"
      if self.intronic == "TRUE"
         #return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = "SO:0000191^interior_intron" 
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetStart"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetStart"]["value"] = self.startOffset.abs
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetEnd"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetEnd"]["value"] = self.endOffset.abs
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetDirection"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetDirection"]["value"] = self.offsetDirection
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["referenceSequence"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["referenceSequence"]["value"] = self.referenceGenomic
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["start"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["start"]["value"] = self.startGenomic
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["end"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["end"]["value"] = self.endGenomic
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["refAllele"] = Hash.new()
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["intronOffsetGenomicCoordinate"]["properties"]["refAllele"]["value"] = self.referenceAllele
      elsif self.fiveUTR == "TRUE"
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = "SO:0000204^five_prime_UTR"
      elsif self.threeUTR == "TRUE"
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = "SO:0000205^three_prime_UTR"
      elsif self.refSeqType == "genomic"
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = nil
      elsif self.refSeqType == "amino acid"
         return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = nil
      else return_hash["SimpleAllele"]["properties"]["Subject"]["properties"]["referenceCoordinate"]["properties"]["primaryTranscriptRegionType"]["value"] = "SO:0000316^CDS"
      end
    
     @allele_hash = return_hash
 
     #return return_hash
 end
end
