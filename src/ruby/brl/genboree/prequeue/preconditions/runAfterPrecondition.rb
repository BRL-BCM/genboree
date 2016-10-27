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

module BRL ; module Genboree ; module Prequeue ; module Preconditions
  class RunAfterPrecondition < BRL::Genboree::Prequeue::Precondition
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    PRECONDITION_TYPE = "runAfterTime"

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [Time] after which the dependent job is allowed to run, as long as it hasn't expired.
    attr_accessor :runAfterTime

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
      @runAfterTime = nil
      super()
    end

    # @note GENBOREE INTERFACE METHOD (subclasses _should_ override)
    # Produce a basic structured Hash containing the core info in this Precondition
    # using Hashes, Arrays, and other core Ruby types and which are easy/fast to format
    # into string representations like JSON, YAML, etc.
    # Should be overridden in any subclass to clear out subclass-specific stuff, but make sure to call super()
    # first and then add sub-class specific stuff to the Hash that the parent method returns.
    # @return [Hash]
    def toStructuredData()
      structuredData = super()
      conditionSD = structuredData["condition"] = {}
      conditionSD["runAfterTime"] = @runAfterTime.to_s
      return structuredData
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHOD (subclasses _must_ implement)
    # Evaluate precondition and update whether precondition met or not.
    # @return [Boolean] indicating if condition met or not
    def evaluate()
      return (Time.now >= @runAfterTime)
    end

    # @abstract GENBOREE ABSTRACT INTERFACE METHOD (subclasses _must_ implement)
    # - Implement initCondition(arg) in sub-classes where arg is a condition hash spec
    #   containing keys and values the sub-class can correctly interpret and use to self-configure.
    # @param [Hash] conditionHash with the sub-class condition specification
    # @return [void]
    def initCondition(conditionHash)
      unless(conditionHash.nil?)
        runAfterTimeStr = conditionHash["runAfterTime"]
        @runAfterTime = Time.parse(runAfterTimeStr)
      end
      return @runAfterTime
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Prequeue ; module Preconditions
