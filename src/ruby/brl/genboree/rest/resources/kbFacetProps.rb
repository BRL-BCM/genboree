#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/kbDoc'

module BRL; module REST; module Resources

  class KbFacetProps < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = {:get => true}
    RSRC_TYPE = 'kbFacetProps'
    FACET_PROPS_DOC = {
      "facetPropsForColl" => {
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
        "value" => ""
      }
    }
    
    FACET_PROP_PATH_DOC_DETAILED = {
      "facetProp" => {
        "value" => "",
        "properties" => {
          "propDef" => {
            "value" => ""
          }
        }
      }
    }
        

    SUPPORTED_ASPECTS = {
      
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/props/facets$}
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

      # validate path against model for this collection
      @mh = @mongoKbDb.modelsHelper()
      @cmh = @mongoKbDb.collMetadataHelper()
      @modelDoc = @mh.modelForCollection(@collName)
      return initStatus
    end
    
    def get()
      begin
        initStatus = initOperation() # error if not ok
        kbd = BRL::Genboree::KB::KbDoc.new(@modelDoc)
        model = kbd.getPropVal('name.model')
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "model:\n\n#{JSON.pretty_generate(model)}")
        propPaths = @mh.getPropPathsForFieldAndValue(model, 'Facet', true)
        respDoc = BRL::Genboree::KB::KbDoc.new(FACET_PROPS_DOC.deep_clone)
        respDoc.setPropVal('facetPropsForColl', @collName)
        itemList = []
        if(@detailed)
          propPaths.each { |pp|
            facetPropPathDoc = BRL::Genboree::KB::KbDoc.new(FACET_PROP_PATH_DOC_DETAILED.deep_clone)
            facetPropPathDoc.setPropVal('facetProp', pp)
            propDef = @mh.findPropDef(pp, model, { :nonRecursive => true })
            facetPropPathDoc.setPropVal('facetProp.propDef', propDef)
            itemList.push(facetPropPathDoc)
          }
        else
          propPaths.each { |pp|
            facetPropPathDoc = BRL::Genboree::KB::KbDoc.new(FACET_PROP_PATH_DOC.deep_clone)
            facetPropPathDoc.setPropVal('facetProp', pp)
            itemList.push(facetPropPathDoc)
          }
        end
        respDoc.setPropItems('facetPropsForColl.facetProps', itemList)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propPaths:\n#{propPaths.inspect}")
        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respDoc)
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

    
  end

end; end; end
