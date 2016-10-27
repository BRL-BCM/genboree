
# ARJ - 2008/05/02
# Adds the missing barbed_wire_noLine_draw entry to style table in datatbases
# which are missing it.
#
# usage: ruby addBarbedNoLines.rb

require 'brl/db/dbrc'
require 'brl/db/util'

# Get connection user/pass for main genboree database from user's ~/.dbrc file
dbrc = BRL::DB::DBRC.new('~/.dbrc', 'genboreeGlycine')
# Get database handle
dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password) ;
# Get map of user database to host machines
rs = dbh.execute("select * from database2host")
d2h = rs.fetch_all
# We're done with main genboree database
rs = nil
dbh.disconnect

# Look at each user database and add the missing row if  it's not there
d2h.each {|row|
  next if(row[1].strip == 'genboree') # skip main genboree database
  # Based on which host, create new DBRC object with connection info for that server
  # (user running this app must have the 2 DBRC keys listed below)
  if(row[2] =~ /tyrosine/)
    dbrc2 = BRL::DB::DBRC.new('~/.dbrc', 'genboreeTyrosine')
  elsif(row[2] =~ /brl6\.hgsc/)
    dbrc2 = BRL::DB::DBRC.new('~/.dbrc', 'genboreeBrl6')
  else
    raise "ERROR=> what database host is #{row[2]}??"
  end
  # The driver string from the .dbrc will be for a -different- database, so
  # patch in -our- database using gsub
  driver = dbrc2.driver.gsub(/genboree|tmp/, row[1])
  # Get connection using the modified driver string
  dbh2 = DBI.connect(driver, dbrc2.user, dbrc2.password)
  # See if barbed_wire_noLine_draw is in the style table or not
  # (we just need 1 row so we use select_one for simplicity/speed...either there's 0 rows or there's 1+)
  sRow = dbh2.select_one("select styleId from style where name = 'barbed_wire_noLine_draw'")
  if(sRow.nil?) # missing barbed_wire_noLine_draw
    puts "inserting missing style into #{driver}"
    dbh2.do("insert into style values (null, 'barbed_wire_noLine_draw', 'Barbed-Wire Rectangle (no lines)')")
  end
  # Done with this user database, so disconnect & promote GC
  dbh2.disconnect
  dbh2 = nil
}

exit(0)
