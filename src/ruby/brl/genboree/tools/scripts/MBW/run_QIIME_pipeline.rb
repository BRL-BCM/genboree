#!/usr/bin/env ruby

require "brl/microbiome/workbench/sample_class"
require "fileutils"

def usage()
  if ARGV.size != 3 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_QIIME_pipeline.rb <location of input table file> <location of output folder> <setting file>\n"
    $stderr.puts "-----------------------------------"
    exit
  end
end



usage()
inputFilePath=File.expand_path(ARGV[0])
inputFile=File.open(inputFilePath,"r")
line=inputFile.gets.chop!
colnames=line.split("\t")
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

settinghash={}
File.open(File.expand_path(ARGV[2]),"r").each_line{|line|
  line.strip!
  cols=line.split("\t")
  settinghash[cols[0]]=cols[1]
}


#betaMetrics = %w(binary_chord binary_euclidean)
betaMetric=settinghash["betaMetrics"]
alphaMetric=settinghash["alphaMetrics"]
betaMetrics=betaMetric.split(",")
alphaMetrics=alphaMetric.split(",")
metaLabels="\""
metanames.each{|name|
   metaLabels+="#{name},"
}
metaLabels.chop!
metaLabels+="\""


outFolder=File.expand_path(ARGV[1])+"/QIIME_result/"
FileUtils.mkdir_p outFolder
mapfile=outFolder+"mapping.txt"
mapWrite=File.open(mapfile,"w")
mapWrite.print "#SampleID\tBarcodeSequence\tNullLinkerPrimerSequence\t"
metanames.each{|key|
  mapWrite.print "#{key}\t"
}
mapWrite.print "\n"
seqfile=outFolder+"seq.fna"
seqWrite=File.open(seqfile,"w")
count=0
sampleArray.each{|sample|
  #creat output folder for each sample
  outsampleDir=File.expand_path(ARGV[1])+"/#{sample.sampleName}/"
  fafiltered="#{outsampleDir}/#{sample.sampleName}.fa"
  mapWrite.print "#{sample.sampleName}\t#{sample.barcode}\t#{sample.proximal}\t"
  1.step(sample.metadata.size,2){|x|
    mapWrite.print "#{sample.metadata[x]}\t"
  }
  mapWrite.print "\n"
  seqRead=File.open(fafiltered,"r")
  seqRead.each_line{ |line|
    head = line.gsub(/>/, "")
    head = head.gsub(/\s+/, "")
    seqWrite.puts ">#{sample.sampleName}_#{count} #{head} orig=bc=#{sample.barcode} new_bc=#{sample.barcode} bc_diffs=0"
    seqWrite.puts seqRead.gets.upcase
    count+=1
  }
}
mapWrite.close()
seqWrite.close()
pickedOTUsFolder=outFolder+"prefix_picked_otus"
rdpFolder=outFolder+"rdp"
otuFile=outFolder+"otu_table.txt"
alnFolder=outFolder+"aln"
filteredalnFolder=outFolder+"filtered_aln"
FileUtils.mkdir_p  "#{outFolder}/taxa/"
cmd=[]


#Multiple OTU picking
cmd << "time pick_otus.py -m #{settinghash["otuFastMethod"]} -u 0 -i #{seqfile} -o #{pickedOTUsFolder}"
cmd << "time pick_rep_set.py -i #{pickedOTUsFolder}/seq_otus.txt -f #{seqfile} -o #{pickedOTUsFolder}/repr_set.fasta"
cmd << "time pick_otus.py -m #{settinghash["otuSlowMethod"]} -i #{pickedOTUsFolder}/repr_set.fasta -o #{pickedOTUsFolder}/cdhit_picked_otus/"
cmd << "time merge_otu_maps.py -i #{pickedOTUsFolder}/seq_otus.txt,#{pickedOTUsFolder}/cdhit_picked_otus/repr_set_otus.txt -o #{outFolder}/otus.txt"
cmd << "time pick_rep_set.py -i #{outFolder}/otus.txt -f #{seqfile} -o #{outFolder}/repr_set.fasta"

