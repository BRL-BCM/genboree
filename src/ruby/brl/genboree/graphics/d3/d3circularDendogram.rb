#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/graphics/d3/d3dendogram'


module BRL; module Genboree; module Graphics; module D3
  
  # class for generating javaScript for rendering circular dendograms
  class D3CircularDendogram < D3Dendogram
    # Constructor
    # @param [#getD3DataType,#to_d3JsonData] d3DataObj @getD3DataType()@ should return a well known d3 data type {Symbol} [e.g :cluster]
    #   @to_d3JsonData()@ should return a D3 compatible json {String} 
    def initialize(d3DataObj)    
      super(d3DataObj)
      @requiresInitialScaling = false
      @longestLabel = d3DataObj.longestLabel
      diameter = ((d3DataObj.root.leaves.size * (@circleRadius*3.14*2 ))) / 3.14
      if(diameter > @diameter)
        @diameter = diameter
        @requiresInitialScaling = true
      end
    end
    
    # Constructs js based on dendogram type
    # @return [String] jsBuff
    def makeJS()
      if(@requiresInitialScaling)
        trueDiam = @diameter + (2 * (@longestLabel.size*14))
        initMatrix = [1, 0, 0, 1, @diameter / 2, ((@diameter / 2)-20)]
        scale = 950 / trueDiam
        initMatrix.size.times { |ii|
          initMatrix[ii] *= scale
        }
        initMatrix[4] += (1-scale)*500/2
        initMatrix[5] += (1-scale)*300/2
      else
        initMatrix = [1, 0, 0, 1, @diameter / 2, ((@diameter / 2)-20)]
        initMatrix[4] += 50
      end
      jsBuff = "
        /* Render code */ 
        var idSuf = Math.round(Math.random() * 1000) ;
        var diameter = #{@diameter};
        var tree = d3.layout.tree()
          .size([360, diameter / 2 - 120])
          .separation(function(a, b) { return (a.parent == b.parent ? 1 : 2) / a.depth; });
        var diagonal = d3.svg.diagonal.radial()
          .projection(function(d) { return [d.y, d.x / 180 * Math.PI]; });
        var detached =  d3.select(document.createElement(\"div\")) ;
        var svg = detached.append(\"svg\")
          .attr(\"id\", \"svg_\" + idSuf)
          .attr('style', \"height:700px; width:950px;z-index:-1;\") ; /* Should be the same as the container div */
        /*  .attr(\"viewbox\", \"100 100 \" + (diameter-140) + \" \" + diameter ) ; */
        
        var g1 = svg.append(\"g\")
            .attr(\"id\", \"svg_g_\" + idSuf)
            .attr(\"transform\", \"matrix(#{initMatrix.join(" ")})\");
        var root = JSON.parse('#{@d3root}') ;
        var nodes = tree.nodes(root), links = tree.links(nodes);
        
        var link = g1.selectAll(\".link\")
          .data(links)
          .enter().append(\"path\")
          .attr(\"class\", \"link\")
          .attr(\"d\", diagonal);
        
        var node = g1.selectAll(\".node\")
          .data(nodes)
          .enter().append(\"g\")
          .attr(\"class\", \"node\")
          .attr(\"transform\", function(d) { return \"rotate(\" + (d.x - 90) + \")translate(\" + d.y + \")\"; }) ;
        node.append(\"circle\")
          .attr(\"r\", #{@circleRadius});
        node.append(\"text\")
          .attr(\"dy\", \".25em\")
          .attr(\"text-anchor\", function(d) { return d.x < 180 ? \"start\" : \"end\"; })
          .attr(\"transform\", function(d) { return d.x < 180 ? \"translate(8)\" : \"rotate(180)translate(-8)\"; })
          .text(function(d) { return d.name; });
        var controlG = svg.append('g').attr(\"id\", \"svg_g_\"+idSuf+\"_2\") ;
        #{jsCodeForController}
        Ext.get('container').appendChild(detached.node()) ; 
      "
      return jsBuff
    end
  
  end
  
end; end; end; end