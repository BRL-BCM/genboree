#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/publicationEntity'
require 'brl/genboree/abstract/resources/publication.rb'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Publications - exposes information about all of the publications associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::PublicationEntity
  # * BRL::Genboree::REST::Data::PublicationEntityList
  # * BRL::Genboree::REST::Data::PartialPublicationEntity
  # * BRL::Genboree::REST::Data::PartialPublicationEntityList
  class Publications < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Publication

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/publications"

    RESOURCE_DISPLAY_NAME = "Publications"
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @dbName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      @filterType = @filter = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/publications(?:$|/attribute/([^/\?]+)/([^/\?]+)$)</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/publications(/{filter} - optional) URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/publications(?:$|/attribute/([^/\?]+)/([^/\?]+)$)}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/
      return 4
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        if(@uriMatchData[3] and @uriMatchData[4])
          @filterType = Rack::Utils.unescape(@uriMatchData[3])
          @filter = Rack::Utils.unescape(@uriMatchData[4])
        end
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/publication")
          
          # Get a list of all layouts for this db/group
          publicationRows = @dbu.selectAllPublications()
          publicationRows.sort! { |left, right| left['id'] <=> right['id'] }
          if(@filterType and @filter and !publicationRows.empty?)
            if(!publicationRows.first.to_h.key?(@filterType))
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_FILTER: You cannot filter publications by #{@filterType.inspect}")
            end
          end

          # Only continue if filter was valid
          if(@statusName == :OK)
            if(@detailed)
              # Process the "detailed" list response
              bodyData = BRL::Genboree::REST::Data::PublicationEntityList.new(@connect)
              publicationRows.each { |row|
                if(@filterType.nil? or @filter.nil? or row[@filterType] == @filter)
                  entity = BRL::Genboree::REST::Data::PublicationEntity.new(@connect, row['id'], row['pmid'], row['type'], row['title'], row['authorList'], row['journal'], row['meeting'], row['date'], row['volume'], row['issue'], row['startPage'], row['endPage'], row['abstract'], row['meshHeaders'], row['url'], row['state'] , row['language'], getAvpHash(@dbu, row['id']))
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['id'])}")
                  bodyData << entity
                end
              }
            else
              # Process the undetailed (names only) list response
              bodyData = BRL::Genboree::REST::Data::PartialPublicationEntityList.new(@connect)
              publicationRows.each { |row|
                if(@filterType.nil? or @filter.nil? or row[@filterType] == @filter)
                  entity = BRL::Genboree::REST::Data::PartialPublicationEntity.new(@connect, row['id'], row['type'], row['title'])
                  entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['id'])}")
                  bodyData << entity
                end
              }
            end
            @statusName = configResponse(bodyData)
            publicationRows.clear() unless (publicationRows.nil?)
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a PublicationEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      if(initStatus == :OK)
        # Check permission for inserts (must be author/admin of a group)
        if(@groupAccessStr == 'r')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a publication in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('PublicationEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a PublicationEntity")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type PublicationEntity")
          elsif(entity.id != nil)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_ID: You cannot specify an ID in the Entity for an insert (ID must be nil)")
          else
            # Insert the publication (silently ignore id)
            rowsInserted = @dbu.insertPublication(entity.pmid, entity.type, entity.title, entity.authorList, entity.journal, entity.meeting, entity.date, entity.volume, entity.issue, entity.startPage, entity.endPage, entity.abstract, entity.meshHeaders, entity.url, entity.state, entity.language)
            publicationId = @dbu.getLastInsertId(:userDB)
            if(rowsInserted == 1)
              unless(entity.avpHash.nil? or entity.avpHash.empty?)
                updateAvpHash(@dbu, publicationId, entity.avpHash)
              end
              # Get the newly created publication to return
              newPublicationRow = @dbu.selectPublicationsById(publicationId)
              newPublicationRow = newPublicationRow.first
$stderr.puts "hmm: #{publicationId.inspect}, #{newPublicationRow.inspect}"
              @statusName=:'Created'
              @statusMsg="The publication was successfully created."
              newPublication = BRL::Genboree::REST::Data::PublicationEntity.new(@connect, newPublicationRow['id'], newPublicationRow['pmid'], newPublicationRow['type'], newPublicationRow['title'], newPublicationRow['authorList'], newPublicationRow['journal'], newPublicationRow['meeting'], newPublicationRow['date'], newPublicationRow['volume'], newPublicationRow['issue'], newPublicationRow['startPage'], newPublicationRow['endPage'], newPublicationRow['abstract'], newPublicationRow['meshHeaders'], newPublicationRow['url'], newPublicationRow['state'] , newPublicationRow['language'], getAvpHash(@dbu, newPublicationRow['id']))
              newPublication.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/publication/#{newPublication.id}"))
              newPublication.setStatus(@statusName, @statusMsg)
              configResponse(newPublication, @statusName)
            end
          end
        end
      end

      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Publications
end ; end ; end # module BRL ; module REST ; module Resources
