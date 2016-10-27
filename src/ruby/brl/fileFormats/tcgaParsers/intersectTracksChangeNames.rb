#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: convert from UCSC table to equivalent LFF version

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'interval' # Implements Interval arithmetic!!!
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




class IntersectTracksChangeNames

  attr_accessor :lociFile, :queryFile, :fileWithExtractedGenes, :targetHash, :hashOfNames, :oldNamesToNewNames
  attr_accessor :className, :typeName, :subTypeName

  INTERSECT_VERSION = "0.1"
  
  def initialize(lociFile, queryFile, fileWithExtractedGenes, className, typeName, subTypeName)
    @queryFile = queryFile
    @fileWithExtractedGenes = fileWithExtractedGenes
    @lociFile =  lociFile
    @className = className
    @typeName = typeName
    @subTypeName = subTypeName
    @targetHash = Hash.new {|hh, kk| hh[kk] = nil}
    @hashOfNames = Hash.new {|hh, kk| hh[kk] = nil}
    @oldNamesToNewNames = Hash.new {|hh, kk| hh[kk] = nil}

  end
  
  def generateTargetHash()


      target_reader = BRL::Util::TextReader.new(@lociFile)
      begin
        target_reader.each { |line|
              line.strip!
              tAnno = line.split(/\t/)

              if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)
                next
              end
 
              myHash = LFFHash.new(line)

              if(@targetHash.has_key?(myHash.lffChr))
                  @targetHash[myHash.lffChr][myHash.lffName] = myHash
              else
                @targetHash[myHash.lffChr] = Hash.new {|hh, kk| hh[kk] = nil}
                @targetHash[myHash.lffChr][myHash.lffName] = myHash
              end
        }  
      rescue => err
        $stderr.puts "ERROR: Target File #{@lociFile} do not exist!. Details: method = extractGenes 164 #{err.message}"
        #      exit 345 #Do not exit just record the error!
      end
      target_reader.close()
  end
  
  
  def createHashOfNames()
    @targetHash.each_value { |chromoseHash|
      chromoseHash.each_value{ |myHash|
        targetName = myHash.lffName.to_s
        if(targetName =~ /^([a-zA-Z0-9]+)(\.\d+)$/)
          base = "#{$1}"
          subFix = 0
        else
          base = targetName
          subFix = 0
        end
        @hashOfNames[base] = subFix
      }
    }
  end
  

  
  def updateHashOfNamesWithQueryNames()
    queryReader = BRL::Util::TextReader.new(@queryFile)
    begin
      queryReader.each{|line|
        line.strip!
        tAnno = line.split(/\t/)
        next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
        myHash = LFFHash.new(line)
        if( myHash.lffName.to_s =~ /^([a-zA-Z0-9]+)\.(\d+)$/)
          baseName = "#{$1}"
          subFix = "#{$2}".to_i
        else
          baseName = myHash.lffName.to_s
          subFix = 1;
        end
        
        if(@hashOfNames.has_key?(baseName))
          value = @hashOfNames[baseName].to_i       
          if(subFix > value)
            @hashOfNames[baseName] = subFix
          end
        end
      } 
    rescue => err
      $stderr.puts "ERROR: Query File #{@queryFile} do not exist!. Details: method = generateMappingFileForSmallAnnToLargeRegions 179 #{err.message}"
      #      exit 348 #Do not exit just record the error!
    end
    queryReader.close
    
  end
  
  
  def filterQuery()
    file_writer = BRL::Util::TextWriter.new(@fileWithExtractedGenes)

    queryReader = BRL::Util::TextReader.new(@queryFile)

      begin
          queryReader.each { |line|
                  line.strip!
                  tAnno = line.split(/\t/)
                  next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
                  myHash = LFFHash.new(line)
                  originalName = myHash.lffName.to_s
                  inter = Interval[myHash.lffStart, myHash.lffStop]

                  if( myHash.lffName.to_s =~ /^([a-zA-Z0-9]+)(\.\d+)$/)
                      baseName = "#{$1}"
                      subFix = "#{$2}".to_i
                  else
                      baseName = myHash.lffName.to_s
                      subFix = 1;
                  end
                  
                  tempTargetChrHash = @targetHash[myHash.lffChr]
                  next if(tempTargetChrHash.nil?)
                  myFlag = false
                  tempTargetChrHash.each{ |key, targetLffHash|
                    next if(myFlag)
                    targetInter = Interval[targetLffHash.lffStart, targetLffHash.lffStop]
                    result = (targetInter & inter)
                    
                    unless( result.empty? )
                      if(!@hashOfNames.has_key?(baseName))
                        
                        if(@oldNamesToNewNames.has_key?(originalName))
                          myHash.lffName= "#{@oldNamesToNewNames[originalName]}".to_sym
                          myHash["originalName".to_sym]= originalName
                        else
                          targetName = targetLffHash.lffName.to_s
                          targetName = "#{$1}" if( targetName =~ /^([a-zA-Z0-9]+)(\.\d+)$/)
                          maxValue =  @hashOfNames[targetName] + 1
                          @hashOfNames[targetName] += 1
                          myHash["originalName".to_sym]= originalName
                          if(maxValue > 1) 
                            myHash.lffName="#{targetName}.#{maxValue}".to_sym
                          else
                            myHash.lffName="#{targetName}".to_sym
                          end
                          @oldNamesToNewNames[originalName] = myHash.lffName.to_s
                        end
                         myHash["trackSrc".to_sym]= "#{myHash.lffType}:#{myHash.lffSubtype}".to_sym
                      end
                      
                      myFlag = true
                      myHash.lffClass = @className if(!@className.nil?)
                      myHash.lffType = @typeName if(!@typeName.nil?)
                      myHash.lffSubtype = @subTypeName if(!@subTypeName.nil?)


                      file_writer.puts myHash.to_lff
                    end
                  }
          }
      rescue => err
        $stderr.puts "ERROR: File #{@queryFile} do not exist!. Details: method = generateMappingFileForSmallAnnToLargeRegions 179 #{err.message}"
        #      exit 348 #Do not exit just record the error!
      end
      queryReader.close()
      file_writer.close()
  end
  

 
   def execute()
    generateTargetHash()
    createHashOfNames()
    updateHashOfNamesWithQueryNames()
    filterQuery()
  end
  



