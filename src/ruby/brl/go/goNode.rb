#!/usr/bin/env ruby

module BRL ; module GO
class GoNode
    attr_reader :name, :id, :type, :acc, :children, :parents, :depth, :gene_products
    attr_writer                          :children, :parents,         :gene_products
    
    
    def initialize( id_in, name_in, type_in, acc_in, depth_in=nil )
        @name     = name_in
        @id       = id_in
        @acc      = acc_in
        @type     = type_in
        @depth    = depth_in
        # Parents and children are represented as a hash.  The keys are the actual nodes (parent or child),
        #   and the value is the _shortest_ documented distance to that node
        @parents  = Hash.new
        @children = Hash.new
        @gene_products = Hash.new
    end
    
    ############################################################################
    # * *Function*: Compares two nodes based on their @id attribute
    # 
    # * *Usage*   : <tt>  node == other_node  </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GoNode, the node to compare against 
    # * *Returns* : 
    #   - +boolean+ -> True if the id's of the two nodes are identicle
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def ==( node )
        self.id == node.id
    end

    ############################################################################
    # * *Function*: Comparison operator for GoNodes.  Depths of nodes are compared.
    # 
    # * *Usage*   : <tt>  node < other_node  </tt>  
    # * *Args*    : 
    #   - +node+ -> The node to which compare self against.
    # * *Returns* : 
    #   - +value+ -> 0 if equal, 1 if greater than, -1 if less than  
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def <=>( node )
        self.depth <=> node.depth
    end
    
    ############################################################################
    # * *Function*: Set's the depth of this node from the root
    # 
    # * *Usage*   : <tt>  node.set_depth( 5 )  </tt>  
    # * *Args*    : 
    #   - +number+ -> The number represtenting the depth of this node from the root
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def set_depth( num )
        # If the given depth is smaller then the current depth, set it to the smaller of the 2
        @depth = num if depth == nil
        @depth = num if num < @depth
    end
    
    
    ############################################################################
    # * *Function*: Add's a parent to this node
    # Parents are a hash where the key is the parent node, and the value is the _shortest_ distance to that node
    # 
    # * *Usage*   : <tt>    </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GoNode, the parent to add to this node.
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    
    def add_parent( node, dist )
        if parents.has_key?( node )
            @parents[node] = dist if parents[node] > dist 
        else
            @parents.store( node, dist )
        end
    end
    
    
    ############################################################################
    # * *Function*: Add's a child to this node
    # Children are a hash where the key is the child node, and the value is the _shortest_ distance to that node
    # 
    # * *Usage*   : <tt>    </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GoNode, the child to add to this node
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def add_child( node, dist )
        if children.has_key?( node )
            @children[node] = dist if children[node] > dist
        else
            @children.store( node, dist )
        end
    end
    
    
    ############################################################################
    # * *Function*: Add a GeneProduct to this node
    # 
    # * *Usage*   : <tt>  node.add_geneProduct( gene_product )  </tt>  
    # * *Args*    : 
    #   - +none+ -> Of type GeneProduct, the product to add to this node.
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def add_geneProduct( product )
        @gene_products.store( product.acc, product )
    end
    
    
    ############################################################################
    # * *Function*: Set's the depth of this node from the root
    # 
    # * *Usage*   : <tt>  node.set_depth( 8 )  </tt>  
    # * *Args*    : 
    #   - +depth+ -> The depth from the root of this node
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def set_depth( dist )
        @depth = dist if @depth == nil
        @depth = dist unless dist > @depth
    end
    
    
    ############################################################################
    # * *Function*: Returns the distance of self to the passed node
    # Only knows distance to parents/children, not siblings (returns -1 if it is not a child or parent)
    # 
    # * *Usage*   : <tt>  node.distance( some_parent )  </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GoNode, the node which to find the distance to.
    # * *Returns* : 
    #   - +number+ -> The distance to the node.  -1 if the node is not listed as a parent or child, 0 is distance to self
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def distance ( node )
        return -1 unless( parents.has_key?( node ) || children.has_key( node ) )
        return 0 if self == node
        return parents[node] if parents.has_key?( node )
        return children[node]
    end
    
    
    ############################################################################
    # * *Function*: Returns the term_id (key) to the parent which is the closest relative of self and the passed node
    # 
    # * *Usage*   : <tt>  node.nearest_parent( other_node )  </tt>  
    # * *Args*    : 
    #   - +other_node+ -> Of type GoNode, the node which to find the distance to.
    # * *Returns* : 
    #   - +number+ -> The term_id (key) to the nearest shared parent
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def nearest_parent( node )
        nearest = -1
        node.parents.each_key{ |k|
            next unless self.parents.has_key?( k )
            nearest = k if nearest == -1
            nearest = k if node.parents[k] < node.parents[nearest] 
        }
        nearest
    end
    
    
    ############################################################################
    # * *Function*: Returns the shortest distance between nodes.
    # Is calculated by finding the nearest parent, and adding the distance of each node to that parent
    # 
    # * *Usage*   : <tt>  node.distance_to_node( some_node )  </tt>  
    # * *Args*    : 
    #   - +some_node+ -> Of type GoNode, the node which to find the distance to.
    # * *Returns* : 
    #   - +number+ -> The distance to the node.
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def distance_to_node( node )
        nearest_p = nearest_parent( node )
        return self.parents[nearest_p] + node.parents[nearest_p]
    end
    
    ############################################################################
    # * *Function*: 
    # 
    # * *Usage*   : <tt>  node.to_s  </tt>  
    # * *Args*    : 
    #   - +none+
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def to_s
        @name.to_s
    end
    
    
    ############################################################################
    # * *Function*: 
    # 
    # * *Usage*   : <tt>  node.to_str  </tt>  
    # * *Args*    : 
    #   - +none+
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def to_str
        @name.to_s
    end
    
end
end ; end
