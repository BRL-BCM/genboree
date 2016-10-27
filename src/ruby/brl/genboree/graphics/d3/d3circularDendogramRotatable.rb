#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'brl/genboree/graphics/d3/d3dendogram'


module BRL; module Genboree; module Graphics; module D3
  # class for generating javaScript for rendering rotatable circular dendograms
  class D3CircularDendogramRotatable < D3Dendogram
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
      rx = @diameter / 2
      ry = @diameter / 2
      if(@requiresInitialScaling)
        trueDiam = @diameter + (2 * (@longestLabel.size*14))
        initMatrix = [1, 0, 0, 1, rx, ry]
        scale = 950 / trueDiam
        initMatrix.size.times { |ii|
          initMatrix[ii] *= scale
        }
        initMatrix[4] += (1-scale)*500/2;
        initMatrix[5] += (1-scale)*300/2;
        initMatrix[5] -= 100 
      else
        initMatrix = [1, 0, 0, 1, rx, ry]
      end
      jsBuff = "
        
        function mouse(e) {
          return [e.pageX - rx, e.pageY - ry];
        }
        
        function mousedown() {
          m0 = mouse(d3.event);
          d3.event.preventDefault();
        }
        
        function mousemove() {
          if (m0) {
            var m1 = mouse(d3.event),
              dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI,
              tx = \"translate3d(0,\" + (ry - rx) + \"px,0)rotate3d(0,0,0,\" + dm + \"deg)translate3d(0,\" + (rx - ry) + \"px,0)\";
            svg
              .style(\"-moz-transform\", tx)
              .style(\"-ms-transform\", tx)
              .style(\"-webkit-transform\", tx);
          }
        }
      
        function mouseup() {
          var svg = d3.select(\"svg\") ;
          var transMatrix = getTransMatrix(svg) ;
          if (m0) {
            var m1 = mouse(d3.event),
              dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI,
              tx = \"rotate3d(0,0,0,0deg)\";
        
            rotate += dm;
            if (rotate > 360) rotate -= 360;
            else if (rotate < 0) rotate += 360;
            m0 = null;
        
            svg
              .style(\"-moz-transform\", tx)
              .style(\"-ms-transform\", tx)
              .style(\"-webkit-transform\", tx);
        
            vis
              .attr(\"transform\", \"matrix(\"+transMatrix.join(' ')+\")rotate(\" + rotate + \")\")
              .selectAll(\"g.node text\")
                .attr(\"dx\", function(d) { return (d.x + rotate) % 360 < 180 ? 8 : -8; })
                .attr(\"text-anchor\", function(d) { return (d.x + rotate) % 360 < 180 ? \"start\" : \"end\"; })
                .attr(\"transform\", function(d) { return (d.x + rotate) % 360 < 180 ? null : \"rotate(180)\"; });
          }
        }
        
        function cross(a, b) {
          return a[0] * b[1] - a[1] * b[0];
        }
        
        function dot(a, b) {
          return a[0] * b[0] + a[1] * b[1];
        }
        
        /* Render code */
        var w = #{@diameter},
        h = #{@diameter},
        rx = w / 2,
        ry = h / 2,
        m0,
        rotate = 0;
        var idSuf = Math.round(Math.random() * 1000) ;
        var cluster = d3.layout.cluster()
          .size([360, ry - 120])
          .sort(null);
        
        var diagonal = d3.svg.diagonal.radial()
          .projection(function(d) { return [d.y, d.x / 180 * Math.PI]; });
        
        var svg = d3.select(\"##{@renderTo}\") ;
        
        var vis = svg.append(\"svg:svg\")
          .attr(\"id\", \"svg_\"+idSuf)
          .attr(\"style\", \"z-index:-1; width:950px; height:700px;\")
          .append(\"svg:g\")
            .attr(\"id\", \"svg_g_\"+idSuf)
            .attr(\"transform\", \"matrix(#{initMatrix.join(" ")})\") ;
        vis.append(\"path\")
          .attr(\"class\", \"arc\")
          .attr(\"d\", d3.svg.arc().innerRadius(ry - 120).outerRadius(ry).startAngle(0).endAngle(2 * Math.PI))
            .on(\"mousedown\", mousedown);

        var nodes = cluster.nodes(JSON.parse('#{@d3root}'));
      
        var link = vis.selectAll(\"path.link\")
          .data(cluster.links(nodes))
          .enter().append(\"svg:path\")
            .attr(\"class\", \"link\")
            .attr(\"d\", diagonal);
      
        
        var node = vis.selectAll(\"g.node\")
          .data(nodes)
          .enter().append(\"svg:g\")
            .attr(\"class\", \"node\")
            .attr(\"transform\", function(d) { return \"rotate(\" + (d.x - 90) + \")translate(\" + d.y + \")\"; }) ;
      
        node.append(\"svg:circle\")
          .attr(\"r\", #{@circleRadius});
      
        node.append(\"svg:text\")
          .attr(\"dx\", function(d) { return d.x < 180 ? 8 : -8; })
          .attr(\"dy\", \".31em\")
          .attr(\"text-anchor\", function(d) { return d.x < 180 ? \"start\" : \"end\"; })
          .attr(\"transform\", function(d) { return d.x < 180 ? null : \"rotate(180)\"; })
          .text(function(d) { return d.name; });
      
        d3.select(window)
          .on(\"mousemove\", mousemove)
          .on(\"mouseup\", mouseup);
          
        var controlG = d3.select(\"svg#svg_\"+idSuf).append('g').attr(\"id\", \"svg_g_\"+idSuf+\"_control\") ;
        #{jsCodeForController()}
          
        
        
      "
      return jsBuff
    end
  
  end
  
end; end; end; end