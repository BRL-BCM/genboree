#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# This file describes the format of the TCGA report

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'brl/fileFormats/validators/tcgaFiles/constants'



# ##############################################################################
# CONSTANTS
# ##############################################################################



module BRL ; module FileFormats; module Validators; module TcgaFiles


class RoiSequencingFile

  attr_accessor :roiId, :samples, :length, :sequence, :oneXCoverage, :twoXCoverage, :oneXCoverageArray, :twoXCoverageArray,
  :oneXCoverageSize, :twoXCoverageSize, :sequenceArray, :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
    if(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @roiId, @sequence, @oneXCoverage, @twoXCoverage, @oneXCoverageArray, @sequenceArray, @twoXCoverageArray = nil
    @samples, @length, @oneXCoverageSize, @twoXCoverageSize = 0
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @roiId = aa[0].chomp if(!aa[0].nil?)
      @samples = aa[1].to_i if(!aa[1].nil?)
      @length = aa[2].to_i if(!aa[2].nil?)
      @sequence = aa[3].chomp if(!aa[3].nil?)
      @sequenceArray = @sequence.split("") if(!@sequence.nil? and @sequence.length > 0)
      if(!aa[4].nil?)
        @oneXCoverage = aa[4].chomp
        @oneXCoverageArray = @oneXCoverage.split(",").map{|xx| xx.to_i}
        @oneXCoverageSize = @oneXCoverageArray.size
      end
      if(!aa[5].nil?)
        @twoXCoverage = aa[5].chomp
        @twoXCoverageArray = @twoXCoverage.split(",").map{|xx| xx.to_i}
        @twoXCoverageSize = @twoXCoverageArray.size
      end
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@roiId.nil? || @roiId.length < 1)
              @errorLevel = 6
              return
      end
      if(@samples < 1)
          @errorLevel = 20
          return
      end
      
      if(@length < 1)
          @errorLevel = 21
          return
      end
      
      if(@sequence.nil? || @sequence.length < 1)
          @errorLevel =  22
          return
      end
      
      if(@sequence.length != @length)
        @errorLevel =  23
        return
      end
      
      if(@oneXCoverage.nil? || @oneXCoverage.length < 1 || @oneXCoverageSize < 1)
        @errorLevel =  24
        return
      end
      
      if(@oneXCoverageSize != @length)
        @errorLevel =  25
        return
      end
      
      @oneXCoverageArray.each{|oneX|
        if(oneX  >  @samples)
          @errorLevel =  59
        end
        }
    
      if(@twoXCoverage.nil? || @twoXCoverage.length < 1 || @twoXCoverageSize < 1)
        @errorLevel =  26
        return
      end
      
           
      if(@twoXCoverageSize != @length)
        @errorLevel =  27
        return
      end
      
      @twoXCoverageArray.each{|twoX|
        if(twoX  >  @samples)
          @errorLevel =  60
        end
        }
    end
  end

class SampleFile

  attr_accessor :sampleId, :sampleType, :patientId, :errorLevel, :currentLine

  ExpectedLineLength = 3 

  def returnErrorMessage(errLev)
    if(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @sampleId, @sampleType, @patientId = nil
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @sampleId = aa[0].chomp if(!aa[0].nil?)
      @sampleType = aa[1].chomp if(!aa[1].nil?)
      @patientId = aa[2].chomp if(!aa[2].nil?)
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)
      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@sampleId.nil? || @sampleId.length < 1)
              @errorLevel = 17
              return
      end
      if(@sampleType.nil? || @sampleType.length < 1)
          @errorLevel = 18
          return
      end
      if(@patientId.nil? || @patientId.length < 1)
          @errorLevel = 19
          return
      end
  end
end

