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
	class LFFMerger
		attr_reader :lffRecords, :sortedRecordIDs, :seenRecordIDs, :mergedRecord, :rawSpanDataRecord, :posStrandCount
		attr_reader :genome1Window, :genome2Window

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
				$stderr.puts "#{Time.now()} MERGER - Found a RefSeq File. Loading..."
				@doCheckRefSeqs = true
				loadValidRefSeqs(optsHash['--validRefSeqFile'])
				$stderr.puts "#{Time.now()} MERGER - ...Done loading valid ref seqs."
			else
				$stderr.puts "#{Time.now()} MERGER - No RefSeq File provided. All RefSeqs are valid."
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
			@newRefSeqs = {}
			@genome1MergeWindow = nil
			@genome2MergeWindow = nil
			@rawSpanDataRecord = nil
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
				types.each {
					|typeToMerge|
					@typesToMerge[typeToMerge] = ''
				}
			end
			@subTypesToMerge = {}
			subtypes = @propTable['input.subtypesToMerge']
			if(subtypes == '<all>')
				@mergeAllSubTypes = true
			else # they must have given a list
				@mergeAllSubTypes = false
				unless(subtypes.kind_of?(Array)) then	subtypes = [ subtypes ] ; end
				subtypes.each {
					|subTypeToMerge|
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
			anyRecip = false
			@doReciprocalMerge.each { |xx| if(xx) then anyRecip = true ; break ; end ; }
			strippedFields = fields.collect{|field| field.strip}
			# Is the size right? If not, stop right here.
			unless((strippedFields.size == 10) or (strippedFields.size == 12) or (strippedFields.size == 13) or (strippedFields.size == 14))
				retVal << "This LFF record has #{strippedFields.size} fields."
				retVal << "LFF records are <TAB> delimited and have either 10 or 12 fields."
				retVal << "Enhanced LFF records can have 13 or 14 fields."
				retVal << "Space characters are not tabs."
			else # right number of fields, check them
				if(anyRecip and strippedFields.size == 10)
					retVal << "This LFF record has only #{strippedFields.size} fields."
					retVal << "This means there is only start/end data for one (1) genome."
					retVal << "But you indicated two (2) genomes were present for merging on our form."
					retVal << "Because of this discrepency, this annotation will be skipped."
				end
				# Do we know about this entrypoint? If not, error and skip annotation.
				if(@doCheckRefSeqs)
					if(!@validRefSeqs.key?(strippedFields[4]))
						retVal << "referring to unknown reference sequence entrypoint '#{fields[4]}'"
						@badRefSeqDetected = true
					else # found correct refseq, but is coords ok?
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
				unless(strippedFields[9].to_s =~ /^\-?\d+(?:\.\d+)?(?:e(?:\+|\-)\d+)?$/i) then
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
					elsif(field.strip =~ DOT_RE and (ii != 8) and (ii != 7) and (ii != 10) and (ii != 11))
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
				# First by refseq the annotation is on
				compareVal = (@lffRecords[xx][REFNAME] <=> @lffRecords[yy][REFNAME])
				if(compareVal == 0)
					# Sort by start positions on the refseq
					compareVal = (@lffRecords[xx][RSTART] <=> @lffRecords[yy][RSTART])
					if(compareVal == 0)
						# If tied start positions, do consistant sorting (robust tie resolution) by query name.
						compareVal = (@lffRecords[xx][TNAME] <=> @lffRecords[yy][TNAME])
					end
				end
				compareVal
			}
			return
		end

		def iterativeMerge()
			# Read in indices once
			$stderr.puts("#{Time.now()} MERGER - loading records")
			tooManyErrs = readLFFRecords()
			$stderr.puts("#{Time.now()} MERGER - done loading records")
			if(tooManyErrs)
				$stderr.puts("#{Time.now()} MERGER - too many (#{MAX_NUM_ERRS}+) errors in file. Abandoning merge entirely.")
			else
				# Write out new refseqs, if any
				writeNewRefSeqs()
				@writer.puts "[annotations]"
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
			elsif(tooManyErrs) # Too many parse errors to bother processing. Whole file is probably messed up
				retVal = FAILED
				puts "Too many errors (#{MAX_NUM_ERRS}) in the annotation file.\nToo likely the whole file has the same error(s) on each line."
				if(@doCheckRefSeqs and @badRefSeqDetected) # then need to print good ref seqs 1st
					puts makeRefSeqStr()
				end
				puts "No merging attempted.\nHere is a sample of some of your formatting errors:\n\n"
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
			@validRefSeqs.keys.sort.each { |refSeq|
				length = @validRefSeqs[refSeq]
				refSeqStr += "#{refSeq}\t#{length}\n"
			}
			refSeqStr += "\n\n"
			return refSeqStr
		end

		# * *Function*: Massive method that does a lot of sexy work to merge LFF
		#   records according the user's settings. Calls lots of helper methods.
		#   Prints progress info to STDERR.
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
			# Go through sorted list of records and merge if appropriate
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
					# Fix tStart/tEnd if necessary
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
						# Check if seen already
						next if(@seenRecordIDs.key?(nextRecordID))
						status = getProceedStatus(nextRecordID, itNum)
						break if(status == STOP_LOOKING)
						next if(status == SKIP_RECORD)
						# else, we have to merge this new record! It passed the merging tests.
						# Record that we've dealt with this newRecordID
						@seenRecordIDs[nextRecordID] = ''
						mergeNewRecord(nextRecord, itNum)
						adjustPosStrandCount(nextRecord, itNum)
					end
					# Record raw span info, if appropriate
					getRawSpanData(itNum)
					# Does the merged record pass all our criteria? [ Record stats here as well ]
					doFilter = filterMergedRecord(itNum)
					next if(doFilter) # Filter the merged result right out...don't output it or anything
					                  # BUG ??? : Should we return all the merged ones back into the list of available annotations?????
					@mergedRecord.aggregateRecord[PHASE] = '.'
				end
				
				# track independent merges of data from same tName separately using a version number
				unless(@mergedRecordCounts.key?(@currQueryName))
					@mergedRecordCounts[@currQueryName] = 1
				else
					@mergedRecordCounts[@currQueryName] += 1
				end
				hitCount = @mergedRecordCounts[@currQueryName]
				# Fix the query name and phase
				@mergedRecord.aggregateRecord[TNAME] = "#{@currQueryName}.#{hitCount}#{@nameSuffices[itNum]}"
				# Output the "merged record" appropriately
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

		# * *Function*: Calculates span data on the current merged-record, including
		#   Span Ratio, span1 / span2, Span Delta.
		# * *Usage*   : <tt>  merger.getRawSpanData()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
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

		# * *Function*: Applies appropriate filters to the current merged-record and
		#   determines if it passes or fails them.
		# * *Usage*   : <tt>  merger.filterMergedRecord()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +true+  -> If the merged-record is filtered out.
		#   - +false+ -> If the merged-record is to be kept (not filtered).
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def filterMergedRecord(itNum)
			spanSizeFail  = (@doSpanSizeFiltering[itNum] ? spanSizeFilter(itNum) : false)
			minScoreFail, score = (@doMergedScoreFiltering[itNum] ? minScoreFilter(itNum) : NO_FAIL_VECTOR)
			numMembersFail, numMembers = (@doNumMembersFiltering [itNum] ? numMembersFilter(itNum) : NO_FAIL_VECTOR)
			spanRatioFail = ((@doSpanRatioFiltering[itNum] and @doReciprocalMerge[itNum]) ? spanRatioFilter(itNum) : false)
			minDensityFail = (@doDensityFiltering[itNum] ? minDensityFilter(itNum) : false)

			# All filters must pass
			pass = ! (spanSizeFail or minScoreFail or numMembersFail or spanRatioFail or minDensityFail)
			return !pass
		end

		# * *Function*: Check the number-of-members filter to the current merged-record.
		# * *Usage*   : <tt>  merger.numMembersFilter()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - Array:
		#     - +true+ | +false+  -> If there are too few members in the record (true) or not (false)
		#     - +size+            -> How many members it has.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def numMembersFilter(itNum)
			retVal = (@mergedRecord.recordsList.size < @minNumMembers[itNum])
			return [ retVal, @mergedRecord.recordsList.size ]
		end

		# * *Function*: Check the minimum-score filter to the current merged-record.
		# * *Usage*   : <tt>  merger.minScoreFilter()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - Array:
		#     - +true+ | +false+  -> If the record's score is too small (true) or not (false)
		#     - +size+            -> Record's score.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def minScoreFilter(itNum)
			retVal = (@mergedRecord.aggregateRecord[SCORE] < @minMergedScore[itNum])
			return [ retVal, @mergedRecord.aggregateRecord[SCORE] ]
		end

		# * *Function*: Check the minimum score denisty of the merged-record on the 2 genomes.
		# * *Usage*   : <tt>  merger.minDensityFilter  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +true+ | +false+  -> If the record's score density is too short on genome 1 or on genome 2 (true) or not (false).
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def minDensityFilter(itNum)
			if(@doReciprocalMerge[itNum])
				return	(	(@rawSpanDataRecord[SCORE_SPAN1] < @genome1MinDensity[itNum]) or
									(@rawSpanDataRecord[SCORE_SPAN2] < @genome2MinDensity[itNum])
								)
			else
				return (@rawSpanDataRecord[SCORE_SPAN1] < @genome1MinDensity[itNum])
			end
		end

		# * *Function*: Check the minimum-span-sizes filter to the current merged-record.
		# * *Usage*   : <tt>  merger.spanSizeFilter()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - +true+ | +false+  -> If the record's span is too short on genome 1 or on genome 2 (true) or not (false).
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def spanSizeFilter(itNum)
			if(@doReciprocalMerge[itNum])
				return ((@rawSpanDataRecord[SPAN1] < @genome1MinSpanSize[itNum]) or (@rawSpanDataRecord[SPAN2] < @genome2MinSpanSize[itNum]))
			else
				return (@rawSpanDataRecord[SPAN1] < @genome1MinSpanSize[itNum])
			end
		end

		# * *Function*: Check the minimum-Span-Ratio filter to the current merged-record.
		# * *Usage*   : <tt>  merger.spanRatioFilter()  </tt>
		# * *Args*    :
		#   - +none+
		# * *Returns* :
		#   - Array:
		#     - +true+ | +false+  -> If the record's Span Ratio is too small (span on 2 genomes too disparate) or not.
		#     - +size+          -> Record's score.
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def spanRatioFilter(itNum)
			return (@rawSpanDataRecord[SPAN_RATIO] < @minSpanRatio[itNum])
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
			# Are we just regrouping existing records?
			if(@groupExistingAnnotations[itNum])
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
			else # we are creating a new aggregate record to output
				# Adjust the class and type
				@mergedRecord.aggregateRecord[CLASSID] << @mergeClassSuffix
				@mergedRecord.aggregateRecord[TYPEID] << @mergeTypeSuffix
				# Fix the strandness as necessary.
				if(@orientationReflectsOrdering[itNum] and @doReciprocalMerge[itNum])
					# Then the "strand" needs to reflect relative-order and NOT sub-component orientation
					@mergedRecord.aggregateRecord[STRAND] = (@mergedRecord.relativeOrder == POS_ORDER ? '+' : '-')
				end
				if(!@orientationReflectsOrdering[itNum] and @noStrictOrientation[itNum] and (@mergedRecord.aggregateRecord[STRAND] != '.'))
					# Then we need an orientation dependent on sub-component orientation, and we haven't enforced
					# the same orientation throughout the aggregate, so let's derive an orientation.
					if(@posStrandCount >= 0)
						@mergedRecord.aggregateRecord[STRAND] = '+'
					else
						@mergedRecord.aggregateRecord[STRAND] = '-'
					end
				end
				# Write out the merged record
				strToWrite = @mergedRecord.aggregateRecord.join("\t")
				@writer.puts(strToWrite)
			end
			return
		end

		# * *Function*: Adjust the strand code for the merged LFF record using current
		#   merging stats.
		# * *Usage*   : <tt>  merger.adjustPosStrandCount(currRecord)  </tt>
		# * *Args*    :
		#   - +record+ -> The merged record to adjust the strand info for.
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +StandardError+ -> If strand column in record is not '.', +, or -.
		# --------------------------------------------------------------------------
		def adjustPosStrandCount(record, itNum)
			if(@noStrictOrientation[itNum] and (record[STRAND] != '.'))
				# Need to track number of + and - blocks seen
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

		# * *Function*: Merge a new LFF record in with the current merged record.
		# * *Usage*   : <tt>  merger.mergeNewRecord(newRecord)  </tt>
		# * *Args*    :
		#   - +newRecord+  -> The new LFF record to add to the current merged record.
		# * *Returns* :
		#   - +none+
		# * *Throws* :
		#   - +none+
		# --------------------------------------------------------------------------
		def mergeNewRecord(newRecord, itNum)
			# First, let's update the merged record.
			@mergedRecord.recordsList << newRecord.dup
			# If appropriate, update relative order of merged record
			if(@mergedRecord.relativeOrder.nil? and @doReciprocalMerge[itNum])
				@mergedRecord.relativeOrder = @mergedRecord.calcRelativeOrder(newRecord)
			end
			# new start and stop on refSeq
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
			# Deal with score
			@mergedRecord.aggregateRecord[SCORE] = @mergedRecord.aggregateRecord[SCORE] + newRecord[SCORE]
			# Update merge windows
			@genome1MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[RSTART] - @genome1MergeRadius[itNum], @mergedRecord.aggregateRecord[REND] + @genome1MergeRadius[itNum])
			if(@doReciprocalMerge[itNum])
				@genome2MergeWindow = BRL::Genboree::FullClosedWindow.new(@mergedRecord.aggregateRecord[TSTART] - @genome2MergeRadius[itNum], @mergedRecord.aggregateRecord[TEND] + @genome2MergeRadius[itNum])
			end
			return
		end

		# * *Function*: Determine if we should keep looking for LFF records to merge
		#   into the current one or not, or whether to just skip the current LFF record
		#   or add it.
		# * *Usage*   : <tt>  merger.getProceedStatus(nextRecordID)  </tt>
		# * *Args*    :
		#   - +nextRecordID+  ->  ID of the next LFF record to look consider.
		# * *Returns* :
		#   - <tt>BRL::Genboree::STOP_LOOKING</tt> -> If shouldn't look for any more records to merge with the current one.
		#   - <tt>BRL::Genboree::SKIP_RECORD </tt>  -> If should keep looking, but don't merge this next LFF record.
		#   - <tt>BRL::Genboree::MERGE_RECORD</tt> -> If should keep looking and merge this next LFF record.
		# * *Throws* :
		#   - +StandardError+ -> If the regular expression provided by the user doesn't
		#     correctly extract what it is supposed to.
		# --------------------------------------------------------------------------
		def getProceedStatus(nextRecordID, itNum)
			# DON't SCREW WITH ORDER OF THESE COMPARISIONS...the order is based on
			# (a) cheapness of comparision and (b) P(returning skip or stop)
			# EVEN IF YOU THINK IT'S UGLY or SOMETHING, GO AWAY! 0_o
			nextRecord = @lffRecords[nextRecordID]
			# Do we have the same refseq? If not, it should be time to stop looking, because we sorted on that.
			# This should speed things up too.
			return STOP_LOOKING unless(nextRecord[REFNAME] == @mergedRecord.aggregateRecord[REFNAME])
			# Check if refSeq name matches properly--sorted by refSeq name and then by start positioecord.aggregateRecord[REFNAME])
			# Check if range on refSeq is acceptable...stop looking if out of merge window
			return STOP_LOOKING unless((nextRecord[RSTART] <= @genome1MergeWindow.last) and (@genome1MergeWindow.first <= nextRecord[REND]))
			if(@doReciprocalMerge[itNum])
				# Check if range on query is acceptable (keep looking if out of this merge window, since not sorted on this)
				return SKIP_RECORD unless((nextRecord[TSTART] <= @genome2MergeWindow.last) and (@genome2MergeWindow.first <= nextRecord[TEND]))
			end
			# Check if type and subtype match properly
			return SKIP_RECORD unless(@mergeAllTypes or @typesToMerge.key?(nextRecord[TYPEID]))
			return SKIP_RECORD unless(@mergedRecord.aggregateRecord[TYPEID] == nextRecord[TYPEID])
			return SKIP_RECORD unless(@mergeAllSubTypes or @subTypesToMerge.key?(nextRecord[SUBTYPE]))
			return SKIP_RECORD unless(@mergedRecord.aggregateRecord[SUBTYPE] == nextRecord[SUBTYPE])

			if(@doReciprocalMerge[itNum] or @doRequireSameQueryIDs[itNum])
				# Check if query name matches properly
				nextRecord[TNAME] =~ @queryIDRE
				raise("\nERROR: bad regular expression '#{@queryIDRegExpStr}' provided by user via query.IDRegExp property. Must have a sub-expression that isolates the query name (such as #{nextRecord[TNAME]} from your file).\n") if($1.nil?)
				nextQueryName = $1
				return SKIP_RECORD unless(nextQueryName == @currQueryName)
			end
			unless(@noStrictOrientation[itNum])
				# Check that strands match
				return SKIP_RECORD unless((nextRecord[STRAND] == @mergedRecord.aggregateRecord[STRAND]) or (nextRecord[STRAND] == '.'))
			end
			unless(@noStrictOrdering[itNum] and @doReciprocalMerge[itNum])
				# Check that order matches
				unless(@mergedRecord.relativeOrder.nil?) # then we must have a relativeOrder
					nextRecordOrder = @mergedRecord.calcRelativeOrder(nextRecord)
					return SKIP_RECORD unless(nextRecordOrder == @mergedRecord.relativeOrder)
				end
			end
			# Need to consider (merge, actually) this record
			return MERGE_RECORD
		end

		def  tryToMergeAnnotation?(recordID, itNum)
			# DON't SCREW WITH ORDER OF THESE COMPARISIONS...the order is based on
			# (a) cheapness of comparision and (b) P(returning skip or stop)
			# EVEN IF YOU THINK IT'S UGLY or SOMETHING, GO AWAY! 0_o
			record = @lffRecords[recordID]
			# Check if type and subtype match properly
			return false unless(@mergeAllTypes or @typesToMerge.key?(record[TYPEID]))
			return false unless(@mergeAllSubTypes or @subTypesToMerge.key?(record[SUBTYPE]))
			return true
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
		def LFFMerger.processArguments
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
			LFFMerger.usage() if(optsHash.empty? or optsHash.key?('--help'));
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
		def LFFMerger.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

  PROGRAM DESCRIPTION:
	  Merges LFF records that are 'close' on the refSeq and on the query sequence
	  into 1 record. Can merge regardless of strand or be strand-sensitive. Takes
	  an LFF file.

	  This version supports multiple levels of merging of the same data. The output
	  is sent to a single file, as specified by the VGP team. The different levels of
	  merging can be identified using suffices on the 'name' columns, as requested.

    COMMAND LINE ARGUMENTS:
      -f    => LFF file to merge.
      -p    => Properties file to use for conversion parameters, etc.
      -r    => Ref seq file to verify entrypoints against.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    lffMerger_multiLevel.VGP.rb  -f annotations.lff -p merger.defaultTemplate.properties
	";
			exit(BRL::Genboree::USAGE_ERR);
		end # def LFFMerger.usage(msg='')
	end # class LFFMerger
end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::Genboree::LFFMerger.processArguments()
	$stderr.puts "#{Time.now()} MERGER - STARTING"
	merger = BRL::Genboree::LFFMerger.new(optsHash)
	exitVal = merger.iterativeMerge()
rescue Exception => err
	errTitle =  "#{Time.now()} MERGER - FATAL ERROR: The merger exited without processing the data, due to a fatal error.\n"
	msgTitle =  "FATAL ERROR: The merger exited without processing the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	puts msgTitle
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} MERGER - DONE" unless(exitVal != 0)
exit(exitVal)
