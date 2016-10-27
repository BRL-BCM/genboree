#!/usr/bin/env ruby
  
require 'brl/microbiome/workbench/RandomForestUtils'
require 'fileutils'
require 'matrix.rb'
  
def usage()
  if ARGV.size != 3 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_MachineLearning.rb <location of QIIME result folder> <location of output folder> <setting file>\n"
    $stderr.puts "-----------------------------------"
    exit
  end
end


usage()
cutoffs = %w(5 25)
matrixFile=File.expand_path(ARGV[0])+"/otu_table.txt"
trimMatrixFile=File.expand_path(ARGV[0])+"/otu_table_trim.txt"
if ! (File.exist?(matrixFile))
    put "otu_table doesn't exist."
    exit
end 

r=File.open(matrixFile,"r")
w=File.open(trimMatrixFile, "w")
r.gets
r.each_line{ |line|
   cols=line.split(/\t/)
   cols.pop
   trimline="" 
   cols.each{|ele|
      trimline << "#{ele}\t"
   }
   trimline.strip!
   w.puts trimline
}
r.close()
w.close()



metahash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

inputFilePath=File.expand_path(ARGV[0])+"/mapping.txt"
inputFile=File.open(inputFilePath,"r")
line=inputFile.gets.chop!
#get meta data names
colnames=line.split("\t")
#curDir="/home2/junm/microbiomeWorkbench/microbiomeWorkbench/"
metanames=[]
for ii in 0...colnames.size
    #puts "meta #{colnames[ii]}"
    metanames.push(colnames[ii])
end

#read in information for each sample
inputFile.each_line{ |line|
  line.chop!
  cols=line.split("\t")
  sampleName=cols[0]
  metadata=[]
  for ii in 1...cols.size
    metahash[metanames[ii]][sampleName]=cols[ii]
  end
}

settinghash={}
File.open(File.expand_path(ARGV[2]),"r").each_line{|line|
   line.strip!
   cols=line.split("\t")
   settinghash[cols[0]]=cols[1]
}

metaarray=settinghash["metaLabels"]
metalabels=metaarray.split(",")
#check featuers in setting file
#for this tool, only metalables are provided
metalabels.each{|feature|
attrhash=metahash[feature]
  #check each cutoff 
  cutoffs.each{ |cutoff|
    #puts cutoffVal = cutoff.to_i
    #optional filtering step if we have really large input
    outDir = File.expand_path(ARGV[1]) + "/RF_Boruta/#{feature}/"
    FileUtils.mkdir_p outDir
    filteredMatrixFile = outDir+"otu_table_#{cutoff}-filtered.txt"
    transMatrixFile=filteredMatrixFile.gsub(/txt/,"trans")
    normMatrixFile = filteredMatrixFile.gsub(/txt/, "norm") 
    rfobject=RandomForestUtils.new(trimMatrixFile,attrhash,feature,outDir) 
    #Filter otu table based on cutoff 
    filteredRF=rfobject.filterFeatureValuesByMinFeatureValue(cutoff.to_i)
    #filteredRF=rfobject.filterFeatureValuesByMinPercent(cutoff.to_i)
    rfobject.printmatrixTofile(filteredRF,filteredMatrixFile)
    #transpose the matrix and add feature value 
    transRF=filteredRF.t
    transRF=rfobject.addmeta(transRF)
    rfobject.printmatrixTofile(transRF,transMatrixFile)  
    #normalize the matrix and prepare input for RandomForest
    normalizedRF=rfobject.normalization(transRF,0,100000)
    rfobject.printmatrixTofile(normalizedRF,normMatrixFile)
    #run Randome Forest
    rfobject.machineLearning(normMatrixFile,cutoff)
    #run Boruta
    rfobject.borutaFeatureSelection(normMatrixFile,cutoff)
  } 
}
