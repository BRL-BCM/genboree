#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/util/checkSumUtil'
require 'brl/util/expander'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/abstract/resources/databaseFiles'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/numericEntity'
require 'brl/genboree/rest/data/databaseFileEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/abstract/resources/staticFileHandler'
require 'brl/genboree/rest/data/fileEntity'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class FileData < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    HTTP_METHODS = { :get => true, :head => true }
    RSRC_TYPE = 'fileData'

    #INTERFACE. CLEANUP: Inheriting classes should also implement any specific
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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/fileData/([^\?]+)$}
    end


    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7         
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])

        # Check that @fileName does not have '^../' or '/../'. That will be a bad request
        # If @fileName has '^./' or '/./', replace it with '' and '/' respectively
        initStatus = initGroupAndDatabase()
        if(@fileName =~ /^\.\.\// or @fileName =~ /\/\.\.\//)
          @statusName, @statusMsg = :"Bad Request", "file names cannot have '../' or '/../'."
          initStatus = :'Bad Request'
        end
        # If @fileName begins with a './ or has a '/./' in the middle replace them appropriately
        @fileName.gsub!(/^\.\//, '')
        @fileName.gsub!(/\/\.\//, '/')
      end
      return initStatus
    end

    # Process HEAD operation on this resource
    def head()
      begin
        # get the response from get(), performing its same validations
        @resp = get()
        if((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
          # then we need to remove the body from the response according to the http
          # requirements of the HEAD request, headers should be identical between
          # get and head
          @resp.body = []
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Process a GET operation on this resource
    # @return [Rack::Response] the response to the get request
    def get()
      begin
        initStatus = initOperation()
        if(initStatus == :OK)
          # alias of databaseFileAspect resource; match data there: group, db, file, aspect
          mockMatchData = [nil, Rack::Utils.escape(@groupName), Rack::Utils.escape(@dbName),
                           Rack::Utils.escape(@fileName), Rack::Utils.escape("data")]
          databaseFileAspectRes = BRL::REST::Resources::DatabaseFileAspect.new(@req, @resp, mockMatchData)
          @resp = databaseFileAspectRes.get()
          @statusName = databaseFileAspectRes.statusName
          @statusMsg = databaseFileAspectRes.statusMsg
        else
          @statusName = initStatus
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
