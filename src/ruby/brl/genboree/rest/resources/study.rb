#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/studyEntity'
require 'brl/genboree/abstract/resources/study'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Study - exposes information about single Study objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::StudyEntity
  class Study < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Study
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
      @dbName = @studyName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/study/{study} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/study/([^/\?]+)$}
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
        @studyName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectStudyByName(@studyName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_STUDY: The study #{@studyName.inspect} was not found in the database #{@dbName.inspect}."
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
        refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study}")
        # Get the study by name 
        studyRows = @dbu.selectStudyByName(@studyName)
        if(studyRows != nil and studyRows.length > 0)
          studyRow = studyRows.first
          avpHash = getAvpHash(@dbu, studyRow['id'])
          entity = BRL::Genboree::REST::Data::StudyEntity.new(@connect, studyRow['name'], studyRow['type'], studyRow['lab'], studyRow['contributors'], studyRow['state'], avpHash)
          entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(studyRow['name'])}")
          @statusName = configResponse(entity)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The study #{@studyName.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
        studyRows.clear() unless (studyRows.nil?)
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a StudyEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()   
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create studies in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('StudyEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type StudyEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a study with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity != nil and entity.name != @studyName and studyExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a study in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a study with default values
          rowsInserted = @dbu.insertStudy(@studyName, "", "", "")
          if(rowsInserted == 1)
            # Get the newly created study to return
            newStudyRows = @dbu.selectStudyByName(@studyName)
            newStudy = newStudyRows.first
            @statusName=:'Created'
            @statusMsg="The study was successfully created."
            avpHash = getAvpHash(@dbu, newStudy['id'])
            respBody = BRL::Genboree::REST::Data::StudyEntity.new(@connect, newStudy['name'], newStudy['type'], newStudy['lab'], newStudy['contributors'], newStudy['state'], avpHash)
            respBody.setStatus(@statusName, @statusMsg)
            respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study/#{Rack::Utils.escape(newStudy['name'])}"))
            configResponse(respBody, @statusName)
            newStudyRows.clear() unless(newStudyRows.nil?)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create study #{@studyName.inspect} in the data base #{@dbName.inspect}")
          end
        elsif(initStatus == :'Not Found' and entity)
          if(entity.name == @studyName)
            # Insert the study
            rowsInserted = @dbu.insertStudy(entity.name, entity.type, entity.lab, entity.contributors, entity.state)
            if(rowsInserted == 1)
              # Get the newly created study to return
              newStudyRows = @dbu.selectStudyByName(entity.name)
              newStudy = newStudyRows.first
              studyId = newStudy['id']
              updateAvpHash(@dbu, studyId, entity.avpHash)
              @statusName=:'Created'
              @statusMsg="The study #{entity.name} was successfully created."
              respBody = BRL::Genboree::REST::Data::StudyEntity.new(@connect, newStudy['name'], newStudy['type'], newStudy['lab'], newStudy['contributors'], newStudy['state'], avpHash)
              respBody.setStatus(@statusName, @statusMsg)
              respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study/#{Rack::Utils.escape(newStudy['name'])}"))
              configResponse(respBody, @statusName)
              newStudyRows.clear() unless(newStudyRows.nil?)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create study #{entity.name.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a study of a different name")
          end
        elsif(initStatus == :'OK' and entity)
          # Study exists; update it.
          studyRows = @dbu.selectStudyByName(@studyName)
          studyRow = studyRows.first
          studyId = studyRow['id']
          rowsUpdated = @dbu.updateStudyById(studyId, entity.name, entity.type, entity.lab, entity.contributors, entity.state)

          # If the only value being updated is the study name and it is identical
          # to the old study name, rowsUpdated returns 0.  Handling that case
          # here instead of in dbUtil to avoid making a mess of the 
          # updateStudyById method. 
          rowsUpdated = 1 if(entity.name == @studyName and rowsUpdated == 0)

          if(rowsUpdated == 1)
            # Always update AVPs (whether "moved" or not)
            updateAvpHash(@dbu, studyId, entity.avpHash)
            studyObj = nil

            # Check if we are "moved" or just updated
            if(entity.name == @studyName)
              changedStudyRows = @dbu.selectStudyByName(entity.name)
              changedStudy = changedStudyRows.first
              studyObj = BRL::Genboree::REST::Data::StudyEntity.new(@connect, changedStudy['name'], changedStudy['type'], changedStudy['lab'], changedStudy['contributors'], changedStudy['state'] )
              studyObj.setStatus(@statusName, "The study #{entity.name} has been updated." )
              changedStudyRows.clear() unless (changedStudyRows.nil?)
            else
              renamedStudyRows = @dbu.selectStudyByName(entity.name)
              renamedStudy = renamedStudyRows.first
              @statusName = :'Moved Permanently'
              studyObj = BRL::Genboree::REST::Data::StudyEntity.new(@connect, renamedStudy['name'], renamedStudy['type'], renamedStudy['lab'], renamedStudy['contributors'], renamedStudy['state'] )
              studyObj.setStatus(@statusName, "The study #{@studyName.inspect} has been renamed to #{entity.name.inspect}.")
              renamedStudyRows.clear() unless (renamedStudyRows.nil?)
            end

            # Respond with the updates
            studyObj.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study/#{Rack::Utils.escape(studyObj.name)}"))
            configResponse(studyObj, @statusName)
          end  
          studyRows.clear() unless(studyRows.nil?)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update study #{@studyName.inspect} in the database #{@dbName.inspect}")
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
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete studies in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the study to be deleted
          studyRow = @dbu.selectStudyByName(@studyName)
          studyId = studyRow.first['id']
          avpDeletion = @dbu.deleteStudy2AttributesByStudyIdAndAttrNameId(studyId)
          deletedRows = @dbu.deleteStudyById(studyId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The study #{@studyName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the study #{@studyName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Study
end ; end ; end # module BRL ; module REST ; module Resources
