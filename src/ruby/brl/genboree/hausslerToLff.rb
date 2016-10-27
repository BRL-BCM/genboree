#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
	Converts PASH text output to 2 LFF files

Author: Andrew R Jackson <andrewj@bcm.tmc.edu>
        Alan Harris <rharris1@bcm.tmc.edu>
Date  : March 13, 2003
=end
# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable'		# for PropTable class
# ##############################################################################
# Turn on extra warnings and such
$VERBOSE = true

module BRL ; module PASH
	class PashToLff
		# Required properties
		PROP_KEYS = 	%w{
											param.class
											param.type
											param.minScore
											genome1.name.buildNumber
											genome2.name.buildNumber
											genome1.name.prefix
											genome2.name.prefix
											genome1.name.buildPrefix
											genome2.name.buildPrefix
											genome1.subtype.buildNumber
											genome2.subtype.buildNumber
											genome1.subtype.prefix
											genome2.subtype.prefix
											genome1.subtype.buildPrefix
											genome2.subtype.buildPrefix
											genome1.chrIDRegExp
											genome2.chrIDRegExp
											genome1.ignore.chrIDRegExp
											genome2.ignore.chrIDRegExp
											output.Genome1Name
											output.Genome2Name
											output.outputDir
										};

		GENOME1_NAME, GENOME1_START, GENOME1_END,GENOME2_NAME, SCORE, STRAND, GENOME2_START, GENOME2_END =
			0,1,2,3,4,5,6,7
		FIRST_GENOME, SECOND_GENOME = 0,1
		SEP = "\t"
		NAME, SUBTYPE = 0,1

		# Static strings to put in LFF file (same for all LFF records)
		attr_accessor :className, :type
		attr_accessor :genome2ID, :nameForward, :genome2SubType
		attr_accessor :genome1ID, :nameReverse, :genome1SubType

		############################################################################
    # * *Function*:
    # * *Usage*   : <tt>    </tt>
    # * *Args*    :
    #   - [++]
    # * *Returns* :
    #   - [++]
    # * *Throws*  :
    #   - [+none+]
    ############################################################################
		def initialize(optsHash)
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# Verify the proptable contains what we need
			@propTable.verify(PROP_KEYS)
			setParameters()
			@pashFileName = optsHash['-f']
		end

		############################################################################
    # * *Function*:
    # * *Usage*   : <tt>    </tt>
    # * *Args*    :
    #   - [++]
    # * *Returns* :
    #   - [++]
    # * *Throws*  :
    #   - [+none+]
    ############################################################################
		def setParameters
			@className = @propTable['param.class']
			@type = @propTable['param.type']
			@outDir = @propTable['output.outputDir']
			Dir.safeMkdir(@outDir)

			@genome1BuildNumber     = [ @propTable['genome1.name.buildNumber'], @propTable['genome1.subtype.buildNumber'] ]
			@genome2BuildNumber    	= [ @propTable['genome2.name.buildNumber'], @propTable['genome2.subtype.buildNumber'] ]
			@genome1Prefix          = [ @propTable['genome1.name.prefix'],      @propTable['genome1.subtype.prefix']      ]
			@genome2Prefix          = [ @propTable['genome2.name.prefix'],      @propTable['genome2.subtype.prefix']      ]
			@genome1BuildPrefix     = [ @propTable['genome1.name.buildPrefix'], @propTable['genome1.subtype.buildPrefix'] ]
			@genome2BuildPrefix     = [ @propTable['genome2.name.buildPrefix'], @propTable['genome2.subtype.buildPrefix'] ]

			@genome1ChrIDRegExpStr  = @propTable['genome1.chrIDRegExp']
			@genome1ChrRE = Regexp.compile( /#{@genome1ChrIDRegExpStr}/ )
			@genome2ChrIDRegExpStr  = @propTable['genome2.chrIDRegExp']
			@genome2ChrRE = Regexp.compile( /#{@genome2ChrIDRegExpStr}/ )
			@genome1IgnoreChrREStr = @propTable['genome1.ignore.chrIDRegExp']
			@genome1IgnoreChrRE = Regexp.compile( /#{@genome1IgnoreChrREStr}/ ) unless(@genome1IgnoreChrREStr.nil? or @genome1IgnoreChrREStr.empty?)
			@genome2IgnoreChrREStr = @propTable['genome2.ignore.chrIDRegExp']
			@genome2IgnoreChrRE = Regexp.compile( /#{@genome2IgnoreChrREStr}/ ) unless(@genome2IgnoreChrREStr.nil? or @genome2IgnoreChrREStr.empty?)

			@genome1Name            = @propTable['output.Genome1Name']
			@genome2Name            = @propTable['output.Genome2Name']
			@minScore               = @propTable['param.minScore'].to_i
			@genome1BuildCode = [ "#{@genome1BuildPrefix[NAME]}#{@genome1BuildNumber[NAME]}", "#{@genome1BuildPrefix[SUBTYPE]}#{@genome1BuildNumber[SUBTYPE]}" ]
			@genome2BuildCode = [ "#{@genome2BuildPrefix[NAME]}#{@genome2BuildNumber[NAME]}", "#{@genome2BuildPrefix[SUBTYPE]}#{@genome2BuildNumber[SUBTYPE]}" ]
		end

		############################################################################
    # * *Function*: Converts the pash file to 2 lff files, one using each genome as
    #   the reference sequence.
    # * *Usage*   : <tt>  converter.convertPashFile()  </tt>
    # * *Args*    :
    #   - [+pashFileName+] Optional pash file name. Otherwise uses -f switch value. Default is nil.
    # * *Returns* :
    #   - [+none+]
    ############################################################################
		def convertPashFile(pashFileName=nil)
			unless(pashFileName.nil?) then @pashFileName = pashFileName ; end

			file = File.basename(@pashFileName)

			if (FileTest.exists?(@pashFileName))
				reader = BRL::Util::TextReader.new(@pashFileName)
			else
				raise "\nERROR: File #{@pashFileName} does not exist.\n"
			end

			forwardWriter = BRL::Util::TextWriter.new("#{@outDir}/#{file}.#{@genome1Name}.lff",false)
			reverseWriter = BRL::Util::TextWriter.new("#{@outDir}/#{file}.#{@genome2Name}.lff",false)

			# Hash for name
			@comparisonForwardHash = Hash.new
			@comparisonReverseHash = Hash.new

			lineCount = 0
			inputLines = reader.readlines()
			reader.close() unless(reader.nil? or reader.closed?)
			forwardRecords = Array.new(inputLines.size)
			reverseRecords = Array.new(inputLines.size)

			inputLines.each {
				|line|
				lineCount += 1
				next if(line =~ /^\s*#/ or line =~ /^\s*$/)
				arrSplit = line.split(' ')
				if(arrSplit.length == 8)
					# Apply any filters
					next unless(checkFilters(arrSplit))
					forwardRecord = Array.new(13)
					reverseRecord = Array.new(13)

					# Build the name of the forward 'query' and reverse 'query'
					buildQueryNames(arrSplit, FIRST_GENOME)
					buildQueryNames(arrSplit, SECOND_GENOME)

					# Create Forward Record - Ref is array 0-2 Target is array 3-5
					forwardWriter.print(@className, SEP,@nameForward, SEP,@type, SEP,@genome2SubType, SEP,@genome1SubType, SEP, arrSplit[GENOME1_START], SEP, arrSplit[GENOME1_END], SEP, arrSplit[STRAND], SEP,'.', SEP, arrSplit[SCORE], SEP, arrSplit[GENOME2_START], SEP, arrSplit[GENOME2_END],"\n")

					# Create Reverse Record - Ref is array 3-5 Target is array 0-2
					reverseWriter.print(@className, SEP,@nameReverse, SEP,@type, SEP,@genome1SubType, SEP,@genome2SubType, SEP,arrSplit[GENOME2_START], SEP,arrSplit[GENOME2_END], SEP,arrSplit[STRAND], SEP,'.', SEP,arrSplit[SCORE], SEP,arrSplit[GENOME1_START], SEP,arrSplit[GENOME1_END], "\n")
				else
					raise "\nERROR: Incorrect number of columns in PASH file at line #{lineCount}\n"
				end # if(arrSplit.length==8)
			} # reader.each {

			forwardWriter.close() unless(forwardWriter.nil? or forwardWriter.closed?)
			reverseWriter.close() unless(reverseWriter.nil? or reverseWriter.closed?)
		end # def PashFile

		def checkFilters(fields)
			return false if(fields[SCORE].to_i < @minScore)
			unless(@genome1IgnoreChrREStr.nil? or @genome1IgnoreChrREStr.empty?)
				return false unless( (fields[GENOME1_NAME] =~ @genome1IgnoreChrRE).nil?)
			end
			unless(@genome2IgnoreChrREStr.nil? or @genome2IgnoreChrREStr.empty?)
				return false unless( (fields[GENOME2_NAME] =~ @genome2IgnoreChrRE).nil?)
			end
			return true
		end

		########################################################################
    # * *Function*: Makes proper strings for sequence names to put in LFF files.
    # * *Usage*   : <tt>  seqID, chrName, subType = buildQueryNames(regExpStr, pashName, hitVersionNum)  </tt>
    # * *Args*    :
    #   - +regExpStr+  ->  A string that is a regular expression which will pull the seq ID out of pashName
    #   - +pashName+   ->  The name of the sequence from the pash file
    #   - +hitVersionNum+  ->  The count number for the query hitting the target
    # * *Returns* : Array:
    #   - [ +seqID+,   -> The isolated sequence ID
    #   - +lffName+,   -> The name used in the lff file
    #   - +subType+ ]  -> An appropriate subtype string
    # * *Throws* :
    #   - +none+
    ########################################################################
		def buildQueryNames(arrSplit, whichGenome)
			if(whichGenome == FIRST_GENOME)
				pashName = arrSplit[GENOME2_NAME]
			else
				pashName = arrSplit[GENOME1_NAME]
			end

			if(whichGenome == FIRST_GENOME)
				pashName =~ @genome1ChrRE
				raise("\nERROR: bad regular expression '#{@genome1ChrIDRegExpStr}' provided by user via genomeX.chrIDRegExp property. Must have a sub-expression that matches the chromosome ID.\n") if($1.nil?)
				@genome2ID = $1
				@genome2SubType = "#{@genome2Prefix[SUBTYPE]}#{@genome2ID}#{@genome2BuildCode[SUBTYPE]}"
				unverQuery = "#{@genome2Prefix[NAME]}#{@genome2ID}#{@genome2BuildCode[NAME]}"
				if(@comparisonForwardHash.key?(unverQuery))
					@comparisonForwardHash[unverQuery] += 1
				else
					@comparisonForwardHash[unverQuery] = 1
				end
				@nameForward = "#{unverQuery}.#{@comparisonForwardHash[unverQuery]}"
			else #if(whichGenome == SECOND_GENOME)
				pashName =~ @genome2ChrRE
				raise("\nERROR: bad regular expression '#{@genome2ChrIDRegExpStr}' provided by user via genomeX.chrIDRegExp property. Must have a sub-expression that matches the chromosome ID.\n") if($1.nil?)
				@genome1ID = $1
				@genome1SubType = "#{@genome1Prefix[SUBTYPE]}#{@genome1ID}#{@genome1BuildCode[SUBTYPE]}"
				unverQuery = "#{@genome1Prefix[NAME]}#{@genome1ID}#{@genome1BuildCode[NAME]}"
				if(@comparisonReverseHash.key?(unverQuery))
					@comparisonReverseHash[unverQuery] += 1
				else
					@comparisonReverseHash[unverQuery] = 1
				end
				@nameReverse = "#{unverQuery}.#{@comparisonReverseHash[unverQuery]}"
			end
			return
		end

		############################################################################
		# * *Function*: Processes all the command-line options and dishes them back as a hash
		# * *Usage*   : <tt>  optsHash = BRL::PASH::PashToLff.processArguments()  </tt>
		# * *Args*    :
		#   - [+none+]
		# * *Returns* :
		#   - [+Hash+]
		# * *Throws*  :
		#   - [+none+]
		############################################################################
		def PashToLff.processArguments
			progOpts =
				GetoptLong.new(
					['-f', GetoptLong::REQUIRED_ARGUMENT],
					['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
					['--help', '-h', GetoptLong::NO_ARGUMENT]
				)

			optsHash = progOpts.to_hash
			PashToLff.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  ############################################################################
	  # * *Function*: Displays some basic usage info on STDOUT
	  # * *Usage*   : <tt>  BRL::PASH::PashToLff.usage("WARNING: insufficient info provided")  </tt>
	  # * *Args*    :
	  #   - [+String+] Optional message string to output before the usage info.
	  # * *Returns* :
	  #   - [+none+]
	  # * *Throws*  :
	  #   - [+none+]
	  ############################################################################
		def PashToLff.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:
      Converts Pash output to LFF, using the settings in a properties file.
      Creates two files...one using the first genome as the refSeq, other using the
      second genome as the refSeq.

    COMMAND LINE ARGUMENTS:
      -f    => Pash output file to convert.
      -p    => Properties file to use for conversion parameters, etc.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    pashToLff.rb  -f pash.out.txt -p humanVsMouse.properties

		";
			exit(2);
		end # def PashToLff.usage(msg='')

	end # PashToLff
end ; end # module BRL; module PASH

# ##############################################################################
# MAIN
# ##############################################################################
# process command line options
optsHash = BRL::PASH::PashToLff.processArguments()
converter = BRL::PASH::PashToLff.new(optsHash)
converter.convertPashFile()

exit(0);

