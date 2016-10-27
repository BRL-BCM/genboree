#!/usr/bin/env ruby

# Loading libraries
require 'pp'
require 'md5'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/sql/binning'
require 'brl/genboree/hdhv'
require 'brl/genboree/helpers/sorter'
require 'brl/genboree/helpers/expander'

############################################################################
# This class is used to validate wig (variableStep and fixedStep files)
# Usage:
# validator = WigValidator.new(fullPathToWigFile, dbuObject)
# validator.validateWig()
# errorList = validator.giveErrorList()

# Note that the validator will keep on accumulating errors till it finds 20 error instances
# It will then raise an Argument error. The giveErrorList method will return an empty string if
# there were no errors found
# To check if the file requires sorting:

# For fixedStep:
# validator.interSort will be equal to :YES
# For variableStep
# validator.intraSort will be equal to :YES, if the all the records within the block need to be sorted
# validator.intersort will be equal to :YES, if the blocks only need to be sorted amon themselves. This
# is only possible if ALL the records in ALL the blocks of a variable step file are sorted and only the chromosomes
# are out of order

class WigValidator
  #################
  # Constants
  BUFFERSIZE = 32000000
  MAXERROR = 20
  #################
  #################
  # variables
  ################
  attr_accessor :inputFile, :email, :sortRequired, :errorList, :lineCount, :errorCount
  attr_accessor :blockHash, :refseq, :dbu, :allFrefHash, :fileFormat, :currentChr, :processedChr
  attr_accessor :blockStart, :chrCheck, :interSort, :intraSort, :sortRequired
  ################
  # Methods
  ################
  # [+inputFile+] full path to the wig file to be validated
  # [+dbu+] dbUtil object for the database where the file is intended to be uploaded
            # This is used to collect info for all the entry points for the database
            # and make sure bogus entry points are reported. 
  def initialize(inputFile, dbu)
    @inputFile = inputFile
    @dbu = dbu
    @fileFormat = nil
    @errorList = ""
    @currentChr = nil
    @errorCount = 0
    @blockStart = nil
    @processedChr = Hash.new
    @sortRequired = @interSort = @intraSort = :NO # initialize all to :NO
    raise ArgumentError, "File: #{@inputFile} does not exist.", caller if(!File.exists?(@inputFile))
    # Get the list of entrypoints (required during validation)
    @allFrefHash = Hash.new
    allFrefRecords = @dbu.selectAllRefNames()
    raise ArgmentError, "No entry point information found for dbUtil object: #{@dbu}", caller if(allFrefRecords.empty? or allFrefRecords.nil?)
    allFrefRecords.each { |record|
      @allFrefHash[record['refname']] = record['rid'].to_i
    }
  end
  
  # generates a string with errors encountered during validation
  # [+returns+] @errorList
  def giveErrorList()
    return @errorList
  end
  
  # [+returns+] @sortRequired (:YES or :NO)
  # For more info on sorting, read documentation above
  def isSortReq?()
    return @sortRequired
  end
  
  # validates the entire wig file
  # [+returns+] nil
  def validateWig()
    wigReader = BRL::Util::TextReader.new(@inputFile)
    orphan = nil
    @lineCount = 0
    # first make sure that the first non empty, non commented line is either a track header or a block header
    # If the first non empty, non commented line is a track header, the second non commented , non empty line has to be a block header
    # Use this block header to set the file format for the entire file (fixed step or variable step)
    nonBlankLine = readFirstNonBlank(wigReader)
    if(nonBlankLine !~ /^track/)
      if(nonBlankLine =~ /^fixedStep/ or nonBlankLine =~ /^variableStep/)
        validateBlockHeader(nonBlankLine)
        # Validate the block header
      else
        @errorList << "Block header not found as the first non-empty, non-commented line in the absence of track header\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)  
      end
    else
      # validate the track header
      validateTrackHeader(nonBlankLine)
      raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
      # now the second non-empty, non-commented line has to be the block header
      nonBlankLine = readFirstNonBlank(wigReader)
      if(nonBlankLine =~ /^fixedStep/ or nonBlankLine =~ /^variableStep/)
        validateBlockHeader(nonBlankLine)
        # Validate the block header
      else
        @errorList << "Block header not found as the next non-empty, non-commented line after the track header\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)  
      end
    end
    # Now validate the rest of the file
    @checkOrder = nil
    oprhan = nil
    errorCount =  0
    chrCheck = @currentChr
    @processedChr[@inputFile] = Hash.new
    startCoordOfBlock = nil # variable to check if blocks need to be sorted relative to each other for variableStep data
    while(!wigReader.eof?)
      buffRead = wigReader.read(BUFFERSIZE)
      buffReadIO = StringIO.new(buffRead)
      buffReadIO.each_line { |line|
        line = orphan + line if(!orphan.nil?)
        orphan = nil
        if(line =~ /\n$/)
          @lineCount += 1
          line.strip!
          next if (line.empty? or line.nil?)
          # Check for block header lines
          if (line =~ /^variableStep/ or line =~ /^fixedStep/)
            if(@checkOrder.nil?)
              @errorList << "Block header is not followed by any records/scores at line number: #{@lineCount}. Possible Empty Block?"
              @errorCount += 1
              raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
            end
            validateBlockHeader(line) # Validate block
            @checkOrder = nil
            startCoordCheck = 0
          # Check for bad format
          # Cannot allow just anything to be processed
          # Throw exception if line is not any of:
          # 1) A commented line
          # 2) An empty line
          # 3) Records following a block header (fixed step/ variable step)
          elsif(line !~ /^#/ and line !~ /^\s*$/ and line !~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i and line !~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i)
            @errorList << "Bad format at line number: #{@lineCount}"
            @errorCount += 1
            raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
          # Regular expression for a fixed step record
          elsif(line =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i and @fileFormat == 'fixedStep')
            @checkOrder = line
          # Regular expression for a variable step record
          elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i and @fileFormat == 'variableStep')
            data = line.split(/\s+/)
            # Check if records for variable step data are in order.
            # It is unwise to sort just the blocks relative to each other based on the start coordinate of
            # the blocks since the first coordinate may not be the REAL first coordinate of the block
            if(@checkOrder.nil?)
              @checkOrder = data[0].to_i
              # This part checks if the blocks just need to be sorted among themselves
              # If only the first coordinate of a block is smaller than the first coordinate of the previous
              # block and the records in both the blocks are sorted, then we just need to rearrange the blocks similar
              # to sorting fixed step files. Another case where we can get away with only rearranging blocks is if the
              # blocks of a chromosome are not together but the records of ALL blocks are sorted. The arrangement of the
              # chromosomes is check in checkBlockHeader(). The bottome line is that in order for this approach to work,
              # the records in the block MUST be sorted so that we can trust the first coordinate of each block to
              # be the start coordinate of the block
              if(!startCoordOfBlock.nil?)
                # Check if its the same chromosome as before
                if(chrCheck == @currentChr)
                  @sortRequired = @interSort = :YES if(@checkOrder < startCoordOfBlock) # This means that the blocks need to be sorted among themselves
                else
                  chrCheck = @currentChr
                end
              end
              startCoordOfBlock = @checkOrder
            # This part checks if its necessary to sort the records inside a block
            # Knowing what kind of sorting is required/not required will save a lot of time!
            else
              if(data[0].to_i >= @checkOrder)
                @checkOrder = data[0].to_i
              else
                @sortRequired = @intraSort = :YES # This means that the records within blocks need to be sorted
                @checkOrder = data[0].to_i
              end
            end
          elsif((line =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i and @fileFormat == 'variableStep') or (line =~ /^(?:(\+|\-)?\d+)\s+(?:(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?)$/i and @fileFormat == 'fixedStep'))
            @errorList << "Bad format at line number: #{@lineCount} Incorrect record type: #{line} for file format: #{@fileFormat} ?"
            @errorCount += 1
            raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
          end
        else
          orphan = line
        end
      }
    end
    @processedChr[@inputFile][@currentChr] = nil  
  end
  
  # reads untill the first non-blank line of the file
  # [+reader+] file reader
  # [+returns+'] the first non blank line from the reader's current position
  def readFirstNonBlank(reader)
    firstNonBlank = nil
    reader.each_line { |line|
      @lineCount += 1
      if(line =~ /\S/ and line !~ /^\s*#/)
        firstNonBlank = line.strip
        break
      end
    }
    return firstNonBlank
  end
  
  # validates the block header in the wiggle files
  # Keeps track if all the blocks of a chromosome are together
  # [+line+] line containing the block header
  # [+returns+] nil
  def validateBlockHeader(line)
    line.strip!
    blockHeader = line.split(/\s+/)
    data = line.split(/\s+/)
    @blockHash = Hash.new
    chrMatch = startMatch = 0
    # Break block header into attribute value pairs
    data.each { |attr|
      avp = attr.split("=")
      if(!@blockHash.has_key?(avp[0]))
        @blockHash[avp[0]] = avp[1]
      end
    }
    
    # Check if 'chrom' value pair exists in the block header.
    if(!@blockHash["chrom"].nil?) 
      # Check if its a genuine chromosome
      if(!@allFrefHash.has_key?(@blockHash['chrom']))
        @errorList << "Unrecognized entrypoint/chromosome: #{@blockHash['chrom']}. Line number: #{@lineCount}. Please make sure if the entry point has already been uploaded and/or the format of the block header is in accordance to the UCSC standards.\n" 
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
      end
      chrMatch += 1
    end
    # Check for the 'start' value pair in the block header (not present for variableStep)
    # If present, the value should be an integer and non 0
    if(!@blockHash['start'].nil?)
      start = @blockHash['start']
      if(start !~ /^\d+$/ or start.to_i == 0)
        @errorList << "start value either missing or 0 or not an integer in block header. Line number: #{@lineCount}\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
      end
      startMatch +=1 
    end
    # Make sure that 'span' and 'step' if present are integer values and non zero
    if(!@blockHash['span'].nil?)
      span = @blockHash['span']
      if(span !~ /^\d+$/ or span.to_i == 0)
        @errorList << "span value missing or 0 or not an integer in block header. Line number: #{@lineCount}\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount == MAXERROR)
      end
    end
    if(!@blockHash['step'].nil?)
      step = @blockHash['step']
      if(step !~ /^\d+$/ or step.to_i == 0)
        @errorList << "step value missing or 0 or not an integer in block header. Line number: #{@lineCount}\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount == MAXERROR)
      end
    end
    
    # More checks for block header. Phew!
    # Only allow variable and fixed step block headers
    if(@fileFormat.nil?)
      @fileFormat = blockHeader[0]
      # validation for fixedStep
      if(@fileFormat == "fixedStep")
        if((chrMatch == 0 or startMatch == 0))
          @errorList << "chrom or start values empty in block header. Line number: #{@lineCount}\n"
          @errorCount += 1
          raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
        elsif((!@blockHash["span"].nil? and !@blockHash["step"].nil?) and (@blockHash["step"].to_i < @blockHash["span"].to_i))
          @errorList << "value for step is smaller than value for span in block header. Line number: #{@lineCount}\n"
          @errorCount += 1
          raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
        end
      # validation for variableStep
      elsif(@fileFormat == "variableStep")
        if(chrMatch == 0)
          @errorList << "chrom value empty in block header. Line number: #{@lineCount}\n"
          @errorCount += 1
          raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
        end
      # Bad format
      else
        @errorList << "The block header line is either incorrectly formatted or is either of 'bed' (not supported) fomat. Line number: #{@lineCount}\n"
        @errorCount += 1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
      end
    else
      if(@fileFormat != blockHeader[0])
        @errorList << "Inconsistent file format. The file starts with #{@fileFormat}. Block header with #{blockHeader} found on #{@lineCount}\n"
        @errorCount +=1
        raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
      else
        # validation for fixedStep
        if(@fileFormat == "fixedStep")
          if((chrMatch == 0 or startMatch == 0))
            @errorList << "chrom or start values empty in block header. Line number: #{@lineCount}\n"
            @errorCount += 1
            raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
          elsif((!@blockHash["span"].nil? and !@blockHash["step"].nil?) and (@blockHash["step"].to_i < @blockHash["span"].to_i))
            @errorList << "value for step is smaller than value for span in block header. Line number: #{@lineCount}\n"
            @errorCount += 1
            raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
          end
        # validation for variableStep
        elsif(@fileFormat == "variableStep")
          if(chrMatch == 0)
            @errorList << "chrom value empty in block header. Line number: #{@lineCount}\n"
            @errorCount += 1
            raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
          end
        # Bad format
        else
          @errorList << "The block header line is either incorrectly formatted or is either of 'bed' (not supported) fomat. Line number: #{@lineCount}\n"
          @errorCount += 1
          raise ArgumentError, "ERRORS: #{@errorList}" if(@errorCount >= MAXERROR)
        end
      end
    end
    
    # Check if file requires sorting
    # This refers to checking if all the blocks for all the choromosomes are together and not randomly distributed in the wiggle file
    # This part applies to both variable step/fixed step files. 
    if(@currentChr.nil?)
      @currentChr = @blockHash['chrom']
    else
      if(@currentChr != @blockHash['chrom'])
        if(@processedChr[@inputFile].has_key?(@blockHash['chrom']))
          @sortRequired = @interSort = :YES
          @processedChr[@inputFile][@currentChr] = nil
        else
          @processedChr[@inputFile][@currentChr] = nil
        end
        @currentChr = @blockHash['chrom']
      end
    end
    # Also check if starts are in increasing order (for fixedStep)
    # It is important that blocks for a chromosome are in increasing order with
    # respect to the coordinates so that we can merge blocks
    if(@blockStart.nil?)
      @blockStart = @blockHash['start'].to_i
      @chrCheck = @currentChr
    else
      if(@chrCheck == @currentChr)
        @sortRequired = @interSort = :YES if(@blockHash['start'].to_i < @blockStart)
        @blockStart = @blockHash['start'].to_i
      else
        @chrCheck = @currentChr
        @blockStart = @blockHash['start'].to_i
      end
    end
  end
  
  # validates the track header
  # [+line+] track header line
  # [+returns+] nil
  def validateTrackHeader(line)
    # Store AVPS for track
    trackHash = Hash.new
    rr = /([^= \t]+)\s*=\s*(?:(?:([^ \t"']+))|(?:"([^"]+)")|(?:'([^']+)'))/ # regular expression for parsing track header
    line.scan(rr) { |md|
      trackHash[md[0]] = "#{md[1]}#{md[2]}#{md[3]}" if(!trackHash.has_key?(md[0]))
    }
    # Check all the attr value pairs
    windowingMethod = (trackHash['windowingFunction'] ? trackHash['windowingFunction'] : nil)
    if(!windowingMethod.nil?)
      if(windowingMethod != 'mean' and windowingMethod != 'maximium' and windowingMethod != 'minimum')
        @errorList << "Unsupported windowingFunction in track header: #{windowingMethod}\n"
        @errorCount += 1
      end
    end
    visibility = (trackHash['visibility'] ? trackHash['visibility'] : nil)
    if(!visibility.nil?)
      if(visibility != 'hide' and visibility != 'dense' and visibility != 'full' and visibility != '0' and visibility != '1' and visibility != '2')
        @errorList << "Unsupported visibility option in track header: #{visibility}\n"
        @errorCount += 1
      end
    end
    viewLimits = (trackHash['viewLimits'] ? trackHash['viewLimits'] : nil)
    if(!viewLimits.nil?)
      limits = viewLimits.split(":")
      if(limits.size != 2)
        @errorList << "Unsupported viewLimits option in track header: #{viewLimits}\n"
        @errorCount += 1
      end
    end
    autoScale = (trackHash['autoScale'] ? trackHash['autoScale'] : nil)
    if(!autoScale.nil?)
      if(autoScale != 'on' and autoScale != 'off')
        @errorList << "Unsupported autoScale option in track header: #{autoScale}\n"
        @errorCount += 1
      end
    end
    heightPixels = (trackHash['maxHeightPixels'] ? trackHash['maxHeightPixels'] : nil)
    if(!heightPixels.nil?)
      pixelArray = heightPixels.split(":")
      if(pixelArray.size != 3)
        @errorList << "Unsupported maxHeightPixels option in track header: #{heightPixels}\n"
        @errorCount += 1
      end 
    end
    color = (trackHash['color'] ? trackHash['color'] : nil)
    if(!color.nil?)
      rgb = color.split(",")
      # check if all values are between 0 and 255
      # also check if there are 3 values (r, g, b)
      if(rgb.size != 3)
        @errorList << "Unsupported color option in track header: #{color}\n" 
        @errorCount += 1
      end
      rgb.each { |val|
        if(val.to_i > 255 or val.to_i < 0)
          @errorList << "Unsupported color option in track header: #{color}. Value of r, g and b has to be between 0 and 255\n"
          @errorCount += 1
        end
      }
    end
    altcolor = (trackHash['altColor'] ? trackHash['altColor'] : nil)
    if(!altcolor.nil?)
      rgb = color.split(",")
      # check if all values are between 0 and 255
      # also check if there are 3 values (r, g, b)
      if(rgb.size != 3)
        @errorList << "Unsupported altColor option in track header: #{altcolor}\n" 
        @errorCount += 1
      end
      rgb.each { |val|
        if(val.to_i > 255 or val.to_i < 0)
          @errorList << "Unsupported altColor option in track header: #{altcolor}. Value of r, g and b has to be between 0 and 255\n"
          @errorCount += 1
        end
      }
    end
  end
  
end


