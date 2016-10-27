require 'go.rb'
require 'goNode.rb'

def match( arrA, hshB )
    arrA.each{ |i| return true if hshB.has_key?( i ) }
    false
end

# An example of usage of GO.rb
begin
    # Load the RGL from file - molecular_function, biological_process, cell_component
    #   Or, load from GO::load_rgl - m,b,c = GO.load_rgl
    file = File.open( "rgl_dump" )
    m, b, c = Marshal.load( file )
    
    m_hash = Hash.new
    m.each_vertex{ |v|
        m_hash.store( v.id, v )
    }
    
    gp = GO.associate_geneProducts
    puts "Associated GeneProducts: #{gp.size} (total number of GeneProduct accession numbers with 1 or more term_id's associated)"
    
    gp.each_pair{ |k,v|
        # loop through, make sure we only add a GeneProduct to the deepest
        #   part of each branch.
        v.term_ids.each{ |id|
            next if m_hash[id].nil?
            next if match( v.term_ids,  m_hash[id].children ) # Next if one has a child which is in this list?
            m_hash[id].add_geneProduct( v ) unless m_hash[id].nil?
        }
    }
    
    # Output GO children of each node, as well as the GeneProduct children
    count = 0
    m.each_vertex{ |v|
        puts "#{v}:"
        puts "\t-----------------------"
        v.children.each{ |child|
            puts "\t#{child}"
        } unless v.children.nil?
        puts "\t-----------------------"
        v.gene_products.each_key{ |gprod|
            puts "\t#{v.gene_products[gprod]}"
            count += 1
        } unless v.gene_products.nil?
        puts
    }
    puts "TOTAL OF #{count} GeneProducts (not necessarily unique) linked to the GO tree based on term_id association"
end