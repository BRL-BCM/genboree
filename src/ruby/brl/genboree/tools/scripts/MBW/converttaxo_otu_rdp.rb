#!/usr/bin/env ruby 

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


infile=File.open(ARGV[0],"r")
inotu=File.open(ARGV[1],"r")

outdir=File.dirname(ARGV[1])
outfilename=File.basename(ARGV[1])
outfilename="#{outdir}/#{outfilename}"
outfilename.gsub!(/.txt/,".rdp.txt")
outfile=File.open(outfilename,"w")

samplearray=[]
infile.each{|line|
   line.strip!
   sample=Sample.new(line)
   samplearray << sample
}
infile.close()
cutoff=0.8
taxohash={}

samplearray.each{|sample|
  taxo="Root"
  if sample.domainname != "NA" and sample.domainscore > cutoff
     taxo="#{taxo};#{sample.domainname}"
     if sample.phylumname != "NA" and sample.phylumscore > cutoff
       taxo="#{taxo};#{sample.phylumname}"
       if sample.classname != "NA" and sample.classscore > cutoff
         taxo="#{taxo};#{sample.classname}"
         if sample.ordername != "NA" and sample.orderscore > cutoff
           taxo="#{taxo};#{sample.ordername}"
           if sample.familyname != "NA" and sample.familyscore > cutoff
             taxo="#{taxo};#{sample.familyname}"
             if sample.genusname != "NA" and sample.genusscore > cutoff
               taxo="#{taxo};#{sample.genusname}"
             end
           end
         end
       end
     end
   end 
 # puts "#{sample.sampleID}\t#{taxo}"
  taxohash[sample.sampleID]=taxo
}

outfile.puts inotu.gets
outfile.puts inotu.gets 
inotu.each{|line|
  line.strip!
  cols=line.split("\t")
  otuid=cols[0]
  newtaxo=taxohash[otuid]
  oldtaxo=cols.last
  line.gsub!(/#{oldtaxo}/,newtaxo)
  outfile.puts line
}
outfile.close()
inotu.close()

