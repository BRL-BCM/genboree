#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

# ##############################################################################
# CONSTANTS
# ##############################################################################
GZIP = BRL::Util::TextWriter::GZIP_OUT

# ##############################################################################
# HELPER FUNCTIONS
# ##############################################################################
# Process command line args
# Note:
#      - extra alias files are optional, but clearly should be provided
module BRL ; module FileFormats; module UcscParsers
class CcdsGeneTable

  attr_accessor :bin, :name, :origName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdsEnd, :exonCount, :exonStarts, :exonEnds
  attr_accessor :iD, :name2, :cdsStartStatus, :cdsEndStatus, :exonFrames

  def initialize(line)
    @bin, @name, @origName, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdsEnd, @exonCount, @exonStarts, @exonEnds,
    @iD, @name2, @cdsStartStatus, @cdsEndStatus, @exonFrames = nil
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @bin = aa[0].to_i
      @name = aa[1].chomp.to_sym
      @origName = @name
      @chrom = aa[2].chomp.to_sym
      @strand = aa[3].chomp.to_sym
      @txStart = aa[4].to_i + 1
      @txEnd = aa[5].to_i
      @cdsStart = aa[6].to_i + 1
      @cdsEnd = aa[7].to_i
      @exonCount = aa[8].to_i
      @exonStarts = aa[9].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[10].split(/,/).map{|xx| xx.to_i}
      @iD = aa[11].to_i
      @name2 = aa[12].gsub(/;/, '.').to_sym if(aa.length > 12 and !aa[12].empty?)
      @cdsStartStatus = aa[13].gsub(/;/, '.').to_sym if(aa.length > 12)
      @cdsEndStatus = aa[14].gsub(/;/, '.').to_sym if(aa.length > 13)
      @exonFrames = aa[15].split(/,/).map{|xx| xx.to_i} if(aa.length > 15)
    end
  end
end

class CcdsInfoTable
  attr_accessor :ccds, :srcDb, :mrnaAcc, :protAcc, :mrnaAccHash, :protAccHash, :rawMrnaAcc

  def initialize(line)
    @ccds, @srcDb, @mrnaAcc, @rawMrnaAcc, @protAcc = nil
    @mrnaAccHash = Hash.new {|hh,kk| hh[kk] = nil}
    @protAccHash = Hash.new {|hh,kk| hh[kk] = nil}

    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @ccds = aa[0].chomp.to_sym
      @srcDb = aa[1].chomp.to_sym
      if(aa.length > 2 and !aa[2].empty?)
        @mrnaAcc = aa[2].strip().gsub(/\.\d+$/, "").strip.to_sym
        @mrnaAccHash[@mrnaAcc] = @srcDb
      end
      if(aa.length > 2 and !aa[2].empty?)
        @rawMrnaAcc = aa[2].chomp.to_sym
      end
      if(aa.length > 3 and !aa[3].empty?)
        @protAcc = aa[3].chomp.to_sym
        @protAccHash[@protAcc] = @srcDb 
      end
    end
  end
end


class CcdsKgMapTable
  attr_accessor :ccdsId, :origName, :geneId, :originalGeneId, :originalGeneIdHash, :geneIdHash, :chrom, :chromStart, :chromEnd, :cdsSimilarity

  def initialize(line)
    @ccdsId, @origName, @geneId, @originalGeneId, @chrom, @chromStart, @chromEnd, @cdsSimilarity = nil
    @geneIdHash = Hash.new {|hh,kk| hh[kk] = nil}
    @originalGeneIdHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @ccdsId = aa[0].to_sym
      @origName = @ccdsId
      if(aa.length > 5 and !aa[1].empty?)
        @originalGeneId = aa[1].chomp.to_sym 
        @originalGeneIdHash[@originalGeneId] = nil
        @geneId = aa[1].strip().gsub(/\.\d+$/, "").strip.to_sym
        @geneIdHash[@geneId] = nil 
      end
      @chrom = aa[2].to_sym
      @chromStart = aa[3].to_i + 1
      @chromEnd = aa[4].to_i
      @cdsSimilarity = aa[5].to_f
    end
  end
end

