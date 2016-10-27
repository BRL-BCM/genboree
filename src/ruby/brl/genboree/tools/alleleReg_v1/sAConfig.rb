class SAConfig 
 attr_accessor :gene_path, 
                :refSeq_path, 
                :canonicalAllele_path, 
                :simpleAllele_path,
                :refSeqGenomeAli_path,
                :hgvsDecode_path

 def initialize in_hash
  @gene_path  = in_hash["data"]["SAConfig"]["properties"]["Gene"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["Gene"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["Gene"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["Gene"]["properties"]["Collection"]["value"]
  @refSeq_path  = in_hash["data"]["SAConfig"]["properties"]["ReferenceSequence"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["ReferenceSequence"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["ReferenceSequence"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["ReferenceSequence"]["properties"]["Collection"]["value"]
  @simpleAllele_path  = in_hash["data"]["SAConfig"]["properties"]["SimpleAllele"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["SimpleAllele"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["SimpleAllele"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["SimpleAllele"]["properties"]["Collection"]["value"]
  @canonicalAllele_path = in_hash["data"]["SAConfig"]["properties"]["CanonicalAllele"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["CanonicalAllele"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["CanonicalAllele"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["CanonicalAllele"]["properties"]["Collection"]["value"]
  @refSeqGenomeAli_path = in_hash["data"]["SAConfig"]["properties"]["RefSeqGenomeAli"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["RefSeqGenomeAli"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["RefSeqGenomeAli"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["RefSeqGenomeAli"]["properties"]["Collection"]["value"]
  @hgvsDecode_path = in_hash["data"]["SAConfig"]["properties"]["hgvsDecoderInput"]["properties"]["Host"]["value"]+"/REST/v1/grp/"+in_hash["data"]["SAConfig"]["properties"]["hgvsDecoderInput"]["properties"]["Group"]["value"]+"/kb/"+in_hash["data"]["SAConfig"]["properties"]["hgvsDecoderInput"]["properties"]["Kb"]["value"]+"/coll/"+in_hash["data"]["SAConfig"]["properties"]["hgvsDecoderInput"]["properties"]["Collection"]["value"]+"/doc/"+in_hash["data"]["SAConfig"]["properties"]["hgvsDecoderInput"]["properties"]["Doc"]["value"]

 end 
end
