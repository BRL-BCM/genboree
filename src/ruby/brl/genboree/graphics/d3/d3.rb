#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/util/util'


module BRL; module Genboree; module Graphics; module D3
  # Root class for generating (Data driven documents )D3-compatible javaScript functions
  class D3
    # Constructor
    # @param [#getD3DataType,#to_d3JsonData] d3DataObj @getD3DataType()@ should return a well known d3 data type {Symbol} [e.g :cluster]
    #   @to_d3JsonData()@ should return a D3 compatible json {String}
    # @raise [RuntimeError] when @d3DataObj@ does not implement @getD3DataType()@ and @to_d3JsonData()@
    def initialize(d3DataObj)    
      raise "Incorrect object type. Object must implement getD3DataType()" unless(d3DataObj.respond_to?(:getD3DataType) and d3DataObj.respond_to?(:to_d3JsonData))
    end
    
    # @abstract this method must be implemented by subclasses
    def makeJS()
      raise NotImplementedError, "Sub-class must implement this abstract method"
    end
    
    # @param [Fixnum] cx start x coordinate for controller mid point
    # @param [Fixnum] cy start y coordinate for controller mid point
    # @param [String] gid the id to set for the controller/compass g. Defaults to 'controllerG'.
    # @param [String] imageGroupId the gid of the g containing the image to pan/zoom. Defaults to first g in svg
    # @return [String] string containing static html for adding controller group in a svg
    def self.controller(cx=50, cy=50, gid="controllerG", imageGroupId=nil)
      imageG = (imageGroupId ? "'#{imageGroupId}'" : 'null')
      return "<defs><style type=\"text/css\">
                .compass{
                fill:  #fff;
                stroke:  #000;
                stroke-width:  1.5;
              }
              .svgButton{
                fill:  #225EA8;
                stroke:  #0C2C84;
                stroke-miterlimit:	6;
                stroke-linecap:  round;
              }
              .svgButton:hover{
                stroke-width:  2;
              }
              .svgPlusMinus{
                fill:  #fff;
                pointer-events: none;
              }
              </style></defs>
              <g id=#{gid}><circle r=\"42\" cx=\"#{cx}\" cy=\"#{cy}\" fill=\"white\" opacity=\"0.75\"/>
              <path class=\"svgButton\" onclick=\"pan(0,50,#{imageG})\" d=\"M#{cx} #{cy-40} l12 20 a40,70 0 0,0 -24,0z\"/>
              <path class=\"svgButton\" onclick=\"pan(50,0,#{imageG})\" d=\"M#{cx-40} #{cy} l20 -12 a70,40 0 0,0 0,24z\"/>
              <path class=\"svgButton\" onclick=\"pan(0,-50,#{imageG})\" d=\"M#{cx} #{cy+40} l12 -20 a40,70 0 0,1 -24,0z\"/>
              <path class=\"svgButton\" onclick=\"pan(-50,0,#{imageG})\" d=\"M#{cx+40} #{cy} l-20 -12 a70,40 0 0,1 0,24z\"/>
              <circle class=\"compass\" r=\"20\" cx=\"#{cx}\" cy=\"#{cy}\"/>
              <circle class=\"svgButton\" r=\"8\" cx=\"#{cx}\" cy=\"#{cy-9}\" onclick=\"zoom(1.25,#{imageG})\"/>
              <circle class=\"svgButton\" r=\"8\" cx=\"#{cx}\" cy=\"#{cy+9}\" onclick=\"zoom(0.8,#{imageG})\"/>
              <rect class=\"svgPlusMinus\" x=\"#{cx-4}\" y=\"#{cy-10.5}\" width=\"8\" height=\"3\"/>
              <rect class=\"svgPlusMinus\" x=\"#{cx-1.5}\" y=\"#{cy-12.5}\" width=\"3\" height=\"8\"/>
              <rect class=\"svgPlusMinus\" x=\"#{cx-4}\" y=\"#{cy+7.5}\" width=\"8\" height=\"3\"/>
              </g>
            "
      
    end
    
    # Assumes 'controlG' has been created
    # @return [String] string containing js code for adding controller group in a svg
    def jsCodeForController()
      return "controlG.append('circle')
          .attr('r', 42)
          .attr('cx', 50)
          .attr('cy', 50)
          .attr('fill', 'white')
          .attr('opacity', 0.75) ;
          
        controlG.append('path')
          .attr('class', 'svgButton')
          .attr('onclick', \"pan(0,50)\")
          .attr('d', \"M50 10 l12 20 a40,70 0 0,0 -24,0z\") ;
          
        controlG.append('path')
          .attr('class', 'svgButton')
          .attr('onclick', \"pan(50,0)\")
          .attr('d', \"M10 50 l20 -12 a70,40 0 0,0 0,24z\") ;
          
        controlG.append('path')
          .attr('class', 'svgButton')
          .attr('onclick', \"pan(0,-50)\")
          .attr('d', \"M50 90 l12 -20 a40,70 0 0,1 -24,0z\") ;
          
        controlG.append('path')
          .attr('class', 'svgButton')
          .attr('onclick', \"pan(-50,0)\")
          .attr('d', \"M90 50 l-20 -12 a70,40 0 0,1 0,24z\") ;
          
        controlG.append('circle')
          .attr('r', 20)
          .attr('cx', 50)
          .attr('cy', 50)
          .attr('class', 'compass') ;
          
        controlG.append('circle')
          .attr('r', 8)
          .attr('cx', 50)
          .attr('cy', 41)
          .attr('class', 'svgButton') 
          .attr('onclick', 'zoom(0.8)') ;
          
        controlG.append('circle')
          .attr('r', 8)
          .attr('cx', 50)
          .attr('cy', 59)
          .attr('class', 'svgButton')
          .attr('onclick', 'zoom(1.25)') ;
        
        controlG.append('rect')
          .attr('class', \"svgPlusMinus\")
          .attr('x', 46)
          .attr('y', 39.5)
          .attr('width', 8)
          .attr('height', 3) ;
          
        controlG.append('rect')
          .attr('class', \"svgPlusMinus\")
          .attr('x', 46)
          .attr('y', 57.5)
          .attr('width', 8)
          .attr('height', 3) ;
          
        controlG.append('rect')
          .attr('class', \"svgPlusMinus\")
          .attr('x', 48.5)
          .attr('y', 55)
          .attr('width', 3)
          .attr('height', 8) ; "
    end
  
  end
  
end; end; end; end
  
  
  
