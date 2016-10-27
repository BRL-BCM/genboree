#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'md5'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/textFileUtil'
require 'brl/fileFormats/tcgaParsers/tcgaFiles'
require 'brl/fileFormats/lffHash'



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
module BRL ; module FileFormats; module TCGAParsers
      
class TableToHashCreator

  def self.ampliconIdToAmpliconTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "AmpliconId #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = rg 
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end
  
  def self.getSortedArrayOfAmpliconIds(ampliconFileName)
    retVal = {}
    ampliconArray = nil
    return retVal if( ampliconFileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(ampliconFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "AmpliconId #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = nil 
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      ampliconArray = retVal.keys.sort 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    
    
    return ampliconArray
  end
  
###########################################  
 
  def self.getSortedArrayOfSampleIds(sampleFileName)
    retVal = {}
    sampleArray = nil

    return retVal unless( !sampleFileName.nil? )

    reader = BRL::Util::TextReader.new(sampleFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = SampleFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.sampleId))
          $stderr.puts "Sample Id #{rg.sampleId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.sampleId] = rg 
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      sampleArray = retVal.keys.sort 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return sampleArray
  end
 
  
###########################################  
  def self.ampliconIdToPrimersLff(fileName, lffFileName, clName="Primers", type="institution", subtype="primers")
    retVal = {}
    return retVal if( fileName.nil? || lffFileName.nil?)
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    fileWriter = BRL::Util::TextWriter.new(lffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =  #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "AmpliconId #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = nil
          fileWriter.print "#{clName}\t#{rg.ampliconId}\t#{type}\t#{subtype}\t#{rg.chromosome}\t"
          fileWriter.print "#{rg.primer_frwStart}\t#{rg.primer_frwStop}\t#{rg.primer_fwOr}\t0\t0\t.\t.\t"
          fileWriter.print "primerSize=#{rg.primer_frwSize}; primerSequence=#{rg.primer_frw};"
          fileWriter.puts ""
          
          fileWriter.print "#{clName}\t#{rg.ampliconId}\t#{type}\t#{subtype}\t#{rg.chromosome}\t"
          fileWriter.print "#{rg.primer_rvStart}\t#{rg.primer_rvStop}\t#{rg.primer_rvOr}\t0\t0\t.\t.\t"
          fileWriter.print "primerSize=#{rg.primer_rvSize}; primerSequence=#{rg.primer_rv};"
          fileWriter.puts ""
        end
        lineCounter = lineCounter + 1
      }
      fileWriter.close()
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

###########################################  
  

  def self.ampliconIdToLff(fileName, lffFileName, clName="Amplicons", type="institution", subtype="amplicons")
    retVal = {}
    return retVal if( fileName.nil? || lffFileName.nil?)
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    fileWriter = BRL::Util::TextWriter.new(lffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "AmpliconId #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = nil          
          fileWriter.print "#{clName}\t#{rg.ampliconId}\t#{type}\t#{subtype}\t#{rg.chromosome}\t"
          fileWriter.print "#{rg.start}\t#{rg.stop}\t+\t0\t0\t.\t.\t"
          fileWriter.print "primer_frw=#{rg.primer_frw}; primer_rv=#{rg.primer_rv}; "
          fileWriter.print "status=#{rg.status}; "
          fileWriter.puts ""
        end
        lineCounter = lineCounter + 1
      }
      fileWriter.close()
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end
#######################################  TableToHashCreator.generateListOfGenesFileFromLff(listOfGenesFileName, lociLffFileName)
  def self.generateListOfGenesFileFromLff(listOfGenesFileName, lociLffFileName)
    hashOfGenes = Hash.new {|hh,kk| hh[kk] = nil }
    if(listOfGenesFileName.nil? || lociLffFileName.nil?)
      $stderr.print("Error you need to provide a lffFileName and the name of the final geneList")
      exit 300
    end
   
   lociReader = BRL::Util::TextReader.new(lociLffFileName)
    begin
      lociReader.each { |ff|
        ff.each { |line|
            line.strip!
            tAnno = line.split(/\t/)
            next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
            myHash = LFFHash.new(line)
            name = "#{myHash.lffName}".strip().gsub(/\.\d+$/, "").strip
            hashOfGenes[name] = nil if(!hashOfGenes.has_key?(name))
        }
      }  
    rescue => err
      $stderr.puts "ERROR: File #{targetFile} do not exist!. Details: method = generateListOfGenesFileFromLff #{err.message}"
      #      exit 345 #Do not exit just record the error!
    end
    lociReader.close()
    
    
    fileWriter = BRL::Util::TextWriter.new(listOfGenesFileName)

    hashOfGenes.keys.sort.each { |myGeneName|
      fileWriter.puts myGeneName
    }
    
    fileWriter.close()
    
    
  end
#######################################
  def self.mappingAmpliconSeqFileToRoiSeqFile( directoryName, largeAnnotationFile, smallAnnotationFile, newFileName  )
  oldSubtype1 = "AmpOneXCoverage".to_sym
  oldSubtype2 = "AmpTwoXCoverage".to_sym
  newSubtype1 = "oneXCoverage".to_sym
  newSubtype2 = "twoXCoverage".to_sym


    if(largeAnnotationFile.nil? || directoryName.nil? || smallAnnotationFile.nil? || newFileName.nil?)
      $stderr.print("Error you need to provide a directoryName, the name of the file with large annotations and the name of the file with small annotations")
      exit 300
    end
           
    Dir.chdir(directoryName)
    fileWriter = BRL::Util::TextWriter.new(newFileName)

    targetArray = Array.new()

    queryReader = BRL::Util::TextReader.new(smallAnnotationFile)
    targetReader = BRL::Util::TextReader.new(largeAnnotationFile)
    begin
      targetReader.each { |ff|
        ff.each { |line|
            line.strip!
            tAnno = line.split(/\t/)
            next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
            myHash = LFFHash.new(line)
            targetArray << myHash
        }
      }  
    rescue => err
      $stderr.puts "ERROR: File #{targetFile} do not exist!. Details:  method = mappingAmpliconSeqFileToRoiSeqFile #{err.message}"
      #      exit 345 #Do not exit just record the error!
    end
    targetReader.close()
    begin
        queryReader.each { |ff|
            ff.each { |line|
                line.strip!
                tAnno = line.split(/\t/)
                next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                myQuery = LFFHash.new(line)
                targetArray.each { |myTarget|
                      next if(myQuery.lffChr != myTarget.lffChr || myTarget.lffStart > myQuery.lffStop || myQuery.lffStart > myTarget.lffStop)
                      myQuery.lffName=myTarget.lffName
                      myQuery.lffSubtype=newSubtype1  if(myQuery.lffSubtype == oldSubtype1)
                      myQuery.lffSubtype=newSubtype2  if(myQuery.lffSubtype == oldSubtype2)
                      fileWriter.puts myQuery.to_lff
                } 
            }
        }
      rescue => err
        $stderr.puts "ERROR: File #{queryFile} do not exist!. Details: method = mappingAmpliconSeqFileToRoiSeqFile #{err.message}"
        #      exit 348 #Do not exit just record the error!
    end
    fileWriter.close()
  end 

#######################################
  def self.roiIdToHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.roiId] = rg          
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

