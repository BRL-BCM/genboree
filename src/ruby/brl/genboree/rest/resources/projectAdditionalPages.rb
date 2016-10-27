#!/usr/bin/env ruby
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/projectFileEntity'
require 'brl/genboree/rest/data/refsEntity'
require 'brl/genboree/abstract/resources/fileManagement'
require 'brl/genboree/rest/em/deferrableBodies/deferrableFileReaderBody'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # ProjectAdditionalPages - for putting/getting/deleting files to the 'genb^^additionalPages' dir of a project.
  #
  class ProjectAdditionalPages < BRL::REST::Resources::GenboreeResource
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'projectAdditionalPages'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @context.clear() if(@context)
      @topLevelProjs.clear() if(@topLevelProjs)
      @projectObj = @topLevelProjs = @projBaseDir  = @escProjName = @projDir = @projName = @aspect = @context = nil
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/additionalPages/file/([^\?]+)(?:\?.*)?$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/prj/([^/\?]+)/additionalPages/file/([^\?]+)(?:\?.*)?$}       # Look for /REST/v1/group/{grp}/prj/{prj}/additionalPages/file/{path to file} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving projects etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @prjName = Rack::Utils.unescape(@uriMatchData[2])
        @fileName = Rack::Utils.unescape(@uriMatchData[3])
        # Check that @fileName does not have '^../' or '/../'. That will be a bad request
        # If @fileName has '^./' or '/./', replace it with '' and '/' respectively
        if(@fileName =~ /^\.\.\// or @fileName =~ /\/\.\.\//)
          @statusName, @statusMsg = :"Bad Request", "file names cannot have '../' or '/../'."
          initStatus = :'Bad Request'
        end
        # If @fileName begins with a './ or has a '/./' in the middle replace them appropriately
        @fileName.gsub!(/^\.\//, '')
        @fileName.gsub!(/\/\.\//, '/')
        @prjFileBase = "#{@genbConf.gbProjectContentDir}/#{CGI.escape(@prjName)}"
        if(!File.exists?(@prjFileBase))
          @statusName, @statusMsg = :"Not Found", "There is no project: #{@prjName} in Group: #{@groupName}"
          initStatus = :'Not Found'
        else
          @additionalPagesDir = "#{@prjFileBase}/genb^^additionalPages"
          FileUtils.mkdir_p(@additionalPagesDir)
          @filesDir = Dir.new(@additionalPagesDir)
        end
      end
      return initStatus
    end

    def getFullFilePath(fileName=@fileName)
      retVal = ''
      # Make path to file
      safeFileName = File.makeSafePath(fileName)
      if(safeFileName and !safeFileName.empty?)
        retVal = "#{@additionalPagesDir}/#{safeFileName}"
      end
      return retVal
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          fullFilePath = getFullFilePath(@fileName)
          # Now have non-empty fullFilePath which points to actual file, or file not found
          if(!fullFilePath.empty? and File.exist?(fullFilePath))
            deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableFileReaderBody.new(:path => fullFilePath, :yield => true)
            @resp.body = deferrableBody
            @resp.status = HTTP_STATUS_NAMES[:OK]
            @resp['Content-Type'] = 'application/octet-stream'
          else # couldn't find file
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: The file #{@fileName.inspect} (under genb^^additionalPages) could not be found for project #{@prjName.inspect} in user group #{@groupName.inspect}."
          end
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
          @statusName = :'Internal Server Error'
          @statusMsg = "FATAL: #{err}."
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          extract = false
          if(@nvPairs.key?('extract') and @nvPairs['extract'] == 'true')
            extract = true
          end
          writeFile(@fileName, @req.body, true, extract, false, []) # In the mixed-in class Abstract::Resources::FileManagement
          respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, :Accepted, msg="ACCEPTED: Upload of file to Project (under genb^^additionalPages) #{@prjName.inspect}, file: #{@fileName.inspect}, accepted. Final storage of file may be ongoing.")
          @statusName = configResponse(respEntity, :Accepted)
          @statusMsg = respEntity.msg
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
          @statusName = :'Internal Server Error'
          @statusMsg = "FATAL: #{err}."
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK or @statusName != :Accepted)
      return @resp
    end


    # Process a DELETE operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          fullFilePath = getFullFilePath(@fileName)
          `rm -f #{fullFilePath}`
          respEntity = BRL::Genboree::REST::Data::TextEntity.new(@connect, '')
          respEntity.setStatus(:OK, "The file #{@fileName.inspect} has been deleted.")
          @statusName = configResponse(respEntity)
        rescue Exception => err
          $stderr.puts err
          $stderr.puts err.backtrace.join("\n")
          @statusName = :'Internal Server Error'
          @statusMsg = "FATAL: #{err}."
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK or @statusName != :Accepted)
      return @resp
    end

  end # class ProjectAdditionalFiles
end ; end ; end # module BRL ; module REST ; module Resources
