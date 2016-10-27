require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/gbToRmMapEntity'
require 'brl/genboree/rest/data/rawDataEntity'

module BRL; module REST; module Resources

  # Mapping between Genboree resources (within a group) to Redmine resources
  # @see GenboreeResource for description of interface methods and constants below
  class RedmineMaps < GenboreeResource
    # @interface
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # @interface
    RSRC_TYPE = "redmineMaps"
    FILTER_FIELDS = [:gbType, :gbRsrc, :rmType, :rmRsrc]

    # @todo strict mode for sql session?
    # allowed values for gbType field in SQL
    GB_TYPE_ENUM = ["group", "database", "file", "track", "kbCollection", "kbDoc", "kbDocProp", "kbQuestion", "kbTemplate"]
    # allowed values for rmType field in SQL
    RM_TYPE_ENUM = BRL::Genboree::REST::Data::GbToRmMapEntity::RM_URL_TYPES.keys
    # Genboree configuration file key whose value defines location defining information about
    #   configured Redmines for this host
    REDMINE_CONFIG = "gbRedmineConfs"
  
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/redmineMaps$}
    end
  
    def self.priority()
      return 3 # higher than group
    end
  
    # idiomatic method for access control
    # provides @groupId, @groupDesc, @groupAccessStr
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        initStatus = initGroup() 
      end
      return initStatus
    end
  
    # @interface
    def cleanup()
      super()
      @groupName = @groupId = @groupDesc = @groupAccessStr = nil
    end

    # Retrieve existing mapping(s)
    # @note mappings may be filtered by payload or by query string; query string may be
    #   thought of as a set of global options that are overriden by more specific payload arguments
    # @todo payload for all plural Genboree resources (including this one) may be be prohibitively large 
    #   -- we like to defer resolution of such issues until an associated problem arises
    def get()
      initStatus = initOperation()
      if(initStatus != :OK)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end

      # Retrieve database records based on payload and query string
      # If-else tree must set dbRecs or raise error
      dbRecs = nil
      reqEntity = parseRequestBodyForEntity(["GbToRmMapEntityList", "GbToRmMapEntity"])
      filtersOverriden = false
      filters = self.class.parseFilters(@nvPairs)
      if(reqEntity.nil?)
        # then payload is empty, use query string to define database query
        if(filters.empty?)
          dbRecs = @dbu.selectGbToRmMapsByGroup(@groupName)
        else
          dbRecs = @dbu.selectGbToRmMapsByGroupAndFilters(@groupName, filters)
        end
        if(dbRecs.nil?)
          raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "An error occurred while retrieving the redmineMaps from the database.")
        end
      elsif(reqEntity == :"Unsupported Media Type")
        # then payload is not correct for this resource
        raise BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", "Unsupported Media Type")
      else
        # then payload is parsed fine; use it to perform selective query
        # parse filters
        filtersOverride = nil
        if(reqEntity.is_a?(GbToRmMapEntityList))
          entities = reqEntity.array
          filtersOverride = self.overrideFilters(filters, entities)
        elsif(reqEntity.is_a?(GbToRmMapEntity))
          entities = [reqEntity]
          filtersOverride = self.overrideFilters(filters, entities)
        else
          # parseRequestBodyForEntity should have returned nil, :"Unsupported Media Type",
          #   or one of these entities
          raise "Interface for parseRequestBodyForEntity has changed"
        end

        # detect overriden filters (those in payload that are also present in query string)
        overridenFilters = []
        filters.each_key { |filter|
          if(filters[filter] != filtersOverride[filter])
            overridenFilters.push(filter)
          end
        }
        filtersOverriden = (!overridenFilters.empty?)
        if(filtersOverriden)
          # @todo then display warning message
        end

        # use filters to perform query
        filters = filtersOverride
        dbRecs = @dbu.selectGbToRmMapsByGroupAndFilters(@groupName, filters)
        if(dbRecs.nil?)
          raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "An error occurred while retrieving the redmineMaps from the database.")
        end
      end

      # With dbRecs set, prepare respEntity
      entities = dbRecs.map { |dbRec| 
        BRL::Genboree::REST::Data::GbToRmMapEntity.fromRecord(dbRec)
      }
      respEntity = BRL::Genboree::REST::Data::GbToRmMapEntityList.new(false, entities)
      respEntity.setStatus(@statusName, @statusMsg)
      configResponse(respEntity) # sets @resp

      return @resp
    end
    
    # Add new mappings
    # Respond with the number of records inserted
    def put()
      # check access
      initStatus = initOperation()
      if(initStatus != :OK)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end

      # @todo update
      update = (@nvPairs.key?("update"))
      if(update)
        # then update existing mappings (upsert)
        raise BRL::Genboree::GenboreeError.new(:"Not Implemented", "Not Implemented")
      end

      # parse entities
      reqEntity = parseRequestBodyForEntity(["GbToRmMapEntityList", "GbToRmMapEntity"])
      entities = nil # Array<BRL::Genboree::REST::Data::gbToRmMapEntity>
      if(reqEntity.nil?)
        # then no payload -- bad request
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Please provide a payload with the Redmine maps to save")
      elsif(reqEntity == :"Unsupported Media Type")
        # then cannot parse payload
        # @todo message
        raise BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", "Unsupported Media Type")
      elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::GbToRmMapEntity))
        entities = [reqEntity]
      elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::GbToRmMapEntityList))
        entities = reqEntity.array
      else
        raise "Interface for parseRequestBodyForEntity has changed"
      end

      # infer types that are missing (gbRsrc and rmRsrc are required)
      entities.each { |entity|
        if(entity.gbType.nil? or entity.gbType.empty?)
          gbType = BRL::Genboree::REST::Data::GbToRmMapEntity.classifyGbRsrc(entity.gbRsrc)
          if(gbType.nil?)
            $stderr.debugPuts(__FILE__, __method__, "WARNING", "Unable to infer allowed resource type for #{entity.gbRsrc.inspect}")
          else
            entity.gbType = gbType
          end
        end

        if(entity.rmType.nil? or entity.rmType.empty?)
          rmType = BRL::Genboree::REST::Data::GbToRmMapEntity.classifyRmRsrc(entity.rmRsrc)
          if(rmType.nil?)
            $stderr.debugPuts(__FILE__, __method__, "WARNING", "Unable to infer allowed resource type for #{entity.rmRsrc.inspect}")
          else
            entity.rmType = rmType
          end
        end
      }

      # validate types
      badEntityIndexes = self.class.validateEntitiesTypes(entities)
      unless(badEntityIndexes.empty?)
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The mappings at position(s) #{badEntityIndexes.map{|ii| ii+1}.join(", ")} in your payload have invalid values for either the gbType field or the rmType field. Allowed gbType values include #{GB_TYPE_ENUM.join(", ")}. Allowed rmType values include #{RM_TYPE_ENUM.join(", ")}")
      end

      # validate entity rsrc urls
      redmineConfs = self.class.getRedmineConfs(@genbConf)
      badEntityIndexes = self.class.validateEntitiesRsrcs(entities, @req, redmineConfs)
      unless(badEntityIndexes.empty?)
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The mappings at position(s) #{badEntityIndexes.map{|ii| ii+1}.join(", ")} in your payload have invalid values for either the gbRsrc field or the rmRsrc field. Please verify that gbRsrc URLs have the same host as this Genboree server that you are submitting mappings to, and that rmRsrc URLs have have host and path information that is consistent with Redmine instances registered with this Genboree server.")
      end

      # prepare entities for insertion
      records = entities.map { |entity| BRL::Genboree::REST::Data::GbToRmMapEntity.toRecord(@groupName, entity) }

      # then add new mappings (insert)
      # @todo if enum field doesnt match it gets inserted as "" and this doesnt error but it should (strict mode)
      nInserted = @dbu.insertGbToRmMaps(records)
      if(nInserted.nil?)
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Final storage of Redmine mappings failed.")
      end

      # prepare response
      rawDataObj = { :nInserted => nInserted }
      respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, rawDataObj)
      respEntity.setStatus(@statusName, @statusMsg)
      configResponse(respEntity) # sets @resp

      return @resp
    end
  
    # Delete an existing mapping
    def delete()
      # check access
      initStatus = initOperation()
      if(initStatus != :OK)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end

      # parse entities
      reqEntity = parseRequestBodyForEntity(["GbToRmMapEntityList", "GbToRmMapEntity"])
      entities = nil
      if(reqEntity.nil?)
        # then no payload -- delete all mappings
        entities = nil
      elsif(reqEntity == :"Unsupported Media Type")
        # then cannot parse payload
        # @todo message
        raise BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", "Unsupported Media Type")
      elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::GbToRmMapEntity))
        entities = [reqEntity]
      elsif(reqEntity.is_a?(BRL::Genboree::REST::Data::GbToRmMapEntityList))
        entities = reqEntity.array
      else
        raise "Interface for parseRequestBodyForEntity has changed"
      end

      nDeleted = nil
      if(entities.nil?)
        # then no specific entities to delete from payload, delete all
        nDeleted = @dbu.deleteGbToRmMapsByGroup(@groupName)
      else
        # compose records for delete query
        records = entities.map { |entity| BRL::Genboree::REST::Data::GbToRmMapEntity.toRecord(@groupName, entity) }
  
        # then perform deletion
        nDeleted = @dbu.deleteGbToRmMaps(records)
      end
      if(nDeleted.nil?)
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Final deletion of Redmine mappings failed.")
      end

      # prepare response
      rawDataObj = { :nDeleted => nDeleted }
      respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, rawDataObj)
      respEntity.setStatus(@statusName, @statusMsg)
      configResponse(respEntity) # sets @resp

      return @resp
    end

    # Extract database filters from the query string
    # @return [Hash] only filters present in query string, subset of FILTER_FIELDS
    def self.parseFilters(nvPairs)
      # gbType, gbRsrc, rmType, rmRsrc
      filters = {}
      FILTER_FIELDS.map { |filter| filter.to_s }.each { |filter|
        filters[filter] = nvPairs[filter] if(nvPairs.key?(filter))
      }
      return filters
    end

    # Return a modified copy of filters with payload-provided overrides to query string filters
    # @param [Hash<String, String>] filters @see parseFilters
    # @param [Array<BRL::Genboree::REST::Data::GbToRmMapEntity>] gbToRmMapEntities data from payload
    #   which may override global filters
    # @todo for a payload with two entities, one with a filter on gbType and one without, this
    #   will override the global query string filter on gbType. we may want to change this. this is
    #   done here because there is only one sql query being performed. changing would require multiple
    #   queries (but could also be performed in a single complex, structured query with some thought)
    def self.overrideFilters(filters, gbToRmMapEntities)
      filters = filters.dup()
      entityFilters = Hash.new { |hh, kk| hh[kk] = [] }
      gbToRmMapEntities.each { |gbToRmMapEntity|
        FILTER_FIELDS.each { |filterField|
          filterValue = gbToRmMapEntity.send(filterField)
          if(!filterValue.nil? and !filterValue.empty?)
            entityFilters[filterField].push(filterValue)
          end
        }
      }
      FILTER_FIELDS.each { |filterField|
        filters[filterField] = entityFilters[filterField] if(entityFilters.key?(filterField))
      }
      return filters
    end

    # Require that payload entities uploaded have values that will be accepted by SQL enum
    # @param [Array<BRL::Genboree::REST::Data::GbToRmMapEntity>] entities parsed from payload
    # @return [Array<Integer>] entity indexes that have offending enum values
    def self.validateEntitiesTypes(entities)
      rv = []
      entities.each_index { |ii|
        entity = entities[ii]
        unless(rsrcTypesValid?(entity))
          rv << ii
        end
      }
      return rv
    end

    # Validate rsrc urls of entities
    # @param [Array<BRL::Genboree::REST::Data::GbToRmMapEntity>] entities to validate from this put request
    # @param [Rack::Request] req Rack::Request for this put request
    # @param [Hash] redmineConfs @see getRedmineConfs
    # @return [Array<Integer>] indexes of invalid entities
    def self.validateEntitiesRsrcs(entities, req, redmineConfs)
      rv = []
      entities.each_index { |ii|
        entity = entities[ii]
        valid = (genboreeHostValid?(req, entity) and redmineHostValid?(redmineConfs, entity))
        unless(valid)
          rv << ii
        end
      }
      return rv
    end

    # Validate the gbType and rmType fields against the enums
    # @param [BRL::Genboree::REST::Data::GbToRmMapEntity]
    # @return [Boolean] true if types are valid
    def self.rsrcTypesValid?(entity)
      rv = false
      gbValid = (GB_TYPE_ENUM.include?(entity.gbType))
      rmValid = (RM_TYPE_ENUM.include?(entity.rmType))
      rv = (gbValid and rmValid)
    end

    # Validate the host of the entity's gbRsrc: must be the same as the server processing the request
    # @param [Rack::Request] req the request currently being processed
    # @param [BRL::Genboree::REST::Data::GbToRmMapEntity] entity a mapping entity in this request's payload
    # @return [Boolean] true if the canonical addresses match
    # @see [BRL::Cache::Helpers::DNSCacheHelper#canonicalAddress]
    def self.genboreeHostValid?(req, entity)
      entityHost = URI.parse(entity.gbRsrc).host rescue nil
      thisHost = req.host
      canonicalAddressesMatch?(entityHost, thisHost)
    end

    # Validate the host of the entity's rmRsrc: its host and path must belong to one of the 
    #   registered Redmines for this host
    # @param [Hash] @see getRedmineConfs
    # @param [BRL::Genboree::REST::Data::GbToRmMapEntity] entity
    # @return [Booelan] true if the canonical addresses of the entity and one of the registered Redmines
    #   match AND the path of that registered redmine is included in the path of the rmRsrc
    def self.redmineHostValid?(redmineConfs, entity)
      rv = false
      uriObj = URI.parse(entity.rmRsrc)
      entityHost = uriObj.host rescue nil

      hostMatch = false
      pathIncluded = false
      redmineConfs.each_key { |redmineName|
        redmineConf = redmineConfs[redmineName]
        hostMatch = canonicalAddressesMatch?(entityHost, redmineConf["host"])
        if(hostMatch)
          if(uriObj.path.index("#{redmineConf["path"]}/") == 0)
            pathIncluded = true
          else
            # since this host path doesnt match, this host is no longer eligible
            hostMatch = false
          end
        end
        rv = (hostMatch and pathIncluded)
        break if(rv)
      }

      return rv
    end

    # Get configured Redmine instances for this host
    # @param [BRL::Genboree::GenboreeConfig] genbConf loaded Genboree config
    # @return [Hash<String, Hash>] map of Redmine instance name to Hash object with keys "host" and "path"
    def self.getRedmineConfs(genbConf)
      rv = nil
      confValue = genbConf.send(REDMINE_CONFIG.to_sym)
      if(confValue.nil?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Missing configuration #{REDMINE_CONFIG.inspect}")
      else
        if(File.exists?(confValue))
          File.open(confValue) { |fh|
            rv = JSON.parse(fh.read) rescue nil
          }
          if(rv.nil?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Bad configuration file #{confValue.inspect}: cannot parse as JSON")
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Bad configuration value for #{REDMINE_CONFIG.inspect}: file does not exist")
        end
      end
      return rv
    end

  end
end; end; end
