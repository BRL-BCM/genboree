#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/resources/kbViews'
require 'brl/genboree/rest/resources/kbQueries'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/em/deferrableBodies/deferrableKbDocsBody'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/kb/helpers/viewsHelper'
require 'brl/genboree/kb/helpers/queriesHelper'
require 'brl/genboree/kb/queries/abstractQueries'
require 'brl/genboree/kb/transformers/collToDocTransformWithkbDocLinks.rb'
require 'brl/genboree/rest/helpers/apiCacheHelper'
require 'brl/genboree/kb/stats/collStats'
require 'brl/genboree/kb/lookupSupport/kbDocLinks.rb'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbDocs - exposes a document in a user data collection within a GenboreeKB knowledgebase
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class KbDocs < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true }
    RSRC_TYPE = 'kbDocs'

    # these limits are fairly arbitrary because many factors can affect an HTTP timeout
    MAX_DOCS = 500
    MAX_DOCS_MULTI_TABBED_GET = 500
    MAX_BYTES = 15 * 1024 * 1024 # 15 MiB

    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = @collName = @docName = nil
      @payloadParams = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/docs$}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 to 10.
    def self.priority()
      return 7
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName  = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName     = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName   = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = initGroupAndKb(checkAccess=false) # access is checked explicitly in http methods
        if(initStatus == :OK)
          # Exclude metadata for now. The current approach for adding metadata is inefficient and does not scale with large doc responses. 
          @excludeMetadata = true
          # This gets initialized if there is a get payload - HashEntity
          @payloadParams = nil
          # Look for doc limits
          @limit = @nvPairs['limit'].to_s.to_i
          @limit = nil if(@limit <= 0)
          # Look for doc skip (with limit, this can do pageination)
          @skip = @nvPairs['skip'].to_s.to_i
          @skip = nil if(@skip <= 0)
          # Look for filters
          @matchMode = @nvPairs['matchMode'].to_s.strip
          @matchProps = @nvPairs['matchProps'].to_s.strip
          @matchValue = @nvPairs['matchValue'].to_s.strip
          @matchProp = @nvPairs['matchProp'].to_s.strip
          @matchValues = @nvPairs['matchValues'].to_s.strip
          @matchLogicOp = @nvPairs['matchLogicOp'].to_s.strip
          @allOrNothing = @nvPairs.key?('allOrNothing') ? @nvPairs['allOrNothing'] : false
          @viewName = ( @nvPairs.key?('matchView') ? @nvPairs['matchView'] : nil )
          @queryName = ( @nvPairs['matchQuery'] ? @nvPairs['matchQuery'] : nil )
          @viewCursor = nil
          @queryCursor = nil
          @propPaths = @nvPairs['propPaths'].to_s.strip
          @propValues = @nvPairs['propValues'].to_s.strip
          @keepQPaths = @nvPairs.key?('keepQPaths')? @nvPairs['keepQPaths'] : false
          @save = (@nvPairs['save'] =~ /\S/ ? @nvPairs['save'].to_s.to_bool : true)
          if(@allOrNothing == 'true' or @allOrNothing == 'yes' or @allOrNothing == '1')
            @allOrNothing = true
          else
            @allOrNothing = false
          end
          @transformationName = @nvPairs['transform'].to_s.strip
          @transformationName = nil unless(@transformationName =~ /\S/)
          @onClick = (@nvPairs['onClick'] == 'true') ? true : false
          @matchOrderBy = @nvPairs['matchOrderBy'].to_s.strip
          @matchOrderByDocPath = nil
          if(@gbEnvelope)
            @wrapInGenbEnvelope = true
          else
            @wrapInGenbEnvelope = false
          end

          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Pre-Clean:\n  @matchMode = #{@matchMode.inspect}\n  @matchLogicOp = #{@matchLogicOp.inspect}\n  @matchProps = #{@matchProps.inspect}\n  @matchVal = #{@matchValue.inspect}\n  @matchProp = #{@matchProp.inspect}\n  @matchValues = #{@matchValues.inspect}")

          # If a query name has been provided, we will try to emulate a query with matchProps
          # Currently only one of the two predefined queries are allowed
          if(initStatus == :OK)
            # validate the match* params
            validateMatchParams()    
            if(@statusName == :OK)        
              if(!@queryName.nil?)
                implicitQueries = BRL::Genboree::KB::Helpers::QueriesHelper::IMPLICIT_QUERIES_DEFS.keys
                if(!implicitQueries.include?(@queryName))
                  # Get the query cursor for the respective query document from the internal collection
                  queryCollName = BRL::Genboree::KB::Helpers::QueriesHelper::KB_CORE_COLLECTION_NAME
                  queriesHelper = @mongoKbDb.queriesHelper()
                  if(queriesHelper.coll.nil?)
                    initStatus = :"Not Found"
                    @statusName = :"Not Found"
                    @statusMsg = "NO_QUERY_COLL: can't get queries document named #{@queryName.inspect} because it appears to be no collection #{queryCollName} in the #{@kbName.inspect} GenboreeKB, within group #{@groupName.inspect} . #{queryCollName.inspect} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
                  else # get the cursor
                    queryCursor = queriesHelper.coll.find({ "Query.value" => @queryName})
                    if(queryCursor and queryCursor.is_a?(Mongo::Cursor) and queryCursor.count > 0) # Should be just one
                      queryCursor.rewind!
                      @queryCursor = queryCursor
                    else
                      initStatus = :"Not Found"
                      @statusName = :"Not Found"
                      @statusMsg = "NO_QUERY_DOC: queries document named #{@queryName.inspect} is not found in the collection #{queryCollName.inspect} in the #{@kbName.inspect} GenboreeKB, within group #{@groupName.inspect} ."
                    end
                  end
                else # implicit queries
                  # For query 'Document Id', no need to to do anything special
                  #    It will be automatically handled by the resource
                  if(@queryName != 'Document Id')
                    queriesHelper = @mongoKbDb.queriesHelper()
                    queriesHelper.modelsHelper = @mongoKbDb.modelsHelper()
                    @matchProps = queriesHelper.getMatchProps(@queryName, @collName)
                    #$stderr.debugPuts(__FILE__, __method__, "STATUS", "matching props:\n#{@matchProps.inspect}")
                  end
                end
              end
            end

            if(@statusName == :OK)
              # Validate & configure view-related info, if relevant.
              if(!@viewName.nil? and @repFormat != :TABBED_MULTI_PROP_NESTING)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Provided a viewName: #{@viewName.inspect}. Setting detailed=true and getting cursor for view." )
                @detailed = true
                # Make sure the view is a valid view and not something bogus
                viewsHelper = @mongoKbDb.viewsHelper()
                viewCursor = viewsHelper.coll.find({ "name.value" => @viewName})
                if(viewCursor and viewCursor.is_a?(Mongo::Cursor) and viewCursor.count > 0)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Found view doc for viewName #{@viewName.inspect}: #{viewCursor.class.inspect}\n\n#{viewCursor.inspect}\n\n" )
                  viewCursor.rewind!
                  @viewCursor = viewCursor
                else
                  # Check if its one of the implicit views
                  if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName))
                    @statusName = :"Bad Request"
                    @statusMsg = "NO_VIEW: The view: #{@viewName.inspect} is not defined in the KB: #{@kbName}"
                  else
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "viewName #{@viewName.inspect} is an implicit view name." )
                  end
                end
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "viewCursor at this point: #{@viewCursor.inspect}." )
              end
            end

            # Validate query related parameters
            if(@statusName == :OK)
              if(@propPaths =~ /\S/)
                @propPaths = @propPaths.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
              else
                @propPaths = nil
              end

              if(@propValues =~ /\S/)
                @propValues = @propValues.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
              else
                @propValues = nil
              end

              if(@matchOrderBy =~ /\S/)
                @matchOrderBy = @matchOrderBy.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
              else
                @matchOrderBy = nil
              end
              if((@propPaths and @propValues.nil?) or (@propValues and @propPaths.nil?) or (@propPaths and @propValues and (@propPaths.size != @propValues.size)))
                @statusName = :'Bad Request'
                @statusMsg = "BAD_PARAMS: you are using either one of the parameters - propPaths, propValues, or the sizes of these parameters are not equal."
              end
            end

            initStatus = @statusName
          end # initGroupAndKb
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @todo Pagination via "skip" and "limit" only work when using matchProp/matchVals and related type requests.
    #   Should work on just about ANY, but especially
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "BEGIN - get()")
      tt = Time.now
      initStatus = initOperation()
      $stderr.debugPuts(__FILE__, __method__, "TIME", "initOperation: #{Time.now - tt} secs")
      failedMultiTab = false
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        # @todo if public or subscriber, can get info
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@groupName:#{@groupName.inspect} ; @groupAccessStr=#{@groupAccessStr.inspect} ; @gbLogin=#{@gbLogin.inspect} ; READ_ALLOWED_ROLES (inheritied constant):\n\n#{JSON.pretty_generate(READ_ALLOWED_ROLES) rescue "null? what??"}\n\n")
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          # Add a payload entity and extract match* params
          # Previous match* params will be over written here
          # Note that generic params are not supported in a payload
          # If post-get combo mode is not active.
          if(@combinedParams.nil?)
            payload = parseRequestBodyForEntity("HashEntity")
            unless(payload.nil?)
              # payload present check for the entity and empty payloads
              if(payload.is_a?(BRL::Genboree::REST::Data::HashEntity) and payload.hash and payload.hash.empty?)
                initStatus = :"Not Implemented"
                @statusName = :"Not Implemented"
                @statusMsg = "EMPTY_PAYLOAD: The payload hash is empty and an empty payload is not supported."
              elsif(payload == :"Unsupported Media Type")
                initStatus = :"Unsupported Media Type"
                @statusName = :"Unsupported Media Type"
                @statusMsg = "BAD_PAYLOAD: The parameters in the payload does not accurately represent a HashEntity."
              else
                # get the match* params
                @payloadParams = payload.hash
                @matchMode = @payloadParams["matchMode"].to_s.strip if(@payloadParams.key?("matchMode"))
                @matchValue = @payloadParams['matchValue'].to_s.strip if(@payloadParams.key?("matchValue"))
                @matchProp = @payloadParams['matchProp'].to_s.strip if(@payloadParams.key?("matchProp"))
                if(@payloadParams.key?("matchValues"))
                 if(@payloadParams["matchValues"].is_a?(Array))
                   @matchValues = @payloadParams["matchValues"].join(",")
                 else
                   initStatus = :"Bad Request"
                   @statusName = :"Bad Request"
                   @statusMsg = "BAD_PARAMS: The parameter matchValues must be an array of elements. #{@payloadParams["matchValues"].inspect} is not valid"
                 end
                end
                if(@payloadParams.key?("matchProps"))
                 if(@payloadParams["matchProps"].is_a?(Array))
                   @matchProps = @payloadParams["matchProps"].join(",")
                 else
                   initStatus = :"Bad Request"
                   @statusName = :"Bad Request"
                   @statusMsg = "BAD_PARAMS: The parameter matchProps must be an array of elements. #{@payloadParams["matchProps"].inspect} is not valid"
                 end
                end
                @matchLogicOp = @payloadParams['matchLogicOp'].to_s.strip if(@payloadParams.key?("matchLogicOp"))
                # need to validate the matchParams here
                validateMatchParams() if(@statusName == :OK)
              end
            end
          end

          if(@statusName == :OK)
            # Get dataCollectionHelper to aid us
            dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            # Get a modelsHelper to aid us also
            modelsHelper = @mongoKbDb.modelsHelper()
            if(dataHelper and modelsHelper)
              @idPropName = dataHelper.getIdentifierName()
              # validate the matchOrderBy paths are indexed or not
              if(@matchOrderBy)
                modelDoc = modelsHelper.modelForCollection(@collName)
                model = modelDoc.getPropVal('name.model')
                begin
                  @matchOrderByDocPath = convertPropPaths( @matchOrderBy, modelsHelper, model, false, true )
                  idValuePath = modelsHelper.modelPath2DocPath(@idPropName, @collName)
                  @matchOrderByDocPath.each_key {|matchpath|
                    if((@matchOrderByDocPath[matchpath][:propDef].key?('index') and @matchOrderByDocPath[matchpath][:propDef]['index'] == true) or (@matchOrderByDocPath[matchpath][:docPath] == idValuePath))
                    else
                      @statusName = :'Bad Request'
                      @statusMsg = "BAD_PROP: One of the property paths provided for sorting #{@matchOrderBy ? @matchOrderBy.inspect : @matchOrderBy.inspect} is not indexed. Sorting of non indexed property is currently not supported"
                      break
                    end
                  }
                rescue BRL::Genboree::KB::KbError => err
                  $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                  @statusName = :'Bad Request'
                  @statusMsg = "BAD_PROP: one of the property paths provided for sorting #{@matchOrderBy ? @matchOrderBy.inspect : @matchOrderBy.inspect} is not valid for documents stored within #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} because they do not match the model for that collection. Double check spelling, case correctness, and location of the properties mentioned in the property path."
                end
              end

              if(@statusName == :OK)
                if(@transformationName)
                  @resp = transformColl()
                elsif(@queryName and @queryCursor)
                  @resp = queryCollection(dataHelper, modelsHelper)
                else
                  # Initialize before checking for cache
                  srcCollLastEditTime = nil
                  secNvPairs = {}
                  apiRecord = nil
                  # get the last edit time of the source collection
                  st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @collName)
                  # when the coll is empty the last edit time is nil
                  srcCollLastEditTime = st.lastEditTime().nil? ? st.timeOfKbFirstEdit() : st.lastEditTime()
                  # Get View Info
                  if(@viewName and @viewCursor)
                    viewsHelper = @mongoKbDb.viewsHelper()
                    viewVersionDoc = viewsHelper.getDocVersion(@viewName)
                    viewVersionDoc = BRL::Genboree::KB::KbDoc.new(viewVersionDoc)
                    viewVersion = viewVersionDoc.getPropVal('versionNum')
                    secNvPairs["viewVersion"] = viewVersion
                  end
                  # @nvPairs getting wiped out at the :postData state of the DeferableBody Class
                  nvPairs = Marshal.load(Marshal.dump(@nvPairs))
                  # make api cache path by merging both @payloadParams and @nvPairs
                  if(@payloadParams)
                    apiPairs = @payloadParams.merge(nvPairs)
                  else
                    apiPairs = nvPairs
                  end
                    apiCacheHelper = BRL::Genboree::REST::Helpers::ApiCacheHelper.new(@rsrcPath, apiPairs)
                  begin
                    apiRecord = apiCacheHelper.getapiCache(srcCollLastEditTime, secNvPairs)
                  rescue  => err
                    apiRecord = nil
                    $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                  end
                  if(apiRecord.nil? or apiRecord.empty? )
                    begin
                      begin
                        $stderr.debugPuts(__FILE__, __method__, "TIME", "COMPLETE - pre-mongo query set up from scratch - no cache (helpers, info, etc)")
                        docsCursor = findDocsCursor(dataHelper, modelsHelper)
                      rescue BRL::Genboree::KB::KbError => err
                        $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                        docCursor = nil
                      end
                      if(docsCursor.is_a?(Mongo::Cursor))
                        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Have a docsCursor resulting from our match* props." )
                        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "docsCursor.count reports #{docsCursor.count.inspect} entries found." )
                        # @todo make the process of adding metadata info for large amount of docs be efficient.
                        metadata = nil
                        if(@excludeMetadata == false)
                        # Get the maximum revision for the docs
                          docIds = []
                          docsCursor.each { |dd|
                            docIds << dd['_id']
                          }
                          metadata = dataHelper.getMetadata(docIds, @collName)
                          docsCursor.rewind!
                          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "metadata:\n#{metadata.inspect}" )
                        end
                        # Set up an object for streaming the data. Cannot send back response as one large payload since it could be massive depending on number of docs in KB.
                        # Also set up some of the attributes in the deferrable body class
                        #     for getting back data as a 'view' if requested.
                        # DeferrableKbDocsBody will figure out if the response is to be sent back as regular
                        #     or as one of the defined views, if given suitable info
                        # Note that we do NOT stream multi-tabbed prop nesting - we will deliver the documents as one large chunk
                        @resp.body = ''
                        
                        @resp.status = HTTP_STATUS_NAMES[:OK]
                        @resp['Content-Type'] = 'text/plain'
                        unless(@repFormat == :TABBED_MULTI_PROP_NESTING)
                          # Prevent the clearing of @mongoKbDb, that will be done when deferred streaming is finished
                          @mongoKbDb.doClear = false
                          # These opts are also available as accessors if you prefer
                          deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableKbDocsBody.new(
                            :docsCursor => docsCursor,
                            :detailed   => @detailed,
                            :idPropName => @idPropName,
                            :limit      => @limit,
                            :viewCursor => @viewCursor,
                            :viewName   => @viewName,
                            :gbEnvelope => @wrapInGenbEnvelope,
                            :model      => modelsHelper.modelForCollection(@collName),
                            :viewsHelper  => @mongoKbDb.viewsHelper,
                            :dataHelper => dataHelper,
                            :revision => (metadata ? metadata['revision'] : nil),
                            :format     => @repFormat,
                            :yield => true # REMOVE THIS WHEN SWITCH TO EM version
                          ) 
                          @resp.body = deferrableBody
                          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Deferrable body object has been set up. Handed off to @resp.body" )
                          @resp.body.addListener(:postData, Proc.new { |event, body|
                            if(body.cacheContent)
                              #insert into the cache record
                              begin
                                ttcache = Time.now
                                apiCacheHelper.putapiCache(body.cacheContent, srcCollLastEditTime, secNvPairs)
                                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Time to insert into cache: #{Time.now - ttcache} secs" )
                              rescue =>  err
                                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - #{err.message}")
                                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - #{err.backtrace}")
                              end
                            end
                          })
                          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Time from starting get to handing off deferrable class: #{Time.now - tt} secs" )
                        else
                          unless(docsCursor.count > MAX_DOCS_MULTI_TABBED_GET)
                            @resp.body = multiTabbedProcessing(docsCursor, modelsHelper.modelForCollection(@collName))
                            if(@resp.body.size < @genbConf.apiCacheMaxBytes.to_i) 
                              begin
                                insertSuccess = apiCacheHelper.putapiCache(@resp.body, srcCollLastEditTime, secNvPairs)
                              rescue  => err
                                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Cache record insert failed #{insertSuccess.inspect}" )
                                $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}" 
                              end
                            else
                              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - Size of the response - #{@resp.body.size} is not within the cache limit #{@genbConf.apiCacheMaxBytes.to_i}")
                            end
                          else
                            @statusName = :"Bad Request"
                            @statusMsg = "Refusing to process request because there are too many requested documents for the multi-tabbed format.  The maximum number of requested documents is #{MAX_DOCS_MULTI_TABBED_GET} and the total number of requested documents is #{docsCursor.count}"
                            failedMultiTab = true
                          end
                        end
                      else # no such path
                        @statusName = :'Bad Request'
                        @statusMsg = "BAD_PROP: one of the property paths provided #{@matchProps ? @matchProps.inspect : @matchProp.inspect} is not valid for documents stored within #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} because they do not match the model for that collection. Double check spelling, case correctness, and location of the properties mentioned in the property path. Have you perhaps provided a CSV list of properties to 'matchProp' instead of to 'matchProps'??"
                      end
                    rescue => err
                      unless(failedMultiTab)
                        @statusName = :'Not Found'
                        @statusMsg = "NO_MODEL: can't get document named #{@docName.inspect} because there does not appear to be a valid model available for data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
                      end
                      $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                    end
                  else # cache present return the cache
                    $stderr.debugPuts(__FILE__, __method__, "TIME", "Api response cache record found. RETURNING record from the CACHE")
                    @resp.body = ''
                    @resp.status = HTTP_STATUS_NAMES[:OK]
                    @resp['Content-Type'] = 'text/plain'
                    content = apiRecord.first['content']
                    @resp.body = content
                  end
                end
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: can't get document named #{@docName.inspect} because appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}, or at least there is no model for one. (Check spelling/case/etc of group and collections names; another cause could be some internal error/corruption)."
            end
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end #initStatus
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "END - get()")
      return @resp
    end

    # Process a PUT operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    # @note the following query string parameters affect the operation:
    #   [Boolean] @save whether or not to commit the payload to the database
    # if @allOrNothing=true, even one bad doc will result in the call failing
    # If @allOrNothing=false and there is at least one 'good' doc to update/insert, we will try to save it.
    # @todo use dch#saveDocs
    def put()
      begin
        $stderr.debugPuts(__FILE__, __method__, "TIME", "START - put()")
        initStatus = initOperation()
        respDoc = nil
        if(initStatus == :OK)
          @groupName = Rack::Utils.unescape(@uriMatchData[1])
          if(@req.env['CONTENT_LENGTH'] and (@req.env['CONTENT_LENGTH'].to_i > MAX_BYTES))
            @statusName = :"Bad Request"
            @statusMsg = "Refusing to process request because the payload exceeds byte limits: payload byte limit is #{MAX_BYTES} and the document count limit is #{MAX_DOCS}"
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
          # @todo if public or subscriber, can get info
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "READ_ALLOWED_ROLES=#{READ_ALLOWED_ROLES.inspect}")
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@groupAccessStr=#{@groupAccessStr.inspect}")
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@save=#{@save.inspect}")
          if(WRITE_ALLOWED_ROLES[@groupAccessStr] or (READ_ALLOWED_ROLES[@groupAccessStr] and !@save))
            # Get dataCollectionHelper to aid us
            dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            modelsHelper = @mongoKbDb.modelsHelper()
            if(dataHelper)
              # Parse the request payload (if any)
              # Also pass any entity-specific options (docType in this case)
              $stderr.debugPuts(__FILE__, __method__, "TIME", "  DONE - init, helper creation")
              # Check to make sure that domain column in doc matches model
              errMsg = ""
              if(@repFormat == :TABBED_MULTI_PROP_NESTING)
                errMsg = checkDomain(self.readAllReqBody(), modelsHelper.modelForCollection(@collName))
              end
              unless(errMsg.empty?)
                @statusName = :"Unsupported Media Type"
                @statusMsg = errMsg
                raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              end
              payload = parseRequestBodyForEntity(['KbDocEntityList', 'KbDocEntity'], { :docType => 'data'})
              $stderr.debugPuts(__FILE__, __method__, "TIME", "  DONE - parse request body")
              if(payload.size rescue nil)
                if(payload.size > MAX_DOCS)
                  @statusName = :"Bad Request"
                  @statusMsg = "Refusing to process request because the payload exceeds size limits: the payload byte limit is #{MAX_BYTES} and the document count limit is #{MAX_DOCS}"
                  raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
                end
              end
              if(payload.nil?) # empty payload
                @statusName = :'Bad Request'
                @statusMsg = "NO_PAYLOAD: No payload provided. You must provide a payload of KbDocEntityList type. "
              elsif(payload == :'Unsupported Media Type') # not correct payload content
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_PAYLOAD: the GenboreeKB docs you provided in the payload are not valid. Either the documents are empty or doesn't follow the property-based document structure. This is not allowed."
              elsif(payload.is_a?(Array) and payload[0] == :'Unsupported Media Type')
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_PAYLOAD: the GenboreeKB docs you provided in the payload are not valid. Either the documents are empty or doesn't follow the property-based document structure. This is not allowed."
              else # payload present
                # Need to do a batch insert after validating the payload
                docCount = 0
                # partition documents into valid and invalid with two data structures: payloadDocNames and badDocs (@todo would be helpful if they shared the same kind of keys...)
                payloadDocNames = BSON::OrderedHash.new() # map root identifier property value to a document
                badDocs = {} # map payload document index to BRL::Genboree::GenboreeError for invalid documents
                payload = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect, [payload]) unless(payload.is_a?(BRL::Genboree::REST::Data::KbDocEntityList))
                origDocs = []
                payload.doWrap = false
                index2id = Array.new(payload.size) # map payload document index to root identifier property
                # ------------------------------
                # Check to see if validation is to be skipped.
                # Warning: Validation should only be skipped if docs are being uploaded using the KB Bulk Upload tool.
                validate = true
                if(@nvPairs.key?('validate') and @nvPairs['validate'] =~ /false/i and @gbSysAuth)
                  validate = false
                  $stderr.debugPuts(__FILE__, __method__, "TIME", "  WARNING: No Validation will be done for this payload.")
                end

                # group admin only: modify internal autoID counters to the max in this payload
                if(@nvPairs.key?("autoAdjust") and @nvPairs["autoAdjust"].to_bool and @groupAccessStr == 'o')
                  docs = payload.collect { |docObj| docObj.doc }
                  propPathToMax = autoAdjust(@mongoKbDb, @collName, docs)
                end

                payload.each { |docObj|
                  begin
                    doc = docObj.doc
                    payloadDoc = BRL::Genboree::KB::KbDoc.new(doc) rescue nil
                    origDocs.push(payloadDoc.nil? ? payloadDoc : payloadDoc.dup())
                    if(!payloadDoc)
                      @statusName = :"Unsupported Media Type"
                      @statusMsg = "BAD_DOC: the GenboreeKB doc at position/index ##{docCount} you provided in the payload is not a valid property-based document."
                      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
                    end
                    if(validate)
                      # validate payloadDoc
                      # modify payloadDoc in place via contentGeneration framework, if needed
                      objectId = dataHelper.save(payloadDoc, @gbLogin, {:save => false})
                      if(!objectId.is_a?(BSON::ObjectId))
                        # then validation/content generation failed
                        # then objectId is actually a KbError, and dataHelper has set its @lastValidatorErrors
                        @statusName = :'Unsupported Media Type'
                        @statusMsg = "BAD_DOC: the GenboreeKB doc at position/index ##{docCount} you provided in the payload does not match the document model for the #{@collName.inspect} collection in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect}. Non-conforming documents are not permitted. Validator complained that:\n  - #{dataHelper.lastValidatorErrors.join("\n")}"
                        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
                      end
                    end
                    # associate doc with payload index
                    idPropName = dataHelper.getIdentifierName()
                    payloadDocName = payloadDoc.getPropVal(idPropName)
                    index2id[docCount] = payloadDocName

                    # verify no duplicate ids in payload
                    if(payloadDocNames.key?(payloadDocName))
                      @statusName = :'Unsupported Media Type'
                      @statusMsg = "BAD_PAYLOAD: There is more than 1 document with the same document name: #{payloadDocName.inspect} "
                      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
                    end
                    payloadDocNames[payloadDocName] = doc
                  rescue => err
                    if(err.is_a?(BRL::Genboree::GenboreeError))
                      badDocs[docCount] = err
                    else
                      $stderr.debugPuts(__FILE__, __method__, "API_ERROR", "#{err.message}\n#{err.backtrace.join("\n")}\n")
                      adminStr = ((@genbConf.is_a?(BRL::Genboree::GenboreeConfig) and @genbConf.send(:gbAdminEmail)) ? ": please contact the administrator at #{@genbConf.send(:gbAdminEmail)}." : "") rescue ""
                      statusMsg = "ERROR: Unhandled exception" << adminStr
                      badDocs[docCount] = BRL::Genboree::GenboreeError.new(:"Internal Server Error", statusMsg)
                    end
                  end
                  if(@allOrNothing and badDocs.key?(docCount))
                    err = badDocs[docCount]
                    raise err
                  end
                  docCount += 1
                }
                $stderr.debugPuts(__FILE__, __method__, "TIME", "  END - validate each payload doc") if(validate)

                id2index = {}
                index2id.each_index { |index|
                  id = index2id[index]
                  id2index[id] = index
                }
                # If a workingRevision is provided, match it against the maximum working revision of the existing docs
                workingRevisionMatched = true
                if(@workingRevision)
                  workingRevisionMatched = matchAgainstMaxRevisionForDocs(modelsHelper, dataHelper, payloadDocNames.keys)
                end
                if(payloadDocNames.empty?)
                  @statusName = :"Bad Request"
                  @statusMsg = "BAD_DOCS: All of the documents in your payload failed validation. See data.invalid for an explanation of each document's error"
                elsif(!workingRevisionMatched)
                  @statusName = :"Conflict"
                  @statusMsg = " WORKING_COPIES_OUT_OF_DATE: Your working copies of new documents are out-of-date. The documents have been changed since you last retrieved them. To prevent loss of new content or the saving of deleted content, your document changes have been rejected."
                else
                  # set @statusName/@statusMsg based on @save and badDocs
                  # modify badDocs, payloadDocNames if mongo save operation fails
                  if(@save)
                    # SAVE Docs
                    $stderr.debugPuts(__FILE__, __method__, "TIME", "  START - save docs via upsert")
                    status = upsertDocs( payloadDocNames, dataHelper)
                    $stderr.debugPuts(__FILE__, __method__, "TIME", "  END - save docs via upsert")
                    if(status != :OK)
                      # handle errors: interface says either an Array or Exception object
                      if(status.is_a?(Array))
                        # then a write error occurred, modify data structures and communicate to user
                        errIndex2Id = payloadDocNames.keys()
                        status.each { |errHash|
                          docId = errIndex2Id[errHash['index']]
                          payloadIdx0 = id2index[docId]
                          payloadDoc = payloadDocNames.delete(docId)
                          # @todo is this an okay message for user?
                          badDocs[payloadIdx0] = BRL::Genboree::GenboreeError.new(:"Internal Server Error", "#{errHash['code']} : #{errHash['errmsg']}")
                        }
                      elsif(status.is_a?(Exception))
                        err = status
                        $stderr.debugPuts(__FILE__, __method__, "API_ERROR", "Non-write error exception from bulkUpsert; message: #{err.message} ; backtrace:\n#{err.backtrace.join("\n")}")
                        @statusName = :"Internal Server Error"
                        @statusMsg = "WARNING: Unknown database state; try retrieving all document ID's to assess it"
                      else
                        $stderr.debugPuts(__FILE__, __method__, "API_ERROR", "The interface to bulkUpsert has changed without changing this method")
                      end
                      $stderr.debugPuts(__FILE__, __method__, "TIME", "Done uploading #{payloadDocNames.size} documents; #{badDocs.size} invalid")
                    else
                      @statusName = :'Created' # @todo OK if any of the payload docs already existed?
                      if(badDocs.empty?)
                        @statusMsg = "CREATED: The documents were inserted/updated."
                      else
                        @statusName = :"Partial Content"
                        @statusMsg = "PARTIAL_SUCCESS: Unfortunately, some of the documents could not be updated/inserted. See data.invalid for an explanation of each document's error"
                      end
                    end
                  else
                    @statusName = :"OK"
                    if(badDocs.empty?)
                      @statusMsg = "OK: The documents were validated and had content generation added and returned but were not committed to the database per your query \"save\"=#{@nvPairs['save']}"
                    else
                      @statusName = :"Partial Content"
                      @statusMsg = "PARTIAL_SUCCESS: Unfortunately, some of the documents could not have content generated (they are invalid). Your documents were not committed to the database per your query \"save\"=#{@nvPairs['save']}. See data.invalid for an explanation of each document's error"
                    end
                  end
                end
                $stderr.debugPuts(__FILE__, __method__, "TIME", "  START - construct response body")
                
                # begin constructing response
                respDoc = getItemWrapper()
                if(@statusName != :"Conflict")
                  # fill valid document components
                  validDocs = []
                  payloadDocNames.each_key { |docId|
                    validDoc = getValidItem(@detailed)
                    idx0 = id2index[docId]
                    validDoc.setPropVal("id", docId)
                    validDoc.setPropVal("id.payloadIndex", idx0)
                    if(@detailed)
                      payloadDoc = payloadDocNames[docId]
                      validDoc.setPropProperties("id.doc", payloadDoc)
                    end
                    validDocs.push(validDoc)
                  }
                  respDoc.setPropItems("docs.valid", validDocs)
                  # Add kbDoclinks to the table for the valid docs.
                  begin
                    kbDocLinks = BRL::Genboree::KB::LookupSupport::KbDocLinks.new(@collName, @mongoKbDb)
                    upsertedRecs = kbDocLinks.upsertFromKbDocs(payloadDocNames.values)
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Inserted #{upsertedRecs} for the collection - #{@collName}")
                  rescue => err
                    $stderr.debugPuts(__FILE__, __method__, "KbDocLinksTable_CREATE_ERROR", "Failed to add recs to the kbDocLinks table - #{err}")
                  end
                  # fill invalid document components
                  invalidDocs = []
                  badDocs.each_key { |idx0|
                    invalidDoc = getInvalidItem(@detailed)
                    id = index2id[idx0]
                    err = badDocs[idx0]
                    invalidDoc['id']['value'] = id # must circumvent setPropVal because id's can be nil (say provided doc doesnt have one)
                    invalidDoc.setPropVal("id.payloadIndex", idx0)
                    invalidDoc.setPropVal("id.msg", err.message)
                    if(@detailed)
                      payloadDoc = payload.array[idx0]
                      invalidDoc.setPropProperties("id.doc", payloadDoc.toStructuredData(wrap=false))
                    end
                    invalidDocs.push(invalidDoc)
                  }
                  # Write original payload docs (parsed to Ruby) to a temp area for debugging/investigation
                  if(@save)
                    logDocs(origDocs)
                  end
                  respDoc.setPropItems("docs.invalid", invalidDocs)
                end
                respEntity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respDoc)
                respEntity.model = modelsHelper.modelForCollection(@collName)
                # Set appropriate status
                if(@statusName != :"Conflict")
                  if(validDocs.empty?)
                    @statusName = :"Bad Request"
                    @statusMsg = "BAD_DOCS: All of the documents in your payload failed to upload. See data.invalid for an explanation of each document's error."
                  elsif(!invalidDocs.empty?)
                    @statusName = :"Partial Content"
                    @statusMsg = "PARTIAL_SUCCESS: Unfortunately, some of the documents could not be updated/inserted. See data.invalid for an explanation of each document's error"
                  end
                end
                respEntity.setStatus(@statusName, @statusMsg)
                configResponse(respEntity, @statusName) # set @resp
                $stderr.debugPuts(__FILE__, __method__, "TIME", "  END - construct response body")
              end # if(payloadDoc)
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: can't put a document named #{@docName.inspect} because there appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
            end # if(dataHelper)
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end # if(WRITE_ALLOWED_ROLES[@groupAccessStr])
        end # if(initStatus == :OK)
        # If something wasn't right, represent as error
      rescue => err
        logAndPrepareError(err)
      end
      if(respDoc.nil?)
        @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      end
      $stderr.debugPuts(__FILE__, __method__, "TIME", "END - put()")
      return @resp
    end

    # @todo delete multiple docs?
    def delete()
    end

    # ------------------------------------------------------------------
    # HELPERS
    # ------------------------------------------------------------------
    # Inserts/updates the passed docs
    # @param [Hash<String, Hash>] payloadDocNames mapping of document identifier property to
    #   the entire document
    # @param [BRL::Genboree::KB::Helpers::DataCollectionHelper] dataHelper a dataCollectionHelper
    #   instance used to perform the upsert
    # @return [:OK, String] :OK or an error message
    #   @see BRL::Genboree::KB::Helpers::AbstractHelper#bulkUpsert
    def upsertDocs(payloadDocNames, dataHelper)
      identProp = dataHelper.getIdentifierName()
      status = dataHelper.bulkUpsert(identProp, payloadDocNames, @gbLogin, { :maxDoc => MAX_DOCS })
      return status
    end
    
    def matchAgainstMaxRevisionForDocs(modelsHelper, dataHelper, docIds)
      retVal = false
      modelDoc = modelsHelper.modelForCollection(@collName)
      model = modelDoc.getPropVal('name.model')
      idPropName = dataHelper.getIdentifierName()
      idValuePath = modelsHelper.modelPath2DocPath(idPropName, @collName)
      propDef = modelsHelper.findPropDef(idPropName, model)
      propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
      matchProps = { idValuePath => propDomain }
      criteriaInfo = {}
      criteriaInfo[:prop] = matchProps
      criteriaInfo[:vals] = docIds
      cursor = dataHelper.cursorBySimplePropValsMatch(criteriaInfo)
      mDocIds = []
      if(cursor and cursor.is_a?(Mongo::Cursor))
        cursor.each { |doc|
          mDocIds << doc['_id']
        }
      end
      # All docs are new and do not exist in the database yet
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "mDocIds.size: #{mDocIds.size.inspect}")
      if(mDocIds.empty?)
        retVal = true
      else
        md = dataHelper.getMetadata(mDocIds, @collName)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "md: #{md.inspect}")
        if(@workingRevision == md['revision'].to_i)
          retVal = true
        end
      end
      return retVal
    end

    def findDocsCursor(dataHelper, modelsHelper)
      docCursor = nil
      # Common info, regardles of mode (in theory)
      # * actual path to the root value, in mongo terms
      idValuePath = modelsHelper.modelPath2DocPath(@idPropName, @collName)
      # * use projection if just getting list of docIds
      if(@detailed)
        outputProps = nil
        if(@nvPairs.key?("viewFields"))
          viewFields = @nvPairs["viewFields"].split(",")
          outputProps =[]
          viewFields.each { |vf|
            outputProps << modelsHelper.modelPath2DocPath(vf, @collName)  
          }
        end
      else # just names/ids
        outputProps = [ idValuePath ]
      end
      # * extraOpts, like :limit?
      extraOpts = {}
      if(@limit)
        extraOpts[:limit] = @limit
      end
      if(@skip)
        extraOpts[:skip] = @skip
      end
      extraOpts = nil if(extraOpts.empty?) # put to nil if we added no additional options (for safety and performance in called methods)

      # * sort by docID as default or use the prop
      if(@matchOrderBy and @matchOrderByDocPath)
        # Note is an array. Property order is important
        sortInfo = []
        @matchOrderBy.each{|matchorder| sortInfo << {@matchOrderByDocPath[matchorder][:docPath] => :asc } }
      else
        sortInfo = { idValuePath => :asc }
      end
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@matchValue: #{@matchValue.inspect}\t@matchValues: #{@matchValues.inspect}")
      # Are we doing some sort of filter/match/search?
      if(@matchValue or @matchValues)
        # We need the model (need the domains of the various @matchProps)
        modelDoc = modelsHelper.modelForCollection(@collName)
        model = modelDoc.getPropVal('name.model')
        if(@matchProps.nil? and @matchProp.nil?) # then no property specified to look in ; assume doc identifier
          docPath = idValuePath
          propDef = modelsHelper.findPropDef(@idPropName, model)
          propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
          matchProps = { idValuePath => propDomain }
        else # have list of props, or just one, to look in depending on scenario
          # Simple "clean" of @matchProps or @matchProp if it uses PropSelector paths
          #  to indicate where "items" arrays will be found. The matchProp(s) are assumed to
          #  be and indeed USE Mongo's approach which is a simple path along which it figures out if
          #  an Array is involved in the search or not. (Our library will expand such KbDoc paths to full
          #  Mongo doc paths by adding in the 'properties', 'items', and 'value' fields to the KbDoc path
          #  where appropriate. See convertPropPaths().)
          #  i.e. This PropSelector type path:
          #    AlleleSpecificCalls.donorsWithHetSNP.[].donor
          #  needs to be:
          #    AlleleSpecificCalls.donorsWithHetSNP.donor
          #  So we do that for convenience now (avoids an error if the PropSelector style path was provided).
          @matchProp.gsub!(/\.\[\s*\]/, "") if(@matchProp)
          if(@matchProps)
            #@matchProps.gsub!(/\.\[\s*\]/, "")
            @matchProps = @matchProps.split(",") if(@matchProps.is_a?(String))
            @matchProps.map!{ |prop|
              prop.gsub(/\.\[\s*\]/, "")
            }
          end
          # Translate prop names from model path to a doc path (i.e. with correct .value, .properties, .items)
          # * Also collect domain information to help search-builder
          # * Note: to support p1=v1,p2=v2,p3=v3 type searching, this method can now return an Array instead of a Hash.
          matchProps = convertPropPaths( (@matchProps or @matchProp), modelsHelper, model, (@matchProps and @matchValues) )
        end

        # * criteria info depends on senario
        # * do query and get cursor here too
        if(@matchValue)
          criteria = {
            :mode     => @matchMode,
            :props    => matchProps,
            :val      => @matchValue,
            :logicOp  => @matchLogicOp
          }
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get docCursor using propS and val using:\n  criteria:\n    #{criteria.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
          docCursor = dataHelper.cursorBySimplePropsValMatch(criteria, outputProps, sortInfo, extraOpts)
        elsif(@matchProps and @matchValues) # then we have p1=v1, p2=v2, p3=v3 kind of query
          criteria = {
            :mode     => @matchMode,
            :props    => matchProps,
            :vals     => @matchValues,
            :logicOp  => @matchLogicOp
          }
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get docCursor using prop and valS using:\n  criteria:\n    #{criteria.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
          docCursor = dataHelper.cursorBySimplePropsValsMatch(criteria, outputProps, sortInfo, extraOpts)
        else # @matchValues
          criteria = {
            :mode => @matchMode,
            :prop => matchProps,
            :vals => @matchValues
          }
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get docCursor using prop and valS using:\n  criteria:\n    #{criteria.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
          docCursor = dataHelper.cursorBySimplePropValsMatch(criteria, outputProps, sortInfo, extraOpts)
        end

        # ------------------------------------------------------------------
        # REMOVED HACK. Now have auto-casting. See explanation in comment:
        # Make another request in case query returned nothing with domain forced to string.
        ## This is basically a hack to allow searching of identifier values that have int type domain but have string values.
        ## Remove this extra search when auto casting is implemented.
        ## @todo: remove this!!
        #if(docCursor.count == 0 and @matchProps.nil? and @matchProp.nil? and propDomain != 'string')
        #  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Reattempting query with domain forced to string")
        #  matchProps = { idValuePath => 'string' }
        #  if(@matchValue)
        #    criteria = {
        #      :mode     => @matchMode,
        #      :props    => matchProps,
        #      :val      => @matchValue,
        #      :logicOp  => @matchLogicOp
        #    }
        #    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get docCursor using propS and val using:\n  criteria:\n    #{criteria.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
        #    docCursor = dataHelper.cursorBySimplePropsValMatch(criteria, outputProps, sortInfo)
        #  else # @matchValues
        #    criteria = {
        #      :mode => @matchMode,
        #      :prop => matchProps,
        #      :vals => @matchValues
        #    }
        #    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get docCursor using prop and valS using:\n  criteria:\n    #{criteria.inspect}\n  outputProps: #{outputProps.inspect}\n  sortInfo:\n    #{sortInfo.inspect}\n\n")
        #    docCursor = dataHelper.cursorBySimplePropValsMatch(criteria, outputProps, sortInfo)
        #  end
        #end
        # ------------------------------------------------------------------
      else # get them all; ugh
        # @todo skip/limit support?
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "About to get ALL docs. Ugh. Is this correct?")
        tt = Time.now
        docCursor = dataHelper.allDocs(:cursor, outputProps, sortInfo, extraOpts)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Got cursor for all docs: #{Time.now - tt} secs")
      end
      return docCursor
    end

    # Method to log the original payload that was uploaded
    # @param [Array] invalidDocs Array with a list of invalid docs
    def logDocs(origDocs)
      grpRecs = dbu.selectGroupByName(@groupName)
      groupId = grpRecs.first['groupId']
      kbId = dbu.selectKbByNameAndGroupName(@kbName, @groupName).first['id']
      kbRootDir = @genbConf.gbKbDocsUploadRootDir
      timeStr = CGI.escape(Time.now)
      uniq = rand(10_000)
      login = CGI.escape(@gbLogin)
      loggingDir = "#{kbRootDir.chomp('/')}/grp/#{groupId}/kb/#{kbId}/#{CGI.escape(@collName)}/"
      `mkdir -p #{loggingDir}`
      exitObj = $?.dup()
      if(exitObj.exitstatus != 0)
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Could not create directory for logging valid/invalid docs: #{loggingDir}.\nCommand exited with status code: #{exitObj.exitstatus}")
      end
      fileName = "#{CGI.escape(@gbLogin)}-#{timeStr}-#{uniq}.json"
      ff = File.open("#{loggingDir}#{fileName}", 'w')
      ff.print(JSON.pretty_generate(origDocs, { :max_nesting => 5000 }))
      ff.close()
    end

    # Converts the KbDoc paths in @matchProps@ to full Mongo-paths with help of the Model.
    #   At same time, collects the DOMAIN information for the property so it's available to things
    #   using the full-mongo-paths (like simple query methods). Can return EITHER a {Hash} of
    #   full-prop-paths mapped to domain, which is the default but doesn't support paths appearing more
    #   than once, OR can return an {Array} of such {Hash}es, which each property in @matchProp@ getting its
    #   own 1-key {Hash} in that {Array}. The latter is useful when a property may appear more than once and
    #   regardless is *required* if the property order in @matchProps@ must be maintained as it must for
    #   p1=v1,p2=v2,p3=v3 type searching.
    # @param [Array<String>] matchProps The array of KbDoc property paths to convers and get domain info for.
    # @param [BRL::Genboree::KB::Helpers::ModelsHelper] modelsHelper A fully configured {BRL::Genboree::KB::Helpers::ModelsHelper}
    #   which can answer questions about the relevant Collection.
    # @param [Hash] model The model for the collection.
    # @param [Boolean] returnArray Indicating whether to return the info as simple Hash or an Array of Hashes because order is important
    #   and/or a property path can appear more than once.
    def convertPropPaths(matchProps, modelsHelper, model, returnArray=false, returnPropDef=false)
      retVal = ( returnArray ? [] : {} )
      matchProps = [ matchProps ] unless(matchProps.acts_as?(Array))
      matchProps.each { |path|
        propDomain = 'string'
        docPath = modelsHelper.modelPath2DocPath(path, @collName)
        propDef = modelsHelper.findPropDef(path, model)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "\n  path: #{path.inspect}\n  docPath: #{docPath.inspect}\n  propDef:\n#{propDef.inspect}\n  domain: #{propDef ? propDef['domain'].inspect : "N/A (nil propDef!)"}")
        if(propDef)
          propDomain = (propDef['domain'] or 'string')
        end
        if(returnArray)
          retVal << { docPath => propDomain }
        elsif(returnPropDef)
          propDef = propDef ? propDef : {}
          retVal[path] = {}
          retVal[path][:docPath] = docPath
          retVal[path][:propDef] = propDef
        else
          retVal[docPath] = propDomain
        end
      }
      return retVal
    end

    # For the PUT response, return a property-oriented document that distinguishes between
    #   items that were saved successfully and those that could not be saved.
    # @return [Hash] a property-oriented document for the PUT response
    # @see getValidItem and getInvalidItem
    def getItemWrapper()
      BRL::Genboree::KB::KbDoc.new( {
        "docs" => {
          "value" => "",
          "properties" => {
            "valid" => {
              "items" => []
            },
            "invalid" => {
              "items" => []
            }
          }
        }
      } )
    end

    # Return a new property-oriented document that can be used in an item list for valid documents
    # @param [Boolean] detailed whether or not we should return a detailed item document or just
    #   a simple one
    # @see getItemWrapper
    def getValidItem(detailed=false)
      doc = BRL::Genboree::KB::KbDoc.new( {
        "id" => {
          "value" => "",
          "properties" => {
            "payloadIndex" => {
              "value" => ""
            }
          }
        }
      } )
      if(detailed)
        doc['id']['properties']['doc'] = {}
      end
      return doc
    end

    # Return a new property-oriented document that can be used in an item list for invalid documents
    # @param [Boolean] detailed whether or not we should return a detailed item document or just
    #   a simple one
    # @see getItemWrapper
    def getInvalidItem(detailed=false)
      doc = BRL::Genboree::KB::KbDoc.new( {
        "id" => {
          "value" => "",
          "properties" => {
            "payloadIndex" => {
              "value" => ""
            },
            "msg" => {
              "value" => ""
            }
          }
        }
      } )
      if(detailed)
        doc['id']['properties']['doc'] = {}
      end
      return doc
    end

    # This method will process a group of documents into the multi-tabbed format
    # @param [Mongo::Cursor] docsCursor a Mongo::Cursor that will contain our documents
    # @param [KbDoc] model Current model associated with documents
    # @return [String] multi-tabbed format of documents
    def multiTabbedProcessing(docsCursor, model)
      # Grab current version number for model
      host = @genbConf.machineName
      path = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/ver/HEAD"
      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, path, @userId)
      apiCaller.initInternalRequest(@rackEnv, genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get({:coll => @collName, :kb => @kbName, :grp => @groupName})
      resp = apiCaller.parseRespBody
      versionNum = resp["data"]["versionNum"]["value"]
      # Set up header lines
      headerLines = ""
      headerLines << "##PRODUCED ON: #{Time.now.rfc822}\n"
      headerLines << "##OBTAINED FROM: #{@rsrcURI}\n"
      basedOnModel = @rsrcURI.slice(0..(@rsrcURI.index("/docs"))) << "model/ver/#{versionNum}"
      headerLines << "##BASED ON MODEL/SCHEMA: #{basedOnModel}\n"
      currentModel = @rsrcURI.slice(0..(@rsrcURI.index("/docs"))) << "model"
      headerLines << "##CURRENT MODEL/SCHEMA: #{currentModel}\n"
      headerLines << "##CURRENT DOCS VALIDATION URL: #{@rsrcURI}&save=false\n"
      # Grab all documents
      totalDocs = []
      #docsCursor.rewind!
      docsCursor.each { |doc|
        totalDocs.push(doc)
      }
      unless(@detailed)
        totalDocs.map! { |doc|
          oldDoc = BRL::Genboree::KB::KbDoc.new(doc)
          newDoc = BRL::Genboree::KB::KbDoc.new()
          newDoc.setPropVal(@idPropName, oldDoc.getPropVal(@idPropName))
          doc = newDoc.to_serializable()
        }
      end
      # Produce new multi-tabbed file
      producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(model)
      multiTabbedDoc = producer.processMultipleDocs(totalDocs)
      # Header lines go in front and multi-tabbed contents come next.  Then, we return our final document into @resp.body
      finalDoc = headerLines << multiTabbedDoc
      return finalDoc
    end

    # Method which checks a given set of docs (in multi-column tabbed format) to see whether domain column associated with docs matches the domain column in model
    # @param [String] docs set of documents in tabbed-delimited format
    # @param [KbDoc] model model associated with collection (to which the docs are being submitted)
    # @return [String] error message (empty if no error)
    def checkDomain(docs, model)
      # Error message - left blank if no error occurs
      errMsg = ""
      # Generate a nested pathed model (will contain correct model)
      modelProducer = BRL::Genboree::KB::Producers::NestedTabbedModelProducer.new(model)
      nestedPathedModel = modelProducer.produce(model, true)
      # Grab index for property path column and for domain column
      propIndexModel = nestedPathedModel[0].split("\t").index("#name")
      domainIndexModel = nestedPathedModel[0].split("\t").index("domain")
      # Create hash that sets property path -> domain
      domainHashNestedPath = {}
      nestedPathedModel.each { |line|
        domainHashNestedPath[line.split("\t")[propIndexModel]] = line.split("\t")[domainIndexModel]
      }
      # Split the multi-column tabbed doc by line
      docsLines = docs.split("\n")
      # Grab index for property path column in docs - if it doesn't exist, error
      propIndexDocs = docsLines[0].split("\t").index("#property") rescue nil
      unless(propIndexDocs)
        errMsg = "We were unable to find the \"#property\" column\nin your submitted multi-column doc."
      else
        # Grab index for domain column in docs - if it doesn't exist, error
        domainIndexDocs = docsLines[0].split("\t").index("domain") rescue nil
        unless(domainIndexDocs)
          errMsg = "We were unable to find the \"domain\" column\nin your submitted multi-column doc."
        else
          # Traverse each line of the multi-column tabbed doc
          docsLines.each { |line|
            # Split current line into individual elements
            currentTokens = line.split("\t")
            # Skip the first line since it's a header
            next if(currentTokens[propIndexDocs] == "#property")
            # Check to see if the domain for the current line in multi-column tabbed doc is the same as the domain for that property path in the model
            unless(currentTokens[domainIndexDocs] == domainHashNestedPath[currentTokens[propIndexDocs]])
              errMsg += "#{currentTokens[propIndexDocs]} does not have valid domain.\nDomain in docs: #{currentTokens[domainIndexDocs]}\nDomain in model: #{domainHashNestedPath[currentTokens[propIndexDocs]]}\n"
            end
          }
        end
      end
      return errMsg
    end

    # Method which uses the query document to query a collection
    # @param [BRL::Genboree::KB::Helpers::DataCollectionHelper] dataHelper a dataCollectionHelper
    # @param [BRL::Genboree::KB::Helpers::ModelsHelper] modelsHelper a modelHelper
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    def queryCollection(dataHelper, modelsHelper)
      queriesHelper = @mongoKbDb.queriesHelper()
      viewsHelper = @mongoKbDb.viewsHelper()
      # Check if cache is present
      srcCollLastEditTime = nil
      apiRecord = nil
      secNvPairs = {}
      # get the last edit time of the source collection
      st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @collName)
      srcCollLastEditTime = st.lastEditTime().nil? ? st.timeOfKbFirstEdit() : st.lastEditTime()

      queryVersionDoc = queriesHelper.getDocVersion(@queryName)
      queryVersionDoc = BRL::Genboree::KB::KbDoc.new(queryVersionDoc)
      queryVersion = queryVersionDoc.getPropVal('versionNum')
      secNvPairs["queryVersion"] = queryVersion

      if(@viewName and @viewCursor)
        viewVersionDoc = viewsHelper.getDocVersion(@viewName)
        viewVersionDoc = BRL::Genboree::KB::KbDoc.new(viewVersionDoc)
        viewVersion = viewVersionDoc.getPropVal('versionNum')
        secNvPairs["viewVersion"] = viewVersion
      end
      nvpairs = Marshal.load(Marshal.dump(@nvPairs))
      $stderr.debugPuts(__FILE__, __method__, "TIME", "Found @nvpairs - #{nvpairs.inspect}")
      apiCacheHelper = BRL::Genboree::REST::Helpers::ApiCacheHelper.new(@rsrcPath, nvpairs)
      begin
        apiRecord = apiCacheHelper.getapiCache(srcCollLastEditTime, secNvPairs) 
      rescue => err
        $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
        apiRecord.nil?
      end
      if(apiRecord.nil? or apiRecord.empty?)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "No CACHE - query fresh")
        queryDoc = nil
        newQueryDoc = nil
        # Get the query document from the cursor
        # queryCursor count is > 0 , checked elsewhere
        queryDoc = BRL::Genboree::KB::KbDoc.new(@queryCursor.first)
        if(queryDoc)
          begin
            # dynamic replacement of the query document
            if(@propPaths and @propValues)
              queriesHelper = @mongoKbDb.queriesHelper()
              newQueryDoc = queriesHelper.makeNewQueryDoc(queryDoc, @propPaths, @propValues)
            else
              newQueryDoc = queryDoc
            end
            docs = []
            queryOpts = {}
            qrCount = nil
            begin
              abQuery = BRL::Genboree::KB::Queries::AbstractQueries.new(newQueryDoc, @mongoKbDb)
              queryOpts[:view] = @viewName if(@viewName and @viewCursor)
              queryOpts[:matchOrderBy] = @matchOrderBy if(@matchOrderBy)
              if(@repFormat == :TABBED_MULTI_PROP_NESTING) # get the count first
                qrCount = abQuery.getQueriedDocCount(@collName)
              else
                qrAggCursor = abQuery.queryColl(@collName, queryOpts)
              end
            rescue => err
              $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
              qrAggCursor = nil
            end
            if((qrAggCursor and qrAggCursor.is_a?(Mongo::Cursor)) or qrCount)
              @idPropName = dataHelper.getIdentifierName()
              @resp.body = ''
              @resp.status = HTTP_STATUS_NAMES[:OK]
              @resp['Content-Type'] = 'text/plain'
              unless(@repFormat == :TABBED_MULTI_PROP_NESTING)
                # Need to defer @mongoKbDb clear into future after deferred work is done. Can't do immediate like normal.
                @mongoKbDb.doClear = false
                # These opts are also available as accessors if you prefer
                deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableKbDocsBody.new(
                  :docsCursor => qrAggCursor,
                  :detailed   => @detailed,
                  :idPropName => @idPropName,
                  :limit      => @limit,
                  :viewCursor => @viewCursor,
                  :viewName   => @viewName,
                  :model      => modelsHelper.modelForCollection(@collName),
                  :viewsHelper  => @mongoKbDb.viewsHelper,
                  :dataHelper => dataHelper,
                  :format     => @repFormat,
                  :yield => true # REMOVE THIS WHEN SWITCH TO EM version
                )
                @resp.body = deferrableBody
                @resp.body.addListener(:postData, Proc.new { |event, body|
                  if(body.cacheContent)
                    # insert into the cache record
                    begin
                      insertSuccess = apiCacheHelper.putapiCache(body.cacheContent, srcCollLastEditTime, secNvPairs) 
                    rescue  => err
                      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Cache record insert failed #{insertSuccess.inspect}" )
                      $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                     end
                  end
                })
              else
               unless(abQuery.queriedDocCount)
                 @statusName = :"Internal Server Error"
                 @statusMsg = "Failed to get queried number of documents for the Genboree KB collection '#{@collName}' with the query document '#{@queryName}'. Details: #{abQuery.queryErrors.inspect}. Count is necessary to proceed with #{@repFormat}"
               else
                 if(abQuery.queriedDocCount and abQuery.queriedDocCount < MAX_DOCS_MULTI_TABBED_GET)
                   qrAggCursor = abQuery.queryColl(@collName, queryOpts)
                   @resp.body = multiTabbedProcessing(qrAggCursor, modelsHelper.modelForCollection(@collName))
                   if(@resp.body.size < @genbConf.apiCacheMaxBytes.to_i) 
                     begin
                       insertSuccess = apiCacheHelper.putapiCache(@resp.body, srcCollLastEditTime, secNvPairs)
                     rescue => err
                      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Cache record insert failed #{insertSuccess.inspect}" )
                      $stderr.puts "ERROR: #{@statusMsg}\n    - ERROR CLASS: #{err.class}\n    - ERROR MSG: #{err.message}\n    - ERROR TRACE:\n#{err.backtrace.join("\n")}"
                     end
                   end

                 else
                   @statusName = :"Bad Request"
                   @statusMsg = "Refusing to process request because there are too many requested documents for the multi-tabbed format.  The maximum number of requested documents is #{MAX_DOCS_MULTI_TABBED_GET} and the total number of requested documents is #{abQuery.queriedDocCount}"
                  #failedMultiTab = true
                 end
                end
              end
            else
              @statusName = :"Internal Server Error"
              @statusMsg = "Failed to query the Genboree KB collection '#{@collName}' with the query document '#{@queryName}'. Details: #{abQuery.queryErrors.inspect}."
            end
          rescue => err
            @statusName = :"Internal Server Error"
            @statusMsg = "Failed to query the Genboree KB collection '#{@collName}' with the query document '#{@queryName}'. #{err.message}\n."
          end
        end
        else # cache present  and just return the content
          $stderr.debugPuts(__FILE__, __method__, "TIME", "RETURNING record from the cache")
          @resp.body = ''
          @resp.status = HTTP_STATUS_NAMES[:OK]
          @resp['Content-Type'] = 'text/plain'
          content = apiRecord.first['content']
          @resp.body = content
        end
      return @resp
    end

   # Method that transforms all the documents in a collection
   # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
   def transformColl()
     transformDocAndVersion = nil
     transformDocAndVersion =  getTransformationDocAndVersionNum()
     if(transformDocAndVersion and @statusName == :OK)
       apiCacheHelper = BRL::Genboree::REST::Helpers::ApiCacheHelper.new(@rsrcPath, @nvPairs)
       apiCacheRec = nil
       apiCacheContent = nil
       st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, @collName)
       srcCollLastEditTime = st.lastEditTime().nil? ? st.timeOfKbFirstEdit() : st.lastEditTime()
       additionalAttValPairs = {} 
          begin
            # get the last edit time of all the associated collection in the transformation doc
            # for that need to get the transformation class instance.
            # Note: not doing the actual transformation here, just getting some background information
            collTransformer = BRL::Genboree::KB::Transformers::CollToDocTransformWithkbDocLinks.new(transformDocAndVersion["doc"], @mongoKbDb)
            associatedColls = collTransformer.associatedColls rescue []
            associatedColls.each {|aColl|
              next if(aColl ==  @collName)
              st = BRL::Genboree::KB::Stats::CollStats.new(@mongoKbDb, aColl)
              additionalAttValPairs[aColl] = st.lastEditTime().nil? ? st.timeOfKbFirstEdit() : st.lastEditTime()
            }
            additionalAttValPairs["transformVersion"] = transformDocAndVersion["versionNum"]
            apiCacheRec = apiCacheHelper.getapiCache(srcCollLastEditTime, additionalAttValPairs)
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_GET_ERROR - #{err.message} \n #{err.backtrace}")
          end
          if(apiCacheRec and !apiCacheRec.empty?)
            # has cache rec, get it
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "CACHE rec found")
            apiCacheContent = apiCacheRec.first["content"]
            if(@repFormat == :HTML or @repFormat == :SMALLHTML)
              @resp.body = apiCacheContent
              @resp['Content-Type'] = 'text/html'
              @resp.status = HTTP_STATUS_NAMES[:OK]
            else
              bodyData = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, JSON(apiCacheContent))
              @statusName = configResponse(bodyData)
            end
          else  
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "No CACHE found - transforming fresh")
            # transform fresh
            begin
              collTransformer = BRL::Genboree::KB::Transformers::CollToDocTransformWithkbDocLinks.new(transformDocAndVersion["doc"], @mongoKbDb)
              collTransformed = collTransformer.doTransform(@collName)
              if(collTransformed)
                if(@repFormat == :HTML or @repFormat == :SMALLHTML)
                  begin
                    bodyData = collTransformer.getHtmlFromJsonOut(collTransformer.transformedDoc, @repFormat, {:onClick => @onClick, :showHisto => @showHisto})
                    apiCon = bodyData
                  rescue => err
                    @statusName = :'Internal Server Error'
                    @statusMsg = "GRID_ERROR: Failed to retrieve grid table for the transformation rules doc #{@transformationName}"
                  end
                  @resp.body = bodyData
                  @resp['Content-Type'] = 'text/html'
                  @resp.status = HTTP_STATUS_NAMES[:OK]
                else # format default is json
                  bodyData = BRL::Genboree::REST::Data::RawDataEntity.new(@connect, collTransformer.transformedDoc)
                  apiCon = collTransformer.transformedDoc.to_json
                  @statusName = configResponse(bodyData)
                end
               # put cache
               if(apiCon.size < @genbConf.apiCacheMaxBytes.to_i)
                 begin
                   apiCacheHelper.putapiCache( apiCon, srcCollLastEditTime, additionalAttValPairs )
                 rescue =>  err
                   $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - #{err.message}\n#{err.backtrace}")
                 end
               else
                   $stderr.debugPuts(__FILE__, __method__, "DEBUG", "API_CACHE_PUT_ERROR - Size of the response - #{apiCon.size} is not within the cache limit #{@genbConf.apiCacheMaxBytes.to_i}")
               end
             else
               @statusName = :"Bad Request"
               @statusMsg = "Failed to transform the Genboree KB collection - #{@collName}. Details: #{collTransformer.transformationErrors.inspect}"
             end
           rescue => err
             @statusName = :"Bad Request"
             @statusMsg = "Failed to transform the Genboree KB collection '#{@collName}' with the transformation Rules document '#{@transformationName}'. Rules Document invalid? #{err.message}\n."
           end
       end
     end
     return @resp
   end

    # Update database counter for a set of docs
    # @param [BRL::Genboree::KB::MongoKbDatabase] mdb
    # @param [String] collName
    # @param [Array<Hash>] docs
    # @return [Hash] map of prop path to old counter
    # @todo move this -- need some area for kb-lib aware functions (kb/util has no dependencies)
    # @todo allOrNothing/atomicity?
    def self.autoAdjust(mdb, collName, docs)
      rv = {}
      # setup
      dvClass = BRL::Genboree::KB::Validators::DocValidator
      modelValidator = BRL::Genboree::KB::Validators::ModelValidator.new()
      modelsHelper = mdb.modelsHelper()
      mdh = mdb.collMetadataHelper()

      # get doc maxes on best effort @see BRL::Genboree::KB::Validators::DocValidator.mapAutoIdPathToMaxInDocs
      modelDocWrap = modelsHelper.modelForCollection(collName)
      modelDoc = modelDocWrap.getPropVal("name.model")
      flatModel = modelsHelper.flattenModel(modelDoc, :format => :propSelector)
      autoIdPropToMatcher = dvClass.mapAutoIdIncPathToMatcher(flatModel, modelValidator)
      # @note if docs are invalid then propPaths here will map to 0 -- it may be desirable to @todo print which ones are 0 to stderr
      propPathToDocsMax = dvClass.mapAutoIdPathToMaxInDocs(autoIdPropToMatcher, docs)

      # update database maxes
      # @todo could be more efficient with a single db query, also prevents atomicity issues like
      #   one update failing and others succeeding
      propPathToDocsMax.each_key { |propPath|
        counterVal = propPathToDocsMax[propPath]
        oldCounter = mdh.setCounterToMax(collName, propPath, counterVal)
        if(oldCounter.nil?)
          $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Could not update counter for collection #{collName.inspect} propPath #{propPath.inspect}")
        end
        rv[propPath] = oldCounter
      }
      return rv
    end
    def autoAdjust(mdb, collName, docs)
      self.class.autoAdjust(mdb, collName, docs)
    end


    # Get the transformation rules document and the version number
    # @return [Hash] retVal hash of transformation document and the version number
    def getTransformationDocAndVersionNum()
      retVal = {}
      versionDoc = nil
      trUrlValid = true
      path = nil
      # Could be a transformation url
      trUrl = URI.parse(@transformationName) rescue nil
      if(trUrl and trUrl.scheme)
        trPath = trUrl.path
        trHost = trUrl.host
        patt = KbTransform.pattern()
        if(trHost and trPath =~ patt)
          apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(trHost, trPath, @userId)
        else
          trUrlValid = false
        end
      else # is a document ID
        host = @genbConf.machineName
        path = "/REST/v1/grp/#{CGI.escape(@groupName)}/kb/#{CGI.escape(@kbName)}/trRulesDoc/#{CGI.escape(@transformationName.strip())}"
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(host, path, @userId)
      end
      if(trUrlValid)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = apiCaller.parseRespBody
        if(apiCaller.succeeded?)
          retVal["doc"] = apiCaller.apiDataObj
        else
          retVal = nil
          @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
          @statusMsg = apiCaller.apiStatusObj['msg']
        end
        if(@statusName == :OK)
          trvPath = nil
          trvHost = nil
          # get the version
          if(path)
            trvPath = path
            trvHost = host
          else
            trvPath = trPath
            trvHost = trHost
          end
            apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(trvHost, "#{trvPath}/ver/HEAD?versionNumOnly=true", @userId)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.get()
            resp = apiCaller.parseRespBody
            if(apiCaller.succeeded?)
              retVal["versionNum"] = apiCaller.apiDataObj["number"]
            else
              retVal = nil
              @statusName = apiCaller.apiStatusObj['statusCode'].to_sym
              @sctatusMsg = apiCaller.apiStatusObj['msg']
            end
         end
      else
        retVal = nil
        @statusName = :"Bad Request"
        @statusMsg = "INVALID_TRANSFORMATION_URL: The URL #{@transformationName.inspect} is invalid. It either has no valid host or a valid trRulesDoc resource path."
      end
      return retVal
    end

    # This method validates the match* parameters and the combinations with which matchProps/matchProp
    # matchValues/matchValue are used. Used in #initOperation and #get when there are match* params
    # retreived via a payload
    def validateMatchParams()
      matchParamsValid = true
      # Clean up filters and make faster testing
      @matchProp = nil unless(@matchProp =~ /\S/)
      @matchValue = nil unless(@matchValue =~ /\S/)
      @matchMode = nil unless(@matchMode =~ /\S/)
      @matchLogicOp = nil unless(@matchLogicOp =~ /\S/)
     
      if(@matchProps =~ /\S/)
        # Protect escaped , actually in the names (i.e. not delimiter)
        # - restore back as just plain , in the items of the split list
        @matchProps = @matchProps.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
      else
        @matchProps = nil
      end
      if(@matchValues =~ /\S/)
        # Protect escaped , actually in the names (i.e. not delimiter)
        # - restore back as just plain , in the items of the split list
        @matchValues = @matchValues.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
      else
        @matchValues = nil
      end
      # Sanity checks on filter combos
      formats = []
      BRL::Genboree::REST::Data::KbDocEntity::FORMATS.each {|format| formats.push(format.to_s.downcase) }
      # Sanity checks.
      if( ( @matchProps  and @matchProp ) or ( @matchValues and @matchValue ) )
        @statusName = :'Bad Request'
        @statusMsg = "BAD_PARAMS: inappropriate combination of 'match' related parameters. Either use: (1) 'matchProps' + 'matchValue' to search one or more properties which may contain the value, or (2) 'matchProp' + 'matchValues' to search a property for one of several possible values, or (3) 'matchProps' + 'matchValues' to search using specific prop<=>value combinations. Currently, no other combination is supported."
      elsif( (@matchProps and @matchValue.nil? and @matchValues.nil?) or (@matchProp and @matchValues.nil? and @matchValue.nil?) or (@matchMode and @matchValue.nil? and @matchValues.nil?) )
        @statusName = :'Bad Request'
        @statusMsg = "BAD_PARAMS: you are using search/match modifiers such as 'matchProps', 'matchProp', and/or 'matchMode' but have not supplied the corresponding 'matchValue' or 'matchValues' parameter. This makes no sense."
      elsif(!BRL::Genboree::REST::Data::KbDocEntity::FORMATS.include?(@repFormat) and @repFormat != :HTML and @repFormat != :SMALLHTML)
        @statusName = :"Not Implemented"
        @statusMsg = "Supported formats include: #{formats.join(",")}"
      elsif(@reqMethod.to_s.upcase == "PUT" and @repFormat == :TABBED_PROP_PATH)
        @statusName = :"Not Implemented"
        suppFormats = formats - ['tabbed_prop_path']
        @statusMsg = "Supported formats include: #{suppFormats.join(",")}"
      elsif(!BRL::Genboree::REST::Data::KbDocEntity::FORMATS.include?(@repFormat) and @repFormat != :HTML and @repFormat != :SMALLHTML)
        @statusName = :"Bad Request"
        @statusMsg = "Supported formats include: #{formats.join(",")}"
      end # Done validations 
      # If fine thus far, configure @match* instance variables
      if(@statusName == :OK)
        @matchMode    = ( @matchMode ? @matchMode.downcase.to_sym : :full )
        @matchLogicOp = ( @matchLogicOp ? @matchLogicOp.downcase.to_sym : :or )
        # Sanity checks on filter
        if( (@matchMode != :full and @matchMode != :prefix and @matchMode != :keyword and @matchMode != :exact) )
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: you have provided the 'matchMode' parameter but your value of #{@matchMode.inspect} is not supported (only 'full', 'exact', 'prefix', 'keyword' are supported)."
        elsif( (@matchLogicOp != :and and @matchLogicOp != :or) )
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: you have provided the 'matchLogicOp' parameter but your value of #{@matchLogicOp.inspect} is not supported (only 'or' and 'and' are supported)."
        elsif( @matchProp and @matchValues and @matchLogicOp == :and )
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: you are using looking for any of the values provided by 'matchValues' in a single property, but have also asserted that 'matchLogicOp' is 'and'. This is not currently allowed, because the property being searched will match if ANY of the values are present; i.e. only an implicit 'or' currently makes sense."
        elsif( @matchProps and @matchValues and (@matchProps.size != @matchValues.size) )
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: you have provided a list of properties via 'matchProps' and a list of their corresponding values via 'matchValues', but the number of properties (#{@matchProps.size}) does not match the number of values (#{@matchValues.size})."
        end
      end
     matchParamsValid = @statusName
     #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Pre-Clean:\n  @matchMode = #{@matchMode.inspect}\n  @matchLogicOp = #{@matchLogicOp.inspect}\n  @matchProps = #{@matchProps.inspect}\n  @matchVal = #{@matchValue.inspect}\n  @matchProp = #{@matchProp.inspect}\n  @matchValues = #{@matchValues.inspect}")
     #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Pre-Clean:\n  @statusName = #{@statusName.inspect}\n  @statusMsg = #{@statusMsg.inspect}")
     return matchParamsValid
   end



  end # class KbDocs < BRL::REST::Resources::KbDocs
end ; end ; end # module BRL ; module REST ; module Resources