#make OTU table 
if(settinghash["createOTUtableFlag"].to_i==1)
  cmd << "time assign_taxonomy.py -i #{outFolder}/repr_set.fasta -m #{settinghash["assignTaxonomyMethod"]} -o #{rdpFolder} -c #{settinghash["assignTaxonomyMinConfidence"]}"
  cmd << "time make_otu_table.py -i #{outFolder}/otus.txt -t #{rdpFolder}/repr_set_tax_assignments.txt -o #{otuFile}"
end

if(settinghash["createHeatmapFlag"].to_i==1)
  cmd << "time make_otu_heatmap_html.py -i #{otuFile} -o #{outFolder}/otu_heatmap/"
end

if(settinghash["createOTUnetworkFlag"].to_i==1)
  cmd << "time make_otu_network.py -m #{mapfile} -i #{otuFile} -o #{outFolder}/otu_network/"
end

if(settinghash["createTaxaSummaries"].to_i==1)
#summarize otu at different level
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l2.txt -L 2 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l3.txt -L 3 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l4.txt -L 4 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l5.txt -L 5 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l6.txt -L 6 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l7.txt -L 7 -m  #{mapfile}"
end 

#make phylogenetic tree
if (settinghash["createPhylogeneticTreeFlag"].to_i==1)
  cmd << "time align_seqs.py -i #{outFolder}/repr_set.fasta -o #{alnFolder} -t /cluster.shared/local/apps/QIIMEsupplementary/core_set_aligned.fasta.imputed -e #{settinghash["alignSeqsMinLen"]} -m #{settinghash["alignmentMethod"]}"
  cmd << "time filter_alignment.py -m /cluster.shared/local/apps/QIIMEsupplementary/lanemask_in_1s_and_0s -i #{alnFolder}/repr_set_aligned.fasta -o #{filteredalnFolder}"
  cmd << "time make_phylogeny.py -t #{settinghash["makeTreeMethod"]} -o #{filteredalnFolder}/rep_set_aligned.tre -l #{filteredalnFolder}/rep_set_tree.log -i #{filteredalnFolder}/repr_set_aligned_pfiltered.fasta"
end

cmd << "ruby /home/junm/microbiomeWorkbench/brlheadmicrobiome/normQotu.rb #{otuFile} 1"
normOtuFile=otuFile.gsub(/\.txt/,"-normalized.txt")
otuFiles=[]
otuFiles<< otuFile
if (settinghash["runLoopWithNormalizedDataFlag"].to_i==1)
 otuFiles<< normOtuFile
end


#make PCoA plots 
if (settinghash["runBetaDiversityFlag"].to_i==1)
 otuFiles.each{ |otuFileLoop|
    #make subdirectory for otu method in plots
    normStub = "-normalized" if otuFileLoop =~ /normalized/
    plotDir = outFolder + "plots/cdhit#{normStub}/"
    FileUtils.mkdir_p plotDir

    #run alpha rarefaction 
     if(settinghash["runAlphaDiversityFlag"].to_i==1)
    alphafolder=outFolder+"alphaRarefaction/"
    FileUtils.mkdir_p alphafolder
    cmd << "time alpha_rarefaction.py -o #{alphafolder} -i #{otuFileLoop} -t #{filteredalnFolder}/rep_set_aligned.tre -m #{mapfile} -p custom_parameters.txt -f" if otuFileLoop !~ /normalized/ 
     end

    betaMetrics.each{ |metric|
    metricFolder=outFolder+"#{metric}_dist/"
      cmd << "time beta_diversity.py -i #{otuFileLoop} -m #{metric} -o #{metricFolder}  -t #{filteredalnFolder}/rep_set_aligned.tre"
      cmd << "time principal_coordinates.py -i #{metricFolder}/#{metric}_otu_table.txt -o #{metricFolder}/#{metric}_coords.txt"
      cmd << "time make_2d_plots.py -i #{metricFolder}/#{metric}_coords.txt -m #{mapfile} -o #{plotDir}/#{metric}_2d-all/ -b #{metaLabels}"
      cmd << "time make_3d_plots.py -i #{metricFolder}/#{metric}_coords.txt -m #{mapfile} -o #{plotDir}/#{metric}_3d-all/ -b #{metaLabels}"
      #cmd << "time ruby /home1/riehle/DYNAlabelHTML-q110.rb #{plotDir}/#{metric}_2d-all/ /home1/riehle/labelfile.txt"
    }
  }
end
cmd.each{|runCmd|
 puts runCmd
 system("#{runCmd}")
}



