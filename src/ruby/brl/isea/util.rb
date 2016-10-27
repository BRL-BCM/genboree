module BRL ; module ISEA
    # * *Author*: Matthew Linnell
    # * *Module*: Util
    # * *Desc*: A mish-mash of utility type functions.
    module Util
        ########################################################################
        # * *Function*: Designed for parsing of command line arguments.  Returns a hash 
        #   where the key is the option( eg "-o" ), and the value is the option parameter( eg "output.txt" )
        #   Command line options that do not contain a parameter are stored as( option=>true, "-a"=>true ) in the hash.
        #
        # * *Usage*   : <tt>  Util.pair_options( in_argv )  </tt>  
        # * *Args*    : 
        #   - +in_argv+ -> of type Array[string], the passed ARGV( or similarly patterned text ) 
        # * *Returns* : 
        #   - +Hash+ -> A hash table where the key is the option, the value the option parameter 
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::pair_options( in_argv )
            hsh = Hash.new
            arr = in_argv.join( " " )
            pairs = arr.scan( /-[a-zA-Z]\s[^-][a-zA-Z0-9-_,\.]*/ )
            pairs.each { |i|
                option, value = i.scan( /[\S][a-zA-Z0-9\,-_\.*]*/ )
                hsh.store( option, value )
            }
            dash_o = arr.scan( /-[a-zA-Z]/ )
            # Grab any standalone options( ie "-a" w/ no argument, value=>true )
            dash_o.each { |i|
                hsh.store( i, true ) unless hsh.has_key?( i )
            }
            return hsh
        end
        
        ########################################################################
        # * *Function*: Converts the given array into a Hash, where the key=array[index] and value=default
        # If the passed array is in the form [ [key, val], [key2, val2] ] the resultant hash will have keys val/val2 with values val/val2 respectively.
        # 
        # * *Usage*   : <tt>  Util.arr_to_hash( arr, "value" ) </tt>  
        # * *Args*    : 
        #   - +arr+ -> Of type Array, the array to be converted into a Hash
        #   - +*default+ -> Optional. The default value to be stored as the value to the keys.  If not specified, will be nil.
        # * *Returns* : 
        #   - +Hash+ -> The Hash representation of the string 
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::arr_to_hash( in_arr, *default )
            hsh = Hash.new
            if( in_arr == nil)
                return hsh
            elsif( in_arr[0].type == Array )
            in_arr.each_index{ |i|
                hsh.store( in_arr[i][0], in_arr[i][1] )
            }
            else
                val = default.first
                in_arr.each { |i|
                    hsh.store( i, val )
                }
            end
            return hsh
        end
        
        
        ########################################################################
        # * *Function*: Takes the given array, and indexes it with a hash table.  Obviously, the array must be composed of unique 
        #   values.  e.g. ["a", "b", "c"] --> ["a" => 0, "b" => 1, "c" => 2]
        # 
        # * *Usage*   : <tt>  Util.index_array( ["a", "b", "1", Hash.new, Array.new] )  </tt>  
        # * *Args*    : 
        #   - +in_arr+ -> Of type Array, the array to be indexed 
        # * *Returns* : 
        #   - +Hash+ -> A Hash where the key = the array element, value = the index of that element  
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::index_array( in_arr, force_str=true )
            hsh = Hash.new
            index = 0
            if( in_arr != nil ) 
                in_arr.each { |i|
                    if force_str
                        hsh.store( i.to_s, index )
                    else
                        hsh.store( i, index )
                    end
                    index += 1
                }
            end
            return hsh
        end
        
        
        ########################################################################
        # * *Function*: Merges 2 tables into one.  Assumes that column 1 for each table is the unique identifier for 
        #   which to match the two tables against each other
        # 
        # * *Usage*   : <tt>  Util.merge_tables( my_table_1, my_table_2 )  </tt>  
        # * *Args*    : 
        #   - +tbl_1+ -> Of type Table, to be joined with tbl_2.  tbl_1 will exist on the left half of the new table
        #   - +tbl_2+ -> Of type Table, to be joined with tbl_1.  tbl_2 will exist on the right half of the new table
        # * *Returns* : 
        #   - +Table+ -> A Table representing the merge of the input  
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::merge_tables( tbl_1, tbl_2 )
            new_tbl = Table.new
            new_row = Array.new
    
            # For each row in tbl_1, go through and find its counterpart in tbl_2.  row[0] is matched.
            tbl_1.each_row { |tbl_1_row|
                tbl_2.each_row { |tbl_2_row|
                    if ( tbl_1_row[0] == tbl_2_row[0] || tbl_1_row[0].to_s == tbl_2_row[0].to_s )
                        temp = Array.new
                        new_row =( tbl_1_row.concat( tbl_2_row[1..-1] ) )
                        new_tbl.push( new_row )
                        break;
                    end
                }
            }
            new_tbl.setColumnNames( ( tbl_1.columns ).concat( tbl_2.columns ) )
            return new_tbl
            
        end
        
        ########################################################################
        # * *Function*: Filters table data based on the presence of {filter_value} in column {filter_key} for each row.
        # 
        # * *Usage*   : <tt>  Util.filter_table( chr1_tbl, "cancer", 1 )  </tt>  Will return only a table with rows containing a "1" in the "cancer" column  
        # * *Args*    : 
        #   - +tbl+ -> The table which will be filtered
        #   - +filter_key+ -> The key( column name ) whose value will be filtered
        #   - +filter_value+ -> The value to filter for in the {filter_key} column
        #   - +mode+ -> Default = "keep" - keeps data matching the filter.  If a mode other than "keep" is specified, matches are discarded
        # * *Returns* : 
        #   - +Table+ -> A table containing only rows matching the filter criteria 
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::filter_table( tbl, filter_key, filter_value, mode="keep")
            return tbl.dup if filter_value == nil   # If the filter_value (regexp) is nil, then filtered table == original!
            filtered_tbl = Table.new
            discarded_tbl = Table.new
            key_index = ( tbl.columns ).index( filter_key )
            return filtered_tbl if key_index == nil
    
            # Loop through each row, checking the {filter_key} column for the presence of {filter_value}
            tbl.each_row { |row|
                # Catches "abc" = "abc" =~ /abc/
                if( row[key_index].type == String )
                    row[key_index] =~ ( filter_value ) ? filtered_tbl.push( row.dup ) : discarded_tbl.push( row.dup )
                # Catches ["abc", "def"] = "abc" =~ /abc/
                elsif( row[key_index].type == Array )
                    if( row[key_index].include?( filter_value ) || row[key_index] =~ filter_value )
                        filtered_tbl.push( row.dup )
                    else
                        # Check the embedded array
                        row[key_index].each{ |i|
                            if( i =~ filter_value )
                                filtered_tbl.push( row.dup )
                                break
                            end
                        }
                    end
                    discarded_tbl.push( row.dup )   # If it got this far, there were no matches
                # Catches 1 = 1
                else
                    row[key_index] == filter_value ? filtered_tbl.push( row.dup ) : discarded_tbl.push( row.dup ) 
                end
            }
            filtered_tbl.setColumnNames( tbl.columns.dup )
            discarded_tbl.setColumnNames( tbl.columns.dup )
            mode == "keep" ? return_tbl = filtered_tbl : return_tbl = discarded_tbl
            return return_tbl
        end
    
    
        ########################################################################
        # * *Function*: Converts the given Hash to a Table, where key=> roww_id( column 1 ), value=> column 2
        # 
        # * *Usage*   : <tt>  Util.hash_to_table( in_hsh )  </tt>  
        # * *Args*    : 
        #   - +in_hsh+ -> Of type Hash, containing information to be converted into a table
        # * *Returns* : 
        #   - +Table+ -> A Table whose data is that of {in_hsh}
        # * *Throws* :
        #   - +none+ 
        ########################################################################
        def Util::hash_to_table( in_hsh )
            new_tbl = Table.new
            
            in_hsh.each_pair{ |key, val|
                new_tbl.push( [key, val] )
            }
            return new_tbl
        end
        
    end
    
end ; end # end module ISEA ; end module BRL
