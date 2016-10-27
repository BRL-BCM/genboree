#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
This file implements the classes BlatHit and BlatMultiHit within the *BRL::Similarity* module.

*BlatHit* takes as input a Blat record in the tab-delimited form  or an array derived from
the tab-delimited form.  BlatHit inherits from the Range object.  The fields of the Blat record
become setable attributes of the BlatHit object.  The following attributes are directly related
to the given Blat field:

     *Attribute = Blat Field
     *numMatches = match
     *numMismatches = mismatch
     *numRepeatMatches = rep. match
     *numNs = N's
     *qNumGaps = Q gap count
     *qNumGapBases = Q gap bases
     *tNumGaps = T gap count
     *tNumGapBases = t gap bases
     *orientation = strand
     *qName = Q name
     *qSize = Q size
     *qStart = Q start
     *qEnd = Q end
     *tName = T name
     *tSize = T size
     *tStart = T start
     *tEnd = T end
     *blockCount = block count
     *blockSizes = blockSizes
     *qBlockStarts = qStarts
     *tBlockStarts = tStarts

The read-only attribute *numFields* is set to 21 which is the number of fields in a Blat record.

The following additional setable attributes are derived from the above attributes:

     *length
     *lengthOfBlocks
     *percentMismatches
     *percentRepeatMatches
     *percentNs
     *percentGapBases
     *optimisticPercentIdentity
     *pessimisticPercentIdentity
     *queryPercentIdentity
     *querySpan
     *targetSpan
     *score
     *zeroBasePos

Three methods are available to retrieve multiple fields:

     *getAsArray
     *getAsLFFAnnotationString
     *to_s

Three setable attributes are used to override the default Class, Type and Subtype for *getAsLFFAnnotationString*.

     	*Attribute = Default
      *lffClass = 'Blat'
			*lffType = 'similarity'
			*lffSubType = 'BlatHSP'

*BlatMultiHit* takes as input a file containing multiple Blat hit records in the tab-delimited form.
The file can be plain text or Gzipped.  Individual Blat hits are instantiated as BlatHit objects and pushed
onto BlatMultiHit which inherits from the Array object. The *outputLDASFile* method outputs the Blat hit
records as a file in the format used by LDAS (Lightweight Distributed Annotation Server) for annotation records.

*BlatParseError* is a private class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : November 11, 2002
=end
require 'delegate'
require 'brl/util/util'           # ARJ 11/13/2002 12:27PM Make sure to include this to get Range extensions
require 'brl/util/textFileUtil'
require 'brl/util/logger'

module BRL; module Similarity

