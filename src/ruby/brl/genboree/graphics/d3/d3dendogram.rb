#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/graphics/d3/d3'


module BRL; module Genboree; module Graphics; module D3
  
  # Intermediate class for generating D3 compatible javaScript functions for dendograms
  # Inherits from D3
  class D3Dendogram < D3
    # @return [String] D3 compatible json {String} corresponding to the entire tree
    attr_accessor :d3root
    # @return [Fixnum] diameter of the dendogram
    attr_accessor :diameter
    # @return [Fixnum] height of the dendogram
    attr_accessor :height
    # @return [Fixnum] width of the dendogram
    attr_accessor :width
    # @return [String] id of the container div where dendogram will be rendered
    attr_accessor :renderTo
    # @return [Fixnum] radius of the circle representing a node
    attr_accessor :circleRadius
    
    # Constructor
    # @param [#getD3DataType,#to_d3JsonData] d3DataObj @getD3DataType()@ should return a well known d3 data type {Symbol} [e.g :cluster]
    #   @to_d3JsonData()@ should return a D3 compatible json {String} 
    def initialize(d3DataObj)    
      super(d3DataObj)
      @d3root = d3DataObj.to_d3JsonData()
      setDefaults()
    end
    
    
    
    
    # Sets up some of the default options for drawing dendograms
    # @return [Boolean] indicating success
    def setDefaults()
      @diameter = 800
      @height = 600
      @width = 600
      @circleRadius = 4.5
      @renderTo = "container"
      return true
    end
    
    # Cleans up instance variables created in #setDefaults
    # @return [Boolean] indicating success
    def cleanup()
      @d3root = nil
      @height = nil
      @circleRadius = nil
      @width = nil
      @renderTo = nil
      return true
    end
  
  end
  
end; end; end; end
