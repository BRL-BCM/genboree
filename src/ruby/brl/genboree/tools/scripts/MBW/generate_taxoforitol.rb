#!/usr/bin/env ruby

#generate colordata.file based on rdp classification result
#infile: mapping.txt otu.txt newick.tree
#output: colordata.file legned.file for itol

class Sample
  def initialize(line)
    cols=line.split("\t")
    @sampleID=cols[0]
    if line =~ /class/
      @classname=cols[cols.index("class")-1].gsub("\"","")
    else
      @classname="NA"
    end
    if line =~ /order/
      @ordername=cols[cols.index("order")-1].gsub("\"","")
    else 
      @ordername="NA"
    end
    if line =~ /family/
      @familyname=cols[cols.index("family")-1].gsub("\"","")
    else
      @familyname="NA"   
    end
    if line =~ /genus/
      @genusname=cols[cols.index("genus")-1].gsub("\"","")
    else 
      @genusname="NA"
    end   
  end
  attr_reader :sampleID, :classname, :ordername, :familyname, :genusname
end

colorarray=["green","red","blue","yellow","pink","gray","purple","earth"]

colorhash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

colorhash["green"]["1"]="#66CC00"
colorhash["green"]["2"]="#66CD00"
colorhash["green"]["3"]="#00FF00"
colorhash["green"]["4"]="#669900"
colorhash["green"]["5"]="#33CC66"
colorhash["green"]["6"]="#66CC66"
colorhash["green"]["7"]="#00FF00"
colorhash["green"]["8"]="#66FF66"
colorhash["green"]["9"]="#99FF66"
colorhash["green"]["10"]="#99CC99"
colorhash["red"]["1"]="#FF0000"
colorhash["red"]["2"]="#8B0000"
colorhash["red"]["3"]="#EE6363"
colorhash["red"]["4"]="#DB2929"
colorhash["red"]["5"]="#FF4040"
colorhash["red"]["6"]="#DD4492"
colorhash["red"]["7"]="#AF4035"
colorhash["red"]["8"]="#CC3232"
colorhash["red"]["9"]="#FFC1C1"
colorhash["red"]["10"]="#FF6347"
colorhash["blue"]["1"]="#000080"
colorhash["blue"]["2"]="#330099"
colorhash["blue"]["3"]="#0000FF"
colorhash["blue"]["4"]="#3300CC"
colorhash["blue"]["5"]="#336699"
colorhash["blue"]["6"]="#3399FF"
colorhash["blue"]["7"]="#3366FF"
colorhash["blue"]["8"]="#33CCFF"
colorhash["blue"]["9"]="#99FFFF"
colorhash["blue"]["10"]="#99CCFF"
colorhash["yellow"]["1"]="#FFCC00"
colorhash["yellow"]["2"]="#FF9900"
colorhash["yellow"]["3"]="#FFCC66"
colorhash["yellow"]["4"]="#EEEE00"
colorhash["yellow"]["5"]="#FFFF00"
colorhash["yellow"]["6"]="#FFFF66"
colorhash["yellow"]["7"]="#FFCC99"
colorhash["yellow"]["8"]="#FFEBCD"
colorhash["orange"]["1"]="#FF6600"
colorhash["orange"]["2"]="#FF7256"
colorhash["orange"]["3"]="#FF8247"
colorhash["orange"]["4"]="#FF8C69"
colorhash["orange"]["5"]="#FFA07A"
colorhash["orange"]["6"]="#FFA07A"
colorhash["pink"]["1"]="#FF00CC"
colorhash["pink"]["2"]="#FF1493"
colorhash["pink"]["3"]="#FF66FF"
colorhash["pink"]["4"]="#FF69B4"
colorhash["pink"]["5"]="#FF6666"
colorhash["pink"]["6"]="#FF99CC"
colorhash["earth"]["1"]="#990066"
colorhash["earth"]["2"]="#996600"
colorhash["earth"]["3"]="#6600FF"
colorhash["earth"]["4"]="#CC9900"
colorhash["earth"]["5"]="#CC9966"
colorhash["earth"]["6"]="#8B668B"
colorhash["earth"]["7"]="#996666"
colorhash["earth"]["8"]="#8B1A1A"
colorhash["earth"]["9"]="#660000"
colorhash["gray"]["1"]="#999999"
colorhash["gray"]["2"]="#666666"
colorhash["gray"]["3"]="#CCCCCC"
colorhash["gray"]["4"]="#000000"
colorhash["gray"]["5"]="#336666"
colorhash["purple"]["1"]="#CC66FF"
colorhash["purple"]["2"]="#CC00FF"
colorhash["purple"]["3"]="#9966FF"
colorhash["purple"]["4"]="#9900FF"
colorhash["purple"]["5"]="#9966CC"
colorhash["purple"]["6"]="#9999FF"
colorhash["purple"]["7"]="#DA70D6"


