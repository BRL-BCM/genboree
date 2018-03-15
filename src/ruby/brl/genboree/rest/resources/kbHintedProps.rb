#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/kbDoc'

module BRL; module REST; module Resources

  class KbHintedProps < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = {:get => true}
    RSRC_TYPE = 'kbHintedProps'
    HINTED_PROPS_DOC = {
      "{propHint}PropsForColl" => {
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
        "value" => ""
      }
    }
    
    HINTED_PROP_PATH_DOC_DETAILED = {
      "{propHint}Prop" => {
        "value" => "",
        "properties" => {
          "propDef" => {
            "value" => ""
          }
        }
      }
    }

    SUPPORTED_ASPECTS = {
      'facet'     => true,
      'filter'    => true,
      'coreInfo'  => true
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/props/([^/\?]+)$}
    end

    def self.priority()
      return 7
    end

    # Start a new doc for the given hint keyword using the provided template document as a starting point.
    # @param [String, Symbol] hint The hint keyword used to select the relevant props in the model
    # @return [Hash{String,Hash}] A template that can be used to get this kind of doc started. (@see {HINTED_PROPS_DOC}
    #   for structure)
    def self.initKbDocFromTemplate( hint, baseTemplateDoc )
      raise ArgumentError, "ERROR: unsupported hint keyword #{hint.inspect}" unless( SUPPORTED_ASPECTS.include?(hint.to_s) )
      template = baseTemplateDoc.deep_clone
      # Turn into json for cheap string replace
      templateJson = JSON.pretty_generate(template)
      # Change {propHint} placehold to be hint value instead
      templateJson.gsub!( /\{propHint\}/, hint.to_s )
      # Back to data structure
      hashDoc = JSON.parse( templateJson )
      # As KbDoc
      kbDoc = BRL::Genboree::KB::KbDoc.new( hashDoc )
      return kbDoc
    end

    # Get the hint keyword-specific field names to use in the response doc, either as an Array or as a Hash
    # @param [String, Symbol] hint The hint keyword you need response doc field names for.
    # @param [Hash[Symbol,Object]] opts Optional arguments. Currently supports @:as@ which can be @:array@
    #   (the default) to return field names as a fixed array or @:hash@ to indicate you want a nice Symbol=>FieldName
    #    map.
    # @return [Array<String>, Hash{Symbol,String} ]
    def self.respDocFields( hint, opts={} )
      allOpts = { :as => :array }.merge( opts )
      fields = [ "#{hint}PropsForColl", "#{hint}Props", "#{hint}Prop" ]
      if( allOpts[:as] == :array )
        retVal = fields
      else # as hash
        retVal = {
          :propsForCollField => fields[0],
          :propsField => fields[1],
          :propField => fields[2]
        }
      end

      return retVal
    end

    def initOperation()
      # check class parent validators
      initStatus = super()
      # Not how we do this. Always test initStatus / @statusName return value
      #raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      if( successCode?( initStatus ) )
        @groupName  = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName     = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName   = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @propHint   = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        if( SUPPORTED_ASPECTS.key?(@propHint) )
          initStatus = initGroupAndKb()

          # Not how we do this. Always test initStatus / @statusName return value
          #raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
          if( successCode?( initStatus ) )
            # validate path against model for this collection
            @mh = @mongoKbDb.modelsHelper()
            @cmh = @mongoKbDb.collMetadataHelper()
            @modelDoc = @mh.modelForCollection(@collName) rescue nil
          end
        else
          @mh = @cmh = @modelDoc = nil
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "NOT_SUPPORTED: There are no properties marked as being #{@propHint.inspect} because that is not a supported keyword. Supported are: #{SUPPORTED_ASPECTS.keys.join(',')} ."
        end
      else
        @groupName = @kbName = @collName = @propHint = @mh = @cmh = @modelDoc = nil
      end

      @statusName = initStatus
      return initStatus
    end

    def get()
      begin
        initStatus = initOperation() # error if not ok
        if( successCode?(initStatus) )
          if( @modelDoc )
            kbd = BRL::Genboree::KB::KbDoc.new(@modelDoc)
            model = kbd.getPropVal('name.model')
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "model:\n\n#{JSON.pretty_generate(model)}")
            propPaths = @mh.getPropPathsForFieldAndValue( model, 'Hints', @propHint, { :operation => :contains } )
            # Start a response doc, relevant for the given hint keyword
            respDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROPS_DOC )
            # The key field names
            hintedPropsForCollField, hintedPropsField, hintedPropField  = self.class.respDocFields( @propHint )

            respDoc.setPropVal( hintedPropsForCollField, @collName)
            itemList = []
            if(@detailed)
              propPaths.each { |pp|
                hintedPropPathDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROP_PATH_DOC_DETAILED )
                hintedPropPathDoc.setPropVal( hintedPropField, pp )
                propDef = @mh.findPropDef(pp, model, { :nonRecursive => true })
                hintedPropPathDoc.setPropVal( "#{hintedPropField}.propDef", propDef)
                itemList.push(hintedPropPathDoc)
              }
            else
              propPaths.each { |pp|
                hintedPropPathDoc = self.class.initKbDocFromTemplate( @propHint, HINTED_PROP_PATH_DOC )
                hintedPropPathDoc.setPropVal( hintedPropField, pp )
                itemList.push(hintedPropPathDoc)
              }
            end
            respDoc.setPropItems( "#{hintedPropsForCollField}.#{hintedPropsField}", itemList)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "propPaths:\n#{propPaths.inspect}")
            bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respDoc)
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
  end
end; end; end
