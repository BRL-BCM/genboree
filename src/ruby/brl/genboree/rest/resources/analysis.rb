#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/analysisEntity'
require 'brl/genboree/abstract/resources/analysis'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Analysis - exposes information about single Analysis objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::AnalysisEntity
  class Analysis < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Analysis
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
      @dbName = @analysisName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/analysis/{analysis} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/analysis/([^/\?]+)$}
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
        @analysisName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectAnalysisByName(@analysisName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_ANALYSIS: The analysis #{@analysisName.inspect} was not found in the database #{@dbName.inspect}."
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
        # Get the analysis by name 
        analysis = fetchAnalysis(@analysisName)
        if(analysis)
          @statusName = configResponse(analysis)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NO_ANALYSIS: The analysis #{@analysisName.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a AnalysisEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()   
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create analyses in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('AnalysisEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type AnalysisEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a analysis with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity != nil and entity.name != @analysisName and analysisExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a analysis in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a analysis with default values
          rowsInserted = @dbu.insertAnalysis(@analysisName, "", "")
          if(rowsInserted == 1)
            @statusName=:'Created'
            @statusMsg="The analysis was successfully created."
            # Get the newly created analysis to return
            analysis = fetchAnalysis(@analysisName)
            analysis.setStatus(@statusName, @statusMsg)
            configResponse(analysis, @statusName)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create analysis #{@analysisName.inspect} in the data base #{@dbName.inspect}")
          end
        elsif(initStatus == :'Not Found' and entity)
          if(entity.name == @analysisName)
            # Deal with experiment first
            experimentId = bioSampleId = nil
            experimentRows = @dbu.selectExperimentByName(entity.experiment)
            if(experimentRows and experimentRows.first)
              experimentId = experimentRows.first['id'] 
            elsif(!entity.experiment.nil? and !entity.experiment.empty?)
              # Create a default (empty) experiment
              rowsInserted = @dbu.insertExperiment(entity.experiment, "")
              insertedExperimentRows = @dbu.selectExperimentByName(entity.experiment) if(rowsInserted == 1)
              experiementId = insertedStudyRows.first['id'] if(insertedexperimentRows and insertedexperimentRows.first)
              # TODO - Error out if insert failed?
            end
            experimentRows.clear() unless(experimentRows.nil?)

            # Insert the analysis
            rowsInserted = @dbu.insertAnalysis(entity.name, entity.type, dataLevel, experimentId, entity.state)
            if(rowsInserted == 1)
              # Update the AVPs
              analysisId = @dbu.getLastInsertId(:userDB)
              updateAvpHash(@dbu, analysisId, entity.avpHash)

              # Respond with the newly created entity
              @statusName=:'Created'
              @statusMsg="The analysis #{entity.name} was successfully created."
              analysis = fetchAnalysis(entity.name)
              analysis.setStatus(@statusName, @statusMsg)
              configResponse(analysis, @statusName)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create analysis #{entity.name.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a analysis of a different name")
          end
        elsif(initStatus == :'OK' and entity)
          # Analysis exists; update it.
          analysisRows = @dbu.selectAnalysisByName(@analysisName)
          analysisRow = analysisRows.first
          analysisId = analysisRow['id']

          # Now deal with experiment
          experimentId = nil
          experimentRows = @dbu.selectExperimentByName(entity.experiment)
          if(experimentRows and experimentRows.first)
            experimentId = experimentRows.first['id'] 
          elsif(!entity.experiment.nil? and !entity.experiment.empty?)
            # Create a default (empty) experiment
            rowsInserted = @dbu.insertExperiment(entity.experiment, "")
            insertedStudyRows = @dbu.selectExperimentByName(entity.experiment) if(rowsInserted == 1)
            experimentId = insertedExperimentRows.first['id'] if(insertedExperimentRows and insertedExperimentRows.first)
            # TODO - Error out if insert failed?
          end
          experimentRows.clear() unless(experimentRows.nil?)
          rowsUpdated = @dbu.updateAnalysisById(analysisId, entity.name, entity.type, entity.dataLevel, experimentId, entity.state)

          # If the only value being updated is the analysis name and it is identical
          # to the old analysis name, rowsUpdated returns 0.  Handling that case
          # here instead of in dbUtil to avoid making a mess of the 
          # updateAnalysisById method. 
          rowsUpdated = 1 if(entity.name == @analysisName and rowsUpdated == 0)

          if(rowsUpdated == 1)
            analysisObj = fetchAnalysis(entity.name)

            # Always update AVPs (whether "moved" or not)
            updateAvpHash(@dbu, analysisId, entity.avpHash)

            # Check if we are "moved" or just updated
            if(entity.name == @analysisName)
              analysisObj.setStatus(@statusName, "The analysis #{entity.name.inspect} has been updated." )
            else
              @statusName = :'Moved Permanently'
              analysisObj.setStatus(@statusName, "The analysis #{@analysisName.inspect} has been renamed to #{entity.name.inspect}.")
            end

            # Respond with the updates
            configResponse(analysisObj, @statusName)
          end  
          analysisRows.clear() unless(analysisRows.nil?)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update analysis #{@analysisName.inspect} in the database #{@dbName.inspect}")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.  NOTE: You must be a group
    # administrator in order to have permission to delete analyses.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete analyses in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the analysis to be deleted
          analysisRow = @dbu.selectAnalysisByName(@analysisName)
          analysisId = analysisRow.first['id']
          avpDeletion = @dbu.deleteAnalysis2AttributesByAnalysisIdAndAttrNameId(analysisId)
          deletedRows = @dbu.deleteAnalysisById(analysisId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The analysis #{@analysisName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the analysis #{@analysisName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Helper method to create an AnalysisEntity from the DB.
    # [+name+] Name of the analysis.
    # [+returns+] An +AnalysisEntity+ or +nil+ if not found.
    def fetchAnalysis(name)
      entity = nil

      analysisRows = @dbu.selectAnalysisByName(name)
      unless(analysisRows.nil? or analysisRows.empty?)
        analysisRow = analysisRows.first
        avpHash = getAvpHash(@dbu, analysisRow['id'])
        entity = BRL::Genboree::REST::Data::AnalysisEntity.new(@connect, analysisRow['name'], analysisRow['type'], analysisRow['dataLevel'], "", analysisRow['state'], avpHash)

        # Now query for experiment
        experimentRow = @dbu.selectExperimentById(analysisRow['experiment_id']) unless(analysisRow['experiment_id'].nil?)
        entity.experiment = experimentRow.first['name'] if(experimentRow and experimentRow.first)
        experimentRow.clear() unless(experimentRow.nil?)

        # Build refs
        entity.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/analysis/#{Rack::Utils.escape(entity.name)}"))
      end
      analysisRows.clear() unless(analysisRows.nil?)

      # Return the entity
      return entity
    end
  end # class Analysis
end ; end ; end # module BRL ; module REST ; module Resources
