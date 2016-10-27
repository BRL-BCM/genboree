#!/usr/bin/env ruby
require "fileutils"

def usage()
  if ARGV.size != 2 || ARGV[0] =~ /--help/
    $stderr.puts "--USAGE----------------------------"
    $stderr.print "ruby analyze_RDP.rb <location of input table file> <location of output folder> \n"
    $stderr.puts "-----------------------------------"
    exit
  end
end


class Sample
  def initialize(line)
    cols=line.split("\t")
    @sampleID=cols[0]
    if line =~ /domain/
      @domainname=cols[cols.index("domain")-1].gsub("\"","")
      @domainscore=cols[cols.index("domain")+1].to_f
    else 
      @domainname="NA"
    end
    if line =~ /phylum/
      @phylumname=cols[cols.index("phylum")-1].gsub("\"","")
      @phylumscore=cols[cols.index("phylum")+1].to_f
    else 
      @phylumname="NA"
    end  
    if line =~ /class/
      @classname=cols[cols.index("class")-1].gsub("\"","")
      @classscore=cols[cols.index("class")+1].to_f
    else
      @classname="NA"
    end
    if line =~ /order/
      @ordername=cols[cols.index("order")-1].gsub("\"","")
      @orderscore=cols[cols.index("order")+1].to_f
    else
      @ordername="NA"
    end
    if line =~ /family/
      @familyname=cols[cols.index("family")-1].gsub("\"","")
      @familyscore=cols[cols.index("family")+1].to_f
    else
      @familyname="NA"
    end
    if line =~ /genus/
      @genusname=cols[cols.index("genus")-1].gsub("\"","")
      @genusscore=cols[cols.index("genus")+1].to_f
    else
      @genusname="NA"
    end
  end
  attr_reader :sampleID, :domainname, :phylumname, :classname, :ordername, :familyname, :genusname, :domainscore, :phylumscore, :classscore, :orderscore, :familyscore, :genusscore
end


def checkhash (level,name,score)
    if name !~ /NA/ and score > $cutoff
      if ! $taxohash[level].has_key?(name)
        taxoarray=[]
        taxoarray << score
        $taxohash[level][name]=taxoarray
      else
        $taxohash[level][name] << score
      end
    end
end

usage()
infile=File.open(ARGV[0],"r")
outfolder=ARGV[1]

samplearray=[]
seqcount=0
infile.each{|line|
   line.strip!
   sample=Sample.new(line)
   samplearray << sample
   seqcount+=1
}
$cutoff=0.8
$taxohash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

samplearray.each{|sample|
    checkhash("class",sample.classname,sample.classscore)
    checkhash("domain",sample.domainname,sample.domainscore)
    checkhash("phylum",sample.phylumname,sample.phylumscore)
    checkhash("order",sample.ordername,sample.orderscore)
    checkhash("family",sample.familyname,sample.familyscore)
    checkhash("genus",sample.genusname,sample.genusscore)
}

$taxohash.each{|taxo,levelhash|
  outfilefolder="#{outfolder}/#{taxo}"
  FileUtils.mkdir_p outfilefolder
  basename=File.basename(ARGV[0])
  outfilepath="#{outfilefolder}/#{basename}.ana"
  outfile=File.open(outfilepath,"w")
  totalsize=0
  outfile.puts "#{$taxohash[taxo].length}"
  outfile.puts " "
  levelhash.each{|k,scorearray|
    size=scorearray.size()
    totalsize+=size
    sum=0
    scorearray.each{|score|
      sum+=score
    }
    percent=sum/size
    outfile.puts "#{k}\t#{size}\t\t#{sum}\t#{percent}"
  }
  notclassified=seqcount-totalsize
  outfile.puts "notClassified\t#{notclassified}\t\t#{notclassified}\t1"
  outfile.close()
}
