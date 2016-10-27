#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class ToolAsset < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

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
      return %r{^/REST/#{VER_STR}/genboree/tool/([^/\?]+)/asset/([^\?]+)$}
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
        @toolIdStr = Rack::Utils.unescape(@uriMatchData[1])
        @assetFileName = Rack::Utils.unescape(@uriMatchData[2])
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
        # Build path to asset file
        # - First, ensure each component of asset path is escaped
        # - Thus we'll support folks knowing how to do it properly (escape file name, regardless of whether file name based on escaped name)
        #   and mistakes (provided unescape file names or subdirs, oops)
        nameComponents = @assetFileName.split(/\//)
        rebuiltName = ''
        nameComponents.each { |comp|
          unless(comp.index('%'))
            rebuiltName << "#{CGI.escape(comp)}/"
          else # already escaped file name, good
            rebuiltName << comp
          end
        }
        rebuiltName.chomp!("/")
        assetFilePath = "#{@genbConf.resourcesDir}/tools/#{CGI.escape(@toolIdStr)}/assets/#{rebuiltName}"
        # Check exists
        if(File.exist?(assetFilePath))
          # Send file
          assetFile = File.open(assetFilePath, 'r')
          @resp.body = assetFile
          @resp.status = HTTP_STATUS_NAMES[:OK]
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_ASSET: The file name '#{@assetFileName}' could not located for the tool '#{@toolIdStr}'."
          $stderr.puts "NO_ASSET: Asset file path #{assetFilePath.inspect} does not exist."
        end
      else
        @statusName = initStatus
        @statusMsg = "NO_ASSET: No asset file '#{@assetFileName}' could be located for the tool '#{@toolIdStr}'." unless(@statusMsg.to_s != 'OK')
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
