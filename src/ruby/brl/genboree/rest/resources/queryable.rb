#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/refEntity'
require 'brl/genboree/rest/data/queryableInfoEntity'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Queryable - exposes information regarding which resources may be queried upon
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::RefEntity
  # * BRL::Genboree::REST::Data::TextEntity
  class Queryable < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports
    # ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'queryable'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @userId = @dbName = @queryName = @apiError = @resource = @rsrcMatchData = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>(^/REST/#{VER_STR}.*)/queryable$</tt>
    def self.pattern()
      # Look for /REST/v1/queryable or /REST/v1/*/queryable
      return %r{(^/REST/#{VER_STR}.*)/queryable$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # We want the query filter to have the lowest possible priority so that it
      # doesn't mistakingly grab URLs that should be designated to other resources
      # (ex] entities with name "query", or AVPs with attribute "query").
      return 4
    end

    # Overridden to meet our needs for matching resource list type.
    def initOperation()
      initStatus = super
      @rsrcMatchData = nil
      @groupName = nil
      @dbName = nil
      @rsrc = nil
      @rsrcName = nil

      if(initStatus == :OK)
        # Get the portion of the url to test against other resources' patterns

        unless(@uriMatchData[1] == '/REST/v1')
          priority = 0
          BRL::REST::Resources.constants.each{|constName|
            const = BRL::REST::Resources.const_get(constName.to_sym)
            if(const.pattern().match(@uriMatchData[1]))
              if(const.priority > priority)
                priority = const.priority
                @rsrc = const
                @rsrcName = constName
                @rsrcMatchData = const.pattern().match(@uriMatchData[1])
              end
            end
          }
          if(@rsrc.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "This url cannot be used to access the queryable resource.")
          end
        end

        unless(@rsrcMatchData.nil?)
          @groupName = (@rsrcMatchData[1].nil?)? Rack::Utils.unescape(@rsrcMatchData[3]) : Rack::Utils.unescape(@rsrcMatchData[1])
          @dbName = (@rsrcMatchData[2].nil?)? nil : Rack::Utils.unescape(@rsrcMatchData[2])
          @fileName = (@rsrcMatchData[3].nil? || (@rsrcMatchData[3]==@groupName))? nil : Rack::Utils.unescape(@rsrcMatchData[3])
          $stderr.puts "File Name: #{@fileName}"
        end
        unless(@groupName.nil? or @dbName.nil?)
          initStatus = initGroupAndDatabase()
        end
      end

      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] RefEntityList of queryable resources.
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@rsrcName == "Group" || @rsrcName == "Database" || @rsrc.nil?)
          # handle /REST/v1/queryable, /REST/v1/grp/{grp}/db/{db}/queryable, /REST/v1/grp/{grp}/queryable
          queryableRsrcs = BRL::Genboree::REST::Data::QueryableInfoEntityList.new()
          BRL::REST::Resources.constants.each { |constName|
            # Retrieve the Constant object
            const = BRL::REST::Resources.const_get(constName.to_sym)
            if(const.queryable?())
              unless(const.templateURI().nil?)
                uri = const.templateURI()
                if(@groupName)
                  uri = uri.gsub('{grp}',Rack::Utils.escape(@groupName))
                end
                if(@dbName)
                  uri = uri.gsub('{db}',Rack::Utils.escape(@dbName))
                end
                unless((@dbName && !@dbName.empty?) && (@groupName &&  !@groupName.empty?))
                  displayNames = const.getAllAttributesWithDisplayNames()
                else
                  displayNames = const.getAllAttributesWithDisplayNames(@dbu)
                end
                rsrcDisplayName = const::RESOURCE_DISPLAY_NAME
                respFormat = const.getRespFormat()
                rsrcEntity = BRL::Genboree::REST::Data::QueryableInfoEntity.new(false, constName, true, displayNames, uri, rsrcDisplayName, respFormat)
                queryableRsrcs << rsrcEntity
              end
            end
          }
          queryableRsrcs.sort!{|aa,bb| aa.resource.downcase<=>bb.resource.downcase}
          configResponse(queryableRsrcs)
        else
          # Handle individual resrouces (/REST/v1/grp/{grp}/db/{db}/{rsrc}/queryable)
          queryable = nil
          fileExists = true
          path = ''
          if(@rsrcName=='DatabaseFile' and @fileName)
            #Make sure our file exists
            @dbFilesObj = BRL::Genboree::Abstract::Resources::DatabaseFiles.new(@groupName, @dbName)
            @dbFileHash = @dbFilesObj.findFileRecByFileName(@fileName)
            if(@dbFileHash)
              path = "#{@dbFilesObj.filesDir.path}/#{@dbFileHash['fileName']}"
            else
              fileExists = false
            end
          end

          if(@rsrc.queryable?() and fileExists)
            displayNames = @rsrc.getAllAttributesWithDisplayNames(@dbu,path)
            respFormat = @rsrc.getRespFormat(path)
            uri = @rsrc.templateURI()
            uri =(@groupName)? uri.gsub('{grp}',Rack::Utils.escape(@groupName)) : uri
            uri =(@dbName)? uri.gsub('{db}',Rack::Utils.escape(@dbName)) : uri
            uri =(@fileName)? uri.gsub('{file}',Rack::Utils.escape(@fileName)) : uri
            rsrcDisplayName = @rsrc::RESOURCE_DISPLAY_NAME
            queryable = BRL::Genboree::REST::Data::QueryableInfoEntity.new(@connect, @rsrcName, true, displayNames, uri, rsrcDisplayName, respFormat)
          elsif(!objExists)
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found',"The file #{@fileName.inspect} was not found in the database #{@dbName} in the group #{@groupName}.")
          else
            queryable = BRL::Genboree::REST::Data::QueryableInfoEntity.new(@connect, @rsrcName, false)
          end
          configResponse(queryable) if(!@apiError)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Queryable
end ; end ; end # module BRL ; module REST ; module Resources
