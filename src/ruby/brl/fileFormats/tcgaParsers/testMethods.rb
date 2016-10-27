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

class TestMethods

  def self.testValueToNameHash(optsHash)
    fileName = optsHash['--ampliconFile']
    type = optsHash['--type']
    subtype = optsHash['--subtype']
    clName = optsHash['--className']

    TableToHashCreator.ampliconIdToLff(fileName, clName, type, subtype)
  end 
  
  def self.testRoiToLff(optsHash)
    #--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
    roiFileName = optsHash['--roiFileName']
    type = optsHash['--type']
    roiSubtype = optsHash['--roiSubtype']
    roiClassName = optsHash['--roiClassName']
    roiLffFileName = optsHash['--roiLffFileName']

    TableToHashCreator.roiIdToLff(roiFileName, roiLffFileName, roiClassName, type, roiSubtype)
  end
  
  def self.testAmpliconIdToLff(optsHash)
    #--ampliconFile  --type --ampliconSubtype --ampliconClassName --ampliconLffFileName
    ampliconFileName = optsHash['--ampliconFileName']
    type = optsHash['--type']
    subtype = optsHash['--ampliconSubtype']
    clName = optsHash['--ampliconClassName']
    ampliconLffFileName = optsHash['--ampliconLffFileName']

    TableToHashCreator.ampliconIdToLff(ampliconFileName, ampliconLffFileName, clName, type, subtype)
  end  

  def self.testAmpliconIdToPrimerLff(optsHash)
    #--ampliconFileName  --type --primerSubtype --primerClassName --primerLffFileName
    ampliconFileName = optsHash['--ampliconFileName']
    type = optsHash['--type']
    primerSubtype = optsHash['--primerSubtype']
    clName = optsHash['--primerClassName']
    primerLffFileName = optsHash['--primerLffFileName']

    TableToHashCreator.ampliconIdToPrimersLff(ampliconFileName, primerLffFileName, clName, type, primerSubtype)
  end  


  def self.testRoiSequencingFileToLff(optsHash)
    #--roiFileName --roiSequencingFileName --type --roiSeqclassName --roiSequencingLffFileName
    roiFileName = optsHash['--roiFileName']
    roiSequencingLffFileName = optsHash['--roiSequencingLffFileName']
    roiSequencingFileName = optsHash['--roiSequencingFileName']
    type = optsHash['--type']
    clName = optsHash['--roiSeqclassName'] 

    puts "Inside the testing roiFileName = #{roiFileName} roiSequencingLffFileName = #{roiSequencingLffFileName} roiSequencingFileName = #{roiSequencingFileName} clName= #{clName} type = #{type}"

    
    TableToHashCreator.roiSequencingFileToLff(roiFileName, roiSequencingLffFileName, roiSequencingFileName, clName, type)
  end

  def self.testRoiSequencingFileToCoverageTable(optsHash)
#    --roiSequencingFileName --roiTableFile
    roiSequencingFileName = nil
    roiTableFile = nil
    
    roiSequencingFileName = optsHash['--roiSequencingFileName'] if(optsHash.key?('--roiSequencingFileName'))
    roiTableFile = optsHash['--roiTableFile'] if(optsHash.key?('--roiTableFile'))

    if(roiSequencingFileName.nil? || roiTableFile.nil?)
      $stderr.puts "Error missing parameters --roiSequencingFileName=#{roiSequencingFileName} --roiTableFile=#{roiTableFile}"
      return
    end
 
    TableToHashCreator.roiSequencingFileToCoverageTable(roiSequencingFileName, roiTableFile)
  end


  def self.testAmpliconSequencingFileToLff(optsHash)
