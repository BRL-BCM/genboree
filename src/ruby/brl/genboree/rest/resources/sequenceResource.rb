#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/em/deferrableBodies/deferrableFileReaderBody'
require 'brl/genboree/rest/resources/genboreeResource'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class SequenceResource < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'sequenceRsrc'

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
      return %r{^/REST/#{VER_STR}/resources/sequence/([^/\?]+)/fasta/([^/\?]+)$}
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
        @dbVer = Rack::Utils.unescape(@uriMatchData[1])
        @dbVer.downcase!
        @seqFileName = Rack::Utils.unescape(@uriMatchData[2])
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
        seqFilePath = "#{@genbConf.resourcesDir}/sequences/#{CGI.escape(@dbVer)}/fasta/#{CGI.escape(@seqFileName)}"
        # Check exists
        if(File.exist?(seqFilePath))
          # Send file
          deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableFileReaderBody.new(:path => seqFilePath, :yield => true)
          @resp.body = deferrableBody
          @resp.status = HTTP_STATUS_NAMES[:OK]
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_SEQ_FILE: The file name '#{@seqFileName}' could not located for genome assembly version '#{@dbVer}'."
          $stderr.puts "NO_SEQ_FILE: Asset file path #{seqFilePath.inspect} does not exist."
        end
      else
        @statusName = initStatus
        @statusMsg = "NO_SEQ_FILE: No asset file '#{@seqFileName}' could be located for genome assembly version '#{@dbVer}'." unless(@statusMsg.to_s != 'OK')
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
