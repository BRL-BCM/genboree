#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/util'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/unlockedRefEntity'
require 'brl/genboree/abstract/resources/unlockedGroupResource'


module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # GrpUnlockedResources
  class GrpUnlockedResources < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # Fixed: This path list was hardcoded here, but should change when core paths list changes in Genboree overall
    DEFAULT_RESOURCE_PATHS = GenboreeRESTRackup::DEFAULT_RESOURCE_PATHS
    RSRC_TYPE = 'unlockedGroupRsrc'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos$</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/unlockedResources$}     # Look for /REST/v1/grp/{grp}/unlockedResources URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @grpApiUriHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf)
      # Init and check group & database exist and are accessible
      if(@statusName == :OK)
        @statusName = initGroup()
      end
      return @statusName
    end

    # Process a GET operation on this resource.
    #
    # Admin privileges is required for PUT and DELETE access to this resource.
    # Non-admin users with access to the group and database resource should have access to GET the unlockKey
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      # If something wasn't right, represent as error
      if(initStatus == :OK)
        # The method below returns an array of hashes of resorces from the unlockedGroupResources and unlockedGroupResourceParents tables
        # {type=>track, id=>34, parents => [{type=>database, id=>45}]}
        grpPath = @grpApiUriHelper.extractPureUri(@rsrcPath)
        @unlockedResources = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getUnlockedResourcesUnderRsrc(@dbu, grpPath)
        if(@unlockedResources.nil? or @unlockedResources.empty?)
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', 'The group does not have any unlocked resources.', nil, false)
        else
          setResponse()
        end
      end
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource
    # [+returns+] <tt>Rack::Response</tt> instance
    # @todo unlocking bottom-level resources is buggy -- underlying database design requires unique group id, type, foreign key for item of type 3-tuple -- fix it
    def put()
      initStatus = initOperation()
      # ADMIN only
      if(@groupAccessStr != 'o')
        @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to access this resource.", nil, false)
      else
        if(initStatus == :OK or initStatus == :'Not Found')
          # Request body must be a RefEntityList
          payload = parseRequestBodyForEntity(['UnlockedRefEntityList', 'RefEntityList'])
          if(payload == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The request body in not a valid media type for this request.', nil, false)
          else
            if(payload.is_a?(RefEntityList) or payload.is_a?(UnlockedRefEntityList))
              # Parse the entities in the payload to identify the resources
              payload.each { |reqRef|
                # If it's an UnlockedRefEntity, we need to respect the 'public' field (but not 'key')
                # but then we need to do the rest of it as if it were a RefEntityList
                if(reqRef.is_a?(UnlockedRefEntity))
                  isPublic = reqRef.public
                else
                  isPublic = false
                end
                resourceClass, matchData = getResource(reqRef.url)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "reqRef:\n\n#{reqRef.inspect}\n\nreqRef.url: #{reqRef.url.inspect}\nresourceClass: #{resourceClass.inspect}\nmatchData:\n\n#{matchData.inspect}\n\n")
                dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
                if(!resourceClass.nil? and resourceClass::UNLOCKABLE)
                  # OLD CODE. Keep for Track for now, for backward compatibility.
                  if(resourceClass == BRL::REST::Resources::Track)
                    # Ensure that the resource belongs to the same group
                    # Is the database linked to the group
                    groupName, databaseName, trackName = Rack::Utils.unescape(matchData[1]), Rack::Utils.unescape(matchData[2]), Rack::Utils.unescape(matchData[3])
                    if(groupName == @groupName)
                      rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.unlockTrack(dbu, groupName, databaseName, trackName, isPublic)
                      if(rows < 1)
                        @statusMsg = "One or more resources were not unlocked. " if(!@statusMsg.is_a?(String))
                        @statusMsg += " <#{reqRef.url}> not unlocked."
                        @statusName = :'Multiple Choices'
                      end
                    else
                      @statusMsg = "One or more resources were not unlocked. " if(!@statusMsg.is_a?(String))
                      @statusMsg += " <#{reqRef.url}> does not belong to the group #{@groupName}."
                      @statusName = :'Multiple Choices'
                    end
                  # OLD CODE. Keep for Database for now, for backward compatibility.
                  elsif(resourceClass == BRL::REST::Resources::Database)
                    groupName, databaseName = Rack::Utils.unescape(matchData[1]), Rack::Utils.unescape(matchData[2])
                    # Is the database linked to the group
                    if(groupName == @groupName)
                      rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.unlockDatabase(dbu, groupName, databaseName, isPublic)
                      if(rows < 1)
                        @statusMsg = "One or more resources were not unlocked. " if(!@statusMsg.is_a?(String))
                        @statusMsg += " <#{reqRef.url}> not unlocked."
                        @statusName = :'Multiple Choices'
                      end
                    else
                      @statusMsg = "One or more resources were not unlocked. " if(!@statusMsg.is_a?(String))
                      @statusMsg += " <#{reqRef.url}> does not belong to the group #{@groupName}."
                      @statusName = :'Multiple Choices'
                    end
                  else # For other kinds of resources. Keep the older non-generic code above for tracks
                    # How deep is the thing we are unlocking?
                    if(matchData.size <= 1)
                      # Unexpected match error. Got a match but no sub-group.
                      @statusMsg = "Found a matching resource without extracting any names from the URL path? Something doesn't make sense. (URL: #{reqRef.url.inspect} ; Resource class: #{resourceClass.inspect}" if(!@statusMsg.is_a?(String))
                      @statusMsg += " <#{reqRef.url}> is not unlockable."
                      @statusName = :'Multiple Choices'
                    else
                      # Must be something at the group-level or below
                      groupName = Rack::Utils.unescape(matchData[1])
                      # Does the group info from the url match the group in the request?
                      if(groupName == @groupName)
                        rsrcType = resourceClass.const_get("RSRC_TYPE")
                        # OLD CODE. Shouldn't get here if it's a TRACK or a DATABASE, which are handled above via resourceClass detection.
                        # * Commenting out
                        #if(matchData.size == 4 and dbApiHelper.extractPureUri(reqRef.url))
                        #  rsrcType = dbApiHelper.extractType(reqRef.url)
                        #  if(rsrcType)
                        #    databaseName = Rack::Utils.unescape(matchData[2])
                        #    rsrcName = Rack::Utils.unescape(matchData[3])
                        #    rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.unlockDbChildRsrc(dbu, groupName, databaseName, rsrcName, rsrcType, isPublic)
                        #    if(rows < 1)
                        #      @statusMsg = "One or more resources were not unlocked. " if(!@statusMsg.is_a?(String))
                        #      @statusMsg += " <#{reqRef.url}> not unlocked."
                        #    end
                        #  else
                        #    @statusMsg = "One or more resources were not unlocked because unlocking this resource is not supported currently. " if(!@statusMsg.is_a?(String))
                        #    @statusMsg += " <#{reqRef.url}> not unlocked."
                        #  end
                        if(matchData.size >= 2) # Then something at top-level is being unlocked. Like a group or something...This ONLY SUPPORTS GROUPS (for safety)
                          # We already know groupName == @groupName, so we can use @groupId here:
                          unlockKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.unlockResource(dbu, @groupId, rsrcType, reqRef.url, isPublic)
                          unless(unlockKey)
                            @statusMsg = "One or more resources were not unlocked because unlocking this resource is not supported currently." if(!@statusMsg.is_a?(String))
                            @statusMsg += " <#{reqRef.url}> not unlocked."
                            @statusName = :'Multiple Choices'
                          end
                        end
                      else
                        @statusMsg = "One or more resources were not unlocked because the resource being unlocked is not in same group as the one mentioned in the request path (i.e. #{groupName.inspect} != #{@groupName.inspect})." if(!@statusMsg.is_a?(String))
                        @statusMsg += " <#{reqRef.url}> not unlocked."
                        @statusName = :'Multiple Choices'
                      end
                    end
                  end
                else
                  # A resource that is not unlockable has been submitted.
                  @statusMsg = "One or more resources could not be unlocked because it is not unlockable. " if(!@statusMsg.is_a?(String))
                  @statusMsg += " <#{reqRef.url}> is not unlockable."
                  @statusName = :'Multiple Choices'
                end
              }
            end
          end
          @unlockedResources = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getUnlockedResourcesForGroupId(@dbu, @groupId)
          setResponse()
        end
      end
      @resp = representError() if(@statusName != :OK and @statusName != :'Multiple Choices')
      return @resp
    end

    def delete()
      initStatus = initOperation()
      # ADMIN only
      if(@groupAccessStr != 'o')
        @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to access this resource.", nil, false)
      else
        if(initStatus == :OK)
          # Request body can be a RefEntityList
          payload = parseRequestBodyForEntity(['UnlockedRefEntityList', 'RefEntityList'])
          if(payload == :'Unsupported Media Type')
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The request body in not a valid media type for this request.', nil, false)
          elsif(payload.nil?)
            # Delete everything from the unlocked tables
            @dbu.deleteUnlockedGroupResourcesByGroupId(@groupId)
            @statusName, @statusMsg = :'Moved Permanently', "All unlocked resources for this group have been locked."
          elsif(payload.is_a?(UnlockedRefEntityList) or payload.is_a?(RefEntityList))
            # Validate the payload first
            # Parse the entities in the payload to identify the resources
            dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
            payload.each { |reqRef|
              @statusMsg = "Results: "
              resourceClass, matchData = getResource(reqRef.url)
              # OLD CODE. Keep for Track for now, for backward compatibility.
              if(resourceClass == BRL::REST::Resources::Track)
                groupName, databaseName, trackName = Rack::Utils.unescape(matchData[1]), Rack::Utils.unescape(matchData[2]), Rack::Utils.unescape(matchData[3])
                rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockTrack(dbu,  groupName, databaseName, trackName)
                @statusMsg += (rows > 0) ? " - Removed #{reqRef.url}" : " - Not removed #{reqRef.url}"
              # OLD CODE. Keep for Database for now, for backward compatibility.
              elsif(resourceClass == BRL::REST::Resources::Database)
                groupName, databaseName = matchData[1], matchData[2]
                rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockDatabase(dbu, groupName, databaseName)
                @statusMsg += (rows > 0) ? " - Removed #{reqRef.url}" : " - Not removed #{reqRef.url}"
              else # For any kind of resource. Keep the older non-generic code above for tracks & databases
                # Must be something at the group-level or below
                groupName = Rack::Utils.unescape(matchData[1])
                # Does the group info from the url match the group in the request?
                if(groupName == @groupName)
                  lockOk = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockResource(dbu, reqRef.url)
                  if(lockOk)
                    @statusMsg << "\n  - DELETED key. [Re]Locked: #{reqRef.url.inspect}"
                  else
                    @statusMsg << "\n  - DID NOT DELETE KEY. Perhaps #{reqRef.url.inspect} was not unlocked to begin with?"
                  end
                  # OLD CODE. Should not be handling tracks or databases here, so should be safe to remove in favour of simple core just above.
                  #groupName, databaseName, rsrcName = Rack::Utils.unescape(matchData[1]), Rack::Utils.unescape(matchData[2]), Rack::Utils.unescape(matchData[3])
                  #rows = 0
                  #if(dbApiHelper.extractPureUri(reqRef.url)) # Ensure rsrc is a db child
                  #  rsrcType = dbApiHelper.extractType(reqRef.url)
                  #  if(rsrcType)
                  #    rows = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.lockDbChildRsrc(dbu, groupName, databaseName, rsrcName, rsrcType)
                  #  end
                  #  @statusMsg += (rows > 0) ? " - Removed #{reqRef.url}" : " - Not removed #{reqRef.url}"
                  #else
                  #  @statusMsg += (rows > 0) ? " - Removed #{reqRef.url}" : " - Not removed #{reqRef.url}"
                  #end
                else
                  @statusMsg = "One or more resources were not [re]locked because the resource being unlocked is not in same group as the one mentioned in the request path (i.e. #{groupName.inspect} != #{@groupName.inspect})."
                  @statusMsg += " <#{reqRef.url}> not unlocked."
                  @statusName = :'Multiple Choices'
                end
              end
              @unlockedResources = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getUnlockedResourcesForGroupId(@dbu, @groupId)
            }
          end
          setResponse()
        end
      end
      @resp = representError() if(@statusName != :OK and @statusName != :'Multiple Choices')
      return @resp
    end

    def setResponse()
      # The method below returns an array of hashes of resources from the unlockedGroupResources and unlockedGroupResourceParents tables
      # {type=>track, id=>34, parents => [{type=>database, id=>45}]}
      if(!@unlockedResources.nil? and !@unlockedResources.empty?)
        payload = parseRequestBodyForEntity(['UnlockedRefEntityList', 'RefEntityList'])
        entityList = BRL::Genboree::REST::Data::UnlockedRefEntityList.new(@connect)
        if(payload == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The request body in not a valid media type for this request.', nil, false)
        else
          requestedUrl = {}
          if(payload.is_a?(RefEntityList) or payload.is_a?(UnlockedRefEntityList))
            # Create a lookup hash of requested urls used to filter the response (if had any in payload)
            payload.each { |requestObj|
              requestedUrl[normalizeUrl(requestObj.url)] = true
            }
          end
          @unlockedResources.each { |resourceHash|
            url = getResourceUrl(resourceHash)
            # Add the entity to the list if the payload is empty (returns all resources) or if it's been specified in the request
            if(!url.nil? and (payload.nil? or requestedUrl.nil? or requestedUrl[url]))
              # Create the entity
              entity = BRL::Genboree::REST::Data::UnlockedRefEntity.new(@connect, url, resourceHash['key'], resourceHash['public'])
              entityList << entity
            end
          }
          entityList.setStatus(@statusName, @statusMsg)
          configResponse(entityList, @statusName)
        end
      end
    end

    def getResource(url)
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "start getResources")
      uriObj = URI.parse(url)
      matchingResourceClass = nil
      # Try to lazy-load (require) each file found in the resourcePaths.
      $LOAD_PATH.sort.each { |topLevel|
        if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
          DEFAULT_RESOURCE_PATHS.each { |rsrcPath|
            rsrcFiles = Dir["#{topLevel}/#{rsrcPath}/*.rb"]
            rsrcFiles.sort.each { |rsrcFile|
              begin
                require rsrcFile
              rescue => err # just log error and try more files
                BRL::Genboree::GenboreeUtil.logError("ERROR: brl/rackups/thin/genboreeRESTRackup.ru#loadResources() => failed to require file '#{rsrcFile.inspect}'.", err)
              end
            }
          }
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "found resource class files [why is this being done via getResources() and not once at start-up??]")
      # Find all the classes in BRL::REST::Resources that inherit from BRL::REST::Resources::Resource
      resources = []
      BRL::REST::Resources.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::REST::Resources.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::REST::Resources::Resource
        next unless(const.is_a?(Class) and const.ancestors.include?(BRL::REST::Resource))
        resources << const
      }
      resources.sort! { |aa, bb| bb.priority() <=> aa.priority() }  # sort resources according to their priorities
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "URL PATH to MATHC: #{uriObj.path}")
      resources.each { |resource|
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "CHECK #{resource.inspect} => #{(uriObj.path =~ resource.pattern()) ? true : false}")
        if(uriObj.path =~ resource.pattern())
          matchingResourceClass = resource
          break
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered resource classes")
      return matchingResourceClass, $~
    end

    def getResourceUrl(resourceHash)
      url = nil
      # Do we have a known resource table row id? Old approach, with highly specific per-resource code.
      # - If so, do old way for back-portability
      if(resourceHash['id'])
        case resourceHash['type']
        when 'track'
          trackName = BRL::Genboree::Abstract::Resources::Track.getName(@dbu, resourceHash['parents'].first['id'], resourceHash['id'])
          databaseRows = @dbu.selectRefseqById(resourceHash['parents'].first['id'])
          if(!databaseRows.nil? and !databaseRows.empty?)
            databaseName = databaseRows.first['refseqName']
            url = makeRefBase(BRL::REST::Resources::Track.getPath(@groupName, databaseName, trackName))
          end
        when 'database'
          databaseRows = @dbu.selectRefseqById(resourceHash['id'])
          if(!databaseRows.nil? and !databaseRows.empty?)
            databaseName = databaseRows.first['refseqName']
            url = makeRefBase(BRL::REST::Resources::Database.getPath(@groupName, databaseName))
          end
        when 'group'
          url = makeRefBase(BRL::REST::Resources::Group.getPath(@groupName))
        else
          url = makeRefBase(resourceHash['uri'])
        end
      else # No known resource table row id at this time (can get, IF needed, using 'type' and the info in the url)
        url = makeRefBase(resourceHash['uri'])
      end
      return url
    end

    def normalizeUrl(url)
      if(url.is_a?(String))
        url = URI.parse(url)
      end
      return makeRefBase(url.path)
    end
  end # class GrpUnlockedResources
end ; end ; end # module BRL ; module REST ; module Resources