class AmpliconFile

  attr_accessor :ampliconId, :ncbiBuild, :chromosome, :start, :stop, :size, :currentLine
  attr_accessor :primer_frw, :primer_frwStart, :primer_frwStop, :primer_frwSize, :primer_fwOr
  attr_accessor :primer_rv, :primer_rvStart, :primer_rvStop, :primer_rvSize, :primer_rvOr 
  attr_accessor :status, :errorLevel

  ExpectedLineLength = 8

  def returnErrorMessage(errLev)
      if(errLev == 9)
          chromosomeValues = Constants::ChromosomeHash.keys.sort.join(",")
          errorString = "The chromosome #{@chromosome} #{Constants::ErrorLevelHash[errLev]} #{chromosomeValues}"
          return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
      elsif(errLev == 10)
         errorString = "#{Constants::ErrorLevelHash[errLev]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 11)
         errorString = "#{Constants::ErrorLevelHash[errLev]} chromosome #{@chromosome} is #{Constants::ChromosomeHash[@chromosome]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 16)
          statusValuesArray = Constants::StatusHash.keys.sort
          statusValuesArray.each {|st|
            st.capitalize!
            }
          statusValues = statusValuesArray.join(",")
          errorString = "#{Constants::ErrorLevelHash[errorLevel]} #{@status} the approved values are #{statusValues}}"
          eturn errorString
      
      else
            return "#{Constants::ErrorLevelHash[errLev]}"
      end
  
  end

  def initialize(line)
    @ampliconId, @ncbiBuild, @chromosome, @start, @stop, @size,
    @primer_frw, @primer_rv, @status = nil
    @primer_frwSize, @primer_frwStart,
    @primer_frwStop,@primer_rvSize, @primer_frwStart, @primer_frwStop = 0
    @primer_fwOr , @primer_rvOr = nil
    @currentLine = line
    @errorLevel = 0
    chromosomeLength = 0
    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @ampliconId = aa[0].chomp if(!aa[0].nil?)
      @ncbiBuild = aa[1].to_f if(!aa[1].nil?)
      @chromosome = aa[2].chomp if(!aa[2].nil?)
      @start = aa[3].to_i 
      @stop = aa[4].to_i
      @size = @stop - @start
 
      if(!aa[5].nil?)
        @primer_frw = aa[5].chomp
        @primer_frwSize = @primer_frw.length
        @primer_frwStart = @start
        @primer_frwStop = @start + @primer_frwSize
        @primer_fwOr = "+"
      end
      
      if(!aa[6].nil?)
        @primer_rv = aa[6].chomp
        @primer_rvSize = @primer_rv.length 
        @primer_rvStart = @stop - @primer_rvSize
        @primer_rvStop =  @stop
        @primer_rvOr = "-"
      end
      @status = aa[7].chomp if(!aa[7].nil?)
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
  
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@ampliconId.nil? || @ampliconId.length < 1)
              @errorLevel = 6
              return
      end
      if(@ncbiBuild < Constants::CurrentBuild)
          @errorLevel = 7
          return
      end
      if(@chromosome.nil? || @chromosome.length < 1)
          @errorLevel = 8
          return
      end
      
      if(!Constants::ChromosomeHash.has_key?(@chromosome))
          @errorLevel =  9
          return
      end
      
      chromosomeLength = Constants::ChromosomeHash[@chromosome]
    
      if(@start >= @stop)
        @errorLevel =  10
        return
      end
    
      if(@start > chromosomeLength || @stop > chromosomeLength)
        @errorLevel = 11
        return
      end
      
      if(@start < 1 || @stop < 1)
        @errorLevel = 12
        return
      end
      @chromosome = "chr#{@chromosome.upcase}"
      
      
      
      if(@primer_frw.nil? || @primer_frw.length < 10 )
        @errorLevel = 13
        return
      end
      
      if(@primer_rv.nil? || @primer_rv.length < 10 )
        @errorLevel = 14
        return
      end

      if(@status.nil? || @status.length < 1 )
        @errorLevel = 15
        return
      end
      
      if(!Constants::StatusHash.has_key?(@status.upcase))
          @errorLevel =  16
          return
      end
      
      @status.capitalize!
       
    end
  end


