
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module Abstract ; module Resources
  # This module provides functionality for saving and maintaining data to disk in an index file.
  # It's primarily used by the various project components but is also used for the database files
  module DataIndexFile
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = ''
    # The type of data stored in the data file
    DATA_FORMAT = :TXT

    # Full path to data file
    attr_accessor :dataFileName
    # The raw text data read from the DATA_FILE
    attr_accessor :dataStr
    # The parsed data read from the DATA_FILE (could be the String contents themselves, Ruby Array/Hash from a JSON.parse(), etc)
    attr_accessor :data

    # Read all of data file into memory. Stores in #dataStr.
    # [+returns+] #dataStr, now the contents of the data file or an empty string if file non-existing
    def readDataFile()
      if(File.exist?(@dataFileName) and File.readable?(@dataFileName))
        reader = File.openWithLock(@dataFileName, "a+")
        @dataStr = reader.read().strip
        reader.releaseLock()
        reader.close()
      else
        @dataStr = ''
      end
      return @dataStr
    end

    # TODO: This is a no-op. Remove its usage from everywhere
    def clearIndexFile()
    end

    # Parse #dataStr. Store in #data.
    # (Could be the String contents themselves, Ruby Array/Hash from a JSON.parse(), etc)
    # [+returns+] #data, now the parsed contents of the data file (like a String for simple components, Array of Hashes for complex compoents)
    def parseDataStr(format=self.class::DATA_FORMAT)
      @data = nil
      case format
        when :TXT
          @data = @dataStr
        when :JSON
          if(@dataStr.nil? or @dataStr.empty? or @dataStr !~ /\S/)
            @data = ''
          else
            @data = JSON(@dataStr)
            @data.delete_if { |rec|
              rec.has_value?(nil)
            }
          end
      end
      return @data
    end

    # Convert this component [back?] to JSON. If its data file stores the component
    # as JSON, this should reconstruct the contents of the data file essentially.
    # The only difference is for empty data files: The JSON equivalent of an empty String
    # is '""' (i.e. String with "") but you wouldn't want to store that in the data file--
    # nor would you want to parse that via JSON.parse() since strings can't be outside of
    # arrays or hashes in JSON [for some reason].
    # [+returns+] This component as a JSON string. Suitable for including in javascript
    #             portions of web pages and such.
    def to_json()
      retVal = ''
      if(@data)
        begin
        retVal = JSON.pretty_generate(@data)
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "problem with this @data:\n\n#{@data.inspect}\n\n")
          raise err
        end
      end
      return retVal
    end

    # Represent as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # _NOTE: sub-classes must implement this, it is very component specific_
    #
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+]   A Hash representing the component, often having an Array for the :children key (which is an Array of Hashes defining child nodes...)
    def to_extjsTreeNode(expanded=false)
      return nil
    end

    # Is this component empty of contents?
    # [+returns+] true if yes, false if no
    def empty?()
      return (@data.nil? or @data.empty?)
    end

    # Replaces this component's data file contents with the +String+ data provided.
    # It is assumed that the content is correctly formatted, etc (no validation is done).
    #
    # [+content+] The +String+ containing the new contents for this component's data file; if nil, then this will truncate the file to 0 bytes.
    # [+returns+] true or some kind of IO related Exception is raised
    def replaceDataFile(content)
      begin # must try to rescue any problems and attempt lock release
        writer = File.openWithLock(@dataFileName, 'w+')
        unless(content.nil?)
          #$stderr.puts "#{self.class}##{__method__}; content size: #{content.size}"
          # write out data if content has data; if content nil don't write--results in wiping the file (so it's correctly empty)
          writer.write(content) unless(content.nil? or content.empty?)
          writer.flush()
        end
        retVal = true
      rescue Exception => ex
        retVal = false
      ensure
        xx = (writer.releaseLock() rescue false)
        writer.close() rescue false
      end
      # Update representation in this object
      @dataStr = content
      parseDataStr()
      return retVal
    end
  end
end ; end ; end ; end