##########################################

  def self.mutationFileToLff(fileName, mutationLffFileName, clName="Mutations", type="institution", subtype="SNPs")
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    fileWriter = BRL::Util::TextWriter.new(mutationLffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/ or line =~ /^\s*Hugo_Symbol/i)
          lineCounter = lineCounter + 1
          next
        end
        rg = MutationFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.id))
          $stderr.puts "The mutationId is #{rg.id} from line #{lineCounter} is present multiple times line skipped"  
        else
          retVal[rg.id] = nil          
          fileWriter.print "#{clName}\t#{rg.id}\t#{type}\t#{subtype}\t#{rg.chromosome}\t"
          fileWriter.print "#{rg.start}\t#{rg.stop}\t#{rg.strand}\t0\t0\t.\t.\t"
          fileWriter.print "geneName=#{rg.hugoSymbol}; "
          fileWriter.print "discoveredBy=#{rg.center}; "          
          fileWriter.print "locusLinkId=#{rg.entrezGeneId}; "
          fileWriter.print "variantClassification=#{rg.variantClassification}; " if(!rg.variantClassification.nil? and rg.variantClassification !~ /unknown/i )
          fileWriter.print "variantType=#{rg.variantType}; " if(!rg.variantType.nil? and rg.variantType !~ /unknown/i )
          fileWriter.print "referenceAllele=#{rg.referenceAllele}; "
          fileWriter.print "tumorSeqAllele1=#{rg.tumorSeqAllele1}; "
          fileWriter.print "tumorSeqAllele2=#{rg.tumorSeqAllele2}; "
          fileWriter.print "dbSNPRS=#{rg.dbSNPRS}; " if(!rg.dbSNPRS.nil? and rg.dbSNPRS !~ /unknown/i  and rg.dbSNPRS !~ /novel/i)
          fileWriter.print "novelMutation=#{rg.novelMutation}; " if(!rg.novelMutation.nil? and rg.novelMutation == true)
          fileWriter.print "dbSNPValStatus=#{rg.dbSNPValStatus}; " if(!rg.dbSNPValStatus.nil? and rg.dbSNPValStatus !~ /unknown/i)
          fileWriter.print "tumor_Sample_Barcode=#{rg.tumor_Sample_Barcode}; "
          fileWriter.print "matched_Norm_Sample_Barcode=#{rg.matched_Norm_Sample_Barcode}; "
          fileWriter.print "matchNormSeqAllele1=#{rg.matchNormSeqAllele1}; "
          fileWriter.print "matchNormSeqAllele2=#{rg.matchNormSeqAllele2}; "
          fileWriter.print "tumorValidationAllele1=#{rg.tumorValidationAllele1}; " if(!rg.tumorValidationAllele1.nil? and rg.tumorValidationAllele1.length > 0)
          fileWriter.print "tumorValidationAllele2=#{rg.tumorValidationAllele2}; " if(!rg.tumorValidationAllele2.nil? and rg.tumorValidationAllele2.length > 0)
          fileWriter.print "matchNormValidationAllele1=#{rg.matchNormValidationAllele1}; " if(!rg.matchNormValidationAllele1.nil? and rg.matchNormValidationAllele1.length > 0)
          fileWriter.print "matchNormValidationAllele2=#{rg.matchNormValidationAllele2}; " if(!rg.matchNormValidationAllele2.nil? and rg.matchNormValidationAllele2.length > 0)
          fileWriter.print "verificationStatus=#{rg.verificationStatus}; " if(!rg.verificationStatus.nil? and rg.verificationStatus !~ /unknown/i)
          fileWriter.print "validationStatus=#{rg.validationStatus}; " if(!rg.validationStatus.nil? and rg.validationStatus !~ /unknown/i)
          fileWriter.print "mutationStatus=#{rg.mutationStatus}; " if(!rg.mutationStatus.nil? and rg.mutationStatus !~ /unknown/i)
          fileWriter.print "SequencingPhase=#{rg.SequencingPhase}; " if(!rg.SequencingPhase.nil?)
          fileWriter.print "mutationId=#{rg.mutationId}; " if(!rg.mutationId.nil?)
          fileWriter.print "\t#{rg.tumorSeqAllele1}"
          fileWriter.puts ""
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

