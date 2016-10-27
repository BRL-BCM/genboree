#env /usr/bin/ruby

#require 'digest/sha1'
#require 'rubygems'
#require 'highline/import'
#require 'net/http'
#require 'json'
#load './token_builder.rb'
#load '../general_utilities/myclasses.rb'

# This file constitutes important function to give API call for reference sequence

def get_refseqali_from_genbkb refSeq,config,apiCaller

 config.refSeqGenomeAli_path
 #kbName   ="alleleModels3"
 #grpName  ="myScratchForGenbreeKB"
 #collName ="RefSeqGenomeAli_0.4"
 ## THE FOLLOWING HARD CODED VARIABLE MAKES API CALL OF REF SEQ FOR GRCH38
 ## IF YOU WANT IT TO WORK TO GET GRCH37 COORDINATE YOU WILL HAVE TO THINK MORE
 ## THIS IS AN ABSOLUTE FIX
 doc      =refSeq+"-grch38"
 uri = "#{config.refSeqGenomeAli_path}/doc/#{doc}?detailed=true"
 uri = URI.parse(uri)
 apic = apiCaller
 apic.setRsrcPath(uri.path+"?"+uri.query)
 #BRL::Genboree::REST::ApiCaller.new(uri.host,uri.path+"?"+uri.query,hostauthmap)
 #apic.initInternalRequest($rackEnv, $domainAlias)
 apic.get
  apic.parseRespBody()
  resp_json = apic.apiRespObj

 if resp_json["status"]["msg"] != "OK"
  raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Reference #{refSeq} Sequence API call failed.")
 end

 return(resp_json)
end

def refseq_json_to_array json_in
  cdsStart = json_in["data"]["id"]["properties"]["Subject"]["properties"]["cdsStart"]["value"]
  cdsEnd =   json_in["data"]["id"]["properties"]["Subject"]["properties"]["cdsEnd"]["value"]
  sequence = json_in["data"]["id"]["properties"]["Subject"]["properties"]["transcriptSequence"]["value"]
  aligned_to = json_in["data"]["id"]["properties"]["Subject"]["properties"]["reference"]["value"]
  align = []
  temp = 1
  (0...json_in["data"]["id"]["properties"]["Subject"]["properties"]["exons"]["value"]).each do |i|
    estart = json_in["data"]["id"]["properties"]["Subject"]["properties"]["exons"]["items"][i]["exon"]["properties"]["referenceStart"]["value"]
    eend   = json_in["data"]["id"]["properties"]["Subject"]["properties"]["exons"]["items"][i]["exon"]["properties"]["referenceEnd"]["value"]
    tstart =  json_in["data"]["id"]["properties"]["Subject"]["properties"]["exons"]["items"][i]["exon"]["properties"]["transcriptStart"]["value"]
    tend   = json_in["data"]["id"]["properties"]["Subject"]["properties"]["exons"]["items"][i]["exon"]["properties"]["transcriptEnd"]["value"]
    one = tstart
    two =  tend
    three = estart
    four = eend
    if json_in["data"]["id"]["properties"]["Subject"]["properties"]["strand"]["value"] == "-"
     align.push([one - 1, two, four, three - 1])
    elsif  json_in["data"]["id"]["properties"]["Subject"]["properties"]["strand"]["value"] == "+"
     align.push([one - 1, two, three - 1, four])
    else
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"The strand of the reference sequence is not identified")
    end

  end
  #puts align,cdsStart,cdsEnd,sequence and reference sequence
  return align,cdsStart,cdsEnd,sequence,aligned_to
end
