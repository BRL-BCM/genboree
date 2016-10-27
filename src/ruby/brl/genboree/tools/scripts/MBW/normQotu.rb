#!/usr/bin/env ruby

count = 0
flag = 0
otuFile = File.expand_path(ARGV[0])
r = File.open(otuFile, "r")

cutOff = ARGV[1].to_f

#check to see if taxonomy is at beginning or end of line
r.gets
r.gets
taxCheck = ""
for i in (0..10)
  taxCheck += r.gets.split("\t")[0]
end

if taxCheck =~ /\;/
  #tax is at beginning, meaning phylogenetic split OTU table
  flag = 1
else
  #tax is at end, meaning full OTU table
  flag = 2
end
r.close


r = File.open(otuFile, "r")
puts outFileAgain = otuFile.gsub(/\.txt/, "-normalized.txt")
w = File.open(outFileAgain, "w")


firstLine = r.gets
w.puts firstLine

#get col headers
header = r.gets


#trim "Consensus Lineage" off of end of headers
#header = header.gsub(/\tConsensus\ Lineage/, "")

#column headers aren't showing up in heatmap .. try removing #sign
#header = header.gsub(/\#OTU\ ID/, "")

w.puts header


headerArr = header.split("\t")
headerCount = 0
headerCount = headerArr.length - 1 if flag == 2
headerCount = headerArr.length if flag == 1
#puts
allArrs = []
allArrSums = []
allTax = []
for i in (0..headerCount)
  tmpArr = []

  allArrs << tmpArr 
  allArrSums.push(0) 
end

count = 0
r.each{ |line|
  spl = line.split("\t")
  #puts spl
  internalCount = 0
  spl.each{ |val|
    #allArrs[count][internalCount] = val
    #puts "#{val}:#{internalCount}"
    #puts allArrs[internalCount][count]
    break if val == nil
   

    if flag == 2
      if internalCount <= headerCount -1
        allArrs[internalCount].push(val.to_i)
        allArrSums[internalCount] = allArrSums[internalCount].to_i + val.to_i
        internalCount += 1 
      else
        allTax.push(val)
        #break
      end
    elsif flag == 1


    end
  }
  count += 1
}

#allArrs[2].each{ |val|
count = 0
count = -1 if flag == 2
lineNum = 0
#allArrSums.each{ |sum|

arrSize = allArrs[0].length

#the value of the multipler used to get the percentages into
#  whole number form
#mult = 1000
mult = 100000

for rowNum in (0...arrSize)
  #puts rowNum
  count = 0
  if flag == 2
    #8-20-10 trying to get just OTU normalized in same format
    #w.print "#{allArrs[0][rowNum]};#{allTax[rowNum].strip}\t"
    w.print "#{allArrs[0][rowNum]}\t"
    for colNum in (1..headerCount-1) 
      #puts "#{rowNum}:#{colNum}"
      #if count == 0
      #  print "*"
      #  puts allArrs[colNum][rowNum]
      #else
      #  puts allArrs[colNum][rowNum]
      #end   

      val = allArrs[colNum][rowNum].to_i
      #puts "#{val}:#{allArrSums[colNum]}"
      if val == 0
        normVal = 0
      else
        normVal = val.to_f / allArrSums[colNum].to_f
      end
      normVal = normVal * mult
      #w.print "#{normVal.to_f * mult}\t"
      w.print "#{normVal.to_i}\t"
      count += 1
    end
    #w.puts 
    w.puts allTax[rowNum]
  end
  #puts sum 
  lineNum += 1


end
r.close()
w.close()


tag = cutOff.to_s
tag = tag.gsub(/\./, "")

r = File.open(outFileAgain, "r")
puts outFileAgainForCleaning = otuFile.gsub(/\.txt/, "-normalized-clean#{tag}.txt")
w = File.open(outFileAgainForCleaning, "w")

w.puts r.gets
r.each{ |line|
  spl = line.split("\t")
  len = spl.length 
  if flag == 2
    sum = 0.0
    for i in (1... len-1)
      sum += spl[i].to_f
    end
    #puts sum
    w.puts line if sum >= cutOff
  elsif flag == 1

  end
}

r.close()
w.close()
