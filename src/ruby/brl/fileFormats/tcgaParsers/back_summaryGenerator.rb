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
require 'brl/fileFormats/tcgaParsers/tcgaFiles'
require 'brl/fileFormats/tcgaParsers/tableToHashCreator'
require 'brl/fileFormats/tcgaParsers/tcgaAuxiliaryMethods'


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

class SummaryGenerator

  def self.generateGeneCoverageFile(optsHash)
#--roiLffFileName --classType --attNameToUseForGrouping --geneCoverageFileName --listOfGenesFileName
    methodName = "generateGeneCoverageFile"
    roiLffFileName = nil
    classType = nil #CountPerCoverage
    attNameToUseForGrouping = nil
    geneCoverageFileName = nil
    sampleFileName = nil
    listOfGenesFileName = nil
    
    listOfGenesFileName = optsHash['--listOfGenesFileName'] if( optsHash.key?('--listOfGenesFileName') )
    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
    classType = optsHash['--classType'] if( optsHash.key?('--classType') )
    attNameToUseForGrouping = optsHash['--attNameToUseForGrouping'] if( optsHash.key?('--attNameToUseForGrouping') )
    geneCoverageFileName = optsHash['--geneCoverageFileName'] if( optsHash.key?('--geneCoverageFileName') )
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    
    
    if( listOfGenesFileName.nil? || roiLffFileName.nil? || attNameToUseForGrouping.nil? || geneCoverageFileName.nil? || classType.nil? || sampleFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--roiLffFileName=#{roiLffFileName}"
      $stderr.puts "--classType=#{classType}"
      $stderr.puts "--attNameToUseForGrouping=#{attNameToUseForGrouping}"
      $stderr.puts "--geneCoverageFileName=#{geneCoverageFileName}"
      $stderr.puts "--listOfGenesFileName=#{listOfGenesFileName}"
      $stderr.puts "--sampleFileName=#{sampleFileName} "
      return
    end
    
    sampleHash = TableToHashCreator.sampleIdToSampleTableHash(sampleFileName)
    numberOfSamples = sampleHash.length

      puts "-------------------- START OF PerformeOperationOnLffFile -------------------------------------------"
      stats = PerformeOperationOnLffFile.new(roiLffFileName, geneCoverageFileName, attNameToUseForGrouping, classType, numberOfSamples, listOfGenesFileName)
      stats.execute()
      puts "-------------------- END OF Sample PerformeOperationOnLffFile -------------------------------------------"
  end
 

  def self.testFilteringOneXCoverageFileUsingNumericColumn(optsHash)
#--geneCoverageFileName --fileOneXCoveragePrefix  --fileCoverageSubFix --columnOneXCoverageNumber --numberOfColumnsCoverage
    methodName = "testFilteringOneXCoverageFileUsingNumericColumn"
    tabDelimitedFileName =  nil 
    filePrefix =  nil
    fileSubFix = nil
    columnNumber = nil
    numberOfColumns = nil
    operation = nil
    operations = Array.new(["between", "between", "between", "between", "between"])
    attributesThreshold = Array.new([0.0, 20.0, 40.0, 60.0, 80.0])
    attributesThresholdMax = Array.new([20.0, 40.0, 60.0, 80.0, 100.0])
    attributeThreshold = 0.0
    attributeThresholdMax = 100.0
    fileName = nil
    preserveDefLine = true
    additional = "b"
    baseString = nil

    tabDelimitedFileName =  optsHash['--geneCoverageFileName'] if(optsHash.key?('--geneCoverageFileName'))
    filePrefix = optsHash['--fileOneXCoveragePrefix'] if(optsHash.key?('--fileOneXCoveragePrefix'))
    fileSubFix = optsHash['--fileCoverageSubFix'] if(optsHash.key?('--fileCoverageSubFix'))
    columnNumber = optsHash['--columnOneXCoverageNumber'] if(optsHash.key?('--columnOneXCoverageNumber'))
    numberOfColumns = optsHash['--numberOfColumnsCoverage']  if( optsHash.key?('--numberOfColumnsCoverage') )

    
    if(tabDelimitedFileName.nil? ||  filePrefix.nil? || columnNumber.nil? ||  numberOfColumns.nil? || fileSubFix.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--geneCoverageFileName=#{tabDelimitedFileName}"
      $stderr.puts "--fileOneXCoveragePrefix=#{filePrefix}"
      $stderr.puts "--fileCoverageSubFix=#{fileSubFix}"
      $stderr.puts "--columnOneXCoverageNumber=#{columnNumber}"
      $stderr.puts "--numberOfColumnsCoverage=#{numberOfColumns}"
      return 
    end

    
    begin
        baseString ="#{filePrefix}"
        begin
          dirExist = Dir.new(baseString) 
        rescue => err
          dirExist = nil
        end
        Dir::mkdir(baseString) if(dirExist.nil?)
    rescue => err
      $stderr.puts "making dir #{baseString} fail"
      baseString = nil
    end


    columnNumber = columnNumber.to_i 
    attributeThreshold = attributeThreshold.to_f 
    numberOfColumns = numberOfColumns.to_i
    

    operations.each_index{|indexId|
      additional = "b"
      operation = operations[indexId] 
      additional = "o" if(operation != "between")
      attributeThreshold = attributesThreshold[indexId]
      attributeThresholdMax = attributesThresholdMax[indexId]
      fileName = "#{baseString}/#{filePrefix}_#{attributeThreshold}-#{attributeThresholdMax}_#{additional}.#{fileSubFix}"
      TableToHashCreator.filteringTabDelimitedFileUsingNumericColumn(tabDelimitedFileName, fileName, columnNumber, attributeThreshold, numberOfColumns, operation, attributeThresholdMax, preserveDefLine)
    }

  end


  def self.testFilteringTwoXCoverageFileUsingNumericColumn(optsHash)
#--geneCoverageFileName --fileTwoXCoveragePrefix  --fileCoverageSubFix --columnTwoXCoverageNumber --numberOfColumnsCoverage
    methodName = "testFilteringTwoXCoverageFileUsingNumericColumn"
    tabDelimitedFileName =  nil 
    filePrefix =  nil
    fileSubFix = nil
    columnNumber = nil
    numberOfColumns = nil
    operation = nil
    operations = Array.new(["between", "between", "between", "between", "between"])
    attributesThreshold = Array.new([0.0, 20.0, 40.0, 60.0, 80.0])
    attributesThresholdMax = Array.new([20.0, 40.0, 60.0, 80.0, 100.0])
    attributeThreshold = 0.0
    attributeThresholdMax = 100.0
    fileName = nil
    preserveDefLine = true
    additional = "b"
    baseString = nil

    tabDelimitedFileName =  optsHash['--geneCoverageFileName'] if(optsHash.key?('--geneCoverageFileName'))
    filePrefix = optsHash['--fileTwoXCoveragePrefix'] if(optsHash.key?('--fileTwoXCoveragePrefix'))
    fileSubFix = optsHash['--fileCoverageSubFix'] if(optsHash.key?('--fileCoverageSubFix'))
    columnNumber = optsHash['--columnTwoXCoverageNumber'] if(optsHash.key?('--columnTwoXCoverageNumber'))
    numberOfColumns = optsHash['--numberOfColumnsCoverage']  if( optsHash.key?('--numberOfColumnsCoverage') )

    
    if(tabDelimitedFileName.nil? ||  filePrefix.nil? || columnNumber.nil? ||  numberOfColumns.nil? || fileSubFix.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--geneCoverageFileName=#{tabDelimitedFileName}"
      $stderr.puts "--fileTwoXCoveragePrefix=#{filePrefix}"
      $stderr.puts "--fileCoverageSubFix=#{fileSubFix}"
      $stderr.puts "--columnTwoXCoverageNumber=#{columnNumber}"
      $stderr.puts "--numberOfColumnsCoverage=#{numberOfColumns}"
      return 
    end


    begin
        baseString ="#{filePrefix}"
        begin
          dirExist = Dir.new(baseString) 
        rescue => err
          dirExist = nil
        end
        Dir::mkdir(baseString) if(dirExist.nil?)
    rescue => err
      $stderr.puts "making dir #{baseString} fail"
      baseString = nil
    end


     
    columnNumber = columnNumber.to_i 
    attributeThreshold = attributeThreshold.to_f 
    numberOfColumns = numberOfColumns.to_i

  

    operations.each_index{|indexId|
      additional = "b"
      operation = operations[indexId] 
      additional = "o" if(operation != "between")
      attributeThreshold = attributesThreshold[indexId]
      attributeThresholdMax = attributesThresholdMax[indexId]
      fileName = "#{baseString}/#{filePrefix}_#{attributeThreshold}-#{attributeThresholdMax}_#{additional}.#{fileSubFix}"
      
      TableToHashCreator.filteringTabDelimitedFileUsingNumericColumn(tabDelimitedFileName, fileName, columnNumber, attributeThreshold, numberOfColumns, operation, attributeThresholdMax, preserveDefLine)
    }

  end


  def self.calculateAverageForCoverageFile(optsHash)
    methodName = "calculateAverageForCoverageFile"
    geneCoverageFileName = nil
    geneCoverageFileName = optsHash['--geneCoverageFileName'] if( optsHash.key?('--geneCoverageFileName') )
    if( geneCoverageFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--geneCoverageFileName=#{geneCoverageFileName}"
        return
    end
    TableToHashCreator.calculateAverageForGeneCoverageFile(geneCoverageFileName)
  end
 
 
   def self.generateGeneCompletionFile(optsHash)
#--ampliconLffFileName --geneCompletionClassType --attNameToUseForGrouping --geneCompletionFileName --listOfGenesFileName
    methodName = "generateGeneCompletionFile"
    ampliconLffFileName = nil
    geneCompletionClassType = nil #CountPerAmpliconCompletion
    attNameToUseForGrouping = nil
    geneCompletionFileName = nil
    sampleFileName = nil
    listOfGenesFileName = nil
    
    listOfGenesFileName = optsHash['--listOfGenesFileName'] if( optsHash.key?('--listOfGenesFileName') )
    ampliconLffFileName = optsHash['--ampliconLffFileName'] if( optsHash.key?('--ampliconLffFileName') )
    geneCompletionClassType = optsHash['--geneCompletionClassType'] if( optsHash.key?('--geneCompletionClassType') )
    attNameToUseForGrouping = optsHash['--attNameToUseForGrouping'] if( optsHash.key?('--attNameToUseForGrouping') )
    geneCompletionFileName = optsHash['--geneCompletionFileName'] if( optsHash.key?('--geneCompletionFileName') )
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    
    
    if( listOfGenesFileName.nil? || ampliconLffFileName.nil? || attNameToUseForGrouping.nil? || geneCompletionFileName.nil? || geneCompletionClassType.nil? || sampleFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--ampliconLffFileName=#{ampliconLffFileName}"
      $stderr.puts "--geneCompletionClassType=#{geneCompletionClassType}"
      $stderr.puts "--attNameToUseForGrouping=#{attNameToUseForGrouping}"
      $stderr.puts "--geneCompletionFileName=#{geneCompletionFileName}"
      $stderr.puts "--listOfGenesFileName=#{listOfGenesFileName}"
      $stderr.puts "--sampleFileName=#{sampleFileName} "
      return
    end
    
    sampleHash = TableToHashCreator.sampleIdToSampleTableHash(sampleFileName)
    numberOfSamples = sampleHash.length

      puts "-------------------- START OF PerformeOperationOnLffFile -------------------------------------------"
      stats = PerformeOperationOnLffFile.new(ampliconLffFileName, geneCompletionFileName, attNameToUseForGrouping, geneCompletionClassType, numberOfSamples, listOfGenesFileName)
      stats.execute()
      puts "-------------------- END OF Sample PerformeOperationOnLffFile -------------------------------------------"
  end
 
  def self.calculateAverageForCompletionFile(optsHash)
    methodName = "calculateAverageForCompletionFile"
    geneCompletionFileName = nil
    geneCompletionFileName = optsHash['--geneCompletionFileName'] if( optsHash.key?('--geneCompletionFileName') )
    if( geneCompletionFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--geneCompletionFileName=#{geneCompletionFileName}"
        return
    end
    TableToHashCreator.calculateAverageForGeneCompletionFile(geneCompletionFileName)
  end
  
  
  def self.testFilteringCompletionFileUsingNumericColumn(optsHash)
#--geneCompletionFileName --fileCompletionPrefix  --fileCompletionSubFix --columnCompletionNumber --numberOfColumnsCompletion
    methodName = "testFilteringCompletionFileUsingNumericColumn"
    tabDelimitedFileName =  nil 
    filePrefix =  nil
    fileSubFix = nil
    columnNumber = nil
    numberOfColumns = nil
    operation = nil
    operations = Array.new(["between", "between", "between", "between", "between"])
    attributesThreshold = Array.new([0.0, 20.0, 40.0, 60.0, 80.0])
    attributesThresholdMax = Array.new([20.0, 40.0, 60.0, 80.0, 100.0])
    attributeThreshold = 0.0
    attributeThresholdMax = 100.0
    fileName = nil
    preserveDefLine = true
    additional = "b"
    baseString = nil

    tabDelimitedFileName =  optsHash['--geneCompletionFileName'] if(optsHash.key?('--geneCompletionFileName'))
    filePrefix = optsHash['--fileCompletionPrefix'] if(optsHash.key?('--fileCompletionPrefix'))
    fileSubFix = optsHash['--fileCompletionSubFix'] if(optsHash.key?('--fileCompletionSubFix'))
    columnNumber = optsHash['--columnCompletionNumber'] if(optsHash.key?('--columnCompletionNumber'))
    numberOfColumns = optsHash['--numberOfColumnsCompletion']  if( optsHash.key?('--numberOfColumnsCompletion') )

    
    if(tabDelimitedFileName.nil? ||  filePrefix.nil? || columnNumber.nil? ||  numberOfColumns.nil? || fileSubFix.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--geneCompletionFileName=#{tabDelimitedFileName}"
      $stderr.puts "--fileCompletionPrefix=#{filePrefix}"
      $stderr.puts "--fileCompletionSubFix=#{fileSubFix}"
      $stderr.puts "--columnCompletionNumber=#{columnNumber}"
      $stderr.puts "--numberOfColumnsCompletion=#{numberOfColumns}"
      return 
    end

    begin
        baseString ="#{filePrefix}"
        begin
          dirExist = Dir.new(baseString) 
        rescue => err
          dirExist = nil
        end
        Dir::mkdir(baseString) if(dirExist.nil?)
    rescue => err
      $stderr.puts "making dir #{baseString} fail"
      baseString = nil
    end



     
    columnNumber = columnNumber.to_i 
    attributeThreshold = attributeThreshold.to_f 
    numberOfColumns = numberOfColumns.to_i

    operations.each_index{|indexId|
      additional = "b"
      operation = operations[indexId] 
      additional = "o" if(operation != "between")
      attributeThreshold = attributesThreshold[indexId]
      attributeThresholdMax = attributesThresholdMax[indexId]
      fileName = "#{baseString}/#{filePrefix}_#{attributeThreshold}-#{attributeThresholdMax}_#{additional}.#{fileSubFix}"
      TableToHashCreator.filteringTabDelimitedFileUsingNumericColumn(tabDelimitedFileName, fileName, columnNumber, attributeThreshold, numberOfColumns, operation, attributeThresholdMax, preserveDefLine)
    }

  end
  
end
end; end; end #namespace

optsHash = Hash.new {|hh,kk| hh[kk] = 0}
optsHash[ARGV[0]] = ARGV[1]
optsHash[ARGV[2]] = ARGV[3]
optsHash[ARGV[4]] = ARGV[5]
optsHash[ARGV[6]] = ARGV[7]
optsHash[ARGV[8]] = ARGV[9]
optsHash[ARGV[10]] = ARGV[11]
optsHash[ARGV[12]] = ARGV[13]
optsHash[ARGV[14]] = ARGV[15]
optsHash[ARGV[16]] = ARGV[17]
optsHash[ARGV[18]] = ARGV[19]
optsHash[ARGV[20]] = ARGV[21]
optsHash[ARGV[22]] = ARGV[23]
optsHash[ARGV[24]] = ARGV[25]
optsHash[ARGV[26]] = ARGV[27]
optsHash[ARGV[28]] = ARGV[29]
optsHash[ARGV[30]] = ARGV[31]
optsHash[ARGV[32]] = ARGV[33]
optsHash[ARGV[34]] = ARGV[35]
optsHash[ARGV[36]] = ARGV[37]



optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }



#--roiLffFileName --classType --attNameToUseForGrouping --geneCoverageFileName --ampliconLffFileName --geneCompletionClassType --geneCompletionFileName 
#--fileCompletionPrefix  --fileCompletionSubFix --columnCompletionNumber --numberOfColumnsCompletion --fileCoveragePrefix  --fileCoverageSubFix --columnCoverageNumber --numberOfColumnsCoverage

#BRL::FileFormats::TCGAParsers::SummaryGenerator.generateGeneCoverageFile(optsHash)
BRL::FileFormats::TCGAParsers::SummaryGenerator.calculateAverageForCoverageFile(optsHash)
#--geneCoverageFileName --fileCoveragePrefix  --fileCoverageSubFix --columnCoverageNumber --numberOfColumnsCoverage
BRL::FileFormats::TCGAParsers::SummaryGenerator.testFilteringOneXCoverageFileUsingNumericColumn(optsHash)
BRL::FileFormats::TCGAParsers::SummaryGenerator.testFilteringTwoXCoverageFileUsingNumericColumn(optsHash)
BRL::FileFormats::TCGAParsers::SummaryGenerator.generateGeneCompletionFile(optsHash)
BRL::FileFormats::TCGAParsers::SummaryGenerator.calculateAverageForCompletionFile(optsHash)
#--geneCompletionFileName --fileCompletionPrefix  --fileCompletionSubFix --columnCompletionNumber --numberOfColumnsCompletion
BRL::FileFormats::TCGAParsers::SummaryGenerator.testFilteringCompletionFileUsingNumericColumn(optsHash)