class UCSCBrowserTable
  attr_accessor :name, :originalName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdEnd, :exonCount, :exonStarts, :exonEnds, :lffLines
  attr_accessor :proteinId, :alignId, :proteinIdHash, :className, :typeName, :subTypeName

  def initialize(line, clName="Direct Recover", type="UCSC", subtype="download")
    @name, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdEnd, @exonCount, @exonStarts, @exonEnds,
    @proteinId, @alignId, @originalName = nil
    @proteinIdHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].strip.to_sym
      @originalName = aa[1].chomp.to_sym
      @chrom = aa[2].chomp.to_sym
      @strand = aa[3].chomp.to_sym
      @txStart = aa[4].to_i + 1
      @txEnd = aa[5].to_i
      @cdsStart = aa[6].to_i + 1
      @cdsEnd = aa[7].to_i
      @exonCount = aa[8].to_i
      @exonStarts = aa[9].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[10].split(/,/).map{|xx| xx.to_i}
      if(aa.length > 1 and !aa[11].nil?)
        @proteinId = aa[11].chomp.to_sym
        @proteinIdHash[@proteinId] = nil 
      end
      @alignId = aa[12].gsub(/;/, '.').to_sym if(aa.length > 3 and !aa[12].nil?)
      @className = clName
      @typeName = type
      @subTypeName = subtype
      @lffLines = ucscLineToLff()
    end
  end
  
  def ucscLineToLff()
    myArray = Array.new()
      @exonStarts.each_index{|myIndex|
        myLine = "#{@className}\t#{@name}\t#{@typeName}\t#{@subTypeName}\t#{@chrom}\t"
        myLine += "#{@exonStarts[myIndex]}\t#{@exonEnds[myIndex]}\t#{@strand}\t0\t0\t.\t.\t"
        myLine += "geneName=#{@name}; transcript=#{@originalName}; "
        myLine += "exonNum=#{@exonCount}; cdsStart=#{@cdsStart}; cdsEnd=#{@cdsEnd}; "
        myLine += "txStart=#{@txStart}; txEnd=#{@txEnd}; "
        myLine += "proteinId=#{@proteinId}; " if(!@proteinId.nil?)
        myLine += "alignId=#{@alignId};" if(!@alignId.nil?)
        myArray << myLine
      }
    return myArray
  end
end




class KnownGeneTable
  attr_accessor :name, :originalName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdEnd, :exonCount, :exonStarts, :exonEnds
  attr_accessor :proteinId, :alignId, :proteinIdHash

  def initialize(line)
    @name, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdEnd, @exonCount, @exonStarts, @exonEnds,
    @proteinId, @alignId, @originalName = nil
    @proteinIdHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].strip().gsub(/\.\d+$/, "").strip.to_sym
      @originalName = aa[0].chomp.to_sym
      @chrom = aa[1].chomp.to_sym
      @strand = aa[2].chomp.to_sym
      @txStart = aa[3].to_i + 1
      @txEnd = aa[4].to_i
      @cdsStart = aa[5].to_i + 1
      @cdsEnd = aa[6].to_i
      @exonCount = aa[7].to_i
      @exonStarts = aa[8].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[9].split(/,/).map{|xx| xx.to_i}
      if(aa.length > 8 and !aa[10].empty?)
        @proteinId = aa[10].chomp.to_sym
        @proteinIdHash[@proteinId] = nil 
      end
      @alignId = aa[11].gsub(/;/, '.').to_sym if(aa.length > 3 and !aa[11].empty?)
    end
  end
end

class NameToValueTable
  attr_accessor :name, :value, :valueHash, :nameHash

  def initialize(line)
    @name, @value, @valueHash, @nameHash = nil
    @valueHash = Hash.new {|hh,kk| hh[kk] = nil}
    @nameHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].strip().gsub(/\.\d+$/, "").strip.to_sym
      @nameHash[@name] = nil
      if(aa.length > 1 and !aa[1].empty?)
        @value = aa[1].strip().gsub(/\.\d+$/, "").strip.to_sym
        @valueHash[@value] = nil
      end
    end
  end 
end

class NameToValueRawTable
  attr_accessor :name, :value, :valueHash, :nameHash

  def initialize(line)
    @name, @value, @valueHash, @nameHash = nil
    @valueHash = Hash.new {|hh,kk| hh[kk] = nil}
    @nameHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].strip().to_sym
      @nameHash[@name] = nil
      if(aa.length > 1 and !aa[1].empty?)
        @value = aa[1].strip().strip.to_sym
        @valueHash[@value] = nil
      end
    end
  end 
end


class RefFlatTable
  attr_accessor :geneName, :geneNameHash, :originalGeneName, :name, :nameHash, :originalName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdsEnd, :exonCount, :exonStart, :exonEnds


  def initialize(line)
    @geneName, @originalGeneName, @name, @originalName, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdsEnd, @exonCount, @exonStart, @exonEnds = nil
    @nameHash = Hash.new {|hh,kk| hh[kk] = nil}
    @geneNameHash = Hash.new {|hh,kk| hh[kk] = nil}
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      if(aa.length > 1 and !aa[0].empty?)
        @geneName = aa[0].strip().gsub(/\.\d+$/, "").strip.to_sym
        @geneNameHash[@geneName] = nil
      end      
      if(aa.length > 1 and !aa[1].empty?)
        @name = aa[1].strip().gsub(/\.\d+$/, "").strip.to_sym
        @nameHash[@name] = nil
      end
      @originalGeneName = aa[0].chomp.to_sym
      @originalName = aa[1].chomp.to_sym
      @chrom = aa[2].chomp.to_sym
      @strand = aa[3].to_sym
      @txStart = aa[4].to_i + 1
      @txEnd = aa[5].to_i
      @cdsStart = aa[6].to_i + 1
      @cdsEnd = aa[7].to_i
      @exonCount = aa[8].to_i
      @exonStarts = aa[9].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[10].split(/,/).map{|xx| xx.to_i}
    end
  end
