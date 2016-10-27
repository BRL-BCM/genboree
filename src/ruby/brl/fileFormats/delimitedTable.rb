require 'rein'
require 'stringio'
# Retry load if doing facets 1.X way fails...maybe we have facets 2.X
begin
  require 'facet/dictionary'
  require 'facet/string/blank'
rescue LoadError => lerr
  require 'facets/dictionary'
  require 'facets/string/blank'
end

module BRL ; module FileFormats

# ----------------------------------------------------------------------------
# Helper module methods
# ----------------------------------------------------------------------------
# Convert arg to an io-compatible object
def self.srcToIO(src)
  unless(src.nil?)
    if(src.kind_of?(String))
      src = StringIO.new(src)
    elsif(!src.respond_to?(:each))
      src = StringIO.new(src.to_s)
    end
  end
  return src
end

# ----------------------------------------------------------------------------
# DelimitedTable - Abstraction of a delimited table.
# . Uses DelimitedRecord class to represent each row
# ----------------------------------------------------------------------------
#   A delimited table has the following properties
#   - there is a column delimiter, such as tab
#   - there is a column order
#     . by default this is the order of the column headers in the first
#       non-blank row
#     . this can be overridden by supplying your own column header map
#       or by providing a ordering function
#   - column headers are unique ; no duplicate column names
#   - there is a row order
#     . by default this is the order of the rows encountered in the src file
#       or string
#     . however, you can specify a sort function based on columns names to get
#       a custom sorting
#   - blank header columns are ignored (treated as if the whole column were
#     empty)
#   - rows with more columns than there are headers are bad and raise error
#   - rows with fewer columns are ok...missing columns will have nil values
# NOTES:
# 1) A colHeaderMap is required
#    - this maps headers names (as Symbols) to column indices (fixnums)
#    - by providing a src IO or String object to the constructor, you can let it
#      automatically find your first non-blank line to use as headers
#      . the column *order* will be maintained and will be as-found in that
#        first non-blank line
#      . empty header columns will be skipped over and will be ignored
#      . any rows in the src IO or String object will also be read and parsed
#    - or you can provide the colHeaderMap yourself by:
#      . provide a Dictionary to colHeaderMap=() that maps header Symbols to
#        indices. The order_by() of your Dictionary will be used; i.e. it will
#        output the columns in the order specified by your Dictionary!
#      . provide an Array of column header symbols in the order you want
#        the columns to be output
# 2) The internal colHeaderMap is a Dictionary.
#    - if it is created automatically from the src IO or String, then the
#      order of the dictionary is the order of columns found on the first
#      non-blank line.
#    - but you can dynamically set the order to whatever you want (or override
#      what it found in the first non-blank line) in a couple of ways:
#      . provide colOrder=() with an Array of column names in the order you
#        want. This is like providing the array to Dictionary#order=().
#      . provide colOrderBy() with a &block just like you would for the
#        dictionary's order_by(). This is less useful in most cases, with the
#        exception of table.colOrderBy {|kk,vv| kk} which would cause table
#        columns to be ordered alphabetically (rather than the order encountered)
# 3) It is possible, but more expensive, to output the rows in some sorted
#    order. The default is to output rows in the same order that they were
#    encountered. But maybe you want to sort the rows by certain columns or
#    something.
#    . if so, you need to provide a comparison block to sortRowsUsing()
#    . this works just like the block you provide to Array#sort() except that
#      the two arguments (the two objects to be compared with a -1,0,1 as the
#      result) are BRL::FileFormats::DelimitedRecord objects
#    . remember that you can access the value stored in a specific column
#      BRL::FileFormats::DelimitedRecord by "delimRec.colName" where "colName"
#      is the name of the column or by delimRec[colName] for more complex things.
# 4) Row values are stored as Symbols, since the same value amy occur over and over
#    in the table.
class DelimitedTable
  attr_accessor :colHeaderMap, :colIndexMap
  attr_accessor :rows, :delim, :delimRE, :srcIO
  attr_accessor :sortRowsBlock

  # INITIALIZER
  #   - src => an IO or String object to read the delimited table data from
  #   - delim => the column delimiter regexp to use (defaults to tab)
  # If src is nil, you will need to provide the header map via colHeaderMap=().
  def initialize(src=nil, delim="\t")
    @delim = delim
    @delimRE = /#{@delim}/
    @colHeaderMap = Dictionary.new()
    @colIndexMap = {}
    @rows = []
    @sortRowsBlock = nil
    @srcIO = BRL::FileFormats::srcToIO(src)
    unless(@srcIO.nil?)
      parseColHeaders(@srcIO)
      parseRows(@srcIO)
    end
  end

  # Parse src (IO or String) for column headers
  #   - src => an IO or String object that will be scanned for the first
  #            non-blank line, which will be used to determine the headers. If
  #            nil, then @srcIO will be assumed.
  def parseColHeaders(src=@srcIO)
    if(src.nil?)
      if(@colHeaderMap.nil?)
        @colHeaderMap = {}
        @colIndexMap = {}
      else
        @colHeaderMap.clear()
        @colIndexMap.clear()
      end
    else
      src = BRL::FileFormats::srcToIO(src) # Use provided src if we can, else assume can use @scrIO
      unless(src.nil?)
        # Read first non-blank line from src and assume it is the header line
        src.each { |line|
          next if(line !~ /\S/)
          aa = line.chomp.split(@delimRE)
          aa.each_index { |ii|
            unless(aa[ii].empty? or aa[ii].blank?) # skip empty/blank columns
              aa[ii] = aa[ii].to_sym
              # Duplicate column names are illegal
              if(@colHeaderMap.key?(aa[ii]))
                raise ArgumentError, "ERROR: found duplicated column headers in the src. This illegal."
              end
              @colHeaderMap[aa[ii]] = ii # Dictionary; stores order encountered
              @colIndexMap[ii] = aa[ii]
            end
          }
          break
        }
      end
    end
    return @colHeaderMap
  end

  # Get an Array of columns, as Symbols
  # CHECKED
  def columns()
    return @colHeaderMap.keys
  end

  # Get an Array of columns, as Symbols
  # CHECKED
  def colOrder()
    return @colHeaderMap.keys
  end

  # Set the column order using the provided array.
  # * ERROR if colArray.length != @colHeaderMap.length
  # CHECKED
  def colOrder=(colArray)
    if(!@colHeaderMap.nil? and colArray.size != @colHeaderMap.size)
      raise ArgumentError, "ERROR: given column array with #{colArray.size} columns, but the table has #{@colHeaderMap.size} columns!"
    end
    unless(colArray.size == colArray.uniq.size)
      raise ArgumentError, "ERROR: there are duplicate column headers! Column headers must be unique."
    end
    @colHeaderMap.clear()
    @colIndexMap.clear()
    colArray.each_index { |ii|
      @colHeaderMap[colArray[ii].to_sym] = ii
      @colIndexMap[ii] = colArray[ii].to_sym
    }
    return
  end

  # Set the column order using the provided block
  # - less useful than just providing the column order directly
  # - the block will be given two arguments (just like Dictionary.order_by)
  #   which are the key (colName) and the value (index of that column in the
  #   input row data). The block must return an object that will be used in
  #   comparisons to determine the column order.
  # - for example, this would end up sorting the columns alphabetically:
  #   table.colOrderBy { |colName, idx| colName }
  # CHECKED
  def colOrderBy( &block )
    @colHeaderMap.order_by( &block )
    @colHeaderMap.each_key { |colName|
      @colIndexMap[@colHeaderMap[colName]] = colName
    }
    return
  end

  # Use the provided comparison block that compares two DelimitedRecords to sort rows
  # - the block will be given two row objects (2 DelimtedRecords) and you
  #   should compare them returning -1,0,1 for their relative order.
  # CHECKED
  def sortRowsUsing( &block )
    @sortRowsBlock = block
  end

  # Parse the rows of src or continue parsing @srcIO to get the rows
  # CHECKED
  def parseRows(src=@srcIO)
    return nil if(src.nil?)
    src = BRL::FileFormats::srcToIO(src) # parse src if provided, else continue with ours
    src.each { |line|
      dRec = BRL::FileFormats::DelimitedRecord.new(line, @colIndexMap, @delim)
      @rows << dRec unless(dRec.nil?)
    }
    return @rows
  end

  # Iterate over each row, using row sorting if desired
  # CHECKED
  def each_row(sortRows=false, &block )
    if(sortRows and @sortRowsBlock.nil?)
      raise ArgumentError, "ERROR: you asked to sort the rows but this DelimitedTable object has comparison block to compare two rows set up (via sortUsingBlock())??"
    end
    if(sortRows)
      @rows.sort(&@sortRowsBlock).each { |row|
        yield(row)
      }
    else
      @rows.each { |row|
        yield(row)
      }
    end
    return
  end

  # Delete columns
  # - removes columns from header maps
  # - visits each row and removes the columns for that row
  # CHECKED
  def deleteColumns(*colNames)
    colNames.each { |colName|
      # remove column from header maps
      colName = colName.to_sym
      colIdx = @colHeaderMap[colName]
      @colHeaderMap.delete(colName)
      @colIndexMap.delete(colIdx)
      # remove column from each row
      @rows.each { |row|
        row.delete(colName)
      }
    }
    return
  end

  # Delete rows
  # - removes data rows
  # - CHECKED
  def deleteRows(*rowIndices)
    return 0 if(@rows.nil? or @rows.empty?)
    rowIndices.each {|ii|
      @rows[ii] = nil
    }
    @rows.compact!
    return rowIndices.size
  end

  # Swap the order of two columns
  # CHECKED
  def swapColumns(colName1, colName2)
    colName1, colName2 = colName1.to_sym, colName2.to_sym
    return false if(colName1 == colName2)
    unless(@colHeaderMap.key?(colName1) and @colHeaderMap.key?(colName2))
      raise ArgumentError, "ERROR: can't swap columns that don't exist."
    end
    idx1 = @colHeaderMap[colName1]
    idx2 = @colHeaderMap[colName2]
    @colHeaderMap[colName1] = idx2
    @colHeaderMap[colName2] = idx1
    @colIndexMap[idx1] = colName2
    @colIndexMap[idx2] = colName1
    self.colOrderBy { |colName, idx| idx }
    return
  end

  # Get row data for given columns, in given order
  # - returns 2D table of the desired column(s) for all rows
  # CHECKED
  def getDataInColumns(*colNames)
    retVal = []
    # check exists and map to sym here instead of inside
    @rows.each { |row|
      currData = []
      colNames.each { |colName|
        colName = colName.to_sym
        raise ArgumentError, "ERROR: column '#{colName}' doesn't exist." unless(@colHeaderMap.key?(colName))
        currData << row[colName]
      }
      retVal << currData unless(currData.empty?)
    }
    return retVal
  end

  # Convert table to a string, including headers and sorting rows if needed
  # CHECKED
  def to_s(includeHeaders=true, sortRows=false)
    sio = StringIO.new('')
    sio.puts @colHeaderMap.keys.join(@delim) if(includeHeaders)
    self.each_row(sortRows) { |row|
      sio.puts row.to_s(@colHeaderMap, @delim)
    }
    return sio.string
  end
