#!/usr/bin/env ruby

require 'fileutils'
require 'statsample'

def min(array)
  min = 999999999
  array.each{ |val|
    min = val if val < min 
  }
  return min
end

def max(array)
  min = -999999999
  array.each{ |val|
    min = val if val > min
  }
  return min
end

#borrowed from
#http://stackoverflow.com/questions/1744525/ruby-percentile-calculations-to-match-excel-formulas-need-refactor
def excel_quartile(array, quartile)
  # Returns nil if array is empty and covers the case of array.length == 1
  return array.first if array.length <= 1
  sorted = array.sort
  # The 4th quartile is always the last element in the sorted list.
  return sorted.last if quartile == 4
  # Source: http://mathworld.wolfram.com/Quartile.html
  quartile_position = 0.25 * (quartile*sorted.length + 4 - quartile)
  quartile_int = quartile_position.to_i
  lower = sorted[quartile_int - 1]
  upper = sorted[quartile_int]
  lower + (upper - lower) * (quartile_position - quartile_int)
end

def excel_lower_quartile(array)
  excel_quartile(array, 1)
end

def excel_median(array)
  excel_quartile(array, 2)
end

def excel_upper_quartile(array)
  excel_quartile(array, 3)
end


otuTable = File.expand_path(ARGV[0])
otuList = File.expand_path(ARGV[1])
otuListOut = otuList.gsub(/txt/, "gini_trends")
otuListOutSorted = otuList.gsub(/txt/, "gini_trends_3sorted")
#metaCMDfile = File.expand_path(ARGV[2])
#rerunsFile = File.expand_path(ARGV[3])
#outDir = File.expand_path(ARGV[2]) + "/"
#FileUtils.mkdir_p outDir
confirmedFile = File.expand_path(ARGV[2])

confirmedHash = Hash.new(0)
confirmed=File.open(confirmedFile,"r")
confirmed.gets
confirmed.each{ |line|
  confirmedHash[line.split("\t")[0]] += 1
}

otuTableHash = Hash.new(0)
r = File.open(otuTable, "r")
titles = r.gets
otuTableBool = 1

metaData = r.gets.strip!
metaDataArr = metaData.split("\t")
metaDataName = metaDataArr[0]
metaDataArr.delete_at(0)
uniqueMetaNames = metaDataArr.uniq

#uniqueMetaNames.each{ |val|
#  puts ":#{val}:"
#}
uniqueMetaNames.delete_if { |val|
  #val.length < 2
  val == "\n"
}

namesArr = []
countsArr = []
meanArr = []
popStdevArr = []
stdArr = []
h1Arr = []
minArr = []
q1Arr = []
medianArr = []
q3Arr = []
maxArr = []
h2Arr = []
h3Arr = []
botWhiskArr = []
topWhiskArr = []

rankArr = []
sampUarr = []
uArr = []
tArr = []
zArr = []
zProb = []
exactProb = []

#store OTUs into hash for rapid lookup
r.each{ |line|
  spl = line.split("\t")
  len = spl.length
  len -= 1
  #delete taxonomy at last array position
  spl.delete_at(len) if otuTableBool == 1
  otuNum = spl[0]
  spl.delete_at(0)
  otuLine = spl.join("\t")
 # puts "#{otuNum}\t#{otuLine}"
  otuTableHash[otuNum] = otuLine
}
r.close()

listRead = File.open(otuList, "r")
listRead.gets

taxArr = []
lineCount = 0

