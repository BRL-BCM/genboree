#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/runEntity'
require 'brl/genboree/abstract/resources/run'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Run - exposes information about single Run objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::RunEntity
  class Run < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::Run
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
      @dbName = @runName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/run/{run} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/run/([^/\?]+)$}
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
        @runName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectRunByName(@runName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_EXPERIMENT: The run #{@runName} was not found in the database #{@dbName}."
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
        # Get the run by name 
        run = fetchRun(@runName)
        if(run)
          @statusName = configResponse(run)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NO_EXPERIMENT: The run #{@runName} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a RunEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()   
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create runs in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('RunEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type RunEntity")
        elsif(entity.nil? and initStatus == :'OK')
          # Cannot update a run with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
        elsif(entity != nil and entity.name != @runName and runExists(@dbu, entity.name))
          # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
          @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a run in the database #{@dbName.inspect} called #{entity.name.inspect}")
        elsif(entity.nil? and initStatus == :'Not Found')
          # Insert a run with default values
          time = Time.now
          $stderr.puts "Creating time in resource: #{time.inspect}"
          rowsInserted = @dbu.insertRun(@runName, "",time,"","")
          if(rowsInserted == 1)
            $stderr.puts "Rows inserted block entered."
            @statusName=:'Created'
            @statusMsg="The run was successfully created."
            # Get the newly created run to return
            run = fetchRun(@runName)
            run.setStatus(@statusName, @statusMsg)
            configResponse(run, @statusName)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create run #{@runName.inspect} in the data base #{@dbName.inspect}")
          end
        elsif(initStatus == :'Not Found' and entity)
          if(entity.name == @runName)
            # Deal with experiment first
            experimentId = nil
            experimentRows = @dbu.selectExperimentByName(entity.experiment)
            if(experimentRows and experimentRows.first)
              experimentId = experimentRows.first['id'] 
            elsif(!entity.experiment.empty?)
              # Create a default (empty) experiment
              rowsInserted = @dbu.insertExperiment(entity.experiment, "")
              $stderr.puts "rows inserted: #{rowsInserted}"
              insertedExperimentRows = @dbu.selectExperimentByName(entity.experiment) if(rowsInserted == 1)
              experimentId = insertedExperimentRows.first['id'] if(insertedExperimentRows and insertedExperimentRows.first)
              # TODO - Error out if insert failed?
            end
            experimentRows.clear() unless(experimentRows.nil?)
            # Insert the run
            rowsInserted = @dbu.insertRun(entity.name, entity.type, entity.time, entity.performer, entity.location, experimentId, entity.state)
            if(rowsInserted == 1)
              # Update the AVPs
              runId = @dbu.getLastInsertId(:userDB)
              updateAvpHash(@dbu, runId, entity.avpHash)

              # Respond with the newly created entity
              @statusName=:'Created'
              @statusMsg="The run #{entity.name} was successfully created."
              run = fetchRun(entity.name)
              run.setStatus(@statusName, @statusMsg)
              configResponse(run, @statusName)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create run #{entity.name.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a run of a different name")
          end
        elsif(initStatus == :'OK' and entity)
          # Run exists; update it.
          runRows = @dbu.selectRunByName(@runName)
          runRow = runRows.first
          runId = runRow['id']
          
          # Deal with experiment first
          experimentId = nil
          experimentRows = @dbu.selectExperimentByName(entity.experiment)
          if(experimentRows and experimentRows.first)
            experimentId = experimentRows.first['id'] 
          elsif(!entity.experiment.nil?)
            # Create a default (empty) experiment
            rowsInserted = @dbu.insertExperiment(entity.experiment, "")
            insertedExperimentRows = @dbu.selectExperimentByName(entity.experiment) if(rowsInserted == 1)
            experimentId = insertedExperimentRows.first['id'] if(insertedExperimentRows and insertedExperimentRows.first)
            # TODO - Error out if insert failed?
          end
          experimentRows.clear() unless(experimentRows.nil?)
          
          rowsUpdated = @dbu.updateRunById(runId, entity.name, entity.type, entity.time, entity.performer, entity.location, experimentId, entity.state)
          # If the only value being updated is the run name and it is identical
          # to the old run name, rowsUpdated returns 0.  Handling that case
          # here instead of in dbUtil to avoid making a mess of the 
          # updateRunById method. 
          rowsUpdated = 1 if(entity.name == @runName and rowsUpdated == 0)

          if(rowsUpdated == 1)
            runObj = fetchRun(entity.name)

            # Always update AVPs (whether "moved" or not)
            updateAvpHash(@dbu, runId, entity.avpHash)

            # Check if we are "moved" or just updated
            if(entity.name == @runName)
              runObj.setStatus(@statusName, "The run #{entity.name.inspect} has been updated." )
            else
              @statusName = :'Moved Permanently'
              runObj.setStatus(@statusName, "The run #{@runName.inspect} has been renamed to #{entity.name.inspect}.")
            end

            # Respond with the updates
            configResponse(runObj, @statusName)
          end  
          runRows.clear() unless(runRows.nil?)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update run #{@runName.inspect} in the database #{@dbName.inspect}")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.  NOTE: You must be a group
    # administrator in order to have permission to delete runs.
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete runs in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          # Find the run to be deleted
          runRow = @dbu.selectRunByName(@runName)
          runId = runRow.first['id']
          avpDeletion = @dbu.deleteRun2AttributesByRunIdAndAttrNameId(runId)
          deletedRows = @dbu.deleteRunById(runId)
          if(deletedRows == 1)
            entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
            entity.setStatus(:OK, "The run #{@runName.inspect} was successfully deleted from the database #{@dbName.inspect}")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the run #{@runName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        end
      end

      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Helper method to create an RunEntity from the DB.
    # [+name+] Name of the run.
    # [+returns+] An +RunEntity+ or +nil+ if not found.
    def fetchRun(name)
      entity = nil

      runRows = @dbu.selectRunByName(name)
      unless(runRows.nil? or runRows.empty?)
        runRow = runRows.first
        avpHash = getAvpHash(@dbu, runRow['id'])
        entity = BRL::Genboree::REST::Data::RunEntity.new(@connect, runRow['name'], runRow['type'], runRow['time'], runRow['performer'], runRow['location'], runRow['experiment_id'], runRow['state'], avpHash)

        # Now query for experiment and bioSample
        experimentRow = @dbu.selectExperimentById(runRow['experiment_id']) unless(runRow['experiment_id'].nil?)
        entity.experiment = experimentRow.first['name'] if(experimentRow and experimentRow.first)

        # Build refs
        entity.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/run/#{Rack::Utils.escape(entity.name)}"))
      end
      runRows.clear() unless(runRows.nil?)

      # Return the entity
      return entity
    end

  end # class Run
end ; end ; end # module BRL ; module REST ; module Resources
