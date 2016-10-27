#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'

module BRL; module REST; module Resources

  class KbProps < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = {:get => true}
    RSRC_TYPE = 'kbProps'

    SUPPORTED_ASPECTS = {
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/props$}
    end

    def self.priority()
      return 6
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
      @modelsHelper = @mongoKbDb.modelsHelper()
      @modelDoc = @modelsHelper.modelForCollection(@collName)
      raise BRL::Genboree::GenboreeError.new(:"Not Found", "No Model document was found for the collection #{@collName.inspect}") if(@modelDoc.nil?)    
      return initStatus
    end

    def get()
      begin
        initStatus = initOperation() # error if not ok
        payload = parseRequestBodyForEntity('TextEntityList')
        payloadArray = payload.array
        propPaths = []
        payloadArray.each {|obj|
          propPaths.push(obj.text)
        }
        if(payload.nil?)
          @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: No payload provided. You need to provide a list (Text Entity) of one or more valid property paths. If you want the entire model document, use coll/{coll}/model"
        elsif(payload == :'Unsupported Media Type')
          @statusName = :'Unsupported Media Type'
          @statusMsg = "The payload you provided is not valid. You need to provide a list (Text Entity) of one or more valid property paths."
        else
          bodyData = BRL::Genboree::REST::Data::HashEntityList.new(@connect)
          mv = BRL::Genboree::KB::Validators::ModelValidator.new()
          propPaths.each { |propPath|
            propDef = @modelsHelper.findPropDef(propPath, @modelDoc)
            raise BRL::Genboree::GenboreeError.new(:"Not Found", "The path given by #{propPath.inspect} is not a valid property path for the #{@collName.inspect} collection model") if(propDef.nil?)    
            # Will generate autoID values for properties that have the autoID domain if option is set to true
            if(@nvPairs.key?("addAutoIDValues") and @nvPairs['addAutoIDValues'] =~ /true/i and propDef['domain'] and propDef['domain'] == 'autoID')
              autoIdGen = BRL::Genboree::KB::ContentGenerators::AutoIdGenerator.new(nil, {}, @collName, @mongoKbDb)
              # Generate ID
              scope = scopeFromPath(propPath, propDef)
              domain = propDef['domain']
              parsedDomain = mv.parseDomain(domain)
              autoId = autoIdGen.generateId(@collName, propPath, parsedDomain, :scope => scope)
              if(autoId.nil?)
                raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Unable to generate unique ID for #{propPath.inspect} in #{@collName.inspect}")
              end
              propDef['autoIDValue'] = autoId
            end
            bodyData << { propPath => propDef }
          }
          @statusName = configResponse(bodyData)
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

      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # @param [String] propPath a kb property path
    # @return [:collection, :items] symbol like that used by docValidator to set scope
    def scopeFromPath(propPath, propDef)
      scope = :collection
      if(propDef.key?('items'))
        scope = :items
      end
      return scope
    end
  end

end; end; end
