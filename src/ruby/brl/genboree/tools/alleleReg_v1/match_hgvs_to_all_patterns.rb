def match_hgvs_to_pattern hgvs_in, var_ins, pat_ins
 pat_ins_pat = Regexp.new(pat_ins)
 succeded = true
 temp_parsed = hgvs_in.match(pat_ins_pat).captures rescue succeded = false
 if succeded == true
  temp_a = Hash.new()
  abc = var_ins.split(",")
  (0...abc.size).each do |j|
    temp_a[abc[j]] = temp_parsed[j]
  end
  return succeded,temp_a
 else
  return succeded,nil
 end
end

def match_hgvs_to_all_patterns hgvs,vars,pats,type,nature,intron,utr5,utr3,allele_name_type,aa_change_type
  found = false
  error = false
  succeded = false
  # check individual patterns
  (0...vars.size).each do |i|
    succeded,back = match_hgvs_to_pattern(hgvs,vars[i],pats[i]) 
    if succeded == true
      return true,back,type[i],nature[i],intron[i],utr5[i],utr3[i],hgvs,allele_name_type[i],aa_change_type[i].chomp 
    end
  end

  # If the hgvs doesnot match with any pattern then give status as false and everything else nil
  if succeded == false
      return false,nil,nil,nil,nil,nil,nil,nil,nil,nil
  end

end
