#!/usr/bin/env ruby
$VERBOSE = true

=begin
This file implements the classes PGIIndex and PGIIndexArray within the *BRL::PGI* module.

*PGIIndex* takes as input a PGI record in the tab-delimited form or an array derived from
the tab-delimited form.  The fields of the PGI record become setable attributes of the
PGIIndex object.  The following attributes are directly related to the given PGI field:

     *Attribute = PGI Field
     *bacID = BacID
     *r1Pool = R1Pool
     *c1Pool = C1Pool
     *r2Pool = R2Pool
     *c2Pool = C2Pool
     *idxChr = IdxChr
     *idxWindowStart = IdxWindowStart
     *idxWindowEnd = IdxWindowEnd
     *idxStart = IdxStart
     *idxEnd = IdxEnd
     *isConfirmViaDirect = isConfirmViaDirect
     *r1NumHits = R1NumHits
     *c1NumHits = C1NumHits
     *r2NumHits = R2NumHits
     *c2NumHits = C2NumHits
     *numPoolsWithAtLeast1Hit = numPoolsWithAtLeast1Hit
     *readList = ReadList
     *readLengths = ReadLengths
     *readStarts = ReadStarts

The read-only attribute *numFields* is set to 19 which is the number of fields in a PGI record.

The following additional setable attributes are derived from the above attributes:

     *size
     *score

Three methods are available to retrieve multiple fields:

     *getAsArray
     *getAsLFFAnnotationString
     *to_s

Three setable attributes are used to override the default Class, Type and Subtype for *getAsLFFAnnotationString*.

      *Attribute = Default
      *lffClass = 'PGI'
      *lffType = 'similarity'
      *lffSubType = 'PGIHSP'

*PGIIndexArray* takes as input a string or IO containing multiple PGI records in the tab-delimited form.
Files can be plain text or Gzipped.  Individual PGI indices are instantiated as PGIIndex objects and pushed
onto PGIIndexArray which inherits from the Array object. The *outputLDASFile* method outputs the PGI
records as a file in the format used by LDAS (Lightweight Distributed Annotation Server) for annotation records.

*PGIParseError* is a class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : December 16, 2002
=end

require 'delegate'
require 'brl/util/util'         # ARJ 11/13/2002 12:27PM Make sure to include this to get Range extensions
require 'brl/util/textFileUtil'