end

class RefGeneTable
  attr_accessor :bin, :name, :origName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdsEnd, :exonCount, :exonStart, :exonEnds
  attr_accessor :iD, :name2, :cdsStartStatus, :cdsEndStatus, :exonFrames

  def initialize(line)
    @bin, @name, @origName, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdsEnd, @exonCount, @exonStart, @exonEnds,
    @iD, @name2, @cdsStartStatus, @cdsEndStatus, @exonFrames = nil
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @bin = aa[0].to_i
      @name = aa[1].chomp.to_sym
      @origName = @name
      @chrom = aa[2].chomp.to_sym
      @strand = aa[3].chomp.to_sym
      @txStart = aa[4].to_i + 1
      @txEnd = aa[5].to_i
      @cdsStart = aa[6].to_i + 1
      @cdsEnd = aa[7].to_i
      @exonCount = aa[8].to_i
      @exonStarts = aa[9].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[10].split(/,/).map{|xx| xx.to_i}
      @iD = aa[11].to_i
      @name2 = aa[12].gsub(/;/, '.').to_sym if(aa.length > 12 and !aa[12].empty?)
      @cdsStartStatus = aa[13].gsub(/;/, '.').to_sym if(aa.length > 13)
      @cdsEndStatus = aa[14].gsub(/;/, '.').to_sym if(aa.length > 14)
      @exonFrames = aa[15].split(/,/).map{|xx| xx.to_i} if(aa.length > 15)
    end
  end
end

class EnsGeneTable

  attr_accessor :name, :origName, :chrom, :strand, :txStart, :txEnd
  attr_accessor :cdsStart, :cdsEnd, :exonCount, :exonStarts, :exonEnds

  def initialize(line)
    @name, @origName, @chrom, @strand, @txStart, @txEnd,
    @cdsStart, @cdsEnd, @exonCount, @exonStarts, @exonEnds = nil
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].chomp.to_sym
      @origName = @name
      @chrom = aa[1].chomp.to_sym
      @strand = aa[2].chomp.to_sym
      @txStart = aa[3].to_i + 1
      @txEnd = aa[4].to_i
      @cdsStart = aa[5].to_i + 1
      @cdsEnd = aa[6].to_i
      @exonCount = aa[7].to_i
      @exonStarts = aa[8].split(/,/).map{|xx| xx.to_i + 1}
      @exonEnds = aa[9].split(/,/).map{|xx| xx.to_i}
    end
  end
end

class EnsGtpTable
  attr_accessor :gene, :transcript, :protein, :geneHash, :transcriptHash, :proteinHash

  def initialize(line)
    @gene, @transcript, @protein = nil
    @geneHash = Hash.new {|hh,kk| hh[kk] = nil}
    @transcriptHash = Hash.new {|hh,kk| hh[kk] = nil}
    @proteinHash = Hash.new {|hh,kk| hh[kk] = nil}

    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)

      if(aa.length > 0 and !aa[0].empty?)
        @gene = aa[0].chomp.to_sym
        @geneHash[@gene] = nil
      end

      if(aa.length > 1 and !aa[1].empty?)
        @transcript = aa[1].chomp.to_sym
        @transcriptHash[@transcript] = nil
      end

      if(aa.length > 2 and !aa[2].empty?)
        @protein = aa[2].chomp.to_sym
        @proteinHash[@protein] = nil
      end
    end
  end
end

class SfDescriptionTable
  attr_accessor :name, :proteinId, :description, :nameHash, :proteinIdHash

  def initialize(line)
    @name, @proteinId, @description = nil
    @nameHash = Hash.new {|hh,kk| hh[kk] = nil}
    @proteinIdHash = Hash.new {|hh,kk| hh[kk] = nil}

    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @name = aa[0].chomp.to_sym
      if(aa.length > 0 and !aa[0].empty?)
        @nameHash[@name] = nil
      end
      @proteinId = aa[1].chomp.to_sym
      if(aa.length > 1 and !aa[1].empty?)
        @proteinIdHash[@proteinId] = nil
      end
      @description = aa[2].chomp.gsub(/;/, '.').to_sym
    end
  end
end

class SuperfamilyTable
  attr_accessor :bin, :name, :chrom, :chromStart, :chromEnd

  def initialize(line)
    @bin, @name, @chrom, @chromStart, @chromEnd = nil
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @bin = aa[0].to_i
      @chrom = aa[1].chomp.to_sym
      @chromStart = aa[2].to_i
      @chromEnd = aa[3].to_i     
      @name = aa[4].chomp.to_sym 
    end
  end
end




end; end; end #namespace
