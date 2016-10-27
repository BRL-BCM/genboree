#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/kbDoc'

module BRL; module REST; module Resources

  class KbFacetDocProps < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = {:get => true}
    RSRC_TYPE = 'kbFacetDocProps'
    FACET_PROPS_DOC = {
      "facetPropsForDoc" => {
        "properties" => {
          "facetProps" => {
            "items" => []
          }
        },
        "value" => ""
      }
    }
    
    FACET_PROP_PATH_DOC = {
      "facetProp" => {
        "value" => "",
        "properties" => {
          "docValue" => {
            "value" => ""
          }
        }
      }
    }
    
    MISSING_VALUE_PLACEHOLDER = "[No Value]"
   
        

    SUPPORTED_ASPECTS = {
      
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/docs/props/facets/values$}
    end

    def self.priority()
      return 7
    end

    def initOperation()
      # check class parent validators
      initStatus = super()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      initStatus = initGroupAndKb()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      # Initialize any helper objects that are required
      @mh = @mongoKbDb.modelsHelper()
      @cmh = @mongoKbDb.collMetadataHelper()
      @dch = @mongoKbDb.dataCollectionHelper(@collName)
      @versHelper = @mongoKbDb.versionsHelper(@collName)
      @modelKbDoc = BRL::Genboree::KB::KbDoc.new(@mh.modelForCollection(@collName))
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
      @allFacetProps = @mh.getPropPathsForFieldAndValue(@modelDoc, 'Facet', true)
      @allFacetPropsHash = {}
      @allFacetProps.each { |pp|
        @allFacetPropsHash[pp] = nil  
      }
      if(payload.nil?)
        if(!@props.nil?)
          validateFacetPropPaths(@props)
        else
          @props = @allFacetProps
        end
      elsif(payload == :'Unsupported Media Type') # not correct payload content
        @statusName = :'Unsupported Media Type'
        @statusMsg = "BAD_PAYLOAD: This resource accepts a simple hash payload: { 'hash' => { 'docIds' => [], 'props' => [] } }"
      else
        # Throw error is docIds or props is also been provided via params
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
          @props = @allFacetProps
        end
        if(payloadObj.key?('cutoffTime'))
          @cutoffTime = payloadObj['cutoffTime']
        end
      end
      return initStatus
    end
    
    def get()
      begin
        initStatus = initOperation() # error if not ok
        docIdentifierPropName = @dch.getIdentifierName()
        mongoPaths = ["#{docIdentifierPropName}.value"]
        # Convert *our* paths to mongoDB compatible paths
        @props.each { |pp|
          mongoPaths << @mh.modelPath2DocPath(pp, @collName)  
        }
        propDef = @mh.findPropDef(docIdentifierPropName, @modelDoc)
        propDomain = ( propDef ? (propDef['domain'] or 'string') : 'string' )
        # Before running the query to select facets, apply time based filteration if required
        filteredIds = []
        if(!@cutoffTime.nil?)
          if(@docIds.nil? or @docIds.empty?)
            filteredIds = @versHelper.filterAllDocsBasedOnTimeStamp(@cutoffTime, @collName, docIdentifierPropName, { :includeCutoffTime => @includeCutoffTime})
          else
            docRecs = @dch.docsFromCollectionByFieldAndValues(@docIds, "#{docIdentifierPropName}.value")
            objId2DocId = {}
            docRecs.each { |docRec|
              kbDocRec = BRL::Genboree::KB::KbDoc.new(docRec)
              objId = docRec['_id']
              docId = kbDocRec.getPropVal(docIdentifierPropName)
              objId2DocId[objId] = docId
            }
            filteredIds = @versHelper.filterDocListBasedOnTimeStamp(objId2DocId, @cutoffTime, @collName, docIdentifierPropName, { :includeCutoffTime => @includeCutoffTime})
          end
        end
        bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
        if(!@cutoffTime.nil? and filteredIds.empty?)
          # None of the docs satisfy the timestamp criteria
        else
          @docIds = filteredIds if(!@cutoffTime.nil?)
          cursor = nil
          if(@docIds.nil? or @docIds.empty?)
            cursor = @dch.cursorForOutputProps(mongoPaths)
          else
            cursor = @dch.cursorBySimplePropValsMatch( { :prop => { "#{docIdentifierPropName}.value" => propDomain }, :vals => @docIds }, mongoPaths )
          end
          cursor.each { |doc|
            kbdRef = BRL::Genboree::KB::KbDoc.new(doc)
            facPropsDoc = BRL::Genboree::KB::KbDoc.new(FACET_PROPS_DOC.deep_clone)
            items = []
            @props.each { |path|
              facPropPathDoc = BRL::Genboree::KB::KbDoc.new(FACET_PROP_PATH_DOC.deep_clone)
              facPropPathDoc.setPropVal("facetProp", path)
              begin
                propValue = kbdRef.getPropVal(path)
                if(propValue.nil?)
                  facPropPathDoc.setPropVal("facetProp.docValue", MISSING_VALUE_PLACEHOLDER)
                else
                  facPropPathDoc.setPropVal("facetProp.docValue", propValue)
                end
              rescue => err
                # Property doesn't exist in the doc  
                facPropPathDoc.setPropVal("facetProp.docValue", MISSING_VALUE_PLACEHOLDER)
                # Dump 'valid' error to log
                $stderr.debugPuts(__FILE__, __method__, "VALID_EXCEPTION", err.message)
              ensure
                items.push(facPropPathDoc)
              end  
            }
            facPropsDoc.setPropVal("facetPropsForDoc", kbdRef.getPropVal(docIdentifierPropName))
            facPropsDoc.setPropItems("facetPropsForDoc.facetProps", items)
            bodyData <<  BRL::Genboree::REST::Data::KbDocEntity.new(@connect, facPropsDoc)
          }
        end
        @statusName = configResponse(bodyData)
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

      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Helpers
    
    # Validate the list of facet props to ensure none of them are under an item list
    def validateFacetPropPaths(propPaths)
      propPaths.each { |pp|
        if(!@allFacetPropsHash.key?(pp))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The property: #{pp} is either not in the model or not marked as being a Facet. Please consult the model for this collection and update your request.")
        end
        if(@mh.withinItemsList(pp, @modelDoc))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "One or more of the properties that are marked as being Facets for the collection: #{@collName} are under an item list. This is not allowed. This also implies that the model itself is improperly constructed.")
        end
      }
    end
    
  end

end; end; end
