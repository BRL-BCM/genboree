#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/bioSampleEntity'
require 'brl/genboree/abstract/resources/bioSample'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSample - exposes information about single BioSample objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::BioSampleEntity
  class BioSample < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSample
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
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
      @dbName = @bioSampleName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/bioSample/{bioSample} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:bioS|s)ample/([^/\?]+)$}
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
        @bioSampleName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectBioSampleByName(@bioSampleName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_BIOSAMPLE: The sample #{@bioSampleName.inspect} was not found in the database #{@dbName.inspect}."
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
        refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample")
        # Get the bioSample by name
        bioSampleRows = @dbu.selectBioSampleByName(@bioSampleName)
        if(bioSampleRows != nil and bioSampleRows.length > 0)
          bioSampleRow = bioSampleRows.first
          avpHash = getAvpHash(@dbu, bioSampleRow['id'])
          entity = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, bioSampleRow['name'], bioSampleRow['type'], bioSampleRow['biomaterialState'], bioSampleRow['biomaterialProvider'], bioSampleRow['biomaterialSource'] , bioSampleRow['state'], avpHash)
          entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(bioSampleRow['name'])}")
          @statusName = configResponse(entity)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The sample #{@bioSampleName.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
        bioSampleRows.clear() unless (bioSampleRows.nil?)
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a BioSampleEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create samples in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('BioSampleEntity')
        $stderr.puts "entity: #{entity.inspect}"
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type BioSampleEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a bioSample with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity != nil and entity.name != @bioSampleName and bioSampleExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a sample in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a bioSample with default values
          rowsInserted = @dbu.insertBioSample(@bioSampleName, "", "", "","")
          if(rowsInserted == 1)
            # Get the newly created bioSample to return
            newBioSampleRows = @dbu.selectBioSampleByName(@bioSampleName)
            newBioSample = newBioSampleRows.first
            @statusName=:'Created'
            @statusMsg="The sample was successfully created."
            avpHash = getAvpHash(@dbu, newBioSample['id'])
            respBody = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, newBioSample['name'], newBioSample['type'], newBioSample['biomaterialState'], newBioSample['biomaterialProvider'], newBioSample['biomaterialSource'], newBioSample['state'], avpHash)
            respBody.setStatus(@statusName, @statusMsg)
            respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample/#{Rack::Utils.escape(newBioSample['name'])}"))
            configResponse(respBody, @statusName)
            newBioSampleRows.clear() unless(newBioSampleRows.nil?)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sample #{@bioSampleName.inspect} in the data base #{@dbName.inspect}")
          end
        elsif(initStatus == :'Not Found' and entity)
          if(entity.name == @bioSampleName)
            # Insert the bioSample
            rowsInserted = @dbu.insertBioSample(entity.name, entity.type, entity.biomaterialState, entity.biomaterialProvider, entity.biomaterialSource, entity.state)
            if(rowsInserted == 1)
              # Get the newly created bioSample to return
              newBioSampleRows = @dbu.selectBioSampleByName(entity.name)
              newBioSample = newBioSampleRows.first
              bioSampleId = newBioSample['id']
              updateAvpHash(@dbu, bioSampleId, entity.avpHash)
              @statusName=:'Created'
              @statusMsg="The sample #{entity.name} was successfully created."
              respBody = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, newBioSample['name'], newBioSample['type'], newBioSample['biomaterialState'], newBioSample['biomaterialProvider'], newBioSample['biomaterialSource'], newBioSample['state'], avpHash)
              respBody.setStatus(@statusName, @statusMsg)
              respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample/#{Rack::Utils.escape(newBioSample['name'])}"))
              configResponse(respBody, @statusName)
              newBioSampleRows.clear() unless(newBioSampleRows.nil?)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sample #{entity.name.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a sample of a different name")
          end
        elsif(initStatus == :'OK' and entity)
          # BioSample exists; update it.
          bioSampleRows = @dbu.selectBioSampleByName(@bioSampleName)
          bioSampleRow = bioSampleRows.first
          bioSampleId = bioSampleRow['id']
          rowsUpdated = @dbu.updateBioSampleById(bioSampleId, entity.name, entity.type, entity.biomaterialState, entity.biomaterialProvider, entity.biomaterialSource, entity.state)

          # If the only value being updated is the bioSample name and it is identical
          # to the old bioSample name, rowsUpdated returns 0.  Handling that case
          # here instead of in dbUtil to avoid making a mess of the
          # updateBioSampleById method.
          rowsUpdated = 1 if(entity.name == @bioSampleName and rowsUpdated == 0)

          if(rowsUpdated == 1)
            # Always update AVPs (whether "moved" or not)
            updateAvpHash(@dbu, bioSampleId, entity.avpHash)
            bioSampleObj = nil

            # Check if we are "moved" or just updated
            if(entity.name == @bioSampleName)
              changedBioSampleRows = @dbu.selectBioSampleByName(entity.name)
              changedBioSample = changedBioSampleRows.first
              bioSampleObj = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, changedBioSample['name'], changedBioSample['type'], changedBioSample['biomaterialState'], changedBioSample['biomaterialProvider'], changedBioSample['biomaterialSource'], changedBioSample['state'] )
              bioSampleObj.setStatus(@statusName, "The sample #{entity.name.inspect} has been updated." )
              changedBioSampleRows.clear() unless (changedBioSampleRows.nil?)
            else
              renamedBioSampleRows = @dbu.selectBioSampleByName(entity.name)
              renamedBioSample = renamedBioSampleRows.first
              @statusName = :'Moved Permanently'
              bioSampleObj = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, renamedBioSample['name'], renamedBioSample['type'], renamedBioSample['biomaterialState'], renamedBioSample['biomaterialProvider'], renamedBioSample['biomaterialSource'], renamedBioSample['state'] )
              bioSampleObj.setStatus(@statusName, "The sample #{@bioSampleName.inspect} has been renamed to #{entity.name.inspect}.")
              renamedBioSampleRows.clear() unless (renamedBioSampleRows.nil?)
            end

            # Respond with the updates
            bioSampleObj.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample/#{Rack::Utils.escape(bioSampleObj.name)}"))
            configResponse(bioSampleObj, @statusName)
          end
          bioSampleRows.clear() unless(bioSampleRows.nil?)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update layout #{@bioSampleName.inspect} in the database #{@dbName.inspect}")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete samples in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the bioSample to be deleted
          bioSampleRow = @dbu.selectBioSampleByName(@bioSampleName)
          bioSampleId = bioSampleRow.first['id']
          avpDeletion = @dbu.deleteBioSample2AttributesByBioSampleIdAndAttrNameId(bioSampleId)
          deletedRows = @dbu.deleteBioSampleById(bioSampleId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The sample #{@bioSampleName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the sample #{@bioSampleName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class BioSample
end ; end ; end # module BRL ; module REST ; module Resources
