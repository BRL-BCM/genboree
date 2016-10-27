#!/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'

module BRL ; module Genboree ; module KB ; module ContentGenerators
  class Generator

    # @return [Array<String>] Array of namespaces in which to look for generator sub-classes at load time.
    DEFAULT_RESOURCE_PATHS = [ "brl/genboree/kb/contentGenerators" ]
    # @return [String] Domain type string this Generator class can handle. See {BRL::Genboreee::KB::Validators::ModelValidator::DOMAINS}.
    DOMAIN_TYPE = nil

    attr_accessor :genbConf
    attr_accessor :contentNeeded
    attr_accessor :doc
    attr_accessor :collName
    attr_accessor :mdb
    attr_accessor :generationErrors
    attr_accessor :generationWarnings

    # @param [Hash] contentNeeded Hash of property paths to content needed record/context.
    # @param [KbDoc] doc Doc needing content added.
    # @param [String] collName Name of collection the doc is from.
    # @param [MongoKbDatabase] mdb A connected {MongoKbDatabase} which can be used to query
    #   collection, etc, as needed.
    def initialize(contentNeeded, doc, collName, mdb)
      @contentNeeded, @doc, @collName, @mdb = contentNeeded, doc, collName, mdb
      # Access to Genboree conf for proxy info and other settings
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      # Make sure @doc is a KbDoc for proper/easy manipulation
      @doc = BRL::Genboree::KB::KbDoc.new(@doc) unless(@doc.is_a?(BRL::Genboree::KB::KbDoc))
      @generationErrors = []
      @generationWarnings = []
      init()
    end

    # Override in sub-class. Do any class-specific initialization.
    def init()
      # In the generic parent class, instantiate each sub-class; will use to add content to property if needed
      #   - Class instance variable has been primed with generator sub-classes mapped by domain type
      #   - Instantiate each one with local state, and we have generator objects ready to work on doc.
      @generatorObjs = {}
      self.class.generators.each_key { |domainType|
        subClass = self.class.generators[domainType]
        generator = subClass.new(@contentNeeded, @doc, @collName, @mdb)
        @generatorObjs[domainType] = generator
      }
    end

    # Try to add all needed content to doc. This is a dispatcher which will
    #   call the addContentToProp() of the appropriate sub-class for each content
    #   needed record.
    # @return [Boolean] Indicating if content-generation went OK {true} without errors, or if problems were encountered {false}.
    def addContentToDoc()
      if(@contentNeeded.acts_as?(Hash))
        # Examine each property needing content
        @contentNeeded.each_key { |propPath|
          context = @contentNeeded[propPath]
          #$stderr.puts "Context: #{context.inspect}"
          # Determine which generator instance to use to handle this content context
          if(context.acts_as?(Hash))
            domainRec = context[:domainRec]
            #$stderr.puts "Domain Rec: #{domainRec.inspect}"
            if(domainRec.acts_as?(Hash))
              domainType = domainRec[:type]
              generatorObj = @generatorObjs[domainType]
              #$stderr.puts "domainType: #{domainType.inspect} ; generObj: #{generatorObj.inspect}"
              if(generatorObj)
                # Get the instance to add the content at this property in @doc.
                @doc = generatorObj.addContentToProp(propPath, context)
                # Capture any errors
                @generationErrors += generatorObj.generationErrors
              else
                @generationErrors << "ERROR: content generation context from validator indicates need to generate content for #{domainType.inspect} type domain. But no generator class or instance available to handle content generation for #{domainType.inspect} type domains."
              end
            else
              @generationErrors << "ERROR: content generation context from validator is missing a valid domain record entry for the :domainRec key in the context Hash for property #{propPath.inspect}."
            end
          else
            @generationErrors << "ERROR: content generation context from validator is missing for property #{propPath.inspect}"
          end
        }
      end
      return @generationErrors.empty?
    end

    # Clear state and aggressive clearing of @contentNeeded Hash to free records that
    #   were passed from Validator.
    def clear()
      @generationErrors.clear() rescue nil
      @generationWarning.clear() rescue nil
      @contentNeeded.clear() rescue nil
      @generatorObjs.clear() rescue nil
      @doc = @collName = @mdb = nil
    end

    # @abstract
    # @param [String] propPath Property path to property in {#doc} needing content
    # @param [Hash] content The content context noted by the validator as it visited the property.
    #   Contains keys :result, :pathElems, :propDef, :domainRec, :parsedDomain
    def addContentToProp(propPath, context)
      raise NotImplementedError, "ERROR: this class (#{self.class}) must implement the #{__method__}() method, but does not. Cannot be called as Generator#addContentToProp"
    end

    # ------------------------------------------------------------------------
    # AUTOMATIC SUB-CLASS DETECTION & LOADING (one-time)
    # ------------------------------------------------------------------------
    class << self
      # Set up class instance variables
      attr_accessor :resourcesLoaded, :generators
      Generator.resourcesLoaded = false
      # Maps domain type String to sub-class that can be used to add content for that kind of domain
      Generator.generators = {}
    end

    # Resource discovery: Find submitter & manager classes
    unless(Generator.resourcesLoaded or ((GenboreeRESTRackup rescue nil) and GenboreeRESTRackup.classDiscoveryDone[self]))
      # Mark resources as loaded (so doesn't try again).
      # Must set this first, else requires in the things we are about to require can unnecessarily ALSO
      #   try to discover resources when they are required (probably due to their "require'ing" this exact file,
      #   each such require of this file would trigger resource discovery [as we have seen], ouch!)
      #   Wastes a lot of time doing redundant discovery.
      Generator.resourcesLoaded = true
      # Record that we've done this class's discovery. Must do before start requiring.
      # - Must use already-defined global store of this info to prevent dependency requires while trying to define this class
      #   re-entering this discovery block over and over and over.
      (GenboreeRESTRackup.classDiscoveryDone[self] = true) if(GenboreeRESTRackup rescue nil)
      # Try to lazy-load (require) each file found in the resourcePaths.
      $LOAD_PATH.sort.each { |topLevel|
        if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
          DEFAULT_RESOURCE_PATHS.each { |rsrcPath|
            rsrcFiles = Dir["#{topLevel}/#{rsrcPath}/*.rb"]
            rsrcFiles.sort.each { |rsrcFile|
              begin
                require rsrcFile
              rescue Exception => err # just log error and try more files
                BRL::Genboree::GenboreeUtil.logError("ERROR: #{__FILE__} => failed to auto-require file '#{rsrcFile.inspect}'.", err)
              end
            }
          }
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "found content generator class files")
      # Find all the classes in BRL::Genboree::KB::ContentGenerators and
      #   identify those that inherit from BRL::Genboree::KB::ContentGenerators::Generators
      BRL::Genboree::KB::ContentGenerators.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::Genboree::KB::ContentGenerators.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::Genboree::Prequeue::Systems::Submitter
        if(const.is_a?(Class))
          # Is const a SUB-class we are interested in?
          if(const.ancestors.include?(BRL::Genboree::KB::ContentGenerators::Generator) and const != BRL::Genboree::KB::ContentGenerators::Generator)
            # Map the domain type String to the class.
            Generator.generators[const::DOMAIN_TYPE] = const
          end
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered content generators classes")
    end
  end # class Generator
end ; end ; end ; end
