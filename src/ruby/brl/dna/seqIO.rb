
require 'stringio'

module BRL ; module DNA

  class SeqIO < StringIO
    attr_accessor :doBuffer, :doPrettyPrint, :bufferSize, :autoPrintIO
    attr_reader :basesPerLine, :ppRE
    attr_accessor :preStripNewlines
  
    def initialize(doPrettyPrint=true, basesPerLine=70)
      @doPrettyPrint = doPrettyPrint
      @basesPerLine = basesPerLine
      @doBuffer = true
      @bufferSize = 4096
      @autoPrintIO = $stdout
      @preStripNewlines = false
      @ppRE = /\S{#{@basesPerLine},#{@basesPerLine}}/
      super()
    end
  
    def sync()
      return !@doBuffer
    end
  
    def sync=(boolean)
      @bufferSize = (boolean ? 0 : @bufferSize)
      self.flushBuffer()
      return @doBuffer = (boolean ? true : false)
    end
  
    def basesPerLine=(bpl)
      @basesPerLine = bpl.to_i
      @ppRE = /\S{#{@basesPerLine},#{@basesPerLine}}/
      return @basesPerLine
    end
    
    def close()
      @bufferSize = 0
      self.flushBuffer()
      self.truncate(0)
      super()
      return
    end
  
    def flush()
      currBufferSize = @bufferSize
      @bufferSize = 0
      self.flushBuffer()
      @bufferSize = currBufferSize
    end
  
    def flushBuffer()
      if(@doBuffer)
        self.dumpString() if(self.string.length >= @bufferSize)
      else # not buffering, dumpString
        self.dumpString()
      end
      return
    end
  
    def dumpString()
      if(self.string.length > 0) # then something to print
        theString = (@preStripNewlines ? self.string.gsub(/\n/, '') : self.string)
        if(@doPrettyPrint)
          theString.scan(@ppRE) { |seqLine| @autoPrintIO.puts seqLine }
          leftOver = ( ($'.nil? or $'.empty?) ? theString.dup : $' )       # '
          if(@doBuffer and leftOver.length < @bufferSize) # if buffering, leave the leftovers
            self.reopen(leftOver, "rw")
          else
            @autoPrintIO.print leftOver
            self.truncate(0)
          end
        else
          @autoPrintIO.print(theString)
          self.truncate(0)
        end
      end
      return
    end
    
    def truncate(size)
      super(size)
      unless(size > 0)
        self.rewind()
      end
      return
    end
    
    def reopen(string, mode="rw")
      self.truncate(0)
      self.rewind()
      self.print string
      return self
    end
    
    def print(obj, *rest)
      retVal = super(obj, *rest)   # prints into the buffer
      self.flushBuffer()  # dumps the buffer if appropriate
      return retVal
    end
  
    def printf(formatStr, obj, *rest)
      retVal = super(formatStr, obj, *rest)  # prints into the buffer
      self.flushBuffer()            # dumps the buffer if appropriate
      return retVal
    end
  
    def putc(obj)
      retVal = super(obj)
      self.flushBuffer()
      return retVal
    end
  
    def puts(obj, *rest)
      retVal = super(obj, *rest)
      self.flushBuffer()
      return retVal
    end
  
    def write(string)
      retVal = super(string)
      self.flushBuffer()
      return retVal
    end
  end

end ; end
