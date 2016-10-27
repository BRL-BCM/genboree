#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/graphics/d3/d3dendogram'


module BRL; module Genboree; module Graphics; module D3
  
  # class for generating javaScript for rendering horizontal dendograms
  class D3HorizontalDendogram < D3Dendogram
    # Constructor
    # @param [#getD3DataType,#to_d3JsonData] d3DataObj @getD3DataType()@ should return a well known d3 data type {Symbol} [e.g :cluster]
    #   @to_d3JsonData()@ should return a D3 compatible json {String}  
    def initialize(d3DataObj)    
      super(d3DataObj)
      @requiresInitialScaling = false
      @longestLabel = d3DataObj.longestLabel
      height = d3DataObj.root.leaves.size * ((@circleRadius+10)*2)
      if(height > @height)
        @height = height
        @requiresInitialScaling = true
        @width = d3DataObj.maxDepth * 130 # Also scale the width
      end
    end
    
    # Constructs js based on dendogram type
    # @return [String] jsBuff
    def makeJS()
      if(@requiresInitialScaling)
        initMatrix = [1, 0, 0, 1, 35, 5]
        scale = (950 * 700) / (@height * @width)
        initMatrix.size.times { |ii|
          initMatrix[ii] *= scale
        }
        initMatrix[4] += (1-scale)*500/2
        initMatrix[5] += (1-scale)*300/2
      else
        initMatrix = [1, 0, 0, 1, 35, 5]
      end
      jsBuff = "
          
        
        /* Render code */
        var idSuf = Math.round(Math.random() * 1000) ;
        var width = #{@width} ;
        var height = #{@height} ;
        
        var cluster = d3.layout.cluster()
          .size([height, width - 160]);
        
        var diagonal = d3.svg.diagonal()
          .projection(function(d) {  return [d.y, d.x]; });
        
        var detached =  d3.select(document.createElement(\"div\")) ;
        
        var svg = detached.append(\"svg\")
          .attr('style', \"height:700px; width:950px;z-index:-1;\")  /* Should be the same as the container div */
          .attr(\"id\", \"svg_\"+idSuf) ;
          
        
        var g1 = svg.append(\"g\")
            .attr('id', \"svg_g_\"+idSuf)
            .attr(\"transform\", \"matrix(#{initMatrix.join(" ")})\");
        
        var nodes = cluster.nodes(JSON.parse('#{@d3root}')), links = cluster.links(nodes);
        
        var link = g1.selectAll(\".link\")
          .data(links)
          .enter().append(\"path\")
          .attr(\"class\", \"link\")
          .attr(\"d\", diagonal);

        var node = g1.selectAll(\".node\")
          .data(nodes)
          .enter().append(\"g\")
          .attr(\"class\", \"node\")
          .attr(\"transform\", function(d) { return \"translate(\" + d.y + \",\" + d.x + \")\"; }) ;

        node.append(\"circle\")
          .attr(\"r\", #{@circleRadius});

        node.append(\"text\")
          .attr(\"dx\", function(d) { return d.children ? -8 : 8; })
          .attr(\"dy\", 1.2)
          .style(\"text-anchor\", function(d) { return d.children ? \"end\" : \"start\"; })
          .text(function(d) { return d.name; });

        var controlG = svg.append('g').attr(\"id\", \"svg_g_\"+idSuf+\"_2\") ;
        #{jsCodeForController}
         Ext.get('container').appendChild(detached.node()) ; 
          "
      return jsBuff
    end
  
  end
  
end; end; end; end