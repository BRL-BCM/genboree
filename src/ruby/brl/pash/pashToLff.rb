#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# Author: Andrew R Jackson (andrewj@bcm.tmc.edu)
# Date: 3/31/2004 4:38PM
# Purpose:
# Converts the Pash output format to LFF, which is used by Genboree, the
# lffMerger, and other tools. Two LFF files will be created, using both
# 'genomes' (or both sequences) as the so-called LFF Reference Sequence.

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable'		# for PropTable class
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module PASH
	class PashToLff
		GENOME1_NAME, GENOME1_START, GENOME1_END,GENOME2_NAME, GENOME2_START, GENOME2_END, STRAND, SCORE, BIT_SCR, ADPT_SCR = 0,1,2,3,4,5,6,7,8,9
		FIRST_GENOME, SECOND_GENOME = 0,1
		SEP = "\t"
		NAME, SUBTYPE = 0,1
		PROP_KEYS = 	%w{
											param.class
											param.type
											input.minScore
											genome1.name.buildNumber
											genome2.name.buildNumber
											genome1.name.prefix
											genome2.name.prefix
											genome1.name.buildPrefix
											genome2.name.buildPrefix
											genome1.subtype.doIncludeID
											genome2.subtype.doIncludeID
											genome1.subtype.buildNumber
											genome2.subtype.buildNumber
											genome1.subtype.prefix
											genome2.subtype.prefix
											genome1.subtype.buildPrefix
											genome2.subtype.buildPrefix
											input.genome1.chrIDRegExp
											input.genome2.chrIDRegExp
											output.Genome1Name
											output.Genome2Name
											output.outputDir
										};

		# ACCESSORS
		attr_accessor :className, :type
		attr_accessor :genome2ID, :nameForward, :genome2SubType
		attr_accessor :genome1ID, :nameReverse, :genome1SubType

		# METHODS

    # * *Function*: Creates a new PashToLff instance.
		# * *Usage*   : <tt>  converter = BRL::PASH::PashToLff.new(optionsHash)  </tt>
		# * *Args*    :
		#   - +optionsHash+  ->  A hash of the command line options obtained from
		#     BRL's GetoptLong#to_hash function. Minmally requires
		#     '-p' and '-f' keys for properties file name and pash
		#     file name be in there.
		# * *Returns* :
		#   - +PashToLff+  -> New object instance .
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# If options supplied on command line instead, use them rather than those in propfile
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				unless(optsHash[argPropName].nil?)
					@propTable[propName] = optsHash[argPropName]
				end
			}
			@propTable.verify(PROP_KEYS)
			setParameters()
			@pashFileName = optsHash['-f']
		end

    # * *Function*: Processes program parameters and sets up internal representations of
    #   the parameters.
    # * *Usage*   : <tt>  pashToLffObj.setParameters()  </tt>
    # * *Args*    :
    #   - +none+
    # * *Returns* :
    #   - +none+
    # * *Throws*  :
    #   - +none+
		# --------------------------------------------------------------------------
		def setParameters()
			@className = @propTable['param.class']
			@type = @propTable['param.type']
			@outDir = @propTable['output.outputDir']
			Dir.safeMkdir(@outDir)
			@genome1DoIncludeID			= (@propTable['genome1.subtype.doIncludeID'].to_i == 0) ? false : true
			@genome2DoIncludeID			= (@propTable['genome2.subtype.doIncludeID'].to_i == 0) ? false : true
			@genome1BuildNumber     = [ @propTable['genome1.name.buildNumber'], @propTable['genome1.subtype.buildNumber'] ]
			@genome2BuildNumber    	= [ @propTable['genome2.name.buildNumber'], @propTable['genome2.subtype.buildNumber'] ]
			@genome1Prefix          = [ @propTable['genome1.name.prefix'],      @propTable['genome1.subtype.prefix']      ]
			@genome2Prefix          = [ @propTable['genome2.name.prefix'],      @propTable['genome2.subtype.prefix']      ]
			@genome1BuildPrefix     = [ @propTable['genome1.name.buildPrefix'], @propTable['genome1.subtype.buildPrefix'] ]
			@genome2BuildPrefix     = [ @propTable['genome2.name.buildPrefix'], @propTable['genome2.subtype.buildPrefix'] ]
			@genome1ChrIDRegExpStr  = @propTable['input.genome1.chrIDRegExp']
			@genome1ChrRE = Regexp.compile( /#{@genome1ChrIDRegExpStr}/ )
			@genome2ChrIDRegExpStr  = @propTable['input.genome2.chrIDRegExp']
			@genome2ChrRE = Regexp.compile( /#{@genome2ChrIDRegExpStr}/ )
			@genome1Name            = @propTable['output.Genome1Name']
			@genome2Name            = @propTable['output.Genome2Name']
			@minScore               = @propTable['input.minScore'].to_i
			@genome1BuildCode = [ "#{@genome1BuildPrefix[NAME]}#{@genome1BuildNumber[NAME]}", "#{@genome1BuildPrefix[SUBTYPE]}#{@genome1BuildNumber[SUBTYPE]}" ]
			@genome2BuildCode = [ "#{@genome2BuildPrefix[NAME]}#{@genome2BuildNumber[NAME]}", "#{@genome2BuildPrefix[SUBTYPE]}#{@genome2BuildNumber[SUBTYPE]}" ]
			return
		end

    # * *Function*: Converts the pash file to 2 lff files, one using each genome as
    #   the reference sequence.
    # * *Usage*   : <tt>  pashToLffObj.convertPashFile()  </tt>
    # * *Args*    :
    #   - +pashFileName+ Optional pash file name. Otherwise uses -f switch value.
    #     Default is nil.
    # * *Returns* :
    #   - +StandardError+ -> If the pash file doesn't exist or is not formatted correctly.
		# --------------------------------------------------------------------------
		def convertPashFile(pashFileName=nil)
			unless(pashFileName.nil?) then @pashFileName = pashFileName ; end
			file = File.basename(@pashFileName)
			if (FileTest.exists?(@pashFileName))
				reader = BRL::Util::TextReader.new(@pashFileName)
			else
				raise "\nERROR: File #{@pashFileName} does not exist.\n"
			end
			forwardWriter = BRL::Util::TextWriter.new("#{@outDir}/#{file}.#{@genome1Name}.lff")
			reverseWriter = BRL::Util::TextWriter.new("#{@outDir}/#{file}.#{@genome2Name}.lff")
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
				arrSplit = line.split(' ')
				if(arrSplit.length >= 8)
					# Apply any filters
					next unless(checkFilters(arrSplit))
					forwardRecord = Array.new(13)
					reverseRecord = Array.new(13)
					# Build the name of the forward 'query' and reverse 'query'
					buildQueryNames(arrSplit, FIRST_GENOME)
					buildQueryNames(arrSplit, SECOND_GENOME)
  			 if(arrSplit.length >= 9)
  			   bitScore = arrSplit[8] 
  			   bitScrStr = " bitScore=#{bitScore}; "
  			 end
  			 if(arrSplit.length >= 10)
  			  adptScore = arrSplit[9]
  			  matchingBasesScore = arrSplit[SCORE]
  			  mbsStr = " matchingBasesScore=#{matchingBasesScore}; "
				 end
				  # Create Forward Record - Ref is array 0-2 Target is array 3-5
					forwardWriter.print(@className, SEP,@nameForward, SEP,@type, SEP,@genome2SubType, SEP,@genome1SubType, SEP,arrSplit[GENOME1_START], SEP,arrSplit[GENOME1_END], SEP,arrSplit[STRAND], SEP,'.', SEP, (arrSplit.length >= 10 ? adptScore : arrSplit[SCORE]), SEP,arrSplit[GENOME2_START], SEP,arrSplit[GENOME2_END])
					forwardWriter.print(SEP, bitScrStr)
					forwardWriter.print(mbsStr) if(arrSplit.length >= 10)
					forwardWriter.print("\n")
					# Create Reverse Record - Ref is array 3-5 Target is array 0-2
					reverseWriter.print(@className, SEP,@nameReverse, SEP,@type, SEP,@genome1SubType, SEP,@genome2SubType, SEP,arrSplit[GENOME2_START], SEP,arrSplit[GENOME2_END], SEP,arrSplit[STRAND], SEP,'.', SEP,(arrSplit.length >= 10 ? adptScore : arrSplit[SCORE]), SEP,arrSplit[GENOME1_START], SEP,arrSplit[GENOME1_END])
					reverseWriter.print(SEP, bitScrStr)
					reverseWriter.print(mbsStr) if(arrSplit.length >= 10)
					reverseWriter.print("\n")
				else
					raise "\nERROR: Incorrect number of columns in PASH file at line #{lineCount}\n"
				end # if(arrSplit.length==8)
			}

			forwardWriter.close() unless(forwardWriter.nil? or forwardWriter.closed?)
			reverseWriter.close() unless(reverseWriter.nil? or reverseWriter.closed?)
			return
		end

		# * *Function*: Checks that the pash record passes any filters. Current just
		#   checks for minimum-score.
		# * *Usage*   : <tt>  pashToLffObj.checkFilters(pashRecord)  </tt>
		# * *Args*    :
		#   - +pashRecord+  ->  An array of the fields of the pash record.
		# * *Returns* :
		#   - +true+  ->  If record passes all filters.
		#   - +false+ ->  If record fails 1+ filters.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def checkFilters(fields)
			return (fields[SCORE].to_i >= @minScore) ? true : false
		end

    # * *Function*: Makes proper strings for sequence names to put in LFF files.
    # * *Usage*   : <tt>  seqID, chrName, subType = buildQueryNames(pashRecord, whichGenome)  </tt>
    # * *Args*    :
    #   - +pashRecord+    ->  An array of the fields of the pash record.
    #   - +whichGenome+   ->  BRL::PASH::FIRST_GENOME or BRL::PASH::SECOND_GENOME.
    # * *Returns* :
    #   - +none+
    # * *Throws* :
    #   - +StandardError+ -> If the regular expressions provided by the user don't
    #     extract what they are supposed to.
		# --------------------------------------------------------------------------
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
				@genome2SubType = "#{@genome2Prefix[SUBTYPE]}#{@genome2DoIncludeID ? @genome2ID : ''}#{@genome2BuildCode[SUBTYPE]}"
				unverQuery = "#{@genome2Prefix[NAME]}#{@genome2ID}#{@genome2BuildCode[NAME]}"
				if(@comparisonForwardHash.key?(unverQuery))
					@comparisonForwardHash[unverQuery] += 1
				else
					@comparisonForwardHash[unverQuery] = 1
				end
				@nameForward = "#{unverQuery}.#{@comparisonForwardHash[unverQuery]}"
			else # if(whichGenome == SECOND_GENOME)
				pashName =~ @genome2ChrRE
				raise("\nERROR: bad regular expression '#{@genome2ChrIDRegExpStr}' provided by user via genomeX.chrIDRegExp property. Must have a sub-expression that matches the chromosome ID.\n") if($1.nil?)
				@genome1ID = $1
				@genome1SubType = "#{@genome1Prefix[SUBTYPE]}#{@genome1DoIncludeID ? @genome1ID : ''}#{@genome1BuildCode[SUBTYPE]}"
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

		# * *Function*: Processes all the command-line options and dishes them back as a hash.
		# * *Usage*   : <tt>  optsHash = BRL::PASH::PashToLff.processArguments()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +Hash+  -> Hash of the command-line args with arg names as keys associated with
		#     values. Values can be nil empty string in user gave '' or even nil if user didn't provide
		#     an optional argument.
		# * *Throws*  :
		#   - +none+
		# --------------------------------------------------------------------------
		def PashToLff.processArguments()
			# We want to add all the prop_keys as potential command line options
			optsArray =	[	['-f', GetoptLong::REQUIRED_ARGUMENT],
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			PashToLff.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT.
	  # * *Usage*   : <tt>  BRL::PASH::PashToLff.usage("WARNING: insufficient info provided")  </tt>
	  # * *Args*    :
	  #   - +String+ ->  Optional message string to output before the usage info.
	  # * *Returns* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def PashToLff.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Converts Pash output to LFF, using the settings in a properties file.
  Creates two files...one using the first genome as the refSeq, other using
  the second genome as the refSeq.

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
# Process command line options
optsHash = BRL::PASH::PashToLff.processArguments()
# Instantiate converter using program arguments
converter = BRL::PASH::PashToLff.new(optsHash)
# Convert
converter.convertPashFile()

exit(0);

