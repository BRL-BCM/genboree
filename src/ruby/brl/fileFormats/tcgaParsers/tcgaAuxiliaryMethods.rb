#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'interval' # Implements Interval arithmetic!!!
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/fileFormats/lffHash'
require 'brl/fileFormats/tcgaParsers/tcgaFiles'



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
      
      
class TcgaAuxiliaryMethods
end

class GenerateMappingFile

  attr_accessor :directoryName, :nameMappingFile, :nameOfduplicatedRecordsFile
  attr_accessor :nameMissingMappingFile, :smallAnnotationFiles
  attr_accessor :largeAnnotationFile, :queryPrefix, :header
  attr_accessor :targetPrefix, :allAnnotations, :annotationMapped

  
  def initialize(largeAnnotationFile, smallAnnotationFile, targetPrefix="target", queryPrefix="query", directoryName=".", nameMappingFile="mappingFile.txt", nameMissingMappingFile="missingMapping.txt", dupFile="duplicatedFile.txt", header="#name\tvalue")
    @directoryName, @nameMappingFile, @nameMissingMappingFile = nil
    @smallAnnotationFiles =  Array.new()
    @queryPrefix = queryPrefix
    @targetPrefix = targetPrefix
    @header = header

    @allAnnotations = Hash.new {|hh, kk| hh[kk] = nil}
    @annotationMapped = Hash.new {|hh, kk| hh[kk] = nil}
    
    @nameMappingFile = nameMappingFile
    @nameMissingMappingFile = nameMissingMappingFile
    @nameOfduplicatedRecordsFile= dupFile
    @largeAnnotationFile =  largeAnnotationFile

    @directoryName = directoryName
        
    if(!smallAnnotationFile.nil? and smallAnnotationFile.length > 0)
      @smallAnnotationFiles << smallAnnotationFile
    else
      @smallAnnotationFiles = Dir["#{@directoryName}/#{@queryPrefix}*.lff"]
    end
    
 
  end
  
  def printHash(fileName, hashToPrint, printkey=true, printvalue=false)
    fileWriter = BRL::Util::TextWriter.new(fileName)
    hashToPrint.each{|key,res|
      if(printkey and !printvalue)
        fileWriter.puts key
      elsif(!printkey and printvalue)
        fileWriter.puts "#{res}"
      else
          fileWriter.puts "#{key}\t#{res}"
      end
      }
    fileWriter.close()
  end
  
  def printMissingMappings()
    missingAnnotations = Hash.new {|hh, kk| hh[kk] = []}

    @allAnnotations.each_key{|anno|
          missingAnnotations[anno] = nil if(!@annotationMapped.has_key?(anno))
      }
    
    printHash(@nameMissingMappingFile, missingAnnotations)    
  end
  

  def printDuplicateRecords()
    fileWriter = BRL::Util::TextWriter.new(@nameOfduplicatedRecordsFile)
    @annotationMapped.each{|key,anno|
          fileWriter.puts "#{key}\t#{anno.keys.join(",")}" if(anno.length() > 1)
      }
    fileWriter.close()
  end

  def printUniqueMappingFile()
    fileWriter = BRL::Util::TextWriter.new(@nameMappingFile)
    fileWriter.puts @header
    @annotationMapped.each{|key,anno|
        anno.each_key{|annoKey|
          fileWriter.puts "#{key}\t#{annoKey}"
          }
      }
    fileWriter.close()
  end
  

 
   def execute()
    generateMappingFileForSmallAnnToLargeRegions()
    printUniqueMappingFile()
    printMissingMappings()
    printDuplicateRecords()
  end
  
 
  def generateMappingFileForSmallAnnToLargeRegions()

#    Dir.chdir(@directoryName)

    if(@largeAnnotationFile.nil? and @queryPrefix.nil?)
      $stderr.print("Error you need to provide a name for the file with the Targets or a queryPrefix")
      exit 300
    end
        
    if(@largeAnnotationFile.nil? and @targetPrefix.nil?)
      $stderr.print("Error you need to provide a name for the file with the Targets or a targetPrefix")
      exit 301
    end    
        
    @smallAnnotationFiles.each { |queryFile|
      queryArray = Array.new()
      targetArray = Array.new()

      queryReader = BRL::Util::TextReader.new(queryFile)

      if(!@largeAnnotationFile.nil? and @largeAnnotationFile.length > 0)
          targetFile = @largeAnnotationFile
      else
          targetFile = queryFile.gsub(/"#{@queryPrefix}"/, "#{@targetPrefix}")
      end
      targetReader = BRL::Util::TextReader.new(targetFile)
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
        $stderr.puts "ERROR: File #{targetFile} do not exist!. Details: method = generateMappingFileForSmallAnnToLargeRegions 164 #{err.message}"
        #      exit 345 #Do not exit just record the error!
      end
      targetReader.close()
      begin
          queryReader.each { |ff|
              ff.each { |line|
                  line.strip!
                  tAnno = line.split(/\t/)
                  next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                  myHash = LFFHash.new(line)
                  queryArray << myHash
              }
          }
      rescue => err
        $stderr.puts "ERROR: File #{queryFile} do not exist!. Details: method = generateMappingFileForSmallAnnToLargeRegions 179 #{err.message}"
        #      exit 348 #Do not exit just record the error!
      end
      queryReader.close
      targetArray.each { |myTarget|
        myTarget.to_interval()
        tIv = myTarget.asInterval
        queryArray.each { |myQuery|
            myQuery.to_interval()
            qIv = myQuery.asInterval

            next if(myQuery.lffChr != myTarget.lffChr || myTarget.lffStart > myQuery.lffStop || myQuery.lffStart > myTarget.lffStop)
            
            if(!@allAnnotations.has_key?(myQuery.lffName))
              @allAnnotations[myQuery.lffName] = nil
            end             

            unless( (tIv & qIv).empty? )
              if(!@annotationMapped.has_key?(myQuery.lffName))  
                targetsHash = Hash.new {|hh, kk| hh[kk] = nil}
                targetsHash[myTarget.lffName]
                @annotationMapped[myQuery.lffName] = targetsHash
              else
                @annotationMapped[myQuery.lffName][myTarget.lffName] = nil if(!@annotationMapped[myQuery.lffName].has_key?(myTarget.lffName))
              end
            end
        }
      }
    }  
  
  end 