#--ampliconSequencingFileName   --ampliconFileName  --type  --ampliconSeqclassName --ampliconSeqLffFileName
    methodName = "testAmpliconSequencingFileToLff"
    ampliconSequencingFileName = nil
    ampliconFileName  = nil
    type  = nil
    ampliconSeqclassName = nil
    ampliconSeqLffFileName = nil
    
    ampliconSequencingFileName = optsHash['--ampliconSequencingFileName'] if( optsHash.key?('--ampliconSequencingFileName') )
    ampliconFileName  = optsHash['--ampliconFileName']       if( optsHash.key?('--ampliconFileName') )
    type  = optsHash['--type'] if( optsHash.key?('--type') )
    ampliconSeqclassName = optsHash['--ampliconSeqclassName'] if( optsHash.key?('--ampliconSeqclassName') )
    ampliconSeqLffFileName = optsHash['--ampliconSeqLffFileName'] if( optsHash.key?('--ampliconSeqLffFileName') )


    if( ampliconFileName.nil? || ampliconSequencingFileName.nil? || ampliconSeqLffFileName.nil? || type.nil? || ampliconSeqclassName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--ampliconFileName=#{ampliconFileName}"
        $stderr.puts "--ampliconSequencingFileName=#{ampliconSequencingFileName}"
        $stderr.puts "--ampliconSeqLffFileName=#{ampliconSeqLffFileName}"
        $stderr.puts "--type=#{type}"
        $stderr.puts "--ampliconSeqclassName=#{ampliconSeqclassName}"
        return
    end 
    
    TableToHashCreator.ampliconSequencingFileToLff(ampliconFileName, ampliconSeqLffFileName ,ampliconSequencingFileName, ampliconSeqclassName, type)
  end
  

  def self.testSampleIdToSampleTableHash(optsHash)
       fileName = optsHash['--sampleFile'] 
    
      sampleHash = TableToHashCreator.sampleIdToSampleTableHash(fileName)
      
      sampleHash.each_key {|key|
        sample = sampleHash[key]
        puts "#{sample.sampleId}\t#{sample.sampleType}\t#{sample.patientId}"
      } 
      
  end

  def self.testLoadtabDelimitedFileToHash(optsHash)
    methodName = "testAmpliconSequencingFileToLff"
    tabDelimitedFileName = nil
    tabDelimitedFileName = optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )
    if( tabDelimitedFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        return
    end
    
      
      tabDelimitedHash = TableToHashCreator.loadTabDelimitedFile(tabDelimitedFileName)
      
        tabDelimitedHash.each_key {|key|
        line = tabDelimitedHash[key]
        puts "geneName = #{key} numberOfRecords = #{line[0]} oneXCoverageTotal = #{line[1]} twoXCoverageTotal = #{line[2]} average1XCoverage = #{line[3]} average2XCoverage = #{line[4]} "
      } 
      
  end

  def self.testCalculateAverageForCoverageFile(optsHash)
    methodName = "testCalculateAverageForCoverageFile"
    tabDelimitedFileName = nil
    tabDelimitedFileName = optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )
    if( tabDelimitedFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        return
    end
    TableToHashCreator.calculateAverageForGeneCoverageFile(tabDelimitedFileName)
  end

  def self.testCalculateAverageForSampleToTotalFile(optsHash)
    methodName = "testCalculateAverageForSampleToTotalFile"
    tabDelimitedFileName = nil
    tabDelimitedFileName = optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )
    if( tabDelimitedFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        return
    end
    TableToHashCreator.calculateAverageForSampleToTotalFile(tabDelimitedFileName)
  end

  def self.testCalculateAverageForAmpliconToTotal(optsHash)
    methodName = "testCalculateAverageForAmpliconToTotal"
    tabDelimitedFileName = nil
    tabDelimitedFileName = optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )
    if( tabDelimitedFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        return
    end
    TableToHashCreator.calculateAverageForAmpliconToTotal(tabDelimitedFileName)
  end


  def self.testAmpliconIdToAmpliconSequencingTableHash(optsHash)
       fileName = optsHash['--ampliconSequencingFile'] 
    

      ampliconSequencingHash = TableToHashCreator.ampliconIdToAmpliconSequencingTableHash(fileName)
      
      ampliconSequencingHash.each_key {|key|
        ampliconSeq = ampliconSequencingHash[key]
        print "#{ampliconSeq.ampliconId}\t#{ampliconSeq.samples}\t#{ampliconSeq.length}\t"
        print "#{ampliconSeq.sequence}\t#{ampliconSeq.oneXCoverage}\t#{ampliconSeq.twoXCoverage}\t"
        print "#{ampliconSeq.oneXCoverageArray.length}\t#{ampliconSeq.twoXCoverageArray.length}\t"
        puts "#{ampliconSeq.oneXCoverageSize}\t#{ampliconSeq.twoXCoverageSize}"
      } 
      
  end


  def self.testRoiIdToRoiSequencingTableHash(optsHash)
       fileName = optsHash['--roiSequencingFile'] 
    

      roiSequencingHash = TableToHashCreator.roiIdToRoiSequencingTableHash(fileName)
      
      roiSequencingHash.each_key {|key|
        roiSeq = roiSequencingHash[key]
        print "#{roiSeq.roiId}\t#{roiSeq.samples}\t#{roiSeq.length}\t"
        print "#{roiSeq.sequence}\t#{roiSeq.oneXCoverage}\t#{roiSeq.twoXCoverage}\t"
        print "#{roiSeq.oneXCoverageArray.length}\t#{roiSeq.twoXCoverageArray.length}\t"
        puts "#{roiSeq.oneXCoverageSize}\t#{roiSeq.twoXCoverageSize}"
      } 
      
  end



def self.testGeneratingMapFilesFromLargeFiles(optsHash)
      return nil unless( optsHash.key?('--ampliconFile') )
      amplicons = optsHash['--ampliconFile']
       
      return nil unless( optsHash.key?('--lociFile') )
      lociFile = optsHash['--lociFile']
      
      return nil unless( optsHash.key?('--mappingFile') )
      mappingFile = optsHash['--mappingFile']
      
      return nil unless( optsHash.key?('--noMappedFile') )
      noMappedFile = optsHash['--noMappedFile']
      
      return nil unless( optsHash.key?('--duplicatedFile') )
      duplicatedFile = optsHash['--duplicatedFile']      
      
      target = SplitLffbyChromosome.new(lociFile, "target")
      target.execute()
      directoryName = target.dirName
      targetPrefix = target.lffPrefix

      query = SplitLffbyChromosome.new(amplicons,"query", directoryName)
      query.execute()
      queryPrefix = query.lffPrefix
      
      mapping = GenerateMappingFile.new("", "" , targetPrefix, queryPrefix, directoryName, mappingFile, noMappedFile, duplicatedFile )
      mapping.execute()
      
end


def self.testMissingAnnotationsFounder(optsHash)
#--targetAnnotationFileName -queryAnnotationFileName --missingAnnotationFileName
    methodName = "testMissingAnnotationsFounder"
    targetAnnotationFileName = nil
    queryAnnotationFileName = nil
    missingAnnotationFileName = nil
    
    targetAnnotationFileName = optsHash['--targetAnnotationFileName'] if( optsHash.key?('--targetAnnotationFileName') )
    queryAnnotationFileName = optsHash['--queryAnnotationFileName'] if( optsHash.key?('--queryAnnotationFileName') )
    missingAnnotationFileName = optsHash['--missingAnnotationFileName'] if( optsHash.key?('--missingAnnotationFileName') )
    
    
    if( targetAnnotationFileName.nil? || queryAnnotationFileName.nil? || missingAnnotationFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--targetAnnotationFileName=#{targetAnnotationFileName}"
      $stderr.puts "--queryAnnotationFileName=#{queryAnnotationFileName}"
      $stderr.puts "--missingAnnotationFileName=#{missingAnnotationFileName}"
      return
    end


      missingAnnotations = MissingAnnotationsFounder.new(targetAnnotationFileName, queryAnnotationFileName, missingAnnotationFileName)
      missingAnnotations.execute()
      
end

def self.testGeneratingROISeqFilesFromAmpliconSeqFiles(optsHash)
#--ampliconSequencingFileName --roiLffFileName
  #ampliconSequencingFileName = nil
  #roiLffFileName = nil
  #
  #    
  #    ampliconSequencingFileName = optsHash['--ampliconSequencingFileName'] if( optsHash.key?('--ampliconSequencingFileName') )
  #    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
  #    
  #    
  #    
  #    target = SplitLffbyChromosome.new(ampliconSequencingFileName, "amps")
  #    target.execute()
  #    directoryName = target.dirName
  #    targetPrefix = target.lffPrefix
  #
  #    query = SplitLffbyChromosome.new(roiLffFileName,"rois", directoryName)
  #    query.execute()
  #    queryPrefix = query.lffPrefix
#--directoryName --largeAnnotationFile --smallAnnotationFile
    methodName = "testGeneratingROISeqFilesFromAmpliconSeqFiles"
    directoryName = nil
    largeAnnotationFile = nil
    smallAnnotationFile = nil
    newFileName = nil
    
    directoryName = optsHash['--directoryName'] if( optsHash.key?('--directoryName') )
    largeAnnotationFile = optsHash['--largeAnnotationFile'] if( optsHash.key?('--largeAnnotationFile') )
    smallAnnotationFile = optsHash['--smallAnnotationFile'] if( optsHash.key?('--smallAnnotationFile') )
    newFileName = optsHash['--newFileName'] if( optsHash.key?('--newFileName') )
    
    if( directoryName.nil? || largeAnnotationFile.nil? || smallAnnotationFile.nil? || newFileName.nil?)
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--directoryName=#{directoryName}"
        $stderr.puts "--largeAnnotationFile=#{largeAnnotationFile}"
        $stderr.puts "--smallAnnotationFile=#{smallAnnotationFile}"
        $stderr.puts "--newFileName=#{newFileName}"
        return
    end
  
  
    TableToHashCreator.mappingAmpliconSeqFileToRoiSeqFile( directoryName, largeAnnotationFile, smallAnnotationFile, newFileName  )  
      
end

  def self.testRoiSeqLffToCoverageTable(optsHash)
    #--roiSequencingLffFileName --roiTableFile --sampleFileName
    methodName = "testRoiSequencingFileToCoverageTable"
    roiSequencingLffFileName = nil
    roiTableFile = nil
    sampleFileName  = nil
    numberOfSamples = 0
    
    sampleFileName  = optsHash['--sampleFileName'] if( optsHash.key?('--sampleFileName') )
    roiSequencingLffFileName = optsHash['--roiSequencingLffFileName'] if(optsHash.key?('--roiSequencingLffFileName'))
    roiTableFile = optsHash['--roiTableFile'] if(optsHash.key?('--roiTableFile'))
    numberOfSamples = optsHash['--numberOfSamples'] if(optsHash.key?('--numberOfSamples'))

    if(roiSequencingLffFileName.nil? || roiTableFile.nil? || sampleFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --roiSequencingLffFileName=#{roiSequencingLffFileName} --roiTableFile=#{roiTableFile} --sampleFileName=#{sampleFileName}"
      return
    end
 
    TableToHashCreator.roiSeqLffToCoverageTable(roiSequencingLffFileName, roiTableFile, sampleFileName, numberOfSamples)
  end

  
  
  def self.testSplittingFiles(optsHash)
      fileName = optsHash['--testFile'] 
   
     splitt = SplitLffbyChromosome.new(fileName)
     splitt.execute()
     puts "The directory is #{splitt.dirName} and the prefix is #{splitt.lffPrefix}"
    
      
  end
  
  def self.testSampleSequenceStorage(optsHash)
    ampliconList = nil
    fileName =  nil 
    assayName =  nil
    assayRunName = nil
    databaseName = nil
    trackName = nil
    outputFile =  nil
    #--sampleFile --assayName --ampliconList --assayRunName --databaseName --trackName --outputFile

    fileName =     optsHash['--sampleFile']
    assayName =    optsHash['--assayName']
    ampliconList = optsHash['--ampliconList'] if(optsHash.key?('--ampliconList'))
    assayRunName = optsHash['--assayRunName'] if(optsHash.key?('--assayRunName'))
    databaseName = optsHash['--databaseName'] if(optsHash.key?('--databaseName'))
    trackName =    optsHash['--trackName'] if(optsHash.key?('--trackName'))
    attributeName = optsHash['--attributeName'] if(optsHash.key?('--attributeName'))
    outputFile =   optsHash['--outputFile'] if(optsHash.key?('--outputFile'))
    
    splitt = SampleSequenceStorage.new(fileName, assayName,
                        ampliconList, assayRunName, databaseName, trackName, attributeName, outputFile)
    splitt.execute()
    $stderr.puts "The directory for storage is #{splitt.storageFolder}"

  end






  
###TODO move to other file
  def self.testSampleToAmpliconTable(optsHash)
    # --sampleFileName --ampliconFileName  --sampleAmpliconTableFile
    ampliconFileName = nil
    sampleFileName =  nil 
    sampleAmpliconTableFile =  nil

    sampleFileName =     optsHash['--sampleFileName'] if(optsHash.key?('--sampleFileName'))
    ampliconFileName = optsHash['--ampliconFileName'] if(optsHash.key?('--ampliconFileName'))
    sampleAmpliconTableFile =   optsHash['--sampleAmpliconTableFile'] if(optsHash.key?('--sampleAmpliconTableFile'))
    if(sampleFileName.nil? || ampliconFileName.nil? || sampleAmpliconTableFile.nil?)
      $stderr.puts "Error missing parameters --sampleFile=#{sampleFileName} --ampliconFileName=#{ampliconFileName} -sampleAmpliconTableFile=#{sampleAmpliconTableFile}"
      return
    end
    
    splitt = SampleToAmpliconTable.new(sampleFileName, ampliconFileName, sampleAmpliconTableFile)
    splitt.execute() if(!splitt.nil?)
  end  
  
###TODO move to other file
  def self.testReadSampleToAmpliconTable(optsHash)
#--sampleAmpliconTableFile --totalAmpliconFile --totalSampleFile
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

#
  def self.testFilteringLffUsingNumericAttValue(optsHash)
#--lffFileName --outPutFileName --attributeName --attributeThreshold --type --subtype --className
    methodName = "testFilteringLffUsingNumericAttValue"
    lffFileName =  nil 
    outPutFileName =  nil
    attributeName = nil
    attributeThreshold = nil
    type = nil
    subtype = nil
    className = nil

    lffFileName =  optsHash['--lffFileName'] if(optsHash.key?('--lffFileName'))
    outPutFileName =    optsHash['--outPutFileName'] if(optsHash.key?('--outPutFileName'))
    attributeName = optsHash['--attributeName'] if(optsHash.key?('--attributeName'))
    attributeThreshold = optsHash['--attributeThreshold'] if(optsHash.key?('--attributeThreshold'))
    type = optsHash['--type']  if( optsHash.key?('--type') )
    subtype  = optsHash['--subtype'] if( optsHash.key?('--subtype') )
    className = optsHash['--className'] if( optsHash.key?('--className') )
    
    if(lffFileName.nil? ||  outPutFileName.nil? || attributeName.nil? || attributeThreshold.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--lffFileName=#{lffFileName}"
      $stderr.puts "--outPutFileName=#{outPutFileName}"
      $stderr.puts "--attributeName=#{attributeName}"
      $stderr.puts "--attributeThreshold=#{attributeThreshold}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--subtype=#{subtype}"
      $stderr.puts "--className=#{className}"
      return 
    end

    TableToHashCreator.filteringLffUsingNumericAttValue(lffFileName, outPutFileName, attributeName, attributeThreshold.to_f, "lessThan", type, subtype, className)

    
  end



  def self.testGenerateAmplicon2LociMappingFile(optsHash)
#--ampliconLffFileName  --lociLffFileName --ampliconToLociFileName --ampliconToLociMissingFileName --ampliconToLociMultipleFileName
      return nil unless( optsHash.key?('--ampliconLffFileName') )
      ampliconLffFileName = optsHash['--ampliconLffFileName']
       
      return nil unless( optsHash.key?('--lociLffFileName') )
      lociLffFileName = optsHash['--lociLffFileName']
      
      return nil unless( optsHash.key?('--ampliconToLociFileName') )
      ampliconToLociFileName = optsHash['--ampliconToLociFileName']
      
      return nil unless( optsHash.key?('--ampliconToLociMissingFileName') )
      ampliconToLociMissingFileName = optsHash['--ampliconToLociMissingFileName']
      
      return nil unless( optsHash.key?('--ampliconToLociMultipleFileName') )
      ampliconToLociMultipleFileName = optsHash['--ampliconToLociMultipleFileName']      

      title ="#ampliconId\t#geneName"
      
      mapping = GenerateMappingFile.new(lociLffFileName ,ampliconLffFileName,  "some", "thing", ".", ampliconToLociFileName, ampliconToLociMissingFileName, ampliconToLociMultipleFileName, title )
      mapping.execute()

  end
 
 
   def self.testGenerateAmplicon2RoiMappingFile(optsHash)
#--ampliconLffFileName  --roiLffFileName --ampliconToRoiFileName --ampliconToRoiMissingFileName --ampliconToRoiMultipleFileName
      return nil unless( optsHash.key?('--ampliconLffFileName') )
      ampliconLffFileName = optsHash['--ampliconLffFileName']
       
      return nil unless( optsHash.key?('--roiLffFileName') )
      roiLffFileName = optsHash['--roiLffFileName']
      
      return nil unless( optsHash.key?('--ampliconToRoiFileName') )
      ampliconToRoiFileName = optsHash['--ampliconToRoiFileName']
      
      return nil unless( optsHash.key?('--ampliconToRoiMissingFileName') )
      ampliconToRoiMissingFileName = optsHash['--ampliconToRoiMissingFileName']
      
      return nil unless( optsHash.key?('--ampliconToRoiMultipleFileName') )
      ampliconToRoiMultipleFileName = optsHash['--ampliconToRoiMultipleFileName']
      title ="#ampliconId\t#RoiId"
      
      mapping = GenerateMappingFile.new(roiLffFileName ,ampliconLffFileName,  "some", "thing", ".", ampliconToRoiFileName, ampliconToRoiMissingFileName, ampliconToRoiMultipleFileName ,title)
      mapping.execute()

  end

   def self.testAddVptoLffFromTabDelimitedFile(optsHash)
#--tabDelimitedFileName  --lffFileName --outPutFileName
    methodName = "testRoiSequencingFileToLff"
    tabDelimitedFileName  = nil            
    lffFileName   = nil
    outPutFileName      =  nil
    
    tabDelimitedFileName =  optsHash['--tabDelimitedFileName'] if( optsHash.key?('--tabDelimitedFileName') )                     
    lffFileName =    optsHash['--lffFileName']  if( optsHash.key?('--lffFileName') )     
    outPutFileName =  optsHash['--outPutFileName'] if( optsHash.key?('--outPutFileName') )        
    
    if( tabDelimitedFileName.nil? || lffFileName.nil? || outPutFileName.nil? )
        $stderr.puts "Error missing parameters in method #{methodName}"
        $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
        $stderr.puts "--lffFileName=#{lffFileName}"
        $stderr.puts "--outPutFileName=#{outPutFileName}"
        return
    end


    mapping = AddVptoLffFromTabDelimitedFile.new(tabDelimitedFileName, lffFileName, outPutFileName)
    mapping.execute()

  end
   
   
   def self.testGenerateRoi2LociMappingFile(optsHash)
#--roiLffFileName --lociLffFileName --roiToLociFileName --roiToLociMissingFileName --roiToLociMultipleFileName
      return nil unless( optsHash.key?('--lociLffFileName') )
      lociLffFileName = optsHash['--lociLffFileName']
       
      return nil unless( optsHash.key?('--roiLffFileName') )
      roiLffFileName = optsHash['--roiLffFileName']
      
      return nil unless( optsHash.key?('--roiToLociFileName') )
      roiToLociFileName = optsHash['--roiToLociFileName']
      
      return nil unless( optsHash.key?('--roiToLociMissingFileName') )
      roiToLociMissingFileName = optsHash['--roiToLociMissingFileName']
      
      return nil unless( optsHash.key?('--roiToLociMultipleFileName') )
      roiToLociMultipleFileName = optsHash['--roiToLociMultipleFileName']
      title ="#RoiId\tgeneName"
      
      mapping = GenerateMappingFile.new(lociLffFileName, roiLffFileName,  "some", "thing", ".", roiToLociFileName, roiToLociMissingFileName, roiToLociMultipleFileName, title )
      mapping.execute()

  end 
   
   
  
  #getSortedArrayOfAmpliconIds(ampliconFileName)
  def self.testGetSortedArrayOfAmpliconIds(optsHash)
      return nil unless( optsHash.key?('--ampliconFileName') )
      ampliconFileName = optsHash['--ampliconFileName']
       
      ampliconArray = TableToHashCreator.getSortedArrayOfAmpliconIds(ampliconFileName)
      ampliconArray.each{|amplicon|
        puts amplicon
      }
  end



  def self.testPerformeOperationOnLffFile(optsHash)
#--roiLffFileName --classType --attNameToUseForGrouping --geneCoverageFileName --listOfGenes
    methodName = "testPerformeOperationOnLffFile"
    roiLffFileName = nil
    classType = nil #CountPerCoverage
    attNameToUseForGrouping = nil
    geneCoverageFileName = nil
    listOfGenes = nil
    
    listOfGenes = optsHash['--listOfGenes'] if( optsHash.key?('--listOfGenes') )
    roiLffFileName = optsHash['--roiLffFileName'] if( optsHash.key?('--roiLffFileName') )
    classType = optsHash['--classType'] if( optsHash.key?('--classType') )
    attNameToUseForGrouping = optsHash['--attNameToUseForGrouping'] if( optsHash.key?('--attNameToUseForGrouping') )
    geneCoverageFileName = optsHash['--geneCoverageFileName'] if( optsHash.key?('--geneCoverageFileName') )
    
    
    
    if( listOfGenes.nil? || roiLffFileName.nil? || attNameToUseForGrouping.nil? || geneCoverageFileName.nil? || classType.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--roiLffFileName=#{roiLffFileName}"
      $stderr.puts "--classType=#{classType}"
      $stderr.puts "--attNameToUseForGrouping=#{attNameToUseForGrouping}"
      $stderr.puts "--geneCoverageFileName=#{geneCoverageFileName}"
      $stderr.puts "--listOfGenes=#{listOfGenes}"
      return
    end

      puts "-------------------- START OF PerformeOperationOnLffFile -------------------------------------------"
      stats = PerformeOperationOnLffFile.new(roiLffFileName, geneCoverageFileName, attNameToUseForGrouping, classType, 0, listOfGenes)
      stats.execute()
      puts "-------------------- END OF Sample PerformeOperationOnLffFile -------------------------------------------"
  end




  def self.validateSampleFile(optsHash)
      return nil unless( optsHash.key?('--sampleFile') )
       fileName = optsHash['--sampleFile'] 
      puts "-------------------- START OF Sample File Validation -------------------------------------------"
      sampleHash = TableToHashCreator.sampleIdToSampleTableHash(fileName)
      puts "number of well formatted records #{sampleHash.length}"
      puts "-------------------- END OF Sample File Validation -------------------------------------------"
  end

  def self.validateAmpliconFile(optsHash)
      return nil unless( optsHash.key?('--ampliconFile') )
       fileName = optsHash['--ampliconFile'] 
      puts "-------------------- START OF Amplicon File Validation -------------------------------------------"
      ampliconHash = TableToHashCreator.ampliconIdToAmpliconTableHash(fileName)
      puts "number of well formatted records #{ampliconHash.length}"
      puts "-------------------- END OF Amplicon File Validation -------------------------------------------"
  end

  def self.validateRoiSequencingFile(optsHash)
      return nil unless( optsHash.key?('--roiSequencingFile') )
       fileName = optsHash['--roiSequencingFile'] 
      puts "-------------------- START OF Roi Sequencing File Validation -------------------------------------------"
      roiSequencingHash = TableToHashCreator.roiIdToRoiSequencingTableHash(fileName)
      puts "number of well formatted records #{roiSequencingHash.length}"
      puts "-------------------- END OF Roi Sequencing File Validation -------------------------------------------"
  end


  def self.validateAmpliconSequencingFile(optsHash)
      return nil unless( optsHash.key?('--ampliconSequencingFile') )
       fileName = optsHash['--ampliconSequencingFile'] 
      puts "-------------------- START OF Amplicon Sequencing File Validation -------------------------------------------"
      ampliconSequencingHash = TableToHashCreator.ampliconIdToAmpliconSequencingTableHash(fileName)
      puts "number of well formatted records #{ampliconSequencingHash.length}"
      puts "-------------------- END OF Amplicon Sequencing File Validation -------------------------------------------"
  end

  def self.validateSampleSequencingFile(optsHash)
      return nil unless( optsHash.key?('--sampleSequencingFile') )
       fileName = optsHash['--sampleSequencingFile'] 
      puts "-------------------- START OF Sample Sequencing File Validation -------------------------------------------"
      sampleSequencingHash = TableToHashCreator.lightSampleSequencingToHash(fileName)
      puts "number of well formatted records #{sampleSequencingHash.length}"
      puts "-------------------- END OF Sample Sequencing File Validation -------------------------------------------"
  end

  def self.validateRoiFile(optsHash)
      return nil unless( optsHash.key?('--roiFile') )
       fileName = optsHash['--roiFile'] 
      puts "-------------------- START OF ROI File Validation -------------------------------------------"
      roiHash = TableToHashCreator.roiIdToHash(fileName)
      puts "number of well formatted records #{roiHash.length}"
      puts "-------------------- END OF ROI File Validation -------------------------------------------"
  end

  def self.testFilteringTabDelimitedFileUsingNumericColumn(optsHash)
#--tabDelimitedFileName --outPutFileName --columnNumber --attributeThreshold --numberOfColumns --operation --attributeThresholdMax --preserveDefLine
    methodName = "testFilteringTabDelimitedFileUsingNumericColumn"
    tabDelimitedFileName =  nil 
    outPutFileName =  nil
    columnNumber = nil
    attributeThreshold = nil
    numberOfColumns = nil
    operation = "moreThan" 
    attributeThresholdMax = "100.0"
    preserveDefLine = "true"

    tabDelimitedFileName =  optsHash['--tabDelimitedFileName'] if(optsHash.key?('--tabDelimitedFileName'))
    outPutFileName =    optsHash['--outPutFileName'] if(optsHash.key?('--outPutFileName'))
    columnNumber = optsHash['--columnNumber'] if(optsHash.key?('--columnNumber'))
    attributeThreshold = optsHash['--attributeThreshold'] if(optsHash.key?('--attributeThreshold'))
    numberOfColumns = optsHash['--numberOfColumns']  if( optsHash.key?('--numberOfColumns') )
    operation  = optsHash['--operation'] if( optsHash.key?('--operation') )
    attributeThresholdMax = optsHash['--attributeThresholdMax'] if( optsHash.key?('--attributeThresholdMax') )
    preserveDefLine = optsHash['--preserveDefLine'] if( optsHash.key?('--preserveDefLine') )
    
    if(tabDelimitedFileName.nil? ||  outPutFileName.nil? || columnNumber.nil? || attributeThreshold.nil? || numberOfColumns.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
      $stderr.puts "--outPutFileName=#{outPutFileName}"
      $stderr.puts "--columnNumber=#{columnNumber}"
      $stderr.puts "--attributeThreshold=#{attributeThreshold}"
      $stderr.puts "--numberOfColumns=#{numberOfColumns}"
      $stderr.puts "--operation=#{operation}"
      $stderr.puts "--attributeThresholdMax=#{attributeThresholdMax}"
      $stderr.puts "--preserveDefLine=#{preserveDefLine}"
      return 
    end
    

    attributeThresholdMax = attributeThresholdMax.to_f
    if(preserveDefLine == "true")
      preserveDefLine = true
    else
      preserveDefLine = false
    end
    
    columnNumber = columnNumber.to_i 
    attributeThreshold = attributeThreshold.to_f 
    numberOfColumns = numberOfColumns.to_i
    

    TableToHashCreator.filteringTabDelimitedFileUsingNumericColumn(tabDelimitedFileName, outPutFileName, columnNumber, attributeThreshold, numberOfColumns, operation, attributeThresholdMax, preserveDefLine)
    
  end


  def self.testFilteringColumnsFromTabDelimitedFile(optsHash)
#--tabDelimitedFileName --outPutFileName --columnNumbers--newHeader --numberOfColumns

    methodName = "testFilteringColumnsFromTabDelimitedFile"
    tabDelimitedFileName =  nil 
    outPutFileName =  nil
    columnNumbers = nil
    newHeader = nil
    numberOfColumns = nil
 


    tabDelimitedFileName =  optsHash['--tabDelimitedFileName'] if(optsHash.key?('--tabDelimitedFileName'))
    outPutFileName =    optsHash['--outPutFileName'] if(optsHash.key?('--outPutFileName'))
    columnNumbers  = optsHash['--columnNumbers'] if( optsHash.key?('--columnNumbers') )
    newHeader = optsHash['--newHeader'] if( optsHash.key?('--newHeader') )
    numberOfColumns = optsHash['--numberOfColumns']  if( optsHash.key?('--numberOfColumns') )
    
    if(tabDelimitedFileName.nil? ||  outPutFileName.nil? || columnNumbers.nil? || numberOfColumns.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--tabDelimitedFileName=#{tabDelimitedFileName}"
      $stderr.puts "--outPutFileName=#{outPutFileName}"
      $stderr.puts "--columnNumbers=#{columnNumbers}"
      $stderr.puts "--newHeader=#{newHeader}"
      $stderr.puts "--numberOfColumns=#{numberOfColumns}"
      return 
    end
    
    numberOfColumns = numberOfColumns.to_i
    
    TableToHashCreator.filteringColumnsFromTabDelimitedFile(tabDelimitedFileName, outPutFileName, columnNumbers, newHeader, numberOfColumns)

  end

  def self.validateMutationTableHash(mutationFileName)
    #--mutationFileName
    errorCounter = 0
    maxNumberOfErrors = 1000
    retVal = {}
    return retVal if( mutationFileName.nil? )

    reader = BRL::Util::TextReader.new(mutationFileName)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/ or line =~ /^\s*Hugo_Symbol/i)
          lineCounter = lineCounter + 1
          next
        end
        
        if(errorCounter > maxNumberOfErrors)
          $stderr.puts "Too many errors in file #{mutationFileName} please fix the problems and re-submit the file!"
          return nil
        end 
        
        rg = MutationFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          if(lineCounter == 1)
            $stderr.puts "error in line #{lineCounter}  = #{Constants::ErrorLevelHash[58]}"
            errorCounter += 1
          else
            $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
            errorCounter += 1
          end
        elsif(retVal.has_key?(rg.id))
          $stderr.puts "Mutation #{rg.chromosome}.#{rg.start}.#{rg.strand}.#{rg.entrezGeneId} from line #{lineCounter} is present multiple times line skipped"
          errorCounter += 1
        else
          retVal[rg.id] = rg
        end
        lineCounter += 1
      }
      reader.close()
      puts "The number of records in file #{mutationFileName} is #{retVal.length} and the number of lines in the file are #{lineCounter}"

    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    return retVal
  end


  def self.testMutationTableHash(optsHash)
    #--mutationFileName

    methodName = "testMutationTableHash"
    tabDelimitedFileName =  nil 

    mutationFileName =  optsHash['--mutationFileName'] if(optsHash.key?('--mutationFileName'))
    if(mutationFileName.nil? )
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--tabDelimitedFileName=#{mutationFileName}"
      return 
    end
    
    numberOfColumns = numberOfColumns.to_i
    validateMutationTableHash(mutationFileName)

  end

  def self.testMutationFileToLff(optsHash)
    #--mutationFileName --type --mutationSubtype  --mutationClassName --mutationLffFileName
    methodName = "testMutationFileToLff"
    mutationFileName =  nil 
    type = nil        
    mutationSubtype =  nil  
    mutationClassName =  nil
    mutationLffFileName = nil
    
    mutationFileName =    optsHash['--mutationFileName'] if( optsHash.key?('--mutationFileName') )
    type =           optsHash['--type'] if( optsHash.key?('--type') )
    mutationSubtype =     optsHash['--mutationSubtype'] if( optsHash.key?('--mutationSubtype') )
    mutationClassName =   optsHash['--mutationClassName'] if( optsHash.key?('--mutationClassName') )
    mutationLffFileName = optsHash['--mutationLffFileName'] if( optsHash.key?('--mutationLffFileName') )
    
    if( mutationFileName.nil? || type.nil? || mutationSubtype.nil? ||  mutationClassName.nil? || mutationLffFileName.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--mutationFileName=#{mutationFileName}"
      $stderr.puts "--type=#{type}"
      $stderr.puts "--mutationSubtype=#{mutationSubtype}"
      $stderr.puts "--mutationClassName=#{mutationClassName}"
      $stderr.puts "--mutationLffFileName=#{mutationLffFileName}"
      return
    end

    TableToHashCreator.mutationFileToLff(mutationFileName, mutationLffFileName, mutationClassName, type, mutationSubtype)
  end


   def self.generateMutationCompletionFile(optsHash)
#--mutationLffFileName --mutationSummaryFileName --mutationAttribute variantClassification --listOfGenes

    methodName = "generateMutationCompletionFile"
    mutationClassType = "CountMutationsVariantClassification"
    mutationAttribute = nil
    mutationLffFileName = nil
    mutationSummaryFileName = nil
    numberOfSamples = 0
    
    mutationAttribute = optsHash['--mutationAttribute'] if( optsHash.key?('--mutationAttribute') )
    mutationLffFileName = optsHash['--mutationLffFileName'] if( optsHash.key?('--mutationLffFileName') )
    mutationSummaryFileName = optsHash['--mutationSummaryFileName'] if( optsHash.key?('--mutationSummaryFileName') )
    
    
    if( mutationLffFileName.nil? || mutationSummaryFileName.nil? || mutationAttribute.nil?)
      $stderr.puts "Error missing parameters in method #{methodName}"
      $stderr.puts "--mutationLffFileName=#{mutationLffFileName}"
      $stderr.puts "--mutationSummaryFileName=#{mutationSummaryFileName}"
      $stderr.puts "--mutationAttribute=#{mutationAttribute}"
      return
    end
    

      puts "-------------------- START OF generateMutationCompletionFile -------------------------------------------"
      stats = PerformeOperationOnLffFile.new(mutationLffFileName, mutationSummaryFileName, mutationAttribute, mutationClassType)
      stats.execute()
      puts "-------------------- END OF Sample PerformeOperationOnLffFile -------------------------------------------"
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


#testing basic functions not used for implementation
#BRL::FileFormats::TCGAParsers::TestMethods.testSplittingFiles(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testValueToNameHash(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testSampleIdToSampleTableHash(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testAmpliconIdToAmpliconSequencingTableHash(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testGeneratingMapFilesFromLargeFiles(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testRoiIdToRoiSequencingTableHash(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testSampleSequenceStorage(optsHash)
#BRL::FileFormats::TCGAParsers::TestMethods.testGetSortedArrayOfAmpliconIds(optsHash)
#working but file not longer available
####BRL::FileFormats::TCGAParsers::TestMethods.testAmpliconSequencingFileToLff(optsHash)
#working but file not longer available
#BRL::FileFormats::TCGAParsers::TestMethods.validateAmpliconSequencingFile(optsHash)#--ampliconSequencingFile


#Validators
#--roiFile --sampleFile --ampliconFile --sampleSequencingFile --roiSequencingFile
#BRL::FileFormats::TCGAParsers::TestMethods.validateRoiFile(optsHash) #--roiFile
#BRL::FileFormats::TCGAParsers::TestMethods.validateSampleFile(optsHash) #--sampleFile
#BRL::FileFormats::TCGAParsers::TestMethods.validateAmpliconFile(optsHash) #--ampliconFile
#BRL::FileFormats::TCGAParsers::TestMethods.validateSampleSequencingFile(optsHash) #--sampleSequencingFile
#BRL::FileFormats::TCGAParsers::TestMethods.validateRoiSequencingFile(optsHash) #--roiSequencingFile


#lff Generators
# --type --ampliconSubtype  --ampliconClassName --ampliconLffFileName
#--ampliconFileName --primerSubtype  --primerClassName --primerLffFileName
#--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
#--roiSequencingFileName --roiSeqclassName --roiSequencingLffFileName

#--ampliconFile  --type --ampliconSubtype --ampliconClassName --ampliconLffFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testAmpliconIdToLff(optsHash)
#--ampliconFileName  --type --primerSubtype --primerClassName --primerLffFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testAmpliconIdToPrimerLff(optsHash)
#--roiFileName --type --roiSubtype  --roiClassName --roiLffFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testRoiToLff(optsHash)
#--roiFileName --roiSequencingFileName --type --roiSeqclassName --roiSequencingLffFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testRoiSequencingFileToLff(optsHash)



#Generating Mapping Files
#--ampliconLffFileName  --roiLffFileName --ampliconToRoiFileName --ampliconToRoiMissingFileName --ampliconToRoiMultipleFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testGenerateAmplicon2RoiMappingFile(optsHash)
#--roiLffFileName --lociLffFileName --roiToLociFileName --roiToLociMissingFileName --roiToLociMultipleFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testGenerateRoi2LociMappingFile(optsHash)
#--ampliconLffFileName  --lociLffFileName --ampliconToLociFileName --ampliconToLociMissingFileName --ampliconToLociMultipleFileName 
#BRL::FileFormats::TCGAParsers::TestMethods.testGenerateAmplicon2LociMappingFile(optsHash)
#    --roiSequencingFileName --roiTableFile
#BRL::FileFormats::TCGAParsers::TestMethods.testRoiSequencingFileToCoverageTable(optsHash)


#Generating Tables and Sample completion
# --sampleFileName --ampliconFileName  --sampleAmpliconTableFile
#BRL::FileFormats::TCGAParsers::TestMethods.testSampleToAmpliconTable(optsHash)
#--sampleAmpliconTableFile --totalAmpliconFile --totalSampleFile
#BRL::FileFormats::TCGAParsers::TestMethods.testReadSampleToAmpliconTable(optsHash)




#add the tabular files to the lffs as value pairs
#--tabDelimitedFileName  --lffFileName --outPutFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testAddVptoLffFromTabDelimitedFile(optsHash)
#--lffFileName --outPutFileName --attributeName --attributeThreshold --type --subtype --className
#BRL::FileFormats::TCGAParsers::TestMethods.testFilteringLffUsingNumericAttValue(optsHash)

#--roiLffFileName --classType --attNameToUseForGrouping --geneCoverageFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testPerformeOperationOnLffFile(optsHash)

#--tabDelimitedFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testLoadtabDelimitedFileToHash(optsHash)
#--tabDelimitedFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testCalculateAverageForCoverageFile(optsHash)
#--tabDelimitedFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testCalculateAverageForSampleToTotalFile(optsHash)
#--tabDelimitedFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testCalculateAverageForAmpliconToTotal(optsHash)
#--ampliconSequencingFileName --roiLffFileName
#BRL::FileFormats::TCGAParsers::TestMethods.testGeneratingROISeqFilesFromAmpliconSeqFiles(optsHash)
#--roiSequencingLffFileName --roiTableFile --sampleFileName # this is for Baylor's data
#BRL::FileFormats::TCGAParsers::TestMethods.testRoiSeqLffToCoverageTable(optsHash)





#--tabDelimitedFileName --outPutFileName --columnNumber --attributeThreshold --numberOfColumns --operation --attributeThresholdMax --preserveDefLine
#BRL::FileFormats::TCGAParsers::TestMethods.testFilteringTabDelimitedFileUsingNumericColumn(optsHash)



#--tabDelimitedFileName --outPutFileName --columnNumbers--newHeader --numberOfColumns
#BRL::FileFormats::TCGAParsers::TestMethods.testFilteringColumnsFromTabDelimitedFile(optsHash)

#BRL::FileFormats::TCGAParsers::TestMethods.testMissingAnnotationsFounder(optsHash)
#--targetAnnotationFileName -queryAnnotationFileName --missingAnnotationFileName

#BRL::FileFormats::TCGAParsers::TestMethods.testMutationTableHash(optsHash)
#--mutationFileName
BRL::FileFormats::TCGAParsers::TestMethods.testMutationFileToLff(optsHash)
##--mutationFileName --type --mutationSubtype  --mutationClassName --mutationLffFileName


#BRL::FileFormats::TCGAParsers::TestMethods.generateMutationCompletionFile(optsHash)
#--mutationLffFileName --mutationSummaryFileName