#--------------------------------------------------------------------------------------------------------
#Class :  BlatHit
#Input :  input   = Blat record as either a tab-delimited string or array.  If no Blat record is supplied
#                   the attributes are initialized to nil.
#         &scoreP = User defined scoring procedure (optional).
#Usage :  BlatHit.new(Blat string or array, Scoring procedure)
#--------------------------------------------------------------------------------------------------------
	class BlatHit
		LFF_CLASS = :Blat
		LFF_TYPE = :Blat
		LFF_SUBTYPE = :Hit

		# start and stop need auto readers only
		# attr_reader :tStart, :tEnd

		# ARJ 11/1/2002 11:29AM => For working with these attributes programmatically, make them have getters AND setters
		attr_accessor :numMatches, :numMismatches, :numRepeatMatches, :numNs, :qNumGaps, :qNumGapBases, :tNumGaps, :tNumGapBases, :orientation, :qName, :qSize,
			:qStart, :qEnd, :tName, :tSize, :tStart, :tEnd, :blockCount, :blockSizes, :qBlockStarts, :tBlockStarts
		# ARJ 11/1/2002 12:25PM => Allow user to override these strings, but initialize will make sensible defaults
		attr_accessor :lffClass, :lffType, :lffSubType, :scoreProc

		# Number of fields in Blat file
		# ARJ 11/1/2002 11:33AM => All instances of this class have this number of fields, so make it a class attribute.
		#                       => I've made it a read-only, since this is a defining characteristic of this object type
		NUM_FIELDS = 21

    def initialize(input=nil, doValidate=false, &scoreP)
			@lffClass = LFF_CLASS
			@lffType = LFF_TYPE
			@lffSubType = LFF_SUBTYPE
			# Can save mem here by using nil in most cases
			@scoreProc = (scoreP.nil? ? nil : scoreP)

      reinitialize(input, doValidate)
    end

		def reinitialize(input=nil, doValidate=false)
			@errorMsgs = ''

			if(input != nil)
				if(input.kind_of?(String))
					input.chomp!
					arrSplit = input.split(/\s+/)
				else # input is an array
					arrSplit = input
				end

				@numMatches = arrSplit[0].to_i
				@numMismatches = arrSplit[1].to_i
				@numRepeatMatches = arrSplit[2].to_i
				@numNs = arrSplit[3].to_i
				@qNumGaps = arrSplit[4].to_i
				@qNumGapBases = arrSplit[5].to_i
				@tNumGaps = arrSplit[6].to_i
				@tNumGapBases = arrSplit[7].to_i
				@orientation = arrSplit[8]
				@qName = arrSplit[9]
				@qSize = arrSplit[10].to_i
				@qStart = arrSplit[11].to_i
				@qEnd = arrSplit[12].to_i
				@tName = arrSplit[13]
				@tSize = arrSplit[14].to_i
				@tStart = arrSplit[15].to_i
				@tEnd = arrSplit[16].to_i
				@blockCount = arrSplit[17].to_i
				@blockSizes = arrSplit[18].to_s.split(/,/)
				@qBlockStarts = arrSplit[19].to_s.split(/,/)
				@tBlockStarts = arrSplit[20].to_s.split(/,/)

				# Validate the input
				if(doValidate)
					valid = validateInput(arrSplit)
					unless(valid)
						raise(BlatParseError, @errorMsgs)
					end
				end

				# ARJ 11/4/2002 11:09AM => Looks like blat from command line is 0-based, half open
				@qBlockStarts.map! { |qBlockStart| qBlockStart.to_i }
				@tBlockStarts.map! {|tBlockStart| tBlockStart.to_i }
				@blockSizes.map! { |blockSize| blockSize.to_i }
			else # Initialize attributes to nil if no input is supplied
				@numMatches, @numMismatches, @numRepeatMatches, @numNs, @qNumGaps, @qNumGapBases, @tNumGaps, @tNumGapBases, @orientation, @qName, @qSize, @qStart, @qEnd, @tName, @tSize, @tStart, @tEnd, @blockCount, @blockSizes, @qBlockStarts, @tBlockStarts = nil
			end
		end

		def validateInput(fields)
			# Going to save up errors
			@errorMsgs += "  - Not a Blat hit record. Blat hits have #{NUM_FIELDS} columns. This has #{fields.size}.\n" if(fields.length < NUM_FIELDS)
			@errorMsgs += "  - First column (Num Matches) is not a positive integer: '#{fields[0]}'.\n" unless(@numMatches > -1)
			@errorMsgs += "  - Second column (Num Mis-matches) is not a positive integer: '#{fields[1]}'.\n" unless(@numMismatches > -1)
			@errorMsgs += "  - Third column (Num Repeats) is not a positive integer: '#{fields[2]}'.\n" unless(@numRepeatMatches > -1)
			@errorMsgs += "  - Fourth column (Num Ns) is not a positive integer: '#{fields[3]}'.\n" unless(@numNs > -1)
			@errorMsgs += "  - Fifth column (Query Gaps) is not a positive integer: '#{fields[4]}'.\n" unless(@qNumGaps > -1)
			@errorMsgs += "  - Sixth column (Query Gap Bases) is not a positive integer: '#{fields[5]}'.\n" unless(@qNumGapBases > -1)
			@errorMsgs += "  - Seventh column (Target Gaps) is not a positive integer: '#{fields[6]}'.\n" unless(@tNumGaps > -1)
			@errorMsgs += "  - Eighth column (Target Gap Bases) is not a positive integer: '#{fields[7]}'.\n" unless(@tNumGapBases > -1)
			@errorMsgs += "  - Nineth column (Orientation) is not a + or - : '#{fields[8]}'.\n" unless(@orientation =~ /^[\+\-]$/)
			@errorMsgs += "  - Eleventh column (Query Size) is not a positive integer: '#{fields[10]}'.\n" unless(@qSize > -1)
			@errorMsgs += "  - Twelfth column (Query Start) is not an integer: '#{fields[11]}'.\n" unless(fields[11] =~ /^\-?\d+$/)
			@errorMsgs += "  - Thirteenth column (Query End) is not an integer: '#{fields[12]}'.\n" unless(fields[12] =~ /^\-?\d+$/)
			@errorMsgs += "  - Fifthteenth column (Target Size) is not an integer: '#{fields[14]}'.\n" unless(fields[14] =~ /^\-?\d+$/)
			@errorMsgs += "  - Sixteenth column (Target Start) is not an integer: '#{fields[15]}'.\n" unless(fields[15] =~ /^\-?\d+$/)
			@errorMsgs += "  - Seventeenth column (Target End) is not an integer: '#{fields[16]}'.\n" unless(fields[16] =~ /^\-?\d+$/)
			@errorMsgs += "  - Eighteenth column (Num Blocks) is not a positive integer: '#{fields[17]}'.\n" unless(@blockCount > -1)
			@errorMsgs += "  - Nineteeth column (Block Sizes) doesn't look like a list of block sizes.\n" unless(fields[18] =~ /^(?:\d+\,)*\d+\,?$/)
			@errorMsgs += "  - Twentieth column (Query Block Starts) doesn't look like a list of block starts.\n" unless(fields[19] =~ /^(?:-?\d+\,)*\-?\d+\,?$/)
			@errorMsgs += "  - Twenty-first column (Target Block Starts) doesn't look like a list of block starts.\n" unless(fields[20] =~ /^(?:-?\d+\,)*\-?\d+\,?$/)
			return (@errorMsgs.nil? or @errorMsgs.empty?())
		end

		def size
			unless(tStart.nil? or tEnd.nil?)
				return tEnd.to_i - tStart.to_i
			else
				return 0
			end
		end

		def lengthOfBlocks() # Length of Blocks derived attribute
			sum = 0
			for size in @blockSizes
				sum = sum + size.to_i
			end
			length = sum
		end

		def percentMismatches() # Percent Mismatches derived attribute
			percentMismatches = @numMismatches.to_f / self.length  * 100.0
		end

		def percentRepeatMatches() # Percent Repeat Matches derived attribute
			percentRepeatMatches = @numRepeatMatches.to_f  / self.length  * 100.0
		end

		def percentNs() # Percent Ns derived attribute
			percentNs = @numNs.to_f  / self.length  * 100.0
		end

		def percentGapBases() # Percent Gaps derived attribute
			percentGapBases = (@qNumGapBases.to_f / self.querySpan)  * 100.0
		end
    
    def percentQueryGapBases()
      return percentGapBases()
    end
    
    def percentTargetGapBases()
      percentGapBases = (@tNumGapBases.to_f / self.targetSpan) * 100.0 
    end
    
		def optimisticPercentIdentity()	# Optimistic Percent Identity derived attribute
			optimisticPercentIdentity = @numMatches.to_f  / self.lengthOfBlocks  * 100.0
		end

		def pessimisticPercentIdentity() # Pessimistic Percent Identity derived attribute
			pessimisticPercentIdentity = @numMatches.to_f  / self.length * 100.0
		end

		def queryPercentIdentity()
			# Percent of Query having Identity with target
			@numMatches.to_f / @qSize * 100
		end

		def querySpan
			@qEnd - @qStart
		end

		def targetSpan
			@tEnd - @tStart
		end

		def alignScore(matchReward=2, mismatchPenalty=1, gapOpenPenalty=2, gapExtension=1)
			score = 0
			score += (matchReward*@numMatches)
			score -= (mismatchPenalty*@numMismatches)
			score -= (gapOpenPenalty*@qNumGaps)
			if(@qNumGapBases > 0)
				score -= (gapExtension*(@qNumGapBases-@qNumGaps))
			end
			return score
		end

		def score
			if(@scoreProc.nil?)
				return self.alignScore()
			else
				return @scoreProc.call(self)
			end
		end

		def zeroBasePos() # Zero Base Position derived attribute
			if @orientation == "+"
				zeroBasePos = @tStart.to_i - @qStart.to_i
			else
				zeroBasePos = @tEnd.to_i - @qStart.to_i
			end
		end

		def getAsArray() # Returns Blat fields as array
			getAsArray = @numMatches, @numMismatches, @numRepeatMatches, @numNs, @qNumGaps, @qNumGapBases, @tNumGaps, @tNumGapBases, @orientation, @qName, @qSize, @qStart, @qEnd, @tName, @tSize, @tStart, @tEnd, @blockCount, @blockSizes, @qBlockStarts, @tBlockStarts
		end

		# ARJ 11/1/2002 12:21PM => Name this as appropriate...but it returns a String.
		# ARJ 11/1/2002 4:11PM => added nameSuffix, which tacks a string onto the 'name' lff column. This is useful for making hits unique so they aren't grouped unintentionally.
		# ARJ 11/1/2002 4:14PM => either the whole hit should be an annotation OR each block needs to be an annotation grouped by a unique 'name'
		def getAsLFFAnnotationString(useAlignScore=true, nameSuffix='', wholeHitIsAnnotation=true, refSequenceIsTarget=true)
			# LLF annotation records look like this:
			# class name    type       subtype      ref        start stop strand    phase   score   tstart  tend
			if(wholeHitIsAnnotation)
				# Looks like blat hits are already 0-based, half-open
				# Convert to 1 based full closed
				qStart = @qStart + 1
				tStart = @tStart + 1

				# ARJ 11/1/2002 12:28PM => This now uses the new instance attributes lff*
				if(refSequenceIsTarget == true)
					convertToLff = "#{@lffClass}\t#{@qName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@tName}\t#{tStart}\t#{@tEnd}\t#{@orientation}\t.\t#{useAlignScore ? self.alignScore() : self.score}\t#{qStart}\t#{@qEnd}\n"
				else # query is the refSeq
					convertToLff = "#{@lffClass}\t#{@tName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@qName}\t#{qStart}\t#{@qEnd}\t#{@orientation}\t.\t#{useAlignScore ? self.alignScore() : self.score()}\t#{tStart}\t#{@tEnd}\n"
				end
				return convertToLff
			else # we need to make 1 annotation per block
				convertToLff = ''
				blockCount = 1
				lastBlockIndex = @tBlockStarts.size - 1
				@tBlockStarts.each_index { |ii|
					# Looks like blat hits are already 0-based, half-open
					# Convert to 1 based full closed
					qBStart = @qBlockStarts[ii] + 1
					qBEnd = @qBlockStarts[ii] + @blockSizes[ii]
					tBStart = @tBlockStarts[ii] + 1
					tBEnd = @tBlockStarts[ii]. + @blockSizes[ii]
					# ARJ 11/1/2002 12:28PM => This now uses the new instance attributes lff*
					if(refSequenceIsTarget == true)
						convertToLff +=
							"#{@lffClass}\t#{@qName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@tName}\t#{tBStart}\t#{tBEnd}\t#{@orientation}\t.\t#{useAlignScore ? self.alignScore() : self.score()}\t#{qBStart}\t#{qBEnd}\n"
					else # query is the refSeq
						convertToLff +=
							"#{@lffClass}\t#{@tName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@qName}\t#{qBStart}\t#{qBEnd }\t#{@orientation}\t.\t#{useAlignScore ? self.alignScore() : self.score()}\t#{tBStart}\t#{tBEnd}\n"
					end
					blockCount += 1
				}
				return convertToLff
			end
		end

		def to_s()
			asString = 	"#{@numMatches}\t#{@numMismatches}\t#{@numRepeatMatches}\t" +
									"#{@numNs}\t#{@qNumGaps}\t#{@qNumGapBases}\t#{@tNumGaps}\t" +
									"#{@tNumGapBases}\t#{@orientation}\t#{@qName}\t#{@qSize}\t" +
									"#{@qStart}\t#{@qEnd}\t#{@tName}\t#{@tSize}\t" +
									"#{@tStart}\t#{@tEnd}\t#{@blockCount}\t#{@blockSizes.join(',')},\t" +
									"#{@qBlockStarts.join(',')},\t#{@tBlockStarts.join(',')},\n"
			return asString
		end # def to_s

		alias_method :to_lffStr, :getAsLFFAnnotationString
		alias_method :length, :size
		alias first tStart
		alias begin tStart
		alias last tEnd
		alias end tEnd
	end # BlatHit

	# ARJ 11/1/2002 12:44PM => If we inherit from array, we get all sorts of fun methods as well!!
	#													 Also, user can control contents, add, delete, sort, the array of hits!
