#!/usr/bin/env ruby


# function to convert cDNA position in HGVS format to genomic & transcript position
# Parameters:
# hgvs_position - part of HGVS string with position, e.g: 78, -78, *78, 78+45, 79-45, *79-45 etc. (indexes in HGVS are 1-based)
# cds_start, cds_stop - first bp of CDS in transcript reference and first bp after the CDS, indexes are 0-based (0-based range)
# transcript_alignments - array of alignments: [ [transcript_start, transcript_stop, genomic_start, genomic_stop], [...], ... ]
#                         all indexes are 0-based, given as the first bp of aligned interval and first bp after the aligned interval (0-based range), 
#                         if the defined genomic subsequence is complementary (on the second strand), the given start/stop positions are reversed
# Output: 
# genomic_position, genomic_complementary, transcript_position, intron_offset (all indexes are 0-based, genomic_complementary is TRUE or FALSE, 
# for introns transcript_position points to the nearest exon and offset is != 0 and corresponds to genomic shift - in all other cases offset=0)
# Errors:
# Standard exception is thrown
def hgvs_cdna(hgvs_position, cds_start, cds_stop, transcript_alignments)
    # debuging print
    # puts  hgvs_position
    # puts cds_start
    # puts cds_stop
    # puts transcript_alignments
    # place for results
    genomic_position = nil
    genomic_complementary = nil
    transcript_position = nil
    intron_offset = 0
    # parse hgvs and calculate genomic position
    if hgvs_position =~ /^([\*\+\-]?\d+)([+-]\d+)?$/
        hgvs_transcript = $~[1] 
        hgvs_offset     = $~[2]
        transcript_position = convert_cdna_to_transcript(hgvs_transcript, cds_start, cds_stop)
        intron_offset = (hgvs_offset.nil?) ? (0) : (hgvs_offset.to_i)
        #puts "trans_pos=#{transcript_position}  cds=(#{cds_start},#{cds_stop})  intron_off=#{intron_offset}"
        transcript_alignments.each { |t|
            cdna_start = t[0]
            cdna_stop  = t[1]
            gen_start  = t[2]
            gen_stop   = t[3]
            # make sure that transcript is on the first strand (not complementary)
            if cdna_start > cdna_stop
                cdna_start, cdna_stop = cdna_stop, cdna_start
                gen_start , gen_stop  = gen_stop , gen_start
            end
            #puts "cdna=(#{cdna_start},#{cdna_stop}) gen=(#{gen_start},#{gen_stop})"
            # check if we have the correct interval
            if cdna_start <= transcript_position and transcript_position < cdna_stop
                offset = transcript_position - cdna_start
                genomic_complementary = (gen_start > gen_stop)
                gen_offset = (genomic_complementary) ? (-1-offset-intron_offset) : (offset+intron_offset)
                genomic_position = gen_start + gen_offset
                #puts "cdna=(#{cdna_start},#{cdna_stop}) gen=(#{gen_start},#{gen_stop}) #{reversed} => #{genomic_position}"
                break
            end
        }
        if genomic_position.nil?
            raise BRL::Genboree::GenboreeError.new(:'Bad Request',"Cannot find alignment with given transcript position (incorrect HGVS?)")
        end
    else
        raise BRL::Genboree::GenboreeError.new(:'Bad Request',"Unknown format of HGVS position: #{hgvs_position}")
    end
    return genomic_position, genomic_complementary, transcript_position, intron_offset
end


# function converting HGVS string with base positions like 78, -78, *78 to transcript index
def convert_cdna_to_transcript(hgvs_position, cds_start, cds_stop)
    leading_char = '+'
    if (hgvs_position !~ /^\d/)
        leading_char = hgvs_position[0..0]
        hgvs_position = hgvs_position[1..-1]
    end
    number = hgvs_position.to_i
    case leading_char
        when '+' 
            return (cds_start + number - 1)
        when '-' 
            return (cds_start - number)
        when '*' 
            return (cds_stop  + number - 1)
    end
    raise BRL::Genboree::GenboreeError.new(:'Bad Request',"Unknown format of HGVS position: #{leading_char}#{hgvs_position}")
end


