#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/plainTextFileIO'
require 'brl/genboree/rest/data/columnsDataEntity'
require 'brl/genboree/rest/em/deferrableBodies/deferrableDelegateBody'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  # @todo BUG! in JSON, YAML, XML wrapped section below
  # @todo BUG! Doesn't read from file async. Reads all lines and transforms before letting go! Use a Deferrable Body!
  class PlainTextResource < BRL::REST::Resources::GenboreeResource
    Abstraction = BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'plainTextRsrc'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/resources/plainTexts/([^/\?]+)/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      if(@statusName == :OK)
        @fileDir = Rack::Utils.unescape(@uriMatchData[1])
        @fileName = Rack::Utils.unescape(@uriMatchData[2])
        @prefixFilter = @nvPairs['prefixFilter']
        @maxNumRecords = @nvPairs['maxNumRecords']
      end
      return @statusName
    end

    # Process a GET operation on this resource.
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      # If something wasn't right, represent as error
      if(initStatus == :OK)
        # Build path to resource file
        filePath = "#{@genbConf.resourcesDir}/plainTexts/#{CGI.escape(@fileDir)}/#{CGI.escape(@fileName)}"
        # Check exists
        if(File.exist?(filePath))
          ioObj = nil
          # If doing prefix filtering, process file differently (it will also do maxNumRecords if appropriate)
          if(@prefixFilter or @maxNumRecords)
            ioObj = Abstraction::PlainTextFileIO.new(filePath, @maxNumRecords, @prefixFilter)
          # Else, just give up whole file.
          else
            # Send file
            ioObj = File.open(filePath, 'r')
          end

          # What format to send data in?
          #$stderr.puts "#{self.class} #{__method__}: format: #{@repFormat.inspect}"
          if(@repFormat == :TABBED)
            # As-is, but send chunks properly async
            deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableDelegateBody.new(:delegate => ioObj, :yield => true)
            @resp.body = deferrableBody
          else # JSON, YAML, XML wrapped
            # @todo BUG! Doesn't read from file async. Reads all lines and transforms before letting go! Use a Deferrable Body!
            # Get lines and wrap as TextEntityList
            entities = []
            ioObj.each_line { |line|
              columns = line.strip.split(/\t/)
              entity = BRL::Genboree::REST::Data::ColumnsDataEntity.new(@connect, columns)
              entities << entity
            }
            ioObj.close if(ioObj.respond_to?(:close))
            # Create TextEntityList
            entityList = BRL::Genboree::REST::Data::ColumnsDataEntityList.new(@connect, entities)
            # Config response
            configResponse(entityList)
          end
          @resp.status = HTTP_STATUS_NAMES[:OK]
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_FILE: The file name '#{@fileName}' could not located in the directory '#{@fileDir}'."
          $stderr.puts "NO_FILE: Asset file path #{filePath.inspect} does not exist."
        end
      else
        @statusName = initStatus
        @statusMsg = "NO_FILE: The file name '#{@fileName}' in directory '#{@fileDir}' could not be located." unless(@statusMsg.to_s != 'OK')
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
