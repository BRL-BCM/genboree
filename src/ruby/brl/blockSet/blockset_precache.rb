#!/usr/bin/env ruby
$VERBOSE = 1

# Author: Matthew Linnell
# March 3rd, 2005
#-------------------------------------------------------------------------------
# Usage:
#     ruby blockset_precache.rb source_db, fsource, outfile
#     ruby blockset_precache.rb genboree_r_13ddb754b00d7ded640aaab94d68c77d, mm5.tba, mm5.tba.dump
#-------------------------------------------------------------------------------
require 'brl/util/textFileUtil'
require 'dbi'
require 'brl/db/dbrc'
include BRL::Util


# Usage
TBA_DB = "genboree"
begin
    # The source database for generating the cache, e.g. genboree_r_13ddb754b00d7ded640aaab94d68c77d
    source_db = ARGV[0]
    fsource   = ARGV[1]
    dump_file = ARGV[2]

          # WRONG!
          # Must use brl/genboree/dbUtil to connect to genboree
          # This will (a) not work anyway in this case and (b) runs the risk of
          # breaking in the multi-db-machine scenario we are using.
          # DbUtil is aware of multi-db-machine possibility and also does some connection caching as well.
    dbrc = BRL::DB::DBRC.new( "~/.dbrc", "genboree" I_AM_BROKEN_FOR_GENBOREE_DATABSE_HANDLES)
    dbh = DBI.connect( dbrc.driver, dbrc.user, dbrc.password )
    STDERR.puts "Begin @ #{Time.now}"
    # Grab database ID through genboree.refseq
    sth = dbh.prepare( "SELECT refSeqId FROM genboree.refseq WHERE databaseName=\"#{source_db}\"" )
    sth.execute
    db_id = sth.fetch[0]

    # Precache fdata2 data
    # First, lookup ftypeid for TBA
    sth = dbh.prepare( "SELECT ftypeid from #{source_db}.ftype WHERE fmethod=\"TBA\" AND fsource=\"#{fsource}\" " )
    sth.execute
    ftypeid = sth.fetch[0]
    STDERR.puts "Large query @ #{Time.now}"
    # Select str for grabbing the information to cache
    pre_cache_str = "SELECT concat_ws('!',fstart,fstop,fscore,rid),fid,rid FROM #{source_db}.fdata2 WHERE ftypeid=#{ftypeid};"
    pre_cache_hsh = Hash.new
    # Store fid, rid in a hash where the key is the concatted string fstart/fstop/fscore/gname
    # The hash key is delited using !, for use in debugging, testing, and verification
    sth = dbh.prepare( pre_cache_str )
    sth.execute
    STDERR.puts "Large query executed, done @ #{Time.now}"
    while row=sth.fetch
        pre_cache_hsh[row[0]] = [row[1], row[2]]
    end
    STDERR.puts "Hash built @ #{Time.now}"
    sth.finish
    dbh.disconnect

    # Dump the hash data to file, so we can use it for each run
    File.open( "#{dump_file}", "w+" ) do |f|
        pre_cache_hsh.each_key{ |k|
            f << "#{k}\t#{pre_cache_hsh[k][0]}\t#{pre_cache_hsh[k][1]}\n"
        }
    end
    STDERR.puts "File dumped @ #{Time.now}"
end
