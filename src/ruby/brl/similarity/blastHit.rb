#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
This file implements the classes BlastHit and BlastMultiHit within the *BRL::Similarity* module.

*BlastHit* takes as input a Blast record in the tab-delimited form (-m 8) or an array derived from
the tab-delimited form.  BlastHit inherits from the Range object.  The fields of the Blast record
become setable attributes of the BlastHit object.  The following attributes are directly related
to the given Blast field:

     *Attribute = Blast Field
     *qName = Query id
     *tName = Subject id
     *percentIdentity = % identity
     *length = alignment length
     *numMismatches = mismatches
     *numGaps = gap openings
     *qStart = q. start
     *qEnd = q. end
     *sStart = s. start
     *sEnd = s. end
     *eValue = e-value
     *bitScore = bit score

The read-only attribute *numFields* is set to 12 which is the number of fields in a Blast record.

The following additional setable attributes are derived from the above attributes:

     *orientation
     *percentMismatches
     *percentGaps
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
      *lffClass = 'Blast'
			*lffType = 'similarity'
			*lffSubType = 'BlastHSP'

*BlastMultiHit* takes as input a file containing multiple Blast hit records in the tab-delimited (-m 8)
or tab-delimited with comment lines (-m 9) form.  The file can be plain text or Gzipped.  Individual
Blast hits are instantiated as BlastHit objects and pushed onto BlastMultiHit which inherits from the
Array object. The *outputLDASFile* method outputs the Blast hit records as a file in the format used by
LDAS (Lightweight Distributed Annotation Server) for annotation records.

*BlastParseError* is a private class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : November 11, 2002
=end

require 'brl/util/textFileUtil'

module BRL; module Similarity

