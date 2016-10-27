#!/usr/bin/env ruby
  
require 'brl/microbiome/workbench/RandomForestUtils'
#require '/home/junm/gaussCode/brlheadmicrobiome/RandomForestUtils'
require 'fileutils'
require 'matrix.rb'
require "brl/util/textFileUtil"
require "brl/util/util"


def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--QIIMEfolder','-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--metaLabels','-m', GetoptLong::REQUIRED_ARGUMENT],
                  ]
      progOpts = GetoptLong.new(*optsArray)
      usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      return optsHash
end

 
def usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
   Microbiome workbench run QIIME pipeline 
   
  COMMAND LINE ARGUMENTS:
    --inputTable                         | -f => QIIMEfolder
    --outputFolder                       | -o => outputfolder
    --metaLabels                         | -m => metalabels


 usage:
  run_MachineLearning_ARG.rb -f projecttest/QIIME_result/ -o projecttest/ -m Body_Site 

";
   exit;
end


settinghash=processArguments()

cutoffs = %w(5 25 100 500)
#cutoffs = %w(40)
qiimefolder=File.expand_path(settinghash["--QIIMEfolder"])
orimatrixFile=qiimefolder+"/otu_table.txt"
matrixFile=qiimefolder+"/otu_table.rdp.txt"
rdpfile="#{qiimefolder}/repr_set.fasta.ignore."

if (File.exist?(rdpfile))
  `converttaxo_otu_rdp.rb #{qiimefolder}/repr_set.fasta.ignore. #{orimatrixFile}`
else 
  matrixFile=orimatrixFile
end 

trimMatrixFile=qiimefolder+"/otu_table_trim.txt"
level=settinghash["--levelLabels"]
if ! (File.exist?(matrixFile))
    puts "otu_table doesn't exist."
    exit
end 

r=File.open(matrixFile,"r")
w=File.open(trimMatrixFile, "w")
r.gets
taxohash={}
r.each_line{ |line|
   line.strip!
   cols=line.split(/\t/)
   taxo=cols.pop
   name=cols[0]
   taxohash[name]=taxo
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

inputFilePath=File.expand_path(settinghash["--QIIMEfolder"])+"/mapping.txt"
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


metaarray=settinghash["--metaLabels"]
metalabels=metaarray.split(",")
#check featuers in setting file
#for this tool, only metalables are provided
metalabels.each{|feature|

  outDir = File.expand_path(settinghash["--outputFolder"]) + "/RF_Boruta/#{feature}/"
attrhash=metahash[feature]
  #check each cutoff 
  cutoffs.each{ |cutoff|
    #puts cutoffVal = cutoff.to_i
    #optional filtering step if we have really large input
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
    rfobject.machineLearning(normMatrixFile,cutoff,feature)
    #run Boruta
    rfobject.borutaFeatureSelection(normMatrixFile,cutoff)

 
    valuearray=attrhash.values
    uniqsize=valuearray.uniq.size()
    if(uniqsize==2)
      #combine RF Boruta OTUtable 
      tableprep=normalizedRF.t
      tableforcombine=filteredMatrixFile.gsub(/txt/,"forcombine")
      rfobject.printmatrixTofile(tableprep,tableforcombine)
      impOutStub="#{outDir}/RandomForest/#{feature}-#{cutoff}_sortedImportance.txt"
      impforcombine="#{outDir}/RandomForest/#{feature}-#{cutoff}_sortedImportanceforcombine.txt"
      r=File.open(impOutStub,"r")
      w=File.open(impforcombine,"w")
      w.puts r.gets
      r.each_line{|line|
        line.strip!
        cols=line.split("\t")
        name=cols[0]
        if name =~ /X/
          name.gsub!(/X/,"")
        end
        taxo=taxohash[name]
        #puts "#{name}\t#{taxohash[name]}"
        outputline="#{taxo}\t#{name}"
        for ii in 1..cols.size()
          outputline="#{outputline}\t#{cols[ii]}\t"
        end 
        outputline.strip!
        w.puts outputline
      }
      r.close()
      w.close()
      borutaconfirmfile="#{outDir}/Boruta/Boruta_#{cutoff}_confirmed.txt"
      combinecmd="combine_MLResult.rb #{tableforcombine} #{impforcombine} #{borutaconfirmfile}"
      puts combinecmd
      system(combinecmd)
    end
  }
  `boxPlotAutoGV-taxDepth.rb #{outDir} #{outDir}/graph/ 7`
  `tsvtoxls.rb #{outDir}/RandomForest/ #{feature}`

}
 outDir = File.expand_path(settinghash["--outputFolder"]) + "/RF_Boruta/"
   line=""
   cutoffs.each{|cut|
     line+="#{cut} "
   }
   `randomforest_errorrate.rb #{outDir} #{line}`
  

