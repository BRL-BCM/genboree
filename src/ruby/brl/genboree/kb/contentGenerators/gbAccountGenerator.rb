#!/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/kb/contentGenerators/generator'

module BRL ; module Genboree ; module KB ; module ContentGenerators
  class GbAccountGenerator < Generator
    
    # @return [String] Domain type string this Generator class can handle. See {BRL::Genboreee::KB::Validators::ModelValidator::DOMAINS}.
    DOMAIN_TYPE = 'gbAccount'

    # @return [Hash<Symbol, Array<String>>] Map of Genboree User Symbol fields to known property names. (Less useful than {KNOWN_PROPS})
    KNOWN_FIELDS = {
      "firstName" => ["First Name", "First name", "first Name", "first name", "firstName", "first_name"],
      "lastName" => ["Last Name", "Last name", "last Name", "last name", "lastName", "last_name"],
      "institution" => ["Institution", "institution"],
      "email" => ["Email", "email", "Email Address", "Email address", "email address", "email Address", "emailAddress", "email_address"]
    }

    # @return [Hash<String, Symbol>] Map of known property names to Genboree User Symbol fields.
    KNOWN_PROPS = KNOWN_FIELDS.inject({}) { |kps,kfs| kfs[1].each { |kp| kps[kp] = kfs[0] } ; kps }

    # Override in sub-class. Do any class-specific initialization.
    def init()
      # Override super.
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
    end
    
    # @abstract
    # @param [String] propPath Property path to property in {#doc} needing content
    # @param [Hash] content The content context noted by the validator as it visited the property.
    #   Contains keys :result, :pathElems, :propDef, :domainRec, :parsedDomain
    def addContentToProp(propPath, context)
      @generationErrors = []
      @generationWarnings = []

      # Get property value at propPath from doc.
      gbAccount = @doc.getPropVal(propPath)
      userRecs = @dbu.selectUserByName(gbAccount)
      if(userRecs.nil?)
        @generationErrors << "An error occured while retrieving user information"
      elsif(userRecs.size == 0)
        @generationWarnings << "No user information found for gbAccount #{gbAccount.inspect}"
      elsif(userRecs.size > 1)
        @generationWarnings << "Multiple user records found for gbAccount #{gbAccount.inspect}"
      else
        userRec = userRecs.first
        propDef = context[:propDef]
        if(propDef.acts_as?(Hash))
          subPropDefs = propDef['properties']
          if(subPropDefs.acts_as?(Array))
            subPropDefs.each { |subPropDef|
              unless(subPropDef['fixed'])
                subPropName = subPropDef['name']
                subPropPath = "#{propPath}.#{subPropName}"
                subPropVal = @doc.getPropVal(subPropPath)
                unless(subPropVal and subPropVal.to_s =~ /\S/)
                  gbField = KNOWN_PROPS[subPropName]
                  if(gbField)
                    subPropVal = userRec[gbField]
                    subPropVal = "[unknown]" if(subPropVal.nil?)
                  else
                    subPropVal = "[unknown]"
                  end
                end
                @doc.setPropVal(subPropPath, subPropVal)
              else
                @generationWarnings << "ignoring sub property #{subPropName.inspect} because its definition sets the \"fixed\" flag"
              end
            }
          else
            @generationWarnings << "receieved propPath #{propPath.inspect} to fill properties for, but it does not have an array of child properties to fill! Specifically, subPropDefs #{subPropDefs.inspect} does not act as an Array"
          end
        else
          @generationErrors << "propDef #{propDef.inspect} does not act like a Hash"
        end
      end

      return @doc
    end
  end # class Generator
end ; end ; end ; end
