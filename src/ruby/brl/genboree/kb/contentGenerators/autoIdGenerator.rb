#!/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/kb/contentGenerators/generator'

module BRL ; module Genboree ; module KB ; module ContentGenerators
  class AutoIdGenerator < Generator
    
    # @return [String] Domain type string this Generator class can handle. See {BRL::Genboreee::KB::Validators::ModelValidator::DOMAINS}.
    DOMAIN_TYPE = 'autoID'

    # mapping from domain to BRL::Util::Util#xorDigest argument
    MODES = {
      "uniqNum" => :int,
      "uniqAlphaNum" => :alphaNum
    }
    # mapping from domain to instance methods for generating IDs of that domain
    OTHER_MODES = {
      "increment" => :getIncrementIds
    }
     
    # Override in sub-class. Do any class-specific initialization.
    def init()
      # Override super.
      @parentListKeys = Hash.new { |hh, kk| hh[kk] = {} }
    end
    alias :clean :init
    
    # @abstract
    # @param [String] propPath Property path to property in {#doc} needing content
    # @param [Hash] context The context noted by the validator as it visited the property.
    #   Minimally contains the keys 
    #   :parsedDomain [Hash] minimally with keys :prefix, :uniqMode, :suffix specifying the ID to generate
    #   :scope [:collection, :items] the scope required for ID uniqueness
    #   @see generateUnique for more detail
    # @raise [BRL::Genboree::KB::ContentGenerators::AutoIdGeneratorError] if unable to make unique id
    # @return [BRL::Genboree::KB::KbDoc] the modified document
    def addContentToProp(propPath, context)
      autoId = generateId(@collName, propPath, context[:parsedDomain], :scope => context[:scope])
      raise AutoIdGeneratorError.new("Unable to generate auto ID for propPath #{propPath.inspect} and context #{context.inspect}") if(autoId.nil?)

      # if no error, id is unique, add it
      @doc.setPropVal(propPath, autoId)
      return @doc
    end

    # Generate an ID (either "unique" or "increment") -- wrapper around generateUnique and getIncrementId
    # @param [String] collName the name of the collection
    # @param [String] propPath the BRL property path for the property
    # @param [Hash] pdom the parsed domain from BRL::Genboree::KB::Validators::ModelValidator::DOMAINS[{domain}][:parseDomain]
    # @param [Hash] opts optional parameters
    #   [Symbol] :scope either :collection or :items for the scope of unique IDs
    #   [Integer] :amount the number of incremental IDs
    # @note underlying private methods make use of instance variables ONLY to verify uniqueness of generated id --
    #   if not for that this could be used in any context
    def generateIds(collName, propPath, pdom, opts={})
      autoIds = []
      defaultOpts = {
        :scope => :collection,
        :amount => 1,
        :length => 6,
        :padding => true
      }
      params = defaultOpts.merge(pdom)
      opts = params.merge(opts)
      opts[:collName] = collName
      opts[:propPath] = propPath

      # Generate an autoID based on the pdom[:uniqMode]; default to "uniqAlphaNum" in MODES
      if(MODES.key?(pdom[:uniqMode]))
        autoId = generateUnique(opts)
        autoIds = [autoId]
      elsif(OTHER_MODES.key?(pdom[:uniqMode]))
        args = [opts]
        method = OTHER_MODES[pdom[:uniqMode]]
        autoIds = self.send(method, *args)
      else
        defaultMode = "uniqAlphaNum"
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Unrecognized pdom[:uniqMode]=#{pdom[:uniqMode].inspect}, defaulting to #{defaultMode.inspect}")
        opts[:uniqMode] = defaultMode
        autoId = generateUnique(opts)
        autoIds = [autoId]
      end

      return autoIds
    end

    # @see generateIds
    def generateId(collName, propPath, pdom, opts={})
      id = nil
      ids = generateIds(collName, propPath, pdom, opts)
      unless(ids.empty?)
        id = ids.first
      end
      return id
    end

    # --------------------------------------------------
    # Private methods
    # --------------------------------------------------

    # Generate a unique (not incremental) ID
    # @param [Hash] params named parameters:
    #   [String] :propPath KbDoc style property path to a property to generate a unique value for
    #   [String] :prefix an ID prefix to use at the beginning of the ID as in {prefix}-
    #   [Symbol] :uniqMode the type of ID to generate, mapping of KB-style terms to BRL-style by @see MODES, generateDynamic
    #   [String] :suffix an ID suffix to use at the end of the ID as in -{suffix}
    #   [:collection, :items] :scope the required scope for ID uniqueness
    #   [Fixnum] :length the String length of the dynamic portion of the ID to create;
    #     total ID length = prefix.size + "-".size + length + "-".size + suffix.size
    #   [String] :delim a delimiter to use to separate prefix, dynamic ID portion, and suffix
    #   [Fixnum] :maxAttempts the maximum attempts to try and generate a unique ID
    # @return [String, nil] the generated ID unique for the given scope or nil if no ID could be created
    def generateUnique(params)
      params = validateGenerateUniqueParams(params)
  
      # transform values from pdom to their associated ones in brl util
      params[:uniqMode] = MODES[params[:uniqMode]].nil? ? :alphaNum : MODES[params[:uniqMode]]

      unique = false
      attempt = 0
      while(!unique and attempt <= params[:maxAttempts]) do
        autoId = composeId(params)
        unique = case params[:scope]
          when :collection
            valueUniqInCollection?(autoId, params[:propPath])
          when :items
            valueUniqInParentList?(autoId, params[:propPath])
          else
            $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "unrecognized value for params[:scope] #{params[:scope].inspect}, using :collection")
            valueUniqInCollection?(autoId, params[:propPath])
          end
        attempt += 1
        params[:length] += 1
      end
      return unique ? autoId : nil
    end

    # For this class, generateUnique requires :prefix, :suffix, and :delim which its children do not require
    # @see generateUnique
    def validateGenerateUniqueParams(params)
      defaultValues = {
        :maxAttempts => 10,
        :scope => :collection,
        :length => 6
      }
      requiredParams = [:delim, :prefix, :propPath, :suffix]
      params = defaultValues.merge(params)
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)
      return params
    end

    # For an autoID of the "increment" mode, increment the counter 
    # @param [Hash] params named arguments
    #   [String] :collName the name of the collection that will have one of its autoID counters incremented
    #   [Boolean] :padding if true, pad the increment portion of the ID with 0s to compose
    #     a string of the length specified by @length@
    # @see generateUnique for :prefix, :suffix, :length, :delim, :propPath
    # @note autoID counters can be interpreted as "the last used ID or 0 if no such ID"
    # @return [Array<String>] identifiers whose middle part is AT LEAST @length@ (if increment counter exceeds
    #   max allowed by length e.g. 999999 for length=6, then length of middle part increases) or nil
    #   if an error occurred
    def getIncrementIds(params)
      params = validateIncIdsParams(params)

      autoIds = []
      mdh = @mdb.collMetadataHelper()
      prevCounter = mdh.updateCounter(params[:collName], params[:propPath], params[:amount])
      unless(prevCounter.nil?)
        params[:amount].times { |ii|
          incVal = prevCounter + ii + 1 # to use in the ID
          genPart = formatIncPart(incVal, params)
          autoId = composeIncId(genPart, params)
          autoIds.push(autoId)
        }
      end
  
      return autoIds
    end

    # For this class, getIncrementIds requires :prefix, :suffix, and :delim which its children do not require
    # @see getIncrementIds
    def validateIncIdsParams(params)
      defaultValues = {
        :amount => 1,
        :padding => true,
        :length => 6
      }
      params = defaultValues.merge(params)
      requiredParams = [:collName, :delim, :prefix, :propPath, :suffix]
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)
      return params
    end

    # Return nil instead of empty array if id generation fails
    # @see getIncrementIds
    def getIncrementId(params)
      rv = nil
      params = params.dup()
      params[:amount] = 1
      autoIds = getIncrementIds(params)
      unless(autoIds.empty?)
        rv = autoIds.first
      end
      return rv
    end

    def formatIncPart(incVal, params)
      genPart = nil
      if(params[:padding])
        genPart = sprintf("%0#{params[:length]}d", incVal)
      else
        genPart = incVal.to_s
      end
      return genPart
    end

    # Determine uniqueness for a value in a collection
    # @todo can users define properties whose name is exactly [\d+]?
    # @todo the mapping should definitely be outside this function in some general KB lib
    #   so that it is consistent later
    def valueUniqInCollection?(value, propPath)
      helper = @mdb.getHelper(@collName)
      if(helper.nil?)
        $stderr.debugPuts(__FILE__, __method__, "KB-ERROR", "Unable to retrieve database helper for collection #{@collName.inspect} and database #{@mdb.db.name.inspect}")
      end
      # map paths generated by the validator to paths that mongo is expecting
      pathElems = propPath.split(".")
      mongoPathElems = [pathElems[0]]
      pathElems[1...pathElems.size-1].each_index{|ii|
        xx = pathElems[ii]
        if(matchData = /\[(\d+)\]/.match(xx))
          # then BRL item list, skipping is same as to say for ALL items
        else
          # then BRL property, amend path
          mongoPathElems += ["properties", xx]
        end
      }
      mongoPathElems << "value"
      mongoPropPath = mongoPathElems.join(".")
      kbDoc = helper.docFromCollectionByFieldAndValue(value, mongoPropPath)
      return kbDoc.nil? ? true : false
    end

    # Determine uniqueness in an item list
    # @param [Object] value the object to check for uniqueness
    # @param [String] propPath the property path 
    # @param [Hash<String,Hash>] map property path to item list to ID values observed within it
    def valueUniqInParentList?(value, propPath, parentListKeys=@parentListKeys)
      retVal = false
      rsplitRet = BRL::Genboree::KB::KbDoc.rsplitItems(propPath)
      pathToLastList, pathWithinList = rsplitRet[:pathToLastList], rsplitRet[:pathWithinList]
      keyExist = parentListKeys[pathToLastList].key?(value)
      unless(keyExist)
        retVal = true
      end
      parentListKeys[pathToLastList][value] = nil
      return retVal
    end

    # Compose an ID (that may not be unique)
    # @param [Hash] params named arguments:
    #   :prefix
    #   :uniqMode
    #   :length
    #   :suffix
    #   :delim
    def composeId(params)
      requiredParams = [:prefix, :uniqMode, :length, :suffix, :delim]
      missingParams = requiredParams - params.keys
      raise ArgumentError.new("Missing required parameters: #{missingParams.join(", ")}") if(!missingParams.empty?)

      genPart = generateDynamic(params[:uniqMode], params[:length])
      autoId = [params[:prefix], genPart, params[:suffix]].join(params[:delim])
    end

    # @todo combine with composeId
    def composeIncId(genPart, params)
      autoId = [params[:prefix], genPart, params[:suffix]].join(params[:delim])
    end

    # @param [:full, :int, :alpha, :alphaNum, :alphaLower, :alphaUpper] mode an acceptable mode for brl/util/util xorDigest
    # @param [Fixnum] length the length of the id to generate
    # @return [String, NilClass] a unique ID to use or nil if unable to generate ID, most likely
    #   because we were given a bad mode
    def generateDynamic(mode, length=6)
      return String.generateUniqueString().xorDigest(length, mode) rescue nil
    end
  end # class Generator
  class AutoIdGeneratorError < RuntimeError; end
end ; end ; end ; end
