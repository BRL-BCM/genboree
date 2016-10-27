#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/annotationFile'
require 'brl/util/vcfParser'
require 'json'

module BRL ; module Genboree ; module Abstract ; module Resources

class VcfFile < AnnotationFile
  attr_accessor :attNameHash, :attIdArray, :attValueHash
  # [+dbu+]
  # [+fileName+]
  # [+showTrackHead+]
  # [+options+]
  DEFAULT_SPAN_AGG_FUNCTION = :med
  COLUMN_HEADER_LINE = "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT" # Sample name will be added in the parent class

  attr_accessor :bucketSum, :bucketCount, :bucketMin, :bucketMax, :bucketSoq
  attr_accessor :coord, :bucket
  def initialize(dbu, fileName=nil, showTrackHead=false, options={})
    super(dbu, fileName)
    @fdataFields = 'fid, rid, fstart, fstop, gname'
    @hdhvType = 'vcf'
    # Set the @formatOptions instance var called by parent
    @formatOptions = options
    @vcfLineCount = 0
  end

  # Converts a record from fdata2 to a vcf line.
  #
  # [+rowObj+]    DBI::Row object containing fdata2 record
  # [+returns+]   vcf line string
  def makeLine(rowObj)
    fid = rowObj['fid'].to_i
    avpHash = @fid2NameAndValueHash[fid]
    chrom = @frefNameHash[rowObj['rid']]
    pos = rowObj['fstart']
    id = rowObj['gname']
    ref = 'N'
    alt = 'N'
    fileFormat = 'VCFv4.1'
    filter = 'GB_FILTER_NOT_VCF'
    qual = 0
    format = nil
    info = 'GB_INFO_NOT_VCF'
    vcfLineStr = ""
    metaInfoLines = ""
    # Shim in some field definitions for when the annotations are not vcf
    if(@vcfLineCount == 0)
      attrValRecs = @dbu.selectFtypeAttributesInfoByFtypeIdList([@ftypeId])
      if(!attrValRecs.nil? and !attrValRecs.empty?)
        attrValRecs.each { |rec|
          attrName = rec['name']
          if(attrName =~ /^gbVcf/)
            attrName.gsub!(/^gbVcf/, "")
            if(attrName == 'fileformat')
              fileFormat = rec['value']
              next
            end
            if(BRL::Util::VcfParser::RESERVED_METAINFO_FIELDS.key?(attrName))
              attrValueRecs = JSON.parse(rec['value'])
              attrValueRecs.each {|rec|
                metaInfoLines << "###{attrName}=#{rec}\n"  
              }
            else
              metaInfoLines << "###{attrName}=#{rec['value']}\n"
            end
          end
        }
      end
      vcfLineStr << "##fileformat=#{fileFormat}\n"
      vcfLineStr << metaInfoLines
      vcfLineStr << "##INFO=<ID=GB_INFO_NOT_VCF, Number=0, Type=Flag, Description=\"Not a VCF record\">\n"
      vcfLineStr << "##FILTER=<ID=GB_FILTER_NOT_VCF, Number=0, Type=Flag, Description=\"Not a VCF record\">\n"
      vcfLineStr << "##FORMAT=<ID=GB_FORMAT_NOT_VCF, Number=0, Type=Flag, Description=\"Not a VCF record\">\n"
      vcfLineStr << "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t#{@ftypeHash['fmethod']}\n"
      @vcfLineCount += 1
    end
    sampleInfo = []
    if(!avpHash.nil? and !avpHash.empty?)
      id = avpHash['ID'] if(avpHash.key?('ID'))    
      ref = avpHash['REF'] if(avpHash.key?('REF'))
      alt = avpHash['ALT'] if(avpHash.key?('ALT'))
      qual = avpHash['QUAL'] if(avpHash.key?('QUAL'))
      filter = avpHash['FILTER'] if(avpHash.key?('FILTER'))
      info = avpHash['INFO'] if(avpHash.key?('INFO'))
      format = avpHash['FORMAT'] if(avpHash.key?('FORMAT'))
      if(format.nil? or format.empty?)
        sampleInfo << "0"
        format = "GB_FORMAT_NOT_VCF"
      else
        format.split(':').each { |fmtEl|
          sampleInfo << "#{avpHash[fmtEl]}"
        }
      end
    else
      format = "GB_FORMAT_NOT_VCF"
      sampleInfo << "0"
    end
    vcfLineStr << "#{chrom}\t#{pos}\t#{id}\t#{ref}\t#{alt}\t#{qual}\t#{filter}\t#{info}\t#{format}\t#{sampleInfo.join(":")}\n"
    return vcfLineStr
  end


  def makeAttributeValuePairs(valueString)
    valueString.each { |value|
      key = value['fid'].to_i
      if(@fid2NameAndValueHash.has_key?(key))
        @fid2NameAndValueHash[key][@attNamesHash[value['attNameId']]] = value['value']
      else
        @fid2NameAndValueHash[key] = { @attNamesHash[value['attNameId']] => value['value'] }
      end
    }
  end

end

end ; end ; end ; end
