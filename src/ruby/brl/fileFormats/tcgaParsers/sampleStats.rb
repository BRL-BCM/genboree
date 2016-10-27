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

class SampleStats

 
###TODO move to other file
  def self.testSampleToAmpliconTable(optsHash)
    # --sampleSequencingFileName --ampliconFileName  --sampleAmpliconTableFile
    ampliconFileName = nil
    sampleSequencingFileName =  nil 
    sampleAmpliconTableFile =  nil
    sampleFileName  = nil

    sampleSequencingFileName =     optsHash['--sampleSequencingFileName'] if(optsHash.key?('--sampleSequencingFileName'))
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    ampliconFileName = optsHash['--ampliconFileName'] if(optsHash.key?('--ampliconFileName'))
    sampleAmpliconTableFile =   optsHash['--sampleAmpliconTableFile'] if(optsHash.key?('--sampleAmpliconTableFile'))
    if(sampleSequencingFileName.nil? || ampliconFileName.nil? || sampleAmpliconTableFile.nil? || sampleFileName.nil?)
      $stderr.puts "Error missing parameters --sampleSequencingFileName=#{sampleSequencingFileName} --ampliconFileName=#{ampliconFileName} -sampleAmpliconTableFile=#{sampleAmpliconTableFile} --sampleFileName=#{sampleFileName}"
      return
    end
    
    splitt = SampleToAmpliconTable.new(sampleSequencingFileName, ampliconFileName, sampleAmpliconTableFile, sampleFileName)
    splitt.execute() if(!splitt.nil?)
  end  
  

  def self.testReadSampleToAmpliconTable(optsHash)
#--sampleAmpliconTableFile --totalAmpliconFile --totalSampleFile --numberOfSamples
    sampleAmpliconTableFile =  nil 
    totalAmpliconFile =  nil
    totalSampleFile = nil

    sampleAmpliconTableFile =  optsHash['--sampleAmpliconTableFile'] if(optsHash.key?('--sampleAmpliconTableFile'))
    totalAmpliconFile =    optsHash['--totalAmpliconFile'] if(optsHash.key?('--totalAmpliconFile'))
    totalSampleFile = optsHash['--totalSampleFile'] if(optsHash.key?('--totalSampleFile'))
    
    return nil if(sampleAmpliconTableFile.nil? ||  totalAmpliconFile.nil? || totalSampleFile.nil?)

    table = ReadSampleToAmpliconTable.new(sampleAmpliconTableFile, totalAmpliconFile, totalSampleFile)
    table.execute()
    
  end

    def self.testFilteringSampleAmpliconCompletionFileUsingNumericColumn(optsHash)
