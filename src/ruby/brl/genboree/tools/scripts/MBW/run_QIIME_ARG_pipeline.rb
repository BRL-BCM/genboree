#!/usr/bin/env ruby

require "brl/microbiome/workbench/sample_class"
require "fileutils"
require "brl/util/textFileUtil"
require "brl/util/util"



def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--inputTable','-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-z', GetoptLong::REQUIRED_ARGUMENT],
                    ['--otuFastMethod','-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--otuSlowMethod','-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--betaMetrics','-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--alphaMetrics' ,'-a', GetoptLong::REQUIRED_ARGUMENT],
                    ['--assignTaxonomyMethods' ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--assignTaxonomyMinConfidence' ,'-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--alignSeqsMinLen' ,'-l', GetoptLong::REQUIRED_ARGUMENT],
                    ['--runAlphaDiversityFlag' ,'-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--runBetaDiversityFlag' ,'-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--createPhylogeneticTreeFlag' ,'-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--createOTUtableFlag' ,'-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--createHeatmapFlag' ,'-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--createOTUnewtworkFlag' ,'-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--createTaxaSummaries' ,'-q', GetoptLong::REQUIRED_ARGUMENT],
                    ['--runLoopWithNormalizedDataFlag' ,'-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--alignmentMethod' ,'-e', GetoptLong::REQUIRED_ARGUMENT],
                    ['--makeTreeMethod' ,'-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--chimeraSlayerFlag' , '-x', GetoptLong::REQUIRED_ARGUMENT]
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
    --inputTable			 | -u => sampleInputtable
    --outputFolder			 | -z => outputfolder
    --otuFastMethod                      | -f => prefix_suffix
    --otuSlowMethod                      | -s => cdhit
    --betaMetrics                        | -b => binary_chord, binary_euclidean
    --alphaMetrics                       | -a => shannon, berger_parker_d, brillouin_d
    --assignTaxonomyMethods              | -t => rdp
    --assignTaxonomyMinConfidence        | -c => 0.85
    --alignSeqsMinLen                    | -l => 150
    --runAlphaDiversityFlag              | -r => 0
    --runBetaDiversityFlag               | -p => 1
    --createPhylogeneticsTreeFlag        | -i => 1
    --createOTUtableFlag                 | -o => 1
    --createHeatmapFlag                  | -m => 0
    --createOTUnewtworkFlag              | -n => 0
    --createTaxaSummaries                | -q => 0
    --runLoopWithNormalizedDataFlag      | -d => 1
    --alignmentMethod                    | -e => pynast
    --makeTreeMethod                     | -g => fasttree
    --chimeraSlayerFlag			 | -x => 1


 usage:
 run_QIIME_ARG_pipeline.rb -u mockbench_inputtable.txt -z projecttest1/ -f prefix_suffix -s cdhit -b 'binary_chord,binary_euclidean' -a 'shannon,berger_parker_d' -t rdp -c 0.85 -l 150 -r 0 -p 1 -i 1 -o 1 -m 0 -n 0 -q 0 -d 1 -e pynast -g fasttree -x 1

";
   exit;
end 


settinghash=processArguments()

inputFilePath=File.expand_path(settinghash['--inputTable'])
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
  if (line.include?("sampleID"))
    next
  end
  line.chop!
  cols=line.split("\t")
  metadata=[]
  for ii in 0...metanames.size
    metadata.push([metanames[ii]],cols[colnames.index(metanames[ii])])
  end
  sample=Sample.new(cols[colnames.index("sampleID")],cols[colnames.index("sampleName")],cols[colnames.index("barcode")],cols[colnames.index("minseqLength")],cols[colnames.index("minAveQual")], cols[colnames.index("minseqCount")],cols[colnames.index("proximal")],cols[colnames.index("distal")],cols[colnames.index("region")],cols[colnames.index("flag1")],cols[colnames.index("flag2")],cols[colnames.index("flag3")],cols[colnames.index("flag4")],cols[colnames.index("fileLocation")],metadata)
  sampleArray.push(sample)
}


#betaMetrics = %w(binary_chord binary_euclidean)
betaMetric=settinghash["--betaMetrics"]
betaMetrics=betaMetric.split(",")
alphaMetric=settinghash["--alphaMetrics"]
alphaMetrics=alphaMetric.split(",")


metaLabels="\""
metanames.each{|name|
   metaLabels+="#{name},"
}
metaLabels.chop!
metaLabels+="\""


outFolder=File.expand_path(settinghash['--outputFolder'])+"/QIIME_result/"
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
  #create output folder for each sample
  outsampleDir=File.expand_path(settinghash['--outputFolder'])+"/#{sample.sampleName}/"
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
otuFile=outFolder+"otu_table_beforechimera.txt"
alnFolder=outFolder+"aln"
filteredalnFolder=outFolder+"filtered_aln"
FileUtils.mkdir_p  "#{outFolder}/taxa/"
cmd=[]


#Multiple OTU picking
cmd << "time pick_otus.py -m #{settinghash["--otuFastMethod"]} -u 0 -i #{seqfile} -o #{pickedOTUsFolder}"
cmd << "time pick_rep_set.py -i #{pickedOTUsFolder}/seq_otus.txt -f #{seqfile} -o #{pickedOTUsFolder}/repr_set.fasta"
cmd << "time pick_otus.py -m #{settinghash["--otuSlowMethod"]} -i #{pickedOTUsFolder}/repr_set.fasta -o #{pickedOTUsFolder}/cdhit_picked_otus/"
cmd << "time merge_otu_maps.py -i #{pickedOTUsFolder}/seq_otus.txt,#{pickedOTUsFolder}/cdhit_picked_otus/repr_set_otus.txt -o #{outFolder}/otus.txt"
cmd << "time pick_rep_set.py -i #{outFolder}/otus.txt -f #{seqfile} -o #{outFolder}/repr_set.fasta"

