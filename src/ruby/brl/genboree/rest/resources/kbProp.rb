#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/hashEntity'
require 'brl/genboree/kb/contentGenerators/autoIdGenerator'
require 'brl/genboree/kb/validators/modelValidator'

module BRL; module REST; module Resources

  class KbProp < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = {:put => true, :get => true}
    RSRC_TYPE = 'kbProp'
    DOMAINS_SUPPORTING_COUNTERS = [ "autoID" ]
    CORE_FIELDS_KILL_LIST = { 'properties' => nil, 'items' => nil , 'name' => nil }
    PROP_DEF_DOC = {
      'PropPath' => {
        "value" => "",
        "properties" => {
          "Definition" => {
            "properties" => {
              "Core" => {
                "properties" => {
                  "Properties" => {
                    "items" => [] 
                  },
                  "Items" => {
                    "properties" => {
                      "SubItem" => {
                        "value" => ""
                      }
                    }
                  }
                }
              },
              "Custom" => {
                "properties" => {
                  
                }
              }
            }
          },
          "Additional Information" => {
            "properties" => {
              "Counters" => {
                "properties" => {
                  "Type" => {
                    "properties" => {
                      "Value" => {
                        "value" => ""
                      }
                    },
                    "value" => ""
                  }
                }
              }
            }
          }
        }
      }
    }
    
    PROP_DEF_MODEL =
    
    {
      "name"        => { "value" => "PROP_DEF_MODEL", "properties" =>
      {
        "internal"  => { "value" => true },
        "description" => { "value" => "A model for representing a property definition"},
        "model"     => { "value" =>
          {
            "name"        => "PropPath",
            "description" => "The full path to the property this model defines.",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "Definition",
                "description" => "The definition section of the property",
                "domain"      => "[valueless]",
                "properties"  => [
                  {
                    "name"    => "Core",
                    "properties" => [
                      {
                        "name" => "Properties",
                        "items" => [
                          {
                            "name" => "Property",
                            "identifier" => true
                          }
                        ]
                      },
                      {
                        "name" => "Items",
                        "properties" => [
                          {
                            "name" => "SubItem"
                          }
                        ]
                      }
                    ]
                  },
                  {
                    "name"    => "Custom"
                  }
                ]
              },
              {
                "name"        => "Additional Information",
                "description" => "Information other than the definition. Example: Counter",
                "domain"      => "[valueless]",
                "properties" => [
                  {
                    "name" => "Counters",
                    "domain" => "[valueless]",
                    "properties" => [
                      {
                        "name" => "Type",
                        "properties" => [
                          {
                            "name" => "Value",
                            "domain" => "posInt"
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
              
            ]
          }
        }
      }}
    }
        

    SUPPORTED_ASPECTS = {
      "autoID" => true,
      "autoIDs" => true
    }

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/prop/([^/\?]+)(?:$|/([^/\?]+)$)}
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
      @propPath   = Rack::Utils.unescape(@uriMatchData[4])
      @aspect     = @uriMatchData[5].nil? ? nil : Rack::Utils::unescape(@uriMatchData[5])
      initStatus = initGroupAndKb()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])

      # validate path against model for this collection
      @mh = @mongoKbDb.modelsHelper()
      @cmh = @mongoKbDb.collMetadataHelper()
      @modelDoc = @mh.modelForCollection(@collName)
      @propDef = @mh.findPropDef(@propPath, @modelDoc)
      
      raise BRL::Genboree::GenboreeError.new(:"Not Found", "The path given by #{@propPath.inspect} is not a valid property path for the #{@collName.inspect} collection model") if(@propDef.nil?)

      return initStatus
    end
    
    def get()
      begin
        initStatus = initOperation() # error if not ok
        respDoc = BRL::Genboree::KB::KbDoc.new(PROP_DEF_DOC.deep_clone)
        propDefModel = PROP_DEF_MODEL.deep_clone
        respDoc.setPropVal('PropPath', @propPath)
        coreProps = respDoc.getPropProperties('PropPath.Definition.Core')
        # Add the core fields to the reponse doc
        coreFields = BRL::Genboree::KB::Validators::ModelValidator::FIELDS
        coreFields.each_key {|field|
          if(!CORE_FIELDS_KILL_LIST.key?(field))
            propVal = ( @propDef.key?(field) ? @propDef[field] : coreFields[field][:default])
            coreProps[field] = { "value" => propVal }
          end
        }
        # Add any custom fields that the model might have
        customProps = respDoc.getPropProperties('PropPath.Definition.Custom')
        customPropsPresent = false
        customPropsForModel = []
        @propDef.each_key { |field|
          if(!coreFields.key?(field) and !CORE_FIELDS_KILL_LIST.key?(field)) # Field should not be part of the "core" or the kill list
            customProps[field] = { "value" => @propDef[field] }
            customPropsForModel.push( { "name" => @propDef[field] })
            customPropsPresent = true
          end
        }
        if(customPropsPresent)
          modelCustomProps = propDefModel['name']['properties']['model']['value']['properties'][0]['properties'][1]
          modelCustomProps['properties'] = []
          modelCustomProps['properties'].push(customPropsForModel)
        end
        domain = coreProps['domain']
        getCounter = false
        DOMAINS_SUPPORTING_COUNTERS.each { |dd|
          
          if(domain['value'] =~ /#{dd}/)
            getCounter = true
            respDoc.setPropVal('PropPath.Additional Information.Counters.Type', dd)
          end
        }
        escGrpName = CGI.escape(@groupName)
        escKbName = CGI.escape(@kbName)
        escCollName = CGI.escape(@collName)
        escPropPath = CGI.escape(@propPath)
        if(@propDef.key?('properties') and !@propDef['properties'].empty?)
          subProps = respDoc.getPropItems('PropPath.Definition.Core.Properties')
          @propDef['properties'].each {|prop|
            propUrl = "http://#{@genbConf.machineName}/REST/v1/grp/#{escGrpName}/kb/#{escKbName}/coll/#{escCollName}/model/prop/#{escPropPath}/#{CGI.escape(prop['name'])}"
            subProps.push({ "Property" => { "value" => propUrl } })
          }
        elsif(@propDef.key?('items') and !@propDef['items'].empty?)
          propUrl = "http://#{@genbConf.machineName}/REST/v1/grp/#{escGrpName}/kb/#{escKbName}/coll/#{escCollName}/model/prop/#{escPropPath}/#{CGI.escape(@propDef['items'][0]['name'])}"
          respDoc.setPropVal('PropPath.Definition.Core.Items.SubItem', propUrl)
        end
        if(getCounter)
          counter = @cmh.getCounter(@collName, @propPath)
          respDoc.setPropVal('PropPath.Additional Information.Counters.Type.Value', counter)
        end
        bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, respDoc)
        bodyData.model = propDefModel
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

    def put()
      begin
        initStatus = initOperation() # error if not ok
        unless(WRITE_ALLOWED_ROLES[@groupAccessStr])
          @statusName = :Forbidden
          @statusMsg = "FORBIDDEN: You do not have sufficient access or permissions to operate on this resource."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end

        # aspect or propPath?
        if(@aspect.nil?)
          # return the property definiition if no aspect is provided
          bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, @propDef)
          @statusName = configResponse(bodyData)
        else
          # check supported aspects
          msg = "The #{@aspect.inspect} aspect that you requested is not supported. Supported aspects: #{SUPPORTED_ASPECTS.keys().join(", ")}"
          raise BRL::Genboree::GenboreeError.new(:"Bad Request", msg) unless(SUPPORTED_ASPECTS.key?(@aspect))

          if(@aspect == "autoID")
            # use scope and parsed domain for auto id
            scope = scopeFromPath(@propPath)
            mv = BRL::Genboree::KB::Validators::ModelValidator.new()
            domain = @propDef['domain']
            parsedDomain = mv.parseDomain(domain)
            # @todo maybe move this function to a class fxn so we don't have to mock up this object
            autoIdGen = BRL::Genboree::KB::ContentGenerators::AutoIdGenerator.new(nil, {}, @collName, @mongoKbDb)

            # Generate ID
            autoId = autoIdGen.generateId(@collName, @propPath, parsedDomain, :scope => scope)
            if(autoId.nil?)
              raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Unable to generate unique ID for #{@propPath.inspect} in #{@collName.inspect}")
            end

            # @todo change to KbDocEntity?
            # if no error, we succeeded with making ID
            @statusName = :OK
            @statusMsg = "Successfully created unique ID"
            entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, autoId)
            entity.setStatus(@statusName, @statusMsg)
            configResponse(entity) # sets @resp
          elsif(@aspect == "autoIDs")
            # parse options unique to this aspect
            amount = @nvPairs.key?("amount") ? @nvPairs["amount"].to_i : 1
            if(amount == 0)
              # then to_i failed
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Could not use amount parameter #{amount.inspect} as an integer")
            end

            # @todo some opportunity for code reuse with autoID
            # use scope and parsed domain for auto id
            scope = scopeFromPath(@propPath)
            mv = BRL::Genboree::KB::Validators::ModelValidator.new()
            domain = @propDef['domain']
            parsedDomain = mv.parseDomain(domain)
            autoIdGen = BRL::Genboree::KB::ContentGenerators::AutoIdGenerator.new(nil, {}, @collName, @mongoKbDb)

            # Generate IDs
            autoIds = autoIdGen.generateIds(@collName, @propPath, parsedDomain, :scope => scope, :amount => amount)
            if(autoIds.empty?)
              raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Unable to generate unique IDs for #{@propPath.inspect} in #{@collName.inspect}")
            end

            # if no error, we succeeded with making ID; configure response
            docs = BRL::Genboree::KB::KbDoc.propDocsFromArray(autoIds, "autoID")
            entities = docs.map { |doc| BRL::Genboree::REST::Data::KbDocEntity.new(false, doc) }
            entityList = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect, entities)
            @statusName = :OK
            @statusMsg = "Successfully created unique IDs"
            entityList.setStatus(@statusName, @statusMsg)
            configResponse(entityList) # sets @resp

          # elsif(@aspect == "yourAspect")
          #   put new aspects here, add aspect name to SUPPORTED_ASPECTS
          else
            raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "A developer indicated support for this #{@aspect.inspect} aspect without implementing it")
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

      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # @param [String] propPath a kb property path
    # @return [:collection, :items] symbol like that used by docValidator to set scope
    def scopeFromPath(propPath)
      scope = :collection
      if(@propDef.key?('items'))
        scope = :items
      end
      return scope
    end
  end

end; end; end
