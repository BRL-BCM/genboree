#!/usr/bin/env ruby

=begin
  Date  : March 13, 2003
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/logger'

# Turn on extra warnings and such
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module Genboree
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	HEADER_RE = /^\s*\[/
	DOT_RE = /^\.$/
	DIGIT_RE = /^\-?\d+$/
	FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,2,3,16
	NEG_ORDER, POS_ORDER = 0,1
	MAX_NUM_ERRS = 150
	MAX_EMAIL_ERRS = 25
	MAX_EMAIL_SIZE = 30_000

	# For reference: lff fields:
	# classID, tName, typeID, subtype, refName, rStart, rEnd, orientation, phase, scoreField, tStart, tEnd
	CLASSID, TNAME, TYPEID, SUBTYPE, REFNAME, RSTART, REND, STRAND, PHASE, SCORE, TSTART, TEND =
			0,1,2,3,4,5,6,7,8,9,10,11

	#=== *Purpose* :
	#  Simple class representing a closed range ( [first, last] ).
	class FullClosedWindow
		attr_accessor :first, :last

		# * *Function*: Creates instance of BRL::Genboree::FullClosedWindow
		# * *Usage*   : <tt>  closedWinObj = BRL::Genboree::FullClosedWindow(first, last)  </tt>
		# * *Args*    :
		#   - +first+  ->  Start of closed range.
		#   - +last+   ->  End of closed range.
		# * *Returns* :
		#   - +FullClosedWindow+  ->  Object instance.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(first, last)
			@first = first
			@last = last
		end
	end # END: class FullClosedWindow

	#=== *Purpose*
	#    Represents a closed Merged LFF record, with comple sub-component tracking.
	class MergedRecord
		attr_reader :aggregateRecord, :recordsList
		attr_accessor :relativeOrder

		# * *Function*: Instantiates BRL::Genboree::MergedRecord.
		# * *Usage*   : <tt>  recordObj = BRL::Genboree::MergedRecord.new(seedRecord)  </tt>
		# * *Args*    :
		#   - +seedRecord+  ->  Optional array argument containing the fields of the first
		#     LFF record in the merged record. Default is nil.
		# * *Returns* :
		#   - +MergedRecord+  ->  Object instance.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(seedRecord=nil)
			@aggregateRecord = nil
			@recordsList = nil
			@relativeOrder = nil
			reinitialize(seedRecord)
		end

		# * *Function*: Allows reuse of the same BRL::Genboree::MergedRecord object
		#   by clearing out internals and optionally setting up for a new merged record.
		# * *Usage*   : <tt>  mergedRecord.reinitialize(newSeedRecord)  </tt>
		# * *Args*    :
		#   - +newSeedRecord+  ->  Optional array argument containing the fields of the first
		#     LFF record in the new merged record. Default is nil.
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def reinitialize(seedRecord=nil)
			@aggregateRecord = nil
			@relativeOrder = nil
			unless(@recordsList.nil?)
				@recordsList.clear
			else
				@recordsList = [ ]
			end
			if(seedRecord.nil?)
				@aggregateRecord = nil
				@recordsList = [  ]
			else
				@aggregateRecord = seedRecord.dup
				@recordsList << seedRecord.dup
			end
			return
		end

		# * *Function*: Determines the relative order of the given annotations w.r.t.
		#   the current aggregate on the two genomes.
		# * *Usage*   : <tt>  order = calcRelativeOrder(newRecord)  </tt>
		# * *Args*    :
		#   - +record+  ->  An array of LFF fields.
		# * *Returns* :
		#   - <tt>BRL::Genboree::NEG_ORDER</tt>  ->	If reverse, or negative, ordering.
		#   - <tt>BRL::Genboree::POS_ORDER</tt>  ->  If positive, or forward, ordering.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def calcRelativeOrder(record)
			return nil if(@aggregateRecord.nil? or @recordsList.nil? or @recordsList.empty?)
			# On the reference genome, we are always going from 0->end. But on the other
			# genome, we could be going in the positive or negative direction.
			# Check whether this record is on the positive or negative side of the aggregate's
			# coordinates on the 2nd genome.
			return NEG_ORDER if(record[TSTART] < @aggregateRecord[TSTART])
			return POS_ORDER
		end
	end # class MergedRecord

	#=== *Purpose* :
	#   Worker class that performs heuristical merging of LFF records
	#   in a file, according to the heuristic parameters provided by the user.
	#   For efficiency, the methods in this class largely make use of the current
	#   object state, rather than returning values all over the place and making
	#   spaghetti.
	class LFFTransformer
		attr_reader :lffRecords, :sortedRecordIDs, :mergedRecord

		# Required properties
		PROP_KEYS = 	%w{
											program.sizeChecker
											program.merger
											program.noMerger
											program.ruby
											output.outputSuffix
											output.outputDir
											output.mergeClassSuffix
											output.mergeTypeSuffix
											output.nameSuffices
											output.baseUrl
											input.typesToMerge
											input.subtypesToMerge
											input.query.IDRegExp
											param.numIterations
										} ;

		MERGE_RECORD, SKIP_RECORD, STOP_LOOKING = 0,1,2
		NO_FAIL_VECTOR = [ false, nil ]

		# * *Function*: Instantiates BRL::Genboree::LFFTransformer.
		# * *Usage*   : <tt>  mergerObj = BRL::Genboree::LFFTransformer.new(optsHash)  </tt>
		# * *Args*    :
		#   - +optsHash+  ->  A hash of the command line options obtained from
		#     BRL's BRL::Util::GetoptLong#to_hash function. Minmally requires
		#     '-p' and '-f' keys for properties file name and pash
		#     file name be in there.
		# * *Returns* :
		#   - +LFFTransformer+  ->  Object instance.
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
			# Verify the proptable contains what we need
			@propTable.verify(PROP_KEYS)
			if(optsHash.key?('--validRefSeqFile'))
				$stderr.puts "#{Time.now()} TRANSFORMER - Found a RefSeq File. Loading..."
				@doCheckRefSeqs = true
				loadValidRefSeqs(optsHash['--validRefSeqFile'])
				$stderr.puts "#{Time.now()} TRANSFORMER - ...Done loading valid ref seqs."
			else
				$stderr.puts "#{Time.now()} TRANSFORMER - No RefSeq File provided. All RefSeqs are valid."
				@doCheckRefSeqs = false
			end
			setParameters()
			##########################################################################
    	# Set low priority (or at least try to....)
 			##########################################################################
			setLowPriority()
			@lffFileName = optsHash['--lffFile']
			@lffRecords = []
			@errorList = []
			@sortedRecordIDs = []
			@posStrandCount = 0
			@badRefSeqDetected = false
			@currQueryName = nil
			@currRecord = nil
			@seenRecordIDs = {}
			@mergedRecordCounts = {}
			@genome1MergeWindow = nil
			@genome2MergeWindow = nil
			@rawSpanDataRecord = nil
			@newRefSeqs = {}
			Dir.safeMkdir(@outDir)
			@outFile = "#{@outDir}/#{File::basename(@lffFileName)}.merged.lff"
			@writer = BRL::Util::TextWriter.new(@outFile + @outputSuffix)
			@mergedRecord = MergedRecord.new()
			@logger = BRL::Util::Logger.new()
		end # END: def initialize(optsHash)

		def loadValidRefSeqs(fileName)
			@validRefSeqs = {}
			@refSeqFile = fileName
			refReader = BRL::Util::TextReader.new(@refSeqFile)
			lineArray = []
			refReader.each { |line|
				line.strip!
				# Skip blank lines, comment lines, [header] lines
				next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ HEADER_RE)
				fields = line.split("\t")		# record lines are TAB delimited
				# all that should be in the file are lff [reference] records
				# Validate reference_point record
				valid = self.validateRefSeq(fields)
				unless(valid == true) # then it is an array of error messages
					@logger.addNewError("ERROR: Bad Ref Seq Record at line #{refReader.lineno}:", valid)
					next
				else
					@validRefSeqs[fields[0].strip] = fields[2].to_i
				end
			}
			refReader.close()
			return
		end

		def setLowPriority()
			begin
				Process.setpriority(Process::PRIO_USER, 0, 19)
			rescue
			end
			return
		end

		def validateRefSeq(fields)
			retVal = []
			strippedFields = fields.collect{|field| field.strip}
			unless(strippedFields.size == 3)
				retVal << "Not an LFF [reference] record. It only has #{strippedFields.size} but should have 3."
			end
			unless(strippedFields[2] =~ /^\d+$/ and (strippedFields[2].to_i > 0))
				retVal << "3rd Column must be an integer that is the RefSeq length."
			end
			if(retVal.empty?)
				fields = nil
				fields = strippedFields
				return true
			else
				return retVal
			end
		end

    # * *Function*: Processes program parameters and sets up internal representations of
    #   the parameters.
    # * *Usage*   : <tt>  mergerObj.setParameters()  </tt>
    # * *Args*    :
    #   - +none+
    # * *Returns* :
    #   - +none+
    # * *Throws*  :
    #   - +none+
		# --------------------------------------------------------------------------
		def setParameters()
			@queryIDRegExpStr = @propTable['input.query.IDRegExp']
			@queryIDRE = /#{@queryIDRegExpStr}/
			@numIterations = @propTable['param.numIterations'].to_i
			@nameSuffices = @propTable['output.nameSuffices'].map!{|xx| xx.strip! ; xx.gsub('<none>','') }
			@mergeClassSuffix = @propTable['param.mergeClassSuffix'].nil? ? '' : @propTable['param.mergeClassSuffix']
			@mergeTypeSuffix = @propTable['param.mergeTypeSuffix'].nil? ? '' : @propTable['param.mergeTypeSuffix']
			@outputSuffix = @propTable['output.outputSuffix'].nil? ? '' : @propTable['output.outputSuffix']
			@outDir = (@propTable['output.outputDir'].nil? or @propTable['output.outputDir'].empty?) ? '.' : @propTable['output.outputDir']
			types = @propTable['input.typesToMerge']
			if(types == '<all>')
				@mergeAllTypes = true
			else
				@mergeAllTypes = false
			end
			return
		end # END: def setParameters()

		# * *Function*: Sucks in all the LFF records in the file into an 2D array.
		# * *Usage*   : <tt>  merger.readLFFRecords()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +StandardError+ -> If the LFF file doesn't exist.
		# --------------------------------------------------------------------------
		def readLFFRecords() # Only do this once
			if(FileTest.exists?(@lffFileName))
				reader = BRL::Util::TextReader.new(@lffFileName)
			else
				raise "---- File #{@lffFileName} does not exist! ----"
			end
			recordCount = 0
			@lffRecords = []
			@sortedRecordIDs = []
			tooManyErrs = false

			reader.each { |line|
				line.strip!
				next if((line =~ BLANK_RE) or (line =~ COMMENT_RE) or (line =~ HEADER_RE))
				fields = line.split("\t")

				# Is it reference? SKIP
				if(fields.length == 3)
					# Validate reference_point record
 					valid = self.validateRefSeq(fields)
					unless(valid == true) # then it is an array of error messages
						@logger.addNewError("ERROR: Bad Ref Seq Record at line #{refReader.lineno}:", valid)
						next
					else
						unless(@validRefSeqs.key?(fields[0].strip))
							@validRefSeqs[fields[0].strip] = fields[2].to_i
							@newRefSeqs[fields[0].strip] = fields[2].to_i
						end
					end
				# Assembly section? SKIP
				elsif(fields.length == 7)
					# do nothing with assembly info for now
					next
				# Assume Annotation section. PROCESS
				else
					# Validate the LFF annotation
					valid = validateAnnotation(fields)
					unless(valid == true) # then it is an array of error messages
						@logger.addNewError("ERROR: Bad Annotation Record at line #{reader.lineno}:", valid)
						if(@logger.size >= MAX_NUM_ERRS)
							tooManyErrs = true
							break
						else
							next
						end
					end
					fields[SCORE] = fields[SCORE].to_f
					# If we have only 10 fields, make last two '.'
					if(fields.length == 10) then fields[TSTART] = fields[TEND] = '.' end
					# Fix it so that start is < end for everything. Keep "strand" (aka orientation) for
					# the directional relationship.
					fields[RSTART] = fields[RSTART].to_i
					fields[REND] = fields[REND].to_i
					if(fields[RSTART] > fields[REND])
						fields[RSTART], fields[REND]  =  fields[REND], fields[RSTART]
					end
					fields[TSTART] = fields[TSTART].to_i if(fields[TSTART] != '.')
					fields[TEND] = fields[TEND].to_i if(fields[TEND] != '.')
					if((fields[TSTART] != '.') and (fields[TEND] != '.'))
						if(fields[TSTART] > fields[TEND])
							fields[TSTART], fields[TEND]  =  fields[TEND], fields[TSTART]
						end
					end
					@lffRecords[recordCount] = fields
					@sortedRecordIDs[recordCount] = recordCount
					recordCount += 1
				end
			}
			reader.close()
			return tooManyErrs
		end

		def validateAnnotation(fields)
			retVal = []
			strippedFields = fields.collect{|field| field.strip}
			# Is the size right? If not, stop right here.
			unless((strippedFields.size == 10) or (strippedFields.size == 12) or (strippedFields.size == 13) or (strippedFields.size == 14))
				retVal << "This LFF record has #{strippedFields.size} fields."
				retVal << "LFF records are <TAB> delimited and have either 10 or 12 fields."
				retVal << "Enhanced LFF records can have 13 or 14 fields."
				retVal << "Space characters are not tabs."
			else # right number of fields, check them
				# Do we know about this entrypoint? If not, error and skip annotation.
				if(@doCheckRefSeqs)
					if(!@validRefSeqs.key?(strippedFields[4]))
						retVal << "referring to unknown reference sequence entrypoint '#{fields[4]}'"
						@badRefSeqDetected = true
					else # found correct refseq, but is coords ok?
						if(strippedFields[6].to_i > @validRefSeqs[strippedFields[4]])
							retVal << "end of annotation (#{strippedFields[4]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
							retVal << "annotation was truncated."
							strippedFields[6] = @validRefSeqs[strippedFields[4]]
							@badRefSeqDetected = true
						end
						if(strippedFields[5].to_i > @validRefSeqs[strippedFields[4]])
							retVal << "start of annotation (#{strippedFields[4]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
							retVal << "annotation was truncated."
							strippedFields[5] = @validRefSeqs[strippedFields[4]]
							@badRefSeqDetected = true
						end
					end
				end

				# ok, we need to do all these checks
				# Fix score column if it starts with just 'e'...which means 1e, presumably
				if(strippedFields[9] =~ /^e(?:\+|\-)\d+/i) then strippedFields[9] = fields[9] = "1#{strippedFields[9]}" end
				# Fix score column if it is just '.'
				if(strippedFields[9] =~ /^\.$/) then strippedFields[9] = fields[9] = '0' end
				# Check that the name column is not too long.
				if(fields[1].length > 200) then retVal << "the name '#{fields[1]}' is too long." end
				# Check the strand column.
				unless(strippedFields[7] =~ /^[\+\-\.]$/) then retVal << "the strand column contains '#{fields[7]}' and not +, -, or ."	end
				# Check the phase column.
				unless(strippedFields[8] =~ /^[012\.]$/) then retVal << "the phase column contains '#{fields[8]}' and not 0, 1, 2, or ." end
				# Check start coord.
				unless(strippedFields[5].to_s =~ DIGIT_RE and (strippedFields[5].to_i >= 0))
					retVal << "the start column contains '#{fields[5]}' and not a positive integer."
					retVal << "reference sequence coordinates should start at 1."
					retVal << "bases at negative or fractional coordinates are not supported."
				else
					strippedFields[5] = strippedFields[5].to_i
					if(strippedFields[5] == 0)	# Looks to be 0-based, half-open
						strippedFields[5] = 1 		# Now it's 1-based, fully closed
					end
				end
				# Check the end coord.
				unless(strippedFields[6].to_s =~ DIGIT_RE and (strippedFields[6].to_i >= 0))
					retVal << "the end column contains '#{fields[5]}' and not a positive integer."
					retVal << "reference sequence coordinates start at 1."
					retVal << "bases at negative or fractional coordinates are not supported."
				else
					strippedFields[6] = strippedFields[6].to_i
					if(strippedFields[6] == 0)	# Looks to be 0-based, half-open
						strippedFields[6] = 1 		# Now it's 1-based, fully closed
					end
				end
				unless(strippedFields[9] =~ /^\-?\d+(?:\.\d+)?(?:e(?:\+|\-)\d+)?$/i) then
					retVal << "the score column contains '#{fields[9]}' and not an integer or real number or ."
				end
				# Check tstart/tend coords.
				if(fields.length >= 12)
					unless(strippedFields[10] =~ DOT_RE or (strippedFields[10] =~ DIGIT_RE and (strippedFields[10].to_i >= 0)))
						retVal << "the tstart column contains '#{fields[10]}' and not a positive integer or '.'"
						retVal << "sequence coordinates start at 1."
						retVal << "bases at negative or fractional coordinates are not supported."
					else
						strippedFields[10] = strippedFields[10].to_i unless(strippedFields[10] =~ DOT_RE)
						if(strippedFields[10] == 0)	# Looks to be 0-based, half-open
							strippedFields[10] = 1 		# Now it's 1-based, fully closed
						end
					end
					unless(strippedFields[11] =~ DOT_RE or (strippedFields[11] =~ DIGIT_RE and (strippedFields[11].to_i >= 0)))
						retVal << "the tend column contains '#{fields[10]}' and not a positive integer or '.'"
						retVal << "sequence coordinates start at 1."
						retVal << "bases at negative or fractional coordinates are not supported."
					else
						strippedFields[11] = strippedFields[11].to_i unless(strippedFields[11] =~ DOT_RE)
						if(strippedFields[11] == 0)	# Looks to be 0-based, half-open
							strippedFields[11] = 1 		# Now it's 1-based, fully closed
						end
					end
				end
				# Check query name matches ID ok
				unless(strippedFields[1] =~ @queryIDRE)
					retVal << "the base query name can't be determined."
					retVal << "query names should look like <name> or <name>.<ver>"
					retVal << "in latter case, the \".<ver>\" will be stripped off"
				end
				# Check if any fields are empty that shouldn't be.
				anyEmpty = false
				fields.each_with_index { |field, ii|
					if(field.strip =~ BLANK_RE)
						anyEmpty = true unless(ii==12 or ii=13)
						break
					elsif(field.strip =~ DOT_RE and (ii != 8) and (ii != 7))
						fields[ii] = nil
					end
				}
				if(anyEmpty) then retVal <<  "some of the fields are empty and this is not allowed." end
			end
			if(retVal.empty?)	# everything ok
				fields = nil
				fields = strippedFields
				return true
			else
				return retVal
			end
		end

		# * *Function*: Sorts the array of LFF record IDs if @doSort is set. Sorting is
		#   by refSeq name and then by start position. It is not a huge waste of
		#   time to unnecessarily sort already sorted data.
		# * *Usage*   : <tt>  merger.sortLFFRecordIDs()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def sortLFFRecordIDs()
			@sortedRecordIDs.sort! {
				|xx,yy|
				record1 = @lffRecords[xx]
				record2 = @lffRecords[yy]
				compareVal = (@lffRecords[xx][REFNAME] <=> @lffRecords[yy][REFNAME])
				if(compareVal == 0)
					compareVal = (@lffRecords[xx][RSTART] <=> @lffRecords[yy][RSTART])
				end
				compareVal
			}
			return
		end

		def iterativeMerge()
			# Read in indices once
			$stderr.puts("#{Time.now()} TRANSFORMER - loading records")
			tooManyErrs = readLFFRecords()
			$stderr.puts("#{Time.now()} TRANSFORMER - done loading records")
			if(tooManyErrs)
				$stderr.puts("#{Time.now()} TRANSFORMER - too many (#{MAX_NUM_ERRS}+) errors in file. Abandoning merge entirely.")
			else
				# Write out new refseqs, if any
				writeNewRefSeqs()
				@writer.puts "[annotations]"
				sortLFFRecordIDs()
				$stderr.puts("#{Time.now()} TRANSFORMER - number LFF records: #{@sortedRecordIDs.size}  (#{@lffRecords.size})")
				$stderr.puts("#{Time.now()} TRANSFORMER - done sorting records")
				@numIterations.times { |ii|
					transformRecords(ii)
				}
				$stderr.puts "#{Time.now()} TRANSFORMER - done merging record"
				@writer.close()
			end
			# Output logged error messages?
			if(@logger.size <= 0)
				retVal = OK
				puts "Transformation of annotations successful."
			elsif(tooManyErrs) # Too many parse errors to bother processing. Whole file is probably messed up
				retVal = FAILED
				puts "Too many errors (#{MAX_NUM_ERRS}) in the annotation file.\nToo likely the whole file has the same error(s) on each line."
				if(@doCheckRefSeqs and @badRefSeqDetected) # then need to print good ref seqs 1st
					puts makeRefSeqStr()
				end
				puts "No upload attempted. Here is a sample of your formatting errors:\n\n"
				puts @logger.to_s(MAX_EMAIL_ERRS)
			else # Ok, but had some errors
				retVal = OK_WITH_ERRORS
				if(@doCheckRefSeqs and @badRefSeqDetected) # then need to print good ref seqs 1st
					puts makeRefSeqStr()
				end
				puts @logger.to_s(MAX_EMAIL_ERRS)
			end
			return retVal
		end

		def writeNewRefSeqs()
			@writer.puts "[reference_points]"
			@newRefSeqs.keys.each { |refSeqName|
				@writer.puts "#{refSeqName}\tChromosome\t#{@newRefSeqs[refSeqName]}"
			}
			return
		end
		
		def makeRefSeqStr()
			return '' unless(@doCheckRefSeqs)
			refSeqStr =    "\nNOTE: Some invalid/unknown reference sequences (the 'ref' column)\n"
			refSeqStr +=   "      and/or annotations that went beyond the ends of the\n"
			refSeqStr +=   "      reference sequence were found.\n"
			refSeqStr +=   "      Here is a list of valid reference sequences and lengths:\n\n"
			refSeqStr +=   "RefSeq_Name\tLength\n"
			refSeqCount = 0
			@validRefSeqs.keys.sort.each { |refSeq|
				length = @validRefSeqs[refSeq]
				refSeqStr += "#{refSeq}\t#{length}\n"
				refSeqCount += 1
				if(refSeqCount >= 30)
					refSeqStr += "....too many Entry Points (#{@validRefSeqs.size}) to continue listing...."
					break
				end
			}
			refSeqStr += "\n\n"
			return refSeqStr
		end

		# * *Function*: Rather than merge, we will just add the suffixes to the data and not modify it otherwise.
		# * *Usage*   : <tt>  merger.transformRecords()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +StandardError+ -> If the regular expression provided by the user doesn't
		#     correctly extract what it is supposed to.
		# --------------------------------------------------------------------------
		def transformRecords(itNum)
			$stderr.puts("#{Time.now()} TRANSFORMER - (Level ##{itNum}) done setup/config")
			# Go through sorted list of records and transform each one
			for ii in (0...@sortedRecordIDs.size)
				currRecordID = @sortedRecordIDs[ii]
				@currRecord = @lffRecords[currRecordID]
				@mergedRecord.reinitialize(@currRecord)
				# Fix the query name and phase
				@mergedRecord.aggregateRecord[TNAME] = "#{@mergedRecord.aggregateRecord[TNAME]}#{@nameSuffices[itNum]}"
				# Output the "merged record" appropriately
				outputMergedRecord(itNum)
				@currRecord = nil
				@mergedRecord.recordsList.each {
					|record|
					record.clear
					record = nil
				}
			end
			$stderr.puts("#{Time.now()} TRANSFORMER - done merging data")
			return
		end

		# * *Function*: Emit the merged record to the output LFF record appropriately.
		# * *Usage*   : <tt>  merger.outputMergedRecord()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def outputMergedRecord(itNum)
			strToWrite = nil
			# Need to write out each of the old records, with its new group.
			# Don't muck with their data much, if we can help it.
			@mergedRecord.recordsList.each {
				|oldRecord|
				oldRecord[TNAME] = @mergedRecord.aggregateRecord[TNAME]
				oldRecord[CLASSID] << @mergeClassSuffix
				oldRecord[TYPEID] << @mergeTypeSuffix
				# Write out the 'grouped' record
				strToWrite = oldRecord.join("\t")
				@writer.puts(strToWrite)
			}
			return
		end

		# * *Function*: Processes all the command-line options and dishes them back as a hash
		# * *Usage*   : <tt>  optsHash = BRL::PASH::PashToLff.processArguments()  </tt>
		# * *Args*  :
		#   - +none+
		# * *Return* :
		#   - +Hash+  -> Hash of the command-line args with arg names as keys associated with
		#     values. Values can be nil empty string in user gave '' or even nil if user didn't provide
		#     an optional argument.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def LFFTransformer.processArguments
			# We want to add all the prop_keys as potential command line options
			optsArray =	[	['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--validRefSeqFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each {
				|propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			LFFTransformer.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

	  # * *Function*: Displays some basic usage info on STDOUT
	  # * *Usage*   : <tt>  BRL::PASH::PashToLff.usage("WARNING: insufficient info provided")  </tt>
	  # * *Args*  :
	  #   - +String+ Optional message string to output before the usage info.
	  # * *Return* :
	  #   - +none+
	  # * *Throws*  :
	  #   - +none+
		# --------------------------------------------------------------------------
		def LFFTransformer.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:
	  Transforms LFF records for VGP/Genboree without doing any merging.
	  Also does verification of data formats.

	  This version supports multiple levels of merging of the same data. The output
	  is sent to a single file, as specified by the VGP team. The different levels of
	  merging can be identified using suffices on the 'name' columns, as requested.

    COMMAND LINE ARGUMENTS:
      -f    => LFF file to merge.
      -p    => Properties file to use for conversion parameters, etc.
      -r    => Ref seq file to verify entrypoints against.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    lffMerger_multiLevel.noMerge.VGP.rb  -f annotations.lff -p merger.defaultTemplate.properties
	";
			exit(BRL::Genboree::USAGE_ERR);
		end # def LFFTransformer.usage(msg='')
	end # class LFFTransformer
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::Genboree::LFFTransformer.processArguments()
	$stderr.puts "#{Time.now()} TRANSFORMER - STARTING"
	merger = BRL::Genboree::LFFTransformer.new(optsHash)
	exitVal = merger.iterativeMerge()
rescue Exception => err
	errTitle =  "#{Time.now()} LFF TRANSFORMER - FATAL ERROR: The transformer exited without processing the data, due to a fatal error.\n"
	msgTitle =  "FATAL ERROR: The transformer exited without processing the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	puts msgTitle
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} TRANSFORMER - DONE" unless(exitVal != 0)
exit(exitVal)
