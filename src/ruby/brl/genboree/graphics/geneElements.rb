#!/usr/bin/env ruby

# Chromosome lengths for promoter regions
chromosomeLength = Hash.new
ch = File.open("chromosomeshg19.length","r")
ch.each_line{|line|
  (a,b)=line.chomp.split(/\s+/)
  chromosomeLength[a]=b.to_i
}
ch.close

fh=File.open(ARGV[0],"r")
while(!fh.eof?)
  line=fh.readline
  splitLine=line.chomp.split(/\t/)
  gene=splitLine[1]
  chr=splitLine[4]
  exonStart=splitLine[5].to_i
  exonEnd=splitLine[6].to_i
  strand=splitLine[7]
  attrs=Hash.new
  avps=splitLine[12].gsub(/\s/,"").split(/;/)
  avps.each{|avp|
    (aa,vv)=avp.split(/=/)
    attrs[aa]=vv
  }
  txStart=attrs["txStart"]
  txEnd=attrs["txEnd"]
  cdsStart=attrs["cdsStart"].to_i
  cdsEnd=attrs["cdsEnd"].to_i
  exonCount=attrs["exonCount"].to_i
  exonNum=attrs["exonNum"].to_i
  noUTR=false
  if(cdsStart>cdsEnd) then
    noUTR=true
  end
  intronNum=1
  inc = 1
  positiveStrand = true
  utrOrder=["5'UTR", "3'UTR"]
  if(strand == '-') then
    intronNum=exonCount-1
    inc=-1
    positiveStrand = false
    utrOrder=["3'UTR", "5'UTR"]
  end
  promoterDiff=2000
  if(positiveStrand) then
    pStart = exonStart-promoterDiff
    puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{(pStart>1) ? pStart : 1}\t#{exonStart-1}\t#{strand}\t0\t1\t.\t.\tType=Promoter"
  end
  if(noUTR) then
    puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
  else
    if(exonEnd<=cdsStart) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]};Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsEnd) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]};Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsStart and exonEnd<=cdsEnd) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsStart and exonEnd>cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsEnd+1}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]}"
    elsif(exonStart<cdsStart and exonEnd<=cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsStart-1}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart<cdsStart and exonEnd>cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsStart-1}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsStart}\t#{cdsEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsEnd+1}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]}"
    end
  end
  exonNum+=inc
  prevExonEnd=exonEnd
  (2..exonCount).each{|ii|
    line=fh.readline
    splitLine=line.chomp.split(/\t/)
    chr=splitLine[4]
    exonStart=splitLine[5].to_i
    exonEnd=splitLine[6].to_i
    puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{prevExonEnd+1}\t#{exonStart-1}\t#{strand}\t0\t1\t.\t.\tType=Intron;Order=#{intronNum}"
    intronNum += inc
    if(noUTR) then
    puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
  else
    if(exonEnd<=cdsStart) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]};Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsEnd) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]};Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsStart and exonEnd<=cdsEnd) then
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart>=cdsStart and exonEnd>cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsEnd+1}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]}"
    elsif(exonStart<cdsStart and exonEnd<=cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsStart-1}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsStart}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
    elsif(exonStart<cdsStart and exonEnd>cdsEnd)
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonStart}\t#{cdsStart-1}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[0]}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsStart}\t#{cdsEnd}\t#{strand}\t0\t1\t.\t.\tType=Exon;Order=#{exonNum};Name=#{exonNum}"
      puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{cdsEnd+1}\t#{exonEnd}\t#{strand}\t0\t1\t.\t.\tType=#{utrOrder[1]}"
    end
  end
  exonNum+=inc
  prevExonEnd=exonEnd

  }
  if(!positiveStrand) then
    pEnd = exonEnd+promoterDiff
    puts "GeneModelNew\t#{gene}\tGeneModelNew\tGeneRefSeqNew\t#{chr}\t#{exonEnd+1}\t#{(pEnd>chromosomeLength[chr]) ? chromosomeLength[chr] : pEnd}\t#{strand}\t0\t1\t.\t.\tType=Promoter"
  end
end
