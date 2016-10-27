#!/usr/bin/env ruby

require "fileutils"
require "rubygems"
require "simple_xlsx"
require "spreadsheet"

def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby run_RDP_pipeline.rb <location of input table file> <location of output folder> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end

def xlsExporter(files,outFile)
  SimpleXlsx::Serializer.new(outFile) do |doc|
    files.each{ |inFile|
      inFile = inFile.chop
      spl = File.basename(inFile).split("-")
      name = spl[0]
      #open new sheet and give it name of 'name'
      #sheetX = book.create_worksheet :name => name
      doc.add_sheet(name) do |sheet|
        r = File.open(inFile, "r")
        count = 0
        r.each{ |line|
          spl = line.split("\t")
          splCount = 0
          splLen = spl.length
          #make array to hold line to write to xlsx file
          lineArr = []
          spl.each{ |cell|
            if count == 0
              lineArr.push(cell)
            else
              if splCount == 0
                lineArr.push(cell)
              else
                lineArr.push(cell.to_f)
              end
            end
            splCount += 1
            break if splCount == splLen -1
          }
          sheet.add_row(lineArr)
          count += 1
        }
      end
    }
  end
end


def cleantrim(infiles,outFolder)
   infiles.each{ |inFile|
    inFile = inFile.chop
    outFile = outFolder + File.basename(inFile).gsub(/\.txt/, "-clean.txt")
    w = File.open(outFile, "w")
    r = File.open(inFile, "r")
    count = 0
    r.each{ |line|
      spl = line.split("\t")
      splCount = 0
      splLen = spl.length
      sum = 0.0
      max = 0.0
      colTitles = ""
      spl.each{ |cell|
        if count == 0
          cell = cell.gsub(/map\./, "")
          spl2 = cell.split(".f")
          cspl = spl2[0].split("_")
          trimUp = "#{cspl[1]}_#{cspl[2]}_#{cspl[0]}"
          colTitles += "#{trimUp}\t"
        else
          if splCount == 0
          else
            sum += cell.to_f
          end
        end
        splCount += 1
        break if splCount == splLen -1
      }
      w.puts colTitles if count == 0
      w.puts line if sum > 0
      count += 1
    }
    w.close()
  }
end


