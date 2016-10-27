#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
This file implements the classes GFF and GFFArray within the *BRL::FileFormats* module.

*GFF* takes as input a GFF record in the tab-delimited form or an array derived from
the tab-delimited form.  The fields of the GFF record become setable attributes of the 
GFF object.  The following attributes are directly related to the given GFF field:

     *Attribute = GFF Field
     *seqname =seqname
     *source = source
     *feature = feature
     *start = start
     *end = end
     *scoreField = score
     *strand = strand
     *frame = frame
     *attributes = attributes

The read-only attribute *numFields* is set to 9 which is the number of fields in a GFF record.

The following additional setable attribute is derived from the above attributes:

     *score
 
Two methods are available to retrieve multiple fields:

     *getAsArray
     *to_s

*GFFArray* takes as input a file containing multiple GFF records in the tab-delimited form.
Files can be plain text or Gzipped.  Individual GFF records are instantiated as GFF objects and pushed
onto GFFArray which inherits from the Array object. 

*GFFParseError* is a class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
Date  : December 16, 2002
=end

require "brl/util/textFileUtil"

module BRL; module FileFormats

	class GFFParseError < StandardError ; end

	class GFF
		# Fields: seqname source feature start end score strand frame attributes

		attr_accessor :seqname, :source, :feature, :start, :end, :scoreField, :strand, :frame, :attributes
		attr_accessor :scoreProc
		attr_reader :numFields

		#Number of fields in GFF file
		@@numFields = 9

		def initialize(input=nil, &scoreP)
			@scoreProc = (scoreP.nil? ? Proc.new {|gffRecord| gffRecord.scoreField();} : scoreP)

			if (input != nil)
				if (input.kind_of?(String))
					#Split input and place fields in attributes if correct number of fields
					input.chomp!
					arrSplit = input.split(/\t/)
				else #input is an array
					arrSplit = input
				end

				if arrSplit.length == @@numFields
					@seqname, @source, @feature, @start, @end, @scoreField, @strand, @frame, @attributes = arrSplit

					#Convert to Zero Based Half Open
					@start = @start.to_i - 1
				else
					raise(GFFParseError, "\nERROR: Incorrect GFF format for this record:\n#{arrSplit.join('    ')}\n")
				end
			else
				@seqname, @source, @feature, @start, @end, @scoreField, @strand, @frame, @attributes = nil
			end
		end

		def score
			@scoreProc.call(self)
		end

		def getAsArray()
			#Returns GFF fields as array
			getAsArray = @seqname, @source, @feature, @start, @end, @scoreField, @strand, @frame, @attributes
		end

		def to_s(isZeroBased = true)

			if isZeroBased == false
				#Convert to 1 based
				start = @start + 1

			elsif isZeroBased == true
				start = @start
			else
				raise(TypeError,  "\nERROR: Incorrect isZeroBased parameter.\n")
			end

			to_s = @seqname + "\t" +  @source+ "\t" + @feature + "\t" +  start.to_s + "\t" + @end + "\t" +  scoreField + "\t" +  @strand + "\t" +  @frame + "\t" + @attributes
		end
	end

	class GFFArray < Array

		def initialize(file=nil)
			if (file != nil)
				if(FileTest.exist?(file) and FileTest.readable?(file))
					begin
						reader = BRL::Util::TextReader.new(file)
						reader.each {
							|line|
							test = line.split(/\t+/)
							if test.length == 9
								self.push(GFFRecord.new(line))
							end
					}
					rescue Exception => err
						raise err
					ensure
						reader.close() unless(reader.nil? or reader.closed?)
					end
				else
					raise(IOError, "\nERROR: GFF file does not exist or is not readable.\n")
				end
			end
		end

	end #class GFFRecordArray

end; end #module BRL; module FileFormats