end

# ----------------------------------------------------------------------------
# DelimitedRecord - Abstraction of a delimited record.
# . Used by DelimitedTable class to represent each row
# ----------------------------------------------------------------------------
class DelimitedRecord < Rein::ObjectTemplate
  attr_accessor :delim, :delimRE, :passed, :rulesPassed

  # Make a new record, given a line and an index->columnName mapping
  def initialize(line, idx2hdrMap, delim="\t")
    super()
    @delim = delim
    @delimRE = /#{@delim}/
    @passed = 0
    @rulesPassed = {}
    replace(line, idx2hdrMap, @delim) unless(line.nil? or line.empty? or idx2hdrMap.nil? or idx2hdrMap.empty?)
  end

  # Replace this record with results from parsing a new line, given an index->columnName mapping
  def replace(line, idx2hdrMap, delim=@delim)
    if( (!line.nil? and !line.empty?) and (idx2hdrMap.nil? or idx2hdrMap.empty?) )
      raise ArgumentError, "ERROR: idx->header name map cannot be nil or empty"
    end
    @delim = delim
    @delimRE = /#{@delimRE}/
    @passed = 0
    @rulesPassed = {}
    self.clear
    unless(line.nil? or line.empty?)
      aa = line.chomp.split(@delimRE)
      if(aa.length > idx2hdrMap.size)
        raise ArgumentError, "ERROR: Delimited line has more columns (#{aa.length}) than there are defined headers (#{idx2hdrMap.size})!"
      end
      idx2hdrMap.each_key { |ii|
        self[idx2hdrMap[ii].to_sym] = (aa[ii].nil? ? nil : aa[ii].to_sym)
      }
    end
    return self
  end

  # Turn the row into a String using a columnName->index mapping *Dictionary* or
  # an Array of column names in the desired order, and optionally overriding the
  # instance's delimiter.
  # - if the column order is a dictionary, data values will be output in the
  #   order provided by the keys of the Dictionary
  # - if the column order is an Array, data values will be output in the
  #   order of the columnNames in the Array
  def to_s(columnOrder, delim=@delim)
    unless(columnOrder.kind_of?(Dictionary) or columnOrder.kind_of?(Array))
      raise ArgumentError, "ERROR: column order must be provided as a Dictionary keyed by column names or an Array of column names"
    end
    sio = StringIO.new()
    columnOrder = columnOrder.keys if(columnOrder.kind_of?(Dictionary))
    columnOrder.each_index { |ii|
      sio.print "#{self[columnOrder[ii]]}#{(ii < columnOrder.size-1) ? @delim : ''}"
    }
    return sio.string
  end

  # Turn the row into an Array using a columnName->index mapping *Dictionary* or
  # an Array of column names in the desired order, and optionally overriding the
  # instance's delimiter.
  # - if the column order is a dictionary, data values will be output in the
  #   order provided by the keys of the Dictionary
  # - if the column order is an Array, data values will be output in the
  #   order of the columnNames in the Array
  def to_a(columnOrder)
    unless(columnOrder.kind_of?(Dictionary) or columnOrder.kind_of?(Array))
      raise ArgumentError, "ERROR: column order must be provided as a Dictionary keyed by column names or an Array of column names"
    end
    arr = []
    columnOrder = columnOrder.keys if(columnOrder.kind_of?(Dictionary))
    columnOrder.each_index { |ii|
      arr << self[columnOrder[ii]]
    }
    return arr
  end
end

end ; end