end #end of class
######################################
class MissingAnnotationsFounder

  attr_accessor :outPutFile
  attr_accessor :largeAnnotationFile, :queryPrefix, :header
  attr_accessor :notInQueryArray
  
  def initialize(largeAnnotationFile, smallAnnotationFile, outPutFile)
    @smallAnnotationFile =  smallAnnotationFile
    @notInQueryArray = Array.new()
    @largeAnnotationFile =  largeAnnotationFile
    @outPutFile = outPutFile
  end
  
  def saveNotInQuery()
    if(@outPutFile.nil?)
      $stderr.print("Error you need to provide a name for the file to save the results")
      exit 301
    end
    begin
      fileWriter = BRL::Util::TextWriter.new(@outPutFile)
      @notInQueryArray.each_index{|location|
        lff = @notInQueryArray[location]
          fileWriter.puts lff.to_lff() if(!lff.nil?)
        }
      fileWriter.close()
    rescue => err
      $stderr.puts "ERROR: File #{outPutFile} do not exist!. Details: method = saveNotInQuery 240 #{err.message}"
    end
  end
  
   def execute()
    generateArrayTargetsNotInQuery()
    saveNotInQuery()
  end
  
 
  def generateArrayTargetsNotInQuery()
    
    if(@largeAnnotationFile.nil?)
      $stderr.print("Error you need to provide a name for the file with the Targets")
      exit 300
    end
        
    if(@smallAnnotationFile.nil?)
      $stderr.print("Error you need to provide a name for the file with the Queries")
      exit 301
    end    
        
    queryArray = Array.new()

    targetFile = @largeAnnotationFile
    targetReader = BRL::Util::TextReader.new(targetFile)
    begin
      targetReader.each { |ff|
        ff.each { |line|
            line.strip!
            tAnno = line.split(/\t/)
            next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
            myHash = LFFHash.new(line)
            @notInQueryArray << myHash
        }
      }  
    rescue => err
      $stderr.puts "ERROR: File #{targetFile} do not exist!. Details: method = generateArrayTargetsNotInQuery 277 #{err.message}"
      #      exit 345 #Do not exit just record the error!
    end
    targetReader.close()
    begin
        queryReader = BRL::Util::TextReader.new(@smallAnnotationFile)
        queryReader.each { |ff|
            ff.each { |line|
                line.strip!
                tAnno = line.split(/\t/)
                next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                myHash = LFFHash.new(line)
                queryArray << myHash
            }
        }
    rescue => err
      $stderr.puts "ERROR: File #{queryFile} do not exist!. Details: method = generateArrayTargetsNotInQuery 293 #{err.message}"
      #      exit 348 #Do not exit just record the error!
    end
    queryReader.close
    
    @notInQueryArray.each_index{|location|
      myTarget = @notInQueryArray[location]
      next if(myTarget.nil?)
      myTarget.to_interval()
      tIv = myTarget.asInterval
      queryArray.each { |myQuery|
          next if(myTarget.nil?)          
          myQuery.to_interval()
          qIv = myQuery.asInterval

          next if(myQuery.lffChr != myTarget.lffChr || myTarget.lffStart > myQuery.lffStop || myQuery.lffStart > myTarget.lffStop)
          unless( (tIv & qIv).empty? )
#              $stderr.puts "deleting #{myTarget.lffName} #{myTarget.lffChr} #{myTarget.lffStart} #{myTarget.lffStop}"
              name = "#{myTarget.lffName} #{myTarget.lffChr} #{myTarget.lffStart} #{myTarget.lffStop}"

              @notInQueryArray[location] = nil
              myTarget = nil
              if(!myTarget.nil?)
                $stderr.puts "Unable to delete #{name}" 
#              else
#                $stderr.puts "Deleted #{name}" 
              end
              
          end
      }
    }
  
  end 


end #end of class

######################################
class RoiCoverage
  attr_accessor :oneXCoverage, :twoXCoverage, :length
  def initialize(oneXCoverage=0.0, twoXCoverage=0.0)
    @oneXCoverage = 0.0
    @twoXCoverage = 0.0
    @length = 0.0
    
    if(!oneXCoverage.nil? and oneXCoverage > 0.0)
      @oneXCoverage += oneXCoverage
      @length = 1.0
    end
    @twoXCoverage += twoXCoverage if(!twoXCoverage.nil? and twoXCoverage > 0.0)
    
  end
  
  def add(oneXCoverageValue, twoXCoverageValue)
    if(!oneXCoverageValue.nil? and oneXCoverageValue > 0.0)
      @oneXCoverage += oneXCoverageValue
      @length += 1
    end
    @twoXCoverage += twoXCoverageValue if(!twoXCoverageValue.nil? and twoXCoverageValue > 0.0)
    
  end 
  
end

