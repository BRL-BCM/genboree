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
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
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
    if(!optsHash.key?('--assembly') or !optsHash.key?('--trackName') or !optsHash.key?('--emailAddress'))
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
     --trackName             | -t    => Track name for of the remote data to acquire
                                       (type:subtype)
     --emailAddress          | -e    => Email address providing to downloader
     --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1)
  ruby BRL_UCSC_importer_complete.rb -a assembly -t trackName -e emailAddress
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
    trackName = inputsHash['--trackName'].strip
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

      puts "\n==== Operation for table data_acquisition_complete =================="
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

      puts "A list of remote data (tracks) that are compatible with user selected database - #{assembly} and the tracks available for: (i) dynamic download and (ii) conversion to lff via a converter:"
      sth = dbh.execute("SELECT data_acquisition_complete.remote_track_name FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}'")
      sth.fetch do |row| 
        puts "#{assembly} \t" + row[0]
      end
      sth.finish

      row_counter = 0
      puts "\nGiven input of a genome assembly version and a list of one or more track names, the program actually goes and downloads the correct file(s) for the track(s) and after downloading them, converts them automatically to LFF."
      sth = dbh.execute("SELECT data_acquisition_complete.remote_track_name, data_acquisition_complete.class_name, data_acquisition_complete.host, data_acquisition_complete.file_to_download, data_acquisition_complete.d_directory_output, data_acquisition_complete.converter_name, data_acquisition_complete.file_to_output, data_acquisition_complete.c_directory_output FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}' AND data_acquisition_complete.remote_track_name = '#{trackName}'")
      sth.fetch do |row| 
        if(("#{assembly}" == "hg18" && "#{row[0]}" == "Segmental:Duplications") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Fosmid:EndPairs") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Iafrate2") ||("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Locke") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Redon") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sebat2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Tuzun") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Tuzun") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Conrad2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Hinds2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Mccarroll") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Variants:TCAG.v7") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Indels:TCAG.v7") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:Genes") || ("#{assembly}" == "hg18" && "#{row[0]}" == "BAC:EndPairs") || ("#{assembly}" == "hg18" && "#{row[0]}" == "AFFY:GNF1H") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:HuEx 1.0") || ("#{assembly}" == "hg18" && "#{row[0]}" == "AFFY:U95") || ("#{assembly}" == "hg18" && "#{row[0]}" == "GNF:Atlas 2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:U133") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:U133Plus2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:EST") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:mRNA") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:Spliced EST") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:xenoEst") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:UniGene") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:Genes") || ("#{assembly}" == "mm9" && "#{row[0]}" == "BAC:EndPairs") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:EST") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:mRNA") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:Spliced EST") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:xenomRNA") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:GNF1M") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:MOE430") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74A") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74B") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74C") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Special Expression:Sex Gene") || ("#{assembly}" == "mm8" && "#{row[0]}" == "AFFY:EXON") || ("#{assembly}" == "mm7" && "#{row[0]}" == "MicroRNA:PicTar") || ("#{assembly}" == "mm7" && "#{row[0]}" == "TAG:CAGE TC"))
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -r #{row[3]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]}")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "Alignment:Chain")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -r #{row[3]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -s Human -q Chimp -f #{row[6]} -d #{row[7]}")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:HapMap SNPs")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o hapmapSnpsCEU.txt.gz -p hapmapSnpsCHB.txt.gz -q hapmapSnpsJPT.txt.gz -u hapmapSnpsYRI.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:HapMap LD")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t '#{row[0]}' -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o hapmapLdPhCeu.txt.gz -p hapmapLdPhChbJpt.txt.gz -q hapmapLdPhYri.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "DIS:CCC")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o cccTrendPvalBd.txt.gz -p cccTrendPvalCad.txt.gz -q cccTrendPvalCd.txt.gz -u cccTrendPvalHt.txt.gz -v cccTrendPvalRa.txt.gz -w cccTrendPvalT1d.txt.gz -x cccTrendPvalT2d.txt.gz")
        elsif(("#{assembly}" == "hg18" && "#{row[0]}" == "DIS:GAD") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Micro:Satellites") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Simple:Repeats") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:SNPs (128)") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Repeat:Masker") || ("#{assembly}" == "hg17" && "#{row[0]}" == "Polymorphisms:SNPs (125)") || ("#{assembly}" == "hg16" && "#{row[0]}" == "Polymorphisms:SNPs") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:SNPs (128)") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Microsatellites") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Simple Repeats") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Repeat Masker") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Mapping:MGI QTL") || ("#{assembly}" == "mm5" && "#{row[0]}" == "Mapping:MGI QTL") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Mapping:WSSD Coverage") || ("#{assembly}" == "mm6" && "#{row[0]}" == "Alignment:ChainSelf"))
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t '#{row[0]}' -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o #{row[3]}")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "NIMH:BIPOL")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o nimhBipolarDe.txt.gz -p nimhBipolarUs.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "RGD:MGI MOUSE QTL")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -s -1 -c 1 -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o jaxQtlAsIs.txt.gz -p jaxQtlPadded.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "RGD:RAT QTL")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o rgdRatQtl.txt.gz -p rgdRatQtlLink.txt.gz")
        elsif("#{assembly}" == "mm8" && "#{row[0]}" == "TAG:CGAP SAGE")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o cgapSage.txt.gz -p cgapSageLib.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "RGD:QTL")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o rgdQtl.txt.gz -p rgdQtlLink.txt.gz")
        elsif("#{assembly}" == "mm5" && "#{row[0]}" == "Alignment:TGI")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -r #{row[3]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -s tigrGeneIndex.txt -d #{row[7]}")
        elsif(("#{assembly}" == "hg18" && "#{row[0]}" == "RNA:Small") || ("#{assembly}" == "hg16" && "#{row[0]}" == "RNA:miRNA") || ("#{assembly}" == "hg15" && "#{row[0]}" == "RNA:RNA Genes") || ("#{assembly}" == "mm9" && "#{row[0]}" == "RNA:miRNA") || ("#{assembly}" == "mm7" && "#{row[0]}" == "RNA:miRNA") || ("#{assembly}" == "mm6" && "#{row[0]}" == "RNA:miRNA"))
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          user_input = "#{row[0]}".split(/:/)
          system("ruby #{row[5]} -r #{row[3]} -t #{user_input[0]} -s #{user_input[1]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]}")
        end
        row_counter = row_counter + 1 
      end
      sth.finish
      if(row_counter == 0)
        puts "\nSorry,track #{trackName} is not a valid track name, so downloading and converting did not occur. Please use the track name available in database for correct input!!!\n\n"
      end  
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


