#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: Data importer tool

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'dbi'
# ##############################################################################
# CONSTANTS
# ##############################################################################
FATAL = BRL::Genboree::FATAL
OK = BRL::Genboree::OK
OK_WITH_ERRORS = BRL::Genboree::OK_WITH_ERRORS
FAILED = BRL::Genboree::FAILED
USAGE_ERR = BRL::Genboree::USAGE_ERR

# ##############################################################################
# HELPER FUNCTIONS AND CLASS
# ##############################################################################
# Process command line args
# Note:
#      - did not find optional extra alias files
def processArguments()
  optsArray = [
                ['--hostFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                ['--assembly', '-a', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--overriding', '-y', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileName', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--dDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--convertName', '-v', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-c', GetoptLong::REQUIRED_ARGUMENT],
                ['--emailAddress', '-e', GetoptLong::REQUIRED_ARGUMENT],
                ['--targetSpecies', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                ['--querySpecies', '-q', GetoptLong::OPTIONAL_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  # Try to use getMissingOptions() from Ruby's standard GetoptLong class
  optsMissing = progOpts.getMissingOptions()
  # If no argument given or request help information, just print usage...
  if(optsHash.empty? or optsHash.key?('--help'))
    usage()
    exit(USAGE_ERR)
  # If there is NOT any required argument file missing, then return an empty array; otherwise, check whether it is REQUIRED_ARGUMENT missing, if yes, then report error
  elsif(optsMissing.length != 0)
    if(!optsHash.key?('--hostFile') or !optsHash.key?('--assembly') or !optsHash.key?('--trackName') or !optsHash.key?('--overriding') or !optsHash.key?('--className') or !optsHash.key?('--fileName') or !optsHash.key?('--dDirectoryOutput') or !optsHash.key?('--convertName') or !optsHash.key?('--cDirectoryOutput') or !optsHash.key?('--emailAddress'))
      usage("Error: the REQUIRED args are missing!")
      exit(USAGE_ERR)
    else
      usage("Error: the OPTIONAL args are missing! Running program depends on which converter to use! Please check its necessity first (see usage info)")
      exit(USAGE_ERR)
    end
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  This program can take the user input/selection of remote UCSC track information, and  
  1) Downloads fosEndPairs table from UCSC and converts it to equivalent LFF version.
  2) Downloads chain table from UCSC and converts it to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --hostFile              | -o    => UCSC host address to contact
    --assembly              | -a    => The template the user's database is based on
    --trackName             | -t    => Track name for of the remote data to acquire
                                       (type:subtype)
    --overriding            | -y    => Track (type:subtype) overriding option for user to pick
                                       Does not allow overriding (1); Allow type only (2); Allow subtype only (3); Allow both (4) 
    --className             | -l    => Class name for of the remote data to acquire
    --fileName              | -f    => File name to download and convert
    --dDirectoryOutput      | -d    => The directory where downloaded files should go
    --convertName           | -v    => Converted file name
    --cDirectoryOutput      | -c    => The directory where converter output should go
    --emailAddress          | -e    => Email address providing to downloader
    --targetSpecies         | -s    => target species provided for chain data
    --querySpecies          | -q    => query species provided for chain data 
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1)
  ruby BRL_UCSC_importer.rb -o host -a assembly -t trackName -y overriding -l className -f fileList -d dDirectoryOutput -v convertName -c cDirectoryOutput -e emailAddress
  i.e.
  ruby BRL_UCSC_importer.rb -o hgdownload.cse.ucsc.edu -a hg18 -t Fosmid:EndPairs -y 1 -l 'End Pairs' -f fosEndPairs.txt.gz -d /users/ybai/work/Project1/test_Downloader -v fosEndPairs_LFF.txt -c /users/ybai/work/Project1/test_Converter -e ybai@ws59.hgsc.bcm.tmc.edu
  2)
  ruby BRL_UCSC_importer.rb -o host -a assembly -t trackName -y overriding -l className -f fileList -d dDirectoryOutput -v convertName -c cDirectoryOutput -e emailAddress -s targetSpecies -q querySpecies
  i.e.
  ruby BRL_UCSC_importer.rb -o hgdownload.cse.ucsc.edu -a hg18 -t Alignment:Chain -y 1 -l 'Comparative Genomics' -f chr1_chainPanTro2.txt.gz -d /users/ybai/work/Project1/test_Downloader -v chr1_chainPanTro2_LFF.txt -c /users/ybai/work/Project1/test_Converter -e ybai@ws59.hgsc.bcm.tmc.edu -s Human -q Chimp
