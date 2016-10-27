module BRL ; module ISEA

    # * *Author*: Matthew Linnell
    # * *Class*: Table
    # * *Desc*: A container for row/column style data.
    class Table
        
        # Returns an array containing the column names of the table
        attr_reader :columns
        
        ############################################################################
        # * *Function*: Creates new Table object.
        # 
        # * *Usage*   : <tt>  tbl = Table.new  </tt>
        # * *Args*    : 
        #   - +none+  
        # * *Returns* : 
        #   - +Table+  -> New Table object.
        # * *Throws* :
        #   - +none+
        ############################################################################
        def initialize
            @arr = Array.new
            @columns = Array.new
        end
        
        
        ############################################################################
        # * *Function*: Performs a subtraction of this table against {tableB}, matching on first column
        # 
        # * *Usage*   : <tt>  tblA - tblB  </tt>
        # * *Args*    : 
        #   - +tableB+ -> The table which to subtract from this one  
        # * *Returns* : 
        #   - +Table+  -> New Table object, representing the difference set of the 2 tables
        # * *Throws* :
        #   - +none+
        ############################################################################
        def - ( tableB )
            new_tbl = Table.new
            # For each row in tbl_1, go through and find its counterpart in tbl_2
            self.each_row { |tbl_1_row|
                found = false
                tableB.each_row { |tbl_2_row|
                    if ( tbl_1_row[0] == tbl_2_row[0] )
                        found = true
                        break;
                    end
                }
                new_tbl.push( tbl_1_row ) unless found
            }
            new_tbl.setColumnNames( self.columns.dup )
            return new_tbl
        end
        
        
        ############################################################################
        # * *Function*: Performs a addition of this table with {tableB}.  Simply adding the rows of one to the other.  Does not check for duplication.
        # 
        # * *Usage*   : <tt>  tblA + tblB  </tt>
        # * *Args*    : 
        #   - +tableB+ -> The table which to add to this one  
        # * *Returns* : 
        #   - +Table+  -> New Table object, representing the addition of the 2 tables
        # * *Throws* :
        #   - +none+
        ############################################################################
        def + ( tableB )
            new_tbl = self.dup
            # For each row in tbl_1, go through and find its counterpart in tbl_2
            tableB.each_row { |tbl_2_row|
                new_tbl.push( tbl_2_row.dup )
            }
            new_tbl.setColumnNames( self.columns.dup )
            return new_tbl
        end
        
        
        ############################################################################
        # * *Function*: Sets the column names.
        # 
        # * *Usage*   : <tt> tbl.setColumnNames( ["col_A", "col_b", ... "col_N"]  </tt>  
        # * *Args*    : 
        #   - +col_names+ -> An array containing the column names.
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def setColumnNames( col_names )
            @columns = Array.new
            # Move DBI::Row (or Array) info to an array
            col_names.each { |i| 
                @columns.push( i ) 
            } 
            return
        end
        
        ############################################################################
        # * *Function*: Adds one additional row to the table.
        # 
        # * *Usage*   : <tt>  tbl.push( ["val_1", "val_2, ... "val_N"] )  </tt>  
        # * *Args*    : 
        #   - +new_row+ -> An array representing the row to be added
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def push( new_row )
            row = Array.new
            new_row.each { |i|
                row.push( i ) 
            }   # Move new_row into to an array in case it is of type DBI::Row
            @arr << row
            return
        end
        
        ############################################################################
        # * *Function*: Removes and returns the last row of the table
        # 
        # * *Usage*   : <tt>  tbl.pop  </tt>  
        # * *Args*    : 
        #   - +none+ 
        # * *Returns* : 
        #   - +Array+ -> An array representing the last row of the table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def pop
            temp = @arr[-1]
            @arr.delete_at( -1 )
            return temp
        end
    
        ############################################################################
        # * *Function*: Returns( without removing ) the last row of the table.
        # 
        # * *Usage*   : <tt>  tbl.peek  </tt>  
        # * *Args*    : 
        #   - +none+ 
        # * *Returns* : 
        #   - +Array+ -> An array representing the last row of the table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def peek
            @arr[-1]
        end
        
        
        ############################################################################
        # * *Function*: Returns the number of rows in this table
        # 
        # * *Usage*   : <tt>  tbl.size  </tt>  
        # * *Args*    : 
        #   - +none+ 
        # * *Returns* : 
        #   - +size+ -> The number of rows in this table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def size
            @arr.length
        end
            
        
        ############################################################################
        # * *Function*: Returns( without removal ) the first row of the table
        # 
        # * *Usage*   : <tt>  tbl.skim  </tt>  
        # * *Args*    : 
        #   - +none+ 
        # * *Returns* : 
        #   - +Array+ -> An array representing the last row of the table.
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def skim
            temp = @arr[0]
            @arr.delete_at( 0 )
            return temp
        end
        
        ############################################################################
        # * *Function*: Returns the row specified by {row_num}
        #   _NOTE_: {row_num} is the absolute index of the row.  Indexing starts at 1, not 0
        #
        # * *Usage*   : <tt>  tbl.getRow( 2 )  </tt>  
        # * *Args*    : 
        #   - +row_num+ -> The number of the row to be acquired
        # * *Returns* : 
        #   - +Array+ -> An array representing the last row of the table.
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getRow( row_num )
            return @arr[row_num-1]
        end
        
    
        ############################################################################
        # * *Function*: Returns an array containing the values in a given column.  
        #   NOTE: Indexing starts at 1, not zero
        # 
        # * *Usage*   : <tt>  tbl.getColumn( 1 )  </tt>  Returns the data from the first column of the table
        # * *Args*    : 
        #   - +col_num+ -> The column number whose data we wish to retrieve. 
        # * *Returns* : 
        #   - +Array+ -> An array containing the data of the given column. 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getColumn( col_num )
            col_data = Array.new
            each_row { |row|
                col_data.push row[ col_num - 1 ]
            }
            return col_data
        end
        
        ############################################################################
        # * *Function*: Same as getRow( ).  Returns, without removal, the row from the specified row number.
        #   _NOTE_: {row_num} is the absolute index of the row.  Indexing starts at 1, not 0
        # 
        # * *Usage*   : <tt>  tbl[2]  </tt>  
        # * *Args*    : 
        #   - +row_num+ 
        # * *Returns* : 
        #   - +Array+ -> An array representing the row of the table at row number {row_num}
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def []( row_num )
            #NOTE: if row=1, returns "row 1", NOT index 2
            return @arr[row_num-1]
        end
        
        ############################################################################
        # * *Function*: Returns the cell at the given {row,column}
        #   _NOTE_: {row, cell} is the absolute index of the row,column.  Indexing starts at 1, not 0
        # 
        # * *Usage*   : <tt>  tbl.cell( 2, 3 )  </tt>  
        # * *Args*    : 
        #   - +row+ -> The row number of the cell
        #   - +cell+ -> The cell number of the cell
        # * *Returns* : 
        #   - +Object+ -> Returns the Object at the given cell coordinates
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def cell( row, column )
            # Ensure we are not trying [nil] and are within bounds
            if( @arr.length == row-1 || @arr[row-1].length == column-1 )
                return nil
            else 
                return( @arr[row-1] )[column-1]
            end
        end
        
        ############################################################################
        # * *Function*: Deletes the row from the table at the given index {row_num}, shifting all below up by one.  Returns the del row.
        # 
        # * *Usage*   : <tt>  tbl.delRow!( 4 )  </tt>  
        # * *Args*    : 
        #   - +row_num+ -> The index of row to be deleted
        # * *Returns* : 
        #   - +Array+ -> An array representation of the row that was deleted from the table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def delRow!( row_num )
            return @arr.delete( row_num-1 )
        end
        
    
        ############################################################################
        # * *Function*: Adds a column to the end of the current table.  There are currently no checks to ensure 
        #   that the data for this column covers every row.
        # 
        # * *Usage*   : <tt>  tbl.addColumn!( "new_column_name", ["a", "b", "c"]  </tt>  
        # * *Args*    : 
        #   - +column_name+ -> Of type string, the name of the new column
        #   - +data+ -> Of type Array, the data that this column contains.  The first element will correspond to row 1, second to row 2, etc.  
        # * *Returns* : 
        #   - +none+
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def addColumn!( column_name, data )
            columns.push( column_name )
            index = 0;
            each_row { |row|
                row << data[index]
                index += 1
                row.flatten!
            }
        end
        
        
        ############################################################################
        # * *Function*: Iterates through each row of the table, calling {&block} on each row
        # 
        # * *Usage*   : <tt>  tbl.each_row { |row| puts row }  </tt>  
        # * *Args*    : 
        #   - +&block+ -> The Block to be called on each row upon iteration
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def each_row( )
            @arr.each { |row|
                yield( row )
            }
            return
        end
    
        ############################################################################
        # * *Function*: Iterates through each cell of the table, calling {&block} on each cell
        # 
        # * *Usage*   : <tt>  tbl.each_cell { |cell| puts cell }  </tt>  
        # * *Args*    : 
        #   - +&block+ -> The Block to be called on each cell upon iteration
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def each_cell( )
            @arr.each { |row|
                row.each { |cell|
                    yield( cell )
                }
            }
            return
        end
        
        
        ############################################################################
        # * *Function*: Iterates through each column of the table, calling {&block} on each row
        # 
        # * *Usage*   : <tt>  tbl.each_column { |col| puts col }  </tt>  
        # * *Args*    : 
        #   - +&block+ -> The Block to be called on each column upon iteration
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def each_column( )
            column_number = 0
            column_size   = @arr[0].length
            temp = Array.new
            
            column_size.times { |i|
                temp.clear
                @arr.each { |row|
                    temp.push( row[i] )
                }
                yield( temp )
            }
            return
        end
        
        
        ############################################################################
        # * *Function*: Iterates through each ColumnName of the table, calling {&block} on each ColumnName
        # 
        # * *Usage*   : <tt>  tbl.each_columnName { |col| puts col }  </tt>  
        # * *Args*    : 
        #   - +&block+ -> The Block to be called on each ColumnName upon iteration
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def each_columnName( )
            @columns.each { |col|
                yield( col )
            }
            return
        end
    
        ############################################################################
        # * *Function*: Dumps a serialized representation of this table to stdout.
        # 
        # * *Usage*   : <tt>  tbl._dump()  </tt>  
        # * *Args*    : 
        #   - +none+
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def _dump( )
            printf "\a\t"
            self.columns.each{ |j|
                printf "#{j}\t"
            }
            printf "\n"
            self.each_row { |row|
                row.each{ |i|
                    printf "#{i}\t"
                }
                printf "\n"
            }
        end
        
        ############################################################################
        # * *Function*: Loads the table into a state as defined by the serialized representation in aString
        # 
        # * *Usage*   : <tt>  tbl._load( aString )  </tt>  
        # * *Args*    : 
        #   - +none+
        # * *Returns* : 
        #   - +aString+ -> The string representing the serialized state of the Table object to be loaded
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def _load( aString )
            @arr = Array.new
            @columns = Array.new
            
            aString.each_line{ |i|
                if( i.split.include?( "\a" ) )
                    self.setColumnNames( i.split()[1..-1] )
                else
                    self.push( i.split() )
                end
            }
            return true
        end
        
        
        ############################################################################
        # * *Function*: Outputs the given( Table )tbl to stdout.  Data is delimited by {delim=\t}, and any arrays in the cell joined by {join}
        # 
        # * *Usage*   : <tt>  tbl.to_s( "\t", "-" )  </tt>  
        # * *Args*    : 
        #   - +delim+ -> The delimeter separating the fields in the table
        #   - +join_txt+ -> The character used to join together arrays that may exist within a field
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def to_s( delim="\t", join_txt="-" )
            return_str = ""
            # Print Column headers
            self.each_columnName { |i|
                return_str << "#{i}#{delim}"
            }
            
            return_str << "\n"
            # Iterate through each row, printing row name first, followed by columnar data
            self.each_row { |row|
                row.each { |cell|
                    if cell.type == Array
                        return_str <<  "#{cell.join(join_txt)}#{delim}"
                        #printf "#{cell.length}#{delimeter}"
                    elsif cell == nil
                        return_str <<  "NIL!-#{delim}"
                    else
                        return_str <<  "#{cell}#{delim}" 
                    end
                }
                return_str << "\n"
            }
            return return_str
        end
        
        
        ############################################################################
        # * *Function*: Sorts the table, based on the values in the first column.  Modifies in place.  (Untested)
        # 
        # * *Usage*   : <tt>  tbl.sort!  </tt>  
        # * *Args*    : 
        #   - +none+
        # * *Returns* : 
        #   - +none+ -> Modifies in place
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def sort!
            @arr.sort!
        end
    end
    
end ; end # end module ISEA ; end module BRL
