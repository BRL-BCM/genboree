#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/database'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # Data representation classes used:
  # * _none_, gets and delivers raw LFF text directly.
  class DbClasses < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/classes$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/classes$}     
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        # This function will set @groupId and @refSeqId if it exist, return value is :OK or :'Not Found'
        initStatus = initGroupAndDatabase()
      end
      return initStatus
    end

    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/class") if(@connect)
        entityList = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
        classList = []
        # foreach of the databases template / user
        # Get all refseq DB names (userDB & shared/template DB)
        allDBs = dbu.selectDBNamesByRefSeqID(@refSeqId)        
        allDBs.each { |uploadRow|
          dbName = uploadRow['databaseName']
          refseqRows = @dbu.selectRefseqByDatabaseName(dbName)
          dbRefSeqId = refseqRows.first['refSeqId']
          refseqRows.clear()
          @dbu.setNewDataDb(dbName)
          classRows = @dbu.selectAllGIDs()
          classRows.each { |row|
            classList << row['gclass']
          }
        }
        classList.uniq!
        # Sort alphabetically
        classList.sort! { |left, right| left.downcase <=> right.downcase }
        classList.each { |className|
          entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, className)
          entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(className)}") if(@connect)
          entityList << entity
        }
        entityList.setStatus(:OK, "")
        @statusName = configResponse(entityList)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp 
    end
    
  end
end ; end ; end # module BRL ; module REST ; module Resources