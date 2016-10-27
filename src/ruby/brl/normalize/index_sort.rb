require 'gsl'
require 'brl/stats/stats'

class IndexSort
  DEFAULT_BUFFER_SIZE = (500 * 1024 * 1024)

  attr_accessor :bufferSize
  attr_accessor :timeHash
  attr_accessor :vectors

  def initialize(*vectors)
    @vectors = vectors
    @bufferSize = DEFAULT_BUFFER_SIZE
    @timeHash = Hash.new { |hh,kk| hh[kk] = 0 }
  end

  def clear()
    @vectors = nil
    @timeHash = Hash.new { |hh,kk| hh[kk] = 0 }
  end

  def printTiming(io)
    @timeHash.each_key { |key|
      io.puts "#{key} => #{@timeHash[key]}"
    }
  end

  def runSort(cmd)
    retVal = system(cmd)
    unless(retVal)
      raise "ERROR: the following unix sort command failed with exit status #{$?.exitstatus.inspect}\n    #{cmd}"
    end
    return retVal
  end

  ##This method indirectly sorts the elements of the vector self into ascending order,
  ##and returns the resulting permutation. The elements of permutation give the index
  ##of the vector element which would have been stored in that position if the vector
  ##had been sorted in place. The first element of permutation gives the index of the
  ##least element in the vector, and the last element of permutation gives the index
  ##of the greatest vector element. The vector self is not changed.
  #
  # WARNING: this method is OLD and NOT TOO USEFUL. Only does first 2 vectors, not all N vectors
  #
  def sort_index()
    t2 = Time.now
    retVal = nil
    begin
      mVec1, mVec2 = @vectors[0], @vectors[1]
      if(mVec1.size == mVec2.size)
        file1 = File.open("tempValueFile1", "w+")
        file2 = File.open("tempValueFile2", "w+")
        mVec1.size.times { |ii|
          file1.puts "#{mVec1[ii]}\t#{ii}"
          file2.puts "#{mVec2[ii]}\t#{ii}"
        }
        file1.close
        file2.close

        cmd = "sort --buffer-size=#{@bufferSize}b -k1n tempValueFile1 > sortedTempValueFile1"
        runSort(cmd)
        cmd = "sort --buffer-size=#{@bufferSize}b -k1n tempValueFile2 > sortedTempValueFile2"
        runSort(cmd)

        readFile1 = File.new("sortedTempValueFile1")
        readFile2 = File.new("sortedTempValueFile2")
        rankVector1 = GSL::Vector.alloc(mVec1.size)
        rankVector2 = GSL::Vector.alloc(mVec1.size)
        rr = /^\S+\t(\d+)$/
        mVec1.size.times { |ii|
          line1 = readFile1.readline
          line2 = readFile2.readline
          line1 =~ rr
          rankVector1[ii] = $1.to_f
          line2 =~ rr
          rankVector2[ii] = $1.to_f
        }
        readFile1.close
        readFile2.close

        @returnArray = []
        @returnArray[0] = rankVector1
        @returnArray[1] = rankVector2
        File.delete("sortedTempValueFile1")
        File.delete("sortedTempValueFile2")
        File.delete("tempValueFile1")
        File.delete("tempValueFile2")
        retVal = @returnArray
      else
        retVal = "Size of two vectors should be equal"
      end
    rescue => err
      $stderr.puts "ERROR: #{self.class}##{__method__}: an exception was raised and caught. Msg: #{err.message}\n#{err.backtrace.join("\n")}"
    end
    @timeHash['TOTAL sort_index time'] += (Time.now - t2)
    return retVal
  end

  ##returns an array of two vectors normalized by rank
  #
  # WARNING: this method is OLD. Only does first 2 vectors, not all N vectors. Needs updating. Needs to check same size too.
  def rankNormalized()
    mVec1, mVec2 = @vectors[0], @vectors[1]
    returnArray = []
    rankNormalizedVector1 = GSL::Vector.alloc(mVec1.size)
    rankNormalizedVector2 = GSL::Vector.alloc(mVec1.size)
    for i in 0...mVec1.size
      averageRank = (@returnArray[0][i].to_f + @returnArray[1][i].to_f)/2
      rankNormalizedVector1[@returnArray[0][i].to_i] = averageRank.to_f
      rankNormalizedVector2[@returnArray[1][i].to_i] = averageRank.to_f
    end
    returnArray[0] = rankNormalizedVector1
    returnArray[1] = rankNormalizedVector2
    return returnArray
  end

  # Maps the values of @mVec1 and @mVec2 to the CDF value of their
  # respective gaussian distributions.
  #
  # WARNING: this used to be called newQuantileNormalized() but did not
  # actually do reference-less quantile normalization. newQuantileNormalized()
  # is aliased to gaussianNormalization() below to prevent breaking code, but
  # things calling newQuantileNormalized() really should be UPDATED to use
  # the REAL quantileNormalization() method below!
  #
  def gaussianNormalization()
    return BRL::Stats::gaussianNormalize(*@vectors)
  end

  alias_method :newQuantileNormalized, :gaussianNormalization

  def quantileNormalization()
    return BRL::Stats::quantileNormalize(*@vectors)
  end
end
