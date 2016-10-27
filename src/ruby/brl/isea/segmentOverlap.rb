require 'brl/db/dbrc'
require 'dbi'
require 'brl/isea/table'

module BRL ; module ISEA 
    # * *Author*: Matthew Linnell
    # * *Class*: SegmentOverlap
    # * *Desc*: Performs interface with DB, runs queries.
    class SegmentOverlap
    
        ############################################################################
        # * *Function*: Creates new BRL::DB::DBRC database object, and connects. 
        # 
        # * *Usage*   : <tt>  db = SegmentOverlap.new( "~/.dbrc", "my_db" )  </tt>  
        # * *Args*    : 
        #   - +dbrcFile+ -> The file to look up connection information, such as host, username, etc.
        #   - +my_db+ -> The name of the database to use
        # * *Returns* : 
        #   - +SegmentOverlap+ -> A new instance of SegmentOverlap.
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def initialize( dbrcFile, databaseName )
            # Create database manager for opening/closing/managing target DB
            dbrc = BRL::DB::DBRC.new( dbrcFile, databaseName )
            @link = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )
        end
        
        ############################################################################
        # * *Function*: Performs a sequence comparison, testing for overlap of an ftype_type/ftype_subtypes against a different ftype_type/ftype_subtype.
        # * *Usage*   : <tt>  seg_overlap.compare( "EST", "all_est", "Gene", "refGene", "chr1_1_fdata" )  </tt>  
        # * *Args*    : 
        #   - +libType+ -> The ftype_type of the sequence to use for the segments to check against the map
        #   - +libSubtype+ -> The ftype_subtype of the sequence to use for the segments to check against the map
        #   - +targetType+ -> The ftype_type of the target to map the segments against
        #   - +targetSubtype+ -> The ftype_subtype of the target to map the segments against
        #   - +tbl_arr+ -> An array of tables on which to perform the query
        # * *Returns* : 
        #   - +Table+ -> A new Table containing the relavent hits of libraries vs. map( ie EST vs. Gene ) 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def compare( libType, libSubtype, targetType, targetSubtype, table )
            result = Table.new
            
            # Iterate through each table( ie chr1_1_fdata...chr20_1_fdata )
            fdata_id_arr = getFdataIds( targetType, targetSubtype, table )
            fdata_id_arr.each { |fdata_id|
                strng = getSelect( libType, libSubtype, targetType, targetSubtype, table, fdata_id )     # Generate selection text
                sth = @link.prepare( strng )
                sth.execute
                # Iterate through each row generated, collect into array.  Array[DBI::Row]
                while row = sth.fetch do
                    result.push( row )
                end
    
                result.setColumnNames( sth.column_names )
                sth.finish
            }
            return result
        end
    
        ############################################################################
        # * *Function*: Performs a sequence comparison based on the "sliding window" principle.  For example, instead
        #   of testing "est_all" vs "refGene" sequences where the refGene is a window to test for overlap, we have the window "slide" 
        #   along the genome, independent of where refGene sequences start and stop.
        # * *Usage*   : <tt>  seg_overlap.compareAbsolute( "EST", "all_est", "chr1_1_fdata", 100000, 10000 )  </tt>  
        # * *Args*    : 
        #   - +libType+ -> The ftype_type of the sequence to use for the segments to check against the map
        #   - +libSubtype+ -> The ftype_subtype of the sequence to use for the segments to check against the map
        #   - +tbl_arr+ -> An array of tables on which to perform the query
        #   - +window_size+ -> The size of the "sliding window" in base pairs
        #   - +boundary_overlap+ -> The overlap of one window with the next in base pairs
        # * *Returns* : 
        #   - +Table+ -> A new Table containing the relavent hits of this sliding window analysis 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def compareAbsolute( libType, libSubtype, table, window_size, boundary_overlap )
            window_start = 0
            window_stop  = window_size
            result = Table.new
            
            # Iterate through each table( ie chr1_1_fdata...chr20_1_fdata )
            window_number = 1
            total = total_windows( table, window_size, boundary_overlap )     # find the length of the sequence, so we know when to stop the sliding window
            while window_number <= total
                strng = getAbsoluteSelect( libType, libSubtype, table, window_start, window_stop )     # Generate selection text
                sth = @link.prepare( strng )
                sth.execute
                result.setColumnNames( sth.column_names.push( "fname_value" ) )  # fname_value == window number
                # Iterate through each row generated, collect into tableay.  Tableay[DBI::Row]
                while row = sth.fetch do
                    result.push( row + [window_number] )
                end
                window_number += 1
                sth.finish
                # Reposition window
                window_start = window_stop - boundary_overlap
                window_stop  = window_start + window_size
            end
            return result
        end
        
        
        ############################################################################
        # * *Function*: Performs a sequence comparison which generates row of libraries with columns
        #   representing which attribute of keyword_type this library hits( ie cancerous vs. noncancerous ) 
        # * *Usage*   : <tt>  seg_overlap( "cgap" )  </tt>  
        # * *Args*    : 
        #   - +targetClass+ -> the keyword_class from which to generate information 
        #   - +targetFdatatoc+ -> Of type fixnum, the target fdatatoc id to restrain the result set to
        # * *Returns* : 
        #   - +Table+ -> Of type Table, a table with the rows representing libraries and columsn attribute hits. 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def compareToKeywords( targetClass )
            result = Table.new
            
            # Iterate through each table( ie chr1_1_fdata...chr20_1_fdata )
            strng = getKeywordSelect( targetClass )     # Generate selection text
            sth = @link.prepare( strng )
            sth.execute
    
            column_names = expand_column( 'libTissue' ) << expand_column( 'libType' ) << expand_column( 'libHistology' ) << expand_column( 'libProtocol' ) << "libKeywords" 
            column_names.flatten!
            shift_length = column_names.length
            shift_array  = Array.new( shift_length, 0 )
            
            # Iterate through each row generated, collect into array.  Array[DBI::Row]
            while row = sth.fetch do
                result.push( shift_array.concat( row ) )
                shift_array = Array.new( shift_length, 0 )
            end
            
            result.setColumnNames( column_names.concat( sth.column_names ) )
            sth.finish
            return result
        end
        
        
        ############################################################################
        # * *Function*: Disconnects from the database loaded by this instance.
        # 
        # * *Usage*   : <tt>  seg_overlap.disconnect  </tt>  
        # * *Args*    : 
        #   - +none+ 
        # * *Returns* : 
        #   - +none+ 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def disconnect
            @link.disconnect
            return
        end
        
        
        ############################################################################
        # * *Function*: Retrieve unique keyword_ids based on keyword.type, ftype.ftype_type, ftype.ftype_subtype( ie keyword.type for all refGenes )
        #   For use in grouping into libraries, etc.
        #
        # * *Usage*   : <tt>  seg_overlap.unique_group_names( "EST", "all_est", "chr1_1_data" )  </tt>  
        # * *Args*    : 
        #   - +ftype_type+ -> The ftype_type of the group you wish to find unique group id's for( ie "EST" )
        #   - +ftype_subtype+ -> The ftype_subtype of the group you wish to find the unique group id's for( is "all_est" )
        #   - +tbl_arr+ -> The table( or chromosome ) from which to pull this information from
        # * *Returns* : 
        #   - +Array+ -> An array containing the unique id's of this group 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def unique_group_names( ftype_type, ftype_subtype, tbl_arr )
            ftype_id = get_ftype_index( ftype_type, ftype_subtype )
            unique_ids = Array.new
            tbl_arr.each { |chr|
                chr_fgroup = chr.sub( "fdata", "fgroup" )
                chr_fname  = chr.sub( "fdata", "fname" )
                strng = "SELECT distinct fname_value from #{chr}, #{chr_fgroup}, #{chr_fname}" +
                        " where" +
                        " #{chr}.FK_ftype_id=#{ftype_id} and" +
                        " #{chr}.fdata_id=#{chr_fgroup}.FK_fgroup_id and" +
                        " #{chr}.FK_fname_id=#{chr_fname}.fname_id;" 
                sth = @link.prepare( strng )
                sth.execute
                while row = sth.fetch do
                    unique_ids.push( row[0] )
                end
                sth.finish
            }
            return unique_ids
        end
        
        ############################################################################
        # * *Function*: Generates string representing the selection to be made for relative positioning( ie EST vs. refGenes )
        # 
        # * *Usage*   : <tt>  getAbsoluteSelect( "EST", "all_est", "Gene", "refGene", "chr1_1_fdata" )  </tt>  
        # * *Args*    : 
        #   - +libType+ -> The ftype_type to be used for comparison( segment )
        #   - +libSubtype+ -> The fytpe_subtype to be used for comparison( segment )
        #   - +targetType+ -> The ftype_type to be used for the target( map )
        #   - +targetSubtype+ -> The ftype_subtype to be used for the target( map )
        #   - +tbl+ -> The table from which the segments and targets will be pooled from
        # * *Returns* : 
        #   - +string+ -> The string to be used in the selection.
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getSelect( libType, libSubtype, targetType, targetSubtype, tbl, fdata_id )
            lib_type_id = get_ftype_index( libType, libSubtype )
            target_type_id = get_ftype_index( targetType, targetSubtype )
            chr_fgroup = tbl.sub( "fdata", "fgroup" )
            
            str =   "SELECT T1.fdata_id as est_fdata_id, T1.FK_fname_id as est_fname_id, T2.FK_fname_id as target_fname_id, T2.fdata_id as target_fdata_id from #{tbl} AS T1, #{tbl} AS T2 " + 
                    " where T2.fdata_id=#{fdata_id} AND " +
                    " T1.FK_ftype_id=#{lib_type_id} and T2.FK_ftype_id=#{target_type_id} AND" +
                    "( T1.fdata_start < T2.fdata_stop and T1.fdata_stop > T2.fdata_start );" 
            return str
        end
    
    
        ############################################################################
        # * *Function*: Generates string representing the selection to be made for absoulte genomic positioning
        # 
        # * *Usage*   : <tt>  getAbsoluteSelect( "EST", "all_est", "Gene", "refGene", "chr1_1_fdata", "1", "10000" )  </tt>  
        # * *Args*    : 
        #   - +libType+ -> The ftype_type to be used for comparison( segment )
        #   - +libSubtype+ -> The fytpe_subtype to be used for comparison( segment )
        #   - +tbl+ -> The table from which the segments and targets will be pooled from
        #   - +window_start+ -> The start location of the viewing window in which the segment will be mapped
        #   - +window_stop+ -> The stop location of the viewing window in which the segment will be mapped
        # * *Returns* : 
        #   - +string+ -> The string to be used in the selection.
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getAbsoluteSelect( libType, libSubtype, tbl, window_start, window_stop )
            lib_type_id = get_ftype_index( libType, libSubtype )
            chr_fgroup = tbl.sub( "fdata", "fgroup" )
            chr_fname  = tbl.sub( "fdata", "fname" )
            
            str =   "SELECT T1.fdata_id AS est_fdata_id, T1.FK_fname_id AS est_fname_id from #{tbl} AS T1, #{chr_fname} AS F1" + 
                    " WHERE T1.FK_ftype_id=#{lib_type_id} AND" +
                    " T1.FK_fname_id=F1.fname_id AND" +
                    "( T1.fdata_start < #{window_stop} AND T1.fdata_stop > #{window_start} ) " 
            return str
        end
    
        ############################################################################
        # * *Function*: Generates string for use in selection of keyword library comparison
        # 
        # * *Usage*   : <tt>  getKeywordSelect( "cgap" )  </tt>  
        # * *Args*    : 
        #   - +targetClass+ -> Of type string, the target keyword_class to look up
        #   - +targetFdatatoc+ -> Of type fixnum, the target fdatatoc id to restrain the result set to 
        # * *Returns* : 
        #   - +string+ -> The string to be used in the selection
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getKeywordSelect( targetClass )
            str =   "SELECT K1.keyword_id, K2.* FROM keyword AS K1, keyword AS K2, keyword_keyword AS KK " + 
                    "WHERE KK.keyword1_id = K1.keyword_id AND K1.keyword_class=\"#{targetClass}\" AND " + 
                    "K1.keyword_type = \"libTitle\" AND KK.keyword2_id = K2.keyword_id";
            return str
        end
        
        
        ############################################################################
        # * *Function*: When given an fdata_id, returns keyword_id( aka library id )
        # 
        # * *Usage*   : <tt>  getLibraryId( "chr1_1_fdata", 4236 )  </tt>
        # * *Args*    : 
        #   - +tbl_name+ -> Of type String, the name of the table in which to look
        #   - +fdata_id+ -> Of type Fixnum, the fdata_id of the segment whose library we wish to know
        # * *Returns* : 
        #   - +libraryId+ -> The library id for this segment
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getLibraryId( tbl_name, fdata_id, fdatatoc_id )
            sth = @link.prepare( "SELECT keyword_id FROM fdatakeyword WHERE fdatakeyword.fdata_id=#{fdata_id} AND fdatakeyword.fdatatoc_id=#{fdatatoc_id};" )
            sth.execute
            row = sth.fetch
            libraryId = row[0]
            sth.finish
            return libraryId
        end
        
        
        ############################################################################
        # * *Function*: Calculates the total number of members in a given library (does not count members from different chromosomes)
        # 
        # * *Usage*   : <tt>  memeber_count( "chr1_1_fdata", 4236 )  </tt>  
        # * *Args*    : 
        #   - +tbl_name+ -> Of type String, the name of the table in which to look
        #   - +fdata_id+ -> The keyword_id of the library whos member count we wish to know
        # * *Returns* : 
        #   - +count+ -> The total number of members in this library
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def member_count( tbl_name, keyword_id, fdatatoc_id = nil)
            if ( fdatatoc_id == nil )
                sth = @link.prepare( "SELECT count(*) FROM fdatakeyword WHERE fdatakeyword.keyword_id=#{keyword_id}" )
            else
                sth = @link.prepare( "SELECT count(*) FROM fdatakeyword WHERE fdatakeyword.keyword_id=#{keyword_id} AND fdatakeyword.fdatatoc_id=#{fdatatoc_id}" )
            end
            sth.execute
            row = sth.fetch
            count = row[0]
            sth.finish
            return count
        end
        
        
        ############################################################################
        # * *Function*: Returns the given fdata_id's of the sequences whose fdata_id=FK_fgroup_id
        # 
        # * *Usage*   : <tt>  getFdataIds( "Gene", "refGene", "chr1_1_fdata" )  </tt>  
        # * *Args*    : 
        #   - +tbl+ -> Of type String, the name of the table in which to look
        #   - +ftype_type+ -> The ftype_type of the fdata_id's we desire
        #   - +ftype_subtype+ -> The ftype_subtype of the fdata_id's we desire
        # * *Returns* : 
        #   - +Array+ -> An array of fdata_id's for this ftype and this table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def getFdataIds( ftype_type, ftype_subtype, tbl )
            result = Array.new
            chr_fgroup = tbl.sub( "fdata", "fgroup" )
            lib_type_id = get_ftype_index( ftype_type, ftype_subtype )
            sth = @link.prepare( "SELECT fdata_id FROM #{tbl}, #{chr_fgroup} where FK_ftype_id=#{lib_type_id} AND fdata_id=FK_fgroup_id;" )
            sth.execute
            while row = sth.fetch
                result.push( row[0] )
             end
             sth.finish
             return( result.uniq )
        end
       
       
        ############################################################################
        # * *Function*: When given an fdata_id, returns fname_value( aka gene name )
        # 
        # * *Usage*   : <tt>  get_fname_info( "chr1_1_fdata", 4236 )  </tt>  
        # * *Args*    : 
        #   - +tbl_name+ -> Of type String, the name of the table in which to look
        #   - +fdata_id+ -> Of type Fixnum, the fdata_id of the segment whose name
        # * *Returns* : 
        #   - +fname_value + -> The name( fname_value ) of this gene 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def get_fname_info( tbl_name, fdata_id )
            chr_fname  = tbl_name.sub( "fdata", "fname" )  # Derive name of <chr>_<type>_fname table from <chr>_<type>_fdata given
            sth = @link.prepare( "SELECT fname_id, fname_value FROM #{tbl_name}, #{chr_fname} where #{tbl_name}.FK_fname_id = #{chr_fname}.fname_id and #{tbl_name}.fdata_id=#{fdata_id};" )
            
            sth.execute
            row = sth.fetch
            fname_id, fname_value = row
            sth.finish
            return fname_value 
        end
        
    
        ############################################################################
        # * *Function*: Retrieve the different possible ftype_types in an Array 
        # 
        # * *Usage*   : <tt>  seg_overlap.ftype_types  </tt>  
        # * *Args*    : 
        #   - +none+  
        # * *Returns* : 
        #   - +Array+ -> An array of the different possible ftype_types
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def ftype_types
            rows = Array.new
            sth = @link.prepare( "SELECT * FROM ftype" )
            sth.execute
            while row = sth.fetch do
                rows.push row[1]
            end
            return rows
        end
        
        
        ############################################################################
        # * *Function*: Retrieve the different possible ftype_subtypes in an Array 
        # 
        # * *Usage*   : <tt>  seg_overlap.ftype_subtypes  </tt>  
        # * *Args*    : 
        #   - +none+  
        # * *Returns* : 
        #   - +Array+ -> An array of the different possible ftype_subtypes
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def ftype_subtypes
            rows = Array.new
            sth = @link.prepare( "SELECT * FROM ftype" )
            sth.execute
            while row = sth.fetch do
                rows.push row[2]
            end
            sth.finish
            return rows
        end
        
        ############################################################################
        # * *Function*: Retrieve the fdatatoc_id for the given fdata table/group 
        # 
        # * *Usage*   : <tt>  seg_overlap.get_fdatatoc_id( "chrY_1_fdata" ) </tt>  
        # * *Args*    : 
        #   - +table+ -> of type String, the name of the table whose fdatatoc_id we want  
        # * *Returns* : 
        #   - +fdatatoc_id+ -> A number, the fdatatoc_id of the given table
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def get_fdatatoc_id( table )
            sth = @link.prepare( "SELECT * FROM fdatatoc where fdatatoc_name=\"#{table}\"" )
            sth.execute
            fdatatoc_id = sth.fetch[0]
            sth.finish
            return fdatatoc_id
        end
        
        
        ############################################################################
        # * *Function*: Retrieve all complete list of chromosomes from fdatatoc where the type="fdata" 
        # 
        # * *Usage*   : <tt>  seg_overlap.get_chromosome_list( ) </tt>  
        # * *Args*    : 
        #   - +none+
        # * *Returns* : 
        #   - +Array+ -> The list of chromosomes (fdata tables) from the database
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def get_chromosome_list( )
            sth = @link.prepare( "SELECT fdatatoc_name FROM fdatatoc where fdatatoc_type=\"fdata\"" )
            sth.execute
            list = Array.new
            while row = sth.fetch do
                list.push row[0]
            end
            sth.finish
            return list
        end
        
        
        ############################################################################
        # * *Function*: Returns an array whose elements are all the possible falues for a particular column
        #   For example, the five possible values for libHistology is cancer, normal, pre-cancer, unchar. histology, and multi histology.
        #   This would return each of those possble values in an array
        # 
        # * *Usage*   : <tt>  seg_overlap.expand_column( "libHistology" )  </tt>
        # * *Args*    : 
        #   - +column_name+ -> The keyword_type whose possible values you wish to know  
        # * *Returns* : 
        #   - +Array+ -> The list of possible values for keyword_type={column_name}
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def expand_column( column_name )
            rows = Array.new
            sth = @link.prepare( "SELECT DISTINCT keyword_value FROM keyword WHERE keyword_type='#{column_name}'" )
            sth.execute
            while row = sth.fetch do
                rows.push row[0]
            end
            return rows
        end
        
        
        ############################################################################
        # * *Function*: Determines the total number of windows given the window size and window overlap
        # 
        # * *Usage*   : <tt>  seg_overlap.total_windows( "chrY_1_fdata", 500_000, 5_000 )  </tt>  
        # * *Args*    : 
        #   - +tbl+ -> The table which shall be queried with the sliding window approach( such as "chr1_1_fdata" )
        #   - ++ -> The window size
        #   - ++ -> The length of window overlap( i.e. there is 5,000 BP overlap between each window )
        # * *Returns* : 
        #   - +total+ -> The total number of windows that would result from this query 
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def total_windows( tbl, window_size, window_overlap )
            sth = @link.prepare( "SELECT max( fdata_stop ) from #{tbl}" );
            sth.execute
            max = sth.fetch[0]     # find the length of the sequence, so we know when to stop the sliding window
            sth.finish
    
            return 0 if window_size > max
    
            total, extra =( max - window_size ).divmod( window_size - window_overlap )
            total += 1
            total += 1 if( extra != 0 )
            return total
        end
        
        private
        ############################################################################
        # * *Function*: Retrieves the unique id( fypte_id ) of this ftype
        #   The purpose of this is to speed up the MySQL query, and eliminate unneccsary joins
        # 
        # * *Usage*   : <tt>  get_fypte_index( "EST", "all_est" )  </tt>  
        # * *Args*    : 
        #   - +type+ -> The ftype_type of our query
        #   - +subtype+ -> The ftype_subtype of our query
        # * *Returns* : 
        #   - +row+ -> The ftype_id( a number ) that corresponds to the given type/subtype
        # * *Throws* :
        #   - +none+ 
        ############################################################################
        def get_ftype_index( type, subtype )
            sth = @link.prepare( "SELECT ftype_id FROM ftype WHERE ftype.ftype_type=\"#{type}\" and ftype.ftype_subtype=\"#{subtype}\";" )
            sth.execute
            row = sth.fetch_array
            return row
        end
        
        
    end

end ; end # end module ISEA ; end module BRL
