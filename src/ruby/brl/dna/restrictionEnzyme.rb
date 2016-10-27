#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'

# http://www.neb.com/nebecomm/products_Intl/productR0136.asp
$VERBOSE = nil

module BRL ; module DNA

class RestrictionEnzyme
	attr_accessor :name, :fwdSeq, :revSeq, :fwdCutIdx, :revCutIdx
	attr_accessor :fwdRE, :revRE
	
	def initialize(name, fwdSeq, revSeq, fwdCutIdx, revCutIdx=nil)
		@name, @fwdSeq, @revSeq, @fwdCutIdx, @revCutIdx = name, fwdSeq, revSeq, fwdCutIdx, revCutIdx
		@revCutIdx = @fwdCutIdx if (@revCutIdx.nil?)
		@fwdRE = /#{@fwdSeq.to_s}/i
		@revRE = /#{@revSeq.to_s}/i
	end
	
	def size()
		return @fwdSeq.to_s.length
	end
	
end

class Not1 < RestrictionEnzyme
	def initialize()
		super('Not1', 'GCGGCCGC', 'CGCCGGCG', 1, 1)
	end
end

class Mse1 < RestrictionEnzyme
	def initialize()
		super('Mse1', 'TTAA', 'AATT', 0, 0)
	end
end

class Csp6I < RestrictionEnzyme
	def initialize()
		super('Csp6I', 'GTAC', 'CATG', 0, 0)
	end
end

class BamH1 < RestrictionEnzyme
  def initialize()
    super('BamH1', 'GGATCC', 'CCTAGG', 0, 0)
  end
end

end ; end
                