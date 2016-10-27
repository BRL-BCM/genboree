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
class PamMatrix
	# Constants
	MATRIX_TYPE = 'PAM'
	FWD,REV = 0,1

	# Attributes
	attr_accessor :rawMatrix, :aminoAcids, :scale, :expScore, :entropy

  # Class instantiate from file
  def PamMatrix::initFromFile(pamFile)
    reader = BRL::Util::TextReader.new(pamFile)
    scale = nil
    expScore = nil
    entropy = nil
    matrix = []
    sawHeader = false
    reader.each { |line|
      next if(line =~ /^\s*$/)
      if(line =~ /^\s*#/)
        if(line =~ /scale\s*=\s*[^=]+=\s*(\S+)/)
          scale = $1.to_f
        end
        if(line =~ /xpected score\s*=\s*([^ \t\n,]+)/)
          expScore = $1.to_f
        end
        if(line =~ /ntropy\s*=\s*(\S+)/)
          entropy = $1.to_f
        end
      else
        ff = line.split(/\s+/)
        ff.map! {|xx| xx.strip }
        matrix << ff
      end
    }
    reader.close
    return PamMatrix.new(matrix, scale, expScore, entropy)
  end
  
  def initialize(matrix, scale=0.0, expScore=0.0, entropy=0.0)
    @matrix = Hash.new { |hh,kk| hh[kk] = {} }
    @rawMatrix = matrix
    @scale, @expScore, @entropy = scale, expScore, entropy
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

end	# class PamMatrix

end ; end

# ##############################################################################
# MAIN (test)
# ##############################################################################
if($0 == __FILE__)
  pam = BRL::SeqAnalysis::PamMatrix.initFromFile(ARGV[0])
  puts pam.score('A','A')
  puts pam.score('I','W')
  puts pam.score('X', 'S')
end
