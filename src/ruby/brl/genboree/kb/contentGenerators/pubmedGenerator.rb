#!/bin/env ruby

# Ensure this is done before attempting activesupport's core_ext stuff! Else issues.
require 'brl/activeSupport/activeSupport'
require 'active_support/core_ext/string'
require 'brl/util/util'
require 'brl/sites/pubmed'
require 'brl/genboree/kb/contentGenerators/generator'

module BRL ; module Genboree ; module KB ; module ContentGenerators
  class PubmedGenerator < Generator
    
    # @return [String] Domain type string this Generator class can handle. See {BRL::Genboreee::KB::Validators::ModelValidator::DOMAINS}.
    DOMAIN_TYPE = 'pmid'

    # Create typical aliases from 1+ snake-string (underscore) inputs.
    #   Not a substitute for composing full set of user-oriented aliases,
    #   just a helper to make some of the typical variants.
    # @param [Array<String>] *snakeStrs One or more snake strings from which
    #   to make a set of aliases. Presumed themselves to be aliases, albeit
    #   materially different looking.
    # @return [Array<String>] The set of alias strings for the input(s).
    # @note must be defined before KNOWN_FIELDS
    def self.aliases(*snakeStrs)
        retVal = []
        snakeStrs.each { |snakeStr|
          camel = snakeStr.camelcase
          human = snakeStr.titlecase
          # snakecase variants
          retVal << snakeStr
          retVal << snakeStr.titlecase.tr(' ', '_')
          # camelcase variants
          retVal << camel
          retVal << camel.decapitalize
          # human variants
          retVal << human = snakeStr.titlecase
          retVal << snakeStr.tr('_', ' ')
        }
        return retVal.uniq
    end
    
    # Allowed fields for the content generator to access through the Pubmed object:
    #   the object supports access to more complex objects but we restrict it here to be
    #   only a list of strings or a string so that the values can fit nicely into KB documents
    # @return [Hash<Symbol, Array<String>>] Map of {BRL::Sites::Pubmed} Symbol fields to known property names. (Less useful than {KNOWN_PROPS})
    KNOWN_FIELDS = {
      :abstract         => [ 'Abstract', 'abstract' ],
      :authorsStr       => [ 'Authors', 'authors' ],
      :citationStr      => [ 'Citation', 'citation' ],
      :doi              => [ 'doi', "DOI" ],
      :doiPubUrl        => aliases("DOI_pub_url", "doi_pub_url"),
      :doiMetaUrl       => aliases("DOI_meta_url", "DOI_metadata_url", "doi_meta_url", "doi_metadata_url"),
      :grants           => [ 'Grants', 'grants' ],
      :issueNumber      => [ 'Issue', 'Iss', 'issue', 'iss' ],
      :journalAbbrv     => [ 'Journal Abbrv', 'Journal', 'journal abbrv', 'journal', 'journalAbbrv' ],
      :journalStr       => [ 'Journal Ref', 'journal ref', 'journalRef' ],
      :journalTitle     => [ 'Journal Title', 'Journal Name', 'journal title', 'journal name', 'journalTitle', 'journalName' ],
      :locationId       => [ 'Location Id', 'location id', 'locationId' ],
      :meshHeadings     => aliases("mesh_headings", "mesh_keywords"),
      :ontologyStr      => aliases("ontology_terms"),
      :pages            => [ 'Pages', 'Pgs', 'pages', 'pgs' ],
      :pmcid            => [ "PMC", "pmc", "PMCID", "pmcid" ],
      :pmid             => [ 'PMID', 'pmid' ],
      :publicationDate  => [ 'Publication Date', 'Pub Date', 'publication date', 'publicationDate', 'pub date', 'pubDate' ],
      :title            => [ 'Article Title', 'Title', 'article title', 'title', 'articleTitle' ], 
      :url              => [ "URL", "url" ] + aliases("pubmed_url", "pubmed_URL"),
      :volumeNumber     => [ 'Volume', 'Vol', 'volume', 'vol' ]
    }
    # @return [Hash<String, Symbol>] Map of known property names to {BRL::Sites::Pubmed} Symbol fields.
    KNOWN_PROPS = KNOWN_FIELDS.inject({}) { |kps,kfs| kfs[1].each { |kp| kps[kp] = kfs[0] } ; kps }
          
    # Override in sub-class. Do any class-specific initialization.
    def init()
      # Overridden.
    end
    
    # @abstract
    # @param [String] propPath Property path to property in {#doc} needing content
    # @param [Hash] content The content context noted by the validator as it visited the property.
    #   Contains keys :result, :pathElems, :propDef, :domainRec, :parsedDomain
    # @return [KbDoc] The modified doc, to which properties/values may have been added. Generally
    #   NOT a new object but same @doc passed in by pointer. 
    def addContentToProp(propPath, context)
      @generationErrors = []
      @generationWarnings = []
      # Get property value at propPath from doc.
      pmid = @doc.getPropVal(propPath)
      # Create Pubmed object from value of property. Class raises error for unknown pubmed ids.
      if(@genbConf.cachingProxyHost and @genbConf.cachingProxyPort)
        opts = { :proxyHost => @genbConf.cachingProxyHost, :proxyPort => @genbConf.cachingProxyPort }
      else
        opts = {}
      end
      pubmedRec = BRL::Sites::Pubmed.new(pmid, opts) rescue nil
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
            pubmedField = KNOWN_PROPS[subPropName]
            if(pubmedField)
              # Is the property variable? i.e. not 'fixed' or static / defined-at-model-time?
              unless(subPropDef['fixed'])
                # Does the doc have a non-nil, non-blank value for this sub property?
                subPropPath = "#{propPath}.#{subPropName}"
                subPropVal = @doc.getPropVal(subPropPath)
                unless(subPropVal and subPropVal.to_s =~ /\S/)
                  # Then set the value for the sub property to the appropriate Pubmed value
                  if(pubmedRec)
                    # transform subPropVal to a string so it can be validated by kb doc
                    subPropVal = pubmedRec[pubmedField]
                    if(subPropVal.is_a?(Array))
                      subPropVal = subPropVal.join(", ")
                    elsif(subPropVal.is_a?(String))
                      # do nothing
                    elsif(subPropVal.nil?)
                      # coerce to String, but no cause for alarm
                      subPropVal = subPropVal.to_s
                    else 
                      # @todo cases printing this message should be considered and probably changed
                      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Coercing value of type #{subPropVal.class} for pubmedField=#{pubmedField.inspect} into a String!")
                      subPropVal = subPropVal.to_s
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
end ; end ; end ; end
