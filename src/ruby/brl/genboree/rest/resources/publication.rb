#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/publicationEntity'
require 'brl/genboree/abstract/resources/publication'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Publication - exposes information about single Publication objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::PublicationEntity
  class Publication < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Publication
    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @dbName = @publicationId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/publication/{publication} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/publication/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/
      return 6
    end

    def initOperation()
      initStatus = super
      if(initStatus == :'OK')
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @publicationId = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectPublicationsById(@publicationId).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_PUBLICATION: The publication with id #{@publicationId.inspect} was not found in the database #{@dbName.inspect}."
          end
        end
      end
      return initStatus
    end
    
    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return @statusName
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/publication}")
        # Get the publication by id
        publicationRows = @dbu.selectPublicationsById(@publicationId)
        if(publicationRows != nil and publicationRows.length > 0)
          publicationRow = publicationRows.first
          avpHash = getAvpHash(@dbu, publicationRow['id'])
          entity = BRL::Genboree::REST::Data::PublicationEntity.new(@connect, publicationRow['id'], publicationRow['pmid'], publicationRow['type'], publicationRow['title'], publicationRow['authorList'], publicationRow['journal'], publicationRow['meeting'], publicationRow['date'], publicationRow['volume'], publicationRow['issue'], publicationRow['startPage'], publicationRow['endPage'], publicationRow['abstract'], publicationRow['meshHeaders'], publicationRow['url'], publicationRow['state'] , publicationRow['language'], avpHash)
          entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(publicationRow['id'])}")
          @statusName = configResponse(entity)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The publication #{@publicationId.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
        publicationRows.clear() unless (publicationRows.nil?)
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
      initStatus = initOperation()   
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create studies in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('PublicationEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type PublicationEntity")
        elsif(entity.nil?)
          # Cannot update a publication with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD: You must supply a PublicationEntity payload when performing a PUT on this resource")
        elsif(initStatus == :'Not Found' and entity)
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this Resource to insert a Publication")
        elsif(initStatus == :'OK' and entity)
          # Check the publication ID for a match
          if(@publicationId.to_i == entity.id)
            # Publication exists; update it.
            rowsUpdated = @dbu.updatePublicationById(@publicationId, entity.pmid, entity.type, entity.title, entity.authorList, entity.journal, entity.meeting, entity.date, entity.volume, entity.issue, entity.startPage, entity.endPage, entity.abstract, entity.meshHeaders, entity.url, entity.state, entity.language)

            # Always update AVPs (whether last update failed or not)
            updateAvpHash(@dbu, @publicationId, entity.avpHash)

            pubRows = @dbu.selectPublicationsById(@publicationId)
            pubRow = pubRows.first
            updatedPub = BRL::Genboree::REST::Data::PublicationEntity.new(@connect, pubRow['id'], pubRow['pmid'], pubRow['type'], pubRow['title'], pubRow['authorList'], pubRow['journal'], pubRow['meeting'], pubRow['date'], pubRow['volume'], pubRow['issue'], pubRow['startPage'], pubRow['endPage'], pubRow['abstract'], pubRow['meshHeaders'], pubRow['url'], pubRow['state'] , pubRow['language'], getAvpHash(@dbu, pubRow['id']))

            updatedPub.setStatus(@statusName, "The publication with id #{@publicationId.inspect} has been updated.")
            pubRows.clear() unless (pubRows.nil?)

            # Respond with the updates
            updatedPub.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/publication/#{Rack::Utils.escape(updatedPub.id)}"))
            configResponse(updatedPub, @statusName)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_ID: You cannot update this publication with this URL because the ID in the Entity (#{entity.id.inspect}) doesn't match the ID from the URL (#{@publicationId.inspect})")
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update publication #{@publicationId.inspect} in the database #{@dbName.inspect}")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.  NOTE: You must be a group
    # administrator in order to have permission to delete studies.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete publications in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the publication to be deleted
          avpDeletion = @dbu.deletePublication2AttributesByPublicationIdAndAttrNameId(@publicationId)
          deletedRows = @dbu.deletePublicationById(@publicationId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The publication with id #{@publicationId.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the publication with id #{@publicationId.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Publication
end ; end ; end # module BRL ; module REST ; module Resources
