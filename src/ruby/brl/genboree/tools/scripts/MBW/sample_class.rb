class Sample
  def initialize(sampleID, sampleName,barcode, minseqLength, minAveQual, minseqCount, proximal,distal,region,flag1, flag2,flag3,flag4,fileLocation,metadata)
    @sampleID=sampleID
    @sampleName=sampleName
    @barcode=barcode
    @minseqLength=minseqLength.to_i
    @minAveQual=minAveQual.to_i
    @minseqCount=minseqCount.to_i
    @proximal=proximal
    @distal=distal
    @region=region
    @flag1=flag1
    @flag2=flag2
    @flag3=flag3
    @flag4=flag4
    @fileLocation=fileLocation
    @metadata=metadata
  end

def outputStat(statFileLocation,faFileLocation,seqfiltFileLocation)
    inFile=File.open(faFileLocation,"r")
    seqLenSum=0
    seqCount=0
    aveReadLen=0
    inFile.each{ |line|
       name=line
       seq=inFile.gets
       seqLenSum += seq.length
       seqCount += 1
     }
     inFile.close()
     if seqCount > 0
        avgReadLen = seqLenSum / seqCount
     end
    seqfiltFile=File.open(seqfiltFileLocation,"r")

    output=File.open(statFileLocation,"w")
    output.puts "sampleID: #{sampleID}"
    output.puts "sampleName: #{sampleName}"
    output.puts "barcode: #{barcode}"
    output.puts "minseqLength: #{minseqLength}"
    output.puts "minAveQual: #{minAveQual}"
    output.puts "minSeqCount: #{minseqCount}"
    output.puts "total_number_of_sequences: #{seqCount}"
    output.puts "fileLocation: #{fileLocation}"
    output.puts "Averge_read_length: #{avgReadLen}"
    output.puts "Proximal_Primer: #{proximal}"
    output.puts "Distal_Primer: #{distal}"
    output.puts "Region: #{region}"
    output.puts "Match_distal_primer_up_to_3_mismatches: #{flag1}"
    output.puts "Trim_at_first_location_of_N: #{flag2}"
    output.puts "Ignore_any_sequence_with_N: #{flag3}"
    output.puts "Trim_sequence_when_the_quality_is_lower_than_a_give_threshold: #{flag4}"
    0.step(metadata.size-1,2){|x|
      output.puts "#{metadata[x]}: #{metadata[x+1]}"
    }
    seqfiltFile.each{|line|
       line.strip!
       output.puts line
    }
    output.close()
    lowSeqCount=0
    if seqCount < @minseqCount
      lowSeqCount=1
    end 
    return lowSeqCount
  end

attr_reader :sampleID, :sampleName, :barcode, :minseqLength, :minAveQual, :minseqCount, :proximal, :distal, :region, :flag1, :flag2, :flag3, :flag4, :fileLocation, :metadata

end


