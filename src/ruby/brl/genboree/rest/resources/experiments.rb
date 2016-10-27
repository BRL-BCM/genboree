#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/rest/data/experimentEntity'
require 'brl/genboree/abstract/resources/experiment.rb'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Experiments - exposes information about all of the experiments associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ExperimentEntity
  # * BRL::Genboree::REST::Data::ExperimentEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  class Experiments < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Experiment

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/experiments"

    RESOURCE_DISPLAY_NAME = "Experiments"
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
      # Look for /REST/v1/grp/{grp}/db/{db}/experiments$ URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/experiments$}
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
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/experiment")
          
          # Get a list of all layouts for this db/group
          experimentRows = @dbu.selectAllExperiments()
          experimentRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::ExperimentEntityList.new(@connect)
            experimentRows.each { |row|
              entity = fetchExperiment(row['name'])
              bodyData << entity
            }
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            experimentRows.each { |row|
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          experimentRows.clear() unless (experimentRows.nil?)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a ExperimentEntity or it will be rejected as a
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
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a experiment in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('ExperimentEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be type :ExperimentEntity")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type :ExperimentEntity")
          elsif(entity.name.nil? or entity.name.empty?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: The entity supplied did not have a valid name.")
          else
            # Make sure there are no name conflicts first
            experimentRows = @dbu.selectExperimentByName(entity.name)
            if(experimentRows != nil and experimentRows.length > 0)
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a experiment in the database #{@dbName.inspect} called #{entity.name.inspect}")
            else
              # Deal with study / bioSample first
              studyId = bioSampleId = nil
              studyRows = @dbu.selectStudyByName(entity.study)
              if(studyRows and studyRows.first)
                studyId = studyRows.first['id'] 
              elsif(!entity.study.empty?)
                # Create a default (empty) study
                rowsInserted = @dbu.insertStudy(entity.study, "", "", "")
                insertedStudyRows = @dbu.selectStudyByName(entity.study) if(rowsInserted == 1)
                studyId = insertedStudyRows.first['id'] if(insertedStudyRows and insertedStudyRows.first)
                # TODO - Error out if insert failed?
              end
              studyRows.clear() unless(studyRows.nil?)
              bioSampleRows = @dbu.selectBioSampleByName(entity.bioSample)
              if(bioSampleRows and bioSampleRows.first)
                bioSampleId = bioSampleRows.first['id'] 
              elsif(!entity.bioSample.empty?)
                # Create a default (empty) study
                rowsInserted = @dbu.insertBioSample(entity.bioSample, "", "", "", "")
                insertedBioSampleRows = @dbu.selectBioSampleByName(entity.bioSample) if(rowsInserted == 1)
                bioSampleId = insertedBioSampleRows.first['id'] if(insertedBioSampleRows and insertedBioSampleRows.first)
                # TODO - Error out if insert failed?
              end
              bioSampleRows.clear() unless(bioSampleRows.nil?)

              # Insert the experiment
              rowsInserted = @dbu.insertExperiment(entity.name, entity.type, studyId, bioSampleId, entity.state)
              experimentId = @dbu.getLastInsertId(:userDB)
              if(rowsInserted == 1)
                # Update AVPs
                unless(entity.avpHash.nil? or entity.avpHash.empty?)
                  updateAvpHash(@dbu, experimentId, entity.avpHash)
                end

                # Get the newly created experiment to return
                experiment = fetchExperiment(entity.name)
                @statusName=:'Created'
                @statusMsg="The experiment was successfully created."
                experiment.setStatus(@statusName, @statusMsg)
                configResponse(experiment, @statusName)
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

    # Helper method to create an ExperimentEntity from the DB.
    # [+name+] Name of the experiment.
    # [+returns+] An +ExperimentEntity+ or +nil+ if not found.
    def fetchExperiment(name)
      entity = nil

      experimentRows = @dbu.selectExperimentByName(name)
      unless(experimentRows.nil? or experimentRows.empty?)
        experimentRow = experimentRows.first
        avpHash = getAvpHash(@dbu, experimentRow['id'])
        entity = BRL::Genboree::REST::Data::ExperimentEntity.new(@connect, experimentRow['name'], experimentRow['type'], "", "", experimentRow['state'], avpHash)

        # Now query for study and bioSample
        studyRow = @dbu.selectStudyById(experimentRow['study_id']) unless(experimentRow['study_id'].nil?)
        entity.study = studyRow.first['name'] if(studyRow and studyRow.first)
        bioSampleRow = @dbu.selectBioSampleById(experimentRow['bioSample_id']) unless(experimentRow['bioSample_id'].nil?)
        entity.bioSample = bioSampleRow.first['name'] if(bioSampleRow and bioSampleRow.first)

        # Build refs
        entity.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/experiment/#{Rack::Utils.escape(entity.name)}"))
      end
      experimentRows.clear() unless(experimentRows.nil?)

      # Return the entity
      return entity
    end
  end # class Experiments
end ; end ; end # module BRL ; module REST ; module Resources
