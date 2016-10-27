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
	class Pash2Lff
		QUERY_NAME, QUERY_START, QUERY_END, TARGET_NAME, TARGET_START, TARGET_END, STRAND, SCORE, BIT_SCR, ADPT_SCR = 0,1,2,3,4,5,6,7,8,9
		QUERY, TARGET = 0,1
		NAME, SUBTYPE = 0,1
		PROP_KEYS = 	%w{
											input.minScore
											input.query.baseNameRE
											input.target.baseNameRE
											output.class
											output.type
											output.subtype
											output.queryFile
											output.targetFile
										}

		# ACCESSORS
		attr_accessor :className, :type
		attr_accessor :targetID, :nameForward
		attr_accessor :queryID, :nameReverse

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
		  @optsHash = optsHash
		  # Read required properties file
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# If options supplied on command line instead, use them rather than those in propfile
			PROP_KEYS.each { |propName|
			  argPropName = "--#{propName}"
				unless(optsHash[argPropName].nil?)
					@propTable[propName] = optsHash[argPropName]
				end
			}
			# Make sure we have something set for each of the property-keys (either from
			# properties file or on the command line)
			@propTable.verify(PROP_KEYS)
			# Configure class using these properties
			setParameters()
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
		  @pashFiles = @optsHash['--pashFiles'].split(',')
			@className = @propTable['output.class']
			@type = @propTable['output.type']
			@subtype = @propTable['output.subtype']
			@queryOut = @propTable['output.queryFile']
			@targetOut = @propTable['output.targetFile']
			@queryChrRE = Regexp.compile( /#{@propTable['input.query.baseNameRE']}/ )
			@targetChrRE = Regexp.compile( /#{@propTable['input.target.baseNameRE']}/ )
			@minScore = @propTable['input.minScore'].to_i
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
		def convertPashFiles(pashFiles=@pashFiles)
		  return if(pashFiles.nil? or pashFiles.empty?)
		  @comparisonForwardHash = Hash.new
			@comparisonReverseHash = Hash.new
		  # Create 2 writers for output LFF, one with "query" mapped on the "target"
		  # and one with "target" mapped onto "query".
			forwardWriter = BRL::Util::TextWriter.new(@queryOut)
			reverseWriter = BRL::Util::TextWriter.new(@targetOut)
		  # Process each pash file
		  pashFiles.each { |pashFile|
			  if(FileTest.exists?(pashFile))
				  reader = BRL::Util::TextReader.new(pashFile)
			  else
  				$stderr.puts "\nWARNING: File #{pashFile} does not exist. Skipping...\n"
  				next
	  		end
			  @forwardHash = Hash.new {|hh,kk| hh[kk] = 0}
			  @reverseHash = Hash.new {|hh,kk| hh[kk] = 0}
			  reader.each { |line|
				  arrSplit = line.chomp.split(/\s+/)
				  # Do we have *at least* 8 columns?
				  if(arrSplit.length >= 8)
					  # Apply any filters
					  next unless(checkFilters(arrSplit))
					  # Build the name of the forward 'query' and reverse 'query'
					  buildQueryNames(arrSplit, QUERY)
					  buildQueryNames(arrSplit, TARGET)
					  # Original pash score column: lower bound on number of matching bases
					  mbsAVP = "matchingBasesScore=#{arrSplit[SCORE]}; "
					  # Do we have a bitscore in the pash record?
  			    if(arrSplit.length >= 9)
  			      bitScr = arrSplit[8] 
  			      bitScrAVP = "bitScore=#{bitScr}; "
  			    else
  			      bitScrAVP = ''
  			    end
  			    # Do we have an adaptive score in the pash record?
  			    if(arrSplit.length >= 10)
  			      adptScr = arrSplit[9]
  			      adptScrAVP = "adaptiveHashScore=#{adptScr}; "
  			    else
  			      adptScrAVP = ''
  			    end
  				  # Create Forward Record - Ref is array 0-2 Target is array 3-5
  					forwardWriter.print  "#{@className}\t#{@nameForward}\t#{@type}\t#{@subtype}\t" +
  					                      "#{@targetID}\t#{arrSplit[TARGET_START]}\t#{arrSplit[TARGET_END]}\t" +
  					                      "#{arrSplit[STRAND]}\t.\t" +
  					                      (arrSplit.length >= 10 ? adptScr : arrSplit[SCORE]) + "\t" +
  					                      "#{arrSplit[QUERY_START]}\t#{arrSplit[QUERY_END]}\t" +
  					                      "#{adptScrAVP}#{bitScrAVP}#{mbsAVP}\n"
  					# Create Reverse Record - Ref is array 3-5 Target is array 0-2
  					reverseWriter.print  "#{@className}\t#{@nameReverse}\t#{@type}\t#{@subtype}\t" +
  					                      "#{@queryID}\t#{arrSplit[QUERY_START]}\t#{arrSplit[QUERY_END]}\t" +
  					                      "#{arrSplit[STRAND]}\t.\t" +
  					                      (arrSplit.length >= 10 ? adptScr : arrSplit[SCORE]) + "\t" +
  					                      "#{arrSplit[TARGET_START]}\t#{arrSplit[TARGET_END]}\t" +
  					                      "#{adptScrAVP}#{bitScrAVP}#{mbsAVP}\n"
  				else # < 8 columns
  					raise "\n\nERROR: Incorrect number of columns in PASH file at line #{reader.lineno}\n\n"
  				end # if(arrSplit.length>=8)
			  }
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
			if(whichGenome == QUERY)
			  pashName = arrSplit[QUERY_NAME]
				pashName =~ @queryChrRE
				raise("\nERROR: bad regular expression '#{@queryChrRE.inspect}' provided by user via the input.query.baseNameRE property. Must have a sub-expression that matches the root of the query name (eg jut the chromosome name).\n") if($1.nil?)
				@queryID = $1
  			@forwardHash[@queryID] += 1
				@nameForward = "#{@queryID}.#{@forwardHash[@queryID]}"
			else # whichGenome == TARGET
			  pashName = arrSplit[TARGET_NAME]
				pashName =~ @targetChrRE
				raise("\nERROR: bad regular expression '#{@targetChrRE.inspect}' provided by user via target.query.baseNameRE property. Must have a sub-expression that matches the the root of the query name (eg jut the chromosome name).\n") if($1.nil?)
				@targetID = $1
			  @reverseHash[@targetID] += 1
				@nameReverse = "#{@targetID}.#{@reverseHash[@targetID]}"
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
		def Pash2Lff.processArguments()
			# We want to add all the prop_keys as potential command line options
			optsArray =	[	['--pashFiles', '-f', GetoptLong::REQUIRED_ARGUMENT],
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each { |propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			unless(progOpts.getMissingOptions().empty?)
        Pash2Lff.usage("USAGE ERROR: some required arguments are missing") 
      end
			optsHash = progOpts.to_hash
			Pash2Lff.usage() if(optsHash.empty? or optsHash.key?('--help'));
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
		def Pash2Lff.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Converts Pash output to LFF, using the settings in a properties file. Pash
  output lists regions of the 'query' that are mapped to regions of the 'target'
  followed by various types of scores.
  
  Settings in the property file can be over-ridden on the command line
  by providing the setting as an argument (make sure to escape special
  characters that may be interpretted by the shell; or quote the whole
  value). For example:
     --output.queryFile='./myOtherQueryFile.lff'
  
  Creates two files...one using the query as the refSeq, other using
  the target as the refSeq.

COMMAND LINE ARGUMENTS:
  -f    => Pash output file to convert.
  -p    => Properties file to use for conversion parameters, etc.
  -h    => [optional flag] Output this usage info and exit

USAGE:
  pash2lff.rb  -f pash.out.txt -p humanVsMouse.properties

";
			exit(2);
		end # def Pash2Lff.usage(msg='')
	end # Pash2Lff
end ; end # module BRL; module PASH

# ##############################################################################
# MAIN
# ##############################################################################
# Process command line options
optsHash = BRL::PASH::Pash2Lff.processArguments()
# Instantiate converter using program arguments
converter = BRL::PASH::Pash2Lff.new(optsHash)
# Convert
converter.convertPashFiles()

exit(0);

