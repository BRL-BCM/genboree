
# Namespace for some Sample-related classes is BRL::Samples
# - SampleRecord class (modified Struct)
# - SampleParser class
module BRL ; module Samples
  # SampleRecord Struct
  # - easy way to make a Class using Struct & a specific columns list
  # - also, lets us override to_a() and to_s() to be a little "special"
  class SampleRecord < Struct
    # Get as Array, optionally respecting the column sort order arg.
    # - note: colSortOrder can just have names of first few columns, or a complete ordering. Both work.
    def to_a(colSortOrder=nil)
      columns = self.members
      if(colSortOrder)
        columns.sort!{ |xx,yy|
          (colSortOrder.index(xx) or colSortOrder.size) <=> (colSortOrder.index(yy) or colSortOrder.size)
        }
      end
      retVal = []
      columns.each { |colName|
        retVal << self.send(colName)
      }
      return retVal
    end

    # Get as String, optionally respecting the column sort order arg.
    def to_s(colSortOrder=nil)
      return to_a(colSortOrder).join("\t")
    end
  end

  # Create a SampleParser class we can instantiate.
  # - we want to be able to give it the column header information (as tab-delim String or Array)
  class SampleParser
    attr_reader :columns
    attr_reader :recordClass

    # CONSTRUCTOR
    # [+header+] - The column header. Could be a tab-delim String or Array of column names.
    #              If String and appears to be a "comment"-style line, the leading /^\s*#/ is stripped automatically.
    def initialize(header)
      unless(header.is_a?(String) or header.is_a?(Array))
        raise "ERROR: #{self.class}##{__method__} => header must be a tab-delimited String or and Array of columnHeaders"
      else
        if(header.is_a?(String)) # then convert to Array
          unless(header =~ /\t/)
            raise "ERROR: #{self.class}##{__method__} => header line must be TAB delimited list of column headers."
          end
          header.chomp!              # else last colheader could have \n in it
          header.gsub!(/^\s*#/, '')  # Remove '#' and preceding whitespace if present.
          @columns = header.split(/\t/)
        else # Array already.
          @columns = header
        end
        # Dynamically make our Sample Record "class" (a Struct based specifically on our column names)
        @recordClass = SampleRecord.new(*@columns.map{|xx| xx.to_sym})
      end
    end

    # Call this function to get back a Sample Record object (a Struct) for the line
    # - return nil if sampleLine nil OR empty/all-whitespace
    # - optionally returns nil if the line is a comment line (1st non-whitespace is '#'). On by default.
    # - line must have same number of columns as the header line, else exception b/c bad line
    def parseLine(sampleLine, skipComments=true)
      retVal = nil
      if(sampleLine.is_a?(String) and sampleLine =~ /\S/ and (!skipComments or sampleLine !~ /^\s*#/))
        sampleLine.chomp!
        fields = sampleLine.split(/\t/)
        if(fields.size != @columns.size)
          raise "ERROR: #{self.class}##{__method__} => Line has #{fields.size} tab-delimited columns. Should have #{@columns.size} columns."
        else
          # Return a SampleRecord object
          retVal = @recordClass.new(*fields)
        end
      end
      return retVal
    end

    # Use above to implement an "each" iterator for an IO stream
    # - iostream must respond to each_line() (e.g. instance of File, Socket, StringIO buffer, etc)
    # - takes a block which will be provided the Sample Record object
    def each_record(iostream, &block)
      unless(iostream.respond_to?(:each_line))
        raise "ERROR: #{self.class}##{__method__} => iostream object must respond to each_line method."
      else # get record for each line and yield up the object
        lineCounter = 1
        iostream.each_line { |line|
          begin
            yield parseLine(line)
          rescue => err
            $stderr.puts "Line #{lineCounter}: bad sample record format."
          end
          lineCounter += 1
        }
      end
    end
  end
end ; end
