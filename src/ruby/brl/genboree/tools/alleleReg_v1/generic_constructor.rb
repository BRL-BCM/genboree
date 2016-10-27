# generic constructor for transcripts
class Allele
 def self.generic_constructor(back,type,nature,intron,utr5,utr3,allele_hgvs,allele_name_type,aa_change_type,config,apiCaller)

    if back["start"].nil? 
      # if start is not defined then 
      # get absolute position in transcript using only end
      # give API call to reference sequence
      required_info_json = get_refseqali_from_genbkb back["refseq"],config,apiCaller
      # puts required_info_json
      # convert json to array
      align, cds_start, cds_end, sequence, aligned_to = refseq_json_to_array required_info_json
      aligned_to_uri = refseqToURI(aligned_to,config.refSeq_path,apiCaller)
      #puts align,cds_start,cds_end,sequence
      #puts align
      # normalize position
      genomic_position, genomic_complementary, back["end"], intron_offset = hgvs_cdna(back["end"].to_s, cds_start - 1, cds_end, align)
      # assign alignment orientation
      # now that end and offset and genomic coordinate of end is known then 
      # call the constructor
      # but before that try to get start, 
      # start offset and  start genomic coordinates
      # If offset is zero
      # assuming that genomic and transcript position back from function is not using any logic
      if intron_offset == 0 
        new(back["refseq"],
            back["end"].to_i,
            back["end"].to_i + 1,
            back["ref"],
            back["alt"],type,nature,intron,utr5,utr3,
            0,0,nil,genomic_position,genomic_position + 1,allele_hgvs,nil,allele_name_type,nil,config,apiCaller,aligned_to,genomic_complementary)
      # when intron offset is not zero
      else 
        # if intron_offset != 0 
        # it means that you need to modify the start
        # and end of offset not the allele start and end
        offset_direction = "+"
        if intron_offset < 0  
         offset_direction = "-"
        end 
        new(back["refseq"],
            back["end"].to_i,
            back["end"].to_i,
            back["ref"],
            back["alt"],type,nature,intron,utr5,utr3,
            intron_offset - 1, intron_offset, offset_direction,
            genomic_position,genomic_position+1,allele_hgvs,aligned_to_uri,allele_name_type,nil,config,apiCaller,aligned_to,genomic_complementary)
      end
      #...........#
    elsif ! back["start"].nil? and ! back["end"].nil?
      # convert start and end in to absolute position
      # give API call to reference sequence
      required_info_json = get_refseqali_from_genbkb back["refseq"],config,apiCaller
      # convert json to array
      align, cds_start, cds_end, sequence, aligned_to = refseq_json_to_array required_info_json
      aligned_to_uri = refseqToURI(aligned_to,config.refSeq_path,apiCaller)
      #puts align,cds_start,cds_end,sequence
      #puts align
      # normalize start of allele
      genomic_start, genomic_complementary, back["start"] , intron_start_offset = hgvs_cdna(back["start"], cds_start - 1, cds_end, align)
      # as start is defined it is 1 based
      # so good to pass to hgvs_cds with -1
      #puts back["start"]

      # set the intron offset direction
      start_offset_direction = "+"
      if intron_start_offset < 0
         start_offset_direction = "-"
      elsif intron_start_offset == 0
         # If not an intron
         #back["start"] = back["start"] - 1
         #genomic_start = genomic_start - 1
         start_offset_direction = nil
      end

      # normalize end of allele
      genomic_end  , genomic_complementary, back["end"]   , intron_end_offset   = hgvs_cdna(back["end"].to_s,cds_start - 1, cds_end, align)
      # set the intron offset direction
      end_offset_direction = "+"
      if intron_end_offset < 0
         end_offset_direction = "-"
      elsif intron_end_offset == 0 
         end_offset_direction = nil
      end
      if start_offset_direction !=  end_offset_direction
         raise BRL::Genboree::GenboreeError.new(:'Not Implemented', "Registering complex alleles where the start and end spans different genomic regions are not supported")
      end


      # The genomic start here can be higher number compared to genomic end when the alignment is to complementary strand, correct this
      if genomic_end < genomic_start
          abs_temp = genomic_end
          genomic_end = genomic_start
          genomic_start = abs_temp
      end  

      # when insertion adjust the back and end by substracting 1 from end and adding 1 at the start
      if nature == "SO:0000667^insertion"
         # add one to start so that the exact position is reached
         back["start"] = back["start"].to_i + 1
         # The end is substracted by 2 as the general logic while constructing allele is to add 1
         back["end"]   = back["end"].to_i - 1
         # Also for genomic positions!
         genomic_start = genomic_start + 1
         genomic_end   = genomic_end   - 1
      end

      # if matches then set the offset direction as of start offset direction
      new(back["refseq"],
          back["start"].to_i,
          back["end"].to_i + 1,
          back["ref"],
          back["alt"],type,nature,intron,utr5,utr3,
          intron_start_offset,intron_end_offset,
          start_offset_direction,
          genomic_start, genomic_end + 1,allele_hgvs,aligned_to_uri,allele_name_type,nil,config,apiCaller,aligned_to,genomic_complementary)

    else
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Failed to initialize given allele")
    end
 end
end
