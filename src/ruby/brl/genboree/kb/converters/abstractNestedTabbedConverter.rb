require 'brl/util/util'
require 'brl/extensions/bson'
require 'brl/extensions/simpleDelegator'

module BRL ; module Genboree ; module KB ; module Converters
  class AbstractNestedTabbedConverter

    REQUIRED_COLS = nil
    KNOWN_COLS    = nil

    attr_accessor :columns, :col2idx, :nameIdx, :result, :errors

    def initialize(opts={})
      init(opts)
    end

    def init(opts={})
      # @seenHeader will keep track of whether we've processed the header line for our tabbed delimited file 
      @seenHeader = false
      # @seenHeader will keep track of whether we've processed the header line for our tabbed delimited file (single doc)
      @seenRoot = false
      # @result will keep track of the resulting KB doc generated from parsing the tabbed delimited file (single doc)
      @result = nil
      # @results will keep track of the resulting KB doc generated from parsing the tabbed delimited file (multiple docs)
      @results = []
      # @columns will keep track of the different column names we see in the header line
      @columns = []
      # @col2idx maps each column name to associated indices (1-to-1 relationship if bulk disabled, 1-to-many if bulk enabled) 
      @col2idx = {}
      # @errors will keep track of which lines contain errors
      @errors = {}
      # @lineNo will keep track of the current line number in our tabbed delimited file 
      @lineNo = 0
      # @nameIdx will keep track of the column index where we can find our property names
      @nameIdx = nil
      # @currentPropDepth will keep track of the current depth of our document (for 
      @currentPropDepth = 0
      # @valIndices will keep track of each column index where values exist (for bulk docs), along with:
      #   Whether root has been visited or not
      #   Current KB doc object associated with column of values
      #   Ancestors associated with current KB doc object
      #   Whether we're currently bypassing a #MISSING# property (or property that has blank value and has domain that does not allow blank values) and its children
      #   The depth associated with the #MISSING# property (or property that has blank value and has domain that does not allow blank values)
      @valIndices = {}
    end

    # This method converts the KB doc(s) gathered in @result into JSON String(s).
    # @param [File] lineReader open stream for reading lines from current tabbed delimited file
    # @param [boolean] bulk boolean that tells us whether we're dealing with bulk documents or not
    # @note This method will return a JSON String. If you actually want the
    #   the nested Ruby data structure, DON'T call this and then do {JSON.parse},
    #   rather just call {#parse} directly. It returns the nested document as a Ruby
    #   data structure.
    # @return [Array] KB doc(s) converted into JSON String(s)
    def convert(lineReader, bulk=false)
      # retVal will contain converted JSON String(s)
      retVal = nil
      # We run parse to convert tabbed delimited document to KB doc(s)
      parseOK = parse(lineReader, bulk)
      # If parsing went OK, we proceed
      if(parseOK)
        begin
          # Unless bulk is enabled, we just set retVal to be the JSON.pretty_generated version of the single KB doc
          unless(bulk)
            retVal = JSON.pretty_generate(@result)
          # If bulk is enabled, then we use JSON.pretty_generate to convert each KB doc to a JSON string and add each to retVal         
          else
            retVal = []
            @results.each_index { |idx|
              retVal << JSON.pretty_generate(@results[idx])
            }
          end
        rescue => err
          # We print a debugging statement if we have an error.  We also set retVal to nil
          $stderr.debugPuts(__FILE__, __method__, "ERROR: code bug produced a data structure in @result(s) (class: {@result.class.inspect}) which could not be turned into a JSON string, but which also was not caught by the converter class (#{self.class.inspect}).\n  Error Class: #{err.class.inspect}\n  Error Message: #{err.message.inspect}\n@result content:\n\n")
          unless(bulk)
            $stderr.debugPuts(__FILE__, __method__, "#{@result.inspect}\n\n")
          else
            $stderr.debugPuts(__FILE__, __method__, "#{@results.inspect}\n\n")
          end
          retVal = nil
        end
      else
        retVal = nil # If parsing did NOT go OK, we set retVal to nil
      end
      return retVal # Finally, we return retVal as our converted KB doc(s)
    end

    # This method parses a tabbed delimited file and converts each data column into a KB doc
    # @param [File or String] lineReader open stream for reading lines from current tabbed delimited file
    # @param [boolean] bulk boolean that keeps track of whether we're parsing multiple (bulk) docs
    # @return [Array or KbDoc] resulting KB doc(s) from parsing tabbed delimited file
    def parse(lineReader, bulk=false)
      init() # clear out anything from prior run [on same lineReader ; for interactive/debug more than anything]
      # If lineReader is valid, proceed
      if(lineReader)
        # ancestors will hold the ancestors for each KB doc currently being processed
        ancestors = []
        # We read through each line of the tabbed delimited file
        lineReader.each_line { |line|
          # We increment @lineNo by 1 each time we read through a line
          @lineNo += 1
          if(line !~ /\S/ or line =~ /^\s*##/) # We skip blank lines and lines that begin with ## (headers from API get call)
            next
          elsif(@seenHeader and line =~ /^\s*#/) # We also skip lines whose first char is comment char if we already have the header
            next
          else # Otherwise, we have a line that needs parsing.  It's either a record or a header
            # We strip the line and then check to see whether we've seen the header already
            line.strip!
            if(@seenHeader) # If we've seen the header already, then we know that this is a non-blank record line that we need to process into our KB doc(s)
              # We split the record line and find the property name information (includes any nesting info).  We use the index @nameIdx as found in our parseHeader method
              rec = line.split(/\t/)
              # We will parse the property name and extract its name info and nesting info
              propNameInfo = rec[@nameIdx]
              propInfo = parsePropNameInfo(propNameInfo)
              if(rec.count > @columns.count)
                @errors[@lineNo] = "The record for #{propInfo[:name]} contains more tab-separated columns than the header line. You have either included extra columns for this particular property that aren't covered by the header line, or your value(s) has an unescaped tab character. Please make sure that all columns are covered by the header line and that you escape your tab characters (\\t)!"
              end
              # If we didn't run into any errors while parsing the property, we proceed to add its value(s) to respective KB doc(s)
              if(@errors.empty?)
                # Unless bulk is true, we proceed with our single document
                unless(bulk)
                  # We create a property object using the line we grabbed
                  propObj = createPropObj(propInfo, rec)
                  # Unless we've already seen the root, we need to set @result to be the property object - this'll be what we return at the end of parsing
                  unless(@seenRoot)
                    @result = propObj
                    @seenRoot = true
                  end
                  # Figure out where to add this property
                  addProp(propObj, propInfo, ancestors)
                else
                  # If bulk IS true, then we need to traverse each key in @valIndices to set up all our KB docs
                  @valIndices.each_key { |index|
                    # We essentially use the above code but do it for multiple docs (using @valIndices)
                    propObj = createPropObj(propInfo, rec, index)
                    unless(@valIndices[index][0])
                      @valIndices[index][1] = propObj
                      @valIndices[index][0] = true
                      @seenRoot = true
                    end
                    # Figure out where to add this property
                    # We grab the current value and current depth of our property
                    currentVal = propObj.values.first["value"]
                    currentDepth = (propInfo[:nesting] ? propInfo[:nesting].size : 0)
                    currentDomain = rec[@col2idx[:domain][0]] rescue nil
                    unless(currentDomain)
                      @errMsg = "You have submitted a multi-column tabbed doc\nbut you are most likely missing the \"domain\" column."
                      raise @errMsg
                    end
                    emptyValueAllowed = true if(currentDomain == "string" or currentDomain == "[valueless]" or currentDomain.include?("regexp") or currentDomain == "url" or currentDomain == "fileUrl" or currentDomain.include?("autoID") or currentDomain.include?("numItems"))
                    # If the current value is "#MISSING#" or the current value is blank and no empty values are allowed, AND the current depth is less than or equal to the depth of the previous missing property
                    # then we need to make sure that we set our missing flag to true ([3]) and also save the depth of the new missing property ([4])
                    if((currentVal=="#MISSING#" or (currentVal=="" and !emptyValueAllowed)) and currentDepth <= @valIndices[index][4].to_i)
                      @valIndices[index][3] = true
                      @valIndices[index][4] = currentDepth
                    else
                      # If the current value is not one of the above, then we proceed.  If our missing flag is on and our current depth is deeper than the missing property, 
                      # we know we're visiting the missing property's child, so we don't want to add it to our doc.
                      unless(@valIndices[index][3] and currentDepth > @valIndices[index][4])
                        # Otherwise, we add the property to our doc.
                        addProp(propObj, propInfo, @valIndices[index][2])
                        # Also, if the missing flag is on, we turn it off and reset the depth associated with the missing property to a huge number
                        # That way, when we come across a missing value again, at any depth in the document, we'll be able to enter the appropriate branch of the if/else statement above on line 154.
                        if(@valIndices[index][3])
                          @valIndices[index][3] = false
                          @valIndices[index][4] = 50000000000
                        end
                      end
                    end
                  }
                end
              end
            # Otherwise, if we haven't seen the header, we need to parse it
            else
              # We call the parseHeader method on the current line, with the parameter bulk telling us whether we're dealing with bulk docs
              parseHeader(line, bulk)
              # After we've parsed the header, we set @seenHeader to true so we don't try to parse it again!
              @seenHeader = true
              # We break our parsing if we ran into any errors while parsing the header
              break unless(@errors.empty?)
              # If bulk is true, then we need to set up our @valIndices to contain information about each value and its index within the document
              if(bulk)
                # We traverse every index associated with our value and set @valIndices for that index to be default values (haven't seen root, no KB doc associated, and empty ancestors)
                # By default, we also set MISSING flag to be false (we haven't seen any missing values yet), and we set the currentDepth to be some huge number.
                # That way, when we DO come across a MISSING value at any depth in the document, we'll be able to enter the appropriate branch of the if/else statement above on line 154.
                # NOTE: value is assumed to be the second element in REQUIRED_COLS (after name) in this context.
                @col2idx[self.class::REQUIRED_COLS[1]].each { |index|
                  @valIndices[index] = [false, nil, [], false, 50000000000]
                }
              end
            end
          end
        }
      end
      # Clean up the model produces (mainly get rid of empty 'properties' created during conversion)
      unless(bulk)
        # Unless bulk is true, we just cleanResult on @result (no parameter necessary)
        cleanResult() rescue nil
        # If @errors has content, we return nil; otherwise, we return @result
        return ( (@errors and !@errors.empty?) ? nil : @result )
      else
        # If bulk is true, then we need to traverse all keys in @valIndices, clean each doc, and then add each doc to @results
        @valIndices.each_key { |index|
          cleanResult(0, @valIndices[index][1]) rescue nil
          @results << @valIndices[index][1]
        }
        # If @errors has content, we return nil; otherwise, we return @results
        return ( (@errors and !@errors.empty?) ? nil : @results )
      end
    end

    # This method provides information about the errors that occurred while converting the tabbed delimited document into KB doc(s)
    # @return [String] collection of errors found while converting tabbed delimited document into KB doc(s)
    def errorSummaryStr()
      # If @errors is a hash and not empty (so there ARE errors), we proceed
      if(@errors.is_a?(Hash) and !@errors.empty?)
        # We sort @errors so that line numbers come up in order, and then we print our errors
        retVal = ''
        @errors.keys.sort.each { |lineNo|
          retVal << "LINE #{lineNo} : #{@errors[lineNo]}\n"
        }
      # Otherwise, if no errors occurred, we set retVal to be nil
      else
        retVal = nil
      end
      # Finally, we return retVal as our collection of errors
      return retVal
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    # ABSTRACT INTERFACE METHOD.
    def createPropObj(propInfo, rec, index=-1)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def addProp(propDef, propInfo, ancestors)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # ABSTRACT INTERFACE METHOD.
    def addChild(parentProp, childProp)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # ABSTRACT INTERFACE METHOD.
    def cleanResult(indent=0, doc=nil)
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # ------------------------------------------------------------------
    # HELPERS - mainly for use internally as parsing done, etc
    # ------------------------------------------------------------------

    # Parses header line to gather information about column names
    # @param [String] line header line that contains information about column names
    # @param [boolean] bulk boolean that lets us know whether we're parsing a header for bulk documents or not
    #   If we are, then column names are not unique (multiple "value" columns, for example)
    #   By default, this is set to false since the default situation is dealing with single documents
    # @return [Array] array containing the names of all different columns
    def parseHeader(line, bulk=false)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "BEGIN: Parse header for line #{@lineNo.inspect}")
      # Split line into different columns (since it's a tab-delimited file)
      colNames = line.split(/\t/)
      # We will traverse every index associated with our columns
      colNames.each_index { |idx|
        # We grab the column associated with the current index
        colName = colNames[idx]
        # We strip the column and see whether it's empty - if it is, we skip it
        colName.strip!
        if(colName =~ /\S/)
          # Normalize name:
          # - if first column, strip leading "#" if present
          if(idx == 0 and colName =~ /^(?:#)?(.+)$/)
            colName = $1
          end
          # We strip the column, downcase it, and convert it to a symbol (this is the standardized format for KNOWN_COLS)
          colNameSym = colName.strip.downcase.to_sym
          # Is this a column we care about? If not, capture it but don't check it.
          if(self.class::KNOWN_COLS[colNameSym])
            # If we've seen the column before and bulk is disabled, that's an error since columns have to be unique
            seenIdx = @columns.index(colNameSym)
            if(seenIdx and !bulk)
              @errors[@lineNo] = "Duplicate/ambiguous column name #{colName.inspect}. Previously seen in column ##{seenIdx + 1}. Column names are not case sensitive and must be unique."
            else # Otherwise, we add it to @columns
              @columns << colNameSym
            end
          else # If it's an unknown column, we add it to @columns without checking anything
            @columns << colName.strip.to_sym
          end
        end
      }
      # Do we have at least minimum number of columns?  If so, proceed.  Otherwise, error!
      if(@columns.size >= self.class::REQUIRED_COLS.size)
        # Do we have at least :name and :identifier [for the root property, to support a minimum model]?  If so, we're good.  Otherwise, error!
        unless( (@columns.find_all { |xx| self.class::REQUIRED_COLS.include?(xx) }.size) >= self.class::REQUIRED_COLS.size )
          @errors[@lineNo] = "Found column headers, but missing some required columns. (Minimum required columns: #{self.class::REQUIRED_COLS.join(', ')})"
        end
      else
        @errors[@lineNo] = "Found column headers, but there are only #{colNames.size} columns. Minimum is #{self.class::REQUIRED_COLS.size} columns. (Minimum required columns: #{self.class::REQUIRED_COLS.join(', ')})"
      end
      # @col2idx is a hash that connects column names to their location within the document
      @col2idx = {}
      # If bulk is disabled, it's a 1-to-1 relationship between column name and index
      unless(bulk)
        @columns.each_index { |idx| @col2idx[@columns[idx]] = idx }
      # Otherwise, it can be a 1-to-many relationship between column name and index
      else
        @columns.each_index { |idx|
          unless(@col2idx[@columns[idx]])
            @col2idx[@columns[idx]] = []
          end
          @col2idx[@columns[idx]] << idx
        }
      end
      # Save name column in @nameIdx since it always comes first in REQUIRED_COLS
      unless(bulk)
        @nameIdx = @col2idx[self.class::REQUIRED_COLS.first]
      else
        @nameIdx = @col2idx[self.class::REQUIRED_COLS.first][0]
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "END: Parse header for line #{@lineNo.inspect}")
      return @columns
    end

    # Parse the nesting and name information associated with a property
    # @param [String] propNameInfo String from tabbed document containing yet-broken down information about property (nesting info and name)
    # @return [Hash<Symbol, String>] Hash that contains broken down information about property's nesting info and name
    def parsePropNameInfo(propNameInfo)
      # Our hash propInfo will contain information about the current property (nesting and name)
      propInfo = {}
      # If propNameInfo contains some non-space characters, we can get started!
      if(propNameInfo and propNameInfo =~ /\S/)
        # We'll strip propNameInfo and break it into its nesting and name info
        propNameInfo.strip!
        propNameInfo  =~ /^(?:([\-\*]+)\s+)?(.+)$/
        propTreeInfo  = $1
        propName      = $2
        # Prop name can't be empty - if it is, we give an error
        if(propName !~ /\S/)
          @errors[@lineNo] = "The property name info in column #{@nameIdx.inspect} doesn't appear to have an actual name. From #{propNameInfo.inspect} we see there is #{propTreeInfo ? propTreeInfo.inspect : 'NO'} tree nesting info, but there is #{propName.inspect} for the property name. While the root property will have no tree information, ALL properties must have a name."
        else
          if(@seenRoot and !propTreeInfo) # Already seen root, but this record also looks like root
            @errors[@lineNo] = "A top-level property has already been seen. It is the only property with no tree nesting info. All other properties MUST be nested under the top level property. Yet the property here for #{propName.inspect} has no tree nesting information. It is also possible that you have new line characters in your value for a particular property. You must escape these characters (\\n) before submitting your document!"
          elsif(!@seenRoot and propTreeInfo)  # No root yet, but trying to define child properties nested within tree
              @errors[@lineNo] = "A top-level property has not been defined yet. But here we appear to have a sub-ordinate/child property called #{propName.inspect} because it has tree nesting information (#{propTreeInfo.inspect}). The top-level property must be seen FIRST, before any others that appear somewhere within the doc; the root property is the ONLY property that will have no tree-nesting information (obviously)."
          else # Should be ok to parse
            propInfo[:nesting]  = propTreeInfo
            propInfo[:name]     = propName
          end
        end
      else # If propNameInfo is empty or doesn't contain any non-space characters, we give an error
        @errors[@lineNo] = "Empty property name found. According to the column headers, the property name can be found in column #{@nameIdx.inspect}. But this non-blank line has nothing in that column. Not allowed; all properties must have names!"
      end
      # Finally, we return propInfo
      return propInfo
    end
  end # class TabbedModelConverter
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Converters
