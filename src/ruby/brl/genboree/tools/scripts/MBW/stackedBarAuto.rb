#!/usr/bin/env ruby

require 'fileutils'

#usage
#ruby stackedBarAuto.rb <input directory containing tsv's> <output directory>

#the maximum number of values to allow
MAX = 25

#set input and output directories and create output directory
inDir = File.expand_path(ARGV[0])
outDir = File.expand_path(ARGV[1])
FileUtils.mkdir_p outDir

#set the file extension
fileExtension = "tsv"
#store files that match the file extension into an array
files = `ls #{inDir}/*#{fileExtension}`.to_a

#loop through each file
files.each_with_index{ |file, i|
  file.strip!

  $stderr.puts file

  #set the title based on the file name
  #  when you implement this you will have to obtain the taxonomic depth
  #  from which ever field / file position lists the taxonomic depth
  title = File.basename(file).split(/[0-9]/)[0] + " - Pooled Taxonomically Binned Data"

  #open the file
  r = File.open(file, "r")

  #get first header line
  line = r.gets.strip!
  
  #store column names
  colNamesArr = line.split(/[,|\t]/)

  #store number of columns
  numCols = colNamesArr.length - 1

  colNames = ""
  #create column names list for R input
  colNamesArr.each_with_index{ |val,count|
    next if count == 0
    colNames += ", " if count > 1 
    colNames += "\"#{val.strip} \""
  }
  puts colNames
  #positional hash based on line number of which rows to keep (up to MAX)
  # key - line number, value - row sum
  keepHsh = Hash.new(0)

  #Hash to store each line
  # key - line number, value - line
  storeLinesHsh = Hash.new(0)

  #store row names
  rowNamesArr = []
  #read through the rest of the lines in the input file
  r.each_with_index{ |line, j|
    #store line into hash
    storeLinesHsh[j] = line.strip
    #split based on comma or tab
    spl = colArr = line.split(/[,|\t]/)

    #store row name
    rowNamesArr.push(spl[0])
    #remove row name from array
    spl.delete_at(0)
    sum = 0.0
    #sum up the values for a row sum
    spl.each{ |val|
      sum += val.to_f
    }
    #store sum into hash
    keepHsh[j] = sum
  }

  r.close()

  #array to keep track of which lines to keep (for a max of MAX)
  keepArr = []

  #sort hash into keepArr based on highest sum
  keepHsh.sort{|a,b| b[1]<=>a[1]}.each{ |elem|
    #puts "#{elem[0]}:#{elem[1]}"
    keepArr.push(elem[0])
  }

  matrixValues = ""
  rowNames = ""

  #loop through the sorted order
  keepArr.each_with_index{ |lineNum, count|
    #puts "#{lineNum}:#{storeLinesHsh[lineNum]}"
    break if count == MAX
    #split based on comma or tab
    spl = storeLinesHsh[lineNum].split(/,|\t/)

    #update rowNames to use later in R script
    rowNames += ", " if count > 0
    nameLimit = spl[0]
    if nameLimit.length > 25
      nameLimit = spl[0][0..25] + "..."
    end
    rowNames += "\"#{nameLimit}\""

    #delete first entry
    spl.delete_at(0)
    #loop through eac value to output matrix values into one flat list
    spl.each_with_index{ |val,splloc|
       matrixValues += "," if count == 0 && splloc > 0
       matrixValues += "," if count > 0
       matrixValues += val
    }
  }
 
  #hard coded xlimit value to use to push over stacked bar charts enough
  #  so that we can see the legend 
  xlimVal = 200 + ((numCols-2)*60)

  #output file to contain R script
  outFile = outDir + "/" + File.basename(file) + ".R"

  #output file to contain temporary pdf
  pdfFile = outFile + ".pdf" 

  #output file to contain PNG
  pngFile = outFile + ".PNG"

  w = File.open(outFile, "w")

  w.puts "pdf(file= \"#{pdfFile}\", width=8, height=8)"
  w.puts "library(RColorBrewer)"
  w.puts "cols <- #{numCols}"
  w.puts "mtx <- matrix(c(#{matrixValues}),ncol=cols,byrow=TRUE)"
  w.puts "colnames(mtx) <- c(#{colNames})"
  w.puts "rownames(mtx) <- c(#{rowNames})"

  #26 color palette
  w.puts "pally <- c(\"#E31A1C\",\"#1F78B4\",\"#FFFF99\",\"#33A02C\",\"#FB9A99\",\"#A6CEE3\",\"#FDBF6F\",\"#CAB2D6\",\"#FF7F00\",\"#6A3D9A\",\"#B2DF8A\",\"#B15928\",\"#7FC97F\",\"#BEAED4\",\"#FDC086\",\"#386CB0\",\"#F0027F\",\"#BF5B17\",\"#666666\",\"#1B9E77\",\"#D95F02\",\"#7570B3\",\"#E7298A\",\"#66A61E\",\"#E6AB02\",\"#A6761D\")"
  w.puts ""
  w.puts "tbl <- as.table(mtx)"
  w.puts "mp <- barplot(tbl, main=\"#{title}\","
  w.puts " "
  #w.puts "  xlab=\"X axis label\","
  w.puts "  col=pally,"
  w.puts "  xlim=c(0,#{xlimVal}),"
  w.puts "  ylim=c(0,1),"
  w.puts "  width = c(30, 30),"
  #print out bar plot legends vertically
  #w.puts "  las=2,"
  #set this to false if we want to write the bar plot legends out at an angle
  w.puts "  axisnames = FALSE,"
  w.puts "  legend = rownames(tbl))"
  #outputs bar chart legends at a 45 degree angle
  w.puts "  text(mp, par(\"usr\")[3], labels = c(#{colNames}), srt = 45, adj= 1.1, xpd = TRUE)"
  w.puts "dev.off()"

  w.close()
  
  #run R script
  `R --vanilla < #{outFile}`

  #convert pdf into PNG
  `convert -density 350 #{pdfFile} #{pngFile}`

  #remove pdf file
  `rm -f #{pdfFile}`
}
