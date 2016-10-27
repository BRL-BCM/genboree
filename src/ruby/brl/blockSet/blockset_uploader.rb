require 'brl/util/textFileUtil'
require 'brl/util/propTable'
require 'brl/blockSet/blockSet'
require 'brl/blockSet/block'
require 'brl/db/dbrc'  
require 'dbi'
include BRL::Util
include BRL::BlockSet

raise "\n\nERROR: missing the .tba file\n\n" unless(ARGV.size >= 1)
TBA_DB = "genboree"
BLOCKSET_LFF_TYPE = 'TBA'
begin
    STDERR.puts "#{Time.now} Begin MemUsage: #{MemoryInfo.getMemUsageStr})"
    # Loading properies, courtesy of Andrew
    PROP_KEYS = %w{ database_list
                    cache_list
                    ref_name
                    input_list
                    dbrc_key }
    optsArray =  [ ['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT], ['--input_list', '-i', GetoptLong::OPTIONAL_ARGUMENT ], 
                   ['--database_list', '-d', GetoptLong::OPTIONAL_ARGUMENT ], ['--cache_list', '-c', GetoptLong::OPTIONAL_ARGUMENT ], 
                   ['--refname', '-r', GetoptLong::OPTIONAL_ARGUMENT ], [ '--dbrc_key', '-k', GetoptLong::OPTIONAL_ARGUMENT ] ]
    progOpts = GetoptLong.new( *optsArray )
    optsHash = progOpts.to_hash
    propTable = BRL::Util::PropTable.new( File.open( optsHash['--propFile'] ) )
    # Allow override at the command line
    PROP_KEYS.each{  |propName|
        argPropName = "--#{propName}"
        propTable[propName] = optsHash[argPropName] unless(optsHash[argPropName].nil?)
    }
    puts propTable.inspect
    dbrc_key = propTable["dbrc_key"]
    
    info_hsh = Hash.new
    tmp_arr = []
    propTable.sort.each{ |v|  tmp_arr.push v[1] }
    tmp_arr[0].size.times{ |i| info_hsh[ tmp_arr[3][i] ] = tmp_arr[1][i], tmp_arr[0][i] }
    dbrc = BRL::DB::DBRC.new( "~/.dbrc", dbrc_key )
    dbh = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )
    # Grab database ID through genboree.refseq
    info_hsh.each_pair{ |k,v|
        sth = dbh.prepare( "SELECT refSeqId FROM genboree.refseq WHERE databaseName=\"#{v[0]}\"" )
        sth.execute
        info_hsh[k].push sth.fetch[0]
        sth.finish
    }

    # Cache's rid information for each db
    # Cache rid information for each source database
    info_hsh.each_pair{ |k,v|
        sth = dbh.prepare( "SELECT refname,rid FROM #{v[0]}.fref" )
        sth.execute
        info_hsh[k].push Hash.new
        while row=sth.fetch
            info_hsh[k][3][row[0]] = row[1]
        end
        sth.finish
    }
    
    # So, ultimately, info_hsh should look something like this:
    # Hash, whose value is an array, and that arrays last value is another hash of rids
    # {
    #     "hg17" => [ "genboree_r_13ddb754b00d7ded640aaab94d68c77d", "hg17_precache_file.dump", 358 (database_id), 
    #                 { "chr1"=>1, "chr2"=>2 (this is the rid table hash)  } ]
    #     "mm5" =>  [ "genboree_r_123a12901200f030e0031c199e90f0dc", "mm5_precache_file.dump", 359 (database_id), 
    #                 { "chr1"=>1, "chr2"=>2 (this is the rid table hash) } ]
    # }
    
    STDERR.puts "#{Time.now} Begin precache (MemUsage: #{MemoryInfo.getMemUsageStr})"
    # Load up dumped hash data
    pre_cache_hsh = Hash.new
    info_hsh.each_pair{ |k,v|
        STDERR.puts "#{Time.now} Begin precache for #{k}:#{v[1]} (MemUsage: #{MemoryInfo.getMemUsageStr})"
        pre_cache_hsh[k] = Hash.new
        f = TextReader.new( v[1] )
        f.each_line{ |line|
            key, val = line.split("\t")
            pre_cache_hsh[k][key] = val
        }
        f.close
    }
    
    STDERR.puts "#{Time.now} Precache loaded. (MemUsage: #{MemoryInfo.getMemUsageStr})"
    # Loop over each input file
    bset = BlockSet.new
    for in_file in propTable["input_list"]
        # Loads the target file into a TBA structure for processing later
        STDERR.puts "#{Time.now} #{in_file} Blockset loading.  (MemUsage: #{MemoryInfo.getMemUsageStr})"
        bset.load_maf_file( in_file )

        STDERR.puts "#{Time.now} Blockset loading complete.  Begin easy DB work.  (MemUsage: #{MemoryInfo.getMemUsageStr})"
        #---------------------------------------------------------------------------
        # Start generation of insert data
        #---------------------------------------------------------------------------
        # Grab next blockset_id
       dbh.do( "INSERT INTO #{TBA_DB}.blockset VALUES( null );" )
       blockset_id = dbh.func( :insert_id )
        
        # Create entry in table "thread"
        thread_insert =  "INSERT INTO #{TBA_DB}.thread VALUES "
        info_hsh.each_key{ |kk|
            vv = info_hsh[kk]
            # Grab ftypeid
            sth = dbh.prepare( "SELECT ftypeid FROM #{info_hsh[kk][0]}.ftype WHERE fmethod = '#{BLOCKSET_LFF_TYPE}' and fsource like '#{kk}%';" )
            sth.execute
            ftypeid = sth.fetch[0]
            thread_insert << " ( #{vv}, #{blockset_id}, #{ftypeid} ),"
            sth.finish
        }
        thread_insert.chop!
        dbh.do( thread_insert )
        
        # Lock tables here on out
        # We need to cache certain info so we can programmically consruct all inserts for speedy inserts
        # Lock DB (couldn't earlier because I can't lock fdata2)
        dbh.do( "LOCK TABLES block WRITE, block_element WRITE, thread WRITE, blockset WRITE;" )
        
        use_db = nil
        insert_str = ""
        b = bset.first
        insert_block = "INSERT INTO #{TBA_DB}.block VALUES( null, #{b.score}, #{blockset_id} );"
        dbh.do( insert_block )
        # grab our new block_id
        block_id = dbh.func( :insert_id ).to_i
        block_insert = File.open( "block_insert.infile", File::CREAT|File::APPEND|File::RDWR )
        block_element_insert = File.open( "block_element_insert.infile", File::CREAT|File::APPEND|File::RDWR )
        # Now, we must extract FID, RID from the database to build the TBA database tables
        first = true
        flush_counter = 0
        STDERR.puts "#{Time.now} BSET.size = #{bset.size}. Starting main loop.  (MemUsage: #{MemoryInfo.getMemUsageStr})"
        bset.each{ |block|
            # Add this block to table block
            block_insert << "#{block_id}\t#{block.score}\t#{blockset_id}\n" unless first
            block.each{ |element|
                # Since we left out "random" data before, we must skip it now as well
                next if element[0].split('.')[1].include?( "random" )
                # BUG: WHY DO I HAVE FID AND RID THAT ARE NIL? THIS SHOULD NOT BE HAPPENING
                database_id = info_hsh[ element[0].split(".")[0] ][2]
                rid         = info_hsh[ element[0].split(".")[0] ][3][element[0].split(".")[1]]
                fid = pre_cache_hsh[ element[0].split(".")[0] ]["#{element[1]}!#{element[1] + element[2]}!#{block.score}!#{rid}"]
                block_element_insert << "null\t#{database_id}\t#{fid}\t#{rid}\t#{block_id}\n" unless fid.nil?
                flush_counter += 1
            }
            # Because we have memory issues, batch out the mysql inserts
            if flush_counter.size > 2500
                block_element_insert.close
                block_insert.close
                block_insert = File.open( "block_insert.infile", File::CREAT|File::APPEND|File::RDWR )
                block_element_insert = File.open( "block_element_insert.infile", File::CREAT|File::APPEND|File::RDWR )
                flush_counter = 0
                STDERR.puts "#{Time.now} Flushing data to disk.  (MemUsage: #{MemoryInfo.getMemUsageStr})"
            end
            block_id += 1
            first = false
        }
        bset.clear # free up memory for next iteration in loop
        block_element_insert.close
        block_insert.close
        # Perform the mysql LOAD DATA INFILE to actually load the data into the DB
        STDERR.puts "#{Time.now} Begin block_element upload (MemUsage: #{MemoryInfo.getMemUsageStr})"
        dbh.do( "LOAD DATA LOCAL INFILE 'block_element_insert.infile' INTO TABLE genboree.block_element" )
        STDERR.puts "#{Time.now} Begin block updload (MemUsage: #{MemoryInfo.getMemUsageStr})"
        dbh.do( "LOAD DATA LOCAL INFILE 'block_insert.infile' INTO TABLE genboree.block" )
        STDERR.puts "Finish data upload @ #{Time.now}\n\n (MemUsage: #{MemoryInfo.getMemUsageStr})"
    end
ensure
    # ensure we release our MySQL locks and close our connection
    dbh.do( "UNLOCK TABLES;" )
    dbh.disconnect
end