##########################################
  def self.roiIdToLff(fileName, roiLffFileName, clName="ROI", type="institution", subtype="roi")
    retVal = {}
    return retVal unless( !fileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(fileName)
    fileWriter = BRL::Util::TextWriter.new(roiLffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.roiId] = nil          
          fileWriter.print "#{clName}\t#{rg.roiId}\t#{type}\t#{subtype}\t#{rg.chromosome}\t"
          fileWriter.print "#{rg.start}\t#{rg.stop}\t+\t0\t0\t.\t.\t"
          fileWriter.print "locusLinkId=#{rg.entrezGeneId}; "
          fileWriter.puts ""
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

  def self.filteringLffUsingNumericAttValue(lffFileName, outPutFileName, attributeName, attributeThreshold, operation="moreThan", newType=nil, newSubType=nil, className=nil, attributeThresholdMax=100.0)
        fileWriter = BRL::Util::TextWriter.new(outPutFileName)
        attributeName = attributeName.to_sym
        reader = BRL::Util::TextReader.new(lffFileName)
        begin
          reader.each { |ff|
              ff.each { |line|
                  line.strip!
                  attributeValue = 0.0
                  tAnno = line.split(/\t/)
                  next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)
                  myHash = LFFHash.new(line)
                  counter = 0
                  if(myHash.key?(attributeName))
                    attributeValue = "#{myHash[attributeName]}".gsub(/\%/, "").strip
                    attributeValue = attributeValue.to_f
                  end

                  myHash.lffType=newType if(!newType.nil?)
                  myHash.lffSubtype=newSubType if(!newSubType.nil?)
                  myHash.lffClass=className if(!className.nil?)

                  if(operation == "moreThan")
                    fileWriter.puts myHash.to_lff if(attributeValue > attributeThreshold)
                  elsif(operation == "lessThan")
                    fileWriter.puts myHash.to_lff if(attributeValue < attributeThreshold)
                  elsif(operation == "lessOrEqualThan")
                    fileWriter.puts myHash.to_lff if(attributeValue <= attributeThreshold)
                  elsif(operation == "moreOrEqualThan")
                   fileWriter.puts myHash.to_lff if(attributeValue >= attributeThreshold)
                  elsif(operation == "between")
                    fileWriter.puts myHash.to_lff if(attributeValue > attributeThreshold and attributeValue < attributeThresholdMax)
                  else
                    puts "#{attributeValue.inspect}  #{operation.inspect} #{attributeThreshold.inspect}"
                  end
                  
              }
          }
      rescue => err
        $stderr.puts "ERROR: File #{lffFileName} do not exist!. Details:  method = filteringLffUsingNumericAttValue #{err.message}"
        #      exit 348 #Do not exit just record the error!
        end
      reader.close()
      fileWriter.close()
  end

  def self.filteringTabDelimitedFileUsingNumericColumn(tabDelimitedFileName, outPutFileName, columnNumber, attributeThreshold, numberOfColumns, operation="moreThan", attributeThresholdMax=100.0, preserveDefLine=true)
    fileWriter = BRL::Util::TextWriter.new(outPutFileName)
    reader = BRL::Util::TextReader.new(tabDelimitedFileName)
    headerPass = false
    begin
      reader.each { |ff|
          ff.each { |line|
              line.strip!
              attributeValue = 0.0
              tAnno = line.split(/\t/)
              
              if(line =~ /^\s*#/ and preserveDefLine and !headerPass)
                fileWriter.puts line
                headerPass = true
              end

              next if(line !~ /\S/ or line=~ /^\s*\[/ or tAnno.length < numberOfColumns or line =~ /^\s*#/)

              counter = 0
              columnNumber = columnNumber.to_i
              if(!tAnno[columnNumber].nil? and tAnno[columnNumber].length > 0)
                attributeValue = tAnno[columnNumber].gsub(/\%/, "").strip
                attributeValue = attributeValue.to_f
              end
              
              if(operation == "moreThan")
                fileWriter.puts line if(attributeValue > attributeThreshold)
              elsif(operation == "lessThan")
                fileWriter.puts line if(attributeValue < attributeThreshold)
              elsif(operation == "lessOrEqualThan")
                fileWriter.puts line if(attributeValue <= attributeThreshold)
              elsif(operation == "moreOrEqualThan")
               fileWriter.puts line if(attributeValue >= attributeThreshold)
              elsif(operation == "between")
                fileWriter.puts line if(attributeValue >= attributeThreshold and attributeValue <= attributeThresholdMax)
              else
                puts "#{attributeValue.inspect}  #{operation.inspect} #{attributeThreshold.inspect}"
              end
              
          }
      }
      rescue => err
        $stderr.puts "ERROR: File #{tabDelimitedFileName} do not exist!. Details:  method = filteringTabDelimitedFileUsingNumericColumn #{err.message}"
        #      exit 348 #Do not exit just record the error!
        end
      reader.close()
      fileWriter.close()
  end


  def self.filteringColumnsFromTabDelimitedFile(tabDelimitedFileName, outPutFileName, columnNumbers, newHeader, numberOfColumns)
        numberOfColumns = nil
        fileWriter = BRL::Util::TextWriter.new(outPutFileName)
        reader = BRL::Util::TextReader.new(tabDelimitedFileName)
        arrayOfColumns = columnNumbers.split(",") if(!columnNumbers.nil? and columnNumbers.length >0)
        numberOfColumnsToPrint = arrayOfColumns.length
        return if(numberOfColumns.nil)
        fileWriter.puts newHeader if(newHeader.nil? and newHeader.length > 0)
        begin
          reader.each { |ff|
              ff.each { |line|
                  line.strip!
                  tAnno = line.split(/\t/)
                  next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < numberOfColumns)
                  counter = 0
                  arrayOfColumns.each {|column|
                    column.to_i
                    fileWriter.print tAnno[column] if(column < numberOfColumns)
                    counter += 1
                    fileWriter.print("\t") if(counter < numberOfColumnsToPrint)
                    }
                  fileWriter.puts "" 
                  
              }
          }
      rescue => err
        $stderr.puts "ERROR: File #{tabDelimitedFileName} do not exist!. Details:  method = filteringColumnsFromTabDelimitedFile #{err.message}"
        #      exit 348 #Do not exit just record the error!
        end
      reader.close()
      fileWriter.close()
  end




  def self.roiSequencingFileToLff(roiFileName, roiSequencingLffFileName, roiSequencingFileName, clName="ROI", type="institution", numberOfSamples=0)
    retVal = {}
    return retVal if( roiFileName.nil? || roiSequencingFileName.nil? || roiSequencingLffFileName.nil?)
    # Read roi file
#    puts "roiFileName = #{roiFileName} roiSequencingLffFileName = #{roiSequencingLffFileName} roiSequencingFileName = #{roiSequencingFileName} clName= #{clName} type = #{type}"
    roiHash = TableToHashCreator.roiIdToHash(roiFileName)
    
    reader = BRL::Util::TextReader.new(roiSequencingFileName)
    fileWriter = BRL::Util::TextWriter.new(roiSequencingLffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          roiDef = roiHash[rg.roiId]
          if(roiDef.nil?)
            $stderr.puts "panic!!! definition for #{rg.roiId.inspect} do not exist in the roi definition file"
            next
          end
          begining = roiDef.start
          ending = roiDef.stop
          chromosome = roiDef.chromosome
          oneCoverageValues = rg.oneXCoverageArray
          twoCoverageValues = rg.twoXCoverageArray
          sequenceArray = rg.sequenceArray
          counter = 0
          location = 0
          subtype1 = "oneXCoverage"
          subtype2 = "twoXCoverage"
          sequenceArray.each { |position|
            location = begining + counter 
            fileWriter.print "#{clName}\t#{rg.roiId}\t#{type}\t#{subtype1}\t#{chromosome}\t"
            fileWriter.print "#{location}\t#{location}\t+\t0\t#{oneCoverageValues[counter]}\t.\t.\tbase=#{position};"
            fileWriter.puts ""
            fileWriter.print "#{clName}\t#{rg.roiId}\t#{type}\t#{subtype2}\t#{chromosome}\t"
            fileWriter.print "#{location}\t#{location}\t+\t0\t#{twoCoverageValues[counter]}\t.\t.\tbase=#{position};"
            fileWriter.puts ""            
            counter = counter + 1  
          }
#          $stderr.puts "annotation #{rg.roiId} last nucleotide = #{location} number of printed records is #{counter - 1} size is #{roiDef.size} and start = #{begining} end = #{ending}"
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end
#################################################
    def self.loadSingleColumnFile(tabDelimitedFileName, tranformKeyToUpperCase=false)
    line = nil
    return nil if( tabDelimitedFileName.nil? )
    if(!File.exist?(tabDelimitedFileName))
      $stderr.puts "Missing file #{tabDelimitedFileName}"
      return nil
    end
    
    # Read ampliconlistName file
    hashOfArraysWithTabDelimitedValues = Hash.new {|hh,kk| hh[kk] = nil }
    reader = BRL::Util::TextReader.new(tabDelimitedFileName)
    counter = 1
    begin
      reader.each { |line|
        next if(line =~ /^\s*[#]/ )
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next unless(aa.length > 0)
        if(aa[0].nil? || aa[0].length < 1)
          $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
        else
          keyToUse = aa.shift
          keyToUse.upcase! if(tranformKeyToUpperCase)
          keyToUse = keyToUse.to_sym
          hashOfArraysWithTabDelimitedValues[keyToUse] = nil
        end

        counter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}" if(!line.nil? and line.length > 0)
      exit 137
    end
    return hashOfArraysWithTabDelimitedValues
    end
#################################################
    def self.loadTabDelimitedFileWithMultipleValues(tabDelimitedFileName, tranformKeyToUpperCase=false)
    line = nil
    return nil if( tabDelimitedFileName.nil? )
    if(!File.exist?(tabDelimitedFileName))
      $stderr.puts "Missing file #{tabDelimitedFileName}"
      return nil
    end
    
    # Read ampliconlistName file
    hashOfHashes = Hash.new {|hh,kk| hh[kk] = nil }
    reader = BRL::Util::TextReader.new(tabDelimitedFileName)
    counter = 1
    begin
      reader.each { |line|
        next if(line =~ /^\s*[#]/ )
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next unless(aa.length > 1)
        if(aa[0].nil? || aa[0].length < 1)
          $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
        else
          keyToUse = aa.shift
          keyToUse.upcase! if(tranformKeyToUpperCase)
          keyToUse = keyToUse.to_sym
          if(!hashOfHashes.has_key?(keyToUse))
            hashOfHashes[keyToUse] = Hash.new {|hh,kk| hh[kk] = nil }
            hashOfHashes[keyToUse][aa] = nil
          else
            hashOfHashes[keyToUse][aa] = nil
          end          
        end

        counter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}" if(!line.nil? and line.length > 0)
      exit 137
    end
    return hashOfHashes
    end
#################################################################
    def self.loadTwoColumnFile(tabDelimitedFileName, tranformKeyToUpperCase=false)
    line = nil
    return nil if( tabDelimitedFileName.nil? )
    if(!File.exist?(tabDelimitedFileName))
      $stderr.puts "Missing file #{tabDelimitedFileName}"
      return nil
    end
    
    # Read ampliconlistName file
    hashOfArraysWithTabDelimitedValues = Hash.new {|hh,kk| hh[kk] = nil }
    reader = BRL::Util::TextReader.new(tabDelimitedFileName)
    counter = 1
    begin
      reader.each { |line|
        next if(line =~ /^\s*[#]/ )
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next unless(aa.length > 0)
        if(aa[0].nil? || aa[0].length < 1)
          $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
        else
          keyToUse = aa.shift
          keyToUse.upcase! if(tranformKeyToUpperCase)
          keyToUse = keyToUse.to_sym
          hashOfArraysWithTabDelimitedValues[keyToUse] = aa.shift
        end

        counter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}" if(!line.nil? and line.length > 0)
      exit 137
    end
    return hashOfArraysWithTabDelimitedValues
    end

#################################################
    def self.loadTabDelimitedFile(tabDelimitedFileName, tranformKeyToUpperCase=false)
    line = nil
    return nil if( tabDelimitedFileName.nil? )
    if(!File.exist?(tabDelimitedFileName))
      $stderr.puts "Missing file #{tabDelimitedFileName}"
      return nil
    end
    
    # Read ampliconlistName file
    hashOfArraysWithTabDelimitedValues = Hash.new {|hh,kk| hh[kk] = [] }
    reader = BRL::Util::TextReader.new(tabDelimitedFileName)
    counter = 1
    begin
      reader.each { |line|
        next if(line =~ /^\s*[#]/ )
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next unless(aa.length > 1)
        if(aa[0].nil? || aa[0].length < 1)
          $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
        else
          keyToUse = aa.shift
          keyToUse.upcase! if(tranformKeyToUpperCase)
          keyToUse = keyToUse.to_sym
          hashOfArraysWithTabDelimitedValues[keyToUse] = aa
        end

        counter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}" if(!line.nil? and line.length > 0)
      exit 137
    end
    return hashOfArraysWithTabDelimitedValues
    end
#################################################################
  def self.calculateAverageForGeneCompletionFile(tabDelimitedFileName)
    return nil if( tabDelimitedFileName.nil? )
    
 
    hashOfArraysWithTabDelimitedValues = TableToHashCreator.loadTabDelimitedFile(tabDelimitedFileName)
    if(hashOfArraysWithTabDelimitedValues.nil?)
      $stderr.puts "Unable to calculateAverageForGeneCompletionFile"
      return nil
    end
    numbArrays = hashOfArraysWithTabDelimitedValues.length.to_f
    numberOfRecords =  0.0
    averageNumberSamples = 0.0
    averageNumberSamplesPass = 0.0
    averagePercentageSamplesPass = 0.0

    
    hashOfArraysWithTabDelimitedValues.each {|key, array|
      numberOfFields = array.length
#      $stderr.puts "processing gene #{key} values"
      if(numberOfFields == 4)
          numberOfRecords += array[0].to_f
          averageNumberSamples += array[1].to_f
          averageNumberSamplesPass += array[2].to_f
          averagePercentageSamplesPass += array[3].to_f
      end
    }

    #tempString = sprintf("%.2f\t%.2f\t%.2f\t%.2f", numberOfRecords, averageNumberSamples, averageNumberSamplesPass, averagePercentageSamplesPass)
    fileWriter = BRL::Util::TextWriter.new(tabDelimitedFileName, "a+")
    #fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
    #fileWriter.puts "Total\t#{tempString}"

    
    numberOfRecords =  numberOfRecords / numbArrays
    averageNumberSamples = averageNumberSamples / numbArrays
    averageNumberSamplesPass = averageNumberSamplesPass / numbArrays
    averagePercentageSamplesPass = averagePercentageSamplesPass / numbArrays
    
    tempString = sprintf("%.2f\t%.2f\t%.2f\t%.2f", numberOfRecords, averageNumberSamples, averageNumberSamplesPass, averagePercentageSamplesPass)

#    fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
    fileWriter.puts "#Number of Genes\t#{numbArrays}"
    fileWriter.puts "#Average\t#{tempString}"
    fileWriter.close()
  end 
####################################################
  def printHtmlTable(title, tableTile, jspLink, institutions)
  puts "<TABLE BORDER=\"0\" CELLPADDING=\"3\" CELLSPACING=\"0\" width=\"600px\">
    <TR>
      <TD align=\"center\"><h2>#{title}</h2></TD>
    </TR>
    <TR>
      <TD align=\"center\">
        <TABLE BORDER=\"1\" WIDTH=\"500px\">
          <TR>
            <TH COLSPAN=\"5\" WIDTH=\"100%\">#{tableTile}</TH>
          </TR>
          <TR>
            <TD > &nbsp;&nbsp;</TD>"
  institutions.names.each{|name|
  puts "          <TD><B><A HREF=\"/java-bin/TCGA-Reporting/#{jspLink}.jsp?institution=#{name}\">#{name}</A></B></TD>"
    }
  puts "          <TD><B>Total</B></TD>\n        </TR>"
  institutions.setValues.each{|setValue|
      results = resultHash[setValue]
          puts "          <TR>
            <TD>#{setValues}</TD>"
          results.each{|value|
              puts "<TD><B>#{value}</B></TD>" 
            }
          put "          </TR>"
      } 

  puts "</TABLE>\n</TD></TR></TABLE><BR />"
end

##################################################################  
  def self.calculateAverageForGeneCoverageFile(tabDelimitedFileName)
    return nil if( tabDelimitedFileName.nil? )
    # Read tabDelimitedFileName file
    
    hashOfArraysWithTabDelimitedValues = TableToHashCreator.loadTabDelimitedFile(tabDelimitedFileName)
    if(hashOfArraysWithTabDelimitedValues.nil?)
      $stderr.puts "Unable to calculateAverageForGeneCoverageFile"
      return nil
    end
    numbArrays = hashOfArraysWithTabDelimitedValues.length.to_f
    numberOfRois =  0.0
    numberOfSamples = 0.0
    percentage1XCoverage = 0.0
    percentage2XCoverage = 0.0

    
    hashOfArraysWithTabDelimitedValues.each {|key, array|
      numberOfFields = array.length
#     $stderr.puts "processing gene #{key} values"
      if(numberOfFields == 4)
          numberOfRois += array[0].to_f
          numberOfSamples += array[1].to_f
          percentage1XCoverage += array[2].to_f
          percentage2XCoverage += array[3].to_f
      end
    }
    
#    puts "The number of arrays is #{numbArrays} The number of rois is #{numberOfRois}, the number of samples is #{numberOfSamples}, the percentage 1x  is #{percentage1XCoverage}, the percentage 2x is #{percentage2XCoverage} "

    #tempString = sprintf("%i\t%i\t%.2f%%\t%.2f%%", numberOfRois.to_i, numberOfSamples.to_i, percentage1XCoverage , percentage2XCoverage)
    fileWriter = BRL::Util::TextWriter.new(tabDelimitedFileName, "a+")
    #fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
    #fileWriter.puts "Total\t#{tempString}"

    
    numberOfRois =  numberOfRois / numbArrays
    numberOfSamples = numberOfSamples / numbArrays
    percentage1XCoverage = percentage1XCoverage / numbArrays
    percentage2XCoverage = percentage2XCoverage / numbArrays
    
    tempString = sprintf("%i\t%i\t%.2f%%\t%.2f%%", numberOfRois.to_i, numberOfSamples.to_i, percentage1XCoverage , percentage2XCoverage)

    fileWriter.puts "#Number of Genes\t#{numbArrays}"
    fileWriter.puts "#Average\t#{tempString}"
    fileWriter.close()
  end 
    
##################################################
  def self.calculateAverageForSampleToTotalFile(tabDelimitedFileName)
    return nil if( tabDelimitedFileName.nil? )
    # Read tabDelimitedFileName file
    
    hashOfArraysWithTabDelimitedValues = TableToHashCreator.loadTabDelimitedFile(tabDelimitedFileName)
    if(hashOfArraysWithTabDelimitedValues.nil?)
      $stderr.puts "Unable to calculateAverageForSampleToTotalFile"
      return nil
    end
    
    numbArrays = hashOfArraysWithTabDelimitedValues.length.to_f
    numberOfAmpliconPass  = 0.0
    totalAmplicon         = 0.0
    percentagePass        = 0.0


    
    hashOfArraysWithTabDelimitedValues.each {|key, array|
      numberOfFields = array.length
#      $stderr.puts "processing gene #{key} values"
      if(numberOfFields == 3)
          numberOfAmpliconPass += array[0].to_f
          totalAmplicon += array[1].to_f
          tempPercPass = array[2].gsub(/\%/, "").strip
          percentagePass += tempPercPass.to_f
      end
    }

#    tempString = sprintf("%.2f\t%.2f\t%.2f", numberOfAmpliconPass, totalAmplicon, percentagePass)
    fileWriter = BRL::Util::TextWriter.new(tabDelimitedFileName, "a+")
#    fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
#    fileWriter.puts "Total\t#{tempString}"

    
    numberOfAmpliconPass =  numberOfAmpliconPass / numbArrays
    totalAmplicon = totalAmplicon / numbArrays
    percentagePass = percentagePass / numbArrays

    
    tempString = sprintf("%.2f\t%.2f\t%.2f%%", numberOfAmpliconPass, totalAmplicon, percentagePass)

#    fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
    fileWriter.puts "#Number of Samples\t#{numbArrays}"
    fileWriter.puts "#Average\t#{tempString}"
    fileWriter.close()
  end 
    

##################################################
  def self.calculateAverageForAmpliconToTotal(tabDelimitedFileName)
    return nil if( tabDelimitedFileName.nil? )
    # Read tabDelimitedFileName file
    
    hashOfArraysWithTabDelimitedValues = TableToHashCreator.loadTabDelimitedFile(tabDelimitedFileName)
    if(hashOfArraysWithTabDelimitedValues.nil?)
      $stderr.puts "Unable to calculateAverageForAmpliconToTotal"
      return nil
    end
    numbArrays = hashOfArraysWithTabDelimitedValues.length.to_f
    numberSamplesPass     = 0.0
    numberSamples         = 0.0                  
    percentageSamplesPass = 0.0                
    


    
    hashOfArraysWithTabDelimitedValues.each {|key, array|
      numberOfFields = array.length
#      $stderr.puts "processing gene #{key} values"
      if(numberOfFields == 3)
          numberSamplesPass += array[0].to_f
          numberSamples += array[1].to_f
          tempPercPass = array[2].gsub(/\%/, "").strip
          percentageSamplesPass += tempPercPass.to_f
      end
    }

    tempString = sprintf("%.2f\t%.2f\t%.2f", numberSamplesPass, numberSamples, percentageSamplesPass)
    fileWriter = BRL::Util::TextWriter.new(tabDelimitedFileName, "a+")
#    fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
   fileWriter.puts "#Total\t#{tempString}"

    
    numberSamplesPass =  numberSamplesPass / numbArrays
    numberSamples = numberSamples / numbArrays
    percentageSamplesPass = percentageSamplesPass / numbArrays

    
    tempString = sprintf("%.2f\t%.2f\t%.2f%%", numberSamplesPass, numberSamples, percentageSamplesPass)

#    fileWriter.puts "------------------------------ Number of Records #{numbArrays} --------------------------------------------------------------"
    fileWriter.puts "#Number of Amplicons\t#{numbArrays}"
    fileWriter.puts "#Average\t#{tempString}"
    fileWriter.close()
  end 
        
##################################################

  def self.roiSeqLffToCoverageTable(roiSequencingLffFileName, roiTableFile, sampleFileName, numberOfSampl=0)
    roiHash = Hash.new {|hh, kk| hh[kk] = nil}
    oneQualSubType = "oneXCoverage".to_sym
    twoQualSubType = "twoXCoverage".to_sym
    return nil if(roiSequencingLffFileName.nil? || roiTableFile.nil? || sampleFileName.nil?)
    fileWriter = BRL::Util::TextWriter.new(roiTableFile)
    reader = BRL::Util::TextReader.new(roiSequencingLffFileName)
    fileWriter.puts "#RoiId\tperc1xCoverage\tperc2xCoverage\tNumberSamples"
    sampleHash = TableToHashCreator.sampleIdToSampleTableHash(sampleFileName)
    if(numberOfSampl == 0)
      numberSamples = sampleHash.length 
    else
      numberSamples = numberOfSampl
    end
    line = nil
    lineCounter = 1
    
    

    begin
      reader.each { |line|
        errofLevel = 0
        oneXScore = 0.0
        twoXScore = 0.0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        
        rg = LFFHash.new(line)

        next if(rg.nil?)
        roiName = rg.lffName
        if(rg.lffSubtype == oneQualSubType)
          oneXScore = rg.lffScore
        end
        
        if(rg.lffSubtype == twoQualSubType)
          twoXScore = rg.lffScore
        end
          
                
        if(!roiHash.has_key?(roiName))
          roiHash[roiName] = RoiCoverage.new(oneXScore, twoXScore)
        else
          roiHash[roiName].add(oneXScore, twoXScore)
        end
      }
   
      roiHash.each{|roiId, roiCoverageObj|
          length = roiCoverageObj.length 
          coverage1XSummary = roiCoverageObj.oneXCoverage
          coverage2xSummary = roiCoverageObj.twoXCoverage
          
          coverageperc1x = ((coverage1XSummary/numberSamples.to_f) / length.to_f) * 100
          coverageperc2x = ((coverage2xSummary/numberSamples.to_f) / length.to_f) * 100
          coverageperc1x = 100.0 if(coverageperc1x > 100.0)
          coverageperc2x = 100.0 if(coverageperc2x  > 100.0)
          tempString = sprintf("%s\t%.2f%%\t%.2f%%\t%d", roiId, coverageperc1x, coverageperc2x, numberSamples)
          fileWriter.puts tempString

        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
  end




####################  TODO --> This methods use the number of samples from the sample-definition file to calculate coverage!!!
  def self.roiSequencingFileToCoverageTable(roiSequencingFileName, roiTableFile, sampleFileName, numberOfSampl=0)
    retVal = {}
    return retVal if(roiSequencingFileName.nil? || roiTableFile.nil? || sampleFileName.nil?)
    fileWriter = BRL::Util::TextWriter.new(roiTableFile)
    reader = BRL::Util::TextReader.new(roiSequencingFileName)
    fileWriter.puts "#RoiId\tperc1xCoverage\tperc2xCoverage\tNumberSamples"
    sampleHash = TableToHashCreator.sampleIdToSampleTableHash(sampleFileName)
    if(numberOfSampl == 0)
      numberSamples = sampleHash.length 
    else
      numberSamples = numberOfSampl
    end
    
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = RoiSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.roiId))
          $stderr.puts "The Roi_id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
        else
          oneCoverageValues = rg.oneXCoverageArray
          twoCoverageValues = rg.twoXCoverageArray
          sequenceArray = rg.sequenceArray
          roiId = rg.roiId
          counter = 0

          length = rg.length
          coverage1XSummary = 0
          coverage2xSummary = 0
          coverageperc1x = 0.0
          coverageperc2x = 0.0
          sequenceArray.each { |position|
            coverage1XSummary += oneCoverageValues[counter]
            coverage2xSummary += twoCoverageValues[counter]           
            counter = counter + 1  
          }
          coverageperc1x = ((coverage1XSummary/numberSamples.to_f) / length.to_f) * 100
          coverageperc2x = ((coverage2xSummary/numberSamples.to_f) / length.to_f) * 100
          tempString = sprintf("%s\t%.2f%%\t%.2f%%\t%d", roiId, coverageperc1x, coverageperc2x, numberSamples)
          fileWriter.puts tempString
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end


#################################################


  def self.ampliconSequencingFileToLff(ampliconFileName, ampliconSeqLffFileName, ampliconSequencingFileName, clName="Amplicon", type="institution")
    retVal = {}
    return retVal if( ampliconFileName.nil? || ampliconSequencingFileName.nil? || ampliconSeqLffFileName.nil?)

    # Read ampliconSequencing file
    if(!File.exist?(ampliconSequencingFileName))
      $stderr.puts "Missing File #{ampliconSequencingFileName}"
      return nil 
    end
    ampliconHash = TableToHashCreator.ampliconIdToAmpliconTableHash(ampliconFileName)
    
    reader = BRL::Util::TextReader.new(ampliconSequencingFileName)
    fileWriter = BRL::Util::TextWriter.new(ampliconSeqLffFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "The Roi_id #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          ampliconDef = ampliconHash[rg.ampliconId]
          if(ampliconDef.nil?)
            $stderr.puts "panic!!! definition for #{rg.ampliconId.inspect} do not exist in the roi definition file"
            next
          end
          begining = ampliconDef.start
          ending = ampliconDef.stop
          chromosome = ampliconDef  .chromosome
          oneCoverageValues = rg.oneXCoverageArray
          twoCoverageValues = rg.twoXCoverageArray
          sequenceArray = rg.sequenceArray
          counter = 0
          location = 0
          subtype1 = "AmpOneXCoverage"
          subtype2 = "AmpTwoXCoverage"
          sequenceArray.each { |position|
            location = begining + counter 
            fileWriter.print "#{clName}\t#{rg.ampliconId}\t#{type}\t#{subtype1}\t#{chromosome}\t"
            fileWriter.print "#{location}\t#{location}\t+\t0\t#{oneCoverageValues[counter]}\t.\t.\tbase=#{position};"
            fileWriter.puts ""
            fileWriter.print "#{clName}\t#{rg.ampliconId}\t#{type}\t#{subtype2}\t#{chromosome}\t"
            fileWriter.print "#{location}\t#{location}\t+\t0\t#{twoCoverageValues[counter]}\t.\t.\tbase=#{position};"
            fileWriter.puts ""            
            counter = counter + 1  
          }
#          $stderr.puts "annotation #{rg.ampliconId} last nucleotide = #{location} number of printed records is #{counter - 1} size is #{ampliconDef.size} and start = #{begining} end = #{ending}"
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end


  def self.sampleIdToSampleTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = SampleFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.sampleId))
          $stderr.puts "Sample Id #{rg.sampleId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.sampleId] = rg 
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end


#AmpliconSequencingFile 
  def self.ampliconIdToAmpliconSequencingTableHash(fileName)
    retVal = {}
    return retVal unless( !fileName.nil? )

    reader = BRL::Util::TextReader.new(fileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        rg = AmpliconSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          end
          lineCounter = lineCounter + 1
          next
        end
        if(retVal.has_key?(rg.ampliconId))
          $stderr.puts "Sample Id #{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
        else
          retVal[rg.ampliconId] = rg 
        end
        lineCounter = lineCounter + 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

  def self.roiIdToRoiSequencingTableHash(roiSequencingFileName, numberOfSamples, roiHash)
    errorCounter = 0
    maxNumberOfErrors = 1000
    retVal = {}
    return retVal unless( !roiSequencingFileName.nil? )

    reader = BRL::Util::TextReader.new(roiSequencingFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end
        
        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{roiSequencingFileName} please fix the problems and re-submit the file!"
          return nil
        end 
        
        rg = RoiSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(retVal.has_key?(rg.roiId))
          $stderr.puts "Roi Id #{rg.roiId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        elsif(rg.samples > numberOfSamples)
          $stderr.puts "error in line #{lineCounter} The number of samples in the sample definition file is #{numberOfSamples} and the number of samples reported in this line is #{rg.samples} --> line rejected"
          errorCounter += 1
        elsif(!roiHash.has_key?(rg.roiId))   
          $stderr.puts "error in line #{lineCounter} The #{rg.roiId} is not defined in the Roi-definition file --> line rejected"
          errorCounter += 1
        #elsif(rg.samples < numberOfSamples)
        #  $stderr.puts "Warning for line #{lineCounter} The number of samples in the sample definition file is #{numberOfSamples} and the number of samples in this line is #{rg.samples}, this line will be analyzed but you should verify the information since the values in both files should match. The current values may affect your Coverage score in this report"
        #  retVal[rg.roiId] = rg
        else
          retVal[rg.roiId] = rg
        end
        lineCounter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end

  def self.lightSampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    retVal = {}
    ampSampKey = nil
    sampleId = nil
    ampliconId = nil
    errorCounter = 0
    maxNumberOfErrors = 1000

    
    return retVal unless( !sampleSequencingFileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(sampleSequencingFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end

        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{sampleSequencingFileName} please fix the problems and re-submit the file!"
          return nil
        end
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        sampleId = rg.sampleId if(errorLevel < 1)
        ampliconId = rg.ampliconId if(errorLevel < 1)
        ampSampKey = MD5.md5("#{rg.sampleId}-#{rg.ampliconId}") if(errorLevel < 1)
        
        
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(!sampleHash.has_key?(sampleId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File SampleId #{sampleId} is not in the Sample Definition File -> line rejected"
          errorCounter += 1
        elsif(!ampliconHash.has_key?(ampliconId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File AmpliconId #{ampliconId} is not in the Amplicon Definition File -> line rejected"
          errorCounter += 1
        elsif(retVal.has_key?(ampSampKey))
          $stderr.puts "The sampleId #{rg.sampleId}-#{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          retVal[ampSampKey] = nil           
        end
        lineCounter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end


  def self.sampleSequencingToHash(sampleSequencingFileName, ampliconHash, sampleHash)
    retVal = {}
    ampSampKey = nil
    sampleId = nil
    ampliconId = nil
    errorCounter = 0
    maxNumberOfErrors = 1000

    
    return retVal unless( !sampleSequencingFileName.nil? )
    # Read amplicon file
    reader = BRL::Util::TextReader.new(sampleSequencingFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter = lineCounter + 1
          next
        end

        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{sampleSequencingFileName} please fix the problems and re-submit the file!"
          return nil
        end
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        sampleId = rg.sampleId if(errorLevel < 1)
        ampliconId = rg.ampliconId if(errorLevel < 1)
        ampSampKey = MD5.md5("#{rg.sampleId}-#{rg.ampliconId}") if(errorLevel < 1)
        
        
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(!sampleHash.has_key?(sampleId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File SampleId #{sampleId} is not in the Sample Definition File -> line rejected"
          errorCounter += 1
        elsif(!ampliconHash.has_key?(ampliconId))
          $stderr.puts "error in line #{lineCounter} Sample-Sequencing-File AmpliconId #{ampliconId} is not in the Amplicon Definition File -> line rejected"
          errorCounter += 1
        elsif(retVal.has_key?(ampSampKey))
          $stderr.puts "The sampleId #{rg.sampleId}-#{rg.ampliconId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          retVal[ampSampKey] = rg   #may be use too much memory          
        end
        lineCounter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end



end #end class

end; end; end #namespace

