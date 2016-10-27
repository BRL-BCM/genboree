def make_hgvs startc,endc,mutationType,referenceGenomic,referenceAllele,alternateAllele,reftype
   $stderr.puts "Inside make hgvs"
   $stderr.puts  startc,endc,mutationType,referenceGenomic,referenceAllele,alternateAllele,reftype

 startc= startc.to_s
 endc= endc.to_s
 case (startc==endc)
  when true
   $stderr.puts "The startc and endc are same for the given allele while making genomic HGVS"
   case mutationType
    when "SO:1000002^substitution"
       return((referenceGenomic+":"+reftype+"."+startc+referenceAllele+">"+alternateAllele))
    when "SO:0000159^deletion"
      if referenceAllele.nil?
       return(referenceGenomic+":"+reftype+"."+startc+"del")
      else
       return(referenceGenomic+":"+reftype+"."+startc+"del"+referenceAllele)
      end
    else
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Cannot generate hgvs string")
   end
  when false
   $stderr.puts "The startc and endc are not same for the given allele while making genomic HGVS"
   case mutationType
    when "SO:0000159^deletion"
       if referenceAllele.nil?
        return(referenceGenomic+":"+reftype+"."+startc+"_"+endc+"del")
       else 
        return(referenceGenomic+":"+reftype+"."+startc+"_"+endc+"del"+referenceAllele)
       end
    when "SO:1000032^indel"
        return(referenceGenomic+":"+reftype+"."+startc+"_"+endc+"delins"+alternateAllele)
    when "SO:0000667^insertion"
       return(referenceGenomic+":"+reftype+"."+startc+"_"+endc+"ins"+alternateAllele)
    else
       raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Cannot generate hgvs string")
   end
  end
end