infile=File.open(ARGV[0],"r")
outdir=File.expand_path(ARGV[1])
oritreefilepath=ARGV[2]
mappingfilepath=ARGV[3]
otutablepath=ARGV[4]
meta=ARGV[5]

outdatafile="#{outdir}/color_taxo_data_file"
outlegendfile="#{outdir}/color_taxo_legend_file"
parsedtreefilepath="#{outdir}/rep_set_aligned.parsed.tre"
outtreefilepath="#{outdir}/rep_set_aligned_itol_tre"
outwhitefilepath="#{outdir}/white_file"
outmetafilepath="#{outdir}/color_#{meta}_data_file"
outconfigfilepath="#{outdir}/config_upload_#{meta}.txt"
exportfilepath="#{outdir}/export_#{meta}.txt"
exportpdfpath="#{outdir}/export_#{meta}.pdf"
outtempfile="#{outdir}/tmp.file"

outdata=File.open(outdatafile,"w")
outlegend=File.open(outlegendfile,"w")
outwhite=File.open(outwhitefilepath,"w")
outmeta=File.open(outmetafilepath,"w")
mappingfile=File.open(mappingfilepath,"r")
otutablefile=File.open(otutablepath,"r")
outconfigfile=File.open(outconfigfilepath,"w")
exportfile=File.open(exportfilepath,"w")

samplearray=[]
origcount=0
infile.each{|line|
   line.strip!
   sample=Sample.new(line)
   samplearray << sample
   origcount+=1
}


taxohash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
samplearray.each{|sample|
 # if ! taxohash.has_key?(sample.ordername)
  if ! taxohash.has_key?(sample.classname)
    taxoarray=[]
    taxoarray << sample
   # taxohash[sample.ordername][sample.familyname]=taxoarray
     taxohash[sample.classname][sample.familyname]=taxoarray 
 else
   # if ! taxohash[sample.ordername].has_key?(sample.familyname)
    if ! taxohash[sample.classname].has_key?(sample.familyname)
      taxoarray=[]
      taxoarray << sample
    #  taxohash[sample.ordername][sample.familyname]=taxoarray
      taxohash[sample.classname][sample.familyname]=taxoarray
    else 
    #  taxohash[sample.ordername][sample.familyname] << sample
       taxohash[sample.classname][sample.familyname] << sample
   end
  end
}


# check apropriate cutoff 
cutoff=1
count=100
classhash={}
total=0
percent=100
while count>25 or percent>85
  classhash.clear
  count=0
  total=0
  taxohash.each{|classname,familyarray|
  #  puts ordername
    classfamilyarray=[] 
    familyarray.each{|familyname,samplearray|
    if samplearray.size() > cutoff
  #    puts "\t#{familyname}\t#{samplearray.size()}"
      count+=1
      classfamilyarray << familyname
      total+=samplearray.size()
    end    
    }
    if classfamilyarray.size()>0
       classhash[classname]=classfamilyarray
    end
  }
  percent=total*100/origcount
  cutoff+=3
end
 
puts "num of family: #{count}"
puts "percent included: #{percent}"

classarray=[]
classhash.sort_by{|k,v| v.size()}.each{|k,v|
  classarray << k
  puts k
  v.each{|samplename|
    puts "\t#{samplename}"
  }
}
classarray.reverse!


#assign colours to each family based on their class
familyhash={}
colorcount=0
earthcount=1
classarray.each{|classname|
  familyarray=classhash[classname]
  if familyarray.size()>1 and colorcount < 7
     arraycount=1
     familyarray.each{|familyname|
         if arraycount <=10
           familyhash[familyname]=colorhash[colorarray[colorcount]][arraycount.to_s]
           arraycount+=1
         else 
            familyhash[familyname]="#"+"%06x" % (rand * 0xffffff) 
         end
     }
     colorcount+=1
  elsif colorcount >=7
     familyarray.each{|familyname|
       familyhash[familyname]= "#"+"%06x" % (rand * 0xffffff)
     }
  else 
    if earthcount <=9 
      familyarray.each{|familyname|
        familyhash[familyname]=colorhash[colorarray[7]][earthcount.to_s]
      }
      earthcount+=1
    else
      familyarray.each{|familyname| 
       familyhash[familyname]="#"+"%06x" % (rand * 0xffffff)
      }
    end 
  end 
}

familyhash.each{|k,v|
  puts "#{k}\t#{v}"
}


#output colordata file for itol 

taxohash.each{|classname,familyarray|
   familyarray.each{|familyname,samplearray|
     if familyhash.has_key?(familyname)
       samplearray.each{|sample|
         color=familyhash[sample.familyname]
         if sample.familyname.split(" ").size()>1
           sample.familyname.gsub!(" ","-")
         end
         outdata.puts "#{sample.familyname}_#{sample.sampleID}\t#{color}"
         outlegend.puts "#{sample.familyname}_#{sample.sampleID}\trange\t#{color}\t#{sample.familyname}"
       }
     else 
       samplearray.each{|sample|
         color="#FFFFFF"
         if sample.familyname.split(" ").size()>1
            sample.familyname.gsub!(" ","-")
         end
         outdata.puts "#{sample.familyname}_#{sample.sampleID}\t#{color}"
         outlegend.puts "#{sample.familyname}_#{sample.sampleID}\trange\t#{color}\tOther"
       }
     end
   }
}
outdata.close()
outlegend.close()

