#!/usr/bin/env ruby 

require "fileutils"
#require "/home/junm/gaussCode/brlheadmicrobiome/sample_class"
require "brl/microbiome/workbench/sample_class"

def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_readsfilter.rb <location of input table file> <location of output folder> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end


usage()
inputFilePath=File.expand_path(ARGV[0])
inputFile=File.open(inputFilePath,"r")
header=inputFile.gets.chop!
colnames=header.split("\t")
#curDir="/home2/junm/microbiomeWorkbench/microbiomeWorkbench/"
metapos=colnames.index("fileLocation")+1
metanames=[]
for ii in metapos...colnames.size
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
}
inputFile.close()

reads_array=[]

sampleArray.each{|sample|
  #creat output folder for each sample
  basename=File.basename(sample.fileLocation)
  basename.gsub!(/.(sra|sff)/,"")
  outSffDir=File.expand_path(ARGV[1])+"/#{basename}/" 
  fastaname="#{outSffDir}#{basename}.fasta"
  if !(File.exist?(fastaname))
     FileUtils.mkdir_p outSffDir
    # puts cmdCovert="ruby #{curDir}convert_SRA.rb #{sample.fileLocation} #{outSffDir}"
     puts cmdCovert="convert_SRA.rb #{sample.fileLocation} #{outSffDir}"
     system("#{cmdCovert}")
  else 
     puts "#{outSffDir} exists"
  end 
  outsampleDir=File.expand_path(ARGV[1])+"/#{sample.sampleName}/"
  FileUtils.mkdir_p outsampleDir
  #execute command for deconvolute and quality filtering FASTA file
  fqFileLocation="#{outSffDir}#{basename}.fq"
   #puts cmdQual="run_Blast_Trim_FASTA.rb #{fqFileLocation}  #{outsampleDir} #{sample.barcode} #{sample.sampleName} #{sample.minseqLength} #{sample.minAveQual} #{sample.proximal} #{sample.distal} #{sample.flag1} #{sample.flag2} #{sample.flag3} #{sample.flag4}"
  puts cmdQual="run_Blast_Trim_FASTA.rb #{fqFileLocation}  #{outsampleDir} #{sample.barcode} #{sample.sampleName} #{sample.minseqLength} #{sample.minAveQual} #{sample.proximal} #{sample.distal} #{sample.flag1} #{sample.flag2} #{sample.flag3} #{sample.flag4}" 

  system("#{cmdQual}")
  puts "Done with #{sample.sampleName}"

  faFiltered="#{outsampleDir}/#{sample.sampleName}.fa"
  seqfiltfile="#{outsampleDir}/#{sample.sampleName}.filter"
  #output stat file
  sample.outputStat("#{outsampleDir}/#{sample.sampleName}_stat","#{faFiltered}","#{seqfiltfile}")
  
  seqCount=0
  File.open(faFiltered,"r").each{|line|
    if line =~ /^>/
      seqCount+=1
    end 
  }
  puts seqCount
  if seqCount > sample.minseqCount
    reads_array << sample.sampleName
  end
}

outTablePath=File.expand_path(ARGV[1])+"/update_inputTable.txt"

inputFile=File.open(inputFilePath,"r")
outTable=File.open(outTablePath,"w")
outTable.puts inputFile.gets
inputFile.each{|line|
   line.strip!
   reads_array.each{|samplename|
      if line =~ /#{samplename}/
         outTable.puts line
      end
   }
}
inputFile.close()
outTable.close()

outputDir=File.expand_path(ARGV[1])
metaline=""
metanames.each{|meta|
  metaline+="#{meta} "
}
puts metaline

`generate_seqmetrics.rb #{outputDir} #{metaline}`

