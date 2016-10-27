#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/rest/data/studyEntity'
require 'brl/genboree/abstract/resources/study.rb'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Studies - exposes information about all of the studies associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::StudyEntity
  # * BRL::Genboree::REST::Data::StudyEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  class Studies < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Study

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/studies"

    RESOURCE_DISPLAY_NAME = "Studies"
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @dbName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/studies$ URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/studies$}
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
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study")
          
          # Get a list of all layouts for this db/group
          studyRows = @dbu.selectAllStudies()
          studyRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::StudyEntityList.new(@connect)
            studyRows.each { |row|
              entity = BRL::Genboree::REST::Data::StudyEntity.new(@connect, row['name'], row['type'], row['lab'], row['contributors'], row['state'], getAvpHash(@dbu, row['id']))
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            studyRows.each { |row|
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          studyRows.clear() unless (studyRows.nil?)
        end
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
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      if(initStatus == :OK)
        # Check permission for inserts (must be author/admin of a group)
        if(@groupAccessStr == 'r')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a study in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('StudyEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a StudyEntity")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type StudyEntity")
          elsif(entity.name.nil? or entity.name.empty?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: The entity supplied did not have a valid name.")
          else
            # Make sure there are no name conflicts first
            studyRows = @dbu.selectStudyByName(entity.name)
            if(studyRows != nil and studyRows.length > 0)
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a study in the database #{@dbName.inspect} called #{entity.name.inspect}")
            else
              # Insert the study
              rowsInserted = @dbu.insertStudy(entity.name, entity.type, entity.lab, entity.contributors, entity.state)
              studyId = @dbu.getLastInsertId(:userDB)
              if(rowsInserted == 1)
                unless(entity.avpHash.nil? or entity.avpHash.empty?)
                  updateAvpHash(@dbu, studyId, entity.avpHash)
                end
                # Get the newly created study to return
                newStudyRow = @dbu.selectStudyByName(entity.name)
                newStudyRow = newStudyRow.first

                @statusName=:'Created'
                @statusMsg="The study was successfully created."
                newStudy = BRL::Genboree::REST::Data::StudyEntity.new(@connect, newStudyRow['name'], newStudyRow['type'], newStudyRow['lab'], newStudyRow['contributors'], newStudyRow['state'] )
                newStudy.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/study/#{Rack::Utils.escape(newStudy.name)}"))
                newStudy.setStatus(@statusName, @statusMsg)
                configResponse(newStudy, @statusName)
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create layout #{entity.name.inspect} in the database #{@dbName.inspect}")
              end
            end
          end
        end
      end

      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Studies
end ; end ; end # module BRL ; module REST ; module Resources