#generate newick tree file for itol
parsecmd="python /home/junm/microbiomeWorkbench/brlheadmicrobiome/newickParse.py #{oritreefilepath}"

puts parsecmd
system(parsecmd)

taxoinfile=File.open(outdatafile,"r")
treefile=File.open(parsedtreefilepath,"r")
outtreefile=File.open(outtreefilepath,"w")

lookuptable={}
taxoinfile.each{|line|
   line.strip!
   name=line.split("\t")[0]
   sampleID=name.split("_").last
   lookuptable[sampleID]=name
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

#add color to meta data 
mapheaders=mappingfile.gets.split("\t")
metapos=mapheaders.index(meta)

metahash={}
mappingfile.each{|line|
  line.strip!
  cols=line.split("\t")
  dataid=cols[0]
  datameta=cols[metapos]
  metahash[dataid]=datameta
}

otutablefile.gets.strip!
otuheaders=otutablefile.gets.split("\t")
otuheaders.pop
otuheaders.delete_at(0)
poshash={}
count=0
otuheaders.each{|sample|
  label=metahash[sample]
  count+=1
  if ! poshash.has_key?(label)
     posarray=[]
     posarray << count
     poshash[label]=posarray
  else
     posarray=poshash[label]
     posarray<< count
     poshash[label]=posarray
  end
}


metacolorhash={}
colorcount=1
poshash.keys.each{|key|
  if colorcount<=9
    metacolorhash[key]=colorhash["earth"][colorcount.to_s]
    colorcount+=1
  else 
    metacolorhash[key]= "#"+"%06x" % (rand * 0xffffff)
  end 
}
otutablefile.each{|line|
  line.strip!
  cols=line.split("\t")
  cols.pop
  otuid=cols[0]
  max=0.0
  label=""
  poshash.each{|k,v|
      sum=0.0
      count=0.0
      v.each{|pos|
         count+=1
         if cols[pos].to_f>0
            sum+=1
         end
      }
      if (sum/count > max)
         max=sum/count
         label=k
      end
  }
  if lookuptable.has_key?(otuid)
    outmeta.puts "#{lookuptable[otuid]}\t#{metacolorhash[label]}"
    outwhite.puts "#{lookuptable[otuid]}\t#FFFFFF"
  end
}
outmeta.close()
outwhite.close()


cmd=[]
cmd << "treeFile = #{outtreefilepath}"
cmd << "treeFormat = newick"
cmd << "treeName = upload"
cmd << "projectName = batch"
cmd << "colorDefinitionFile = #{outlegendfile}"
cmd << "dataset1File = #{outdatafile}"
cmd << "dataset1Label = taxo"
cmd << "dataset1Separator =tab"
cmd << "dataset1Type = colorstrip"
cmd << "dataset1StripWidth = 100"
cmd << "dataset1PreventOverlap = 0"
cmd << "dataset1BranchColoringType = both"
cmd << "dataset2File = #{outwhitefilepath}"
cmd << "dataset2Label = white"
cmd << "dataset2Separator =tab"
cmd << "dataset2Type = colorstrip"
cmd << "dataset2StripWidth = 100"
cmd << "dataset2PreventOverlap = 0"
cmd << "dataset2BranchColoringType = none"
cmd << "dataset3File = #{outmetafilepath}"
cmd << "dataset3Label = meta"
cmd << "dataset3Separator =tab"
cmd << "dataset3Type = colorstrip"
cmd << "dataset3StripWidth = 100"
cmd << "dataset3PreventOverlap = 0"
cmd << "dataset3BranchColoringType = none"

cmd.each{|line|
  outconfigfile.puts line
}
outconfigfile.close()
`iTOL_uploader.pl --configure #{outconfigfilepath} >#{outtempfile}`
`sed '$d' < #{outtempfile} > #{outtempfile}.tmp`
`mv #{outtempfile}.tmp #{outtempfile}`
queryID=`tail -1 #{outtempfile}`


cmd.clear
cmd << "tree = #{queryID}  "
cmd << "outputFile = #{exportpdfpath}"
cmd << "format = pdf"
cmd << "fontSize = 6"
cmd << "displayMode = circular"
cmd << "colorBranches =1"
cmd << "showBS = 0"
cmd << "rangesCover = leaves"
cmd << "alignLabels =1"
cmd << "ignoreBRL =1"
cmd << "arc = 360"
cmd << "datasetList = dataset1,dataset2,dataset3"
cmd << "scaleFactor =1"

cmd.each {|line|
  exportfile.puts line
}
exportfile.close()
 
`iTOL_downloader.pl --configure #{exportfilepath}`



