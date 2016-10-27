#!/usr/bin/env ruby

require 'brl/genboree/rest/helpers/trackApiUriHelper'

module BRL; module Genboree; module Helpers

class ParallelTrackDownload
  
  MAX_THREADS = 3
  BATCH_SIZE = 3
  attr_accessor :uriFileHash
  attr_accessor :batchSize
  attr_accessor :maxThreads
  attr_accessor :spanAggFunction
  attr_accessor :emptyScoreValue
  attr_accessor :regions
  attr_accessor :userId
  attr_accessor :hostAuthMap
  attr_accessor :threadStatusHash
  
  # [+uriFileHash+] A hash mapping track URIs to their files
  # [+userId+]
  def initialize(uriFileHash, userId)
    @uriFileHash = uriFileHash
    @userId = userId
    @maxThreads = ParallelTrackDownload.getMaxThreads()
    @batchSize = BATCH_SIZE
    @spanAggFunction = 'avg'
    
    @emptyScoreValue = nil
    @format = 'bedGraph'
    @regions = 10_000
    @hostAuthMap = nil
    @threadStatusHash = {}
  end

  # [+&block+] code block to execure after very batch
  def downloadTracksInBatches(&block)
    batchPool = 0
    tmpHash = {}
    @uriFileHash.each_key { |trkUri|
      if(batchPool < @batchSize)
        batchPool += 1
        tmpHash[trkUri] = @uriFileHash[trkUri]
        next
      end
      downloadTracksUsingThreads(tmpHash) 
      yield block if(block_given?)
      tmpHash.clear()
      batchPool = 1
      tmpHash[trkUri] = @uriFileHash[trkuri]
    }
    if(!tmpHash.empty?)
      downloadTracksUsingThreads(tmpHash)
      yield block if(block_given?)
    end
  end
  
  def success?()
    retVal = true
    @threadStatusHash.values.each { |val|
      unless(val)
        retVal = false
        break
      end
    }
    return retVal
  end
  
  
  def downloadTracksUsingThreads(uriFileHash=@uriFileHash, &block)
    count = 0
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Using threads: #{@maxThreads}.")
    threads = []
    @threadStatusHash = {}
    uriFileHash.each_key {|uri|
      childrenThreads = (Thread.list.size - 1)
      if(childrenThreads == 0 or childrenThreads % @maxThreads != 0)
        threads << Thread.new {
          trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
          retVal = trkApiHelper.getDataFileForTrack(uri, @format, @spanAggFunction, @regions, uriFileHash[uri], @userId, @hostAuthMap, @emptyScoreValue, 1)
          @threadStatusHash[uri] = (retVal ? true : false)
        }
      else
        addedToPool = false
        # Sleep every 5 seconds and then query the number of children threads running.
        # As soon as one spot is free, insert the *current* job in the thread pool and move on to the next download.
        loop {
          sleep(5)
          childrenThreads = (Thread.list.size - 1)
          if(childrenThreads == 0 or childrenThreads % @maxThreads != 0)
            threads << Thread.new {
              trkApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new()
              retVal = trkApiHelper.getDataFileForTrack(uri, @format, @spanAggFunction, @regions, uriFileHash[uri], @userId, @hostAuthMap, @emptyScoreValue)
              @threadStatusHash[uri] = (retVal ? true : false)
            }
            addedToPool = true
          end
          break if(addedToPool)
        }
      end
      count += 1
    }
    threads.each { |aThread| aThread.join }
    yield block if(block_given?)
  end
  
  # Class method to return max number of concurrent threads to run when downloading track data
  # [+retVal+] retVal: integer value 
  def self.getMaxThreads()
    retVal = nil
    maxThreadsFromEnv = ENV['GB_NUM_CORES']
    if(maxThreadsFromEnv =~ /^\d+$/)
      maxThreadsFromEnv.strip!
      retVal = ( maxThreadsFromEnv.to_i <= MAX_THREADS ? maxThreadsFromEnv.to_i : MAX_THREADS)
    else
      retVal = MAX_THREADS
    end
    return retVal
  end
  
end
end; end; end
