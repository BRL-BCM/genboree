#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/bioSampleEntity'
require 'brl/genboree/abstract/resources/bioSampleSet'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSampleSet - exposes information about single BioSampleSet objects associated with a
  #   group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::BioSampleEntity
  class BioSampleSet < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSampleSet
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    # Labels, etc, for building more generic strings that are copy-paste-bug free
    RSRC_STRS = { :type => 'sampleSet', :label => 'sample set', :capital => 'Sample Set', :pluralType => 'sampleSets', :pluralLabel => 'sample sets', :pluralCap => 'Sample Sets' }
    # Standard (mainly table-column) attrs
    STD_ATTRS = { 'name' => true, 'state' => true }
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @dbName = @bioSampleSetName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/bioSampleSet/{bioSampleSet} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:bioS|s)ampleSet/([^/\?]+)(?:/([^/\?]+))?$} # /sampleSet/{name}/[aspect]
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
        @bioSampleSetName = Rack::Utils.unescape(@uriMatchData[3])
        @aspect = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])  # Could be nil, 'samples', or 'attributes'
        @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
        @dbApiHelper.rackEnv = @rackEnv if(@rackEnv)
        @sampleApiHelper = BRL::Genboree::REST::Helpers::SampleApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
        @sampleApiHelper.rackEnv = @rackEnv if(@rackEnv)
        initStatus = initGroupAndDatabase()
        if(initStatus == :'OK')
          unless(@dbu.selectBioSampleSetByName(@bioSampleSetName).length > 0)
            initStatus = @statusName = :'Not Found'
            @statusMsg = "NO_BIOSAMPLE: The sampleSet #{@bioSampleSetName.inspect} was not found in the database #{@dbName.inspect}."
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
        if(@aspect.nil?)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet")
          # Get the bioSampleSet by name
          bioSampleSetRows = @dbu.selectBioSampleSetByName(@bioSampleSetName)
          if(bioSampleSetRows != nil and bioSampleSetRows.length > 0)
            bioSampleSetRow = bioSampleSetRows.first
            avpHash = getAvpHash(@dbu, bioSampleSetRow['id'])
            entity = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, bioSampleSetRow['name'], bioSampleSetRow['state'], avpHash)
            entity.detailed = @detailed
            entity.dbu = @dbu
            entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(bioSampleSetRow['name'])}")
            entity.bioSampleRefBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample")
            @statusName = configResponse(entity)
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The sampleSet #{@bioSampleSetName.inspect} does not exist in database #{@dbName.inspect} and group #{@groupName.inspect}.")
          end
          bioSampleSetRows.clear() unless (bioSampleSetRows.nil?)
        elsif(@aspect == 'attributes')
          commonAttributesGet()
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: Unrecognized apsect for get: #{@aspect.inspect} ")
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

     # ATTRIBUTES INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def selectEntityByName(entityName)
      return @dbu.selectBioSampleSetByName(entityName)
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a BioSampleSetEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      initStatus = initOperation()
      # Check permission for inserts (must be author/admin of a group)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create sampleSets in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else
        # Regular sampleSet/bioSampleSet operation
        if(@aspect.nil?)
          # Get the entity from the HTTP request
          entity = parseRequestBodyForEntity('BioSampleSetEntity')
          if(entity == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type BioSampleSetEntity")
          elsif(entity.nil? and initStatus == :'OK')
            # Cannot update a bioSampleSet with a nil entity
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an update")
          elsif(entity != nil and !entity.name.empty? and !entity.name.nil? and entity.name != @bioSampleSetName and bioSampleSetExists(@dbu, entity.name))
            # Name Conflict - don't try insert (when :'Not Found') or update (when :OK)
            @apiError = BRL::Genboree::GenboreeError.new(:'Conflict', "DUPLICATE_NAME: There is already a bioSampleSet in the database #{@dbName.inspect} called #{entity.name.inspect}")
          elsif(entity.nil? and initStatus == :'Not Found')
            # Insert a bioSampleSet with default values
            rowsInserted = @dbu.insertBioSampleSet(@bioSampleSetName)
            if(rowsInserted == 1)
              # Get the newly created bioSampleSet to return
              newBioSampleSetRows = @dbu.selectBioSampleSetByName(@bioSampleSetName)
              newBioSampleSet = newBioSampleSetRows.first
              @statusName=:'Created'
              @statusMsg="The sampleSet was successfully created."
              avpHash = getAvpHash(@dbu, newBioSampleSet['id'])
              respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], {})
              respBody.setStatus(@statusName, @statusMsg)
              respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
              configResponse(respBody, @statusName)
              newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sampleSet #{@bioSampleSetName.inspect} in the data base #{@dbName.inspect}")
            end
          elsif(initStatus == :'Not Found' and entity and !entity.name.nil? and !entity.name.empty?)
            if(entity.name == @bioSampleSetName)
              # Insert the bioSampleSet
              rowsInserted = @dbu.insertBioSampleSet(entity.name, entity.state)
              # Insert any bioSamples if a bioSample list is present
              if(rowsInserted == 1) # successfull db insertion
                # Get the newly created bioSample to return
                newBioSampleSetRows = @dbu.selectBioSampleSetByName(entity.name)
                newBioSampleSet = newBioSampleSetRows.first
                bioSampleSetId = newBioSampleSet['id']
                updateAvpHash(@dbu, bioSampleSetId, entity.attributes)
                @statusName=:'Created'
                @statusMsg="The sampleSet #{entity.name} was successfully created."
                respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], entity.attributes)
                respBody.setStatus(@statusName, @statusMsg)
                respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
                configResponse(respBody, @statusName)
                newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
              else # insert failed
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sampleSet #{entity.name.inspect} in the database #{@dbName.inspect}")
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a sampleSet of a different name. Entity: #{entity.inspect}\n sampleName: #{@bioSampleSetName.inspect} ")
            end
          elsif(initStatus == :'OK' and entity and !entity.name.nil? and !entity.name.empty?)
            if(entity.name == @bioSampleSetName)
              rowsDeleted = @dbu.deleteBioSampleSetByName(@bioSampleSetName)
              # Insert the bioSampleSet
              rowsInserted = @dbu.insertBioSampleSet(entity.name, entity.state)
              # Insert any bioSamples if a bioSample list is present
              if(rowsInserted == 1) # successfull db insertion
                # Get the newly created bioSample to return
                newBioSampleSetRows = @dbu.selectBioSampleSetByName(entity.name)
                newBioSampleSet = newBioSampleSetRows.first
                bioSampleSetId = newBioSampleSet['id']
                updateAvpHash(@dbu, bioSampleSetId, entity.attributes)
                @statusName=:'Created'
                @statusMsg="The sampleSet #{entity.name} was successfully replaced."
                respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], entity.attributes)
                respBody.setStatus(@statusName, @statusMsg)
                respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
                configResponse(respBody, @statusName)
                newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
              else # insert failed
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sampleSet #{entity.name.inspect} in the database #{@dbName.inspect}")
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: You cannot use this URL to insert a sampleSet of a different name. Entity: #{entity.inspect}\n sampleName: #{@bioSampleSetName.inspect} ")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update layout #{@bioSampleSetName.inspect} in the database #{@dbName.inspect}")
          end
        # For adding samples to sampleSet
        elsif(@aspect == 'samples')
          # Create a sampleList from either the bioSampleEntityList or refList payload
          error = createSampleList()
          # Make sure all samples exist are in the same db as the sampleSet if payload is refList
          if(error.empty?)
            # New sampleSet
            bioSampleAttrNames = []
            attrNames = {}
            bioSampleAttrValues = []
            attrValues = {}
            bioSample2attributes = []
            bioSample2bioSampleSet = []
            if(initStatus == :'Not Found')
              rowsInserted = @dbu.insertBioSampleSet(@bioSampleSetName, '0')
              if(rowsInserted == 1) # successfull db insertion
                # Get the newly created bioSample to return
                newBioSampleSetRows = @dbu.selectBioSampleSetByName(@bioSampleSetName)
                newBioSampleSet = newBioSampleSetRows.first
                bioSampleSetId = newBioSampleSet['id']
                # Collect all necessary info in hashes and arrays for insertions/selections in the end to avoid making sql calls for every entity
                @sampleList.each { |sample|
                  bioSampleId = nil
                  if(sample.respond_to?(:name)) # bioSampleEntityList
                    bioSampleRows = @dbu.selectBioSampleByName(sample.name)
                    # Only add if it does not already exist
                    if(bioSampleRows.nil? or bioSampleRows.empty?)
                      type = sample.type ? sample.type : ''
                      biomaterialState = sample.biomaterialState ? sample.biomaterialState : ''
                      biomaterialProvider = sample.biomaterialProvider ? sample.biomaterialProvider : ''
                      biomaterialSource = sample.biomaterialSource ? sample.biomaterialSource : ''
                      state = sample.state ? sample.state : 0
                      rowsInserted = @dbu.insertBioSample(sample.name, type, biomaterialState, biomaterialProvider, biomaterialSource, state)
                      bioSampleId = @dbu.getLastInsertId(:userDB)
                      # Add attributes for the samples:
                      avpHash = sample.avpHash
                      avpHash.each_key { |attrName|
                        attrValue = avpHash[attrName]
                        if(!attrNames.has_key?(attrName))
                          attrNames[attrName] = nil
                          bioSampleAttrNames << [attrName, 0]
                        end
                        if(!attrValues.has_key?(attrValue))
                          attrValues[attrValue] = nil
                          bioSampleAttrValues << [attrValue, 0]
                        end
                        ## Will replace by the ids of attrName and attrValue later
                        bioSample2attributes << [bioSampleId, attrName, attrValue]
                      }
                    else
                      bioSampleId = bioSampleRows.first['id']
                    end
                  elsif(sample.respond_to?(:url)) # refEntityList
                    bioSampleName = CGI.escape(@sampleApiHelper.extractName(sample.url))
                    # for refEntityList sample has to be present
                    bioSampleRecs = @dbu.selectBioSampleByName(bioSampleName)
                    bioSampleRec = bioSampleRecs.first
                    bioSampleId = bioSampleRec['id']
                  end
                  bioSample2bioSampleSet << [bioSampleId, bioSampleSetId]
                }
                # Insert the attributes for newly added biosamples, if required
                if(!bioSample2attributes.empty?)
                  attrRecs = @dbu.selectBioSampleAttrNamesByNames(attrNames.keys)
                  if(attrRecs.size < attrNames.size)
                    @dbu.insertBioSampleAttrNames(bioSampleAttrNames, bioSampleAttrNames.size)
                    attrRecs = @dbu.selectBioSampleAttrNamesByNames(attrNames.keys)
                  end
                  attrRecs.each { |attr|
                    attrNames[attr['name']] = attr['id']
                  }
                  valueRecs = @dbu.selectBioSampleAttrValueByValues(attrValues.keys)
                  if(valueRecs.size < attrValues.size)
                    @dbu.insertBioSampleAttrValues(bioSampleAttrValues, bioSampleAttrValues.size)
                    valueRecs = @dbu.selectBioSampleAttrValueByValues(attrValues.keys)
                  end
                  valueRecs.each { |val|
                    attrValues[val['value']] = val['id']
                  }
                  # For each record, the second entry is the attrName and the third entry is the attr value
                  bioSample2attributes.size.times { |ii|
                    bioSample2attributes[ii][1] = attrNames[bioSample2attributes[ii][1]]
                    bioSample2attributes[ii][2] = attrValues[bioSample2attributes[ii][2]]
                  }
                  @dbu.insertBioSample2Attributes(bioSample2attributes, bioSample2attributes.size)
                end
                # Finally insert the records for linking
                @dbu.insertBioSample2BioSampleSets(bioSample2bioSampleSet, bioSample2bioSampleSet.size)
                @statusName=:'Created'
                @statusMsg="The sampleSet #{@bioSampleSetName.inspect} was created and the samples were added."
                respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], {})
                respBody.setStatus(@statusName, @statusMsg)
                respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
                configResponse(respBody, @statusName)
                newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
              else # insert failed
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to create sampleSet #{@bioSampleSetName.inspect} in the database #{@dbName.inspect}")
              end
            # sampleSet Exists
            elsif(initStatus == :'OK')
              $stderr.puts "sampleSet Exists..."
              newBioSampleSetRows = @dbu.selectBioSampleSetByName(@bioSampleSetName)
              newBioSampleSet = newBioSampleSetRows.first
              bioSampleSetId = newBioSampleSet['id']
              @sampleList.each { |sample|
                bioSampleId = nil
                if(sample.respond_to?(:name)) # bioSampleEntityList
                  bioSampleRows = @dbu.selectBioSampleByName(sample.name)
                  # Only add if it does not already exist
                  if(bioSampleRows.nil? or bioSampleRows.empty?)
                    type = sample.type ? sample.type : ''
                    biomaterialState = sample.biomaterialState ? sample.biomaterialState : ''
                    biomaterialProvider = sample.biomaterialProvider ? sample.biomaterialProvider : ''
                    biomaterialSource = sample.biomaterialSource ? sample.biomaterialSource : ''
                    state = sample.state ? sample.state : 0
                    rowsInserted = @dbu.insertBioSample(sample.name, type, biomaterialState, biomaterialProvider, biomaterialSource, state)
                    bioSampleId = @dbu.getLastInsertId(:userDB)
                    # Add attributes for the samples:
                    avpHash = sample.avpHash
                    avpHash.each_key { |attrName|
                      attrValue = avpHash[attrName]
                      if(!attrNames.has_key?(attrName))
                        attrNames[attrName] = nil
                        bioSampleAttrNames << [attrName, 0]
                      end
                      if(!attrValues.has_key?(attrValue))
                        attrValues[attrValue] = nil
                        bioSampleAttrValues << [attrValue, 0]
                      end
                      ## Will replace by the ids of attrName and attrValue later
                      bioSample2attributes << [bioSampleId, attrName, attrValue]
                    }
                  else
                    bioSampleId = bioSampleRows.first['id']
                  end
                elsif(sample.respond_to?(:url)) # refEntityList
                  bioSampleName = CGI.escape(@sampleApiHelper.extractName(sample.url))
                  # for refEntityList sample has to be present
                  bioSampleRecs = @dbu.selectBioSampleByName(bioSampleName)
                  bioSampleRec = bioSampleRecs.first
                  bioSampleId = bioSampleRec['id']
                end
                bioSample2bioSampleSet << [bioSampleId, bioSampleSetId]
              }
              # Insert the attributes for newly added biosamples, if required
              if(!bioSample2attributes.empty?)
                attrRecs = @dbu.selectBioSampleAttrNamesByNames(attrNames.keys)
                if(attrRecs.size < attrNames.size)
                  @dbu.insertBioSampleAttrNames(bioSampleAttrNames, bioSampleAttrNames.size)
                  attrRecs = @dbu.selectBioSampleAttrNamesByNames(attrNames.keys)
                end
                attrRecs.each { |attr|
                  attrNames[attr['name']] = attr['id']
                }
                valueRecs = @dbu.selectBioSampleAttrValueByValues(attrValues.keys)
                if(valueRecs.size < attrValues.size)
                  @dbu.insertBioSampleAttrValues(bioSampleAttrValues, bioSampleAttrValues.size)
                  valueRecs = @dbu.selectBioSampleAttrValueByValues(attrValues.keys)
                end
                valueRecs.each { |val|
                  attrValues[val['value']] = val['id']
                }
                # For each record, the second entry is the attrName and the third entry is the attr value
                bioSample2attributes.size.times { |ii|
                  bioSample2attributes[ii][1] = attrNames[bioSample2attributes[ii][1]]
                  bioSample2attributes[ii][2] = attrValues[bioSample2attributes[ii][2]]
                }
                @dbu.insertBioSample2Attributes(bioSample2attributes, bioSample2attributes.size)
              end
              # Finally insert the records for linking
              @dbu.insertBioSample2BioSampleSets(bioSample2bioSampleSet, bioSample2bioSampleSet.size)
              @statusName=:'Created'
              @statusMsg = 'The samples were successfully added.'
              respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], {})
              respBody.setStatus(@statusName, @statusMsg)
              respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
              configResponse(respBody, @statusName)
              newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to add samples to sampleSet; #{@bioSampleSetName.inspect} in the database #{@dbName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: #{error.inspect} ")
          end
        # For adding attributes
        elsif(@aspect == 'attributes')
          if(initStatus == :'Not Found')
            rowsInserted = @dbu.insertBioSampleSet(@bioSampleSetName, '0')
            if(rowsInserted == 1) # successfull db insertion
              # Get the newly created bioSample to return
              newBioSampleSetRows = @dbu.selectBioSampleSetByName(@bioSampleSetName)
              newBioSampleSet = newBioSampleSetRows.first
              bioSampleSetId = newBioSampleSet['id']
              @statusName=:'Created'
              @statusMsg="The sampleSet #{@bioSampleSetName.inspect} was successfully created."
              # Add attributes
              commonAttributesPut()
              avpHash = getAvpHash(@dbu, bioSampleSetId)
              respBody = BRL::Genboree::REST::Data::BioSampleSetEntity.new(@connect, newBioSampleSet['name'],  newBioSampleSet['state'], avpHash)
              respBody.setStatus(@statusName, @statusMsg)
              respBody.makeRefsHash(makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sampleSet/#{Rack::Utils.escape(newBioSampleSet['name'])}"))
              configResponse(respBody, @statusName)
              newBioSampleSetRows.clear() unless(newBioSampleSetRows.nil?)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while attempting to update layout #{@bioSampleSetName.inspect} in the database #{@dbName.inspect}")
            end
          elsif(initStatus == :'OK')
            commonAttributesPut()
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "DB_ERROR: There was an unknown database error while putting attributes for sampleSet: #{@bioSampleSetName.inspect} in the database #{@dbName.inspect}")
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: Unrecognized apsect for put: #{@aspect.inspect} ")
        end
      end
      # Respond with an error if appropriate
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Creates sampleList from either sampleList (bioSampleEntityList) or refList (refEntityList)
    # [+returns+] error
    def createSampleList()
      error = ''
      @sampleList = []
      # Check if request body is a sampleList or a refList
      entities = parseRequestBodyForEntity('RefEntityList')
      if(entities.nil?)
        error =  'payload required to add/delete samples in sampleSet'
      elsif(entities.array[0] == :'Unsupported Media Type') # Must be bioSampleEntityList
        entities = parseRequestBodyForEntity('BioSampleEntityList')
        if(entities.nil?)
          error =  'payload required to add/delete samples in sampleSet'
        elsif(entities.array[0] == :'Unsupported Media Type')
          error = 'payload neither bioSampleEntityList nor refEntityList'
        else
          entities.each { |entity|
            if(!entity.respond_to?(:name) or entity.name.nil? or entity.name.empty?)
              error = "entity: #{entity.inspect} -> Does not have a proper value for 'name' or is missing."
              break
            else
              @sampleList.push(entity)
            end
          }
        end
      else # refEntityList
        # Need to check/validate that all samples have a url column
        sampleNames = {}
        recCount = 1
        entities.each { |entity|
          if(!entity.respond_to?(:url) or entity.url.nil? or entity.url.empty?)
            error = "entity: #{entity.inspect} -> Does not have a proper value for 'url' or is missing."
            break
          else
            @sampleList.push(entity)
          end
        }
        error = validateSampleList(@sampleList)
      end
      $stderr.puts "sampleList: #{@sampleList.inspect}"
      return error
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def deleteEntity2AttributeById(entityId, attrId=nil)
      return @dbu.deleteBioSampleSet2AttributesByBioSampleSetIdAndAttrNameId(entityId, attrId)
    end

    # ATTR INTERFACE: use attrValMap correctly to update entity's std_attrs
    def updateEntityStdAttrs(entityId, attrValMap)
      return @dbu.updateBioSampleSetById(entityId, attrValMap['name'], attrValMap['state'])
    end

    # ATTR INTERFACE: Deal with getting special attribute value (if any) (used by commonAttrGet())
    def getSpecialValue(row)
      retVal = nil
      return retVal
    end

    # ATTR INTERFACE: set up Hash for correct values of STD_ATTRS (using current + payload as appropriate)
    def updatedSpecialAttrValMap(entityRow, entityId, payloadEntity)
      attrValMap = {}
      entityText = payloadEntity.text
      # Set current values from row, update whichever is @attrName from payload
      STD_ATTRS.each { |attr|
        if(@attrName != attr) # Not one being changed, use Current Value:
          val = entityRow[attr]
          attrValMap[attr] = val
        else # One being changed, use New Value:
          if(STATE_ATTRS.key?(attr))
            # 'state' is actually column we will modify
            attrValMap['state'] = switchState(attr, entityRow['state'], entityText)
          else # non-state thing, do what is appropriate
            val = entityText
            attrValMap[attr] = val
          end
        end
      }
      return attrValMap
    end

    # ATTR INTERFACE: Calls appropriate row-select by attribute name to get attr name row
    def selectAttrNameByName(attrName)
      return @dbu.selectBioSampleSetAttrNameByName(attrName)
    end

    # [+returns+] error
    def validateSampleList(sampleList)
      # Make sure all samples exist are in the same db as the sampleSet
      error = ''
      error = 'Incorrect payload for adding samples to sampleSet' if(sampleList.nil? or sampleList.empty?)
      if(error.empty?)
        sampleList.each { |sampleUri|
          if(!@sampleApiHelper.exists?(sampleUri.url))
            error = "BAD_REQUEST: sample resource: #{sampleUri.url.inspect} does not exist. "
            break
          elsif(@dbApiHelper.extractPureUri(@rsrcURI) != @dbApiHelper.extractPureUri(sampleUri.url))
            error = "BAD_REQUEST: sample resource: #{sampleUri.url.inspect} does not belong to the same db as sampleSet: #{@rsrcURI.inspect}"
            break
          else
            # We are fine
          end
        }
      end
      return error
    end

    # Process a DELETE operation on this resource. NOTE: The put() request may
    # include a payload of a BioSampleEntityList or refEntityList with the 'samples' aspect for removing samples from a sampleList.
    # Also may be used for deleting all attributes with the 'attributes' aspect
    # In both cases above (with aspect provided), the sampleSet itself will not be removed.
    # If no aspect is provided, will remove the sampleSet itself
    # [+returns+] Rack::Response instance
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(@groupAccessStr != 'o')
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to delete sampleSets in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        else
          if(@aspect.nil?)
            bioSampleSetRow = @dbu.selectBioSampleSetByName(@bioSampleSetName)
            bioSampleSetId = bioSampleSetRow.first['id']
            avpDeletion = @dbu.deleteBioSampleSet2AttributesByBioSampleSetIdAndAttrNameId(bioSampleSetId)
            deletedRows = @dbu.deleteBioSampleSetById(bioSampleSetId)
            if(deletedRows == 1)
              entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
              entity.setStatus(:OK, "The sampleSet #{@bioSampleSetName.inspect} was successfully deleted from the database #{@dbName.inspect}")
              @statusName = configResponse(entity)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the sampleSet #{@bioSampleSetName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
            end
          elsif(@aspect == 'samples')
              error = createSampleList()
              if(error.empty?)
                bioSampleSetRow = @dbu.selectBioSampleSetByName(@bioSampleSetName)
                bioSampleSetId = bioSampleSetRow.first['id']
                problemSamples = []
                @sampleList.each { |sample|
                  bioSampleId = nil
                  bioSampleName = nil
                  if(sample.respond_to?(:name)) # for a bioSampleEntityList payload
                    bioSampleRow = @dbu.selectBioSampleByName(sample.name)
                    bioSampleId = bioSampleRow.first['id']
                    bioSampleName = sample.name
                  elsif(sample.respond_to?(:url)) # for a refEntityList payload
                    bioSampleName = CGI.escape(@sampleApiHelper.extractName(sample.url))
                    bioSampleRow = @dbu.selectBioSampleByName(bioSampleName)
                    bioSampleId = bioSampleRow.first['id']
                  end
                  @dbu.deleteBioSample2BioSampleSetByBioSampleIdAndBioSampleSetId(bioSampleId, bioSampleSetId)
                }
                entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                entity.setStatus(:OK, "The samples were successfully removed from the sampleSet #{@bioSampleSetName.inspect}")
                @statusName = configResponse(entity)
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: #{error.inspect} ")
              end
          elsif(@aspect == 'attributes')
            commonAttributesDelete()
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: Unrecognized apsect for delete: #{@aspect.inspect} ")
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class BioSampleSet
end ; end ; end # module BRL ; module REST ; module Resources