class SampleSequencingFile

  attr_accessor :sampleId, :ampliconId, :numberOfReadsAtempted, :numberOfReadsPassed, :pass, :q30OverAmpliconLength,
  :chemistry, :validate, :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
    if(errLev == 31)
      chemistryValues = Constants::ChemistryHash.keys.sort.join(",")
      errorString = "The Chemistry #{@chemistry} #{Constants::ErrorLevelHash[errLev]} #{chemistryValues}"
      return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
    else
      return "#{Constants::ErrorLevelHash[errLev]}"
    end
  end


  def initialize(line)
    @sampleId = nil
    @ampliconId= nil
    @chemistry = nil
    @validate = true
    @numberOfReadsAtempted = nil
    @numberOfReadsPassed = nil
    @q30OverAmpliconLength = nil
    @pass = nil
    @currentLine = line
    @errorLevel = 0

    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      lineLength = aa.length
      if(lineLength < 2 or aa[1].nil?)
        $stderr.puts "Line contains only one column Why??? #{aa}"
      elsif(lineLength == 2 and !aa[0].nil? and !aa[1].nil?) # we need an emptyClass
        @sampleId = aa[0].chomp if(!aa[0].nil?)
        @ampliconId = aa[1].chomp if(!aa[1].nil?)
        @numberOfReadsAtempted = ""
        @numberOfReadsPassed = ""
        @pass = ""
        @q30OverAmpliconLength = ""
        @chemistry = ""
        @validate = false
      else
        @sampleId = aa[0].chomp if(!aa[0].nil?)
        @ampliconId = aa[1].chomp if(!aa[1].nil?)
        @numberOfReadsAtempted = aa[2].to_i if(!aa[2].nil?)
        @numberOfReadsPassed = aa[3].to_i if(!aa[3].nil?)
        if(@numberOfReadsPassed > 1)
          @pass = true
        else
          @pass = false
        end
        @q30OverAmpliconLength = aa[4].to_f if(!aa[4].nil?)
        @chemistry = aa[5].chomp if(!aa[5].nil?)
      end
    end
    validate(line, lineLength) if(@validate)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
        else
          @errorLevel = 5
        end
        return
      end

      if(@sampleId.nil? || @sampleId.length < 1)
              @errorLevel = 17
              return
      end

      if(@ampliconId.nil? || @ampliconId.length < 1)
              @errorLevel = 6
              return
      end
      
      if(@numberOfReadsAtempted < 1)
          @errorLevel = 28
          return
      end
      
      if(@q30OverAmpliconLength > 1.05)
          @errorLevel =  29
          return
      end
      
      if(@chemistry.nil? || @chemistry.length < 1)
        @errorLevel =  30
        return
      end
      
      if(!Constants::ChemistryHash.has_key?(@chemistry.upcase))
        @errorLevel =  31
        return
      end
      
  end

  def to_sample(standart_table=0)
    if(standart_table == 0)
      baseStr = "#{@sampleId}\t#{@ampliconId}\t#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@q30OverAmpliconLength}\t#{@chemistry}"
    elsif(standart_table == 1)
      baseStr = "#{@ampliconId}\t#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@pass}\t#{@q30OverAmpliconLength}\t#{Constants::ChemistryHash[@chemistry.upcase]}"   
    elsif(standart_table == 2)
      baseStr = "#{@numberOfReadsAtempted}\t#{@numberOfReadsPassed}\t#{@pass}\t#{@q30OverAmpliconLength}\t#{Constants::ChemistryHash[@chemistry.upcase]}"
    else
      @pass = false if(@pass.nil? || @pass == "")
      baseStr = "#{@pass}"
    end
    return baseStr
  end

  def self.getFields(standart_table=0)
    if(standart_table == 0)
      baseFields = "sampleId\tampliconId\tnumberOfReadsAtempted\tnumberOfReadsPassed\tq30/AmpliconLength\tchemistry"
    elsif(standart_table == 1)
      baseFields = "ampliconId\tnumberOfReadsAtempted\tnumberOfReadsPassed\tpass\tq30/AmpliconLength\tchemistryCode"   
    else
      baseFields = "numberOfReadsAtempted\tnumberOfReadsPassed\tpass\tq30/AmpliconLength\tchemistryCode"
    end
    return baseFields
      
  end
  
  def self.getFieldTypes(standart_table=0)
    if(standart_table == 0)
      baseFields = "text:255\ttext:255\tinteger_32\tinteger_32\tfloat\ttext:255"
    elsif(standart_table == 1)
      baseFields = "text:255\tinteger_32\tinteger_32\tboolean\tfloat\tinteger_32"   
    else
      baseFields = "integer_32\tinteger_32\tboolean\tfloat\tinteger_32"
    end
    return baseFields
      
  end
  

  end



