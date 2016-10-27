#!/usr/bin/env ruby
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

=begin
This file implements the classes LFF and LFFArray within the *BRL::FileFormats* module.

*LFF* takes as input a LFF record in the tab-delimited form or an array derived from
the tab-delimited form.  LFF is the load file format for the Lightweight Distibuted
Annotation Server.  The fields of the LFF record become setable attributes of the
LFF object.  The following attributes are directly related to the given LFF field:

     *Attribute = LFF Field
     
     *lffClass = class
     *gName = name
     *lffType = type
     *lffSubtype = subtype
     *chrom = ref
     *tStart = start
     *tEnd = stop
     *strand = strand
     *phase = phase
     *scoreField = score
     *qStart = tstart
     *qEnd = tend
     *aComment = attribute comments
     *sComment = sequence comment
     *fComment = freeform comments

The read-only attribute *numFields* is set to 12 which is the number of fields in a LFF record.

The following additional setable attribute is derived from the above attributes:

     *score

Two methods are available to retrieve multiple fields:

     *getAsArray
     *to_a
     *to_s

*LFFArray* takes as input a file containing multiple LFF records in the tab-delimited form.
Files can be plain text or Gzipped.  Individual LFF records are instantiated as LFF objects and pushed
onto LFFArray which inherits from the Array object.

*LFFParseError* is a class used for error handling that inherits from the StandardError object.

Author: Alan Harris <rharris1@bcm.tmc.edu>
      : Andrew R Jackson
Date  : December 16, 2002
      : 2006
=end

require "brl/util/textFileUtil"

module BRL; module FileFormats
	
	# ---------------------------------------------------------------------------
	# ERROR Classes
	# ---------------------------------------------------------------------------
  class LFFParseError < StandardError
    def message=(value)
      @message = value
    end
  end
  
 	# ---------------------------------------------------------------------------
	# Main LFF Class
	# ---------------------------------------------------------------------------
  class LFF
    NUM_FIELDS_PARTIAL = 10
    NUM_FIELDS_FULL = 15
    SPACE_REPLACE_STR = '_'
    
    # Fields: class name type subtype ref start stop strand phase score tstart tend
    attr_accessor :lffClass, :gName, :lffType, :lffSubtype, :chrom, :tStart, :tEnd
    attr_accessor :strand, :phase, :scoreField, :qStart, :qEnd
    attr_accessor :aComment, :sComment, :fComment

    def initialize(input=nil)
      unless(input.nil?)
        if(input.kind_of?(String))
          # Split input and place fields in attributes if correct number of fields
          input.chomp!
          arrSplit = input.split(/\t/)
        else #input is an array
          arrSplit = input
        end

        if((arrSplit.length >= NUM_FIELDS_PARTIAL) and (arrSplit.length <= NUM_FIELDS_FULL))
          @lffClass = arrSplit[0].to_sym
          @gName = arrSplit[1].to_sym
          @lffType = arrSplit[2].to_sym
          @lffSubtype = arrSplit[3].to_sym
          @chrom = arrSplit[4].to_sym
          @tStart = arrSplit[5].to_i
          @tEnd = arrSplit[6].to_i
          @strand = arrSplit[7].to_sym
          @phase = arrSplit[8].to_i
          @scoreField = (arrSplit[9].strip == '.') ? 1.0 : arrSplit[9].to_f
          @qStart = arrSplit[10]
          @qEnd = arrSplit[11]
          @aComment = arrSplit[12]
          @sComment = arrSplit[13]
          @fComment = arrSplit[14]

          # Convert so start < end
          if(@tStart > @tEnd)
            @tStart, @tEnd = @tEnd, @tStart
          end
          unless(@qStart.nil? or @qEnd.nil? or (@qStart.strip == '.') or (@qEnd.strip == '.'))
            @qStart = @qStart.to_i
            @qEnd = @qEnd.to_i
            if(@qStart > @qEnd)
              @qStart, @qEnd = @qEnd, @qStart
            end
          end
        else
          raise(LFFParseError, "\nERROR: Incorrect LFF Annontation format:\nINPUT: #{input.inspect}\nARRSPLIT: #{arrSplit.inspect}\n")
        end
      else
        @lffClass, @gName, @lffType, @lffSubtype, @chrom, @tStart, @tEnd, @strand, @phase, @scoreField, @qStart, @qEnd, @aComment, @sComment, @fComment = nil
      end
      return
    end

    def getAsArray()
      return self.to_a()
    end
    
    def to_a()
      return [ @lffClass, @gName, @lffType, @lffSubtype, @chrom, @tStart, @tEnd, @strand, @phase, @scoreField, @qStart, @qEnd, @aComment, @sComment, @fComment ]
    end

    def size
      unless(@tStart.nil? or @tEnd.nil?)
        return (@tEnd.to_i - @tStart.to_i) + 1
      else
        return 0
      end
    end

    def to_s(isZeroBased = false, replaceSpaces = false)
      if(isZeroBased)
        # Convert to 1 based
        tStart = @tStart + 1
        tEnd = @tEnd
        qStart, qEnd = nil
        if(@strand == :+ )
          qStart = @qStart + 1 unless(@qStart.nil?)
          qEnd = @qEnd
        elsif(@strand == :- )
          qEnd = @qEnd + 1 unless(@qEnd.nil?)
          qStart = @qStart
        end
      else
        tStart = @tStart
        tEnd = @tEnd
        qStart = @qStart
        qEnd = @qEnd
      end

      qEnd = '.' if(@qEnd.nil?)
      qStart = '.' if(@qStart.nil?)
      aComm = '.' if(@aComment.nil?)
      sComm = '.' if(@sComment.nil?)
      fComm = '.' if(@fComment.nil?)
      to_s =  "#{@lffClass}\t#{@gName}\t#{@lffType}\t#{@lffSubtype}\t#{@chrom}\t#{tStart}\t#{tEnd}\t" +
              "#{@strand}\t#{@phase}\t#{@scoreField}\t#{qStart}\t#{qEnd}\t#{aComm}\t#{sComm}\t#{fComm}"
      to_s.gsub!(/ +/, SPACE_REPLACE_STR) if(replaceSpaces)
      return to_s
    end
    
    alias length size
    alias first tStart
    alias begin tStart
    alias last tEnd
    alias end tEnd
    alias orientation strand
  end

	# ---------------------------------------------------------------------------
	# Array of LFF Objects
	# ---------------------------------------------------------------------------
  class LFFArray < Array
    @@headerStr = "#class\tname\ttype\tsubtype\tchrom\tstart\tstop\tstrand\tphase\tscore\tqstart\tqend\tattrComments\tseq\tfreeComments"

    def LFFArray.headerStr()
      return @@headerStr
    end

    def LFFArray.headerStr=()
      @@headerStr = headerStr
    end

    def initialize(file=nil)
      unless(file.nil?)
        if(FileTest.exist?(file) and FileTest.readable?(file))
          begin
            reader = BRL::Util::TextReader.new(file)
            reader.each { |line|
              self.push(LFF.new(line))
            }
          rescue Exception => err
            raise err
          ensure
            reader.close() unless(reader.nil? or reader.closed?)
          end
        else
          raise(IOError, "\nERROR: LFF file does not exist or is not readable\n")
        end
      end
    end
  end
end ; end #module BRL; module FileFormats
