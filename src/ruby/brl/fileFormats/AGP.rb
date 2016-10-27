#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes

module BRL ; module FileFormats	
	YES_RE = /^\s*yes\s*$/i
	GAP_TYPE_RE = /^\s*N\s*$/i
	NONGAP_TYPE_RE = /^\s*[A-MO-Z]\s*$/i
	COMMENT_RE = /^\s*#/
	U_ORIENT_RE = /^U$/i
	
	class AGPRecord
		attr_accessor :objName, :objStart, :objEnd, :partNum, :compType
	
		def initialize(arrayRec)
			@objName, @objStart, @objEnd, @partNum, @compType =
				arrayRec[0], arrayRec[1].to_i, arrayRec[2].to_i, arrayRec[3].to_i, arrayRec[4]
		end
		
		def to_s()
			return "#{@objName}\t#{@objStart}\t#{@objEnd}\t#{@partNum}\t#{@compType}"
		end
	end
	
	class AGPGapRecord < AGPRecord
		attr_accessor :gapLen, :gapType, :linkage
		
		def initialize(arrayRec)
			super(arrayRec)
			@gapLen, @gapType, @linkage = arrayRec[5].to_i, arrayRec[6], (arrayRec[7] =~ YES_RE ? true : false)
		end
		
		def to_s()
			return "#{super()}\t#{@gapLen}\t#{@gapType}\t#{@linkage ? 'yes' : 'no' }"
		end
		
		def to_lff(nameSuffix)
			return "Assembly\t#{@objName}_Gap#{nameSuffix.to_s}\tAssembly\tScaffolds\t#{@objName}\t#{@objStart}\t#{@objEnd}\t+\t.\t0.0"
		end
		
		def AGPGapRecord.isGapRecord?(arrayRec)
			return (!arrayRec.nil? and arrayRec.size < 9 and arrayRec[4] =~ GAP_TYPE_RE)
		end
	end
	
	class AGPNonGapRecord < AGPRecord
		attr_accessor :compID, :compStart, :compEnd, :orientation
		
		def initialize(arrayRec)
			super(arrayRec)
			@compID, @compStart, @compEnd, @orientation =
				arrayRec[5], arrayRec[6].to_i, arrayRec[7].to_i, arrayRec[8].chomp
		end
		
		def to_s()
			return "#{super()}\t#{@compID}\t#{@compStart}\t#{@compEnd}\t#{@orientation}"
		end
		
		def to_lff(nameSuffix)
			return "Assembly\t#{@compID}\tAssembly\tScaffolds\t#{@objName}\t#{@objStart}\t#{@objEnd}\t#{@orientation =~ U_ORIENT_RE ? '.' : @orientation}\t.\t1.0\t#{@compStart}\t#{@compEnd}"
		end
		
		def AGPNonGapRecord.isNonGapRecord?(arrayRec)
			return (!arrayRec.nil? and arrayRec.size >= 9 and arrayRec[4] != NONGAP_TYPE_RE)
		end
	end

end ; end
