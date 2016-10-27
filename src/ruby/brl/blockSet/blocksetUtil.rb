# Matthew Linnell
# 2/15/2005
#-------------------------------------------------------------------------------

require 'dbi'
require 'brl/db/dbrc'
require 'brl/sql/binning'
include BRL::SQL

module BRL; module BlockSet
    ########################################################################
    # * *Function*: Determines what blocks exist in the TBA database which hit a given region of a read.  Useful for determining to what other genomes one can "jump" to.
    #
    # * *Usage*   : <tt>  hit( source_db, begin_index, end_index, chromosome_num )  </tt>
    # * *Args*    :
    #   - +source_db+ -> of type String, the name of the source database
    #   - +begin_index+ -> of type Fixnum, the basepair index to start our search
    #   - +end_index+ -> of type Fixnum, the basepair index to end our search
    #   - +ridSeqId+ -> of type Fixnum, the chromosome number (rid) you wish to search in
    #   - +fsource+ -> of type String, the nmae of the fsource for this particular data.  This is necessary because a database can contain more than one source of blockset alignment data.
    # * *Returns* :
    #   - +Array+ -> An array of block_id's that hit the specified region.
    # * *Throws* :
    #   - +ArgumentError+ -> Throws argument error if the begin_index > end_index
    ########################################################################
    def hit( source_db, begin_index, end_index, chromosome_num, fsource )
        begin
          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
            dbrc = BRL::DB::DBRC.new( "~/.dbrc", "genboree" I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
            dbh = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )
            raise ArgumentError if begin_index.to_i > end_index.to_i

            # determine rid from chromosome number
            sth = dbh.prepare( "SELECT ridSeqId FROM #{source_db}.ridSequence WHERE seqFileName=\"chr#{chromosome_num}.fa\" " )
            sth.execute
            rid = sth.fetch[0]

            # get database_id's for use later
            sth = dbh.prepare( "SELECT refSeqId FROM genboree.refseq WHERE databaseName=\"#{source_db}\"" )
            sth.execute
            db_id = sth.fetch

            # Grab ftypeid for TBA on this database
            sth = dbh.prepare( "SELECT ftypeid FROM #{source_db}.ftype WHERE fmethod=\"TBA\" AND fsource=\"#{fsource}\" " )
            sth.execute
            ftypeid = sth.fetch[0]

            # Get min bin size
            sth = dbh.prepare( "SELECT fvalue FROM  #{source_db}.fmeta WHERE fname=\"MIN_BIN\" " )
            sth.execute
            minbin = sth.fetch[0]

            b = Binning.new
            lowbin = b.bin( minbin, begin_index, begin_index )
            highbin = b.bin( minbin, end_index, end_index )
            # Get all fid/rid's for TBA's in this region
            select_str = "SELECT fid,rid FROM #{source_db}.fdata2 WHERE ( ( fstart <= #{begin_index} AND fstop >= #{end_index} ) OR ( fstart <= #{begin_index} AND fstop >= #{end_index} ) OR ( fstart >= #{begin_index} AND fstop <= #{end_index} ) ) AND ftypeid=#{ftypeid} AND rid=#{rid} AND fbin >= #{lowbin} AND fbin <= #{highbin}"
            sth = dbh.prepare( select_str )
            sth.execute
            fid_arr = []
            while row=sth.fetch
                fid_arr.push row.clone
            end
            if fid_arr.empty?
                return []
            else
                # Get block_id's for the blocks that hit in this region
                select_str = "SELECT block_element.block_id FROM genboree_blockset.block_element WHERE genboree_blockset.block_element.database_id = #{db_id} AND ("
                first = true
                fid_arr.each{ |fid,rid|
                    select_str << " OR " unless first
                    select_str << "  ( genboree_blockset.block_element.fid = #{fid} AND genboree_blockset.block_element.rid = #{rid} ) "
                    first = false
                }
                select_str << ");"
                sth = dbh.prepare( select_str )
                sth.execute

                results_arr = []
                while row=sth.fetch
                    results_arr.push row[0]
                end
            end
        rescue ArgumentError => e
            $stderr.puts "ERROR. The 'start' (2nd argument) may not be larger than the stop (3rd argument)."
        ensure
            dbh.disconnect
        end
        return results_arr.sort
    end

    ########################################################################
    # * *Function*: Used by jump() to determine base offset taking into account gaps "-"
    ########################################################################
    def count_dash_downstream( seqA, index )
        count = 0
        seqA[index+1..-1].each_byte{ |i|
            if i=="-"[0]
                count += 1
            else
                break
            end
        }
        return count
    end

    ########################################################################
    # * *Function*: Used by jump() to determine base offset taking into account gaps "-"
    ########################################################################
    def count_dash_upstream( seqA, index )
        count = 0
        seqA[0..index-1].reverse.each_byte{ |i|
            if i=="-"[0]
                count += 1
            else
                break
            end
        }
        return count
    end

    ########################################################################
    # * *Function*: Determines what basepair to jump to in a target genome iven source database, if possible
    #
    # * *Usage*   : <tt>  jump( source_db, target_db, base_index, chromosome_num )  </tt>
    # * *Args*    :
    #   - +source_db+ -> of type String, the name of the source database
    #   - +target_db+ -> of type String, the name of the source database
    #   - +base_index+ -> of type Fixnum, the basepair index to start our search
    #   - +ridSeqid+ -> of type Fixnum, the chromosome number (rid) you wish to search in
    #   - +fsource+ -> of type String, the nmae of the fsource for this particular data.  This is necessary because a database can contain more than one source of blockset alignment data.
    # * *Returns* :
    #   - +Array+ -> The basepair index in the given target chromosome to which the current base aligns.
    # * *Throws* :
    #   - +ArgumentError+ -> Throws argument error if the begin_index > end_index
    ########################################################################
    def jump( source_db, target_db, base_index, chromosome_num, fsource )
        begin
          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
            dbrc = BRL::DB::DBRC.new( "~/.dbrc", "genboree"  I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
            dbh = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )

            # get database_id's for use later
            sth = dbh.prepare( "SELECT refSeqId FROM genboree.refseq WHERE databaseName=\"#{source_db}\"" )
            sth.execute
            db_idA = sth.fetch
            sth = dbh.prepare( "SELECT refSeqId FROM genboree.refseq WHERE databaseName=\"#{target_db}\"" )
            sth.execute
            db_idB = sth.fetch

            # get ftypeid for TBA in first DB
            sth = dbh.prepare( "SELECT ftypeid FROM #{source_db}.ftype WHERE ftype.fmethod=\"TBA\" AND ftype.fsource=\"#{fsource}\"; " )
            sth.execute
            ftypeid = sth.fetch[0]

            # Get min bin size
            sth = dbh.prepare( "SELECT fvalue FROM  #{source_db}.fmeta WHERE fname=\"MIN_BIN\" OR fname=\"MAX_BIN\" ORDER BY fname" )
            sth.execute
            maxbin = sth.fetch[0]
            minbin = sth.fetch[0]


            # determine rid from chromosome number
            sth = dbh.prepare( "SELECT ridSeqId FROM #{source_db}.ridSequence WHERE seqFileName=\"chr#{chromosome_num.to_s.upcase}.fa\" " )
            sth.execute
            rid = sth.fetch[0]

            offset = nil
            b = Binning.new
            bin_whereclause = b.makeBinSQLWhereExpression( base_index.to_i, base_index.to_i, minbin.to_i, maxbin.to_i)
            source_hsh = Hash.new

            # First, find out which fid's overlap with this base
            fid_fstart_hsh, fid_arr = [], []
            select_str = "SELECT fdata2.fid, fdata2.fstart FROM #{source_db}.fdata2 WHERE fdata2.ftypeid=#{ftypeid} AND #{bin_whereclause} AND fdata2.rid=#{rid} AND (  #{base_index} >= fstart AND #{base_index} < fstop );"
            #puts "SELECT fdata2.fid, fdata2.fstart FROM #{source_db}.fdata2 WHERE fdata2.ftypeid=#{ftypeid} AND #{bin_whereclause} AND fdata2.rid=#{rid} AND (  #{base_index} >= fstart AND #{base_index} < fstop )"
            sth = dbh.prepare( select_str )
            sth.execute
            while row=sth.fetch
                fid_fstart_hsh[row[0]] = [ row[1] ]
                fid_arr.push row[0]
            end
            return [] if fid_arr.size == 0

            # Next, grab the relevant fidText data for this list of fid's
            select_str = "SELECT fidText.fid, fidText.text FROM #{source_db}.fidText WHERE fidText.fid IN ( #{fid_arr.join(',')} );"
            sth = dbh.prepare( select_str )
            sth.execute
            while row=sth.fetch
                fid_fstart_hsh[row[0]].push row[1]
            end

            # Lastly, get the block_id's for each of the fid's
            select_str = "SELECT block_element.fid, block_element.block_id FROM genboree_blockset.block_element WHERE block_element.fid IN ( #{fid_arr.join(',')} ) AND database_id=#{db_idA} AND block_element.rid=#{rid}"
            sth = dbh.prepare( select_str )
            sth.execute
            while row=sth.fetch
                source_hsh[row[1]] = fid_fstart_hsh[row[0]]
            end
            target_hsh = Hash.new
            if source_hsh.size > 0
                # Now, check each of these blocks for the target to jump to
                count = 0
                blk_str = " ( "
                source_hsh.each_pair{ |key,val|
                    blk_str << " block_id=#{key} "
                    if count < source_hsh.size-1
                        blk_str << " OR "
                    end
                    count += 1
                }
                blk_str << " ) "
                sth = dbh.prepare( "SELECT block_element.*, fidText.text FROM genboree_blockset.block_element, #{target_db}.fidText WHERE #{blk_str} AND database_id=\"#{db_idB}\" AND fidText.fid=block_element.fid" )
                sth.execute
                while row=sth.fetch
                    target_hsh[row[4]] = row.clone
                end
            end

            # If target_hsh is zero size, we cannot jump
            answer = []
            target_hsh.each_pair{ |key,val|
                offset = base_index.to_i - source_hsh[key][0] + 1
                count, index = 0, 0
                source_hsh[key][1].each_byte{ |b|
                    count += 1 unless b == "-"[0]
                    if count == offset
                        offset = index
                        break
                    end
                    index += 1
                }
                select_str = "SELECT #{target_db}.fdata2.fstart, #{target_db}.fidText.text, #{target_db}.fdata2.gname FROM #{target_db}.fdata2,#{target_db}.fidText WHERE fdata2.fid = #{val[2]} AND fdata2.rid = #{val[3]} AND fidText.fid = #{val[2]} "
                sth = dbh.prepare( select_str )
                sth.execute
                final_data = sth.fetch
                # If we "jump" into a region with "-", we need to round up or down depending on which direction is closer
                roundup = false
                if val[5][ offset,1 ] == "-"
                    up = count_dash_upstream( val[5], offset )
                    down = count_dash_downstream( val[5], offset )
                    # The first half of this if statement determines whether to round up or down in the sequence
                    # when jumping to a gap.  If we are closer to the upstream region, round upstream, and vice versa
                    # if we are in the middle, go upstream
                    # the second half of this if statement checks for the case of jumping to the gap of a gene which *starts* with a gap
                    # in other words, if we have a sequence "------ATGC" and we jump into that gap, we never round down, always up.
                    round_downstream = true if down < up || ( offset-up == 0 && val[5][0,1] == "-" )
                end

                # If we terminate within a "-" we can do 1 of 2 things, round up, or round down
                # by default the system rounds down, so if the # "-" upstream is less than down,
                # we should round up
                if round_downstream
                    # the first non "-" we enounter append to final data
                    final_data[1][offset..-1].each_byte{ |i|
                        if i == "-"[0]
                            next
                        else
                            final_data[1][offset] = i
                            break
                        end
                    }
                end
                #puts source_hsh[key].inspect
                #puts final_data.inspect

                final_data[1] = final_data[1].slice( 0, offset+1 )
                final_data[1].delete!( "-" )
                answer.push "#{ final_data[2].split(".")[0]}:#{final_data[0]+final_data[1].size-1}"
            }
            answer
        rescue ArgumentError => e
            $stderr.puts "ERROR.  Incorrect input format."
            $stderr.puts "Usage: ruby blockset_jump.rb source_database target_database index chr#"
            $stderr.puts "For example:"
            $stderr.puts "\truby blockset_jump.rb genboree_r_1562e5ad604bf9b381736710a7066e90 genboree_r_4199ed4c7575fd782e1b51e616deb724 56150394 1"
        ensure
            dbh.disconnect
        end
        return answer.sort!
    end

    ########################################################################
    # * *Function*: Get the fdata information for where we can jump to from this block_element
    #
    # * *Usage*   : <tt>  block_jump( block_id )  </tt>
    # * *Args*    :
    #   - +source_db+ -> of type Fixnum, the block_id of interest
    # * *Returns* :
    #   - +Array+ -> An array of DBI::Rows that represent the fdata2 entries for each block element in the block of interest
    ########################################################################
    def block_jump( block_id )
        fdata_list = []
        begin
          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
            dbrc = BRL::DB::DBRC.new( "~/.dbrc", "genboree"  I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
            dbh = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )

            # Get a list of other blocks with the same block_id (sister block_elements)
            sth = dbh.prepare( "SELECT * FROM genboree_blockset.block_element WHERE block_id = #{block_id}" )
            sth.execute
            block_elements = sth.fetch_all
            sth.finish

            # now, grab fdata2 data for each of these block_elements
            db_hsh = Hash.new
            block_elements.each{ |be|
                # First, we must know which database to look in
                if db_hsh[be[1]] != nil
                    db_name = db_hsh[be[1]]
                else
                    sth = dbh.prepare( "SELECT databaseName FROM genboree.refseq WHERE refSeqId=#{be[1]}" )
                    sth.execute
                    db_name = sth.fetch[0]
                    db_hsh[be[1]] = db_name
                    sth.finish
                end

                # Now, grab the fdata2 information from that database for this block element
                sth = dbh.prepare( "SELECT * FROM #{db_name}.fdata2 WHERE fid=#{be[2]} AND rid=#{be[3]}" )
                sth.execute
                while row = sth.fetch
                    fdata_list.push [be[1], row]
                end
                sth.finish
            }
        #ensure
            dbh.disconnect
        end
        return fdata_list
    end

    ############################################################################
    # * *Function*: Return the multiway aligment for the given block
    #
    # * *Usage*   : <tt>  get_alignment( block_id )  </tt>
    # * *Args*    :
    #   - +block_id+ -> of type Fixnum, the block_id of interest
    # * *Returns* :
    #   - +Array+ -> An array of block_element data where [ [ "hg17", "geneA", "start", "stop", "{seq}" ], [ "mm5", "geneAorthologue", "start", "stop", "{seq}" ] ]
    ############################################################################
    def get_alignment( block_id )
        answer = []
          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
        dbrc = BRL::DB::DBRC.new( "~/.dbrc", "genboree"  I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
        dbh  = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )

        # Get all the block elements involved in this aligment
        sth = dbh.prepare( "SELECT * FROM genboree_blockset.block_element WHERE block_id=#{block_id}" )
        sth.execute
        while row=sth.fetch
            answer.push( row.clone )
        end
        return nil if answer.size == 0
        # Based grab the annotation and its sequence from its respective database
        hsh = Hash.new
        answer.each{ |row| hsh[row[1]] = row[2..5] }
        sth = dbh.prepare( "SELECT refSeqId, databaseName, refseq_version FROM refseq WHERE refSeqId IN ( #{hsh.keys.join(",")} )" )
        sth.execute
        while row=sth.fetch
            hsh[ row[0] ].push row[1], row[2]
        end
        sth.finish
        hsh.each_key do |key|
            val = hsh[key]
            sth = dbh.prepare( "SELECT gname, fstart, fstop FROM #{val[3]}.fdata2 WHERE fid=#{val[0]}" )
            sth.execute
            hsh[key].push sth.fetch
            sth.finish
            sth = dbh.prepare( "SELECT text FROM #{val[3]}.fidText WHERE fid=#{val[0]}" )
            sth.execute
            hsh[key].push sth.fetch[0]
            sth.finish
        end
        algn = []
        hsh.each_key{ |key| algn.push [ hsh[key][4], hsh[key][5][0],hsh[key][5][1],hsh[key][5][2], hsh[key][6] ]}
        return algn
    end

end ; end # module BRL, module BlockSet
