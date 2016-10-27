#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/rest/data/analysisEntity'
require 'brl/genboree/abstract/resources/analysis.rb'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Analyses - exposes information about all of the analyses associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::AnalysisEntity
  # * BRL::Genboree::REST::Data::AnalysisEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  class Analyses < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Analysis

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/analyses"
   
    RESOURCE_DISPLAY_NAME = "Analyses" 
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
      # Look for /REST/v1/grp/{grp}/db/{db}/analyses$ URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/analyses$}
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
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/analysis")
          
          # Get a list of all layouts for this db/group
          analysisRows = @dbu.selectAllAnalyses()
          analysisRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::AnalysisEntityList.new(@connect)
            analysisRows.each { |row|
              entity = fetchAnalysis(row['name'])
              bodyData << entity
            }
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            analysisRows.each { |row|
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          analysisRows.clear() unless (analysisRows.nil?)
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
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      initStatus = initOperation()
      initStatus = initGroupAndDatabase() if(initStatus == :OK)
      if(initStatus == :OK)
        # Check permission for inserts (must be author/admin of a group)
        if(@groupAccessStr == 'r')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a analysis in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('AnalysisEntity')
          if(entity.nil?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be type :AnalysisEntity")
          elsif(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type :AnalysisEntity")
          elsif(entity.name.nil? or entity.name.empty?)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: The entity supplied did not have a valid name.")
          else
            # Make sure there are no name conflicts first
            analysisRows = @dbu.selectAnalysisByName(entity.name)
            if(analysisRows != nil and analysisRows.length > 0)
              @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a analysis in the database #{@dbName.inspect} called #{entity.name.inspect}")
            else
              # Deal with experiment (insert empty, or use existing)
              experimentId = nil
              experimentRows = @dbu.selectExperimentByName(entity.experiment)
              if(experimentRows and experimentRows.first)
                experimentId = experimentRows.first['id'] 
              elsif(!entity.experiment.nil? and !entity.experiment.empty?)
                # Create a default (empty) experiment
                rowsInserted = @dbu.insertExperiment(entity.experiment, "")
                insertedExperimentRows = @dbu.selectExperimentByName(entity.experiment) if(rowsInserted == 1)
                experimentId = insertedExperimentRows.first['id'] if(insertedExperimentRows and insertedExperimentRows.first)
                # TODO - Error out if insert failed?
              end
              experimentRows.clear() unless(experimentRows.nil?)

              # Insert the analysis
              rowsInserted = @dbu.insertAnalysis(entity.name, entity.type, entity.dataLevel, experimentId, entity.state)
              analysisId = @dbu.getLastInsertId(:userDB)
              if(rowsInserted == 1)
                # Update AVPs
                unless(entity.avpHash.nil? or entity.avpHash.empty?)
                  updateAvpHash(@dbu, analysisId, entity.avpHash)
                end

                # Get the newly created analysis to return
                analysis = fetchAnalysis(entity.name)
                @statusName=:'Created'
                @statusMsg="The analysis was successfully created."
                analysis.setStatus(@statusName, @statusMsg)
                configResponse(analysis, @statusName)
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
  end # class Analyses
end ; end ; end # module BRL ; module REST ; module Resources