end #end of class
######################################



class  IntersectTracksChangeNamesWrapper


DEFAULTUSAGEINFO ="

      Usage: This program takes a Loci File 'lociFile' as an input and extract all the corresponding regions from the second file 'queryFile'
		then rename all the resulting annotations using the names from the Loci File. If the annotations already have the same name
		as in the loci file then only the annotations with different name are renamed. You can also change the className, trackname and 
		subtype name.
      
  
      Mandatory arguments:

    -c    --className            #[className].
    -o    --fileWithExtractedGenes            #[fileWithExtractedGenes].
    -q    --queryFile            #[queryFile].
    -l    --lociFile            #[lociFile].
    -u    --subTypeName            #[subTypeName].
    -t    --typeName            #[typeName].
    -v,   --version             Display version.
    -h,   --help, 			   Display help
      
"


    def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end
    
    def self.printVersion()
      puts BRL::FileFormats::TCGAParsers::IntersectTracksChangeNames::INTERSECT_VERSION
      exit(0)
    end

    def self.parseArgs()

      optsArray = [
                    ['--className', '-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--fileWithExtractedGenes', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--queryFile', '-q', GetoptLong::REQUIRED_ARGUMENT],
                    ['--lociFile', '-l', GetoptLong::REQUIRED_ARGUMENT],
                    ['--subTypeName', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--typeName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--version', '-v',   GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      
      if(optsHash.key?('--help'))
        printUsage()
      elsif(optsHash.key?('--version'))
        printVersion()
      end
      printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)

      return optsHash
    end



    def self.extractGenesInsideLocusWrapper(optsHash)

        mapping = BRL::FileFormats::TCGAParsers::IntersectTracksChangeNames.new(optsHash['--lociFile'], optsHash['--queryFile'], optsHash['--fileWithExtractedGenes'], optsHash['--className'], optsHash['--typeName'], optsHash['--subTypeName'])
        mapping.execute()
     

    end
  
end

end; end; end; #namespace

optsHash = BRL::FileFormats::TCGAParsers::IntersectTracksChangeNamesWrapper.parseArgs()

BRL::FileFormats::TCGAParsers::IntersectTracksChangeNamesWrapper.extractGenesInsideLocusWrapper(optsHash)
