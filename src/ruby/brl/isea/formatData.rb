require "brl/isea/util"
require "brl/isea/table"

module BRL ; module ISEA
    # * *Author*: Matthew Linnell
    # * *Class*: FormatData
    # * *Desc*: Designed for special formatting/filtering of groups and libraries of data in a Table for analysis 
    class FormatData
        
        ########################################################################
        # * *Function*: Joins a listing of multtiple rows into libraries, and processes
        #   table for the number of times each library hits each column/group( fname )
        # 
        # * *Usage*   : <tt>  f_data.format_for_hits( chr1_tbl, "keyword_id", chr1_tbl_columns, mode )  </tt>  
        # * *Args*    : 
        #   - +table+ -> Of type Table, the data to be formatted
        #   - +key+ -> The name of the field by which to group libraries together( such as "keyword_id" )
        #   - +column_names+ -> The names of the columns to identify hits against
        #   - +mode+ -> "keyword_value" if building a table of keyword/histology types, etc.  "fname_value" if mapping segments, such as EST vs. RefGene
        # * *Returns* : 
        #   - +Table+ -> Of type Table, containing formatted information 
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def format_for_hits( table, key, column_names, mode )
            new_tbl = Table.new
            new_tbl.setColumnNames( ["identifier"].concat( column_names ) )  # Must begin with leading tab, because column 0 = identifier
            if( mode == "keyword" )
                fname_id_index =( table.columns ).index( "keyword_value" )
                fdata_index = 0
                # The remainder of this if statement is needed for propagation of libKeyword information
                keyword_type_index = (table.columns ).index( "keyword_type" )
                libKeywords_index = column_names.index( 'libKeywords' ) + 1 #not sure I understand why I must add 1 here
            else
                fname_id_index =( table.columns ).index( "fname_value" )
                fdata_index = ( table.columns ).index( "est_fdata_id" )
            end
    
            # Discover location/index of columns whose value we will need
            id_index = ( table.columns ).index( key )
            
            #library_name_index =( table.columns ).index( "window_number" )
            library_name_index =( table.columns ).index( "est_keyword_value" )
    
            # First, generate a hash table indexing the index of each column name for speedy lookup
            col_hsh = Util::index_array( column_names )
            # Shifting index by 1, because we are adding the row identifier into row[0]
            col_hsh.each_key { |key|
                col_hsh[key] += 1
            }
                
            # Iterate through table, row by row, building the new row for each library
            member_hsh = Hash.new              # A hash indexing library members.  key=library_id, value=[fdata units belonging to library]
            library_index_hsh = Hash.new       # A hash that has the row index of the library in the new table
            
            row_index = 1  # Start at 1, since the table indexing starts at 1
            # For each row( read: unique LIBRARY ), row[0] = library name row[1..N] contain hit information
            # for each different group( column_name ).  For example, if LibA has 2 members which hit group fname1, row[1]=2
            table.each_row { |r|
                libKeywords = true if ( mode == "keyword" && r[keyword_type_index] == 'libKeywords')
                # Does this element/fdata belong to a currently indexed library?
                if library_index_hsh.has_key?( r[id_index] ) # yes, library exists, add this fdata element to its value_array
                    member_hsh[ r[id_index] ].push( r[fdata_index] )
                    updated_row = new_tbl.getRow( library_index_hsh[r[id_index]] )
                else    # new library entry, and thus new row on the new table
                    member_hsh.store( r[id_index],  Array.new )
                    member_hsh[ r[id_index] ].push( r[fdata_index] )
                    updated_row = Array.new( new_tbl.columns.length, 0 )   # row[0] = library name, row[1..N-1] hits to column[0..N-2], row[N]
                    updated_row[0] = ( r[id_index] )  # Ad identifyer for row
                end
    
                # Which group does it over lap with? we must match this hit to the column with the right this fname_id, and add this unit
                unless libKeywords
                    if ( updated_row[ col_hsh[r[fname_id_index].to_s ] ] == 0 )
                        updated_row[ col_hsh[r[fname_id_index].to_s ] ] = Array.new
                    end
               end
                
                if ( mode == "keyword" )
                    if libKeywords
                        updated_row[ libKeywords_index ] = r[fname_id_index].to_s
                    else
                        updated_row[ col_hsh[r[fname_id_index].to_s ] ].push( 1 )
                    end
                else
                    updated_row[ col_hsh[r[fname_id_index].to_s ] ].push( r[fdata_index] )
                end
                
                # push updated_row onto new table only if this library did not exist before
                if( !library_index_hsh.has_key?( r[id_index] ) ) 
                    new_tbl.push( updated_row ) 
                    library_index_hsh.store( r[id_index], row_index )
                    row_index += 1
                end
            }
    
            return new_tbl
        end
        
        
        ########################################################################
        # * *Function*:  Will sum the total number of hits for a given
        #   refgene( aka column name ) for the given keywords.
        # 
        # * *Usage*   : <tt>  f_data.total_refgene_hits( tbl, [11, 467, 798] )  </tt>  
        # * *Args*    : 
        #   - +tbl+ -> Of type Table, the table which contains the wanted information
        #   - +keywords+ -> Of type Hash, the list of keyword_ids( or whatever other type of id in column 1 ) for which we wish to check
        # * *Returns* : 
        #   - +Hash+ -> A Hash whose key=refGene value=total hits 
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def total_refgene_hits( tbl, keywords )
            result_hsh       = Util.arr_to_hash( tbl.columns, 0 )  # The # of est hits.  The key=EST-Library & val=hits for that Library
            count_hsh        = Util.arr_to_hash( tbl.columns )   # The # of unique libraries
            unique_hsh       = Util.arr_to_hash( tbl.columns )   # The # of unique est's
            result_hsh.each_key{ |key|
                result_hsh[key] = Hash.new
            }
            unique_hsh.each_key{ |key|
                unique_hsh[key] = Array.new
            }
            count_hsh.each_key{ |key|
                count_hsh[key] = Array.new
            }
            
            column_names = tbl.columns
            tbl.each_row { |row|
                if keywords.has_key?( row[0] ) # Process only wanted keywords ids
                    index = 1   # start at 1, because 0 = row identifier && 1 = total possible est's
                    # Sum the hits for each refgene
                    while index < row.length - 1    # -1 because first column is the identifier
                        if ( row[index] != 0 )
                            result_hsh[column_names[index]][row[0]] = row[index].length
                            count_hsh[column_names[index]]  << row[0] if ( row[index].length != 0 )
                            unique_hsh[column_names[index]] << row[index]
                        end
                        index += 1
                    end
                end
            }
            unique_hsh.each_value{ |val|
                val.flatten!
                val.uniq!
            }
            return result_hsh, count_hsh, unique_hsh
        end 
    end

end ; end # end module ISEA ; end module BRL
