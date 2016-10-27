#!/usr/bin/env ruby

def usage()
  if ARGV.size != 12 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------" 
    $stderr.print "ruby run_Blast_TrimF_ASTA.rb  <the location of input FASTQ file> <the location of output directory> <sample barcode> <sample name> <sample min sequence length> <sample min average quality> <proximal primer> <distal primer> <flag1> <flag2> <flag3> <flag4>"
    $stderr.puts "-----------------------------------"
    exit
  end
end


def translateMultiSeq(str)
  if str != "0" and str != 0
    #1-30-14 kpr add case insensitivity to gsub commands
    str.gsub!(/R/i, "[GA]")
    str.gsub!(/Y/i, "[TC]")
    str.gsub!(/M/i, "[AC]")
    str.gsub!(/K/i, "[GT]")
    str.gsub!(/S/i, "[GC]")
    str.gsub!(/W/i, "[AT]")
    str.gsub!(/H/i, "[ACT]")
    str.gsub!(/B/i, "[GCT]")
    str.gsub!(/V/i, "[GCA]")
    str.gsub!(/D/i, "[GAT]")
    str.gsub!(/N/i, "[GATC]")
  end
end

def blast(seq, primer)
   
  tmpFile = "/scratch/#{rand(999999)}tmp.fa"
  w1 = File.open(tmpFile, "w")
  w1.puts ">tmp"
  w1.puts seq
  #puts seq
  w1.close()
  
  primerFile="/scratch/#{primer}tmp.fa"
  p1=File.open(primerFile,"w")
  p1.puts ">pri"
  p1.puts primer
  p1.close()
     

  cmd = "/cluster.shared/local/bin/blastn -query #{primerFile} -subject #{tmpFile} -task blastn-short -evalue 10 -reward 2"
  results = `#{cmd}`.to_a
  #puts results
  count = 0

  len = results.length
  preMod = len - 25
  numAlignments = preMod / 9
  
  identities = 0
  loc = 0
  strand = ""
  returnVal = 0
  
  #len > 30 means we have at least one hit
  #if len > 30
  for i in (1..numAlignments)
    #puts "####{i}######"
    iLoc = 2 + (9 * i)
    sLoc = 3 + (9 * i)
    lLoc = 7 + (9 * i)
   
    #puts "##########"
    identities = results[iLoc].split(" ")[2].split("/")[0].to_i
    loc = results[lLoc].split("  ")[1].to_i
    strand = results[sLoc].split("/")[1].chop
    #puts "##########"

    if primer == "53"
      if identities >= 13 and strand == "Plus"     
#puts "777"
        returnVal = loc #if loc > returnVal
      end
    elsif primer == "31"
      if identities >= 16 and strand == "Plus"
#puts "888"
        returnVal = loc #if loc > returnVal
      end
    end
  end  

  #puts "%%%%%#{returnVal}%%%%%"

  `rm #{tmpFile}`
  `rm #{primerFile}`

  returnVal = 0 if returnVal == nil
  return returnVal
  

end

def qualDropLoc(arr, windowLen, qualScore)
  len = arr.length
  capLen = len-windowLen
  for i in (0..capLen)
    innerLoopLen = i + windowLen
    average = 0
    sum = 0
    #puts "###{i}##"
    for j in (i...innerLoopLen)
      #puts arr[j]
      val = arr[j].to_i - 33
      #puts val.to_i
      sum += val
    end
    #puts sum
    #print "#{i}:"
    average = sum / innerLoopLen
    #print "\t"
    #break
  end
  average = 0 if average == nil
  return average
end


#usage()

inputFile = ARGV[0]
outputFolder = ARGV[1]

primer=ARGV[2]
title=ARGV[3]

innerCount = 0
count = 0
outCount = 0
count = 0
trimLenArg = ARGV[4].to_i
avgArg = ARGV[5].to_i

proPrimer=ARGV[6].dup
distPrimer=ARGV[7].dup