#make OTU table 
if(settinghash["--createOTUtableFlag"].to_i==1)
  cmd << "time assign_taxonomy.py -i #{outFolder}/repr_set.fasta -m #{settinghash["--assignTaxonomyMethods"]} -o #{rdpFolder} -c #{settinghash["--assignTaxonomyMinConfidence"]}"
  cmd << "time make_otu_table.py -i #{outFolder}/otus.txt -t #{rdpFolder}/repr_set_tax_assignments.txt -o #{otuFile}"
end

cmd << "time align_seqs.py -i #{outFolder}/repr_set.fasta -o #{alnFolder} -t /cluster.shared/local/apps/QIIMEsupplementary/core_set_aligned.fasta.imputed -e #{settinghash["--alignSeqsMinLen"]} -m #{settinghash["--alignmentMethod"]}"

#run chimeraSlayer 
if(settinghash["--chimeraSlayerFlag"].to_i==1)
  
  cmd << "/cluster.shared/local/apps/microbiomeutil-20101212/microbiomeutil_20101212/ChimeraSlayer/ChimeraSlayer.pl --query_NAST #{alnFolder}/repr_set_aligned.fasta --exec_dir #{alnFolder}"
  cmd << "removechimera.rb #{otuFile} #{alnFolder}/repr_set_aligned.fasta.CPS.CPC"
else
  ottufile=otuFile.gsub(/_beforechimera/,"")
  cmd << "cp #{otuFile} #{ottufile}" 
end 
  otuFile=outFolder+"otu_table.txt"

if(settinghash["--createHeatmapFlag"].to_i==1)
  cmd << "time make_otu_heatmap_html.py -i #{otuFile} -o #{outFolder}/otu_heatmap/"
end

if(settinghash["--createOTUnetworkFlag"].to_i==1)
  cmd << "time make_otu_network.py -m #{mapfile} -i #{otuFile} -o #{outFolder}/otu_network/"
end

if(settinghash["--createTaxaSummaries"].to_i==1)
#summarize otu at different level
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l2.txt -L 2 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l3.txt -L 3 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l4.txt -L 4 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l5.txt -L 5 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l6.txt -L 6 -m  #{mapfile}"
cmd << "time summarize_taxa.py -i #{otuFile} -o #{outFolder}/taxa/otu_l7.txt -L 7 -m  #{mapfile}"
end 

#make phylogenetic tree
if (settinghash["--createPhylogeneticTreeFlag"].to_i==1)
# cmd << "time align_seqs.py -i #{outFolder}/repr_set.fasta -o #{alnFolder} -t /cluster.shared/local/apps/QIIMEsupplementary/core_set_aligned.fasta.imputed -e #{settinghash["--alignSeqsMinLen"]} -m #{settinghash["--alignmentMethod"]}"
  cmd << "time filter_alignment.py -m /cluster.shared/local/apps/QIIMEsupplementary/lanemask_in_1s_and_0s -i #{alnFolder}/repr_set_aligned.fasta -o #{filteredalnFolder}"
  cmd << "time make_phylogeny.py -t #{settinghash["--makeTreeMethod"]} -o #{filteredalnFolder}/rep_set_aligned.tre -l #{filteredalnFolder}/rep_set_tree.log -i #{filteredalnFolder}/repr_set_aligned_pfiltered.fasta"
end

cmd << "normQotu.rb #{otuFile} 1"
normOtuFile=otuFile.gsub(/\.txt/,"-normalized.txt")
otuFiles=[]
otuFiles<< otuFile
if (settinghash["--runLoopWithNormalizedDataFlag"].to_i==1)
 otuFiles<< normOtuFile
end


#make PCoA plots 
if (settinghash["--runBetaDiversityFlag"].to_i==1)
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
      cmd << "time principal_coordinates.py -i #{metricFolder}/#{metric}_otu_table#{normStub}.txt -o #{metricFolder}/#{metric}_coords#{normStub}.txt"
      cmd << "time make_2d_plots.py -i #{metricFolder}/#{metric}_coords#{normStub}.txt -m #{mapfile} -o #{plotDir}/#{metric}_2d-all/ -b #{metaLabels}"
      cmd << "time make_3d_plots.py -i #{metricFolder}/#{metric}_coords#{normStub}.txt -m #{mapfile} -o #{plotDir}/#{metric}_3d-all/ -b #{metaLabels}"
      #cmd << "time ruby /home1/riehle/DYNAlabelHTML-q110.rb #{plotDir}/#{metric}_2d-all/ /home1/riehle/labelfile.txt"
    }
  }
end

cmd.each{|runCmd|
 puts runCmd
 system("#{runCmd}")
}

#generate circular phylogenetic tree graph
`run_RDP_2.2.rb #{outFolder}/repr_set.fasta #{outFolder}`
metanames.each{|meta|
  `generate_taxoforitol.rb #{outFolder}/repr_set.fasta.ignore. #{filteredalnFolder} #{filteredalnFolder}/rep_set_aligned.tre #{outFolder}/mapping.txt #{outFolder}/otu_table.txt #{meta}`
}

