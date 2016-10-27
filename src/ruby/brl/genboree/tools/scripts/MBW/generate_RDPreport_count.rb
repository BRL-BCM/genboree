#!/usr/bin/env ruby
require "fileutils"

#if entry does not have trailing slash, append one
def Append(val)
  len = val.length
  len -= 1
  tmp = val
  if val[len].chr != "/"
    return tmp += "/" if val[len].chr != "/"
  else
    return tmp
  end
end

#create directory based on argument 1 if it does not exist
FileUtils.mkdir_p ARGV[1]

#declare input and output locations
inputLoc = Append(ARGV[0])
outputLoc = Append(ARGV[1])

#dirs will hold directories of contents of ARGV[0]
dirs = []

#list entries of directory and filter out root and parent folders
tmpdirs = Dir.entries(inputLoc)
tmpdirs.each{ |val|
  if val !~ /\./
    dirs.push(val)
  end
}

count = 0

#loop to evaluate files in each folder in ARGV[0]
dirs.each{ |dir|
  $stderr.print "Looping through #{dir}\t\t"

  #files is array to hold files in dir
  files = Dir.glob("#{inputLoc}#{dir}/*")

  #arr holds list of all values from all files
  arr = []
  #fNamesArr holds list of file names for outputting
  fNamesArr = []

  #loop through each file from directory
  files.each{ |fileName|
    spl = fileName.split("/")
    loc = spl.length
    loc -= 1
    #push name of file onto array
    fNamesArr.push(spl[loc])

    input = File.open(fileName, "r")
 
    #read first two lines
    input.gets
    input.gets 
 
    #collecet array of all possible names 
    input.each{ |line|
      spl = line.split("\t")
      arr.push(spl[0]) 
    }  
    input.close()
  }

  #create hash based on values present in array
  b = Hash.new(0)
  arr.each do |v|
    b[v] += 1
  end

  #sort array based on name for formatted output
  bSort = Hash.new(0)
  bSort = b.sort

  outSpl = dir.gsub(/\//, "")
  outFile = outSpl + "_count.txt" 
  #open output file
  w = File.open(outputLoc + outFile, "w")

  #being official output
  w.print "___\t"
  #print the first row of data which consists of the names of the files
  fNamesArr.each{ |fileName|
    w.print "#{fileName}\t"
  }

  #clear line
  w.puts ""

  #loop through sorted hash
  bSort.each{ |k, v| 
    tempName = k.gsub(/"/, "") 
    #print first array entry, which is name of taxonomy entry
    w.print "#{k}\t"  
   
    #loop through each file in entry
    fNamesArr.each{ |fileName|
      inputFile = "#{inputLoc}#{dir}/#{fileName}"
      input = File.open(inputFile, "r")

      input.gets
      input.gets
    
      flag = 0
   
      #loop through file and print out abundance 
      input.each{ |line|
        spl = line.split("\t")

        if k == spl[0]
          #going back to rdp, we can show just count for pca
          perc = spl[1].to_f

          ###perc = spl[3].to_f * 100
          #if perc > 0.1
          if perc >= 0.001
            w.print "#{perc}\t"

            flag = 1
          end
        end
      }
      #print a 0 if taxonomy was not present
      w.print "0\t" if flag == 0

    }
    w.puts ""


  }
  w.close()
  $stderr.puts "done"
  
#########################start normalized output section##########

  puts reOpen = outputLoc + outFile
  r = File.open(reOpen, "r")

  puts outFileAgain = reOpen.gsub(/\.txt/, "-normalized.txt")
  w = File.open(outFileAgain, "w")
  
  nameArr = []
  normArr = []
  len = 0
  rows = 0

  w.puts r.gets 
  r.each{ |line|
    spl = line.split("\t")
    len = spl.length
    normArr.push(line)
    nameArr.push(spl[0])
    rows += 1
  } 

  sumArr = []
  for i in (0..len-2)
    pos = 0
    sum = 0
    normArr.each{ |line|
      spl = line.split("\t")
      sum += spl[i].to_f
      #pos += 1
    } 
    sumArr.push(sum)
  end  


  normArr.each{ |line|
  #nameArr.each{ |name|
  #  print "#{name}\t"
  
  spl = line.split("\t")
  w.print "#{spl[0]}\t"

  for i in (0..len-2)
    if i == 0
      #print "#{nameArr[i]}\t"
    else
      #normArr.each{ |line|
        #spl = line.split("\t")
        norm = spl[i].to_f / sumArr[i].to_f
        if norm > 0.001
          w.print norm
        else
          w.print "0"
        end
        w.print "\t"
      #}      
    end

  end
  w.puts ""
  #}
  }

  r.close()
  w.close()
  
  count += 1
  #break if count > 1 
}
