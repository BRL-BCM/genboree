#!/usr/bin/env ruby
require 'stringio'
require 'fileutils'
require 'brl/util/util'

module BRL ; module Util
  class BufferedFileWriter
    #------------------------------------------------------------------
    # CONSTANTS
    WRITE_BUFF_SIZE = 4 * 1024 * 1000

    #------------------------------------------------------------------
    # PROPERTIES
    # Path to file to read through
    attr_accessor :filePath
    # File handle for reading
    attr_accessor :fileObj
    # Size of write buffer
    attr_accessor :buffSize
    # The write buffer
    attr_accessor :buff
    # Number of lines written so far
    attr_accessor :lineno
    attr_accessor :count

    #------------------------------------------------------------------
    # INSTANCE METHODS

    def initialize(filePath, buffSize=WRITE_BUFF_SIZE)
      @filePath = filePath
      @buffSize = buffSize
      @lineno = 0
      @count = 0
      init()
    end

    def init()
      # Get at file
      if(@filePath)
        @fileObj = File.open(@filePath, "w+")
      else
        raise "ERROR: no such file: #{@filePath.inspect}"
      end
      # Set up StringIO buffer
      @buff = StringIO.new()
    end

    def flush()
      #$stderr.puts "#{@buff.pos}\t#{buff.size}\t#{buff.string.inspect}"
      @count += 1
      if(@buff and @buff.is_a?(StringIO))
        unless(@buff.pos == 0)
       #   $stderr.puts @count
          @fileObj.write(@buff.string)
          #fileObj.flush()
          @buff.truncate(0)
          @buff.rewind()
        end
      end
    end

    def close()
      # Check if there's anything in the buffer and flush it!
      flush()
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

    def print(chunk)
      # Write data into buffer
      retVal = @buff.print(chunk)
      # Do we need to flush the buffer?
      if(@buff.size > @buffSize)
        flush()
      end
    end

    def puts(line)
      # Write data into buffer
      retVal = @buff.puts(line)
      # Do we need to flush the buffer?
      if(@buff.size > @buffSize)
        flush()
      end
    end
  end
end ; end
