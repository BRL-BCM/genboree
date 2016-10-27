#!/usr/bin/env ruby
require 'json'
require 'brl/util/util'

module BRL ; module Graphics ; module D3
  # Helper methods for working with D3 Label-Value list data structures--the kind
  #   used by D3 donut, pie, bar, etc charts.
  class D3HierarchyHelpers
    # When internal (non-leaf) nodes have no size set--for e.g. when converted from a KB
    # partitioning transformation--can use this to populate the size of each node with the
    # SUM of sizes of all its direct children. Done via DFS, this means each node will have the sum
    # of all leaf node sizes below it.
    def self.addNodeSums(d3Hierarchy, defaultValue=0)
      if(d3Hierarchy['children'].is_a?(Array))
        d3Hierarchy['size'] = defaultValue unless(d3Hierarchy['size'])
        d3Hierarchy['children'].each { |child|
          d3Hierarchy['size'] += self.addNodeSums(child, defaultValue)
        }
        retVal = d3Hierarchy['size']
      else # No children node, must be leaf
        retVal = (d3Hierarchy['size'] or defaultValue)
      end
      return retVal
    end
  end
end ; end ; end
