#!/usr/bin/env ruby
#You can obtain the command line version of of the software using Mercurial:
#hg clone http://huttenhower.sph.harvard.edu/hg/lefse
#You need to have the following prerequisites installed:
#- R
#- the splines, stats4, survival, mvtnorm, modeltools, coin, and MASS
#library in R. (we use the LDA implemantation in R which is in the MASS
#library having the other listed libraries as prerequisites)
#- the rpy2 (version >= 2.1), argparse, and numpy python library (if
#you have a version of R you compiled by yourself it can be tricky to
#install rpy2 which is the library connecting python and R)
#- Matplotlib 1.01 or higher 

require "fileutils"
require "brl/util/textFileUtil"
require "brl/util/util"


def processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--QIIMEfolder','-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--class','-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--subclass','-s', GetoptLong::REQUIRED_ARGUMENT],
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
   Microbiome workbench run LEfSe program
   
  COMMAND LINE ARGUMENTS:
    --inputTable                         | -f => QIIMEfolder (or any folder has otu_table.txt and mapping.txt files)
    --outputFolder                       | -o => outputfolder
    --class                              | -c => class
    --subclass				 | -s => subclass (if there is no subclass needed, just type nosubclass)

 usage:
  run_LEfSe_ARG.rb -f projecttest/QIIME_result/ -o projecttest/ -c Body_Site -s ethnicity

";
   exit;
end

def prepareLEfSe(inotu,inmapping,outtaxo,meta,subclass)

  mheader=inmapping.gets.strip!
  mheadercols=mheader.split("\t")
  metapos=mheadercols.index(meta)
  subpos=mheadercols.index(subclass)
  metahash={}
  subhash={}
  nosub=2
  inmapping.each{|line|
    line.strip!
    cols=line.split("\t")
    metahash[cols[0]]=cols[metapos]
    if ! subpos.nil?
      subhash[cols[0]]=cols[subpos]
    else 
      subhash[cols[0]]="NA"
      nosub=1
    end
  }
  header1=inotu.gets
  header=inotu.gets.strip
  headercols=header.split("\t")
  headercols.delete_at(0)
  headercols.pop
  count=0
  poshash={}
  headercols.each{|ele|
    poshash[count]=ele
    count+=1
  }
  rdphash={}
  taxohash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
  inotu.each{|line|
    line.strip!
    cols=line.split("\t")
    otuid=cols[0]
    cols.delete_at(0)
    taxo=cols.pop
    if taxo !~ /Root/
      taxo="Root;#{taxo}"
    end 
    rdphash[otuid]=taxo
    taxocols=taxo.split(";")
    taxoid="Root"
    for ii in 1...taxocols.size()
      if ! taxocols[ii].nil? 
         taxoid="#{taxoid}|#{taxocols[ii]}"
         if ! taxohash.has_key?(taxoid)
           poshash.each{|k,v|
             taxohash[taxoid][v]=0
             taxohash[otuid][v]=0
           }
         end
      end
      for jj in 0...cols.size()
        sampleid=poshash[jj]
        taxohash[taxoid][sampleid] += cols[jj].to_f
      end 
    end
    for jj in 0...cols.size()
      sampleid=poshash[jj]
      taxohash[otuid][sampleid] = cols[jj].to_f
    end 
  }

  sumhash={}
  poshash.each{|k,v|
    sumhash[v]=0
  }

  taxohash.each{|taxo, samplehash|
    if taxo !~ /^Root/
      samplehash.each{|sample,count|
        sumhash[sample]+=count
      }
    end 
  }

  header.gsub!(/#OTU ID/,"id")
  header.gsub!(/Consensus Lineage/,"")
  metaline=meta
  subline=subclass
  poshash.sort.each{|k,v|
    metaline="#{metaline}\t#{metahash[v]}"
    subline="#{subline}\t#{subhash[v]}"
  }
  outtaxo.puts metaline
  outtaxo.puts subline
  outtaxo.puts header

  taxohash.sort.each{|taxo,samplehash|
    if taxo != /^Root/
      modtaxo=rdphash[taxo]
      if ! modtaxo.nil?
        modtaxo.gsub!(/;/,"|")
        modtaxo.gsub!(/"/,"")
        taxo="#{modtaxo}-#{taxo}"
      end
    end 
    line="#{taxo}"
    poshash.sort.each{|k,v|
    value=samplehash[v]/sumhash[v]
      line="#{line}\t#{value}"
    }
    outtaxo.puts line
  }
  outtaxo.close()
  inotu.close()
  inmapping.close()
  return nosub
end

def runLEfSe(outtaxofilepath,outdir)
  outinfile=outtaxofilepath.gsub(/.txt/,".in")
  outresfile=outtaxofilepath.gsub(/.txt/,".res")
  outpng=outtaxofilepath.gsub(/.txt/,".png")
  outcladogram=outtaxofilepath.gsub(/.txt/,".cladogram.png")
  outfolder="#{outdir}/biomarkers/"
  FileUtils.mkdir_p outfolder
#  puts "format_input.py #{outtaxofilepath} #{outinfile} -c 1 -s #{nosub} -u 3 -o 1000000" 
#  puts "run_lefse.py #{outinfile} #{outresfile}"
#  puts "plot_res.py #{outresfile} #{outpng}"
#  puts "plot_features.py #{outinfile} #{outresfile} #{outfolder}"
  `format_input.py #{outtaxofilepath} #{outinfile} -c 1 -s 2 -u 3 -o 1000000`
  `run_lefse.py #{outinfile} #{outresfile}`
  `plot_res.py #{outresfile} #{outpng}`
  `plot_cladogram.py #{outresfile} #{outcladogram} --format png`
  `plot_features.py #{outinfile} #{outresfile} #{outfolder}`
end


settinghash=processArguments()
qiimefolder=File.expand_path(settinghash["--QIIMEfolder"])
inotupath=qiimefolder+"/otu_table.txt"
inmappingpath=qiimefolder+"/mapping.txt"
meta=settinghash["--class"]
subclass=settinghash["--subclass"]
outdir=File.expand_path(settinghash["--outputFolder"])+"/LEfSe/#{meta}_#{subclass}/"
FileUtils.mkdir_p outdir
outtaxofilepath="#{outdir}/#{meta}_LEfSe_table.txt"
inotu=File.open(inotupath,"r")
inmapping=File.open(inmappingpath,"r")
outtaxo=File.open(outtaxofilepath,"w")
nosub=prepareLEfSe(inotu,inmapping,outtaxo,meta,subclass)
if nosub == 1
  puts "no subclass is selected."
end
runLEfSe(outtaxofilepath,outdir)