class TabDelimitedFileReader

  attr_accessor :tabDelimitedFileName, :definitionArray
  attr_accessor :numberOfRecords, :numberOfDefinitions, :hashOfArraysWithTabDelimitedValues
  

  def initialize(tabDelimitedFileName)
    @tabDelimitedFileName = nil
    @definitionArray = nil
    @numberOfRecords = 0
    @numberOfDefinitions = 0
    @hashOfArraysWithTabDelimitedValues = Hash.new {|hh,kk| hh[kk] = [] }
    @tabDelimitedFileName =  tabDelimitedFileName

  end

  
  def loadTabDelimitedFile()
    line = nil
    return nil if( @tabDelimitedFileName.nil? )
    # Read tabDelimitedFile file
    reader = BRL::Util::TextReader.new(@tabDelimitedFileName)
    counter = 1
    begin
      reader.each { |line|
        if(line =~ /^\s*[#]/ and @definitionArray.nil?)
          @definitionArray = line.chomp.gsub(/#/, "").split(/\t/)
          @numberOfDefinitions = @definitionArray.length
          next
        end
        next if(line.nil? or line.empty? or line =~ /^\s*[#]/)
        aa = line.chomp.split(/\t/)
        if(aa[0].nil? || aa[0].chomp.length < 1)
          $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
        else
          keyToUse = aa[0].to_sym
          @hashOfArraysWithTabDelimitedValues[keyToUse] = aa
        end
        counter += 1
      }
      reader.close()
      @numberOfRecords = @hashOfArraysWithTabDelimitedValues.length
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
  end

end

class InstFileAgregator
  attr_accessor :filePrefix, :rootDir, :dirs, :directories, :names, :setValues, :resultHash
  attr_accessor :numberOfRecords
  
  def initialize(filePrefix, rootDir, dirs)
    @filePrefix = nil
    @rootDir = nil
    @dirs = nil
    @directories = Array.new()
    @names = Array.new()
    @setValues = Array.new()
    @resultHash = Hash.new {|hh,kk| hh[kk] = [] }
    @numberOfRecords = 0
  end 

end

  class AddVptoLffFromTabDelimitedFile
    attr_accessor :tabDelimitedFileName, :lffFileName, :lffFileOutput, :definitionArray
    attr_accessor :numberOfRecords, :numberOfDefinitions, :hashOfArraysWithTabDelimitedValues
    
  
    
    def initialize(tabDelimitedFileName, lffFileName, outPutFileName)
      @tabDelimitedFileName, @lffFileName, @lffFileOutput = nil
      @definitionArray = nil
      @numberOfRecords = 0
      @numberOfDefinitions = 0
      @hashOfArraysWithTabDelimitedValues = Hash.new {|hh,kk| hh[kk] = [] }
      @tabDelimitedFileName =  tabDelimitedFileName
      @lffFileName = lffFileName
      @lffFileOutput = outPutFileName
    end
  
    def execute()
      loadTabDelimitedFile()
      readLffFile()
    end
    
    def readLffFile()
      fileWriter = BRL::Util::TextWriter.new(@lffFileOutput)
      reader = BRL::Util::TextReader.new(@lffFileName)
      begin
        reader.each { |ff|
            ff.each { |line|
                line.strip!
                tAnno = line.split(/\t/)
                next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                myHash = LFFHash.new(line)
                name = myHash.lffName
                arrayVPs = @hashOfArraysWithTabDelimitedValues[name]
                counter = 0
                arrayVPs.each{|vpValues|
                  vpName = @definitionArray[counter]
                  myHash[vpName.to_sym]=vpValues
                  counter += 1
                }
                fileWriter.puts myHash.to_lff 
            }
        }
      rescue => err
          $stderr.puts "ERROR: File #{@lffFileName} do not exist!. Details:  method = readLffFile 470  #{err.message}"
          #      exit 348 #Do not exit just record the error!
      end
        reader.close()
        fileWriter.close()
    end
    
    def loadTabDelimitedFile()
      return nil if( @tabDelimitedFileName.nil? )
      # Read ampliconlistName file
      reader = BRL::Util::TextReader.new(@tabDelimitedFileName)
      counter = 1
      begin
        reader.each { |line|
          if(line =~ /^\s*[#]/ and @definitionArray.nil?)
            @definitionArray = line.chomp.gsub(/#/, "").split(/\t/)
            @definitionArray.shift
            @numberOfDefinitions = @definitionArray.length
            next
          end
          next if(line.nil? or line.empty?)
          aa = line.chomp.split(/\t/)
          if(aa[0].nil? || aa[0].chomp.length < 1)
            $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file #{tabDelimitedFileName} line number #{counter}"
          else
            keyToUse = aa.shift.to_sym
            @hashOfArraysWithTabDelimitedValues[keyToUse] = aa
          end
          counter += 1
        }
        reader.close()
        @numberOfRecords = @hashOfArraysWithTabDelimitedValues.length
      rescue => err
        $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        $stderr.puts "LINE: #{line.inspect}"
        exit 137
      end
    end
  end

  class AddCommaSeparatedVptoLffFromTabDelimitedFile
    attr_accessor :tabDelimitedFileName, :lffFileName, :lffFileOutput, :definitionArray
    attr_accessor :numberOfRecords, :numberOfDefinitions, :hashOfKeyWithCommaSeparatedValues
    
  
    
    def initialize(tabDelimitedFileName, lffFileName, outPutFileName)
      @tabDelimitedFileName, @lffFileName, @lffFileOutput = nil
      @definitionArray = nil
      @numberOfRecords = 0
      @numberOfDefinitions = 0
      @hashOfKeyWithCommaSeparatedValues = Hash.new {|hh,kk| hh[kk] = nil }
      @tabDelimitedFileName =  tabDelimitedFileName
      @lffFileName = lffFileName
      @lffFileOutput = outPutFileName
    end
  
    def execute()
      loadTabDelimitedFile()
      readLffFile()
    end
    
    def readLffFile()
      fileWriter = BRL::Util::TextWriter.new(@lffFileOutput)
      reader = BRL::Util::TextReader.new(@lffFileName)
      begin
        reader.each { |line|
                line.strip!
                tAnno = line.split(/\t/)
                next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                myHash = LFFHash.new(line)
                name = myHash.lffName
                vPvalue = @hashOfKeyWithCommaSeparatedValues[name]
                counter = 0
                if(!vPvalue.nil?)
                  vpName = @definitionArray[counter]  
                  myHash[vpName.to_sym]=vPvalue
                end
                fileWriter.puts myHash.to_lff 
        }
      rescue => err
          $stderr.puts "ERROR: File #{@lffFileName} do not exist!. Details:  method = readLffFile 552 #{err.message}"
          #      exit 348 #Do not exit just record the error!
      end
        reader.close()
        fileWriter.close()
    end
    
    def loadTabDelimitedFile()
      return nil if( @tabDelimitedFileName.nil? )
      # Read ampliconlistName file
      hashOfHashes = Hash.new {|hh,kk| hh[kk] = nil }
      reader = BRL::Util::TextReader.new(@tabDelimitedFileName)
      counter = 1
      begin
        reader.each { |line|
          if(line =~ /^\s*[#]/ and @definitionArray.nil?)
            @definitionArray = line.chomp.gsub(/#/, "").split(/\t/)
            @definitionArray.shift
            @numberOfDefinitions = @definitionArray.length
            next
          end
          next if(line.nil? or line.empty?)
          aa = line.chomp.split(/\t/)
          if(aa[0].nil? || aa[0].chomp.length < 1)
            $stderr.puts "wrong record in line --->\"#{line.chomp}\"<----in file loadTabDelimitedFile line number #{counter}"
          else
            keyToUse = aa.shift.to_sym
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
        hashOfHashes.each_key{|myKey|
          @hashOfKeyWithCommaSeparatedValues[myKey] = hashOfHashes[myKey].keys.join(",")
        }
  
        @numberOfRecords = @hashOfKeyWithCommaSeparatedValues.length
        
      rescue => err
        $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        $stderr.puts "LINE: #{line.inspect}"
        exit 137
      end
    end
  end
  

class SplitLffbyChromosome
  # Accessors (getters/setters ; instance variables
    attr_accessor :dirName, :hashOfLffWithArrays, :lffPrefix, :lffFile
    
  def initialize(lffFileIn, preFix=nil, directoryName=nil)
    @lffFile = lffFileIn
    if(preFix.nil?)
      @lffPrefix = lffFileIn
    else
      @lffPrefix = preFix
    end
    if(directoryName.nil?)
      @dirName = createFolder()
    else
      @dirName = directoryName
    end
    @hashOfLffWithArrays = Hash.new {|hh,kk| hh[kk] = [] }
  end
   
  def createFolder()
    directoryName = "#{@lffPrefix}_#{Time.now()}".gsub(/\W/, "")
    Dir::mkdir(directoryName)
    return directoryName
  end
  


  def initialLffLoad()
    counter = 0
    reader = BRL::Util::TextReader.new(@lffFile)
    reader.each { |ff|
      ff.each { |line|
        line.strip!
        tAnno = line.split(/\t/)
        next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
        myHash = LFFHash.new(line)
        @hashOfLffWithArrays[myHash.lffChr] << myHash
        counter += 1
      }
    }
    reader.close()
  end
  # Sort the annotations in each chromosome by position
  def sortLffWithArraysByStart()
    
    @hashOfLffWithArrays.each_key { |chrom|
      @hashOfLffWithArrays[chrom].sort! {|aa, bb| 
        retVal = (aa.lffStart <=> bb.lffStart)
        retVal = (aa.lffStop <=> bb.lffStop) if(retVal == 0)
        retVal
      }
    }
    
  end
  
  def createLffFilesDivByChrom ( )
    lffHash = LFFHash.new()
    newFileName = nil
    fileWriter = nil
    
    @hashOfLffWithArrays.each_key { |chrom|
      newFileName = "#{@dirName}/#{@lffPrefix}_#{chrom}.lff"
      fileWriter = BRL::Util::TextWriter.new(newFileName)
      @hashOfLffWithArrays[chrom].each {|annotation| 
        lffHash = annotation
        fileWriter.puts lffHash.to_lff()
      }
      fileWriter.close()
    }
  end
  
   
  def execute()
    initialLffLoad()
    sortLffWithArraysByStart()
    createLffFilesDivByChrom()
  end

 
end #end of class

class SampleSequenceStorage
  # Accessors (getters/setters ; instance variables
    attr_accessor :dirName, :hashOfSamplesWithArrays, :storageFolder
    attr_accessor :samplePrefix, :sampleFile, :sampleNames, :attributeName
    attr_accessor :ampliconNames, :ampliconOrderHash, :definitionFile, :trackName
    attr_accessor :orderUsingAmpHash, :outputFile, :assayName, :assayRunName, :databaseName
  
    DataStorage = "/usr/local/brl/data/dataStorage/assays"
    
  def initialize(sampleFileIn, assayName, ampliconListFileName=nil, assayRunName=nil, databaseName=nil, trackName=nil, attributeName=nil, outputFile=nil, preFix=nil, directoryName=nil)
    @ampliconNames = nil
    @sampleFile = sampleFileIn
    @dirName = directoryName
    @assayName = assayName
    @assayRunName = assayRunName
    @trackName = trackName
    @databaseName = databaseName
    @trackName = "centerName:amplicons" if(@trackName.nil?)
    @attributeName = attributeName
    @attributeName = "ampliconId" if(@attributeName.nil?)
    @storageFolder = createStorageFolder()
    
    if(!outputFile.nil?)
      @outputFile = outputFile
    else
      @outputFile = "#{sampleFileIn}_results_#{Time.now()}.txt".gsub(/\s/, "").gsub(/:/, "")
    end
    @assayRunName = @outputFile.gsub(/\.txt/, "") if(@assayRunName.nil?)
    
    
    @definitionFile = "#{@outputFile}.schema"
    
    @orderUsingAmpHash = false
    @ampliconOrderHash = Hash.new {|hh,kk| hh[kk] = [] }
    @ampliconNames = loadAmpliconOrderList(ampliconListFileName) unless(ampliconListFileName.nil?)
    if(!@ampliconNames.nil? and @ampliconNames.length > 0)
      counter = 0
      @orderUsingAmpHash = true
      @ampliconNames.each{|amplicon|
        @ampliconOrderHash[amplicon] = counter
        counter += 1
        }
    end

    if(preFix.nil?)
      @samplePrefix = sampleFileIn
    else
      @samplePrefix = preFix
    end

    @hashOfSamplesWithArrays = Hash.new {|hh,kk| hh[kk] = [] }
  end
   
  
  def createStorageFolder()
    $stderr.puts "Inside the storage folder"
    return nil  if(@assayName.nil? or @assayRunName.nil? or @databaseName.nil?)
        $stderr.puts "createStorageFolder after return"
    dirs = [@databaseName, @assayName, @assayRunName]
    baseString = DataStorage
    begin
      dirs.each {|dir|
        baseString ="#{baseString}/#{dir}"
        begin
          dirExist = Dir.new(baseString) 
        rescue => err
          dirExist = nil
          $stderr.puts "The directory #{baseString} already exist"
        end
        Dir::mkdir(baseString) if(dirExist.nil?)
      }
    rescue => err
      $stderr.puts "making dir #{baseString} fail"
      baseString = nil
    end

    return baseString
  end
  
  def loadAmpliconOrderList(ampliconListFileName)
    $stderr.puts ampliconListFileName.inspect
    ampliconNames = nil
    return nil if( ampliconListFileName.nil? )
    # Read ampliconlistName file
    reader = BRL::Util::TextReader.new(ampliconListFileName)    
    begin
      ampliconNames = Array.new()
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[\[#]/)
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next if(aa.length > 1)
        ampliconId = aa[0].chomp if(!aa[0].nil?)
        ampliconNames << ampliconId
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    
    return ampliconNames
  end
  
  
  def initialSampleLoad()
    retVal = {}
    reader = BRL::Util::TextReader.new(@sampleFile)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter += 1
          next
        end
        
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          lineCounter += 1
          next
        end
        @hashOfSamplesWithArrays[rg.sampleId] << rg
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


  # Sort the annotations in each chromosome by position
  def sortFilesWithArraysByAmplicon()
   
    @hashOfSamplesWithArrays.each_key { |sampleId|
      if(!@orderUsingAmpHash)
        @hashOfSamplesWithArrays[sampleId].sort! {|aa, bb| 
          retVal = (aa.ampliconId <=> bb.ampliconId)
        }
      else
        @hashOfSamplesWithArrays[sampleId].sort! {|aa, bb|
          if(aa.ampliconId.nil? || bb.ampliconId.nil?)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with empty values for a amplicon"
            retVal = 1
          elsif(@ampliconOrderHash[aa.ampliconId].nil? || @ampliconOrderHash[aa.ampliconId].to_s.length < 1)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with an amplicon #{aa.ampliconId} not in the amplicon definition file"
            retVal = 1
          elsif(@ampliconOrderHash[bb.ampliconId].nil? || @ampliconOrderHash[bb.ampliconId].to_s.length < 1)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with an amplicon #{bb.ampliconId} not in the amplicon definition file"
            retVal = 1
          else
            retVal = (@ampliconOrderHash[aa.ampliconId] <=> @ampliconOrderHash[bb.ampliconId])
          end
        }
      end
    }
    
  end
  
  def printDefinitionFile()
    fileWriter = BRL::Util::TextWriter.new(@definitionFile)
    fileWriter.puts "ASSAY NAME:\t#{@assayName}"
    fileWriter.puts "ASSAY ATTRIBUTES:\tdate=#{Time.now.rfc2822};"
    fileWriter.puts "RECORD FIELDS:\t#{SampleSequencingFile.getFields(2)}"
    fileWriter.puts "FIELD TYPES:\t#{SampleSequencingFile.getFieldTypes(2)}"
    fileWriter.puts "ANNO LINK ATTRIBUTE:\t#{@attributeName}"
    fileWriter.puts "ANNO LINK TRACK:\t#{@trackName}"
    counter = 1
    @ampliconNames.each { |ampliconName|
      fileWriter.puts "#{counter}\t#{ampliconName}"
        counter += 1
    }
    fileWriter.close()
    
  end


  def createFilesReadyToStore()
    printDefinitionFile()  if(@orderUsingAmpHash)
    fileWriter = BRL::Util::TextWriter.new(@outputFile)
    fileWriter.puts "ASSAY NAME:\t#{@assayName}"
    fileWriter.puts "ASSAY RUN ATTRIBUTES:\tdate=#{Time.now.rfc2822};"
    fileWriter.puts "ASSAY RUN NAME:\t#{@assayRunName}"
    fileWriter.puts "DATA:"
    
    @hashOfSamplesWithArrays.each_key { |sampleId|
      ampliconDone = Hash.new {|hh,kk| hh[kk] = 0}
      @hashOfSamplesWithArrays[sampleId].each {|annotation|
        ampliconDone[annotation.ampliconId] =  annotation.to_sample(2)
      }
      if(@orderUsingAmpHash)
        @ampliconNames.each { |ampliconName|
          if(!ampliconDone.has_key?(ampliconName))
            tempAnnotation = SampleSequencingFile.new("#{sampleId}\t#{ampliconName}")
            ampliconDone[ampliconName] = tempAnnotation.to_sample(2)  
          end
        }
      else
        @ampliconNames = ampliconDone.keys
      end
      counter = 0
      fileWriter.print "#{sampleId}\t"
      @ampliconNames.each { |ampliconName|
        fileWriter.print "#{ampliconDone[ampliconName]}" if(ampliconDone.has_key?(ampliconName))
        counter += 1
        fileWriter.print "\t" if(counter < @ampliconNames.length)
      }
      fileWriter.puts ""
    }
    fileWriter.close()
  end
  
   
  def execute()
    initialSampleLoad()
    sortFilesWithArraysByAmplicon()
    createFilesReadyToStore()
  end

 
end #end of class




class SampleToAmpliconTable
  # Accessors (getters/setters ; instance variables
    attr_accessor :dirName, :hashOfSamplesWithArrays
    attr_accessor :samplePrefix, :sampleSequencingFile, :sampleNames
    attr_accessor :ampliconNames, :ampliconOrderHash, :sampleFileName
    attr_accessor  :outputFile
  
    
  def initialize(sampleSequencingFileIn, ampliconFileName, outputFile, sampleFileName, preFix=nil, directoryName=nil)
    return nil if(sampleSequencingFileIn.nil? || ampliconFileName.nil? || outputFile.nil?) 
    @ampliconNames = nil
    @sampleFileName = sampleFileName
    @sampleSequencingFile = sampleSequencingFileIn
    @sampleNames = nil
    @dirName = directoryName
    @outputFile = outputFile

    @ampliconOrderHash = Hash.new {|hh,kk| hh[kk] = [] }
    @ampliconNames = TableToHashCreator.getSortedArrayOfAmpliconIds(ampliconFileName)
    if(!@ampliconNames.nil? and @ampliconNames.length > 0)
      counter = 0
      @ampliconNames.each{|amplicon|
        @ampliconOrderHash[amplicon] = counter
        counter += 1
        }
    end

    @sampleNames = TableToHashCreator.getSortedArrayOfSampleIds(@sampleFileName)
    
    
    if(preFix.nil?)
      @samplePrefix = sampleSequencingFileIn
    else
      @samplePrefix = preFix
    end

    @hashOfSamplesWithArrays = Hash.new {|hh,kk| hh[kk] = [] }
  end
   
  def createFolder()
    directoryName = "#{@samplePrefix}_#{Time.now()}".gsub(/\s/, "")
    Dir::mkdir(directoryName)
    return directoryName
  end
  
  def loadAmpliconOrderList(ampliconListFileName)
    $stderr.puts ampliconListFileName.inspect
    ampliconNames = nil
    return nil if( ampliconListFileName.nil? )
    # Read ampliconlistName file
    reader = BRL::Util::TextReader.new(ampliconListFileName)    
    begin
      ampliconNames = Array.new()
      reader.each { |line|
        next if(line !~ /\S/ or line =~ /^\s*[\[#]/)
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        next if(aa.length > 1)
        ampliconId = aa[0].chomp if(!aa[0].nil?)
        ampliconNames << ampliconId
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    
    return ampliconNames
  end
  
  
  def initialSampleLoad()

    reader = BRL::Util::TextReader.new(@sampleSequencingFile)
    line = nil
    lineCounter = 1
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          lineCounter += 1
          next
        end
        
        rg = SampleSequencingFile.new(line)
        errorLevel = rg.errorLevel
        if(errorLevel > 0)
          $stderr.puts "error in line #{lineCounter} errorId [#{errorLevel}] =   #{rg.returnErrorMessage(errorLevel)}"
          lineCounter += 1
          next
        end
        @hashOfSamplesWithArrays[rg.sampleId] << rg
        lineCounter += 1
      }
      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
    
    #@hashOfSamplesWithArrays.each_key{|sampleId|
    # puts "SampleId from Sample Sequencing File = #{sampleId.inspect}" 
    #  }



    @sampleNames.each{|sampleId|
      if(!@hashOfSamplesWithArrays.has_key?(sampleId))
#        puts "SampleId from Sample File NOT in SSF = #{sampleId.inspect}"
        ampliconNames.each{|ampliconId|
          line = "#{sampleId}\t#{ampliconId}"
          rg = SampleSequencingFile.new(line)
          @hashOfSamplesWithArrays[rg.sampleId] << rg
          }
      else
#        puts "SampleId from Sample File FOUND in SSF = #{sampleId.inspect}"
      end
      }


  end

  def sortFilesWithArraysByAmplicon()
    
    @hashOfSamplesWithArrays.each_key { |sampleId|
        @hashOfSamplesWithArrays[sampleId].sort! {|aa, bb|
          if(aa.ampliconId.nil? || bb.ampliconId.nil?)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with empty values for a amplicon"
            retVal = 1
          elsif(@ampliconOrderHash[aa.ampliconId].nil? || @ampliconOrderHash[aa.ampliconId].to_s.length < 1)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with an amplicon #{aa.ampliconId} not in the amplicon definition file"
            retVal = 1
          elsif(@ampliconOrderHash[bb.ampliconId].nil? || @ampliconOrderHash[bb.ampliconId].to_s.length < 1)
            $stderr.puts "The Sample_Sequencing file contains a sample #{sampleId} with an amplicon #{bb.ampliconId} not in the amplicon definition file"
            retVal = 1
          else
            retVal = (@ampliconOrderHash[aa.ampliconId] <=> @ampliconOrderHash[bb.ampliconId])
          end
        }
    }
  end
  
  def createFilesDivBySample()
    newFileName = nil
    fileWriter = nil
    @dirName = createFolder() if(@dirName.nil?)
    @hashOfSamplesWithArrays.each_key { |sampleId|
      newFileName = "#{@dirName}/#{sampleId}"
      fileWriter = BRL::Util::TextWriter.new(newFileName)
      ampliconDone = Hash.new {|hh,kk| hh[kk] = 0}
      @hashOfSamplesWithArrays[sampleId].each {|annotation|
        ampliconDone[annotation.ampliconId] =  annotation.to_sample(1)
      }

      @ampliconNames.each { |ampliconName|
        if(!ampliconDone.has_key?(ampliconName))
          tempAnnotation = SampleSequencingFile.new("#{sampleId}\t#{ampliconName}")
          ampliconDone[ampliconName] = tempAnnotation.to_sample(1)  
        end
      }

      @ampliconNames.each { |ampliconName|
        fileWriter.puts ampliconDone[ampliconName] if(ampliconDone.has_key?(ampliconName))
      }
      fileWriter.close()
    }
  end

  def createSampleToAmpliconTable()
    fileWriter = BRL::Util::TextWriter.new(@outputFile)

    fileWriter.print "#Sample_Name\t"
    counter = 0
    @ampliconNames.each { |ampliconName|
        fileWriter.print ampliconName
        counter += 1
        fileWriter.print "\t" if(counter < @ampliconNames.length)
        }
    fileWriter.puts ""
    counter = 0
    
    @hashOfSamplesWithArrays.each_key { |sampleId|
      ampliconDone = Hash.new {|hh,kk| hh[kk] = 0}
      @hashOfSamplesWithArrays[sampleId].each {|annotation|
        ampliconDone[annotation.ampliconId] =  annotation.to_sample(3)
      }

      @ampliconNames.each { |ampliconName|
        if(!ampliconDone.has_key?(ampliconName))
          tempAnnotation = SampleSequencingFile.new("#{sampleId}\t#{ampliconName}")
          ampliconDone[ampliconName] = tempAnnotation.to_sample(3)  
        end
      }

      counter = 0
      fileWriter.print "#{sampleId}\t"
      @ampliconNames.each { |ampliconName|
        fileWriter.print "#{ampliconDone[ampliconName]}" if(ampliconDone.has_key?(ampliconName))
        counter += 1
        fileWriter.print "\t" if(counter < @ampliconNames.length)
      }
      fileWriter.puts ""
    }
    fileWriter.close()
  end
  
   
  def execute()
    initialSampleLoad()
    sortFilesWithArraysByAmplicon()
#    createFilesDivBySample()
    createSampleToAmpliconTable()
  end

 
end #end of class

## Need to change add a static variable
######################################
class ReadSampleToAmpliconTable
  # Accessors (getters/setters ; instance variables
    attr_accessor :hashOfSamplesWithArrays, :hashOfSamplesWithTotal
    attr_accessor :sampleAmpliconTableFile, :hashOfAmpliconsWithTotal
    attr_accessor :numberOfSamples, :numberOfAmplicons, :numberOfSamplesDefault
    attr_accessor :totalAmpliconFile, :totalSampleFile, :definitionArray
  
    
  def initialize(sampleAmpliconTableFile, totalAmpliconFile, totalSampleFile)
    return nil if(sampleAmpliconTableFile.nil? ||  totalAmpliconFile.nil? || totalSampleFile.nil?) 
    @sampleAmpliconTableFile = sampleAmpliconTableFile
    @totalAmpliconFile = totalAmpliconFile
    @totalSampleFile = totalSampleFile
    @numberOfAmplicons, @numberOfSamples = 0

    @hashOfSamplesWithArrays = Hash.new {|hh,kk| hh[kk] = [] }
    @hashOfSamplesWithTotal = Hash.new {|hh,kk| hh[kk] = 0 }
    @hashOfAmpliconsWithTotal = Hash.new {|hh,kk| hh[kk] = 0 }
    @definitionArray = nil
  end
  
  def loadTable()
    return nil if( @sampleAmpliconTableFile.nil? )
    # Read ampliconlistName file
    reader = BRL::Util::TextReader.new(@sampleAmpliconTableFile)
    counter = 1
    begin
      reader.each { |line|
        if(line =~ /^\s*[#]/ and @definitionArray.nil?)
          @definitionArray = line.chomp.gsub(/#/, "").split(/\t/)
          @definitionArray.shift
          @numberOfAmplicons = @definitionArray.length
          next
        end
        next if(line.nil? or line.empty?)
        aa = line.chomp.split(/\t/)
        sampleId = aa.shift
        @hashOfSamplesWithArrays[sampleId] = aa
        counter += 1
      }
      reader.close()
      @numberOfSamples = @hashOfSamplesWithArrays.length
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
  end
  
  
  def populateSampleTotals()
      @hashOfSamplesWithArrays.each {|key, array|
        total = 0
        array.each{|amplicon|
          total = total + 1 if(amplicon =~ /true/)
          }
        @hashOfSamplesWithTotal[key] = total
        }
  end

  def populateAmpliconTotals()
      @definitionArray.each_index{|location|
        total = 0
        @hashOfSamplesWithArrays.each {|key,array|
          sampleValue = array[location]
          total += 1 if(sampleValue =~ /true/)
        }
        @hashOfAmpliconsWithTotal[@definitionArray[location]] = total
      }
      
  end


   def createTotalAmpliconFile()
    percentage = 0.00
    fileWriter = BRL::Util::TextWriter.new(@totalAmpliconFile)
    fileWriter.puts "#AmpliconId\tNumberSamplesPass\tNumberSamples\tPercentageSamplesPass"
    @definitionArray.each {|ampliconName|
        percentage = ((@hashOfAmpliconsWithTotal[ampliconName]).to_i / @numberOfSamples.to_f ) * 100
        tempString = sprintf("%s\t%i\t%i\t%.2f%%", ampliconName, @hashOfAmpliconsWithTotal[ampliconName], @numberOfSamples, percentage)
        fileWriter.puts tempString
#        fileWriter.puts "#{ampliconName}\t#{@hashOfAmpliconsWithTotal[ampliconName]}\t#{@numberOfSamples}\t#{percentage}"
    }
    fileWriter.close()
  end 


  def createTotalSampleFile()
    percentage = 0.00
    fileWriter = BRL::Util::TextWriter.new(@totalSampleFile)
    fileWriter.puts "#SampleName\tNumberOfAmpliconPass\tTotalAmplicon\tPercentagePass"
    @hashOfSamplesWithTotal.each{|key, value|
      percentage = (value.to_i / @numberOfAmplicons.to_f ) * 100
      tempString = sprintf("%s\t%i\t%i\t%.2f%%", key, value, @numberOfAmplicons, percentage)
      fileWriter.puts tempString
#      fileWriter.puts "#{key}\t#{value}\t#{@numberOfAmplicons}\t#{percentage}"
    }
    fileWriter.close()
  end
  
   
  def execute()
    loadTable()
    populateSampleTotals()
    populateAmpliconTotals()
    createTotalAmpliconFile()
    createTotalSampleFile()
  end

 
end #end of class
#####################################
class CountPerAmpliconCompletion
  attr_accessor :groupByAtt, :numberSamples, :numberSamplesPass, :percentageSamplesPass
  attr_accessor :arrayOfNumberSamples, :arrayOfNumberSamplesPass, :arrayOfPercentageSamplesPass
  attr_accessor :numberOfRecords
  attr_accessor :totalOfNumberSamples, :totalOfNumberSamplesPass, :totalOfPercentageSamplesPass
  attr_accessor :averageOfNumberSamples, :averageOfNumberSamplesPass, :averageOfPercentageSamplesPass
  
  def initialize(lffHash, groupByAtt, numberOfSamples)    
    @numberOfRecords = 0.0
    @totalOfNumberSamples = 0.0
    @totalOfNumberSamplesPass = 0.0
    @totalOfPercentageSamplesPass = 0.0
    @averageOfNumberSamples = 0.0
    @averageOfNumberSamplesPass = 0.0
    @averageOfPercentageSamplesPass = 0.0
    @numberOfSamplesDefault = numberOfSamples
    @arrayOfNumberSamples = Array.new()
    @arrayOfNumberSamplesPass = Array.new()
    @arrayOfPercentageSamplesPass = Array.new()
    @numberSamples = "NumberSamples".to_sym
    @numberSamplesPass = "NumberSamplesPass".to_sym
    @percentageSamplesPass = "PercentageSamplesPass".to_sym
    @groupByAtt = groupByAtt
    add(lffHash) 
  end
  
  def add(lffHash)
    begin
    numberSamplesValue = ""
    numberSamplesPassValue = ""
    percentageSamplesPassValue = ""
    
    if(!lffHash.nil?)

      numberSamplesValue = "#{lffHash[@numberSamples]}"
      
      if(!numberSamplesValue.nil? and numberSamplesValue.length > 0)
        numberSamplesValue = numberSamplesValue.to_f
      else
        numberSamplesValue = 0.0
      end
      
      numberSamplesPassValue = "#{lffHash[@numberSamplesPass]}"
      
      if(!numberSamplesPassValue.nil? and numberSamplesPassValue.length > 0)
        numberSamplesPassValue = numberSamplesPassValue.to_f
      else
        numberSamplesPassValue = 0.0
      end

      percentageSamplesPassValue = "#{lffHash[@percentageSamplesPass]}"
      
      if(!percentageSamplesPassValue.nil? and percentageSamplesPassValue.length > 0)
        percentageSamplesPassValue = percentageSamplesPassValue.gsub(/\%/, "").strip
        percentageSamplesPassValue = percentageSamplesPassValue.to_f
      else
        percentageSamplesPassValue = 0.0
      end
      
      
    else
      numberSamplesValue = 0.0
      numberSamplesPassValue = 0.0
      percentageSamplesPassValue = 0.0
    end

    @arrayOfNumberSamples << numberSamplesValue
    @arrayOfNumberSamplesPass << numberSamplesPassValue
    @arrayOfPercentageSamplesPass << percentageSamplesPassValue
    
    rescue => err
    $stderr.puts "Segmentation on class CountPerCoverage::add #{lffHash.inspect}"
    end
  end
  
  def calculateTotal()
    counter = 0
    @arrayOfNumberSamples.each{|numberSamplesValue|
      @totalOfNumberSamples += numberSamplesValue
      counter += 1
    }
    @numberOfRecords = counter
    
    
    counter = 0
    @arrayOfNumberSamplesPass.each{|numberSamplesPassValue|
      @totalOfNumberSamplesPass += numberSamplesPassValue
      counter += 1
    }

    counter = 0
    @arrayOfPercentageSamplesPass.each{|percentageSamplesPassValue|
      @totalOfPercentageSamplesPass += percentageSamplesPassValue
      counter += 1
    }

    
    @averageOfNumberSamples = @totalOfNumberSamples / @numberOfRecords if(!@totalOfNumberSamples.nil? and !@numberOfRecords.nil?)
    @averageOfNumberSamplesPass = @totalOfNumberSamplesPass / @numberOfRecords if(!@totalOfNumberSamplesPass.nil? and !@numberOfRecords.nil?)
    @averageOfPercentageSamplesPass = @totalOfPercentageSamplesPass / @numberOfRecords if(!@totalOfPercentageSamplesPass.nil? and !@numberOfRecords.nil?)
  end
  
  def printHeader(fileWriter)
    fileWriter.puts "#geneName\tNumber of amplicons\tNumber of Samples\tNumber of Samples Pass\tPercentage of Samples Pass"    
  end

  def printTotal(fileWriter)
    if(@groupByAtt.nil? || @numberOfRecords.nil? ||  @averageOfNumberSamples.nil? || @averageOfNumberSamplesPass.nil? || @averageOfPercentageSamplesPass.nil?)
    puts "#{@groupByAtt}-#{@numberOfRecords}-#{@averageOfNumberSamples}-#{@averageOfNumberSamplesPass}-#{@averageOfPercentageSamplesPass}"
    else
    tempString = sprintf("%s\t%i\t%.2f\t%.2f\t%.2f%%", @groupByAtt, @numberOfRecords.to_i, @averageOfNumberSamples, @averageOfNumberSamplesPass, @averageOfPercentageSamplesPass)
    fileWriter.puts tempString
    end
  end
  
end

#####################################
class CountPerCoverage
  attr_accessor :groupByAtt, :perc1xCoverage, :perc2xCoverage
  attr_accessor :arrayOfPerc1xCoverageValues, :arrayOfPerc2xCoverageValues, :arrayOfNumberOfSamples
  attr_accessor :numberOfRecords, :numberOfSamplesDefault
  attr_accessor :totalOf1xRecords, :totalOf2xRecords, :totalNumberOfSamples
  attr_accessor :averageOf1xRecords, :averageOf2xRecords, :averageNumberOfSamples
  
  def initialize(lffHash, groupByAtt, numberOfSamples)
    @numberOfRecords = 0.0
    @totalOf1xRecords = 0.0
    @totalOf2xRecords = 0.0
    @totalNumberOfSamples = 0.0
    @averageOf1xRecords = 0.0
    @averageOf2xRecords = 0.0
    @averageNumberOfSamples = 0.0
    @numberOfSamplesDefault = numberOfSamples
    @arrayOfPerc1xCoverageValues = Array.new()
    @arrayOfPerc2xCoverageValues = Array.new()
    @arrayOfNumberOfSamples = Array.new()
    @perc1xCoverage = "perc1xCoverage".to_sym
    @perc2xCoverage = "perc2xCoverage".to_sym
    @numberOfSamples = "NumberSamples".to_sym
    @groupByAtt = groupByAtt
    add(lffHash) 
  end
  
  def add(lffHash)
    begin
    oneXValue = ""
    twoXValue = ""
    nuSamp = ""
    
    if(!lffHash.nil?)

      oneXValue = "#{lffHash[@perc1xCoverage]}"
      
      if(!oneXValue.nil? and oneXValue.length > 0)
        oneXValue = oneXValue.gsub(/\%/, "").strip
        oneXValue = oneXValue.to_f
      else
        oneXValue = 0.0
      end
      
      twoXValue = "#{lffHash[@perc2xCoverage]}"
      
      if(!twoXValue.nil? and twoXValue.length > 0)
        twoXValue = twoXValue.gsub(/\%/, "").strip
        twoXValue = twoXValue.to_f
      else
        twoXValue = 0.0
      end
      
      nuSamp ="#{lffHash[@numberOfSamples]}"
      if(!nuSamp.nil? and nuSamp.length > 0)
        nuSamp = nuSamp.to_f
      else
        nuSamp = @numberOfSamplesDefault
      end
      
    else
      oneXValue = 0.0
      twoXValue = 0.0
      nuSamp = @numberOfSamplesDefault
    end
    
    @arrayOfPerc1xCoverageValues << oneXValue
    @arrayOfPerc2xCoverageValues << twoXValue
    @arrayOfNumberOfSamples << nuSamp
    rescue => err
    $stderr.puts "Segmentation on class CountPerCoverage::add #{lffHash.inspect}"
    end
  end
  
  def calculateTotal()
    counter = 0
    @arrayOfPerc1xCoverageValues.each{|oneXValue|
      @totalOf1xRecords += oneXValue
      counter += 1
    }
    @numberOfRecords = counter
    counter = 0
    @arrayOfPerc2xCoverageValues.each{|twoXValue|
      @totalOf2xRecords += twoXValue
      counter += 1
    }

    counter = 0
    @arrayOfNumberOfSamples.each{|nuSamp|
      @totalNumberOfSamples += nuSamp
      counter += 1
    }

    @averageOf1xRecords = @totalOf1xRecords / @numberOfRecords if(!@totalOf1xRecords.nil? and !@numberOfRecords.nil?)
    @averageOf2xRecords = @totalOf2xRecords / @numberOfRecords if(!@totalOf2xRecords.nil? and !@numberOfRecords.nil?)
    @averageNumberOfSamples = @totalNumberOfSamples / @numberOfRecords if(!@totalNumberOfSamples.nil? and !@numberOfRecords.nil?)

  end
  
  def printHeader(fileWriter)
    fileWriter.puts "#gene Name\tNumber of ROIs\tNumber of samples\tpercentage1XCoverage\tpercentage2XCoverage"    
  end

  def printTotal(fileWriter)

    tempString = sprintf("%s\t%i\t%i\t%.2f%%\t%.2f%%", @groupByAtt.to_s, @numberOfRecords.to_i, @averageNumberOfSamples.to_i, @averageOf1xRecords, @averageOf2xRecords)
    fileWriter.puts tempString
  end
  
end

#########################################################

class CountMutationsVariantClassification
  attr_accessor :groupByAtt, :names, :numberOfRecords
  
  def initialize(lffHash, groupByAtt, numberOfSamples=0)
    @numberOfRecords = 0.0
    @names = Array.new()
    @groupByAtt = groupByAtt
    add(lffHash) 
  end
  
  def add(lffHash)
    begin
    name = nil
    name = "#{lffHash.lffName}" if(!lffHash.nil?)
    
    @names << name if(!name.nil?)
    rescue => err
    $stderr.puts "Segmentation on class CountMutationsVariantClassification::add #{lffHash.inspect}"
    end
  end
  
  def calculateTotal()
    counter = 0
    @numberOfRecords = @names.size if(!@names.nil?)
  end
  
  def printHeader(fileWriter)
    fileWriter.puts "#variant Classification\tNumber of Records"    
  end

  def printTotal(fileWriter)
    tempString = sprintf("%s\t%i", @groupByAtt.to_s, @numberOfRecords.to_i)
    fileWriter.puts tempString
  end
  
end



#########################################################


class PerformeOperationOnLffFile
  attr_accessor :lffFileName, :lffFileOutput, :typeOfCounterObject, :hashOfGroupsTouse
  attr_accessor :hashOfGroupAttributes, :grpAtt, :numberOfSamples, :fileWithlistOfGroupsToUse
  
  def initialize(lffFileName, outPutFileName, attNameToUseForGrouping, typeOfCounterObject, numberOfSamples=0, fileWithlistOfGroupsToUse=nil)
    @lffFileName, @lffFileOutput = nil
    @typeOfCounterObject = eval(typeOfCounterObject)
    @grpAtt = attNameToUseForGrouping.to_sym
    @fileWithlistOfGroupsToUse = fileWithlistOfGroupsToUse
    if(!@fileWithlistOfGroupsToUse.nil?)
      @hashOfGroupsTouse = TableToHashCreator.loadSingleColumnFile(@fileWithlistOfGroupsToUse)
    else
      @hashOfGroupsTouse = nil
    end
    @hashOfGroupAttributes = Hash.new {|hh,kk| hh[kk] = nil }
    @lffFileName = lffFileName
    @lffFileOutput = outPutFileName
    @numberOfSamples = numberOfSamples

  end

  def execute()
    readLffFile()
    calculateTotals()
  end
  
  def readLffFile()
    reader = BRL::Util::TextReader.new(@lffFileName)
    begin
      counter = 1
      reader.each { |ff|
          ff.each { |line|
              line.strip!
              tAnno = line.split(/\t/)
              if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)
                $stderr.puts "line is empty #{line} or truncated"
                counter += 1
                next
              end
              myHash = LFFHash.new(line)
              groupByAtt = myHash[@grpAtt]
              groupByAtt = "#{groupByAtt}"
              if(groupByAtt.nil? or groupByAtt.length < 1)
                $stderr.puts "line in file #{@lffFileName} do not have the attribute #{@grpAtt} -> #{line}"
                counter += 1
                next
              end
              
              if(groupByAtt =~ /,/)
                indiGroup = groupByAtt.split(/,/)
              else
                indiGroup = [groupByAtt]
              end
              
            indiGroup.each{|grpByAtt|
              grpByAtt = grpByAtt.to_sym
              if(!@fileWithlistOfGroupsToUse.nil?)
                if(grpByAtt.nil? || "#{grpByAtt}".size < 1)
                  $stderr.puts "There is no group in file #{@lffFileName} line = #{counter} annotation name = #{myHash.lffName} chr = #{myHash.lffChr} coord start = #{myHash.lffStart}"
                  counter += 1
                  next 
                end
              end
              if(!@hashOfGroupsTouse.nil? and @hashOfGroupsTouse.has_key?(grpByAtt))
                @hashOfGroupsTouse[grpByAtt] = "found"
              end
              
              if(@hashOfGroupAttributes.has_key?(grpByAtt))
                  @hashOfGroupAttributes[grpByAtt].add(myHash)
              else
                  @hashOfGroupAttributes[grpByAtt] = @typeOfCounterObject.new(myHash, grpByAtt, numberOfSamples)
              end
              counter += 1
            }
          }
      }
      
    if(!@hashOfGroupsTouse.nil?)
      @hashOfGroupsTouse.each_key{ |groupToUse|
        if(@hashOfGroupsTouse[groupToUse].nil?)
          @hashOfGroupAttributes[groupToUse] = @typeOfCounterObject.new(nil, groupToUse, numberOfSamples)
        end
      }
    end
      
    rescue => err
        $stderr.puts "ERROR: File #{@lffFileName} do not exist!. Details:  method = readLffFile 1609 #{err.message}"
        #      exit 348 #Do not exit just record the error!
    end
      reader.close()

  end
  
  def calculateTotals()

    fileWriter = BRL::Util::TextWriter.new(@lffFileOutput)
    counter = 0
    @hashOfGroupAttributes.each {|groupByAtt, countObject|
      countObject.printHeader(fileWriter) if(counter == 0)
      countObject.calculateTotal()
      countObject.printTotal(fileWriter)
      counter += 1
    }
    fileWriter.close()
  end
    
end #end of class

#####################################
end; end; end #namespace
