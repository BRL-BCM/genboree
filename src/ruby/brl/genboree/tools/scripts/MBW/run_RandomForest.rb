#!/usr/bin/env ruby

#$LOAD_PATH << '/cluster.shared/local/lib/ruby/site_ruby/1.8/brl/microbiome/workbench'   
require 'brl/microbiome/workbench/RandomForestUtils'
require 'fileutils'
require 'matrix.rb'
require 'brl/microbiome/workbench/sample_class'
  
def usage()
  if ARGV.size != 3 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_RandomForest.rb <location of input table file> <location of output folder> <setting file>\n"
    $stderr.puts "-----------------------------------"
    exit
  end
end


usage()
cutoffs = %w(5 25)
matrixFile=File.expand_path(ARGV[1])+"/QIIME_result/otu_table.txt"
trimMatrixFile=File.expand_path(ARGV[1])+"/QIIME_result/otu_table_trim.txt"
if ! (File.exist?(matrixFile))
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

inputFilePath=File.expand_path(ARGV[0])
inputFile=File.open(inputFilePath,"r")
line=inputFile.gets.chop!
#get meta data names
colnames=line.split("\t")
#curDir="/home2/junm/microbiomeWorkbench/microbiomeWorkbench/"
metapos=colnames.index("fileLocation")+1
metanames=[]
for ii in metapos...colnames.size
    puts "meata #{colnames[ii]}"
    metanames.push(colnames[ii])
end


sampleArray=[]
#read in information for each sample
inputFile.each_line{ |line|
  line.chop!
  cols=line.split("\t")
  metadata=[]
  for ii in 0...metanames.size
    metadata.push([metanames[ii]],cols[colnames.index(metanames[ii])])
  end
  sample=Sample.new(cols[colnames.index("sampleID")],cols[colnames.index("sampleName")],cols[colnames.index("barcode")],cols[colnames.index("minseqLength")],cols[colnames.index("minAveQual")], cols[colnames.index("minseqCount")],cols[colnames.index("proximal")],cols[colnames.index("distal")],cols[colnames.index("region")],cols[colnames.index("flag1")],cols[colnames.index("flag2")],cols[colnames.index("flag3")],cols[colnames.index("flag4")],cols[colnames.index("fileLocation")],metadata)
  sampleArray.push(sample)
  #build metahash to store features
  0.step(metadata.size-1,2){|x|
       y=x/2
      # puts "#{metanames[y]} #{sample.sampleName} #{metadata[x+1]}"
       metahash[metanames[y]][sample.sampleName]=metadata[x+1]     
  }
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
