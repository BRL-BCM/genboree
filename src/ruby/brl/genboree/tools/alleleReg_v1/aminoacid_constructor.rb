class Allele
 def self.aminoacid_constructor(back,type,nature,intron,utr5,
                              utr3,allele_hgvs,allele_name_type,aminoacidChangeType,config,apiCaller)

    if back["start"].nil? 
        new(back["refseq"],
            back["end"].to_i - 1,
            back["end"].to_i,
            back["ref"],
            back["alt"],
            type,
            nil,
            nil,
            nil,
            nil,
            0,
            0,
            nil,
            nil,
            nil,
            allele_hgvs,
            nil,
            allele_name_type,aminoacidChangeType,config,apiCaller,nil,nil)

    elsif ! back["start"].nil? and ! back["end"].nil?
        if aminoacidChangeType == "SO:0001823^conservative_inframe_insertion"
         back["start"] = back["start"].to_i + 1
         back["end"]   = back["end"].to_i - 1
        end
        new(back["refseq"],
            back["start"].to_i - 1,
            back["end"].to_i,
            back["ref"],
            back["alt"],type,nil,nil,nil,nil,
            0,0,nil,
            nil,nil,
            allele_hgvs,nil,allele_name_type,aminoacidChangeType,config,apiCaller,nil,nil)
        
    else
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Failed to initialize given allele")
    end
 end
end