"
end

class MyImporter
  def initialize(inputsHash)
  end 

  def mysql(opts, stream)
    IO.popen("mysql #{opts}", 'w') {|io| io.puts stream}
  end

  def import(inputsHash) 
    hostFile = inputsHash['--hostFile'].strip
    assembly = inputsHash['--assembly'].strip
    trackName = inputsHash['--trackName'].strip
    overriding = inputsHash['--overriding'].strip
    className = inputsHash['--className'].strip
    fileName = inputsHash['--fileName'].strip
    dDirectoryOutput = inputsHash['--dDirectoryOutput'].strip
    convertName = inputsHash['--convertName'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip
    emailAddress = inputsHash['--emailAddress'].strip
    user_input = trackName.split(/:/)
    if("#{className}" == "Comparative Genomics")
      targetSpecies = inputsHash['--targetSpecies'].strip
      querySpecies = inputsHash['--querySpecies'].strip
    end

    # make downloading and converting directories
    Dir.mkdir("#{dDirectoryOutput}")
    Dir.mkdir("#{cDirectoryOutput}")

    self.mysql '-u root', <<-end
      drop database if exists importer_db;
      create database importer_db;
      grant all on importer_db.* to #{`id -un`.strip}@localhost;
    end

    begin
      # connect to the MySQL server
      dbh = DBI.connect("DBI:Mysql:importer_db:localhost", "root")

      row = dbh.select_one("SELECT VERSION()")
      puts "Server version: " + row[0]

      puts "==== Operation for table data_acquisition =================="
      ## Operation for table "data_acquisition"
      dbh.do("DROP TABLE if exists data_acquisition")

      dbh.do("CREATE TABLE data_acquisition(
        db_name VARCHAR(30) NOT NULL, 
        remote_track_name VARCHAR (41) NOT NULL, 
        class_name VARCHAR(40) NOT NULL, 
        PRIMARY KEY (db_name, remote_track_name, class_name)         
      )")

      # prepare statement for use within insert loop
      sth = dbh.prepare("INSERT INTO data_acquisition(db_name, remote_track_name, class_name) VALUES(?, ?, ?)")
      # read each line from file, split into values, and insert into database
      File.open("data_acquisition_data.txt", "r") do |f|
        f.each_line do |line|
          db_name, remote_track_name, class_name = line.chomp.split("\t")
          sth.execute(db_name, remote_track_name, class_name)
        end
      end

      puts "A list of remote data (tracks) that are compatible with user selected database - #{assembly}:"
      sth = dbh.execute("SELECT data_acquisition.remote_track_name FROM data_acquisition WHERE data_acquisition.db_name = '#{assembly}'")
      sth.fetch do |row| 
        puts "#{assembly} \t" + row[0]
      end
      sth.finish

      puts "==== Operation for table track =================="
      ## Operation for table "track"
      dbh.do("DROP TABLE if exists track")

      dbh.do("CREATE TABLE track(
        track_name VARCHAR (41) NOT NULL,
        type VARCHAR (20) NOT NULL, 
        sub_type VARCHAR (20) NOT NULL, 
        PRIMARY KEY (track_name, type, sub_type)
      )")

      # insert rows for track
      track_rows = dbh.do("INSERT INTO track(track_name, type, sub_type)
        VALUES
          ('#{trackName}','#{user_input[0]}','#{user_input[1]}')")
      puts "Number of rows inserted: #{track_rows}"

      sth = dbh.execute("SELECT track.track_name FROM data_acquisition, track WHERE data_acquisition.remote_track_name = track.track_name AND data_acquisition.remote_track_name = '#{trackName}'")
      sth.fetch do |row| 
        puts "There is remote track(s) available for this input! The following track can be loaded:"
        puts row[0]
      end
      sth.finish

      puts "==== Operation for table downloader_argument =================="
      ## Operation for table "downloader_argument"
      dbh.do("DROP TABLE if exists downloader_argument")

      dbh.do("CREATE TABLE downloader_argument(
        d_tool_name VARCHAR (100) NOT NULL,
        remote_track_name VARCHAR (41) NOT NULL,
        class_name VARCHAR (40) NOT NULL,
        file_to_download VARCHAR (60) NOT NULL,
        d_directory_output VARCHAR (100) NOT NULL,
        assembly VARCHAR (30) NOT NULL,
        host VARCHAR (60) NOT NULL, 
        email VARCHAR (40) NOT NULL, 
        PRIMARY KEY (d_tool_name, remote_track_name, class_name, file_to_download, d_directory_output),
        FOREIGN KEY (remote_track_name) REFERENCES track (track_name) ON DELETE CASCADE,
        FOREIGN KEY (class_name) REFERENCES data_acquisition (class_name) ON DELETE CASCADE,
        FOREIGN KEY (assembly) REFERENCES data_acquisition (db_name) ON DELETE CASCADE
      )")

      # insert some rows for downloader argument
      downloader_rows = dbh.do("INSERT INTO downloader_argument(d_tool_name,remote_track_name,class_name,file_to_download,d_directory_output,assembly,host,email) 
        VALUES 
          ('BRL_UCSC_downloader.rb','#{user_input[0]}:#{user_input[1]}','#{className}','#{fileName}','#{dDirectoryOutput}','#{assembly}','#{hostFile}','#{emailAddress}')")
      puts "Number of rows inserted: #{downloader_rows}"

      sth = dbh.execute("
              SELECT downloader_argument.d_tool_name, downloader_argument.host, downloader_argument.assembly, downloader_argument.file_to_download, downloader_argument.d_directory_output, downloader_argument.email
              FROM downloader_argument, track, data_acquisition
              WHERE downloader_argument.remote_track_name = track.track_name
              AND downloader_argument.class_name = data_acquisition.class_name
              AND downloader_argument.assembly = data_acquisition.db_name
              AND data_acquisition.db_name = '#{assembly}'")
      sth.fetch do |row|
        col0 = row[0] 
        col1 = row[1] 
        col2 = row[2] 
        col3 = row[3] 
        col4 = row[4] 
        col5 = row[5] 
        # downloader start working...
        system("ruby #{col0} -o #{col1} -a #{col2} -f #{col3} -d #{col4} -e #{col5}")
      end
      sth.finish


      puts "==== Operation for table converter_argument =================="
      ## Operation for table "converter_argument"
      dbh.do("DROP TABLE if exists converter_argument")

      dbh.do("CREATE TABLE converter_argument(
        c_tool_name VARCHAR (100) NOT NULL,
        remote_track_name VARCHAR (41) NOT NULL,
        class_name VARCHAR (40) NOT NULL,
        type VARCHAR (20) NOT NULL, 
        sub_type VARCHAR (20) NOT NULL, 
        file_to_convert VARCHAR (60) NOT NULL,
        c_directory_input VARCHAR (100) NOT NULL,
        t_species VARCHAR (40),
        q_species VARCHAR (40),
        file_to_output VARCHAR (60) NOT NULL,
        c_directory_output VARCHAR (100) NOT NULL,
        PRIMARY KEY (c_tool_name, remote_track_name, class_name),
        FOREIGN KEY (class_name) REFERENCES data_acquisition (class_name) ON DELETE CASCADE,
        FOREIGN KEY (file_to_convert) REFERENCES downloader_argument (file_to_download) ON DELETE CASCADE,
        FOREIGN KEY (c_directory_input) REFERENCES downloader_argument (d_directory_output) ON DELETE CASCADE
      )")

      if(overriding.to_i == 1) # Does not allow overriding
        if("#{className}" == "Comparative Genomics")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_chimpchainlff.rb','Alignment:Chain','#{className}','Alignment', 'Chain', '#{fileName}','#{dDirectoryOutput}','#{targetSpecies}', '#{querySpecies}', '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        elsif("#{className}" == "End Pairs")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_fosmidlff.rb','Fosmid:EndPairs','#{className}','Fosmid', 'EndPairs', '#{fileName}','#{dDirectoryOutput}', NULL, NULL, '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        end
      elsif(overriding.to_i == 2) # Allow type only
        if("#{className}" == "Comparative Genomics")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_chimpchainlff.rb','#{user_input[0]}:Chain','#{className}','#{user_input[0]}', 'Chain', '#{fileName}','#{dDirectoryOutput}','#{targetSpecies}', '#{querySpecies}', '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        elsif("#{className}" == "End Pairs")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_fosmidlff.rb','#{user_input[0]}:EndPairs','#{className}','#{user_input[0]}', 'EndPairs', '#{fileName}','#{dDirectoryOutput}', NULL, NULL, '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        end
      elsif(overriding.to_i == 3) # Allow subtype only
        if("#{className}" == "Comparative Genomics")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_chimpchainlff.rb','Alignment:#{user_input[1]}','#{className}','Alignment', '#{user_input[1]}', '#{fileName}','#{dDirectoryOutput}','#{targetSpecies}', '#{querySpecies}', '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        elsif("#{className}" == "End Pairs")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_fosmidlff.rb','Fosmid:#{user_input[1]}','#{className}','Fosmid', '#{user_input[1]}', '#{fileName}','#{dDirectoryOutput}', NULL, NULL, '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        end
      elsif(overriding.to_i == 4) # Allow both
        if("#{className}" == "Comparative Genomics")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_chimpchainlff.rb','#{user_input[0]}:#{user_input[1]}','#{className}','#{user_input[0]}', '#{user_input[1]}', '#{fileName}','#{dDirectoryOutput}','#{targetSpecies}', '#{querySpecies}', '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        elsif("#{className}" == "End Pairs")
          converter_rows = dbh.do("insert into converter_argument(c_tool_name,remote_track_name,class_name,type,sub_type,file_to_convert,c_directory_input,t_species,q_species,file_to_output,c_directory_output) 
            values 
              ('BRL_UCSC_fosmidlff.rb','#{user_input[0]}:#{user_input[1]}','#{className}','#{user_input[0]}', '#{user_input[1]}', '#{fileName}','#{dDirectoryOutput}', NULL, NULL, '#{convertName}','#{cDirectoryOutput}')")
          puts "Number of rows inserted: #{converter_rows}"
        end
      end

      sth = dbh.execute("
        SELECT converter_argument.c_tool_name, converter_argument.file_to_convert, converter_argument.remote_track_name, converter_argument.class_name, converter_argument.c_directory_input, converter_argument.t_species, converter_argument.q_species, converter_argument.file_to_output, converter_argument.c_directory_output
        FROM converter_argument, downloader_argument
        WHERE downloader_argument.file_to_download = converter_argument.file_to_convert
        AND downloader_argument.d_directory_output = converter_argument.c_directory_input")
      sth.fetch do |row| 
        # converter start working...
        if("#{className}" == "Comparative Genomics")
          system("ruby #{row[0]} -r #{row[1]} -t #{row[2]} -l '#{row[3]}' -i #{row[4]} -s #{row[5]} -q #{row[6]} -f #{row[7]} -d #{row[8]}")
        elsif("#{className}" == "End Pairs")
          system("ruby #{row[0]} -r #{row[1]} -t #{row[2]} -l '#{row[3]}' -i #{row[4]} -f #{row[7]} -d #{row[8]}")
        end
      end
      sth.finish

      puts "==== Operation for Genboree uploads files =================="
      sth = dbh.execute("
        SELECT converter_argument.file_to_output, converter_argument.c_directory_output
        FROM converter_argument, downloader_argument, data_acquisition
        WHERE downloader_argument.file_to_download = converter_argument.file_to_convert
        AND converter_argument.class_name = data_acquisition.class_name
        AND downloader_argument.assembly = data_acquisition.db_name 
        AND data_acquisition.db_name = '#{assembly}'
        AND downloader_argument.d_directory_output = converter_argument.c_directory_input")
      puts "The file to be uploaded into Genboree is: "
      sth.fetch do |row| 
        puts "#{row[1]}/#{row[0]}"
      end
      sth.finish

      #clean up the downloaded and converted directories/files
    #  system("rm -r #{dDirectoryOutput}")
    #  system("rm -r #{cDirectoryOutput}")

    rescue DBI::DatabaseError => e
      puts "An error occurred"
      puts "Error code: #{e.err}"
      puts "Error message: #{e.errstr}"
      puts "Error SQLSTATE: #{e.state}"
    ensure
      # disconnect from server
      dbh.disconnect if dbh
    end
  end
end

# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "#{Time.now} BEGIN IMPORT (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
begin
  optsHash = processArguments()
  importer = MyImporter.new(optsHash)
  importer.import(optsHash)
  $stderr.puts "#{Time.now} DONE IMPORT"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end