listRead.each{ |line|
  #setup array holder and arrays to store separated OTU abundance based
  #  on meta data label
  line.strip!
  arrs = []
  uniqueMetaNames.each{ |val|
    #puts val
    arr = []
    arrs << arr
  }
 
  #otuNumArr = []
  
  readOTUs = 0
  #listRead.each{ |line|
 # puts line
  otuLineSplit = line.split("\t")
  #otuNum = line.split("\t")[1].split(" ")[0].gsub(/X/, "")
  otuNum = otuLineSplit[1]
 # puts otuNum
  otuTax = "#{otuLineSplit[0]}\t#{otuNum}"
  taxArr.push(otuTax)
    
  #otuNumArr.push(otuNum)
  abunArr = otuTableHash[otuNum].split("\t")
  
  count = 0 
  abunArr.each{ |val|
    #print "#{metaDataArr[count]}:#{val}:"
    arrLoc = uniqueMetaNames.index(metaDataArr[count])
   # puts "#{arrLoc}\t#{val}"
    arrs[arrLoc].push(val.to_i)
    count += 1
  }
  
  readOTUs += 1
    #break if readOTUs > 2
  #}

  #make array to hold yes and no arrays
  yesNoArrs = []
  
  loopCount = 0
  arrs.each{ |currArr|
    if uniqueMetaNames[loopCount] =~ /notapp/
      loopCount += 1
      next
    end
 
    yesNoArrs << currArr
    
    #puts uniqueMetaNames[loopCount]
    namesArr.push("#{uniqueMetaNames[loopCount]}-#{otuNum}")
    #puts "#{uniqueMetaNames[loopCount]}-#{otuNum}"
    #http://samdorr.net/blog/2008/10/standard-deviation/
    count = currArr.size
    countsArr.push(count)
    total=currArr.inject(:+)
    mean = total / count.to_f
    meanArr.push(mean)
    popstddev = Math.sqrt( currArr.inject(0) { |sum, e| sum + (e - mean) ** 2 } / count.to_f )
    popStdevArr.push(popstddev)
    stddev = Math.sqrt( currArr.inject(0) { |sum, e| sum + (e - mean) ** 2 } / (count.to_f - 1))
    stdArr.push(stddev)

    minVal = min(currArr) 
    minVal = currArr.min
    minArr.push(minVal)
    q1 = excel_lower_quartile(currArr)
    q1Arr.push(q1)
    median = excel_median(currArr)
    medianArr.push(median)
    q3 = excel_upper_quartile(currArr)
    q3Arr.push(q3)
    maxVal = max(currArr)
    maxArr.push(maxVal)
  
    h1 = q1
    h1Arr.push(h1)
    h2 = median - q1
    h2Arr.push(h2)
    h3 = q3 - median
    h3Arr.push(h3)
  
    tmpBot1 = q1 - minVal
    tmpBot2 = 1.5 * (q3 - q1)
    bottomWhisker = 0
    if tmpBot1 > tmpBot2
      bottomWhisker = tmpBot2
    else
      bottomWhisker = tmpBot1
    end
  
    tmpTop1 = maxVal - q3
    tmpTop2 = 1.5 * (q3 - q1)
    topWhisker = 0 
    if tmpTop1 > tmpTop2
      topWhisker = tmpTop2
    else
      topWhisker = tmpTop1
    end
   
    botWhiskArr.push(bottomWhisker)
    topWhiskArr.push(topWhisker)
    loopCount += 1
  }
  
  #temp arrays to cast yes and no arrays as integers
  tmpArr1 = []
  tmpArr2 = []

  yesNoArrs[0].each{ |val|
    tmpArr1.push(val.to_i)
  }

  yesNoArrs[1].each{ |val|
    tmpArr2.push(val.to_i)
  }

  arr1 = tmpArr1.map {|x| x}.to_scale
  arr2 = tmpArr2.map {|x| x}.to_scale

  #puts "OTU#\tsamp1rankSum\tsamp2rankSum\tsamp1u\tsamp2u\tUval\tTval\tname\tZval\tzProb\texactProb" if lineCount == 0
  u = Statsample::Test::UMannWhitney.new(arr1, arr2)
  #puts u.summary


  #print "#{otuNum}\t"
  #print "#{u.r1}\t"
  #print "#{u.r2}\t"
  #print "#{u.u1}\t"
  #print "#{u.u2}\t"
  #print "#{u.u}\t"
  #print "#{u.t}\t"
  #print "#{u.name}\t"
  #print "#{u.z}\t"
  #print "#{u.probability_z}\t"
  #print "#{u.probability_exact}"

  rankArr.push(u.r1)
  rankArr.push(u.r2)
  sampUarr.push(u.u1)
  sampUarr.push(u.u2)
  uArr.push(u.u)
  tArr.push(u.t)
  zArr.push(u.z)
  zProb.push(u.probability_z)
  exactProb.push(u.probability_exact)

  lineCount += 1
}
listRead.close()
#namesArr.each{ |val| puts ":#{val}:"}
  
combineArrs = []
  
combineArrs << namesArr
combineArrs << countsArr
combineArrs << meanArr
combineArrs << popStdevArr
combineArrs << stdArr
combineArrs << minArr 
combineArrs << q1Arr
combineArrs << medianArr
combineArrs << q3Arr
combineArrs << maxArr
combineArrs << h1Arr
combineArrs << h2Arr
combineArrs << h3Arr
combineArrs << botWhiskArr
combineArrs << topWhiskArr
  
labels = %w(name count mean population_standard_deviation standard_deviation min q1 median q3 max height1 height2 height3 bottomWhisker topWhisker U Z)



=begin 
count = 0
combineArrs.each{ |arr|
  print labels[count]
  arr.each{ |val|
    print "\t#{val}"
  }
  puts
  count += 1
}
=end

#re-open OTU list for up and down trend analysis of fold and direction
listRead = File.open(otuList, "r")


count = 0

#get q1, q3, and median locations (in case they change later don't hard code)
#puts q1Loc = labels.index("q1")
#puts mLoc = labels.index("median")
#puts q3Loc = labels.index("q3") 
yesno1 = ""
yesno2 = ""

=begin
if namesArr[0] =~ /Yes/
  yesno1 = "Yes"
  yesno2 = "No"
else
  yesno1 = "No"
  yesno2 = "Yes"
=end