#--------------------------------------------------------------------------------------------------------
#Class :  BlastHit
#Input :  input   = Blast record as either a tab-delimited string or array.  If no Blast record is supplied
#                   the attributes are initialized to nil.
#         &scoreP = User defined scoring procedure (optional).
#Usage :  BlastHit.new(Blast string or array, Scoring procedure)
#--------------------------------------------------------------------------------------------------------
	class BlastHit
		LFF_CLASS = :Blast
		LFF_TYPE = :Blast
		LFF_SUBTYPE = :Hit

		# Fields: Query id, Subject id, % identity, alignment length, mismatches, gap openings, q. start, q. end, s. start, s. end, e-value, bit score

		attr_accessor :qName, :tName, :percentIdentity, :length, :numMismatches, :numGaps, :qStart, :qEnd, :tStart, :tEnd, :eValue, :bitScore
		attr_accessor :lffClass, :lffType, :lffSubType, :scoreProc
		attr_reader :numFields

		# Number of fields in Blast file
		NUM_FIELDS = 12

		def initialize(input=nil, doValidate=false, &scoreP)
			@lffClass = LFF_CLASS
			@lffType = LFF_TYPE
			@lffSubType = LFF_SUBTYPE
			@scoreProc = (scoreP.nil? ? nil : scoreP)
      reinitialize(input, doValidate)
    end

    def reinitialize(input=nil, doValidate=false)
			@errorMsgs = ''
			if(input != nil)
				if(input.kind_of?(String))
					# Split input and place fields in attributes if correct number of fields
					input.chomp!
					arrSplit = input.split(/\s+/)
				else # input is an array
					arrSplit = input
				end

				@qName = arrSplit[0]
				@tName = arrSplit[1]
				@percentIdentity = arrSplit[2].to_f
				@length = arrSplit[3].to_i
				@numMismatches = arrSplit[4].to_i
				@numGaps = arrSplit[5].to_i
				@qStart = arrSplit[6].to_i
				@qEnd = arrSplit[7].to_i
				@tStart = arrSplit[8].to_i
				@tEnd = arrSplit[9].to_i
				@eValue = arrSplit[10].to_f
				@bitScore = arrSplit[11].to_f

				# Validate the input
				if(doValidate)
					valid = validateInput(arrSplit)
					unless(valid)
						# @errorMsgs.unshift("Incorrect format. Doesn't look like NCBI Blastall -m8 or -m9 format. You sure this a Blast hit?")
						raise(BlastParseError, @errorMsgs)
					end
				end

				# Convert to Zero Based Half Open
				@qStart = @qStart - 1
				if(self.orientation == "+")
					@tStart = @tStart - 1
				else
					@tEnd = @tEnd - 1
				end
			else # input == nil
				@qName, @tName, @percentIdentity, @length, @numMismatches, @numGaps, @qStart, @qEnd, @tStart, @tEnd, @eValue, @bitScore = nil
			end # if(input != nil)
		end

		def validateInput(fields)
			# Going to save up errors
			@errorMsgs += "  - Not a Blast hit record. Blast hits have #{NUM_FIELDS} columns. This has #{fields.size}.\n" if(fields.length < NUM_FIELDS)
			@errorMsgs += "  - Third column (% Identity) is not a positive real number: '#{fields[2]}'.\n" unless(@percentIdentity >= 0.0)
			@errorMsgs += "  - Fourth column (Align Length) is not a positive integer: '#{fields[3]}'.\n" unless(@length >= 0.0)
			@errorMsgs += "  - Fifth column (Mismatches) is not a positive integer: '#{fields[4]}'.\n" unless(@numMismatches >= 0.0)
			@errorMsgs += "  - Sixth column (# Gap Openings) is not a positive integer: '#{fields[5]}'.\n" unless(@numGaps >= 0.0)
			@errorMsgs += "  - Seventh column (Query Start) is not an integer: '#{fields[6]}'.\n" unless(fields[6] =~ /^\-?\d+$/)
			@errorMsgs += "  - Eighth column (Query End) is not an integer: '#{fields[7]}'.\n" unless(fields[7] =~ /^\-?\d+$/)
			@errorMsgs += "  - Nineth column (Target Start) is not an integer '#{fields[8]}'.\n" unless(fields[8] =~ /^\-?\d+$/)
			@errorMsgs += "  - Tenth column (Target End) is not an integer: '#{fields[9]}'.\n" unless(fields[9] =~ /^\-?\d+$/)
			# Fix score column if it starts with just 'e'...which means 1e, presumably
			if(fields[10] =~ /^e(?:\+|\-)?\d+/) then fields[10] = "1#{fields[10]}" ; @eValue = fields[10].to_f end
			@errorMsgs += "  - Eleventh column (E-Val) is not an real number: '#{fields[10]}'.\n" unless(fields[10] =~ /^\-?\d+(?:(?:\.\d+)?)|(?:e(?:\+|\-)?\d+)$/)
			@errorMsgs += "  - Twelfth column (Bitscore) is not an integer: '#{fields[11]}'.\n" unless(fields[11] =~ /^\-?\d+(?:(?:\.\d+)?)|(?:e(?:\+|\-)?\d+)$/)
			return ((@errorMsgs.nil? or @errorMsgs.empty?()) ? true : false)
		end

		def size ()
			unless(tStart.nil? or tEnd.nil?)
				return tEnd.to_i - tStart.to_i
			else
				return 0
			end
		end

		def orientation() # Orientation derived attribute
			if @tStart.to_f > @tEnd.to_f
				orientation = "-"
			else
				orientation = "+"
			end
		end

		def percentMismatches() # Percent Mismatches derived attribute
			percentMismatches = @numMismatches.to_f / @length.to_f * 100.0
		end

		def percentGaps() 	# Percent Gaps derived attribute
			percentGaps = @numGaps.to_f / @length.to_f * 100.0
		end

		def querySpan
			@qEnd - @qStart
		end

		def targetSpan
			@tEnd - @tStart
		end

		def score
			if(@scoreProc.nil?)
				return @bitScore
			else
				return @scoreProc.call(self)
			end
		end

		def zeroBasePos() #Zero Base Position derived attribute
			if self.orientation == "+"
				zeroBasePos = @tStart.to_i - @qStart.to_i
			else
				zeroBasePos = @tEnd.to_i - @qStart.to_i
			end
		end

		def getAsArray()
			# Returns Blast fields as array
			getAsArray = @qName, @tName, @percentIdentity, @length, @numMismatches, @numGaps, @qStart, @qEnd, @tStart, @tEnd, @eValue, @bitScore
		end

		def getAsLFFAnnotationString(nameSuffix='', refSequenceIsTarget=true)
			# LLF annotation records look like this:
			# class name    type       subtype      ref        start stop strand    phase   score   tstart  tend

			# Convert to 1 based for LFF
			qStart = @qStart + 1
			orientation = self.orientation()

		  if(@tStart <= @tEnd)
		    tStart, tEnd = @tStart + 1, @tEnd
		  else
		    tStart, tEnd = @tEnd + 1, @tStart
		  end

			if(refSequenceIsTarget == true)
				convertToLff = "#{@lffClass}\t#{@qName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@tName}\t#{tStart}\t#{tEnd}\t#{orientation}\t.\t#{sprintf('%.3f', self.score().to_f)}\t#{qStart}\t#{@qEnd}\n"
			else # query is ref seq
				convertToLff = "#{@lffClass}\t#{@tName}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t#{@qName}\t#{qStart}\t#{qEnd}\t#{orientation}\t.\t#{sprintf('%.3f', self.score().to_f)}\t#{tStart}\t#{@tEnd}\n"
			end
			return convertToLff
		end

		def to_s(isZeroBased = true)
			orientation = self.orientation

			if isZeroBased == false
				# Convert to 1 based
				qStart = @qStart + 1

				if orientation == "+"
					tStart = @tStart + 1
					tEnd = @tEnd
				else
					tEnd = @tEnd + 1
					tStart = @tStart
				end
			elsif isZeroBased == true
				qStart = @qStart
				tStart = @tStart
				tEnd = @tEnd
			else
				raise(TypeError, "Incorrect isZeroBased parameter. Must be true or false.")
			end

			to_s = @qName + "\t" +  @tName + "\t" + @percentIdentity.to_s + "\t" +  @length.to_s + "\t" + @numMismatches.to_s + "\t" +  @numGaps.to_s + "\t" +  qStart.to_s + "\t" +  @qEnd.to_s + "\t" + tStart.to_s + "\t" + tEnd.to_s + "\t" + @eValue.to_s + "\t" +  @bitScore.to_s
		end

		alias_method :to_lffStr, :getAsLFFAnnotationString
		#RAH - 10/24/05 Warning from aliasing length to size
		#alias_method :length, :size
		alias first tStart
		alias begin tStart
		alias last tEnd
		alias end tEnd
	end

