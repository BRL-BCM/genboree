#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'Newick'
require 'json'
require 'brl/util/util'
require 'brl/dataStructure/cache' # for CacheObject wrapper and CacheError exception class

# @author Andrew R Jackson

module BRL ; module DataStructure

  # An extended version of jhbadger's Newick-ruby NewickTree class.
  # @note Requires the @newick-ruby@ gem be installed
  #   https://github.com/jhbadger/Newick-ruby for example or @gem install newick-ruby@
  # @note Originally motivated mainly by desire to dump Newick as a d3-supported JSON str
  #   https://github.com/mbostock/d3/wiki
  class NewickTree < ::NewickTree
    attr_accessor :labelMap # Map for mapping newick names to actual entity names
    attr_accessor :longestLabel
    
    # Get depth of node in this tree.
    # @param [::NewickNode] newickNode The node for which to get the depth. Must be a ::NewickNode.
    # @retur [Fixnum] The depth of the node
    def nodeDepth(newickNode)
      return newickNode.nodesToAncestor(self.root)
    end

    # Get the maximum depth to a leaf in the tree. Also known as the tree's height.
    # @return [Fixnum] The height of the tree.
    def maxDepth()
      retVal = -1
      self.root.leaves.each { |leaf|
        depth = leaf.nodesToAncestor(self.root).size
        retVal = depth if(retVal < depth)
      }
      return retVal
    end
    
    alias :height :maxDepth
    
    

    # Convert the @NewickTree@ instance to a d3-compatible cluster tree layout data structure. Really
    #   just a {Hash} of {Hash}es which mirrors d3's cluster layout JSON format. This method is
    #   implemented through breadth-first search using a queue.
    # @param [Hash] opts A {Hash} with options for how to set :size, :value, and :separation in
    #   the d3 representation
    # @return [Hash] a {Hash} of {Hash}es which mirrors d3's cluster layout JSON format. Each node is
    #   a {Hash} with the keys @:name@, @:size@, @:value@, and @:separation@. The root node is returned.
    def convertToD3Cluster(opts={:edgeLenAsSize=>true, :edgeLenAsValue=>true, :edgeLenAsSeparation=>true})
      # Init the root of the d3 cluster tree layout
      d3root = {}
      d3root[:newickNode] = self.root
      # Breadth-first visit of the newick tree (self) via a queue
      # - build d3 hash of hashes as we visit
      queue = [ d3root ]
      validLabelMapExists = false
      if(@labelMap and @labelMap.is_a?(Hash))
        validLabelMapExists = true
      end
      while(!queue.empty?) do
        # visit next node in queue
        currD3node = queue.shift
        # as part of visit, set properties of this d3 node, mainly from the corresponding NewickNode
        newickNode = currD3node[:newickNode]
        nodeName = nil
        unless(validLabelMapExists) # Replace newick node name with entity name if map exists
          nodeName = newickNode.name
        else
          nodeName = (@labelMap[newickNode.name] || newickNode.name)
        end
        nodeName.strip!
        if(@longestLabel)
          @longestLabel = (@longestLabel.size < nodeName.size ? nodeName : @longestLabel)
        else
          @longestLabel = nodeName 
        end
        currD3node[:name] = nodeName.gsub(/;$/, '')
        currD3node[:size]       = newickNode.edgeLen  if(opts[:edgeLenAsSize])
        currD3node[:separation] = newickNode.edgeLen  if(opts[:edgeLenAsSeparation])
        currD3node[:value]      = newickNode.edgeLen  if(opts[:edgeLenAsValue])
        if(!currD3node[:newickNode].children.nil? and !currD3node[:newickNode].children.empty?)
          currD3node[:children] = []
          # schedule the children nodes for visits
          currD3node[:newickNode].children.each { |child|
            childNode = {}
            childNode[:newickNode] = child
            currD3node[:children] << childNode
            queue.push(childNode)
          }
        end
        # all done with corresponding NewickNode for *this* d3 node, clean it up
        currD3node.delete(:newickNode)
      end
      return d3root
    end

    # @api D3 Interface
    # @see {convertToD3Cluster}
    # @param [Hash{Symbol=>Boolean}] opts  As described in {#convertToD3Cluster} but with the additional supported key @:prettify@ which can be used to get more human-readable JSON (using newlines and nesting)
    # @option opts [Symbol] :prettify
    # @option opts [Symbol] :edgeLenAsSize
    # @option opts [Symbol] :edgeLenAsValue
    # @option opts [Symbol] :edgeLenAsSeparation
    # @return [String] JSON representation of output generated from #convertToD3Cluster
    def to_d3JsonData(opts={:prettify=>false, :edgeLenAsSize=>true, :edgeLenAsValue=>true, :edgeLenAsSeparation=>true})
      d3root = convertToD3Cluster(opts)
      if(d3root.nil?)
        retVal = nil
      else # make JSON String
        # Need to use more suitable max_nesting setting (default will cause JSON lib crash in many cases)
        # - obj.children.idx suggests at least 3 * max depth should be enough
        # - we'll do 8 * max depth for safety
        # - should just suck up more memory when larger max_mestings are allowed
        maxNesting = (self.height() * 8)
        if(opts[:prettify])
          retVal = JSON.pretty_generate(d3root, :max_nesting => maxNesting)
        else
          retVal = d3root.to_json(:max_nesting => maxNesting)
        end
      end
      return retVal
    end
    
    # @api D3 Interface
    # @return [Symbol]
    def getD3DataType()
      return :cluster
    end
    
  end # class NewickTree < ::NewickTre
end ; end # module BRL ; module DataStructure