#--sampleAmpliconTableFile --sampleAmpliconCompletionPrefix  --sampleAmpliconCompletionSubFix --columnAmpliconSampleCompletionNumber --numberOfColumnsSampleAmpliconCompletion
    methodName = "testFilteringSampleAmpliconCompletionFileUsingNumericColumn"
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

    tabDelimitedFileName =  optsHash['--totalAmpliconFile'] if(optsHash.key?('--totalAmpliconFile'))
    filePrefix = optsHash['--sampleAmpliconCompletionPrefix'] if(optsHash.key?('--sampleAmpliconCompletionPrefix'))
    fileSubFix = optsHash['--sampleAmpliconCompletionSubFix'] if(optsHash.key?('--sampleAmpliconCompletionSubFix'))
    columnNumber = optsHash['--columnAmpliconSampleCompletionNumber'] if(optsHash.key?('--columnAmpliconSampleCompletionNumber'))
    numberOfColumns = optsHash['--numberOfColumnsSampleAmpliconCompletion']  if( optsHash.key?('--numberOfColumnsSampleAmpliconCompletion') )

    
    if(tabDelimitedFileName.nil? ||  filePrefix.nil? || columnNumber.nil? ||  numberOfColumns.nil? || fileSubFix.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--totalAmpliconFile=#{tabDelimitedFileName}"
      $stderr.puts "--sampleAmpliconCompletionPrefix=#{filePrefix}"
      $stderr.puts "--sampleAmpliconCompletionSubFix=#{fileSubFix}"
      $stderr.puts "--columnAmpliconSampleCompletionNumber=#{columnNumber}"
      $stderr.puts "--numberOfColumnsSampleAmpliconCompletion=#{numberOfColumns}"
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




  def self.testCalculateAverageForSampleToTotalFile(optsHash)
    methodName = "testCalculateAverageForSampleToTotalFile"
    
    totalSampleFile = nil
    totalSampleFile = optsHash['--totalSampleFile'] if( optsHash.key?('--totalSampleFile') )
    if( totalSampleFile.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--totalSampleFile=#{totalSampleFile}"
        return
    end
    TableToHashCreator.calculateAverageForSampleToTotalFile(totalSampleFile)
  end
  
  
    def self.testFilteringSampleCompletionFileUsingNumericColumn(optsHash)
#--totalSampleFile --sampleCompletionPrefix  --sampleCompletionSubFix --columnSampleCompletionNumber --numberOfColumnsSampleCompletion
    methodName = "testFilteringSampleCompletionFileUsingNumericColumn"
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

    tabDelimitedFileName =  optsHash['--totalSampleFile'] if(optsHash.key?('--totalSampleFile'))
    filePrefix = optsHash['--sampleCompletionPrefix'] if(optsHash.key?('--sampleCompletionPrefix'))
    fileSubFix = optsHash['--sampleCompletionSubFix'] if(optsHash.key?('--sampleCompletionSubFix'))
    columnNumber = optsHash['--columnSampleCompletionNumber'] if(optsHash.key?('--columnSampleCompletionNumber'))
    numberOfColumns = optsHash['--numberOfColumnsSampleCompletion']  if( optsHash.key?('--numberOfColumnsSampleCompletion') )

    
    if(tabDelimitedFileName.nil? ||  filePrefix.nil? || columnNumber.nil? ||  numberOfColumns.nil? || fileSubFix.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--totalSampleFile=#{tabDelimitedFileName}"
      $stderr.puts "--fileCompletionPrefix=#{filePrefix}"
      $stderr.puts "--fileCompletionSubFix=#{fileSubFix}"
      $stderr.puts "--columnSampleCompletionNumber=#{columnNumber}"
      $stderr.puts "--numberOfColumnsSampleCompletion=#{numberOfColumns}"
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
  
  

  def self.testCalculateAverageForAmpliconToTotal(optsHash)
#--totalAmpliconFile
    methodName = "testCalculateAverageForAmpliconToTotal"
    totalAmpliconFile = nil
    totalAmpliconFile = optsHash['--totalAmpliconFile'] if( optsHash.key?('--totalAmpliconFile') )
    if( totalAmpliconFile.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--totalAmpliconFile=#{totalAmpliconFile}"
        return
    end
    TableToHashCreator.calculateAverageForAmpliconToTotal(totalAmpliconFile)
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

optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }

#Generating Tables and Sample completion
# --sampleSequencingFileName --ampliconFileName  --sampleAmpliconTableFile  #### Need to optimize this
# method uses lots of memory to create the file sampleAmpliconTable.table
BRL::FileFormats::TCGAParsers::SampleStats.testSampleToAmpliconTable(optsHash)
#--sampleAmpliconTableFile --totalAmpliconFile --totalSampleFile ## this method creates the sampleCompletion.summary and
# the ampliconCompletion.summary ## need to modify to accept 1000 sample as a constant
BRL::FileFormats::TCGAParsers::SampleStats.testReadSampleToAmpliconTable(optsHash)
#--totalSampleFile
BRL::FileFormats::TCGAParsers::SampleStats.testCalculateAverageForSampleToTotalFile(optsHash)
#--totalAmpliconFile
BRL::FileFormats::TCGAParsers::SampleStats.testCalculateAverageForAmpliconToTotal(optsHash)
BRL::FileFormats::TCGAParsers::SampleStats.testFilteringSampleCompletionFileUsingNumericColumn(optsHash)
BRL::FileFormats::TCGAParsers::SampleStats.testFilteringSampleAmpliconCompletionFileUsingNumericColumn(optsHash)