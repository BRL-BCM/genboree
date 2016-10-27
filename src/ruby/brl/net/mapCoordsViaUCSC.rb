#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# VERSION INFO
# ##############################################################################
# $Id$
# $Header: $
# $LastChangedDate$
# $LastChangedDate$
# $Change: $
# $HeadURL$
# $LastChangedRevision$
# $LastChangedBy$
# ##############################################################################

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/net/ucscCoordConverter'
include BRL::Net


$stdout.sync = true 

module BRL ; module FormatMapper

class CoordConverter
	# Constants
	INT_RE = /^(\d+)$/
	CHR_RE = /^(chr\S+)$/
	PROB_RECORD = 'PROBLEM_RECORD => '
	TOO_FEW_COLS = 'TOO FEW COLUMNS'
	MULTI_CHRS = 'COORDS IN COLS MAP TO MULTIPLE CHRS NOW'
	CANT_CONVERT = 'UCSC SAYS CANT CONVERT'
	BAD_CHR = 'BAD CHROMOSOME NAME'
	
	def initialize(optsHash)
	  @t1 = @t2 = Time.now
		@fileName = optsHash['--inputFile']
		unless(File.exist?(@fileName))
			raise IOError, "\n\nERROR: the following file doesn't exist:\n'#{@fileName}'\n\n"
		end
		@srcName = optsHash['--srcName'].strip
		@destName = optsHash['--destName'].strip
		@chrom = optsHash['--chr']
		if(@chrom =~ INT_RE)
			@fixedChrom = false
			@chrom = @chrom.to_i
		elsif(@chrom =~ CHR_RE)
			@fixedChrom = true
		end
		@columns = optsHash['--columnList'].strip.split(',')
		@columns.map! { |xx| xx.to_i }
		@maxIndex = (@columns + (@fixedChrom ? [] : [@chrom])).max
		@t2 = Time.now
		$stderr.puts "TIME: initialize() = #{@t2 - @t1}"
	end
	
	def run()
		convertFile()
	end

	def convertFile()
		# Open file
		reader = BRL::Util::TextReader.new(@fileName)
		# Create converter
		@converter = BRL::Net::UCSCCoordConverter.new(@srcName, @destName)
		# Loop over lines of file
		reader.each { |line|
			# Ignore comments/blanks
			if(line =~ /^\s*$/ or line =~ /^\s*#/)
				puts line
				next
			end
			# Parse into columns
			fields = line.strip.split("\t")
			# Do we have enough columns or is this funky?
			unless(fields.size > @maxIndex)
				$stderr.puts PROB_RECORD + TOO_FEW_COLS + " (#{fields.size}), NEED #{@maxIndex+1}: " + fields.join("\t")
				next
			end
			# Convert record
			recConvertedOk = convertRecord(fields)
			# Output record
			puts fields.join("\t") if(recConvertedOk)
		}
		# Close converter
		begin
		  @t1 = Time.now
			converter.finish()
			@t2 = Time.now
			$stderr.puts "TIME: coverter.finish() = #{@t2-@t1}"
		rescue
		end
		# Close file
		reader.close()
		return		
	end
	
	def convertRecord(fields)
		# Determine chr to use
		chrom = @fixedChrom ? @chrom : fields[@chrom]
		# Convert each coordinate in the record
		recConvertedOk = true
		@columns.each { |column|
			begin
				result = @converter.convertCoord(chrom, fields[column].to_i)
			rescue UCSCParseError => err
				$stderr.puts err.message
				$stderr.puts err.backtrace
				$stderr.puts PROB_RECORD + PARSE_ERR + " (col: #{column}) Got ParseError for this record: " + fields.join("\t")
				$stderr.puts "\n\nHTML FROM UCSC:\n\n#{@converter.body}\n\n"
				$stderr.puts "(SKIPPING...)"
				recConvertedOk = false
			else
				case result
					when BRL::Net::UCSCBadChrResponse
						$stderr.puts PROB_RECORD + BAD_CHR + " The chromosome '#{chrom}' is unknown to UCSC: " + fields.join("\t")
						$stderr.puts "\n\nHTML FROM UCSC:\n\n#{@converter.body}\n\n"
						recConvertedOk = false
						break
					when BRL::Net::UCSCCantConvertResponse
						$stderr.puts PROB_RECORD + CANT_CONVERT + " (col: #{column}) UCSC says it may have too many Ns, may have moved, or be duplicated in the newer draft: " + fields.join("\t")
						$stderr.puts "\n\nHTML FROM UCSC:\n\n#{@converter.body}\n\n"
						recConvertedOk = false
						break
					when BRL::Net::UCSCOkResponse
						fields[column] = result.value
					when BRL::Net::UCSCNewChrResponse
						fields[column] = result.value
						fields[@chrom] = result.chrom if(!@fixedChrom)
					else
						raise ScriptError, "\n\nERROR: unknown result returned from covertCoord:\n'#{result.inspect}'\n\nHTML FROM UCSC:\n\n#{@converter.body}\n\n"
				end
			end
		}
		return recConvertedOk
	end	
	
	# Process arguments
	def CoordConverter.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--inputFile', '-i', GetoptLong::REQUIRED_ARGUMENT],
									['--srcName', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--destName', '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--chr', '-c', GetoptLong::REQUIRED_ARGUMENT],
									['--columnList', '-k', GetoptLong::REQUIRED_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		$stderr.puts "COMMAND ARGS:"
		optsHash.each { |key, val|
			$stderr.puts "  #{key}\t#{val}"
		}
		BRL::FormatMapper::CoordConverter.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end
	
	def CoordConverter.usage(msg='')
		unless(msg.empty?)
				puts "\n#{msg}\n"
			end
      puts "

  PROGRAM DESCRIPTION:
    Using the UCSC web service, processes a tab-delimited file and maps
    coordinates from one genome draft to another. You are expected to use the
    same draft names as the website, although standard abbreviations are
    understood (eg hg15, hg16).
    
    You specify which columns have coordinates you want converted in the file
    via a comma-separated list of number provided to the --columnList (-k)
    option.
    
    You specific which column in the file contains the chromosome name (in the
    form of 'chr7', 'chr12', etc) OR if all the coordinates are from the same
    chromosomes you can specific the chromosome string directly.
    
    -> Column counting begins at 0.
    -> Output is on STDOUT.
    -> Error, including Flagged records which could not be converted, is on
       STDERR (you may wish to egrep this for: '^PROBLEM_RECORD=>' to get all
       the records which could not be converted)
    -> Comment lines: any line in your file with '#' as the first
       non-whitespace is not coverted, just output as-is.
      
    COMMAND LINE ARGUMENTS:
      --inputFile   |  -i  => Tab-delimited file with coordinates to convert.
      --srcName     |  -s  => Quoted string specifying the original draft name.
      --destName    |  -d  => Quoted string specifying the new draft name.
      --chr         |  -c  => Either an integer which is the column index which
                              contains the chromosome name OR a string of the
                              form 'chrV' where V is the chromosome number
                              which will be used for converting all records.
      --columnList  |  -k  => Comma-separated list of integers which are the
                              columns in each record with coordinates to convert.
      --help        |  -h  => Shows this help info and exits.

    EXAMPLE:
      mapCoordsViaUCSC.rb -i myFile.txt -s 'Nov. 2002' -d 'hg16' -c 2 -k 3,5
      OR
      mapCoordsViaUCSC.rb -i myFile.txt -s 'hg13' -d 'hg16' -c chr13 -k 3
      
	";
			exit(2)
	end
end

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::CoordConverter::processArguments()
extracter = BRL::FormatMapper::CoordConverter.new(optsHash)
extracter.run()
exit(0)
