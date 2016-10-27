#!/usr/bin/env ruby

require 'time'
require 'open-uri'
require 'brl/sites/abstractSite'

module BRL; module Sites

  # @todo omim fields link to other content by enclosing some reference within curly braces
  #   e.g. {6:Eagle and Barrett (1950)} links to a paper and {SNOMEDCT:87715008,56893005} 
  #   links to the SNOMEDCT ontology
  # @todo external links section
  # @todo folks at omim update mim numbers fairly frequently, api key registration says to
  #   update on our end every 2 weeks
  class Omim < AbstractSite
    HOST = "api.omim.org"
    PATH = "/api/entry"
    API_KEY_ENV_VAR = 'OMIM_API_KEY'
    DEFAULT_API_KEY = ENV[API_KEY_ENV_VAR]

    MIM_NUMBER = "mimNumber"
    API_KEY = "apiKey"
    FORMAT = "format"
    INCLUDE = "include"

    ENTRY_LIST = "omim.entryList.entry"
    # relative to entry
    TITLE = "titles.preferredTitle"
    OTHER_TITLES = "titles.alternativeTitles"

    # map fields to a description
    FIELD_LIST = {
      :title => "Title of the MIM entry",
      :otherTitles => "Alternative titles for the MIM entry",
      :references => "A list of references from the text sections"
    }

    TEXT_SECTION = "textSection"
    TEXT_SECTION_NAME = "textSectionName"
    TEXT_SECTION_LIST = "textSectionList"
    TEXT_SECTION_CONTENT = "textSectionContent"
    # map text section symbol to a description of that text section
    TEXT_SECTIONS = {
      :animalModel => "Animal Model",
      :biochemicalFeatures => "Biochemical Features",
      :clinicalFeatures => "Clinical Features",
      :clinicalManagement => "Clinical Management",
      :cloning => "Cloning",
      :cytogenetics => "Cytogenetics",
      :description => "Description",
      :diagnosis => "Diagnosis",
      :evolution => "Evolution",
      :geneFamily => "Gene Family",
      :geneFunction => "Gene Function",
      :geneStructure => "Gene Structure",
      :geneTherapy => "Gene Therapy",
      :geneticVariability => "Genetic Variability",
      :genotype => "Genotype",
      :genotypePhenotypeCorrelations => "Genotype/Phenotype Correlations",
      :heterogeneity => "Heterogeneity",
      :history => "History",
      :inheritance => "Inheritance",
      :mapping => "Mapping",
      :molecularGenetics => "Molecular Genetics",
      :nomenclature => "Nomenclature",
      :otherFeatures => "Other Features",
      :pathogenesis => "Pathogenesis",
      :phenotype => "Phenotype",
      :populationGenetics => "Population Genetics",
      :text => "Text (unfielded text section at the start of the entry)"
    }

    REFERENCE = "reference"
    REFERENCE_LIST = "referenceList"

    PROV_INFO = {
      :status => 'status',
      :contributors => 'contributors',
      :editHistory => 'editHistory',
      :creationDate => 'creationDate',
      :dateCreated => {
        :type => :date,
        :str => 'dateCreated',
        :epochNum => 'epochCreated'
      },
      :dateUpdated => {
        :type => :date,
        :str => 'dateUpdated',
        :epochNum => 'epochUpdated'
      }
    }

    attr_reader :mimNumber
    attr_reader :apiKey
    attr_reader :parsedBody
    attr_reader :entry
    attr_accessor :debug
    # @param [String, Fixnum] mimNumber the Mendelian Inheritance in Man accession number
    # @param [String] apiKey an API key for OMIM, may be filled via an environment variable 
    #   set by API_KEY_ENV_VAR instead
    # @see parent for information on setting up proxy cache
    def initialize(mimNumber, apiKey=nil, opts={})
      # be careful rearranging method orders here
      super(opts)
      @debug = ( opts[:debug] or false )
      @apiKey = setApiKey(apiKey)
      self.mimNumber=(mimNumber)
    end

    # Clean up instance variables between changes in mimNumber (and associated requests)
    def clean()
      @parsedBody = @entry = @references = @title = @otherTitles = nil
      @textSections = {}
      @provInfo = {}
    end

    def mimNumber=(mimNumber)
      @mimNumber = mimNumber
      request(@mimNumber)
      parseFields()
      return @mimNumber
    end

    def setApiKey(apiKey)
      @apiKey = (apiKey.nil? ? DEFAULT_API_KEY : apiKey)
      raise OmimError.new("NO_API_KEY: No API key was provided and the environment variable #{API_KEY_ENV_VAR} is not set!") if(@apiKey.nil?)
      return @apiKey
    end

    # Provide convenient access to fields of interest
    def [](field)
      retVal = nil
      if(@parsedBody)
        retVal =
          case field
          when :references
            @references
          when :title
            @title
          when :otherTitles
            @otherTitles
          when *PROV_INFO.keys
            @provInfo[field]
          when *TEXT_SECTIONS.keys()
            @textSections[field]
          else
            nil
          end
      end
      return retVal
    end

    # Describe which fields are available (somewhat determined by the mimNumber)
    # @param [TrueClass, FalseClass] descMap flag to include a description of fields
    # @return [Array, Hash] the list of known keys, as a Hash mapped to their description if descMap is true
    def keys(descMap=false)
      retVal = nil
      if(descMap)
        retVal = {}
        retVal.merge!(FIELD_LIST)
        retVal.merge!(TEXT_SECTIONS)
        retVal.merge!(PROV_INFO)
      else
        retVal = FIELD_LIST.keys() + textSections()
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPERS - Mainly for internal use by this class's methods
    # ------------------------------------------------------------------

    # Make a request to the HOST with the mimNumber
    def request(mimNumber=@mimNumber)
      query = {
        MIM_NUMBER => @mimNumber,
        API_KEY => @apiKey,
        FORMAT => "json",
        INCLUDE => "all"
      }
      url = buildUrl(HOST, PATH, query)
      requestWrapper(url)
    end

    # wrap OpenURI::open to handle errors as needed
    # set @parsedBody
    def requestWrapper(url, headers={})
      clean()
      begin
        $stderr.debugPuts(__FILE__, __method__, "OMIM", "making request at #{url}")
        open(url, headers){|ff|
          if(@debug)
            $stderr.debugPuts(__FILE__, __method__, "DEBUG", "headers:\n#{JSON.pretty_generate(ff.meta)}") if(@debug)
          end
          @parsedBody = JSON.parse(ff.read())
        }
      rescue ::OpenURI::HTTPError => err
        # host kind of communicates errors e.g. "The request sent by the client was syntactically 
        # incorrect" with nonsense mim number
        http_status_code, http_status_string = err.io.status
        $stderr.debugPuts(__FILE__, __method__, "OMIM_ERROR", "http_status_code=#{http_status_code}")
        $stderr.debugPuts(__FILE__, __method__, "OMIM_ERROR", "http_status_string=#{http_status_string}")
        $stderr.debugPuts(__FILE__, __method__, "OMIM_ERROR", "response body=#{err.io.string}")
        logError(err)
      end
      # @todo does host ever not respond with JSON when not 4xx or 5xx?
      return @parsedBody
    end

    # Fill in instance variables that are used to provide convenient [] access
    def parseFields()
      # library only accesses one mimNumber at a time
      @entry = getDotKey(@parsedBody, ENTRY_LIST)
      
      # provide access to text sections for this mimNumber
      @textSections = {}
      @entry[TEXT_SECTION_LIST].each_index{|ii|
        textSection = @entry[TEXT_SECTION_LIST][ii][TEXT_SECTION]
        textSectionName = textSection[TEXT_SECTION_NAME]
        @textSections[textSectionName.to_sym] = textSection[TEXT_SECTION_CONTENT]
      }

      # provide access to reference list for this mimNumber
      @references = @entry[REFERENCE_LIST].collect{|xx| xx[REFERENCE]}

      @title = getDotKey(@entry, TITLE)

      # provide access to provenance info for this mimNumber
      @provInfo = collectProvInfo(@entry)

      begin
        @otherTitles = getDotKey(@entry, OTHER_TITLES).gsub("\n", "").split(";;")
      rescue ArgumentError => err
        @otherTitles = []
      end

      return nil
    end

    def collectProvInfo(entryHash)
      provInfo = {}
      #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "entryHash keys: #{entryHash.keys.inspect}")
      PROV_INFO.each_key { |key|
        val = PROV_INFO[key]
        if(val.is_a?(Hash) and val[:type] == :date)
          # Try epoch date first
          eKey = val[:epochNum]
          #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "eKey 1 => #{eKey.inspect}")
          eVal = entryHash[eKey]
          #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "eVal 1 => #{eVal.inspect}")
          if( eVal.to_s =~ /^\d+$/)
            date = Time.at( eVal.to_i )
            #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "date 1 => #{date.inspect}")
          else # try str date
            eKey = val[:str]
            #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "eKey 2 => #{eKey.inspect}")
            eVal = entryHash[eKey]
            #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "eVal 2 => #{eVal.inspect}")
            date = Time.parse( eVal )  rescue nil
            #stderr.debugPuts(__FILE__, __method__, 'DEBUG', "date 2 => #{date.inspect}")
          end
          provInfo[key] = date.utc.rfc822 unless(date.nil?)
        else # regular string to use as key in entry
          provInfo[key] = entry[val]
        end
      }
      return provInfo
    end

    # List which text sections are available for this mimNumber
    def textSections()
      return @textSections.respond_to?(:keys) ? @textSections.keys() : []
    end

    # List which provenance sections are available for this mimNumber
    def provInfoFields()
      return @provInfo.respond_to?(:keys) ? @provInfo.keys() : []
    end

    # Accept mongo-style dot delimited strings specifying nested attributes for hashes
    #   if an array is encountered along the dotStr, take the first element
    # @param [Hash] hash the hash to get attribute specified in dotStr from
    # @param [String] dotStr a string specifying a nested attribute in hash
    # @return [Object] the item specified in dotStr
    # @raises [ArgumentError] if the item is not found
    # @todo move to BRL::Util?
    def getDotKey(hash, dotStr)
      retVal = nil
      delim = "."
      keyArray = dotStr.split(delim)
      # init loop
      item = hash[keyArray[0]]
      for ii in (1...keyArray.length) do
        raise ArgumentError, "no child item \"#{keyArray[ii]}\" for current item \"#{item.inspect}\"" unless(item and item.key?(keyArray[ii]))
        item = item[keyArray[ii]]
        item = item.first if(item.is_a?(Array))
      end
      retVal = item
      return retVal
    end

  end
  class OmimError < RuntimeError; end
end; end
