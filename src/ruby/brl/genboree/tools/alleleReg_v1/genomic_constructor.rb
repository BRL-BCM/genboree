#load 'class_allele.rb'

class Allele  
 def self.genomic_constructor(back,type,nature,intron,utr5,
                              utr3,allele_hgvs,allele_name_type,aa_change_type,config,apiCaller)

    # see if intron utr5 and utr3 is not true because that is not possible for genmoic allele
    if back["start"].nil? 
        new(back["refseq"],
            back["end"].to_i - 1,
            back["end"].to_i,
            back["ref"],
            back["alt"],
            type,
            nature,
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
            allele_name_type,nil,config,apiCaller,nil,nil)

    elsif ! back["start"].nil? and ! back["end"].nil?
        if nature == "SO:0000667^insertion"
         back["start"] = back["start"].to_i + 1
         back["end"]   = back["end"].to_i - 1
        end
        new(back["refseq"],
            back["start"].to_i - 1,
            back["end"].to_i,
            back["ref"],
            back["alt"],type,nature,nil,nil,nil,
            0,0,nil,
            nil,nil,
            allele_hgvs,nil,allele_name_type,nil,config,apiCaller,nil,nil)
        
    else
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Failed to initialize given allele")
    end
 end
end
