#!/bin/env ruby
require 'brl/util/util'
require 'brl/sites/omim'
require 'brl/genboree/kb/contentGenerators/generator'

module BRL ; module Genboree ; module KB ; module ContentGenerators
  class OmimGenerator < Generator
    
    # @return [String] Domain type string this Generator class can handle. See {BRL::Genboreee::KB::Validators::ModelValidator::DOMAINS}.
    DOMAIN_TYPE = 'omim'
    
    # @return [Hash<Symbol, Array<String>>] Map of {BRL::Sites::Omim} Symbol fields to known property names. (Less useful than {KNOWN_PROPS})
    KNOWN_FIELDS = {
      :title => [ 'Title', 'title' ],
      :otherTitles => [ 'Other Titles', 'Other titles', 'otherTitles', 'other titles' ],
      :references => [ 'References', 'references' ],
      :animalModel => [ 'Animal Model', 'Animal model', 'animalModel', 'animal model'],
      :biochemicalFeatures => [ 'Biochemical Features' ],
      :clinicalFeatures => [ 'Clinical Features' ],
      :clinicalManagement => [ 'Clinical Management' ],
      :cloning => [ 'Cloning' ],
      :cytogenetics => ["Cytogenetics"],
      :description => ["Description"],
      :diagnosis => ["Diagnosis"],
      :evolution => ["Evolution"],
      :geneFamily => ["Gene Family"],
      :geneFunction => ["Gene Function"],
      :geneStructure => ["Gene Structure"],
      :geneTherapy => ["Gene Therapy"],
      :geneticVariability => ["Genetic Variability"],
      :genotype => ["Genotype"],
      :genotypePhenotypeCorrelations => "Genotype/Phenotype Correlations",
      :heterogeneity => ["Heterogeneity"],
      :history => ["History"],
      :inheritance => ["Inheritance"],
      :mapping => ["Mapping"],
      :molecularGenetics => ["Molecular Genetics"],
      :nomenclature => ["Nomenclature"],
      :otherFeatures => ["Other Features"],
      :pathogenesis => ["Pathogenesis"],
      :phenotype => ["Phenotype"],
      :populationGenetics => ["Population Genetics"],
      :text => ["Text"],

      :status => [ 'Status', 'status' ],
      :contributors => [ 'Contributors', 'contributors' ],
      :editHistory => [ 'Edit History', 'Edit history', 'edit history', 'editHistory' ],
      :creationDate => [ 'Creation Date', 'Creation date', 'creation date', 'creationDate' ],
      :dateCreated => [ 'Date Created', 'Date created', 'date created', 'dateCreated' ],
      :dateUpdated => [ 'Date Updated', 'Date updated', 'date updated', 'dateUpdated' ]
    }

    # @return [Hash<String, Symbol>] Map of known property names to {BRL::Sites::Omim} Symbol fields.
    KNOWN_PROPS = KNOWN_FIELDS.inject({}) { |kps,kfs| kfs[1].each { |kp| kps[kp] = kfs[0] } ; kps }
   
    # Override in sub-class. Do any class-specific initialization.
    def init()
      # Override super.
    end
    
    # @abstract
    # @param [String] propPath Property path to property in {#doc} needing content
    # @param [Hash] content The content context noted by the validator as it visited the property.
    #   Contains keys :result, :pathElems, :propDef, :domainRec, :parsedDomain
    def addContentToProp(propPath, context)
      @generationErrors = []
      @generationWarnings = []
      # Get property value at propPath from doc.
      mimNumber = @doc.getPropVal(propPath)
      # Create Omim object from value of property. Class raises error for unknown omim ids.
      if(@genbConf.cachingProxyHost and @genbConf.cachingProxyPort)
        opts = { :proxyHost => @genbConf.cachingProxyHost, :proxyPort => @genbConf.cachingProxyPort }
      else
        opts = {}
      end
      omimRec = BRL::Sites::Omim.new(mimNumber, nil, opts) rescue nil 
      if(omimRec.nil?)
        raise OmimGeneratorError.new("Unable to complete request to #{BRL::Sites::Omim::HOST}.")
      end
      # Get property definition object from context (model info for this property)
      propDef = context[:propDef]
      if(propDef.acts_as?(Hash))
        # Examine property definition from the model. For each sub-property that is 'known' AND which is missing
        #   from the doc, try to add it.
        subPropDefs = propDef['properties']
        if(subPropDefs.acts_as?(Array))
          subPropDefs.each { |subPropDef|
            subPropName = subPropDef['name']
            # Is it a known property name?
            omimField = KNOWN_PROPS[subPropName]
            if(omimField)
              # Is the property variable? i.e. not 'fixed' or static / defined-at-model-time?
              unless(subPropDef['fixed'])
                # Does the doc have a non-nil, non-blank value for this sub property?
                subPropPath = "#{propPath}.#{subPropName}"
                subPropVal = @doc.getPropVal(subPropPath)
                unless(subPropVal and subPropVal.to_s =~ /\S/)
                  # Then set the value for the sub property to the appropriate Omim value
                  if(omimRec)
                    # handle complex objects returned by the omim library
                    # @todo the content generators need to be able to handle complex objects better
                    # maybe nested domains that have content generators? 
                    subPropVal = case omimField
                      when :references
                        omimRec[:references].nil? ? nil : omimRec[:references].collect{|xx| xx["source"]}.join("; ")
                      when :otherTitles
                        omimRec[:otherTitles].nil? ? nil : omimRec[:otherTitles].join(";; ")
                      else
                        omimRec[omimField]
                      end
                    subPropVal = "[unknown]" if(subPropVal.nil?)
                  else
                    subPropVal = "[unknown]"
                  end
                  @doc.setPropVal(subPropPath, subPropVal)
                end
              end
            end
          }
        end
      end
      return @doc
    end
  end # class Generator
  class OmimGeneratorError < RuntimeError; end
end ; end ; end ; end
