#!/usr/bin/env ruby
require 'gsl'
require 'brl/util/util'
require 'brl/stats/linearRegression'

module BRL ; module Stats
  # ------------------------------------------------------------------
  # NORMALIZATION METHODS
  # ------------------------------------------------------------------
  # Compute quantile normalized versions of the vectors w.r.t. each other.
  # - all vectors MUST be the same size
  # - can take up to 3X total memory size of the input gslVectors while running,
  #   and 2X total memory size of input gslVectors when done
  # - returns an Array of GSL::Vectors with the normalized values
  def self.quantileNormalize(*gslVectors)
    vecSize = gslVectors.first.size
    numVectors = gslVectors.size
    # Array of GSL::Vectors to return:
    normalizedVectors = Array.new(numVectors)
    sameSize = true
    1.upto(numVectors - 1) { |jj| sameSize = false if(gslVectors[jj].size != vecSize) }
    if(sameSize)
      # What are the sort indices for each vector?
      # - i.e. at what index in a SORTED vector can the value be found?
      # - we'll also alloc the normalized vectors we'll be returning now
      vectorSortIndices = Array.new(numVectors)
      vectorRanks = Array.new(numVectors)
      numVectors.times { |jj|
        vectorSortIndices[jj] = gslVectors[jj].sort_index
        vectorRanks[jj] = vectorSortIndices[jj].inv # inv because we want the ranks, not the permutation
        normalizedVectors[jj] = GSL::Vector.alloc(vecSize)
      }
      # Need to compute the rank values from the sorted arrays
      # - i.e. the value to use for each rank, rather than the current raw values
      rankValues = GSL::Vector.alloc(vecSize)
      # - for each rank, compute average value at that rank
      vecSize.times { |ii|
        sum = 0.0
        numVectors.times { |jj|
          vector = gslVectors[jj]
          sum += vector[vectorSortIndices[jj][ii]]
        }
        rankValues[ii] = sum / numVectors
      }
      # Now create the quantile normalized vectors by using the rankValue rather than the value
      vecSize.times { |ii|
        # What are the ranks of the values in their respective vectors?
        numVectors.times { |jj|
          # Get values for those ranks. Use rank value in place of raw value
          rank = vectorRanks[jj][ii]
          normalizedVectors[jj][ii] = rankValues[rank]
        }
      }
    else # vector size mismatch
      raise "ERROR: All vectors must be of same size in order to be normalized."
    end
    return normalizedVectors
  end

  # Compute normalized versions of the vectors by mapping each to their gaussian
  # and taking the CDF at that point (1 - oneTailedPvalue)
  # - all vectors MUST be the same size
  # - can take up to 3X total memory size of the input gslVectors while running,
  #   and 2X total memory size of input gslVectors when done
  # - returns an Array of GSL::Vectors with the normalized values
  def self.gaussianNormalize(*gslVectors)
    vecSize = gslVectors.first.size
    numVectors = gslVectors.size
    normalizedVectors = Array.new(numVectors)
    sameSize = true
    1.upto(numVectors - 1) { |jj| sameSize = false if(gslVectors[jj].size != vecSize) }
    if(sameSize)
      # Compute mean & stdevs
      means = Array.new(numVectors)
      sds   = Array.new(numVectors)
      numVectors.times { |jj|
        means[jj] = gslVectors[jj].mean
        sds[jj]   = gslVectors[jj].sd
        normalizedVectors[jj] = GSL::Vector.alloc(vecSize)
      }
      vecSize.times { |ii|
        numVectors.times { |jj|
          # Get our raw and normalized vectors, and their mean & sd
          vector = gslVectors[jj]
          mean = means[jj]
          sd   = sds[jj]
          # Put in the gaussian CDF P-value
          normalizedVectors[jj][ii] = GSL::Cdf::gaussian_P((vector[ii] - mean) / sd)
        }
      }
    else # vector size mismatch
      raise "ERROR: All vectors must be of same size in order to be normalized."
    end
    return normalizedVectors
  end

  # ------------------------------------------------------------------
  # REGRESSION & FIT
  # ------------------------------------------------------------------
  # Perform linear regression on 2 GSL::Vectors
  # - returns an instance of BRL::Stats::LinearRegression which can be asked
  #   for linear regression components or to compute follow-up statistics
  def self.linearRegress(gslVector1, gslVector2)
    return BRL::Stats::LinearRegression.new(gslVector1, gslVector2)
  end
end ; end # module BRL ; module Stats
