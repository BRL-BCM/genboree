#!/usr/bin/env ruby
require 'open3'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/abstractStreamer'

# List of fdata2 fields that are required
module BRL ; module Genboree ; module Abstract ; module Resources
  class PlainTextFileIO < AbstractStreamer
    FILTER_CMD_BASE = 'grep -i '
    READ_CHUNK_SIZE = 4 * 1024 * 1024

    attr_accessor :filePath
    attr_accessor :prefixFilter
    attr_accessor :maxNumRecords

    def initialize(filePath, maxNumRecords=nil, prefixFilter=nil)
      super()
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
      @filePath = filePath
      @maxNumRecords = maxNumRecords.to_i
      @maxNumRecords = nil if(@maxNumRecords <= 0)
      @prefixFilter = (prefixFilter ? prefixFilter.to_s : nil)
    end

    def each()
      ioObj = self.getIoObj()
      if(ioObj)
        while( (chunk = ioObj.read(READ_CHUNK_SIZE)) )
          yield chunk
        end
        ioObj.close
      end
      return
    end

    def each_line()
      ioObj = self.getIoObj()
      if(ioObj)
        ioObj.each_line { |line|
          yield line
        }
        ioObj.close
      end
      return
    end

    def getIoObj()
      retVal = nil
      # If NO maxNumRecords NOR prefixFilter, then just whole file
      if(maxNumRecords.nil? and prefixFilter.nil?)
        retVal = File.open(seqFilePath, 'r')
      else # either maxNumRecords and/or prefixFilter provided
        cmd = FILTER_CMD_BASE.dup
        # Prep for max number of records
        cmd << " --max-count=#{@maxNumRecords} " if(@maxNumRecords)
        # Prep for a prefix filter
        if(@prefixFilter)
          @prefixFilter.gsub!(/\./, "%%GENB_TMP_PH_DOT%%")
          @prefixFilter.gsub!(/\^/, "%%GENB_TMP_PH_CARAT%%")
          @prefixFilter.gsub!(/[^a-zA-Z0-9_\-\+\#=@\#%\^&\*\(\)\[\]\|\:;,\/\?]/, '.')
          @prefixFilter.gsub!(/%%GENB_TMP_PH_DOT%%/, "\\.")
          @prefixFilter.gsub!(/%%GENB_TMP_PH_CARAT%%/, "\\^")
          @prefixFilter = "^#{@prefixFilter}"
        else # no filter, make sure to match all
          @prefixFilter = "."
        end
        cmd << " --extended-regexp \"#{@prefixFilter}\" "
        # Add file path to cmd
        cmd << " #{@filePath}"
        cmdStdin, cmdStdout, cmdStderr = Open3.popen3(cmd)
        cmdStdin.close
        cmdStderr.close
        retVal = cmdStdout
      end
      return retVal
    end
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module Abstract ; module Resources
