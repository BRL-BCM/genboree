#!/usr/bin/env ruby
$VERBOSE = nil

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'time'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/prequeue/job'

module BRL ; module Genboree ; module Prequeue
  # @api BRL Ruby - prequeue
  # @api BRL RUby - preconditions
  # @see Job
  class Precondition
    #------------------------------------------------------------------
    # CLASS INSTANCE VARIABLES and ONE-TIME RESOURCE DISCOVERY
    #------------------------------------------------------------------

    # Set up class instance variables
    class << self
      # @return [Boolean] indicating whether class-level resources have been dynamically
      #   found and stored already or not. i.e. so they are done once per process.
      attr_accessor :resourcesLoaded
      # @return [Hash{String=>Precondition}] contains the set of {Precondition} subclasses
      #    keyed by their type String.
      attr_accessor :preconditionClasses
      Precondition.resourcesLoaded = false
      Precondition.preconditionClasses = {}
    end

    # Resource discovery: Find submitter & manager classes
    unless(Precondition.resourcesLoaded or ((GenboreeRESTRackup rescue nil) and GenboreeRESTRackup.classDiscoveryDone[self]))
      # Mark resources as loaded (so doesn't try again)
      Precondition.resourcesLoaded = true
      # Record that we've done this class's discovery. Must do before start requiring.
      # - Must use already-defined global store of this info to prevent dependency requires while trying to define this class
      #   re-entering this discovery block over and over and over.
      (GenboreeRESTRackup.classDiscoveryDone[self] = true) if(GenboreeRESTRackup rescue nil)
      # Try to lazy-load (require) each file found in the resourcePaths.
      $LOAD_PATH.sort.each { |topLevel|
        if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
          [ "brl/genboree/prequeue/preconditions/" ].each { |rsrcPath|
            rsrcFiles = Dir["#{topLevel}/#{rsrcPath}/*.rb"]
            rsrcFiles.sort.each { |rsrcFile|
              begin
                require rsrcFile
              rescue Exception => err # just log error and try more files
                BRL::Genboree::GenboreeUtil.logError("ERROR: #{__FILE__} => failed to require file '#{rsrcFile.inspect}'.", err)
              end
            }
          }
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "found precondion class files")
      # Find all the classes in BRL::Genboree::Prequeue::Preconditions and
      # identify those that inherit from BRL::Genboree::Prequeue::Precondition
      BRL::Genboree::Prequeue::Preconditions.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::Genboree::Prequeue::Preconditions.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::Genboree::Prequeue::Precondition
        if(const.is_a?(Class))
          # Is const a SUB-class we are interested in?
          if(const.ancestors.include?(BRL::Genboree::Prequeue::Precondition))
            Precondition.preconditionClasses[const::PRECONDITION_TYPE] = const
          end
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered precondition classes")
    end

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [BRL::Genboree::Prequeue::Job] the job having this Precondition
    attr_accessor :job
    # @return [Boolean] indicating whether precondition has been met or not
    attr_accessor :met
    # @return [Symbol] indicating type of precondition (and thus also determines Precondition sub-class).
    attr_accessor :type
    # @return [Time] object representing the time when the precondition expires
    attr_accessor :expires
    # @return [Boolean] indicating whether the precondition has expired or not
    attr_accessor :expired
    # @return [Array<Hash>] containing info/feedback records about the precondition
    attr_accessor :feedback
    # @return [Boolean] indicating whether a method (probably a subclass method) has added some appropriate feedback
    #   for this condition
    attr_accessor :feedbackSet
    # @return [Hash{Symbol,Object}] pre-check data generally prepared and provided by the PreconditionSet. Where suitable, the
    #   PreconditionSet containing this Precondition may perform some batch-queries and/or validation/context checks and provide the results here.
    #   These can be used to greatly shortcut the cost of evaluate() for each job, if the Precondition subclass
    #   knows to look and take advantage of this info.
    attr_accessor :preCheckInfo

    # ------------------------------------------------------------------
    # INTANCE METHODS
    # ------------------------------------------------------------------

    # @param [String] type indicating a precondition type for which there is a Precondition sub-class available
    # @param [Hash] conditionHash with the sub-class condition specification
    # @param [Time] expires representing the time when the precondition expires
    # @param [Boolean] met indicating whether precondition has been met or not
    # @param [Array] feedbackArray with any feedback Hash records about the precondition (if any)
    def initialize(job, type="job", conditionHash=nil, expires=(Time.now + Time::WEEK_SECS), met=false, feedbackArray=[])
      @job = job
      @type, @met = type, met
      @expires = (expires.is_a?(Time) ? expires : Time.parse(expires.to_s))
      @expired = (Time.now > @expires)
      @feedback = feedbackArray
      @feedbackSet = false  # Regardless of whether there is OLD feedback, we haven't set any new feedback since creating this object
      self.initCondition(conditionHash)
    end

    # Check the status of this precondition, evaluating its specific condition if needed.
    # @return [Boolean] if the condition is/was met (i.e. update & return the @met property)
    def check()
      # No need to update if already met
      unless(@met)
        # No met. Has expired?
        @expired = (Time.now > @expires)
        # If not expired, check the actual condition
        unless(@expired)
          # Call sub-class specific check() method which will assess status
          # of the precondition. Returns boolean if condition met or not.
          begin
            @met = evaluate()
          rescue => @err
            @met = false
            # Record error in @feedback Hash for trace purposes, unless already marked as set
            # (e.g. by specific subclass method or something)
            unless(@feedbackSet)
              @feedback = [] unless(@feedback.is_a?(Array))
              @feedback <<
              {
                'type' => 'internalError',
                'info' =>
                {
                  'class'     => @err.class,
                  'message'   => @err.message,
                  'backtrace' => @err.backtrace.join("\n")
                }
              }
            end
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Exception raised while checking job status. Cannot evaluate condition. Error message: #{@err.message.inspect}. Backtrace:\n#{@feedback.last['info']['backtrace']}")
          end
        end
      end
      return @met
    end

    # ------------------------------------------------------------------
    # GENBOREE INTERFACE METHODS
    # - Methods to be implemented by precondition sub-classes
    # ------------------------------------------------------------------

    # @note GENBOREE INTERFACE METHOD (subclasses _should_ override)
    # Clears the state, stored data, and other info from this object.
    # Should be overridden in any subclass to clear out subclass-specific stuff, but make sure to call super()
    # so parent stuff gets cleaned too.
    # @return [void]
    def clear()
      @job = nil
      @type = nil
    end

    # @note GENBOREE INTERFACE METHOD (subclasses _should_ override)
    # Produce a basic structured Hash containing the core info in this Precondition
    # using Hashes, Arrays, and other core Ruby types and which are easy/fast to format
    # into string representations like JSON, YAML, etc.
    # Should be overridden in any subclass to clear out subclass-specific stuff, but make sure to call super()
    # first and then add sub-class specific stuff to the Hash that the parent method returns.
    # @return [Hash]
    def toStructuredData()
      structuredData = {}
      structuredData["met"]      = @met
      structuredData["type"]     = @type
      structuredData["expires"]  = @expires.to_s
      structuredData["feedback"] = @feedback if(@feedback.is_a?(Array) and !@feedback.empty?)
      return structuredData
    end

    # @note GENBOREE INTERFACE METHOD (usually _not_ overridden)
    # Produce a JSON representation of this Precondition; i.e. as a structured data representation.
    # @return [String] in JSON format, reprenting this Precondition
    def to_json()
      structuredData = self.toStructuredData()
      return structuredData.to_json()
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHOD (subclasses _must_ implement)
    # Evaluate precondition and update whether precondition met or not.
    # @return [Boolean] indicating if condition met or not
    def evaluate()
      raise NotImplementedError, "BUG: This class #{self.class} has a bug. The author did not implement the required '#{__method__}()' method."
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHOD (subclasses _must_ implement)
    # - Implement initCondition(arg) in sub-classes where arg is a condition hash spec
    #   containing keys and values the sub-class can correctly interpret and use to self-configure.
    # @param [Hash] conditionHash with the sub-class condition specification
    # @return [void]
    def initCondition(conditionHash)
      raise NotImplementedError, "BUG: This class #{self.class} has a bug. The author did not implement the required '#{__method__}()' method."
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Prequeue
