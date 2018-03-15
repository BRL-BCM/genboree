#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/resources/kbHintedProps'

module BRL; module REST; module Resources

  class KbHintedDocProps < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbHintedDocProps'
    HINTED_PROPS_DOC = {
      "{propHint}PropsForDoc" => {
        "properties" => {
          "{propHint}Props" => {
            "items" => []
          }
        },
        "value" => ""
      }
    }
    
    HINTED_PROP_PATH_DOC = {
      "{propHint}Prop" => {
        "value" => "",
        "items" => [ ]
      }
    }

    HINTED_PROP_DOC_VALUE = {
      "docValue" => {
        "value" => ""
      }
    }

    SUPPORTED_ASPECTS = {
      'facet'     => true,
      'filter'    => true,
      'coreInfo'  => true,
      'relation'  => true
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/docs/props/([^/\?]+)/values$}
    end

    def self.priority()
      return 7
    end

    # @see {BRL::REST::Resources::KbHintedProps.initKbDocFromTemplate}
    # Currently, that implemenation works just fine here too. Will be given base-docs appropriate
    #   for *this* class, of course (i.e. the various HINTED_ constants)
    def self.initKbDocFromTemplate( hint, baseTemplateDoc )
      return BRL::REST::Resources::KbHintedProps.initKbDocFromTemplate( hint, baseTemplateDoc )
    end

    # Get the hint keyword-specific field names to use in the response doc, either as an Array or as a Hash
    # @param [String, Symbol] hint The hint keyword you need response doc field names for.
    # @param [Hash[Symbol,Object]] opts Optional arguments. Currently supports @:as@ which can be @:array@
    #   (the default) to return field names as a fixed array or @:hash@ to indicate you want a nice Symbol=>FieldName
    #    map.
    # @return [Array<String>, Hash{Symbol,String} ]
    def self.respDocFields( hint, opts={} )
      allOpts = { :as => :array }.merge( opts )
      fields = [ "#{hint}PropsForDoc", "#{hint}Props", "#{hint}Prop" ]
      if( allOpts[:as] == :array )
        retVal = fields
      else # as hash
        retVal = {
          :propsForDocField => fields[0],
          :propsField => fields[1],
          :propField => fields[2]
        }
      end

      return retVal
    end

    def initOperation()
      # check class parent validators
      initStatus     = super()

      # Not how we do this. Always test initStatus / @statusName return value
      #raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      if( successCode?( initStatus ) )
        @groupName  = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName     = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName   = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @propHint   = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        if( SUPPORTED_ASPECTS.key?(@propHint) )
          initStatus = initGroupAndKb()
          if( successCode?( initStatus ) )
            # Initialize any helper objects that are required
            @mh = @mongoKbDb.modelsHelper()
            @cmh = @mongoKbDb.collMetadataHelper()
            @dch = @mongoKbDb.dataCollectionHelper(@collName)
            @versHelper = @mongoKbDb.versionsHelper(@collName)
            modelRecord = @mh.modelForCollection(@collName) rescue nil
            if( modelRecord )
              @modelKbDoc = BRL::Genboree::KB::KbDoc.new(@mh.modelForCollection(@collName)) rescue nil
              @modelDoc = @modelKbDoc.getPropVal('name.model')
              # Set up @docIds or @props or @cutoffTime which may come either from params or payload
              @docIds = nil
              @props = nil
              @cutoffTime = nil
              # If true, the comparison will include the cutoff time. Otherwise it will only consider timestamps newer than the cutoff time.
              @includeCutoffTime = false
              # First check the request params
              if(@nvPairs['docIds'])
                @docIds = @nvPairs['docIds'].split(",")
              end
              if(@nvPairs['props'])
                @props = @nvPairs['props'].split(",")
              end
              if(@nvPairs['cutoffTime'])
                @cutoffTime = @nvPairs['cutoffTime']
              end
              if(@nvPairs['includeCutoffTime'] and @nvPairs['includeCutoffTime'] == "true")
                @includeCutoffTime = true
              end
              # Parse the request payload (if any)
              payload = parseRequestBodyForEntity('HashEntity')
              @allHintedProps = @mh.getPropPathsForFieldAndValue(@modelDoc, 'Hints', @propHint, { :operation => :contains } )
              @allHintedPropsHash = {}
              @allHintedProps.each { |pp|
                @allHintedPropsHash[pp] = nil
              }
              if(payload.nil?)
                if(!@props.nil?)
                  begin
                    validateFacetPropPaths(@props)
                  rescue => err
                    @statusName = :'Bad Request'
                    @statusMsg = err.message
                  end
                else
                  @props = @allHintedProps
                end
              elsif(payload == :'Unsupported Media Type') # not correct payload content
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_PAYLOAD: This resource accepts a simple hash payload: { 'hash' => { 'docIds' => [], 'props' => [] } }"
              else
                # Throw error is docIds or props is also been provided via params
                # @todo Allow docIds and props to be provided by both url and payload
                # @todo All OR some of props,docIds,cutoffTime in url while others in payload
                if(!@docIds.nil? or !@props.nil? or !@cutoffTime.nil?)
                  raise BRL::Genboree::GenboreeError.new(:"Bad Request", "You cannot provide docIds/props/cutoffTime via both URL and payload.")
                end
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "payload:\n#{payload.inspect}")
                payloadObj = payload.hash
                if(payloadObj.key?('docIds'))
                  @docIds = payloadObj['docIds']
                end
                if(payloadObj.key?('props'))
                  @props = payloadObj['props']
                  validateFacetPropPaths(@props)
                else
                  @props = @allHintedProps
                end
                if(payloadObj.key?('cutoffTime'))
                  @cutoffTime = payloadObj['cutoffTime']
                end
              end
            else
              @modelDoc = nil
              @versHelper = @modelKbDoc = @docIds = @props = @cutoffTime = @includeCutoffTime = @allHintedProps = @allHintedProps = nil
            end
          end
        else
          @mh = @cmh = @modelDoc = nil
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NOT_SUPPORTED: There are no properties marked as being #{@propHint.inspect} because that is not a supported keyword. Supported are: #{SUPPORTED_ASPECTS.keys.join(',')} ."
        end
      else
        @groupName = @kbName = @collName = @propHint = @mh = @cmh = @modelDoc = nil
        @versHelper = @modelKbDoc = @docIds = @props = @cutoffTime = @includeCutoffTime = @allHintedProps = @allHintedProps = nil
      end

      @statusName = initStatus
      return initStatus
    end
    
    def get()
      begin
        initStatus = initOperation() # error if not ok
        if( successCode?(initStatus) )
          if( @modelDoc )
            docIdentifierPropName = @dch.getIdentifierName()
            mongoPaths = ["#{docIdentifierPropName}.value"]
            # Convert *our* paths to mongoDB compatible paths
            @props.each { |pp|
              mongoPaths << @mh.modelPath2DocPath(pp, @collName)
            }
            propDef = @mh.findPropDef(docIdentifierPropName, @modelDoc)
            propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
            # Before running the query to select props with hint keyword, apply time based filteration if required
            filteredIds = []
            if(!@cutoffTime.nil?)
              if(@docIds.nil? or @docIds.empty?)
                # @todo BUG! If the collection has 20 million or 200 millions docs, this ids list will be huge. AND will
                #   be used to form a mongo query doc below!
                # @todo need to do this in deferrable body and have 2 cursors: one which gets docIds from matching versions
                #   records which we go through to accumulate several thousand (5000?) docIds for which we then do a 2nd
                #   retrieval to get their prop-value details or whatever AND render those (not accumulate). And this
                #   needs to happen within a deferrable so non-blocking and so we don't accumulate massive response payload in RAM.
                filteredIds = @versHelper.filterAllDocsBasedOnTimeStamp(@cutoffTime, @collName, docIdentifierPropName, { :includeCutoffTime => @includeCutoffTime})
              else
                # @todo BUG! Same issues as above. If the collection has 20 million or 200 millions docs, this ids list will be huge. AND will
                #   be used to form a mongo query doc below!
                # @todo need to do this in deferrable body and have 2 cursors: one which gets docIds from matching versions
                #   records which we go through to accumulate several thousand (5000?) docIds for which we then do a 2nd
                #   retrieval to get their prop-value details or whatever AND render those (not accumulate). And this
                #   needs to happen within a deferrable so non-blocking and so we don't accumulate massive response payload in RAM.
                docRecs = @dch.docsFromCollectionByFieldAndValues(@docIds, "#{docIdentifierPropName}.value")
                objId2DocId = {}
                docRecs.each { |docRec|
                  kbDocRec = BRL::Genboree::KB::KbDoc.new(docRec)
                  objId = docRec['_id']
                  docId = kbDocRec.getPropVal(docIdentifierPropName)
                  objId2DocId[objId] = docId
                }
                # @todo BUG! see above
                filteredIds = @versHelper.filterDocListBasedOnTimeStamp(objId2DocId, @cutoffTime, @collName, docIdentifierPropName, { :includeCutoffTime => @includeCutoffTime})
              end
            end
            bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
            if(!@cutoffTime.nil? and filteredIds.empty?)
              # None of the docs satisfy the timestamp criteria
            else
              # The key field names needed to build appropriate response document
              hintedPropsForDocField, hintedPropsField, hintedPropField  = self.class.respDocFields( @propHint )

              @docIds = filteredIds if(!@cutoffTime.nil?)
              cursor = nil
              if(@docIds.nil? or @docIds.empty?)
                cursor = @dch.cursorForOutputProps(mongoPaths)
              else
                # @todo BUG! see above, but @docIds may be huge by this point. Mongo may fail [too big] or may block [big but slow]
                cursor = @dch.cursorBySimplePropValsMatch( { :prop => { "#{docIdentifierPropName}.value" => propDomain }, :vals => @docIds }, mongoPaths )
              end
              cursor.each { |doc|
                kbdRef = BRL::Genboree::KB::KbDoc.new(doc)
                propSelector = kbdRef.propSelector()
                hintedPropsDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROPS_DOC)
                items = []
                @props.each { |path|
                  begin
                    # Get all the values for the propPath (ones within items lists can have more that 1 value per prop path)
                    pathAsSelector = BRL::Genboree::KB::Helpers::ModelsHelper.modelPathToPropSelPath(path, @modelDoc)
                    propSelector = kbdRef.propSelector()
                    propValues = propSelector.getMultiPropValues( pathAsSelector )
                    #propValue = kbdRef.getPropVal(path)
                    # Create a hintedProp object for this prop if have a value it in the current doc (if not, don't add the hintedProp at all for this doc)
                    unless(propValues.nil? or propValues.empty?)
                      # Create a record for this doc
                      hintedPropPathDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROP_PATH_DOC )
                      hintedPropPathDoc.setPropVal( hintedPropField, path)
                      # Create a value object for each value
                      propValues.each { |propVal|
                        valDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROP_DOC_VALUE )
                        valDoc.setPropVal( 'docValue', propVal)
                        hintedPropPathDoc.addPropItem( hintedPropField, valDoc )
                      }

                      # Add this doc's record to the set of all doc records
                      items.push(hintedPropPathDoc)
                    end
                  rescue => err
                    # Dump 'valid' error to log and try to keep going
                    $stderr.debugPuts(__FILE__, __method__, "VALID_EXCEPTION", "#{err.message}\nTRACE:\n\n#{err.backtrace.join("\n")}\n\n")
                  end
                }

                # Don't output records for docs that have NO values for ANY of the hinted props
                if(items and !items.empty?)
                  hintedPropsDoc.setPropVal( hintedPropsForDocField, kbdRef.getPropVal(docIdentifierPropName) )
                  hintedPropsDoc.setPropItems( "#{hintedPropsForDocField}.#{hintedPropsField}", items)
                  bodyData <<  BRL::Genboree::REST::Data::KbDocEntity.new(@connect, hintedPropsDoc)
                end
              }
            end

            @statusName = configResponse(bodyData)
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: There does not appeat to be a collection called #{@collName.inspect} within this KB. Please double check spelling, etc. Or less likely, the model for the collection is missing or is corrupt."
          end
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end

      @resp = representError() unless( successCode?(@statusName) )
      return @resp
    end

    # Helpers
    
    # Validate the list of hinted props to ensure none of them are under an item list
    def validateFacetPropPaths(propPaths)
      propPaths.each { |pp|
        if(!@allHintedPropsHash.key?(pp))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The property: #{pp.inspect} is either not in the model or not marked as being a #{@propHint.inspect} property. Please consult the model for this collection and update your request.")
        end
        if( @mh.withinItemsList(pp, @modelDoc) and (@propHint == 'facet' or @propHint == 'filter') )
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "One or more of the properties that are marked as being Facets for the collection: #{@collName.inspect} are under an item list. This is not allowed. This also implies that the model itself is improperly constructed.")
        end
      }
    end
  end
end; end; end