module BRL; module PGI

	class PGIParseError < StandardError ; end

	class PGIIndex
		#Fields:  BacID <pool1 pool2 ...> IdxChr IdxWindowStart IdxWindowEnd IdxStart IdxEnd isConfirmViaDirect <numHitsPool1 numHitsPool2 ...> C1NumHits R2NumHits C2NumHits numPoolsWithAtLeast1Hit ReadList ReadLengths ReadStarts

		# Start and stop have automatic readers
		attr_accessor :idxStart, :idxEnd
		attr_accessor :bacID, :poolIDs
		attr_accessor :idxChr, :idxWindowStart, :idxWindowEnd, :isConfirmViaDirect
		attr_accessor :numHitsPerPool, :numPoolsWithAtLeast1Hit, :readList, :readLengths, :readStarts
		attr_accessor :lffClass, :lffType, :lffSubType, :scoreProc
		attr_accessor :numPools, :numFields

		CONFIRMED = 'true'
		UNCONFIRMED = 'false'
		NA = 'n.a.'

		def initialize(input=nil, numPools=nil, &scoreP)
			# ARJ 11/13/2002 12:32PM Always want to do this if handed a block (even if that's all we get)
			@scoreProc = (scoreP.nil? ? Proc.new {|pgiHit| pgiHit.numPoolsWithAtLeast1Hit();} : scoreP)
			@lffClass = 'PGI'
			@lffType = 'similarity'
			@lffSubType = 'PGIHSP'
			@numPools = numPools
			@poolIDs = []
			@numHitsPerPool = []
			# ARJ 11/13/2002 12:34PM => Is this the no-arg or 1-arg constructor?
			unless(input.nil?) # have an arg
				@numFields = 11 + (2*@numPools.to_i)
				# ARJ 11/8/2002 9:41AM => PGIIndex can be initialized from a String or an array. If not String, assume the input object acts like an array.
				if(input.kind_of?(String))
					# Split input and place fields in attributes if correct number of fields
					input.chomp!
					arrSplit = input.split(/\s+/)
				else # assume it is an array or array-like
					arrSplit = input
				end

				if arrSplit.length == @numFields # Then everything ok, parse it up
					@bacID = arrSplit[0]
					@numPools.times {
						|ii|
						@poolIDs.push(arrSplit[ii+1])
					}

					@idxChr, @idxWindowStart, @idxWindowEnd, @idxStart, @idxEnd, @isConfirmViaDirect = arrSplit.slice(@numPools+1, 6)
					@numPools.times {
						|ii|
						@numHitsPerPool.push(arrSplit[ii+7+@numPools])
					}
					@numPoolsWithAtLeast1Hit, @readList, @readLengths, @readStarts = arrSplit.slice(2*numPools+7, 4)
					@readList = @readList.split(/,/)
					@readLengths = @readLengths.split(/,/)
					@readStarts = @readStarts.split(/,/)
				else
					raise(PGIParseError, "\nERROR: Incorrect PGI format--source doesn't have #{@numFields} fields. Source was\n#{input.inspect}\n")
				end
			else # no args
				# Initialize attributes to nil if no input is supplied
				# ARJ 11/13/2002 12:30PM Here is a fun trick using parallel assignment. If many <-- one, then many[0] will equal one, and the rest of many will be all nil
				#                        So to get parallel nil assignment many <-- nil.
				@bacID, @poolIDs, @idxChr, @idxWindowStart, @idxWindowEnd, @idxStart, @idxEnd, @isConfirmViaDirect, @numHitsPerPool, @numPoolsWithAtLeast1Hit, @readList, @readLengths, @readStarts = nil
				@numFields = nil
			end
		end

		def size
			unless(tStart.nil? or tEnd.nil?)
				return tEnd.to_i - tStart.to_i
			else
				return 0
			end
		end

		def score
			@scoreProc.call(self)
		end

		def getAsArray()
			#Returns PGI fields as array
			getAsArray = @bacID, @r1Pool, @c1Pool, @r2Pool, @c2Pool, @idxChr, @idxWindowStart, @idxWindowEnd, @idxStart, @idxEnd, @isConfirmViaDirect, @r1NumHits, @c1NumHits, @r2NumHits, @c2NumHits, @numPoolsWithAtLeast1Hit, @readList, @readLengths, @readStarts
		end

		def getAsLFFAnnotationString(nameSuffix='', wholeHitIsAnnotation=true, refSequenceIsTarget=true)
			# LLF annotation records look like this:
			#class name    type       subtype      ref        start stop strand    phase   score   tstart  tend

			# ARJ 11/13/2002 12:41PM => currently, the LFF refSequence must be the target, the reverse is not supported (yet)
			unless(refSequenceIsTarget==true)
				raise(ArgumentError, "The target of the PGI Hit must be the LFF reference sequence; the reverse is not supported by this format.")
			end

			# Make the LFF string or strings, depending on what was asked for
			convertToLFF = ""
			if(wholeHitIsAnnotation)
				# Convert to 1 based full closed
				idxBStart = @idxStart.to_i + 1
				idxBEnd = @idxEnd
				convertToLFF = "#{@lffClass}\t#{bacID}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t" + @idxChr + "\t" + idxBStart.to_s + "\t" + idxBEnd.to_s + "\t+\t.\t" + @score + "\n"
			else # we need to make 1 annotation per block
				lastBlockIndex = @readList.size - 1

				@readList.each_index {
					|ii|
					# Convert to 1 based full closed
					idxBStart = @readStarts[ii].to_i + 1
					idxBEnd = @readStarts[ii].to_i + @readLengths[ii].to_i

				 convertToLFF +=
						"#{@lffClass}\t#{bacID}#{nameSuffix}\t#{@lffType}\t#{@lffSubType}\t" + @idxChr + "\t" + idxBStart.to_s + "\t" + idxBEnd.to_s + "\t+\t.\t" + self.score() + "\n"
				}
				return convertToLFF
			end
		end

		def to_s(isZeroBased = true)
				return asString = 	"#{@bacID}\t#{@r1Pool}\t#{@c1Pool}\t#{@r2Pool}\t#{@c2Pool}\t" +
														"#{@idxChr}\t#{@idxWindowStart}\t#{@idxWindowEnd}\t#{@idxStart}\t" +
														"#{@idxEnd}\t#{@isConfirmViaDirect}\t#{@r1NumHits}\t#{@c1NumHits}\t" +
														"#{@r2NumHits}\t#{@c2NumHits}\t#{@numPoolsWithAtLeast1Hit}\t" +
														"#{@readList.join(',')}\t#{@readLengths.join(',')}\t" +
														(isZeroBased ? @readStarts.join(',') : @readStarts.collect{|rStart| rStart+1}.join(',')) +
														"\n"
		end # def to_s

		alias length size
		alias first idxStart
		alias begin idxStart
		alias last idxEnd
		alias end idxEnd

	end # PGIIndex

	class PGIMultiHit < Array
		attr_accessor :headerRe
		attr_accessor :numPools, :scoreProc

		def initialize(inputSrc=nil, numPools=nil, &sProc)
			@numPools = numPools
			@scoreProc = sProc
			unless(inputSrc.nil?) # Then we have a source to read from
				# What does header look like?
				@headerRe = /BacID\t(?:[^\n\r\t ]+\t){#{numPools}, #{numPools}}IdxChr\tIdxWindowStart\tIdxWindowEnd\tIdxStart\tIdxEnd\tisConfirmViaDirect\t.+\tnumPoolsWithAtLeast1Hit\tReadList\tReadLengths\tReadStarts/

				# ARJ 11/13/2002 1:30PM => We let the source be a String, IO (including socket/file), or our TextReader
				#                          This means it will reply to "each" so we can walk through the lines.
				# ARJ 11/13/2002 1:31PM => NOTE: If the source has "issues", it may raise an IOError or something. Since
				#                                that is the user's fault, we'll let them rescue the situation.
				#                                We will re-raise the error but ensure the source is closed
				lineNum = 0
				begin
					if(inputSrc.kind_of?(String) or inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader)) # then init from string
						inputSrc.each {
							|line|
							if(lineNum == 0 and (line =~ @headerRe))
								raise(PGIParseError, "\nERROR: First line in the source must be a header line. Line was:\n#{line}\n")
							elsif(lineNum > 0)
								if(@scoreProc.nil?) then self.push(PGIIndex.new(line, @numPools)) else self.push(PGIIndex.new(line, @numPools, &@scoreProc)) end
							end
							lineNum+= 1
						}
					else # dunno the type
						raise(TypeError, "\nERROR: Cannot initialize a PGIMultiHit from #{inputSrc.type}. Try a String, IO, or BRL::Util::TextReader object.");
					end # if(source.kind_of?(String) or source.kind_of?(IO) or source.kind_of?(BRL::Util::TextReader))
				ensure
					inputSrc.close() unless(!inputSrc.respond_to?("close") or inputSrc.nil? or inputSrc.closed?)
				end # begin
			else # no-arg constructor
				@headerRe = nil
				super.new()
			end # unless(source.nil?)
		end # def initialize(inputSrc=nil, &sProc)

		def outputLDASFile(fileOut, wholeHitIsAnnotation=true, doPrintAnnotationHeader=true,doGzip=true)
			writer = BRL::Util::TextWriter.new(fileOut, doGzip)
			if(doPrintAnnotationHeader) then writer.write("[annotations]\n") end

			qCountHash = {}
			self.each {
				|pgiHit|
				bacid = pgiHit.bacID

				if(!qCountHash.key?(bacid))
					qCountHash[bacid] = 1
				else
					qCountHash[bacid] += 1
				end

				line = (wholeHitIsAnnotation ? pgiHit.getAsLFFAnnotationString(".#{qCountHash[bacid]}") : pgiHit.getAsLFFAnnotationString(".#{qCountHash[bacid]}", false, true) )
				#puts line
				writer.write("#{line}\n")
			}
			writer.close unless(writer.closed?)
		end
	end # class PGIMultiHit

end ; end #module BRL; module PGI
