#!/usr/bin/env ruby

module BRL ; module GO

class GeneProduct
    attr_reader :term_ids, :acc, :parents
    
    def initialize( acc_in, term_id_in=nil )
        @acc = acc_in
        @term_ids = Array.new
        @term_ids.push( term_id_in ) unless term_id_in.nil?
        @parents = Hash.new
    end
    
    
    ########################################################################
    # * *Function*: Compares two GeneProducts based on their @acc attribute
    # 
    # * *Usage*   : <tt>  node == other_node  </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GeneProduct, the node to compare against 
    # * *Returns* : 
    #   - +boolean+ -> True if the accession number  of the two nodes are identicle
    # * *Throws* :
    #   - +none+ 
    ########################################################################
    def ==( node )
        self.acc == node.acc 
    end
    
    ############################################################################
    # * *Function*: Add's a parent to this node
    # Parents are a hash where the key is the parent node
    # 
    # * *Usage*   : <tt>  gene_product.add_parent( go_node )  </tt>  
    # * *Args*    : 
    #   - +node+ -> Of type GoNode, the parent to add to this PeneProduct.
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def add_parent( go_node )
        @parents.store( go_node, nil )
    end
    
    ############################################################################
    # * *Function*: Add's a parent to this node
    # Parents are a hash where the key is the parent node
    # 
    # * *Usage*   : <tt>  gene_product( term_id )  </tt>
    # * *Args*    : 
    #   - +term+ -> The term_id associated with this accession number (GeneProduct)
    # * *Returns* : 
    #   - +none+
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def add_term( term_id_in )
        @term_ids.push( term_id_in )
    end
    
    
    ############################################################################
    # * *Function*: Add's a parent to this node
    # Parents are a hash where the key is the parent node
    # 
    # * *Usage*   : <tt>  gene_product.weight  </tt>  
    # * *Args*    : 
    #   - +none+
    # * *Returns* : 
    #   - +weight+ -> A number, 0 < x <= 1, which is the given "weight" of this geneproduct, based on how many times it occurs in the GO tree
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def weight
        1.0/@parents.length
    end
    
    def to_s
        @acc
    end
end
end ; end