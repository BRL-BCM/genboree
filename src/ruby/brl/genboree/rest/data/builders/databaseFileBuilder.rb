#!/usr/bin/env ruby

require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/rest/resources/databaseFile"
require "brl/genboree/abstract/resources/databaseFiles"
#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # DatabaseFileBuilder
  #  This implementation applies a Boolean Query to the contents of a tab-delimited
  #  file created as a result of a applying a query
  class DatabaseFileBuilder < Builder
    include BRL::Genboree::REST::Helpers
    include BRL::Genboree::REST::Data::Builders 
    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true
   
    # DISPLAY_NAMES: Place-holder constant for display names, in the event of a call to /REST/v1/queryable (or similar)
    # In the event of a call to /queryable on a specific file, header will parsed and returned as display names
    DISPLAY_NAMES = []

    RESPONSE_FORMAT = ""
    # LFF_FIELDNAMES: Constant to store database field names of LFF column headers
    LFF_FIELDNAMES = ['gclass','gname', 'fmethod', 'fsource', 'refname','fstart', 'fstop','fstrand','fphase','fscore','ftarget_start','ftarget_stop','attribute Comments','sequence','freestyle comments']
    # LFF_HEADER: All LFF columns for reference when doing transformation from LFF to TABBED format
    LFF_HEADER = ["class", "name", "type", "subtype", "Entry Point", "start", "stop", "strand", "phase", "score", "qStart", "qStop", "attribute comments", "sequence", "freestyle comments"]

    # LFF_REQUIRED: Core LFF columns for doing integrity check on LFF files
    LFF_REQUIRED = ["class", "name", "type", "subtype", "Entry Point", "start", "stop", "strand", "phase", "score"]
    
    def initialize(url)
      matches = DatabaseFileBuilder::pattern().match(url)
      @group = matches[1]
      @db = matches[2]
      @fileName = matches[3]
    end

    # This overridden method processes tab-delimited files by first mapping each piece of
    # data in a given line to an attribute name, then evaluating whether that line of data
    # succeeds all tests within the given query.  As such, while the method signature is
    # uniform with the superclass method, several items here are not used, including:
    # +dbu+, +refSeqId+, +userId+, and +detailed+. Additionally, +layout+ has not been
    # implemented yet.  
    # [+query+] Query used to examine the given file
    # [+format+] Limited to :TABBED and :LFF. :LFF files can be converted into :TABBED files,
    #           but :TABBED files cannot be converted into :LFF files.
    # [+returns+] This +DatabaseFileBuilder+. The object itself is built to yield data in blocks
    #           vi the DatabaseFileBuilder#each() method, similar to the DbAnnosBuilder.
    def applyQuery(query, dbu, refSeqId, userId, detailed=false, format=:TABBED, layout=nil)
      case(format)
      when :LFF, 'lff', 'text/lff'
        @format = :LFF
      when :TABBED, 'tabbed'
        @format = :TABBED
      else
        # Cannot handle this format, exit quickly
        @error = BRL::Genboree::GenboreeError.new(:'Bad Request',"The specified format (#{format.to_s.downcase}) is not supported")
        return self
      end
      # Find the file, path using the Database Files abstract class
      @dbFilesObj = BRL::Genboree::Abstract::Resources::DatabaseFiles.new(Rack::Utils.unescape(@group),Rack::Utils.unescape(@db))
      @dbFileHash = @dbFilesObj.findFileRecByFileName(@fileName)
      if(!@dbFileHash.nil?)
        @path = "#{@dbFilesObj.filesDir.path}/#{@dbFileHash['fileName']}"
      else
        @error = BRL::Genboree::GenboreeError.new(:'Not Found', "The file '#{@fileName}' could not be found in the database #{@db} in the group #{@group}.")
        return self
      end

      # Do some pre-processing of LFF files; This should only read 2 lines max (if an LFF file also has a ## header with
      # a resource type).
      if(@dbFileHash['fileName'].split('.').last == 'lff')
        @lff = true
        lffFile = File.open(@path)
        # Look at the first line of the file, check the integrity of the LFF header
        lffFile.each_line{|line|
          missingCols = []
          if(line.index("#") == 0 and line.index('##')==nil)
            #Get our original header to verify columns
            header = line.slice(1, line.length)
            header.gsub!("\n","")
            header = header.split(/\t/)
            LFF_REQUIRED.each{|column|
              if(!header.include?(column))
                missingCols << column
              end
            }
            if(missingCols.length > 0)
              msg = "There file you are querying does not adhere to LFF core requirements.  The following required columns are missing from the header: #{missingCols.join(",")} "
              @error = BRL::Genboree::GenboreeError.new(:'Bad Request', msg)
              return self
            else
              # Break once we've read the header so we don't read the rest of the file unnecessarily
              break
            end
          end
        }
        lffFile.close()
      else
        if(format == :LFF)
          @error = BRL::Genboree::GenboreeError.new(:'Bad Request', "The translation from tabbed to #{format.to_s.downcase} is not supported.")
          return self
        end
        @lff = false
      end
      @subjectFile = File.open(@path)
      
      @query = JSON.parse(query)
      return self
    end

    # Provided for returning the data in chunks streamed
    def each
       
      if(@error)
        yield ""
        return
      end

      buffer = ''
      displayNames = nil
      @marker = nil
      @cols = {}
      @lffToTabbed = false
      @lffToTabbedHeader = []
      # The following block is executed in the event that a query executed on an LFF file is requested in TABBED format
      # To properly construct the header, we'll need to read through the file twice: the first pass will gather all necessary
      # attributes from the 'attribute comments' column, the second pass will be the evaluation.
      if(@lff and @format == :TABBED)
        # Read through the file once to construct our header
        @lffToTabbed = true 
        marker = nil
        @subjectFile.each_line{|line|
          if(line.index("#") == 0 and line.index('##')==nil)
            #Get our original header to verify columns
            header = line.slice(1, line.length)
            header.gsub!("\n","")
            header = header.split(/\t/)
            LFF_HEADER.each_index{|ii|
              col = LFF_HEADER[ii]
              field = LFF_FIELDNAMES[ii]
              
              if(header.include?(col) && col !='attribute comments')
                # In the event that qStart or qStop have been ommitted, build an array @lffToTabbedHeader and hash @cols accordingly
                # @lffToTabbedHeader will use the column names as they appear in the file, plus new columns from avps, to construct a new header
                # @cols will serve as a fixed representation of which column number corresponds with which column name
                # In order to allow both queries using database field names as their attributes as well as queries using LFF field names as attributes
                # we'll store both as keys indicating the appropriate column number
                unless(col == 'sequence' || col == 'freestyle comments')
                  @lffToTabbedHeader[ii]=col
                  @cols[field]=ii
                  @cols[col]=ii
                else
                  # If either column 'sequence' or 'freestyle comments' exists, it's position will be changed after the removal of the attributes column.
                  # Since 'sequence' is not guaranteed, need to check for it's existence when inserting 'freestyle comments'.
                  posChange = (col=='sequence' || @cols.include?('sequence'))? 1 : 2
                  @lffToTabbedHeader[ii-posChange]=col
                  @cols[field]=ii-posChange
                  @cols[col]=ii-posChange
                end
              elsif(col == 'attribute comments')
                # Remember which column the avps were stored in
                @marker = ii
              end
            }
          else
            valueStr = line.gsub("\n","")
            element = valueStr.split(/\t/)
            if(!element[@marker].nil? and element[@marker] !='')
              avps = element[@marker].split(';')
              attributes = []
              avps.each{|avp|
                pair = avp.split('=')
                key = pair[0].strip
                attributes << key
              }
              keys = @cols.keys
              attributes.each{|item|
                if(!keys.include?(item))
                  # Append our new attribute to the header, add it to the @cols hash with the correct column as it appears in the header
                  pos = @lffToTabbedHeader.length
                  @lffToTabbedHeader[pos] = item
                  @cols[item]=pos
                end  
              }
            end
             
          end
        }
        #Close, then reopen, our subject file for our second read through. 
        @subjectFile.close
        @subjectFile = File.open(@path)
      end
      
      @subjectFile.each_line{|line|
        if(line.index("##") == 0)
          # Get the resource type, if available
          # Some of this string transformation code might need to change once the 'Apply Query' tool is in place
          rsrc = line.match(/##(\w+)\s+(\w+)/)[1] #Return the word after the '##'; leaving the second part of the expr in place in case we need 
          rsrc += "Builder"                       # the flag later
          const = BRL::Genboree::REST::Data::Builders::const_get(rsrc.to_sym)
          displayNamesArr = const::DISPLAY_NAMES
          displayNames = {}
          # Flatten the DISPLAY_NAMES constant into a regular hash, then invert it so that the format is 'displayName'=>'fieldName'
          displayNamesArr.map{|item| item.each_pair{|key, value| displayNames[key]=value } }
          displayNames = displayNames.invert
        elsif(line.index("#") == 0)
          if(@lffToTabbed)
            # Already gathered avp/header info, yield the header joined by tabs
            yield "##{@lffToTabbedHeader.join("\t")}\n"
          else
            #Ensure the header gets yielded, map our attributes to column numbers for comparison
            attrStr = line.slice(1, line.length)
            attrStr.gsub!("\n","")
            attrs = attrStr.split(/\t/) 
            
            attrs.each_index{|ii| 
              # If a value exists in the displayNames hash, translate it into it's field name;
              # otherwise, insert it 
              if(displayNames or @lff)
                if(displayNames)
                  key = (displayNames[attrs[ii]])? displayNames[attrs[ii]] : attrs[ii]
                elsif(@lff)
                  @marker = ii if attrs[ii]=='attribute comments'
                  key = LFF_FIELDNAMES[ii]
                end
                spareKey = attrs[ii]
                @cols[spareKey] = ii
              else
                key = attrs[ii]
              end
              @cols[key]=ii
              
            }
            yield line
          end
        else
          #Process the rest of the file
          #Start by putting the respective attributes in an array
          valueStr = line.gsub("\n","")
          element = valueStr.split(/\t/)
          if((@lffToTabbed or @lff) and (!element[@marker].nil? and element[@marker] !=''))
            avps = element[@marker].split(';')
            avpHash = {}
            avps.each{|avp|
              pair = avp.split('=')
              key = pair[0].strip
              avpHash[key] = pair[1]
            }
            if(@lff and !@lffToTabbed)
              #Convert 'attribute comments' column into a hash instead of a string
              element[@marker] = avpHash
            elsif(@lffToTabbed)
              #Delete the 'attribute comments column, map appropriate values to columns determined in header
              element.delete_at(@marker)
              avpHash.each_pair{|key, value|
                element[@cols[key]]=value
              }
            end
          end
          
          if(filterResults(@query, element, @cols))
            buffer += (@lffToTabbed)? "#{element.join("\t")}\n" : line
          end
          
          if(buffer.size > MAX_BUFFER_SIZE)
            yield buffer
            buffer = ''
          end
        end
      }
      yield buffer if(buffer.size > 0)

    end
    
    # Helper method to evaluate individual results against the new query.
    # Should recursively examine the query body and return a boolean if all requirements are met.
    # [+query+] The query body as passed by the each method or a previous call to filterResults
    # [+element+] The line of data to be inspected
    # [+header+] A hash mapping attribute names to column numbers
    # [+returns+] The result of evaluate(), once a single clause has been found
    def filterResults(query, element, header)
      if(query.class == Hash and query['attribute'])
        # Clause
        if(header.include?(query['attribute']))
          testValue = element[header[query['attribute']]]
          return evaluate(query, testValue)
        elsif(header.include?('attribute Comments') and element[header['attribute Comments']].include?(query['attribute']))
          testValue = element[header['attribute Comments']][query['attribute']]
          return evaluate(query, testValue)
        else 
          return false
        end
      elsif(query.class == Hash and query['body'])
        # Statement
        inverse = query['not']
        if(inverse)
          return !filterResults(query['body'], element, header)
        else
          return filterResults(query['body'], element, header)
        end
      elsif(query.class == Array)
        # Body of a statement
        if(query.length == 1)
          return filterResults(query.first, element, header)
        else
          bool = query[0]['bool']
          query.each{|item|
            # Greedily return a value based on the boolean stored and results of recursive call
            if(bool == 'AND' && !filterResults(item, element, header))
              return false
            elsif(bool == 'OR' && filterResults(item, element, header))
              return true
            end
          }
          # If all previous tests passed, this method will not have returned anything
          # Next branch ensures that the proper result is returned in this case.
          if(bool == 'AND')
            return true
          elsif(bool == 'OR')
            return false
          end
        end
      end    
    end
  
    # This method takes a single clause and test value and evaluates that value appropriately
    # given the "op" attribute of the clause provided, as well as the case sensitivity where
    # it is appropriate.
    # [+clause+] A hash passed from the filterResults method containing an attribute, operator, value
    #            and case sensitivity boolean.
    # [+testValue+] The relevant value for evaluation based on the line of data inspected by filterResults
    #               and the attribute value of the clause being evaluated.  The filterResults method does
    #               not verify the existence of a value, on the existence of the attribute in the header,
    #               so the value can be nil.
    # [+returns+] Returns false on testValue=nil, otherwise returns the boolean result of an evaluation of the test
    #             value against the clause provided.
    def evaluate(clause, testValue=nil)
      
      if(clause['value'].is_a?(String))
        value = clause['value'].gsub(/\\/, "\\").gsub(/'/, "\\'")
      elsif(clause['value'].is_a?(Numeric))
        value = clause['value']
      end

      # Process ranges properly
      if(value.to_s.index(".."))
        values = value.split("..")
        values[0] = values[0].to_f if(values[0].to_f.to_s == values[0])
        values[0] = values[0].to_i if(values[0].to_i.to_s == values[0])
        values[1] = values[1].to_f if(values[1].to_f.to_s == values[1])
        values[1] = values[1].to_i if(values[1].to_i.to_s == values[1])
      else
        values = []
      end
      
      if(testValue.nil?)
        return false
      else
        case clause['op']
        when "=~"
          r = Regexp.new(value)
          matches = r.match(testValue)
          if(matches)
            return true
          else
            return false
          end
        when "has":
          if(clause['case'] == "sensitive")
            return testValue.to_s.include?(value.to_s)
          else
            return testValue.to_s.downcase.include?(value.to_s.downcase)
          end
        when "==":
          if(value.is_a?(Numeric))
            return testValue.to_f == value
          elsif(value.is_a?(String) and value['case'] == 'sensitive')
            return testValue == value
          else
            return testValue.downcase == value.downcase
          end
        when "startsWith":
          testString = testValue.slice(0,value.length)
          if(clause['case'] == "sensitive")
            return testString == value
          else
            return testString.downcase == value.downcase
          end
        when "endsWith":
          testString = testValue.slice(testValue.length-value.length,value.length)
          if(clause['case'] == "sensitive")
            return testString == value
          else
            return testString.downcase == value.downcase
          end
        when "<":
          return testValue.to_f < value if(value.is_a?(Numeric))
          return testValue < value if(value.is_a?(String))
        when ">":
          return testValue.to_f > value if(value.is_a?(Numeric))
          return testValue > value if(value.is_a?(String))
        when ">=":        
          return testValue.to_f >= value if(value.is_a?(Numeric))
          return testValue >= value if(value.is_a?(String))
        when "<=":        
          return testValue.to_f <= value if(value.is_a?(Numeric))
          return testValue <= value if(value.is_a?(String))
        when "()":
          return (testValue.to_f > values[0] && testValue.to_f < values[1]) if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
          return (testValue > values[0] && testValue < values[1]) if(values[0].is_a?(String) or values[1].is_a?(String))
        when "(]":
          return (testValue.to_f > values[0] && testValue.to_f <= values[1]) if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
          return (testValue > values[0] && testValue <= values[1]) if(values[0].is_a?(String) or values[1].is_a?(String))
        when "[)":
          return (testValue.to_f >= values[0] && testValue.to_f < values[1]) if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
          return (testValue >= values[0] && testValue < values[1]) if(values[0].is_a?(String) or values[1].is_a?(String))
        when "[]":
          return (testValue.to_f >= values[0] && testValue.to_f <= values[1]) if(values[0].is_a?(Numeric) and values[1].is_a?(Numeric))
          return (testValue >= values[0] && testValue <= values[1]) if(values[0].is_a?(String) or values[1].is_a?(String))
        end

      end
    end

    # This +Builder+ subclass can handle the same URIs as the 
    # +BRL::REST::Resources::DatabaseFile+ class, so this method simply returns the
    # same RegExp from that class.
    def self.pattern()
      return BRL::REST::Resources::DatabaseFile.pattern()
    end


    # This method will inspect what type of content we are creating (depending
    # on the value of "format" used) and return an appropriate content type
    def content_type()
      
      return BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@format]
    end

  end # class DatabaseFileBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
