#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/experimentEntity'
require 'brl/genboree/abstract/resources/experiment'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Experiment - exposes information about single Experiment objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::ExperimentEntity
  class Experiment < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Experiment
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
      @dbName = @experimentName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/experiment/{experiment} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/experiment/([^/\?]+)$}
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
        @experimentName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectExperimentByName(@experimentName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_EXPERIMENT: The experiment #{@experimentName.inspect} was not found in the database #{@dbName.inspect}."
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
        # Get the experiment by name 
        experiment = fetchExperiment(@experimentName)
        if(experiment)
          @statusName = configResponse(experiment)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NO_EXPERIMENT: The experiment #{@experimentName.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
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
      initStatus = initOperation()   
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create experiments in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('ExperimentEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type ExperimentEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a experiment with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity != nil and entity.name != @experimentName and experimentExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a experiment in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a experiment with default values
          rowsInserted = @dbu.insertExperiment(@experimentName, "")
          if(rowsInserted == 1)
            @statusName=:'Created'
            @statusMsg="The experiment was successfully created."
            # Get the newly created experiment to return
            experiment = fetchExperiment(@experimentName)
            experiment.setStatus(@statusName, @statusMsg)
            configResponse(experiment, @statusName)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create experiment #{@experimentName.inspect} in the data base #{@dbName.inspect}")
          end
        elsif(initStatus == :'Not Found' and entity)
          if(entity.name == @experimentName)
            # Deal with study / bioSample first
            studyId = bioSampleId = nil
            studyRows = @dbu.selectStudyByName(entity.study)
            if(studyRows and studyRows.first)
              studyId = studyRows.first['id'] 
            elsif(!entity.study.nil? and !entity.study.empty?)
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
            elsif(!entity.bioSample.nil? and !entity.bioSample.empty?)
              # Create a default (empty) study
              rowsInserted = @dbu.insertBioSample(entity.bioSample, "", "", "", "")
              insertedBioSampleRows = @dbu.selectBioSampleByName(entity.bioSample) if(rowsInserted == 1)
              bioSampleId = insertedBioSampleRows.first['id'] if(insertedBioSampleRows and insertedBioSampleRows.first)
              # TODO - Error out if insert failed?
            end
            bioSampleRows.clear() unless(bioSampleRows.nil?)

            # Insert the experiment
            rowsInserted = @dbu.insertExperiment(entity.name, entity.type, studyId, bioSampleId, entity.state)
            if(rowsInserted == 1)
              # Update the AVPs
              experimentId = @dbu.getLastInsertId(:userDB)
              updateAvpHash(@dbu, experimentId, entity.avpHash)

              # Respond with the newly created entity
              @statusName=:'Created'
              @statusMsg="The experiment #{entity.name} was successfully created."
              experiment = fetchExperiment(entity.name)
              experiment.setStatus(@statusName, @statusMsg)
              configResponse(experiment, @statusName)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create experiment #{entity.name.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a experiment of a different name")
          end
        elsif(initStatus == :'OK' and entity)
          # Experiment exists; update it.
          experimentRows = @dbu.selectExperimentByName(@experimentName)
          experimentRow = experimentRows.first
          experimentId = experimentRow['id']

          # Now deal with study / bioSample
          studyId = bioSampleId = nil
          studyRows = @dbu.selectStudyByName(entity.study)
          if(studyRows and studyRows.first)
            studyId = studyRows.first['id'] 
          elsif(!entity.study.nil? and !entity.study.empty?)
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
          elsif(!entity.bioSample.nil? and !entity.bioSample.empty?)
            # Create a default (empty) study
            rowsInserted = @dbu.insertBioSample(entity.bioSample, "", "", "", "")
            insertedBioSampleRows = @dbu.selectBioSampleByName(entity.bioSample) if(rowsInserted == 1)
            bioSampleId = insertedBioSampleRows.first['id'] if(insertedBioSampleRows and insertedBioSampleRows.first)
            # TODO - Error out if insert failed?
          end
          bioSampleRows.clear() unless(bioSampleRows.nil?)
           
          rowsUpdated = @dbu.updateExperimentById(experimentId, entity.name, entity.type, studyId, bioSampleId, entity.state)

          # If the only value being updated is the experiment name and it is identical
          # to the old experiment name, rowsUpdated returns 0.  Handling that case
          # here instead of in dbUtil to avoid making a mess of the 
          # updateExperimentById method. 
          rowsUpdated = 1 if(entity.name == @experimentName and rowsUpdated == 0)

          if(rowsUpdated == 1)
            experimentObj = fetchExperiment(entity.name)

            # Always update AVPs (whether "moved" or not)
            updateAvpHash(@dbu, experimentId, entity.avpHash)

            # Check if we are "moved" or just updated
            if(entity.name == @experimentName)
              experimentObj.setStatus(@statusName, "The experiment #{entity.name.inspect} has been updated." )
            else
              @statusName = :'Moved Permanently'
              experimentObj.setStatus(@statusName, "The experiment #{@experimentName.inspect} has been renamed to #{entity.name.inspect}.")
            end

            # Respond with the updates
            configResponse(experimentObj, @statusName)
          end  
          experimentRows.clear() unless(experimentRows.nil?)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update experiment #{@experimentName.inspect} in the database #{@dbName.inspect}")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.  NOTE: You must be a group
    # administrator in order to have permission to delete experiments.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete experiments in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the experiment to be deleted
          experimentRow = @dbu.selectExperimentByName(@experimentName)
          experimentId = experimentRow.first['id']
          avpDeletion = @dbu.deleteExperiment2AttributesByExperimentIdAndAttrNameId(experimentId)
          deletedRows = @dbu.deleteExperimentById(experimentId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The experiment #{@experimentName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the experiment #{@experimentName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error
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
  end # class Experiment
end ; end ; end # module BRL ; module REST ; module Resources
