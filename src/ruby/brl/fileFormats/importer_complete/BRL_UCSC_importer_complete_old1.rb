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
                ['--assembly', '-a', GetoptLong::REQUIRED_ARGUMENT],
                ['--emailAddress', '-e', GetoptLong::REQUIRED_ARGUMENT],
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
    if(!optsHash.key?('--assembly') or !optsHash.key?('--emailAddress'))
      usage("Error: the REQUIRED args are missing!")
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
     Downloads a table from UCSC and converts it to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
     --assembly              | -a    => The template the user's database is based on
     --emailAddress          | -e    => Email address providing to downloader
     --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1)
  ruby BRL_UCSC_importer_complete.rb -a assembly -e emailAddress
"
end

class MyImporter
  def initialize(inputsHash)
  end 

  def mysql(opts, stream)
    IO.popen("mysql #{opts}", 'w') {|io| io.puts stream}
  end

  def import(inputsHash) 
    assembly = inputsHash['--assembly'].strip
    emailAddress = inputsHash['--emailAddress'].strip

    self.mysql '-u root', <<-end
      drop database if exists importer_db_complete;
      create database importer_db_complete;
      grant all on importer_db_complete.* to #{`id -un`.strip}@localhost;
    end

    begin
      # connect to the MySQL server
      dbh = DBI.connect("DBI:Mysql:importer_db_complete:localhost", "root")

      row = dbh.select_one("SELECT VERSION()")
      puts "Server version: " + row[0]

      puts "==== Operation for table data_acquisition =================="
      ## Operation for table "data_acquisition_complete"
      dbh.do("DROP TABLE if exists data_acquisition_complete")

      dbh.do("CREATE TABLE data_acquisition_complete(
        db_name VARCHAR(30) NOT NULL, 
        remote_track_name VARCHAR (41) NOT NULL, 
        class_name VARCHAR(40) NOT NULL, 
	host VARCHAR (60) NOT NULL, 
	file_to_download VARCHAR (60) NOT NULL,
	d_directory_output VARCHAR (100) NOT NULL,
	converter_name VARCHAR (60) NOT NULL,
	file_to_output VARCHAR (60) NOT NULL,
	c_directory_output VARCHAR (100) NOT NULL,
        PRIMARY KEY (db_name, remote_track_name, class_name)         
      )")

      # prepare statement for use within insert loop
      sth = dbh.prepare("INSERT INTO data_acquisition_complete(db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)")
      # read each line from file, split into values, and insert into database
      File.open("data_acquisition_complete_data.txt", "r") do |f|
        f.each_line do |line|
          db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output = line.chomp.split("\t")
          sth.execute(db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output)
        end
      end

      puts "A list of remote data (tracks) that are compatible with user selected database - #{assembly}:"
      sth = dbh.execute("SELECT data_acquisition_complete.remote_track_name, data_acquisition_complete.class_name, data_acquisition_complete.host, data_acquisition_complete.file_to_download, data_acquisition_complete.d_directory_output, data_acquisition_complete.converter_name, data_acquisition_complete.file_to_output, data_acquisition_complete.c_directory_output FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}'")
      sth.fetch do |row| 
        puts "\n#{assembly} \t" + row[0]
        ###call downloader for each track
        system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
        ###call converter for each track
        puts "Converting starts...\n"
        if("#{assembly}" == "hg18" && "#{row[0]}" == "Fosmid:EndPairs")
          system("ruby #{row[5]} -r #{row[3]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]}")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "Alignment:Chain")
          system("ruby #{row[5]} -r #{row[3]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -s Human -q Chimp -f #{row[6]} -d #{row[7]}")
        #elsif

       end

      end
      sth.finish
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


