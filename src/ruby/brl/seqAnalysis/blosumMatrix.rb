#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# VERSION INFO
# ##############################################################################
# $Id$
# $Header: $
# $LastChangedDate$
# $LastChangedDate$
# $Change: $
# $HeadURL$
# $LastChangedRevision$
# $LastChangedBy$
# ##############################################################################

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'
require 'brl/util/textFileUtil'

module BRL ; module SeqAnalysis

class BlosumMatrix
	# Constants
	MATRIX_TYPE = 'BLOSUM'
	FWD,REV = 0,1
	
	# Attributes
	attr_accessor :rawMatrix, :aminoAcids, :clusterPercentage

  # Class instantiate from file
  def BlosumMatrix::initFromFile(blosumFile)
    reader = BRL::Util::TextReader.new(blosumFile)
    clusterPercentage = nil
    expScore = nil
    entropy = nil
    matrix = []
    sawHeader = false
    reader.each { |line|
      next if(line =~ /^\s*$/)
      if(line =~ /^\s*#/)
        if(line =~ /luster [pP]ercentage: >= (\d+)/)
          scale = $1.to_f
        end
        if(line =~ /xpected\s*=\s*([^ \t\n,]+)/)
          expScore = $1.to_f
        end
        if(line =~ /ntropy\s*=\s*([^ \t\n,]+)/)
          entropy = $1.to_f
        end
      else
        ff = line.split(/\s+/)
        ff.map! {|xx| xx.strip }
        matrix << ff
      end
    }
    reader.close
    return BlosumMatrix.new(matrix, clusterPercentage, expScore, entropy)
  end
  
  def initialize(matrix, clusterPercentage=0.0, expScore=0.0, entropy=0.0)
    @matrix = Hash.new { |hh,kk| hh[kk] = {} }
    @rawMatrix = matrix
    @clusterPercentage, @expScore, @entropy = clusterPercentage, expScore, entropy
    matrix[0].shift
    @aminoAcids = matrix[0]
    1.upto(matrix.size-1) { |ii|
      row = matrix[ii]
      aa2 = row.shift
      row.each_index { |jj|
        aa = @aminoAcids[jj]
        @matrix[aa][aa2] = row[jj]
      }
    }
  end
  
  def score(oldAA, newAA)
    return @matrix[oldAA.upcase][newAA.upcase]
  end

end	# class BlosumMatrix

end ; end

# ##############################################################################
# MAIN (test)
# ##############################################################################
if($0 == __FILE__)
  blosum = BRL::SeqAnalysis::BlosumMatrix.initFromFile(ARGV[0])
  puts blosum.score('A','A')
  puts blosum.score('I','W')
  puts blosum.score('X', 'S')
end
