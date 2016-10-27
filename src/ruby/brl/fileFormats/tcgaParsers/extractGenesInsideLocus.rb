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

class ExtractGenesInsideLocus


  attr_accessor :targetFile, :queryFile, :fileWithExtractedGenes
  EXTRACT_GENES_VERSION = "0.1"

  
  def initialize(targetFile, queryFile, fileWithExtractedGenes)
    @queryFile = queryFile
    @fileWithExtractedGenes = fileWithExtractedGenes
    @targetFile =  targetFile 
  end
  

 
  def extractGenes()    
    fileWriter = BRL::Util::TextWriter.new(@fileWithExtractedGenes)  

      targetReader = BRL::Util::TextReader.new(@targetFile)
      begin

        targetHash = Hash.new {|hh, kk| hh[kk] = nil}
        targetReader.each { |line|
              line.strip!
              tAnno = line.split(/\t/)

              next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)
               
 
              myHash = LFFHash.new(line)


              
              targetHash[myHash.lffChr] = Hash.new {|hh, kk| hh[kk] = nil} if(!targetHash.has_key?(myHash.lffChr) )
              targetHash[myHash.lffChr][myHash.lffName] = myHash


        }  
      rescue => err
        $stderr.puts "ERROR: Target File #{targetFile} do not exist!. Details: method = extractGenes 164 #{err.message}"
        #      exit 345 #Do not exit just record the error!
      end
      targetReader.close()



    queryReader = BRL::Util::TextReader.new(@queryFile)

    begin
      queryReader.each { |line|
        line.strip!
        tAnno = line.split(/\t/)
        next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or tAnno.length < 10)				
        myHash = LFFHash.new(line)
        inter = Interval[myHash.lffStart, myHash.lffStop]  
        tempTargetHash = targetHash[myHash.lffChr]
        next if(tempTargetHash.nil?)
        myFlag = false
        tempTargetHash.each{ |key, targetLffHash|
          next if(myFlag)
          targetInter = Interval[targetLffHash.lffStart, targetLffHash.lffStop]
          result = (targetInter & inter)                  
          unless( result.empty? )
            myFlag = true
            fileWriter.puts myHash.to_lff
          end
        }
    }  
    rescue => err
    $stderr.puts "ERROR: File #{@queryFile} do not exist!. Details: method = extractGenes 179 #{err.message}"
    #      exit 348 #Do not exit just record the error!
    end
    queryReader.close()
    fileWriter.close()
  
  end 


end #end of class





class ExtractGenesInsideLocusWrapper


DEFAULTUSAGEINFO ="

      Usage: Extract Annotations using a Loci File for example extract all the snps inside a locus file.
      
  
      Mandatory arguments:

    -o    --fileWithExtractedGenes            #[fileWithExtractedGenes].
    -q    --queryFile            #[queryFile].
    -t    --targetFile            #[targetFile].
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
      puts BRL::FileFormats::TCGAParsers::ExtractGenesInsideLocus::EXTRACT_GENES_VERSION
      exit(0)
    end

    def self.parseArgs()
          
      optsArray = [
                    ['--fileWithExtractedGenes', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--queryFile', '-q', GetoptLong::REQUIRED_ARGUMENT],
                    ['--targetFile', '-t', GetoptLong::REQUIRED_ARGUMENT],
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

        mapping = BRL::FileFormats::TCGAParsers::ExtractGenesInsideLocus.new(optsHash['--targetFile'], optsHash['--queryFile'], optsHash['--fileWithExtractedGenes'])
	mapping.extractGenes()
     

    end
  
end

end; end; end;  #namespace

optsHash = BRL::FileFormats::TCGAParsers::ExtractGenesInsideLocusWrapper.parseArgs()

BRL::FileFormats::TCGAParsers::ExtractGenesInsideLocusWrapper.extractGenesInsideLocusWrapper(optsHash)
