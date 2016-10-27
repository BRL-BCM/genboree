#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/dna/fastaRecord'

module BRL ; module Genboree

class FastaRecordRetriever
	# ############################################################################
	# CONSTANTS
	MAIN_GENB = 'genboree'
	
	OK, IDX_FILE_MISSING, NO_INDEX_LOADED =	0,1,2

	# ############################################################################
	# ATTRIBUTES
	# ############################################################################
	attr_accessor :fastaID, :indexFile, :err, :errMsg, :faIndexer
	
	# init
	def initialize(indexFile=nil)
		@indexFile = indexFile
		@faIndexer = BRL::DNA::FastaFileIndexer.new()
		@err = nil
	end
	
	# load indexFile
	def loadIndex()
		unless(@indexFile.nil? or !File.exists?(@indexFile.to_s))
			@faIndexer.loadIndex(@indexFile)
			return OK
		else # oh oh where is the index?
			@errMsg = "ERROR: Can't load index file '#{@indexFile}'"
			return @err = IDX_FILE_MISSING
		end
	end
	
	# getFastaRec by id
	def getFastaRec(fastaID)
		if(@faIndexer.fastaRecordIndices.nil? or @faIndexer.fastaRecordIndices.empty?)
			@errMsg = "ERROR: no index file has been loaded. Can't look anything up."
			return @err = NO_INDEX_LOADED
		else
			return @faIndexer.getFastaRecordStr(fastaID)
		end
	end
	
	# load resource -> indexFile map
	def loadIndexFileMap()
	
	end	
	
end # class FastaRecordRetriever

end ; end # module BRL ; module Genboree
