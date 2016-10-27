#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/graphics/d3/d3dendogram'


module BRL; module Genboree; module Graphics; module D3
  # class for generating javaScript for rendering collapsible horizontal dendograms
  class D3HorizontalDendogramCollapsible < D3Dendogram
    attr_accessor :toggleType
    # Constructor
    # @param [#getD3DataType,#to_d3JsonData] d3DataObj @getD3DataType()@ should return a well known d3 data type {Symbol} [e.g :cluster]
    #   @to_d3JsonData()@ should return a D3 compatible json {String} 
    def initialize(d3DataObj)    
      super(d3DataObj)
      @d3DataObj = d3DataObj
      @toggleType = 'expandAll'
      @requiresInitialScaling = false
    end
    
    # Constructs js based on dendogram type
    # @return [String] jsBuff
    def makeJS()
      expandRootWithChildrenJs = "
        root.children.forEach(toggleAll);
        for(var ii=0; ii<root.children.length;ii++)
        {
          toggle(root.children[ii]) ;
        }
      "
      expandNodes = (@toggleType != 'expandAll' ? expandRootWithChildrenJs : "")
      initMatrix = [1, 0, 0, 1, 120, 20]
      if(@toggleType == 'expandAll')
        height = @d3DataObj.root.leaves.size * ((@circleRadius+10)*2)
        if(height > @height)
          @height = height
          @requiresInitialScaling = true
          @width = @d3DataObj.maxDepth * 130 # Also scale the width
        end
        if(@requiresInitialScaling)
          scale = (900 * 750) / (@width * @height)
          initMatrix.size.times { |ii|
            initMatrix[ii] *= scale
          }
          initMatrix[4] += (1-scale)*500/2
          initMatrix[5] += (1-scale)*300/2
        end  
      end
      jsBuff = "
        
          /* Render code */
          var m = [20, 120, 20, 120],
          w = (#{@width+150}) - m[1] - m[3],
          h = (#{@height}) - m[0] - m[2],
          i = 0,
          root ;
          var idSuf = Math.round(Math.random() * 1000) ;
          var tree = d3.layout.tree()
            .size([h, w]);
          
          var diagonal = d3.svg.diagonal()
            .projection(function(d) { return [d.y, d.x]; });
          
          var vis = d3.select(\"##{@renderTo}\").append(\"svg:svg\")
              .attr(\"id\", \"svg_\"+idSuf)  
              .attr(\"width\", 950)
              .attr(\"height\", 700)
            .append(\"svg:g\")
              .attr(\"id\", \"svg_g_\"+idSuf)
              .attr(\"transform\", \"matrix(#{initMatrix.join(" ")})\");
          
          root = JSON.parse('#{@d3root}');
          root.x0 = h / 2;
          root.y0 = 0;
        
          function toggleAll(d) {
            if (d.children) {
              d.children.forEach(toggleAll);
              toggle(d);
            }
          }
        
          #{expandNodes}
        
          update(root);
          
          var controlG = d3.select(\"svg#svg_\"+idSuf).append('g').attr(\"id\", \"svg_g_\"+idSuf+\"_control\") ;
          #{jsCodeForController}        
          function update(source) {
            var duration = d3.event && d3.event.altKey ? 5000 : 500;
          
            var nodes = tree.nodes(root).reverse();
          
            nodes.forEach(function(d) { d.y = d.depth * 180; });
          
            var node = vis.selectAll(\"g.node\")
                .data(nodes, function(d) { return d.id || (d.id = ++i); });
          
            var nodeEnter = node.enter().append(\"svg:g\")
                .attr(\"class\", \"node\")
                .attr(\"transform\", function(d) { return \"translate(\" + source.y0 + \",\" + source.x0 + \")\"; })
                .on(\"click\", function(d) { toggle(d); update(d); });
          
            nodeEnter.append(\"svg:circle\")
                .attr(\"r\", 1e-6)
                .style(\"fill\", function(d) { return d._children ? \"lightsteelblue\" : \"#fff\"; });
          
            nodeEnter.append(\"svg:text\")
                .attr(\"x\", function(d) { return d.children || d._children ? -10 : 10; })
                .attr(\"dy\", \".30em\")
                .attr(\"text-anchor\", function(d) { return d.children || d._children ? \"end\" : \"start\"; })
                .text(function(d) { return d.name; })
                .style(\"fill-opacity\", 1e-6);
          
            var nodeUpdate = node.transition()
                .duration(duration)
                .attr(\"transform\", function(d) { return \"translate(\" + d.y + \",\" + d.x + \")\"; });
          
            nodeUpdate.select(\"circle\")
                .attr(\"r\", #{@circleRadius})
                .style(\"fill\", function(d) { return d._children ? \"lightsteelblue\" : \"#fff\"; });
          
            nodeUpdate.select(\"text\")
                .style(\"font-size\", \"0.66em\")
                .style(\"fill-opacity\", 1);
          
            var nodeExit = node.exit().transition()
                .duration(duration)
                .attr(\"transform\", function(d) { return \"translate(\" + source.y + \",\" + source.x + \")\"; })
                .remove();
            
            if(nodeExit[0].length != 0)
            {
              nodeExit.select(\"circle\")
                .attr(\"r\", 1e-6);
              nodeExit.select(\"text\")
                .style(\"fill-opacity\", 1e-6);
            }
          
            var link = vis.selectAll(\"path.link\")
                .data(tree.links(nodes), function(d) { return d.target.id; });
          
            link.enter().insert(\"svg:path\", \"g\")
                .attr(\"class\", \"link\")
                .attr(\"d\", function(d) {
                  var o = {x: source.x0, y: source.y0};
                  return diagonal({source: o, target: o});
                })
              .transition()
                .duration(duration)
                .attr(\"d\", diagonal);
          
            link.transition()
                .duration(duration)
                .attr(\"d\", diagonal);
          
            link.exit().transition()
                .duration(duration)
                .attr(\"d\", function(d) {
                  var o = {x: source.x, y: source.y};
                  return diagonal({source: o, target: o});
                })
                .remove();
          
            nodes.forEach(function(d) {
              d.x0 = d.x;
              d.y0 = d.y;
            });
          }
          
          function toggle(d) {
            if (d.children) {
              d._children = d.children;
              d.children = null;
            } else {
              d.children = d._children;
              d._children = null;
            }
          }
          
      "
      return jsBuff
    end
  
  end
  
end; end; end; end