#--------------------------------------------------------------------------------------------------------
#Class :  BlatMultiHit
#Input :  file    = Plain text or Gzipped file containing Blat records.
#         &scoreP = User defined scoring procedure (optional).
#Usage :  BlatMultiHit.new(File, Scoring procedure)
#Dependencies:  BRL::Util::TextReader, BRL::Util::TextWriter
#--------------------------------------------------------------------------------------------------------
	class BlatMultiHit < Array
		attr_reader :headerStr
		attr_accessor :scoreProc
		@@headerStr = "psLayout version 3\n\nmatch   mis-    rep.    N's     Q gap   Q gap   T gap   T gap   strand  Q               Q       Q       Q       T               T       T       T       block   blockSizes      qStarts  tStarts\n        match   match           count   bases   count   bases           name            size    start   end     name            size    start   end     count\n---------------------------------------------------------------------------------------------------------------------------------------------------------------\n"
		HEADER_RE = /^(?:psLayout|match|\s+match|-+)/

		def initialize(inputSrc=nil, &sProc)
			@scoreProc = sProc
			unless(inputSrc.nil?) # Then we have a source to read from
				# ARJ 11/13/2002 1:30PM => We let the source be a String, IO (including socket/file), or our TextReader
				#                          This means it will reply to "each" so we can walk through the lines.
				# ARJ 11/13/2002 1:31PM => NOTE: If the source has "issues", it may raise an IOError or something. Since
				#                                that is the user's fault, we'll let them rescue the situation.
				#                                We will re-raise the error but ensure the source is closed
				lineNum = 0
				additionalHeaderLines = (0..4)
				begin
					if(inputSrc.kind_of?(String) or inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader)) # then init from string
							inputSrc.each {
								|line|
								lineNum += 1
								line.strip!
								next if(line =~ /^\s*$/)
								next if(line =~ HEADER_RE)
								# if(lineNum==0 and (line !~ /3\s*$/))
								# raise(BlatParseError, "ERROR: Incorrect version of BLAT. BLAT Version 3 should be used. Header is required. Line found:\n>>\n#{line}\n<<\n")
								# elsif(additionalHeaderLines===lineNum) # Then we're in other header lines we don't care about
								# lineNum+=1
								# next
								# else

								# we have an actual blat hit
									fields = line.split(/\s+/)
							  	if fields.length >= BRL::Similarity::BlatHit::NUM_FIELDS # the everything ok enough...extra fields ignored
							    	if(@scoreProc.nil?) then self.push(BlatHit.new(fields)) else self.push(BlatHit.new(fields, &@scoreProc)) end
							    else
							    	raise(BlatParseError, "ERROR: Bad blat record. BLAT Version 3 should be used. Line Number: #{lineNum}. Line found:\n>>\n#{line}\n<<\n")
						    	end
						    # end
					    }
					else
						raise(TypeError, "Cannot initialize a BlatMultiHit from #{inputSrc.type}. Try a String, IO, or BRL::Util::TextReader object.");
					end # if(source.kind_of?(String) or source.kind_of?(IO) or source.kind_of?(BRL::Util::TextReader))
				rescue Exception => err
					raise err
				ensure
					reader.close() unless(inputSrc.respond_to?('close') or reader.nil? or reader.closed?)
				end # begin
			else # no-arg constructor
				super.new()
			end # unless(inputSrc.nil?)
		end # def initialize(inputSrc, &sProc)

		def BlatMultiHit.headerStr()
			return @@headerStr
		end

		# ARJ 11/1/2002 4:14PM => either the whole hit should be an annotation OR each block needs to be an annotation grouped by a unique 'name'
		# ARJ 11/1/2002 4:17PM => choice of whether to print annotation header (if concatenating files, probably you don't want it... :)
		def outputLDASFile(fileOut, wholeHitIsAnnotation=true, doPrintAnnotationHeader=true, doGzip=true)
			writer = BRL::Util::TextWriter.new(fileOut, doGzip)
			if(doPrintAnnotationHeader) then writer.write("[annotations]\n") end

				qCountHash = {}
				self.each {
					|blatHit|
					qname = blatHit.qName
					if(!qCountHash.key?(qname))
						qCountHash[qname] = 1
					else
						qCountHash[qname] += 1
					end
					line = (wholeHitIsAnnotation ? blatHit.getAsLFFAnnotationString(".#{qCountHash[qname]}") : blatHit.getAsLFFAnnotationString(".#{qCountHash[qname]}", false, true) )
					writer.write("#{line}\n")
				}
				writer.close unless(writer.closed?)
		end
	end # class BlatMultiHit

	private

#--------------------------------------------------------------------------------------------------------
#Class :  BlatParseError
#Input :  Error message to be displayed to user.
#Output:  Outputs to StandardError.
#Usage :  raise(BlatParseError, "Error Message")
#-------------------------------------------------------------------------------------------------------
	# ARJ 11/1/2002 11:38AM => By having specific Exception Classes, users of the library can
	#                       => rescue these specific errors and do the right thing in those
	#                       => cases, while letting other StandardErrors not be rescued or
	#												=> handled differently.

	class BlatParseError < StandardError ; end

end ; end # module BRL; module Similarity

