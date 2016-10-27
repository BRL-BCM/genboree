#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# Author: Andrew R Jackson (andrewj@bcm.tmc.edu)
# Date: 3/31/2004 4:38PM
# Purpose:
# Annotation merger. Merges annotations provided in LFF formatted files and
# mergers them according to the user's parameters. The goal is create a single
# aggregate annotation from several singular annotations, according to the
# user's instructions.
#
# Supports simple overlap merge, radial merge, reciprocal merging,
# order/orientation requirements, aggregate characteristic filtering, and 
# a bunch more heuristics/parameters.
#
# This program is under development and extension.
# See the comments in the sample properties files provided with your
# lffMerger.rb distribution for some explanation of what sorts of merging
# models are possible with this framework. Not intended as a panacea (yet).

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/logger'
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module Genboree
	# CONSTANTS
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	HEADER_RE = /^\s*\[/
	DOT_RE = /^\.$/
	DIGIT_RE = /^\d+$/
	FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,2,3,16
	NEG_ORDER, POS_ORDER = 0,1
	MAX_NUM_ERRS = 150
	MAX_EMAIL_ERRS = 25
	MAX_EMAIL_SIZE = 30_000
	# For reference: lff fields:
	# classID, tName, typeID, subtype, refName, rStart, rEnd, orientation, phase, scoreField, tStart, tEnd
	CLASSID, TNAME, TYPEID, SUBTYPE, REFNAME, RSTART, REND, STRAND, PHASE, SCORE, TSTART, TEND =
			0,1,2,3,4,5,6,7,8,9,10,11

	class FullClosedWindow
		attr_accessor :first, :last

		def initialize(first, last)
			@first = first
			@last = last
		end
	end

	class MergedRecord
		attr_reader :aggregateRecord, :recordsList
		attr_accessor :relativeOrder

		def initialize(seedRecord=nil)
			@aggregateRecord = nil
			@recordsList = nil
			@relativeOrder = nil
			reinitialize(seedRecord)
		end

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
		#   - <tt>BRL::Genboree::POS_ORDER</tt>  -> If positive, or forward, ordering.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def calcRelativeOrder(record)
			return nil if(@aggregateRecord.nil? or @recordsList.nil? or @recordsList.empty?)
			return NEG_ORDER if(record[TSTART] < @aggregateRecord[TSTART])
			return POS_ORDER
		end
	end # class MergedRecord

	#=== *Purpose* :
	#   Worker class that performs heuristical merging of LFF records
	#   in a file, according to the parameters provided by the user.

	class LFFMerger
		attr_reader :lffRecords, :sortedRecordIDs, :seenRecordIDs, :mergedRecord, :rawSpanDataRecord, :posStrandCount
		attr_reader :genome1Window, :genome2Window

		# CONSTANTS
		PROP_KEYS = 	%w{
											program.sizeChecker
											program.merger
											program.noMerger
											program.ruby
											output.outputSuffix
											output.outputDir
											output.mergeClassSuffix
											output.mergeTypeSuffix
											output.groupExistingAnnotations
											output.orientationWillReflectOrdering
											output.nameSuffices
											output.baseUrl
											input.typesToMerge
											input.subtypesToMerge
											input.query.IDRegExp
											param.numIterations
											param.doRequireSameQueryIDs
											param.reciprocalMerge
											param.genome1.mergeRadius
											param.genome2.mergeRadius
											param.strictOrientation
											param.strictOrdering
											param.doSpanSizeFiltering
											param.genome1.minSpanSize
											param.genome2.minSpanSize
											param.doMergedScoreFiltering
											param.minMergedScore
											param.doDensityFiltering
											param.genome1.minScorePerSpan1
											param.genome2.minScorePerSpan2
											param.doNumMergedMembersFiltering
											param.minNumMergedRecords
											param.doSpanRatioFiltering
											param.minSpanRatio

										} ;
		MERGE_RECORD, SKIP_RECORD, STOP_LOOKING = 0,1,2
		SPAN1, SPAN2, SPAN_RATIO, SPAN_DELTA, SPAN1_SPAN2, SCORE_SPAN1, SCORE_SPAN2 = 0,1,2,3,4,5,6
		NO_FAIL_VECTOR = [ false, nil ]

		# * *Function*: Instantiates BRL::Genboree::LFFMerger.
		# * *Usage*   : <tt>  mergerObj = BRL::Genboree::LFFMerger.new(optsHash)  </tt>
		# * *Args*    :
		#   - +optsHash+  ->  A hash of the command line options obtained from
		#     BRL's BRL::Util::GetoptLong#to_hash function. Minmally requires
		#     '-p' and '-f' keys for properties file name and pash
		#     file name be in there.
		# * *Returns* :
		#   - +LFFMerger+  ->  Object instance.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def initialize(optsHash)
			@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
			# If options supplied on command line instead, use them rather than those in propfile
			PROP_KEYS.each { |propName|
				argPropName = "--#{propName}"
				unless(optsHash[argPropName].nil?)
					@propTable[propName] = optsHash[argPropName]
				end
			}
			@propTable.verify(PROP_KEYS)
			if(optsHash.key?('--validRefSeqFile'))
				$stderr.puts "#{Time.now()} MERGER - Found a RefSeq File. Loading..."
				@doCheckRefSeqs = true
				loadValidRefSeqs(optsHash['--validRefSeqFile'])
				$stderr.puts "#{Time.now()} MERGER - ...Done loading valid ref seqs."
			else
				$stderr.puts "#{Time.now()} MERGER - No RefSeq File provided. All RefSeqs are valid."
				@doCheckRefSeqs = false
			end
			setParameters()
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
			Dir.safeMkdir(@outDir)
			@outFile = "#{@outDir}/#{File::basename(@lffFileName)}.merged.lff"
			@writer = BRL::Util::TextWriter.new(@outFile + @outputSuffix)
			@mergedRecord = MergedRecord.new()
			@logger = BRL::Util::Logger.new()
		end

		def loadValidRefSeqs(fileName)
			@validRefSeqs = {}
			@refSeqFile = fileName
			refReader = BRL::Util::TextReader.new(@refSeqFile)
			lineArray = []
			refReader.each { |line|
				line.strip!
				next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ HEADER_RE)
				fields = line.split("\t")
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

		# Puts user parameters into variables. Ugly.
		def setParameters()
			@queryIDRegExpStr = @propTable['input.query.IDRegExp']
			@queryIDRE = /#{@queryIDRegExpStr}/
			@numIterations = @propTable['param.numIterations'].to_i
			unless(@propTable['output.nameSuffices'].kind_of?(Array))
				@propTable['output.nameSuffices'] = [ @propTable['output.nameSuffices'] ]
			end
			@nameSuffices = @propTable['output.nameSuffices'].map!{|xx| xx.strip! ; xx.gsub('<none>','') }
			unless( @propTable['param.reciprocalMerge'].kind_of?(Array))
				 @propTable['param.reciprocalMerge'] = [  @propTable['param.reciprocalMerge']  ]
			end
			@doReciprocalMerge = @propTable['param.reciprocalMerge'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.doRequireSameQueryIDs'].kind_of?(Array))
				@propTable['param.doRequireSameQueryIDs'] = [ @propTable['param.doRequireSameQueryIDs']  ]
			end
			@doRequireSameQueryIDs = @propTable['param.doRequireSameQueryIDs'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.genome1.mergeRadius'].kind_of?(Array))
				@propTable['param.genome1.mergeRadius'] = [ @propTable['param.genome1.mergeRadius']  ]
			end
			@genome1MergeRadius = @propTable['param.genome1.mergeRadius'].map!{|xx| xx.to_i }
			unless(@propTable['param.genome2.mergeRadius'].kind_of?(Array))
				@propTable['param.genome2.mergeRadius'] = [  @propTable['param.genome2.mergeRadius'] ]
			end
			@genome2MergeRadius = @propTable['param.genome2.mergeRadius'].map!{|xx| xx.to_i }
			unless(@propTable['param.strictOrientation'].kind_of?(Array))
				@propTable['param.strictOrientation'] = [ @propTable['param.strictOrientation']  ]
			end
			@noStrictOrientation = @propTable['param.strictOrientation'].map!{|xx| xx.to_i == 0 ? true : false }
			unless(@propTable['param.strictOrdering'].kind_of?(Array))
				@propTable['param.strictOrdering'] = [  @propTable['param.strictOrdering' ] ]
			end
			@noStrictOrdering = @propTable['param.strictOrdering'].map!{|xx| xx.to_i == 0 ? true : false }
			unless(@propTable['output.orientationWillReflectOrdering'].kind_of?(Array))
				@propTable['output.orientationWillReflectOrdering'] = [ @propTable['output.orientationWillReflectOrdering']  ]
			end
			@orientationReflectsOrdering = @propTable['output.orientationWillReflectOrdering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['output.groupExistingAnnotations'].kind_of?(Array))
				@propTable['output.groupExistingAnnotations'] = [  @propTable['output.groupExistingAnnotations'] ]
			end
			@groupExistingAnnotations = @propTable['output.groupExistingAnnotations'].map!{|xx| xx.to_i == 0 ? false : true }

			@mergeClassSuffix = @propTable['param.mergeClassSuffix'].nil? ? '' : @propTable['param.mergeClassSuffix']
			@mergeTypeSuffix = @propTable['param.mergeTypeSuffix'].nil? ? '' : @propTable['param.mergeTypeSuffix']
			@outputSuffix = @propTable['output.outputSuffix'].nil? ? '' : @propTable['output.outputSuffix']
			@typesToMerge = {}
			unless(@propTable['param.doSpanSizeFiltering'].kind_of?(Array))
				@propTable['param.doSpanSizeFiltering'] = [ @propTable['param.doSpanSizeFiltering']  ]
			end
			@doSpanSizeFiltering = @propTable['param.doSpanSizeFiltering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.genome1.minSpanSize'].kind_of?(Array))
				@propTable['param.genome1.minSpanSize'] = [  @propTable['param.genome1.minSpanSize'] ]
			end
			@genome1MinSpanSize = @propTable['param.genome1.minSpanSize'].map!{|xx| xx.to_i }
			unless(@propTable['param.genome2.minSpanSize'].kind_of?(Array))
				@propTable['param.genome2.minSpanSize'] = [ @propTable['param.genome2.minSpanSize']  ]
			end
			@genome2MinSpanSize = @propTable['param.genome2.minSpanSize'].map!{|xx| xx.to_i }
			unless(@propTable['param.doMergedScoreFiltering'].kind_of?(Array))
				@propTable['param.doMergedScoreFiltering'] = [ @propTable['param.doMergedScoreFiltering']  ]
			end
			@doMergedScoreFiltering = @propTable['param.doMergedScoreFiltering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.minMergedScore'].kind_of?(Array))
				@propTable['param.minMergedScore'] = [  @propTable['param.minMergedScore'] ]
			end
			@minMergedScore = @propTable['param.minMergedScore'].map!{|xx| xx.to_f}
			unless(@propTable['param.doDensityFiltering'].kind_of?(Array))
				@propTable['param.doDensityFiltering'] = [ @propTable['param.doDensityFiltering']  ]
			end
			@doDensityFiltering = @propTable['param.doDensityFiltering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.genome1.minScorePerSpan1'].kind_of?(Array))
				@propTable['param.genome1.minScorePerSpan1'] = [  @propTable['param.genome1.minScorePerSpan1'] ]
			end
			@genome1MinDensity = @propTable['param.genome1.minScorePerSpan1'].map!{|xx| xx.to_f}
			unless(@propTable['param.genome2.minScorePerSpan2'].kind_of?(Array))
				@propTable['param.genome2.minScorePerSpan2'] = [  @propTable['param.genome2.minScorePerSpan2'] ]
			end
			@genome2MinDensity = @propTable['param.genome2.minScorePerSpan2'].map!{|xx| xx.to_f}
			unless(@propTable['param.doNumMergedMembersFiltering'].kind_of?(Array))
				@propTable['param.doNumMergedMembersFiltering'] = [ @propTable['param.doNumMergedMembersFiltering']  ]
			end
			@doNumMembersFiltering = @propTable['param.doNumMergedMembersFiltering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.minNumMergedRecords'].kind_of?(Array))
				@propTable['param.minNumMergedRecords'] = [ @propTable['param.minNumMergedRecords']  ]
			end
			@minNumMembers = @propTable['param.minNumMergedRecords'].map!{|xx| xx.to_i }
			unless(@propTable['param.doSpanRatioFiltering'].kind_of?(Array))
				@propTable['param.doSpanRatioFiltering'] = [ @propTable['param.doSpanRatioFiltering']  ]
			end
			@doSpanRatioFiltering = @propTable['param.doSpanRatioFiltering'].map!{|xx| xx.to_i == 0 ? false : true }
			unless(@propTable['param.minSpanRatio'].kind_of?(Array))
				@propTable['param.minSpanRatio'] = [ @propTable['param.minSpanRatio']  ]
			end
			@minSpanRatio = @propTable['param.minSpanRatio'].map!{|xx| xx.to_f }

			@outDir = (@propTable['output.outputDir'].nil? or @propTable['output.outputDir'].empty?) ? '.' : @propTable['output.outputDir']
			types = @propTable['input.typesToMerge']
			if(types == '<all>')
				@mergeAllTypes = true
			else
				@mergeAllTypes = false
				unless(types.kind_of?(Array)) then types = [ types ] ; end
				types.each { |typeToMerge|
					@typesToMerge[typeToMerge] = ''
				}
			end
			@subTypesToMerge = {}
			subtypes = @propTable['input.subtypesToMerge']
			if(subtypes == '<all>')
				@mergeAllSubTypes = true
			else
				@mergeAllSubTypes = false
				unless(subtypes.kind_of?(Array)) then	subtypes = [ subtypes ] ; end
				subtypes.each { 					|subTypeToMerge|
					@subTypesToMerge[subTypeToMerge] = ''
				}
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
					next
				# Assembly section? SKIP
				elsif(fields.length == 7)
					# do nothing with assembly info for now
					next
				# Assume Annotation section. PROCESS
				else
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

		# Validation especially important for web-version. Pedantic feedback.
		def validateAnnotation(fields)
			retVal = []
			anyRecip = false
			@doReciprocalMerge.each { |xx| if(xx) then anyRecip = true ; break ; end ; }
			strippedFields = fields.collect{|field| field.strip}
			unless((strippedFields.size == 10) or (strippedFields.size == 12))
				retVal << "This LFF record has #{strippedFields.size} fields."
				retVal << "LFF records are <TAB> delimited and have either 10 or 12 fields."
				retVal << "Space characters are not tabs."
			else
				if(anyRecip and strippedFields.size == 10)
					retVal << "This LFF record has only #{strippedFields.size} fields."
					retVal << "This means there is only start/end data for one (1) genome."
					retVal << "But you indicated two (2) genomes were present for merging on our form."
					retVal << "Because of this discrepency, this annotation will be skipped."
				end
				if(@doCheckRefSeqs) # The provided with a file of valid refseq records.
					if(!@validRefSeqs.key?(strippedFields[4]))
						retVal << "referring to unknown reference sequence entrypoint '#{fields[4]}'"
						@badRefSeqDetected = true
					else
						if(strippedFields[6].to_i > @validRefSeqs[strippedFields[4]])
							retVal << "end of annotation (#{strippedFields[6]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
							retVal << "annotation was truncated."
							strippedFields[6] = @validRefSeqs[strippedFields[4]]
							@badRefSeqDetected = true
						end
						if(strippedFields[5].to_i > @validRefSeqs[strippedFields[4]])
							retVal << "start of annotation (#{strippedFields[5]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
							retVal << "annotation was truncated."
							strippedFields[5] = @validRefSeqs[strippedFields[4]]
							@badRefSeqDetected = true
						end
					end
				end

				# Minutia of validation tests for sane data. Important for web-based version and database-constraints.
				# Fix score column if it starts with just 'e'...which means 1e, presumably. Bloody NCBI Blast.
				if(strippedFields[9] =~ /^e(?:\+|\-)\d+/) then strippedFields[9] = fields[9] = "1#{strippedFields[9]}" end
				if(strippedFields[9] =~ /^\.$/) then strippedFields[9] = fields[9] = '0' end
				if(fields[1].length > 200) then retVal << "the name '#{fields[1]}' is too long." end
				unless(strippedFields[7] =~ /^[\+\-\.]$/) then retVal << "the strand column contains '#{fields[7]}' and not +, -, or ."	end
				unless(strippedFields[8] =~ /^[012\.]$/) then retVal << "the phase column contains '#{fields[8]}' and not 0, 1, 2, or ." end
				unless(strippedFields[5].to_s =~ DIGIT_RE and (strippedFields[5].to_i >= 0))
					retVal << "the start column contains '#{fields[5]}' and not a positive integer."
					retVal << "reference sequence coordinates should start at 1."
					retVal << "bases at negative or fractional coordinates are not supported."
				else
					strippedFields[5] = strippedFields[5].to_i
					if(strippedFields[5] == 0)	# Looks to be 0-based, half-open
						strippedFields[5] = 1 		# Now it's 1-based, fully closed. Oh well.
					end
				end
				unless(strippedFields[6].to_s =~ DIGIT_RE and (strippedFields[6].to_i >= 0))
					retVal << "the end column contains '#{fields[5]}' and not a positive integer."
					retVal << "reference sequence coordinates start at 1."
					retVal << "bases at negative or fractional coordinates are not supported."
				else
					strippedFields[6] = strippedFields[6].to_i
					if(strippedFields[6] == 0)	# Looks to be 0-based, half-open
						strippedFields[6] = 1 		# Now it's 1-based, fully closed. Oh well.
					end
				end
				unless(strippedFields[9].to_s =~ /^\-?\d+(?:\.\d+)?(?:e(?:\+|\-)\d+)?$/) then
					retVal << "the score column contains '#{fields[9]}' and not an integer or real number or ."
				end
				if(fields.length == 12)
					unless(strippedFields[10] =~ DOT_RE or (strippedFields[10] =~ DIGIT_RE and (strippedFields[10].to_i >= 0)))
						retVal << "the tstart column contains '#{fields[10]}' and not a positive integer or '.'"
						retVal << "sequence coordinates start at 1."
						retVal << "bases at negative or fractional coordinates are not supported."
					else
						strippedFields[10] = strippedFields[10].to_i unless(strippedFields[10] =~ DOT_RE)
						if(strippedFields[10] == 0)	# Looks to be 0-based, half-open
							strippedFields[10] = 1 		# Now it's 1-based, fully closed. Oh well.
						end
					end
					unless(strippedFields[11] =~ DOT_RE or (strippedFields[11] =~ DIGIT_RE and (strippedFields[11].to_i >= 0)))
						retVal << "the tend column contains '#{fields[10]}' and not a positive integer or '.'"
						retVal << "sequence coordinates start at 1."
						retVal << "bases at negative or fractional coordinates are not supported."
					else
						strippedFields[11] = strippedFields[11].to_i unless(strippedFields[11] =~ DOT_RE)
						if(strippedFields[11] == 0)	# Looks to be 0-based, half-open
							strippedFields[11] = 1 		# Now it's 1-based, fully closed. Oh well.
						end
					end
				end
				unless(strippedFields[1] =~ @queryIDRE)
					retVal << "the base query name can't be determined."
					retVal << "query names should look like <name> or <name>.<ver>"
					retVal << "in latter case, the \".<ver>\" will be stripped off"
				end
				anyEmpty = false
				fields.each_with_index { |field, ii|
					if(field.strip =~ BLANK_RE)
						anyEmpty = true
						break
					elsif(field.strip =~ DOT_RE and (ii != 8) and (ii != 7) and (ii != 10) and (ii != 11))
						fields[ii] = nil
					end
				}
				if(anyEmpty) then retVal <<  "some of the fields are empty and this is not allowed." end
			end
			if(retVal.empty?)
				fields = nil
				fields = strippedFields
				return true
			else
				return retVal
			end
		end

		def sortLFFRecordIDs()
			@sortedRecordIDs.sort! {
				|xx,yy|
				record1 = @lffRecords[xx]
				record2 = @lffRecords[yy]
				compareVal = (@lffRecords[xx][REFNAME] <=> @lffRecords[yy][REFNAME])
				if(compareVal == 0)
					compareVal = (@lffRecords[xx][RSTART] <=> @lffRecords[yy][RSTART])
					if(compareVal == 0)
						compareVal = (@lffRecords[xx][TNAME] <=> @lffRecords[yy][TNAME])
					end
				end
				compareVal
			}
			return
		end

		# Main merge method. Calls method that do the real work.
		def iterativeMerge()
			$stderr.puts("#{Time.now()} MERGER - loading records")
			tooManyErrs = readLFFRecords()
			$stderr.puts("#{Time.now()} MERGER - done loading records")
			if(tooManyErrs)
				$stderr.puts("#{Time.now()} MERGER - too many (#{MAX_NUM_ERRS}+) errors in file. Abandoning merge entirely.")
			else
				sortLFFRecordIDs()
				$stderr.puts("#{Time.now()} MERGER - number LFF records: #{@sortedRecordIDs.size}  (#{@lffRecords.size})")
				$stderr.puts("#{Time.now()} MERGER - done sorting records")
				@numIterations.times { |ii|
					mergeRecords(ii)
				}
				$stderr.puts "#{Time.now()} MERGER - done merging record"
				@writer.close()
			end
			# Output logged error messages?
			if(@logger.size <= 0)
				retVal = OK
				puts "Merge of annotations successful."
			elsif(tooManyErrs) # Too many parse errors to bother processing. Whole file is probably messed up.
				retVal = FAILED
				puts "Too many errors (#{MAX_NUM_ERRS}) in the annotation file.\nToo likely the whole file has the same error(s) on each line."
				if(@doCheckRefSeqs and @badRefSeqDetected)
					puts makeRefSeqStr()
				end
				puts "No merging attempted.\nHere is a sample of some of your formatting errors:\n\n"
				puts @logger.to_s(MAX_EMAIL_ERRS)
			else # Ok, but had some errors
				retVal = OK_WITH_ERRORS
				if(@doCheckRefSeqs and @badRefSeqDetected)
					puts makeRefSeqStr()
				end
				puts @logger.to_s(MAX_EMAIL_ERRS)
			end
			return retVal
		end

		def makeRefSeqStr()
			return '' unless(@doCheckRefSeqs)
			refSeqStr =    "\nNOTE: Some invalid/unknown reference sequences (the 'ref' column)\n"
			refSeqStr +=   "      and/or annotations that went beyond the ends of the\n"
			refSeqStr +=   "      reference sequence were found.\n"
			refSeqStr +=   "      Here is a list of valid reference sequences and lengths:\n\n"
			refSeqStr +=   "RefSeq_Name\tLength\n"
			@validRefSeqs.keys.sort.each { |refSeq|
				length = @validRefSeqs[refSeq]
				refSeqStr += "#{refSeq}\t#{length}\n"
			}
			refSeqStr += "\n\n"
			return refSeqStr
		end

		# * *Function*: Massive method that does a lot of 'sexy' work to merge LFF
		#   records according the user's settings. Calls lots of helper methods.
		#   Prints progress info to STDERR. Not particularly fast ; O(N^2) with
		#   amelioration via shortcuts that make it supra-O(N) for sparse data
		#   and O(N^2) for large data. Need to work on that.
		# * *Usage*   : <tt>  merger.mergeRecords()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +StandardError+ -> If the regular expression provided by the user doesn't
		#     correctly extract what it is supposed to.
		# --------------------------------------------------------------------------
		def mergeRecords(itNum)
			@seenRecordIDs.clear
			$stderr.puts("#{Time.now()} MERGER - (Level ##{itNum}) done setup/config")
			# Go through sorted list of records and do a greedy merge if possible.
			for ii in (0...@sortedRecordIDs.size)
				currRecordID = @sortedRecordIDs[ii]
				# Skip ones we've dealt with already (maybe have been merged already)
				next if(@seenRecordIDs.key?(currRecordID))
				@seenRecordIDs[currRecordID] = ''
				@posStrandCount = 0
				@currRecord = @lffRecords[currRecordID]
				adjustPosStrandCount(@currRecord, itNum)
				@mergedRecord.reinitialize(@currRecord)
				@currRecord[TNAME] =~ @queryIDRE
				@currQueryName = $1
				# Should we even merge this annotation with others, or just skip right to
				# re-outputting it because its type/subtype is not something we are merging?
				tryMerge = tryToMergeAnnotation?(currRecordID, itNum)				
				if(tryMerge)
					unless(@doReciprocalMerge[itNum])
						@mergedRecord.aggregateRecord[TSTART] = '.'
						@mergedRecord.aggregateRecord[TEND] = '.'
					end
					# Set up merge windows
					@genome1MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[RSTART] - @genome1MergeRadius[itNum], @mergedRecord.aggregateRecord[REND] + @genome1MergeRadius[itNum])
					if(@doReciprocalMerge[itNum])
						@genome2MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[TSTART] - @genome2MergeRadius[itNum], @mergedRecord.aggregateRecord[TEND] + @genome2MergeRadius[itNum])
					end
					# Go through rest of records until progress out of merge radius
					for jj in ((ii+1)...@sortedRecordIDs.size)
						nextRecordID = @sortedRecordIDs[jj]
						nextRecord = @lffRecords[nextRecordID]
						next if(@seenRecordIDs.key?(nextRecordID)) # Check if this record already merged/dealt with
						status = getProceedStatus(nextRecordID, itNum) # Do we merge it with the current aggregate or not?
						break if(status == STOP_LOOKING)
						next if(status == SKIP_RECORD)
						@seenRecordIDs[nextRecordID] = ''
						mergeNewRecord(nextRecord, itNum)
						adjustPosStrandCount(nextRecord, itNum)
					end
					getRawSpanData(itNum)
					# Does the merged record pass all our criteria? [ Record stats here as well ]
					doFilter = filterMergedRecord(itNum)
					next if(doFilter) # Filter the merged aggregate (and all it's singleton components) right out...don't output it, reuse the singltons, or anything
					                  # ISSUE ??? : Should we return all the singletons back into the list of available annotations?????
					@mergedRecord.aggregateRecord[PHASE] = '.'
				end
				# Track independent merges of data from same tName separately using a version number
				unless(@mergedRecordCounts.key?(@currQueryName))
					@mergedRecordCounts[@currQueryName] = 1
				else
					@mergedRecordCounts[@currQueryName] += 1
				end
				hitCount = @mergedRecordCounts[@currQueryName]
				# Fix the query name and phase
				@mergedRecord.aggregateRecord[TNAME] = "#{@currQueryName}.#{hitCount}#{@nameSuffices[itNum]}"
				outputMergedRecord(itNum)
				@currRecord = nil
				@rawSpanDataRecord = nil
				@mergedRecord.recordsList.each { |record| 
					record.clear
					record = nil
				}
			end
			$stderr.puts("#{Time.now()} MERGER - done merging data")
			return
		end

		def getRawSpanData(itNum)
			span1 = (@mergedRecord.aggregateRecord[REND].to_f - @mergedRecord.aggregateRecord[RSTART].to_f) + 1
			if(@doReciprocalMerge[itNum])
				span2 = (@mergedRecord.aggregateRecord[TEND].to_f - @mergedRecord.aggregateRecord[TSTART].to_f) + 1
				spanRatio = span1 / span2
				spanRatio2 = span2 / span1
				spanDelta = span1 - span2
				span1DivSpan2 = span1/span2
				span2Density = @mergedRecord.aggregateRecord[SCORE].to_f / span2
			else
				span2 = 0
				spanRatio = 1
				spanRatio2 = 1
				spanDelta = 0
				span1DivSpan2 = 1
				span2Density = 1
			end
			if(spanRatio2 < spanRatio) then spanRatio = spanRatio2 end
			span1Density = @mergedRecord.aggregateRecord[SCORE].to_f / span1
			@rawSpanDataRecord = [ span1, span2, spanRatio, spanDelta, span1DivSpan2, span1Density, span2Density ]
			return
		end

		def filterMergedRecord(itNum)
			spanSizeFail  = ((@doReciprocalMerge[itNum] and @doSpanSizeFiltering[itNum]) ? spanSizeFilter(itNum) : false)
			minScoreFail, score = (@doMergedScoreFiltering[itNum] ? minScoreFilter(itNum) : NO_FAIL_VECTOR)
			numMembersFail, numMembers = (@doNumMembersFiltering [itNum] ? numMembersFilter(itNum) : NO_FAIL_VECTOR)
			spanRatioFail = ((@doSpanRatioFiltering[itNum] and @doReciprocalMerge[itNum]) ? spanRatioFilter(itNum) : false)
			minDensityFail = (@doDensityFiltering[itNum] ? minDensityFilter(itNum) : false)

			pass = ! (spanSizeFail or minScoreFail or numMembersFail or spanRatioFail or minDensityFail)
			return !pass
		end

		def numMembersFilter(itNum)
			retVal = (@mergedRecord.recordsList.size < @minNumMembers[itNum])
			return [ retVal, @mergedRecord.recordsList.size ]
		end

		def minScoreFilter(itNum)
			retVal = (@mergedRecord.aggregateRecord[SCORE] < @minMergedScore[itNum])
			return [ retVal, @mergedRecord.aggregateRecord[SCORE] ]
		end

		def minDensityFilter(itNum)
			if(@doReciprocalMerge[itNum])
				return	(	(@rawSpanDataRecord[SCORE_SPAN1] < @genome1MinDensity[itNum]) or
									(@rawSpanDataRecord[SCORE_SPAN2] < @genome2MinDensity[itNum])
								)
			else
				return (@rawSpanDataRecord[SCORE_SPAN1] < @genome1MinDensity[itNum])
			end
		end

		def spanSizeFilter(itNum)
			if(@doReciprocalMerge[itNum])
				return ((@rawSpanDataRecord[SPAN1] < @genome1MinSpanSize[itNum]) or (@rawSpanDataRecord[SPAN2] < @genome2MinSpanSize[itNum]))
			else
				return (@rawSpanDataRecord[SPAN1] < @genome1MinSpanSize[itNum])
			end
		end

		def spanRatioFilter(itNum)
			return (@rawSpanDataRecord[SPAN_RATIO] < @minSpanRatio[itNum])
		end

		def outputMergedRecord(itNum)
			strToWrite = nil
			# Are we just regrouping existing records?
			if(@groupExistingAnnotations[itNum])
				# Need to write out each of the old records, with its new group.
				@mergedRecord.recordsList.each {
					|oldRecord|
					oldRecord[TNAME] = @mergedRecord.aggregateRecord[TNAME]
					oldRecord[CLASSID] << @mergeClassSuffix
					oldRecord[TYPEID] << @mergeTypeSuffix
					strToWrite = oldRecord.join("\t")
					@writer.puts(strToWrite)

				}
			else # We are creating a new aggregate record to output
				@mergedRecord.aggregateRecord[CLASSID] << @mergeClassSuffix
				@mergedRecord.aggregateRecord[TYPEID] << @mergeTypeSuffix
				if(@orientationReflectsOrdering[itNum] and @doReciprocalMerge[itNum])
					@mergedRecord.aggregateRecord[STRAND] = (@mergedRecord.relativeOrder == POS_ORDER ? '+' : '-')
				end
				if(!@orientationReflectsOrdering[itNum] and @noStrictOrientation[itNum] and (@mergedRecord.aggregateRecord[STRAND] != '.'))
					if(@posStrandCount >= 0)
						@mergedRecord.aggregateRecord[STRAND] = '+'
					else
						@mergedRecord.aggregateRecord[STRAND] = '-'
					end
				end
				strToWrite = @mergedRecord.aggregateRecord.join("\t")
				@writer.puts(strToWrite)
			end
			return
		end

		def adjustPosStrandCount(record, itNum)
			if(@noStrictOrientation[itNum] and (record[STRAND] != '.'))
				if(record[STRAND] == '+')
					@posStrandCount += 1
				elsif(record[STRAND] == '-')
					@posStrandCount -= 1
				else
					raise("\nERROR: bad strand type found: \"#{record[STRAND]}\" (should have already verfied this record?)")
				end
			end
			return
		end

		def mergeNewRecord(newRecord, itNum)
			@mergedRecord.recordsList << newRecord.dup
			if(@mergedRecord.relativeOrder.nil? and @doReciprocalMerge[itNum])
				@mergedRecord.relativeOrder = @mergedRecord.calcRelativeOrder(newRecord)
			end
			if(newRecord[RSTART] < @mergedRecord.aggregateRecord[RSTART])
				@mergedRecord.aggregateRecord[RSTART] = newRecord[RSTART]
			end
			if(newRecord[REND] > @mergedRecord.aggregateRecord[REND])
				@mergedRecord.aggregateRecord[REND] = newRecord[REND]
			end
			if(@doReciprocalMerge[itNum])
				if(newRecord[TSTART] < @mergedRecord.aggregateRecord[TSTART])
					@mergedRecord.aggregateRecord[TSTART] = newRecord[TSTART]
				end
				if(newRecord[TEND] > @mergedRecord.aggregateRecord[TEND])
					@mergedRecord.aggregateRecord[TEND] = newRecord[TEND]
				end
			end
			@mergedRecord.aggregateRecord[SCORE] = @mergedRecord.aggregateRecord[SCORE] + newRecord[SCORE]
			@genome1MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[RSTART] - @genome1MergeRadius[itNum], @mergedRecord.aggregateRecord[REND] + @genome1MergeRadius[itNum])
			if(@doReciprocalMerge[itNum])
				@genome2MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[TSTART] - @genome2MergeRadius[itNum], @mergedRecord.aggregateRecord[TEND] + @genome2MergeRadius[itNum])
			end
			return
		end

		# To merge or not to merge, that is the question:
		def getProceedStatus(nextRecordID, itNum)
			nextRecord = @lffRecords[nextRecordID]
			return STOP_LOOKING unless(nextRecord[REFNAME] == @mergedRecord.aggregateRecord[REFNAME])
			return STOP_LOOKING unless((nextRecord[RSTART] <= @genome1MergeWindow.last) and (@genome1MergeWindow.first <= nextRecord[REND]))
			if(@doReciprocalMerge[itNum])
				return SKIP_RECORD unless((nextRecord[TSTART] <= @genome2MergeWindow.last) and (@genome2MergeWindow.first <= nextRecord[TEND]))
			end
			return SKIP_RECORD unless(@mergeAllTypes or @typesToMerge.key?(nextRecord[TYPEID]))
			return SKIP_RECORD unless(@mergedRecord.aggregateRecord[TYPEID] == nextRecord[TYPEID])
			return SKIP_RECORD unless(@mergeAllSubTypes or @subTypesToMerge.key?(nextRecord[SUBTYPE]))
			return SKIP_RECORD unless(@mergedRecord.aggregateRecord[SUBTYPE] == nextRecord[SUBTYPE])

			if(@doReciprocalMerge[itNum] or @doRequireSameQueryIDs[itNum])
				nextRecord[TNAME] =~ @queryIDRE
				raise("\nERROR: bad regular expression '#{@queryIDRegExpStr}' provided by user via query.IDRegExp property. Must have a sub-expression that isolates the query name (such as #{nextRecord[TNAME]} from your file).\n") if($1.nil?)
				nextQueryName = $1
				return SKIP_RECORD unless(nextQueryName == @currQueryName)
			end
			unless(@noStrictOrientation[itNum])
				return SKIP_RECORD unless((nextRecord[STRAND] == @mergedRecord.aggregateRecord[STRAND]) or (nextRecord[STRAND] == '.'))
			end
			unless(@noStrictOrdering[itNum] and @doReciprocalMerge[itNum])
				unless(@mergedRecord.relativeOrder.nil?) # then we must have a relativeOrder
					nextRecordOrder = @mergedRecord.calcRelativeOrder(nextRecord)
					return SKIP_RECORD unless(nextRecordOrder == @mergedRecord.relativeOrder)
				end
			end
			return MERGE_RECORD
		end

		def tryToMergeAnnotation?(recordID, itNum)
			record = @lffRecords[recordID]
			return false unless(@mergeAllTypes or @typesToMerge.key?(record[TYPEID]))
			return false unless(@mergeAllSubTypes or @subTypesToMerge.key?(record[SUBTYPE]))
			return true
		end
		
		def LFFMerger.processArguments
			# We want to add all the prop_keys as potential command line options
			optsArray =	[	['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
										['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
										['--validRefSeqFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
										['--help', '-h', GetoptLong::NO_ARGUMENT]
									]
			PROP_KEYS.each { |propName|
				argPropName = "--#{propName}"
				optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
			}
			progOpts = GetoptLong.new(*optsArray)
			optsHash = progOpts.to_hash
			LFFMerger.usage() if(optsHash.empty? or optsHash.key?('--help'));
			return optsHash
		end

		def LFFMerger.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

PROGRAM DESCRIPTION:
  Merges LFF records that are 'close' on the refSeq and on the query sequence
  into 1 record. Can merge regardless of strand or be strand-sensitive. Takes
  an LFF file.

  This version supports multiple iterations of merging of the same data. The
  output is sent to a single file, as specified by the VGP team. The different
  iterations of merging can be identified using user-supplied suffices for the
  'name' columns, as requested by the Genboree team.

COMMAND LINE ARGUMENTS:
  -f    => LFF file to merge.
  -p    => Properties file to use for conversion parameters, etc.
  -r    => [optional] Ref seq file to verify entrypoints against.
  -h    => [optional flag] Output this usage info and exit

USAGE:
  lffMerger.rb  -f annotations.lff -p merger.defaultTemplate.properties

";
			exit(BRL::Genboree::USAGE_ERR);
		end # def LFFMerger.usage(msg='')
	end # class LFFMerger
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::Genboree::LFFMerger.processArguments()
# Some exception stuff mainly for web-version.
begin
	$stderr.puts "#{Time.now()} MERGER - STARTING"
	merger = BRL::Genboree::LFFMerger.new(optsHash)
	exitVal = merger.iterativeMerge()
rescue Exception => err
	errTitle =  "#{Time.now()} MERGER - FATAL ERROR: The merger exited without processing the data, due to a fatal error.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	$stderr.puts errTitle + errstr  
	exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} MERGER - DONE" unless(exitVal != 0)
exit(exitVal)