def makeheatmap(infiles,outFolder,height,width)
  infiles.each{ |inFile|
    inFile = File.expand_path(inFile.chop)
    #make temp file purged of trailing tabs
    tmpFile = "#{inFile}.tmp"
    w = File.open(tmpFile, "w")

    r = File.open(inFile, "r")
    r.each{ |line|
      #remove trailing tabs
      w.puts line.strip
    }
    r.close()
    w.close()

    heatmapCMD = "generic_make_2D_heatmap.rb -i #{tmpFile} -o #{outFolder} -d both -f dist -h hclust -k TRUE -s 0.75 -t none -y none -c Spectral -H #{height} -W #{width}"
    `#{heatmapCMD}`

    #remove temp file
    `rm -f #{tmpFile}`

    #loop through output folder to rename files to match original name
    ext = ".txt.tmp.fixed.heatmap"
    heatmapFiles = `ls #{outFolder}/*#{ext}*`.to_a
    heatmapFiles.each{ |file|
      newFileName = file.strip.gsub(/#{ext}/,"")
      mvCMD = "mv #{file.strip} #{newFileName}"
      `#{mvCMD}`
    }
  }
end

inputFilePath=File.expand_path(ARGV[0])
inputFile=File.open(inputFilePath,"r")
line=inputFile.gets.chop!
colnames=line.split("\t")
#curDir="/home2/junm/microbiomeWorkbench/microbiomeWorkbench/"
metapos=colnames.index("fileLocation")+1

metanames=[]
for ii in metapos...colnames.size
    metanames.push(colnames[ii])
end
samplehash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

#read in information for each sample
inputFile.each_line{ |line|
  line.chop!
  cols=line.split("\t")
  #creat output folder for each sample
  basename=File.basename(cols[colnames.index("fileLocation")])
  basename.gsub!(/.[sra|sff]/,"")
  outSffDir=File.expand_path(ARGV[1])+"/#{basename}/"
  sampleName=cols[colnames.index("sampleName")]
  outsampleDir=File.expand_path(ARGV[1])+"/#{sampleName}/"
  faFiltered="#{outsampleDir}/#{sampleName}.fa"
  minseqCount=cols[colnames.index("minseqCount")].to_i
  for ii in 0...metanames.size
    samplehash[sampleName][metanames[ii]]=cols[colnames.index(metanames[ii])]
  end

  seqCount=`grep "^>"  #{faFiltered} | wc -l`.to_i
  if(seqCount > minseqCount)
    #execute command for RDP classifier
   # cmdRDP="ruby #{curDir}run_RDP_2.2.rb #{faFiltered} #{outsampleDir}"
   cmdRDP="run_RDP_2.2.rb #{faFiltered} #{outsampleDir}"
   $stderr.puts cmdRDP
   system("#{cmdRDP}")

    #execut command for binning the result of RDP classifier
    inputForBin="#{outsampleDir}/#{sampleName}.fa.ignore."
    #cmdBin="ruby #{curDir}analyze_RDP.rb #{inputForBin} #{outsampleDir}"
    cmdBin="analyze_RDP.rb #{inputForBin} #{outsampleDir}"
    $stderr.puts cmdBin
    system("#{cmdBin}")

  end

}

#combine the result from individual sample into one folder
outDir=File.expand_path(ARGV[1])+"/"
outRDPDir=File.expand_path(ARGV[1])+"/RDPsummary/"
#cmdCombine="ruby #{curDir}combine_RDP.rb #{outRDPDir} #{outDir}"
cmdCombine="combine_RDP.rb #{outRDPDir} #{outDir}"
$stderr.puts cmdCombine
system("#{cmdCombine}")

#generate report based on the RDP classier result
#cmdReport="ruby #{curDir}generate_RDPreport.rb #{outRDPDir} #{outDir}RDPreport/"
cmdReport="generate_RDPreport.rb #{outRDPDir} #{outDir}RDPreport/"
$stderr.puts cmdReport
system("#{cmdReport}")
cmdReport="generate_RDPreport_count.rb #{outRDPDir} #{outDir}RDPreport/"
$stderr.puts cmdReport
system("#{cmdReport}")


weightednormfiles= `ls #{outDir}RDPreport/*_weighted-normalized.txt`.to_a
countnormfiles=`ls #{outDir}RDPreport/*_count-normalized.txt`.to_a
weightedfiles=`ls #{outDir}RDPreport/*_weighted.txt`.to_a
countfiles=`ls #{outDir}RDPreport/*_count.txt`.to_a
weightednormout="#{outDir}RDPreport/weighted_normalized.xlsx"
weightedout="#{outDir}RDPreport/weighted.xlsx"
countnormout="#{outDir}RDPreport/count_normalized.xlsx"
countout="#{outDir}RDPreport/count.xlsx"

trimout="#{outDir}RDPreport/"
heatmapout="#{outDir}RDPreport/"
xlsExporter(weightednormfiles,weightednormout)
xlsExporter(countnormfiles,countnormout)
xlsExporter(weightedfiles,weightedout)
xlsExporter(countfiles,countout)

cleantrim(weightednormfiles,trimout)
makeheatmap(weightednormfiles, heatmapout,11,16)


outDir=File.expand_path(ARGV[1])+"/"
normfiles= `ls #{outDir}RDPreport/*_weighted.txt`.to_a


normfiles.each{|normfile|
  normfile.strip!
  puts normfile
  for ii in 0...metanames.size
    normfiler=File.open(normfile,"r")
    outmetafilepath=normfile.gsub(/\.txt/,"")
    outmetafilepath1="#{outmetafilepath}.meta.#{metanames[ii]}.tsv"
    outmetafilepath2="#{outmetafilepath}.meta.#{metanames[ii]}.excludenotclassified.tsv"
    outmetafile=File.open(outmetafilepath1,"w")
    outmetafile2=File.open(outmetafilepath2,"w")
    header=normfiler.gets
    cols=header.split("\t")
    count=0
    metahash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
    taxohash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
    taxohashshort=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}
    sumhash={}
    sumhashshort={}
    cols.each{|samplename|
      samplename.gsub!(/\.fa.ignore..ana/,"")
      if samplehash.has_key?(samplename)
         metaname=metanames[ii]
         meta=samplehash[samplename][metaname]
         if ! metahash.has_key?(meta)
              samplearray=[]
              samplearray << count
              metahash[meta]=samplearray
         else
              samplearray=metahash[meta]
              samplearray << count
              metahash[meta]=samplearray
         end
      end
      count+=1
    }
    outline="taxo_name\t"
    metahash.keys.each{|key|
        #outline+="#{key}\t"
        sumhash[key]=0
        sumhashshort[key]=0
    }
    #outmetafile.puts outline
    #outmetafile2.puts outline
    normfiler.each{|line|
        line.strip!
        datacols=line.split("\t")
        taxo=datacols[0]
        metahash.each{|meta,posarray|
           sum=0
           posarray.each{|pos|
              sum+=datacols[pos].to_f
           }
           taxohash[taxo][meta]=sum/posarray.size()
           sumhash[meta]+=taxohash[taxo][meta]
           unless taxo =~ /notClassified/
             taxohashshort[taxo][meta]=sum/posarray.size()
             sumhashshort[meta]+=taxohashshort[taxo][meta]
           end
        }
    }
    normfiler.close()

    taxohash.each{|taxo,metaarray|
       metaarray.each{|meta,value|
          taxohash[taxo][meta]=value/sumhash[meta]
       }
    }
    taxohashshort.each{|taxo,metaarray|
       metaarray.each{|meta,value|
          taxohashshort[taxo][meta]=value/sumhashshort[meta]
       }
    }

    #set up variables for correctly outputting header line
    headerCount = 0
    headerLine = "taxo_name\t"

    taxohash.each{|taxo,metaarray|
       outline="#{taxo}\t"
       metaarray.each{|meta,value|
           if value < 0.0001
             value = 0
           end
           outline+="#{value.to_f}\t"
           #append values to header line
           headerLine += "#{meta}\t"
       }

       #output headerLine if we're at the first line
       outmetafile.puts headerLine if headerCount < 1
       headerCount += 1

       outmetafile.puts outline
    }
    outmetafile.close()


    #set up variables for correctly outputting header line
    headerCount = 0
    headerLine = "taxo_name\t"

    taxohashshort.each{|taxo,metaarray|
       outline="#{taxo}\t"
       metaarray.each{|meta,value|
           if value < 0.0001
             value = 0
           end
           outline+="#{value.to_f}\t"
           #append values to header line
           headerLine += "#{meta}\t"
       }

       #output headerLine if we're at the first line
       outmetafile2.puts headerLine if headerCount < 1
       headerCount += 1

       outmetafile2.puts outline
    }
    outmetafile2.close()

   end
}