require "fileutils"
FileUtils.mkdir_p "#{outputFolder}"

  tag=primer
  pattern = "tcag" + tag.to_s 
  tag=proPrimer
  len=pattern.length+tag.length
  translateMultiSeq(tag)
 
  #tag = tag.downcase!.to_s
  #1-30-14 kpr
  tag = tag.downcase.to_s

  #puts pattern=pattern.downcase!+tag
  
  #pattern = Regexp.new(pattern.downcase! + tag, Regexp::IGNORECASE)
  #1-30-14 kpr
  pattern = Regexp.new(pattern.downcase + tag, Regexp::IGNORECASE)

  outFile = outputFolder + "/" + title + ".fa"
  statfilename = outputFolder +"/"+title+".filter"
  statfile =File.open(statfilename,"w")
  output = File.open(outFile, "w")
  input = File.open(inputFile, "r")
  
  notmatchproximal=0
  shortcount=0
  lowqualcount=0
  hasNcount=0
  sffseqcount=0 
  #Read in FASTQ file  
  input.each{ |line|
    name = line
    seq = input.gets
    plusMinus = input.gets
    scores = input.gets
    #seq=seq.downcase!
    #1-30-14 kpr
    seq=seq.downcase

    seqLen = seq.length
    bPrimerLen = 0    
    nFlag = 0
    qualityDropLocation = 0
    sffseqcount+=1
    #match proximal primer first
    if seq =~ /^#{pattern}/i
      #output.puts "match proximal primer"
      #calculate average of quality score
      n = 0
      sum = 0
      while n < seqLen
        sum += scores[n] - 33
        n += 1
      end
      avg = sum / seqLen 
 
      #match distal primer,the index of distalprimer is in bPrimerLoc    
      bPrimerLen=distPrimer.length
      if seq =~ /#{distPrimer}/
        #output.puts "V53 exact primer match"
        bPrimerLoc = seq.index("#{distPrimer}")
        #otherwise we need to see if we can find approximate match
      else
        #check for blast flag
        if ARGV[8].to_i == 1
          #output.puts "V5V3 about to blast"
          bPrimerLoc = blast(seq, distPrimer)
          innerCount += 1
        else
          bPrimerLoc = 0
        end 
      end 
  

    #set bPrimerLoc back to sequence length if we have not found primer      
    bPrimerLoc = seqLen if bPrimerLoc == 0
    nloc = 0 
    
    #find the location of "N"
    bigNloc = seq.index("N")
    smallNloc = seq.index("n")
    
    nloc = seqLen 
    if bigNloc != nil and smallNloc != nil
      #take the min of the locations or if they are equal let nloc remain 
      #  the seqLen value 
      if bigNloc < smallNloc 
        nloc = bigNloc
        nFlag = 1 
      else
        nloc = smallNloc
      end 
    elsif bigNloc == nil
      if !(smallNloc == nil)
        nloc = smallNloc
        nFlag = 1
      end
    elsif smallNloc == nil
      if !(bigNloc == nil)
        nloc = bigNloc
        nFlag = 1
      end
    end 
    
    
    bPrimerLoc = seqLen if bPrimerLoc == 0
    nloc = seqLen if nloc == 0
    trimLocPosition = seqLen
    #puts name  
    #puts "big: #{bigNloc} small: #{smallNloc}  #{nloc} #{bPrimerLoc}"
    
    if ARGV[9].to_i == 1 
       #if primer location occurs before an 'n' use primer location
       if bPrimerLoc <= nloc
           trimLocPosition = bPrimerLoc
       else
           trimLocPosition = nloc
       end
     else
        trimLocPosition = bPrimerLoc
     end
     trimSize=trimLocPosition-bPrimerLen+1
     #puts "#{trimLocPosition}  #{trimSize} #{avg}"  
     #drop sequnce based on quality       
     if ARGV[11].to_i == 1
       qualityDropLocation = qualDropLoc(scores, 30, 20)
       if qualityDropLocation > 0
         if qualityDropLocation <= trimLocPosition
             trimLocPosition = qualityDropLocation
             trimSize = qualityDropLocation - bPrimerLen + 1
         end
       end
     end

     #output filtered sequece based on if there is "N" in the sequnce 
     if ARGV[10].to_i == 1       
       if nFlag == 0
         if trimSize >= trimLenArg and avg >= avgArg
            output.puts name.gsub(/\@/, ">")
            output.puts seq[len, trimLocPosition-len].upcase
            outCount += 1
         elsif trimSize< trimLenArg
            shortcount+=1
         elsif avg<avgArg
            lowqualcount+=1 
         end
       else 
            hasNcount+=1 
       end
     else
       if trimSize >= trimLenArg and avg >= avgArg
         output.puts name.gsub(/\@/, ">")
         output.puts seq[len, trimLocPosition-len].upcase
         outCount += 1
       elsif trimSize< trimLenArg
            shortcount+=1
       elsif avg<avgArg
            lowqualcount+=1
       end
     end
    else 
      notmatchproximal+=1
      
  end
  }

  total=outCount+shortcount+lowqualcount+hasNcount
  output.close()
  statfile.puts "total_sequence_counts_in_sffFile:\t#{sffseqcount}"
  statfile.puts "total_sequence_counts_after_filter:\t#{outCount}"
  statfile.puts "total_sequnece_counts_before_filter:\t#{total}"
  statfile.puts "sequence_not_match_proximal_primer:\t#{notmatchproximal}"
  statfile.puts "sequence_length_shorter_than_min_after_trimming:\t#{shortcount}"
  statfile.puts "sequence_qual_lower_than_min:\t#{lowqualcount}"
  statfile.puts "sequnece_hasN_filtered:\t#{hasNcount }"
  statfile.close()
  #puts innerCount
  #$stderr.puts outCount

