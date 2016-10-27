#env /usr/bin/ruby
#load '../hgvs_parser/refseq_apis.rb'
#load 'position_normalize.rb'

# A super class defines basic properties of allele
# Several classes are inherited from this 
class Allele 
 # default constructor
 attr_accessor :allele_hgvs,:refSeq,:alleleStart,:alleleEnd,
               :referenceAllele,:alternateAllele,
               :refSeqType,:mutationType,:intronic,
               :fiveUTR,:threeUTR,:pretty_print,
               :startOffset,:endOffset,:offsetDirection,
               :startGenomic,:endGenomic,:generate_hash,:referenceGenomic,
               :alleleNameType,:refSeqURI,:aminoacidChangeType,
               :config, :apiCaller, :allele_hash, :doc_id, :subject,
               :canonicalAllele,
               :referenceGenomicId, 
               :t2g_alignment_oritentation
 # initialize function
 def initialize(refSeq,alleleStart,alleleEnd,
                referenceAllele,alternateAllele,
                refSeqType,mutationType,intronic,
                fiveUTR,threeUTR,
                startOffset,endOffset,offsetDirection,
                startGenomic,endGenomic,alleleHGVS,referenceGenomic,allele_name_type,aminoacidChangeType,config,apiCaller,referenceGenomicId,t2g_alignment_oritentation)

    @allele_hgvs = alleleHGVS

    @refSeq,@alleleStart,@alleleEnd,
    @referenceAllele,@alternateAllele,
    @refSeqType,@mutationType,@intronic,
    @fiveUTR,@threeUTR,
    @startOffset,@endOffset,@offsetDirection,
    @startGenomic, @endGenomic, @referenceGenomic,@alleleNameType,
    @aminoacidChangeType,@config,@apiCaller, @referenceGenomicId= 
    refSeq,alleleStart,alleleEnd,
    referenceAllele,alternateAllele,
    refSeqType,mutationType,intronic,fiveUTR,threeUTR,
    startOffset,endOffset,offsetDirection,startGenomic,endGenomic,referenceGenomic,allele_name_type, aminoacidChangeType,config,apiCaller,referenceGenomicId

    @t2g_alignment_oritentation = t2g_alignment_oritentation

    #@doc_id  = "SA"+("%015d" % rand(1000000000000000)).to_s
    # get the docid here:
    @doc_id = get_document_id @config.simpleAllele_path+"/model/prop/SimpleAllele/autoIDs",@apiCaller

    @subject = "http://reg.genome.network/allele/"+@doc_id

    refsequri = refseqToURI(refSeq,@config.refSeq_path,@apiCaller)

    @refSeqURI = refsequri
end
end
