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
require 'brl/util/textFileUtil'



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

class AddBatchToSampleSummary

  def self.generateNewSampleSummaryFile(optsHash)
    #--sample2BatchFileName --sampleCompletionSummaryFile --newSampleSummaryFileName --newColumnName --columnLocation --keySize
    methodName = "generateNewSampleSummaryFile"
    sample2BatchFileName = nil
    sampleCompletionSummaryFile = nil
    newSampleSummaryFileName  = nil
    newColumnName = nil
    columnLocation = nil
    keySize = nil
    
    sample2BatchFileName        = optsHash['--sample2BatchFileName'] if( optsHash.key?('--sample2BatchFileName') )
    sampleCompletionSummaryFile  = optsHash['--sampleCompletionSummaryFile'] if(optsHash.key?('--sampleCompletionSummaryFile'))
    newSampleSummaryFileName       = optsHash['--newSampleSummaryFileName'] if(optsHash.key?('--newSampleSummaryFileName'))
    newColumnName   = optsHash['--newColumnName'] if(optsHash.key?('--newColumnName'))
    columnLocation = optsHash['--columnLocation'] if(optsHash.key?('--columnLocation'))
    keySize = optsHash['--keySize'] if(optsHash.key?('--keySize'))

    if(sample2BatchFileName.nil? || sampleCompletionSummaryFile.nil? || newSampleSummaryFileName.nil? || newColumnName.nil? || columnLocation.nil? || keySize.nil?)
      $stderr.puts "Error missing parameters in method #{methodName} --sample2BatchFileName=#{sample2BatchFileName} --sampleCompletionSummaryFile=#{sampleCompletionSummaryFile} --newSampleSummaryFileName=#{newSampleSummaryFileName} --newColumnName=#{newColumnName} --columnLocation=#{columnLocation} --keySize=#{keySize}"
      return
    end
 
    createNewSampleCompletionFile(sample2BatchFileName, sampleCompletionSummaryFile, newSampleSummaryFileName, newColumnName, columnLocation.to_i, keySize.to_i)
  end


#    def self.truncate(text, length=1)
#     return nil if(text.nil?)
#     return text if(text.length < length)
#     words=text.split(//)
#     news = words[0..(length-1)].join('')
#     return news
#    end

    def self.truncate(text, length=1)
     return nil if(text.nil?)
     return text if(text.length < length)
     return text[0,length]
    end


#    def self.truncate(text, length, start=0)
#     return nil if(text.nil?)
#     return text if(text.length < length)
#     return text[start,length]
#    end

   
    def self.createNewSampleCompletionFile(sample2BatchFileName, sampleCompletionSummaryFile, newSampleSummaryFileName, newColumnName, location, keySize)
    foundfileWriter = BRL::Util::TextWriter.new(newSampleSummaryFileName)
    sample2batchHash = TableToHashCreator.loadTwoColumnFile(sample2BatchFileName)
    reader = BRL::Util::TextReader.new(sampleCompletionSummaryFile)


    lineCounter = 1
    lineHeader = nil
    firstLine = false
    line = nil
    begin
      reader.each { |line|
        errofLevel = 0
        if(line !~ /\S/ or line =~ /^\s*[\[#]/)
          if(!firstLine)
            lineHeader = line.chomp.split(/\t/)
            firstColumn = lineHeader.shift
            lineCounter = lineCounter + 1
            firstLine = true;
            foundfileWriter.print "#{firstColumn}\t#{newColumnName}\t"
            foundfileWriter.puts lineHeader.join("\t")
          end
          next
        end
        
        lineArray = line.chomp.split(/\t/)
        firstColumn = lineArray.shift
        useAsKey = truncate(firstColumn, keySize)
        batch = sample2batchHash[useAsKey.to_sym]
        batch = "unKnown" if(batch.nil?)
        foundfileWriter.print "#{firstColumn}\t#{batch}\t"
        foundfileWriter.puts lineArray.join("\t")
        lineCounter = lineCounter + 1
      }
      reader.close()
      foundfileWriter.close()

    end 
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{lineCounter}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end


end #className


end; end; end #namespace

optsHash = Hash.new {|hh,kk| hh[kk] = 0}
numberOfArgs = ARGV.size
i = 0
while i < numberOfArgs
	key = "''"
	value = "''"
	key = ARGV[i] if( !ARGV[i].nil? )
	value =  ARGV[i + 1]  if( !ARGV[i + 1].nil? )
	optsHash[key] = value
	i += 2
end



optsHash.each {|key, value|

  $stderr.puts "#{key} == #{value}" if(!key.nil?)
  }




#--sample2BatchFileName --sampleCompletionSummaryFile --newSampleSummaryFileName --newColumnName --columnLocation --keySize
BRL::FileFormats::TCGAParsers::AddBatchToSampleSummary.generateNewSampleSummaryFile(optsHash)

