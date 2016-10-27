#!/usr/bin/env ruby
require 'stringio'
require 'fileutils'
require 'brl/util/util'

module BRL ; module Util
  class BufferedFileLineReader
    #------------------------------------------------------------------
    # CONSTANTS
    READ_BUFF_SIZE = 4 * 1024 * 1000

    #------------------------------------------------------------------
    # PROPERTIES
    # Path to file to read through
    attr_accessor :filePath
    # File handle for reading
    attr_accessor :fileObj
    # Size of read buffer
    attr_accessor :buffSize
    # The read buffer
    attr_accessor :buff
    # Number of lines iterated over (yielded) so far
    attr_accessor :lineno

    #------------------------------------------------------------------
    # INSTANCE METHODS

    def initialize(filePath, buffSize=READ_BUFF_SIZE)
      @filePath = filePath
      @buffSize = buffSize
      @lineno = 0
      init()
    end

    def init()
      # Get at file
      if(@filePath and File.exist?(@filePath))
        @fileObj = File.open(@filePath)
      else
        raise "ERROR: no such file: #{@filePath.inspect}"
      end
      # Set up StringIO buffer
      @buff = StringIO.new()
    end

    def close()
      # Close file if open
      begin
        if(@fileObj and @fileObj.respond_to?(:close) and !@fileObj.closed?)
          @fileObj.close()
        end
      rescue => err
        # no-op for failed file close
      ensure
        @fileObj = nil
        @filePath = nil
      end
      # Clean up buffer
      begin
        if(@buff and @buff.is_a?(StringIO))
          @buff.clear()
        end
      rescue => err
        # no-op for failed clear
      ensure
        @buff = nil
      end
    end

    def each_line()
      havePartial = false
      # Read through @fileObj in @buffSize chunks
      while(!@fileObj.eof?)
        @buff.write(@fileObj.read(@buffSize))
        # Go through @buff (carefully, watching for partial lines), yielding up each line
        @buff.rewind()
        @buff.each_line { |line|
          # Check that last char is newline
          if(line.ord(-1) == 10)
            havePartial = false
            @lineno += 1
            yield line
          else # partial line or last line (w/o final \n)
            # Save partial line to set up next big chunk of file
            @buff.truncate(0)
            @buff.rewind()
            @buff.write(line)
            havePartial = true
            break
          end
        }
      end
      # Do we have something in @buff still? Should be last non-newline terminated line if so
      if(havePartial)
        @lineno += 1
        yield @buff.readline
      end
    end
  end
end ; end
