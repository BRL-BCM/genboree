#!/usr/bin/env ruby
#taxoinfile=repr_set_tax_assignments.txt"
#oritreefile=.tre file"
#outdatafile=datafile for itol"
#outtreefile=tree file after replacement"

inDir=ARGV[0]
taxoninfilepath="#{inDir}/rdp/repr_set_tax_assignments.txt"
oritreefilepath="#{inDir}/filtered_aln/rep_set_aligned.tre"
parsedtreefilepath="#{inDir}/filtered_aln/rep_set_aligned.parsed.tre"
outtreefilepath="#{inDir}/filtered_aln/rep_set_aligned.itol.tree"
mappingfile="#{inDir}/mapping.txt"


parsecmd="python /home/junm/microbiomeWorkbench/brlheadmicrobiome/newickParse.py #{oritreefilepath}"

puts parsecmd
system(parsecmd)

taxoinfile=File.open(taxoninfilepath,"r")
treefile=File.open(parsedtreefilepath,"r")
outtreefile=File.open(outtreefilepath,"w")
inputfile=File.open(mappingfile,"r")

metahash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
line=inputfile.gets.chop!
#get meta data names
colnames=line.split("\t")
#curDir="/home2/junm/microbiomeWorkbench/microbiomeWorkbench/"
metanames=[]
for ii in 0...colnames.size
    #puts "meta #{colnames[ii]}"
    metanames.push(colnames[ii])
end

#read in information for each sample
inputfile.each_line{ |line|
  line.strip!
  cols=line.split("\t")
  sampleName=cols[0]
  metadata=[]
  for ii in 1...cols.size
    metahash[metanames[ii]][sampleName]=cols[ii]
  end
}
inputfile.close()

lookuptable={}
idhash={}
taxoinfile.each_line{|line|
        line.strip!
	cols=line.split(" ")
        idnum=cols[0]
        idname=cols[1] 
        idname=idname.gsub!(/_\d+$/,"")
        rdp=cols[2]
        rdpcols=rdp.split(";")
        if(rdpcols.size==9)
          taxo=rdpcols[8].gsub("\"","")
        else
          taxo=rdpcols.last.gsub("\"","")
        end
        lookuptable[idnum]="#{taxo}-#{idnum}"
        idhash[idnum]=idname
}
taxoinfile.close()

metanames.each{|feature|
    attrhash=metahash[feature]
    uniqsize=attrhash.values.uniq.size()
    metalabels=attrhash.values.uniq
    if (uniqsize==2 or uniqsize==3)
      outdatafilepath="#{inDir}/filtered_aln/rep_set_aligned.#{feature}.datafile"
      outdatafile=File.open(outdatafilepath,"w")
      if(uniqsize==2)
       idhash.each{|k,v|
         idnum=k
         meta=attrhash[v]
         idtaxo=lookuptable[k]
        # puts "#{meta}\t#{idnum}\t#{idtaxo}\t#{metalabels[0]}"
         if(meta=~/#{metalabels[0]}/)
             color="#ffaaaa" 
         elsif (meta=~/#{metalabels[1]}/)
             color="#aaffaa"
         end
         outdatafile.puts "#{idtaxo}\trange\t#{color}\t#{meta}"
       }
      elsif (uniqsize==3)
       idhash.each{|k,v|
         idnum=k
         meta=attrhash[v]
         idtaxo=lookuptable[k]
         if(meta=~/#{metalabels[0]}/)
             color="#ffaaaa"
         elsif (meta=~/#{metalabels[1]}/)
             color="#aaffaa"
         elsif (meta=~/#{metalabels[2]}/)
             color="#aaaaff"
         end
         outdatafile.puts "#{idtaxo}\trange\t#{color}\t#{meta}"
       }
       end
       outdatafile.close()
    end
}



line=treefile.gets
cols=line.split(/\'/)

cols.each{|col|
 if lookuptable.has_key?(col)
   outtreefile.print lookuptable[col]
 else
   outtreefile.print col
 end
}
outtreefile.close()

