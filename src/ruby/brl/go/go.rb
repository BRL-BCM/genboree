#!/usr/bin/env ruby

require 'dbi'
require 'brl/db/dbrc'
require 'rgl/adjacency'
require 'rgl/dot'
require 'brl/go/goNode'
require 'brl/go/geneProduct'

module BRL ; module GO

    ############################################################################
    # * *Function*: Build a set of 3 RGL objects representing the current GO database on hand
    # 
    # * *Usage*   : <tt>  GO.load_rgl  </tt>  
    # * *Args*    : 
    #   - +none+
    # * *Returns* : 
    #   - +m,b,c -> 3 RGL objects, representing the molecular_function, biological_process, and cell_component trees
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def GO::load_rgl
        dbrc = BRL::DB::DBRC.new( "~/.dbrc", "wlu1_go", "brl_go" )
        m_term_hsh = Hash.new # Molecular function list
        c_term_hsh = Hash.new # Cellular component list
        b_term_hsh = Hash.new # Biologoical process list
        graph_path = Array.new        
        DBI.connect( dbrc.driver, dbrc.user, dbrc.password ) do |dbh|
            # Build a list of all terms
            str = "SELECT term.id, term.name, term.term_type, term.acc FROM term where term.term_type='molecular_function' or term.term_type='Gene_Ontology';"
            dbh.select_all( str ) do |row| row[0] == 1 ? m_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone, 0 ) ) : m_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone ) ) end
            str = "SELECT term.id, term.name, term.term_type, term.acc FROM term where term.term_type='cellular_component' or term.term_type='Gene_Ontology';"
            dbh.select_all( str ) do |row| row[0] == 1 ? c_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone, 0 ) ) : c_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone ) ) end
            str = "SELECT term.id, term.name, term.term_type, term.acc FROM term where term.term_type='biological_process' or term.term_type='Gene_Ontology';"
            dbh.select_all( str ) do |row| row[0] == 1 ? b_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone, 0 ) ) : b_term_hsh.store( row[0], GoNode.new( row[0], row[1].clone, row[2].clone, row[3].clone ) ) end
            # Grab the list of all graph paths to the root
            str = "SELECT * FROM graph_path where distance != 0"
            dbh.select_all( str ) do |row| graph_path.push( row.clone ) end
        end
        
        m_rgl_array = Array.new
        c_rgl_array = Array.new
        b_rgl_array = Array.new
        graph_path.each_index{ |i|
                term_1 = graph_path[i][1]
                term_2 = graph_path[i][2]
                dist   = graph_path[i][3]
                if b_term_hsh.has_key?( term_2 )  # Is the largest group, so check first (most likely to hit here)
                    parent = b_term_hsh[term_1]
                    child  = b_term_hsh[term_2]
                    child.set_depth( dist ) if term_1 == 1
                    b_rgl_array.push( parent )
                    b_rgl_array.push( child )
                    parent.add_child( child, dist )
                    child.add_parent( parent, dist )
                elsif m_term_hsh.has_key?( term_2 )         # Second largest group, so check second
                    parent = m_term_hsh[term_1]
                    child  = m_term_hsh[term_2]
                    child.set_depth( dist ) if term_1 == 1
                    m_rgl_array.push( parent )
                    m_rgl_array.push( child )
                    parent.add_child( child, dist )
                    child.add_parent( parent, dist )
                else    # Cellular component smallest group
                    parent = c_term_hsh[term_1]
                    child  = c_term_hsh[term_2]
                    child.set_depth( dist ) if term_1 == 1
                    c_rgl_array.push( parent )
                    c_rgl_array.push( child )
                    parent.add_child( child, dist )
                    child.add_parent( parent, dist )
                end
        }
        
        m_dg = RGL::DirectedAdjacencyGraph[ *m_rgl_array ]
        b_dg = RGL::DirectedAdjacencyGraph[ *b_rgl_array ]
        c_dg = RGL::DirectedAdjacencyGraph[ *c_rgl_array ]
        # Uncomment the following 3 lines to dump the rgl object to file for quick loading later
        #   To quick load: m,b,c = Marshal.load(File.open( "rgl_file" ))
        file = File.open( "rgl_dump", File::CREAT|File::TRUNC|File::RDWR )
        file << Marshal.dump( [m_dg, b_dg, c_dg] )
        file.close
        return m_dg, b_dg, c_dg     # molecular_function, biological_process, cellular_component 
    end
    
    
    ############################################################################
    # * *Function*: Build a Hash representing the association of GO term id's to accession numbers
    # 
    # * *Usage*   : <tt>  GO.associate_geneProducts  </tt>  
    # * *Args*    : 
    #   - +none+
    # * *Returns* : 
    #   - +Hash -> Of type Hash, where the key is the accession number and the value is a GeneProduct object
    # * *Throws* :
    #   - +none+ 
    ############################################################################
    def GO::associate_geneProducts
        refFlat_hsh = Hash.new
        join_hsh = Hash.new
        matched_hsh = Hash.new
        
        dbrc = BRL::DB::DBRC.new( "~/.dbrc", "andrewj_ucsc_hg13", "brl_go" )
        DBI.connect( dbrc.driver, dbrc.user, dbrc.password ) do |dbh|
            refFlat_str = "select distinct(geneName), name from refFlat;"
            join_str = "select distinct(geneName), name from refFlat, wlu1_go.gene_product where refFlat.geneName = wlu1_go.gene_product.symbol;"
            
            dbh.select_all( refFlat_str ) do |row| refFlat_hsh.store( row[0].clone, row[1] ) end
            dbh.select_all( join_str ) do |row| join_hsh.store( row[0].clone, row[1] ) end
        end
        
        # Find which symbols have a direct match, and which do not.  Segregate.
        join_hsh.each_key{ |k|
            matched_hsh.store( k, refFlat_hsh.delete( k ) )
        }
        
        # The following had an exact match bewteen the refFlat DB and the GO DB.
        gene_product = Hash.new
        DBI.connect( dbrc.driver, dbrc.user, dbrc.password ) do |dbh|
            matched_hsh.each_pair{ |k,v|
                next if k=="" || k == nil
                str = "select term_id from wlu1_go.gene_product, wlu1_go.association where gene_product.symbol =\"#{k}\" and association.gene_product_id = gene_product.id;"
                dbh.select_all( str ) do |row| 
                    gene_product.has_key?( v ) ? gene_product[ v ].add_term( row[0] ) : gene_product.store( v, GeneProduct.new( v, row[0] ) ) 
                end
            }
        end
        
        # The following did not have an exact match, so we must use "like" instead of = in the query
        DBI.connect( dbrc.driver, dbrc.user, dbrc.password ) do |dbh|
            refFlat_hsh.each_pair{ |k,v|
                next if k=="" || k == nil
                str = "select term_id from wlu1_go.gene_product, wlu1_go.association where gene_product.symbol like \"#{k}%\" and association.gene_product_id = gene_product.id;"
                #puts str
                dbh.select_all( str ) do |row| 
                    #puts "FOUND #{row} in #{k}/#{v}"
                    gene_product.has_key?( v ) ? gene_product[ v ].add_term( row[0] ) : gene_product.store( v, GeneProduct.new( v, row[0] ) ) 
                end
            }
        end
        
	# Dump the gene product hash to a file for quick loading. 
	dumpFile=File.new("gp_dump", "w")
	dumpFile << Marshal.dump(gene_product)
	dumpFile.close
	
        return gene_product
    end
    
	############################################################################
	# * *Function*: This function was included in the test script and is used in associating gene products with GO terms
	# 
	# * *Usage*   : <tt>  GO.match(arrA, hshB)  </tt>  
	# * *Args*    : 
	#   - +arrA+ -> The array to check. 
	#   - +hshB+ -> The hash to check. 
	# * *Returns* : 
	#   - +value+ -> True if there's a match, false otherwise. 
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::match( arrA, hshB )
		arrA.each{ |i| return true if hshB.has_key?( i ) }
		false
	end

	############################################################################
	# * *Function*: Connects the gene products to the GO tree. Adapted from code in the test script
	# 
	# * *Usage*   : <tt>  GO.addGeneProducts(gp, currentGraph)  </tt>  
	# * *Args*    : 
	#   - +gp+ -> The hash of gene products generated by GO.associate_geneProducts. 
	#   - +currentGraph+ -> The section of the GO tree with which to associate the products. 
	# * *Returns* : 
	#   - +none+
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::addGeneProducts(gp, currentGraph)
		temp_hash=Hash.new
		currentGraph.each_vertex { |v|
			temp_hash.store(v.id, v)
		}

		gp.each_pair{ |k,v|
			# Loop through, make sure we only add a GeneProduct to the deepest part of each branch. 
			v.term_ids.each { |id|
				next if temp_hash[id].nil?
				# Next if one has a child which is in this list?
				next if match( v.term_ids,  temp_hash[id].children )
				temp_hash[id].add_geneProduct( v ) unless temp_hash[id].nil?
			}
		}
	end

	############################################################################
	# * *Function*: Calculates the factorial of a given number. 
	# 
	# * *Usage*   : <tt>  GO.factorial(n)  </tt>  
	# * *Args*    : 
	#   - +n+ -> The integer whose factorial to compute.  
	# * *Returns* : 
	#   - +value+ -> The factorial of n. 
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::buildFactTable(n)
	$fact=Array.new
		$fact[0]=1
		1.upto(n) { |i|
			$fact[i]=$fact[i-1]*i
		}
	end

	def GO::factorial(n)
		# result=1
		# if (n>=2)
			# n.downto(2) { |i|
				# result*=i
			# }
		# end
		# return result
		return $fact[n]
	end
	
	############################################################################
	# * *Function*: Calculates permuations for n objects taken r at a time. 
	# 
	# * *Usage*   : <tt>  GO.permutations(n, r)  </tt>  
	# * *Args*    : 
	#   - +n+ -> Total objects.  
	#   - +r+ -> Number taken at one time.  
	# * *Returns* : 
	#   - +value+ -> permutation (n r). 
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::permutations(n, r)
		return factorial(n)/(factorial(r)*factorial(n-r))
	end
	
	############################################################################
	# * *Function*: Calculate a p-value based on the hypergeometric distribution. 
	# 
	# * *Usage*   : <tt>  GO.hypergeometric(populationSize, populationHits, sampleSize, sampleHits)  </tt>  
	# * *Args*    : 
	#   - +populationSize+ -> Total population size.  
	#   - +populationHits+ -> Number of genes having that annotation in the population. 
	#   - +sampleSize+ -> Size of the submitted sample
	#   - +sampleHits+ -> Number of sample genes having that annotation. 
	# * *Returns* : 
	#   - +value+ -> p-value of that observation. 
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::hypergeometric(populationSize, populationHits, sampleSize, sampleHits)
		return permutations(populationHits, sampleHits).to_f*permutations(populationSize-populationHits, sampleSize-sampleHits)/permutations(populationSize, sampleSize)
	end

	############################################################################
	# * *Function*: Calculate a p-value based on the hypergeometric distribution for sampleHits or more. 
	# 
	# * *Usage*   : <tt>  GO.pvalue(populationSize, populationHits, sampleSize, sampleHits)  </tt>  
	# * *Args*    : 
	#   - +populationSize+ -> Total population size.  
	#   - +populationHits+ -> Number of genes having that annotation in the population. 
	#   - +sampleSize+ -> Size of the submitted sample
	#   - +sampleHits+ -> Number of sample genes having that annotation. 
	# * *Returns* : 
	#   - +value+ -> p-value of that observation or more. 
	# * *Throws* :
	#   - +none+ 
	############################################################################

	def GO::pvalue(populationSize, populationHits, sampleSize, sampleHits)
		p=0
		0.upto(sampleHits-1) { |j|
			p+=hypergeometric(populationSize, populationHits, sampleSize, j)
		}
		return 1-p	
	end

end
end