class RoiFile

  attr_accessor :roiId, :ncbiBuild, :chromosome, :start, :stop, :size, :entrezGeneId,
  :errorLevel, :currentLine

  ExpectedLineLength = 6 

  def returnErrorMessage(errLev)
      if(errLev == 9)
          chromosomeValues = Constants::ChromosomeHash.keys.sort.join(",")
          errorString = "The chromosome #{@chromosome} #{Constants::ErrorLevelHash[errLev]} #{chromosomeValues}"
          return errorString
      elsif(errLev == 4 or errLev == 5 )
          errorString = "#{Constants::ErrorLevelHash[errLev]} = #{@currentLine}"
          return errorString
      elsif(errLev == 10)
         errorString = "#{Constants::ErrorLevelHash[errLev]} start = #{@start} and stop = #{@stop}"
         return errorString
      elsif(errLev == 11)
         errorString = "#{Constants::ErrorLevelHash[errLev]} chromosome #{@chromosome} is #{Constants::ChromosomeHash[@chromosome]} and you are providing start = #{@start} and stop = #{@stop}"
         return errorString
      else
            return "#{Constants::ErrorLevelHash[errLev]}"
      end
  
  end


  def initialize(line)
    @roiId, @ncbiBuild, @chromosome, @start, @stop, @size = nil
    @entrezGeneId = 0
    @currentLine = line
    @errorLevel = 0
    chromosomeLength = 0
    @errorLevel = 3 if(line.nil? or line.empty?)
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(/\t/)
      @roiId = aa[0].chomp if(!aa[0].nil?)
      @ncbiBuild = aa[1].to_f if(!aa[1].nil?)
      @chromosome = aa[2].chomp if(!aa[2].nil?)
      @start = aa[3].to_i
      @stop = aa[4].to_i
      @size = @stop - @start
      if(!aa[5].nil? and aa[5].size > 0)
        aa[5].chomp!
        aa[5] = "0" if(aa[5] =~ /null/i)
        @entrezGeneId = aa[5].chomp.to_i
      elsif(aa[5].nil?)
        aa[5] = "0"
        @entrezGeneId = aa[5].chomp.to_i
      end
      lineLength = aa.length
    end
    validate(line, lineLength)
  end
 
  def validate(line, lineLength)

      if(lineLength > ExpectedLineLength || lineLength < ExpectedLineLength)
        if(lineLength > ExpectedLineLength)
          @errorLevel = 4
       else
          @errorLevel = 5
        end
        return
      end

      if(@roiId.nil? || @roiId.length < 1)
              @errorLevel = 1
              return
      end
      if(@ncbiBuild < Constants::CurrentBuild)
          @errorLevel = 7
          return
      end
      if(@chromosome.nil? || @chromosome.length < 1)
          @errorLevel = 8
          return
      end
      
      if(!Constants::ChromosomeHash.has_key?(@chromosome))
          @errorLevel =  9
          return
      end
      
      chromosomeLength = Constants::ChromosomeHash[@chromosome]
    
      if(@start > @stop)
        @errorLevel =  10
        return
      end
    
      if(@start > chromosomeLength || @stop > chromosomeLength)
        @errorLevel = 11
        return
      end
      
      if(@start < 1 || @stop < 1)
        @errorLevel = 12
        return
      end
      @chromosome = "chr#{@chromosome.upcase}"
      
      if(@entrezGeneId < 0 )
        @errorLevel = 2
        return
      end
       
    end
  end


        
end; end; end; end;