#generate xls summary file based on meta

for ii in 0...metanames.size
  tsvfiles=`find  #{outDir}RDPreport/ -name "*meta.#{metanames[ii]}*.tsv"`.to_a
  xlsfile="#{outDir}RDPreport/RDP_#{metanames[ii]}_summary.xls"
  unless tsvfiles.empty?
  book = Spreadsheet::Workbook.new
  tsvfiles.each{|tsvfile|
     tsvfile.strip!
     filename=File.basename(tsvfile)
     sheetname=filename.gsub(/\.tsv/,"")
     sheet = book.create_worksheet :name => "#{sheetname}"
     readtsvfile=File.open(tsvfile,"r")
     headercols=readtsvfile.gets.split("\t")
     headercols.each{|col|
       sheet.row(0).push "#{col}"
     }
     rowcount=1
     readtsvfile.each{|line|
       line.strip!
       cols=line.split(/\t/)
       pos=0
       cols.each{|col|
           if pos == 0
             sheet.row(rowcount).push col
           else
             sheet.row(rowcount).push col.to_f
           end
           pos+=1
       }
       rowcount+=1
     }
  }
  book.write "#{xlsfile}"
  end
end

#generate stackplots

`stackedBarAuto.rb #{outDir}RDPreport/ #{outDir}RDPfigure/`