#--------------------------------------------------------------------------------------------------------
#Class :  BlastMultiHit
#Input :  file    = Plain text or Gzipped file containing Blast records in -m 8 or -m 9 format.
#         &scoreP = User defined scoring procedure (optional).
#Usage :  BlastMultiHit.new(File, Scoring procedure)
#Dependencies:  BRL::Util::TextReader, BRL::Util::TextWriter
#--------------------------------------------------------------------------------------------------------
	class BlastMultiHit < Array

		def initialize(file, &scoreProc)

			if(FileTest.exist?(file) and FileTest.readable?(file))
				begin
					reader = BRL::Util::TextReader.new(file)

					reader.each {
						|line|
						# Skip comment lines
						if line !~ /^s*#/
							fields = line.split(/\s+/)
							if fields.length == 12
								if(scoreProc.nil?) then self.push(BlastHit.new(fields)) else self.push(BlastHit.new(fields, &scoreProc)) end
							end
						end
					}
	 			rescue Exception => err
					raise err
				ensure
					reader.close() unless(reader.nil? or reader.closed?)
				end
			else
				raise(IOError, "BLAST file does not exist or is not readable")
			end
		end

		def outputLDASFile(fileOut, doPrintAnnotationHeader=true, doGzip=true)
			writer = BRL::Util::TextWriter.new(fileOut, doGzip)
			if(doPrintAnnotationHeader) then writer.write("[annotations]\n") end

			qCountHash = {}
			self.each {
				|blastHit|
				qname = blastHit.qName
				if(!qCountHash.key?(qname))
					qCountHash[qname] = 1
				else
					qCountHash[qname] += 1
				end
				line = blastHit.getAsLFFAnnotationString(".#{qCountHash[qname]}")
				#puts line
				writer.write(line)
			}
			writer.close unless(writer.closed?)
		end
	end

	private

#--------------------------------------------------------------------------------------------------------
#Class :  BlastParseError
#Input :  Error message to be displayed to user.
#Output:  Outputs to StandardError.
#Usage :  raise(BlastParseError, "Error Message")
#--------------------------------------------------------------------------------------------------------
	class BlastParseError < StandardError ; end

end ; end # module BRL; module Similarity