#1-26-11 need to add labels instead of the confusing 'yes' or 'no'
yesno1 = namesArr[0].split("-")[0]
yesno2 = namesArr[1].split("-")[0]



listOut = File.open(otuListOut, "w")
#listOut.puts "RDP Taxonomy\tOTU#\t#{yesno1}-q1\t#{yesno1}-median\t#{yesno1}-q3\t#{yesno2}-q1\t#{yesno2}-median\t#{yesno2}-q3\tU\tZ\tDirectional_Change\tBoruta"

#12-9-10 add min and max
listOut.puts "RDP Taxonomy\tOTU#\t#{yesno1}-min\t#{yesno1}-q1\t#{yesno1}-median\t#{yesno1}-q3\t#{yesno1}-max\t#{yesno2}-min\t#{yesno2}-q1\t#{yesno2}-median\t#{yesno2}-q3\t#{yesno2}-max\tU\tZ\t#{yesno1}-Uscore\t#{yesno2}-Uscore\t#{yesno1}-h1\t#{yesno1}-h2\t#{yesno1}-h3\t#{yesno1}-botWhisk\t#{yesno1}-topWhisk\t#{yesno2}-h1\t#{yesno2}-h2\t#{yesno2}-h3\t#{yesno2}-botWhisk\t#{yesno2}-topWhisk\tDirectional_Change\tBoruta"


loopCount = 0
taxArr.each{ |line|
  otuNum = line.split("\t")[1].strip
  boruta = "Rejected"
  boruta = "Confirmed" if confirmedHash[otuNum] > 0

  #puts "#{otuNum}:#{boruta}"

  alab = namesArr[count]
  #10-27-10 make exception for PQ vs. Adult (aka non-PQ or Jumpstart)
  #1-26-11 remove exception so it's generic
  #alab = "Yes" if alab =~ /PQ/
  amin = minArr[count].to_f
  aq1 = q1Arr[count].to_f
  am1 = medianArr[count].to_f
  aq3 = q3Arr[count].to_f
  amax = maxArr[count].to_f
  s1U = sampUarr[count].to_f

  ah1 = h1Arr[count].to_f
  ah2 = h2Arr[count].to_f
  ah3 = h3Arr[count].to_f
  abot = botWhiskArr[count].to_f
  atop = topWhiskArr[count].to_f

  count += 1
  blab = namesArr[count]
  bmin = minArr[count].to_f
  bq1 = q1Arr[count].to_f
  bm1 = medianArr[count].to_f
  bq3 = q3Arr[count].to_f
  bmax = maxArr[count].to_f
  s2U = sampUarr[count].to_f

  bh1 = h1Arr[count].to_f
  bh2 = h2Arr[count].to_f
  bh3 = h3Arr[count].to_f
  bbot = botWhiskArr[count].to_f
  btop = topWhiskArr[count].to_f
  
  uVal = uArr[loopCount]
  zVal = zArr[loopCount]  
   
  listOut.print "#{line}\t" 
  #listOut.print "#{aq1}\t#{am1}\t#{aq3}\t#{bq1}\t#{bm1}\t#{bq3}\t#{uVal}\t#{zVal}\t"
  #listOut.print "#{aq1}\t#{am1}\t#{aq3}\t#{bq1}\t#{bm1}\t#{bq3}\t#{uVal}\t#{zVal}\t#{s1U}\t#{s2U}\t"

  #12-9-10 add min, max and box plot data
  listOut.print "#{amin}\t#{aq1}\t#{am1}\t#{aq3}\t#{amax}\t#{bmin}\t#{bq1}\t#{bm1}\t#{bq3}\t#{bmax}\t#{uVal}\t#{zVal}\t#{s1U}\t#{s2U}\t#{ah1}\t#{ah2}\t#{ah3}\t#{abot}\t#{atop}\t#{bh1}\t#{bh2}\t#{bh3}\t#{bbot}\t#{btop}\t"


  #determine which columns of data is a yes (the first or the second)
=begin
  if alab=~ /Yes/
    if s1U > s2U
      listOut.print "UP"
    else
      listOut.print "DOWN"
    end
  else
    if s2U > s1U
      listOut.print "UP"
    else
      listOut.print "DOWN"
    end
=end
  #1-26-11 make this situation generic
  if s1U > s2U 
    listOut.print "UP in #{alab.split("-")[0]}"
  else 
    listOut.print "UP in #{blab.split("-")[0]}" 
  end 


  listOut.puts "\t#{boruta}"

  count += 1
  loopCount += 1
  #break if count > 10
}

listOut.close()

#12-1-10 also double sort the output by confirmed, rejected then lowested U
#sortCMD = "sort -t $'\t' -k 12,12 -k 9,9n #{otuListOut} > #{otuListOutSorted}"
#12-9-10 change sort to use new tab format
sortCMD = "sort -t $'\t' -k 28,28 -k 13,13n -k 14,14n #{otuListOut} > #{otuListOutSorted}"
`#{sortCMD}`
