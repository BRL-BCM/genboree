#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/kb/kbDoc'

module BRL; module REST; module Resources

  # Related to docs-wide info for a specific prop.
  class KbDocsProp < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = { :get => true  }
    RSRC_TYPE = 'kbDocsProp'
    SUPPORTED_ASPECTS = { 'get' => { 'values/distinct' => true } }
    REJECTION_SET_REG_EXPS = [ /\[\s*\d+\s*,/,  /\.</, /\{\s*\}/]

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/docs/prop/([^/\?]+)(?:$|/([^\?]+)$)}
    end

    def self.priority()
      return 8
    end

    def initOperation()
      # check class parent validators
      initStatus = super()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      # Get info from rsrcPath
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      @propPath   = Rack::Utils.unescape(@uriMatchData[4])
      @aspect     = Rack::Utils.unescape(@uriMatchData[5])
      if(@aspect)
        unless(SUPPORTED_ASPECTS[@reqMethod.to_s.downcase].key?(@aspect))
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The aspect #{@aspect.inspect} is not supported for #{@reqMethod.to_s.upcase}")
        end
      else # Currently MUST have an aspect, it's the only KbDocsProp request that is handled right now
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "This request is not supported for properties.")
      end

      # Get info from params
      # - optional aggOp
      @aggOp = ( (@nvPairs['aggOp'].to_s =~ /\S/) ? @nvPairs['aggOp'].downcase.to_sym : :count )
      raise BRL::Genboree::GenboreeError.new(:'Bad Request', "The aggregation operation (aggOp parameter) #{@nvPairs['aggOp'].inspect} is not supported. Only count, sum, avg, max, min.") unless( [ :count, :sum, :avg, :max, :min ].include?(@aggOp) )

      initStatus  = initGroupAndKb()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      if(matchRejectionSet?(@propPath))
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "The property path (#{@propPath.inspect} cannot contain: empty curly/square braces, square braces with multiple values or '<'. If you are trying to access an item or a property under an item, use square braces with a single number[idx] or curly braces with a value {value} to indicate the index/value  of the item you are interested in.")
      end

      # validate path against model for this collection
      @mh = @mongoKbDb.modelsHelper()
      @model = @mh.getModel(@collName)
      raise BRL::Genboree::GenboreeError.new(:"Not Found", "Model document not found for this collection.") unless(@model)
      return initStatus
    end

    def get()
      begin
        initStatus = initOperation() # error if not ok
        dataHelper = @mongoKbDb.dataCollectionHelper(@collName)
        # Ask for the distinct values for propPath
        # Try to make sure we have nice model path. Although helper method should convert automatically so this would be for clear logging & intent
        modelPath = BRL::Genboree::KB::KbDoc.docPath2ModelPath(@propPath)
        # Get the distinct values. Since we have the model available, provide it to avoid re-retrieval
        resultSet = dataHelper.distinctValsForProp(modelPath, @model, @aggOp)
        # @todo process & present resultSet
        entity = buildEntity(resultSet, @aggOp)
        @statusName = configResponse(entity)
      rescue BRL::Genboree::KB::KbError => kerr
        @statusName = :'Bad Request'
        @statusMsg = kerr.message
      rescue BRL::Genboree::GenboreeError => gerr
        @statusName = gerr.type
        @statusMsg = gerr.message
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "API_HANDLER_ERROR", err.message)
        $stderr.debugPuts(__FILE__, __method__, "API_HANDLER_ERROR", err.backtrace.join("\n"))
        @statusName = :"Internal Server Error"
        @statusMsg = err.message
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # ----------------------------------------------------------------
    # HELPERS
    # ----------------------------------------------------------------

    def matchRejectionSet?(prop)
      retVal = false
      REJECTION_SET_REG_EXPS.each { |regExp|
        if(prop =~ regExp)
          retVal = true
          break
        end
      }
      return retVal
    end

    def buildEntity(resultSet, aggOp=@aggOp)
      kbDocEntityList = BRL::Genboree::REST::Data::KbDocEntityList.new(false)
      # resultSet will be an Array<BSON::OrderedHash> where each OrderedHash is of the form:
      #   { "count" => 5, "value" => %%SIMPLE_VALUE%% }
      #   { "count" => 5, "value"=> [ %%ARRAY OF SIMPLE VALUES%% ] }  # <= because propPath is under an items list and thus each doc can have multiple values!
      if(resultSet)
        resultSet.each_index { |ii|
          result = resultSet[ii]
          # Set up the KbDoc
          kbDoc = BRL::Genboree::KB::KbDoc.new({})
          kbDoc.setPropVal('distinctValue', ii)
          kbDoc.setPropVal("distinctValue.#{@aggOp}", result[@aggOp.to_s])
          # Deal with 2 kinds of "distinct" values since propPath might have been in an items list
          rawVal = result['value']
          if(rawVal.is_a?(Array)) # propPath was in an items list and so there can be multiple values per doc
            rawVal.each { |val|
              valDoc = BRL::Genboree::KB::KbDoc.new({})
              valDoc.setPropVal('value', val)
              kbDoc.addPropItem('distinctValue.multiValued', valDoc)
            }
          else # propPath not under items list, so simple distinct values
            kbDoc.setPropVal('distinctValue.value', rawVal)
          end
          # Add the kbDoc to the list
          kbDocEntityList << kbDoc
        }

      end
      return kbDocEntityList
    end
  end
end; end; end
