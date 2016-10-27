#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'


class MappingsToBedToWigDriver
  DEBUG=false
  def initialize(pattern, scratchDir, center, sample, mark, chromosomesRef, out10kbWig)
    @pattern        = pattern
    @scratchDir     = scratchDir
    @center         = center
    @sample         = sample
    @mark           = mark 
    @out10kbWig    = out10kbWig 
    @chromosomesRef = chromosomesRef
  end
 
  def myFileOpen(fileName)
    $stderr.puts "Trying to open #{fileName}" if (DEBUG)
    reader = nil
    if (fileName=~/\.gz$/) then
      reader = File.popen("gzip -d -c #{fileName}", "r")
    elsif (fileName=~/\.bz2$/) then
      reader = File.popen("bzcat #{fileName}", "r")
    elsif
      reader = File.open(fileName)
    end
    return reader
  end

  def work()
    # generate bed file
    @collatedBedFile  = "#{@scratchDir}/all.#{File.basename(@out10kbWig)}.bed"
    collateBedFiles()
    # extend to 200bp
    @collatedBed200File  = "#{@scratchDir}/all.ext200.#{File.basename(@out10kbWig)}.bed"
    extendBedTo200BP(@collatedBedFile, @collatedBed200File)
    @collatedBedFileExt200NonRedundant = "#{@scratchDir}/nonred.ext200.all.#{File.basename(@out10kbWig)}.bed"
    # remove non redundant reads
    removeRedundantReads(@collatedBed200File, @collatedBedFileExt200NonRedundant)
    # generate wig file
    generate10kblffFile()
    system("rm -r #{@collatedBedFile} #{@collatedBed200File} #{@collatedBedFileExt200NonRedundant}")
  end
   
  def generate10kblffFile()
    #wigCmd="windowsCoverage.exe -m #{@collatedBedFileExt200NonRedundant} -R #{@chromosomesRef} -o #{@out10kbWig} -w 10000 -t #{@center}_#{@mark} -s #{@sample}" ;  
    wigCmd="windowsCoverage.exe -m #{@collatedBedFileExt200NonRedundant} -R #{@chromosomesRef} -W #{@out10kbWig} -B 1000 -w 20 -N \"#{@center} #{@sample} #{@mark}\"" ;  
    $stderr.puts "executing wig command #{wigCmd}" 
    system(wigCmd)
  end 

  def collateBedFiles()
    list1 = Dir[@pattern]
    if (list1==nil) then
      list1 = []
    end
    list1.each {|bedFile|
      catCmd = ""
      if (bedFile =~ /\.gz/) then
        catCmd = "gzip -d -c #{bedFile} >> #{@collatedBedFile}"
      elsif (bedFile =~ /\.bz2/) then
        catCmd = "bunzip2 -c #{bedFile} >> #{@collatedBedFile}"
      else
        catCmd = "cat #{bedFile} >> #{@collatedBedFile}"
      end
      $stderr.puts "executing cat | #{catCmd} | " 
      system(catCmd)
    }
  end
  
  def extendBedTo200BP(inF, outF)
    r = myFileOpen(inF)
    w = BRL::Util::TextWriter.new(outF)
    r.each {|l|
      f = l.strip.split(/\t/)
      if (f[4]=="+") then 
        f[2] = f[1].to_i + 199
      else 
        f[1]=f[2].to_i-199
      end
      f[1]=1 if (f[1].to_i<1)
      w.puts f.join("\t")
    }
    r.close()
    w.close()  
  end
  
  # Two reads are considered redundant if 
  # * they occur on the same chromosome 
  # * they share the same strand 
  # * they have the same starting point 
  def removeRedundantReads(inF, outF)
    $stderr.puts "inF = #{inF} outF = #{outF}"
    sortCmd = ""
    sortCmd << "cat #{inF} "
    sortCmd << "| sort -k5,5 -k1,1 -k2,2n -T #{@scratchDir} -S 1G -o #{outF}.sorted"
    $stderr.puts "sortcmd = #{sortCmd}" 
    system(sortCmd)
    prevChrom = nil
    prevStart = nil
    prevStop = nil
    r = BRL::Util::TextReader.new("#{outF}.sorted")
    w = BRL::Util::TextWriter.new(outF)
    r.each {|l|
      ff = l.strip.split(/\t/)
      if (ff[0]==prevChrom && ff[1]==prevStart) then
        $stderr.puts "duplicated read #{l.strip}" if (DEBUG)
      else
        w.print l
        prevChrom = ff[0]
        prevStart = ff[1]
      end
    }
    r.close()
    w.close()
    system("rm -f #{outF}.sorted") 
  end

  def MappingsToBedToWigDriver.usage()
    $stderr.puts "
This is an utility that collects mappings of split input files, unique reads only, and generates collated bed files and corresponding wig files.
 USAGE:
   bedToLff.rb <bed pattern> <scratch dir> <center> <sample> <mark> <chromosomes ref> <out 10kb lff>
"
    exit(2)
  end
end



####### MAIN

if (ARGV.size==0 || ARGV.member?("--help") || ARGV.member?("-h")) then
  MappingsToBedToWigDriver.usage() 
end
mapppingsToWigDriver = MappingsToBedToWigDriver.new(*ARGV)
mapppingsToWigDriver.work()
