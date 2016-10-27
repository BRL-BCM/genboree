#!/usr/bin/env ruby
require 'open3'
require 'stringio'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/abstractStreamer'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources
  # For serving static files in chunks via API in a Rack-based web server stack
  # - especially binary and large files
  class StaticFileHandler < AbstractStreamer
    genbConf = BRL::Genboree::GenboreeConfig.load()
    CHUNK_SIZE = genbConf.staticFileChunkSize.to_i 
    TOO_BIG_FOR_READ = 128 * 1024 * 1024

    attr_accessor :filePath

    def initialize(filePath, maxNumRecords=nil, prefixFilter=nil)
      super()
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
      @filePath = filePath
    end

    # Serve the file in reasonable chunks.
    # - This method avoids keeping around a file handle to the file being read.
    # - Thus if the yield takes a long time or something else bad happens, we
    #   don't keep or leak file handles and such.
    def each()
      offset = 0      # where we are currently reading from in the file
      bytesSent = 0   # how much we've sent so far (mainly for any logging etc)
      while(buff = IO.read(@filePath, CHUNK_SIZE, offset))
        yield buff
        bytesSent += buff.size
        offset += CHUNK_SIZE
      end
      buff = nil
    end

    def read(length=nil)
      sio = StringIO.new
      self.each { |chunk|
        sio << chunk
        if(sio.size > TOO_BIG_FOR_READ) # Too much memory, calling code should have used each() not read().
          sio.truncate(0)
          sio.rewind
          sio = nil
          raise "FATAL ERROR: bad code called #{File.basename(__FILE__)}:#{__method__}() rather than being designed around safer iterative code-block based approaches. Futher processing will stop; the poorly design code should be fixed."
        elsif(length and sio.size > length)        # Calling code asking only for length. If over, then stop (and adjust any overage)
          sio.truncate(length)
          break
        end
      }
      return sio.string
    end
    alias_method :read_body, :read

    def close()
      @filePath = nil
    end
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module Abstract ; module Resources
