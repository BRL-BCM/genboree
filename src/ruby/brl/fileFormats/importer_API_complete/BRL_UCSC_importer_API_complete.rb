#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# ##############################################################################
# Simple: Data importer tool using REST API

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'dbi'

# FOR THE PURPOSE OF HANDLING USER'S LOGIN CONFIGURATION FILE 
require 'brl/genboree/genbrc'

require 'stringio'
require 'net/http' ; require 'open-uri' ; require 'rest-open-uri'
require 'json' ; require 'sha1' ; require 'cgi'

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
                ['--bcmHost', '-s', GetoptLong::REQUIRED_ARGUMENT],
                ['--grp', '-g', GetoptLong::REQUIRED_ARGUMENT],
                ['--inputDb', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--assembly', '-a', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--emailAddress', '-e', GetoptLong::REQUIRED_ARGUMENT],
                ['--deleteTrackBeforeUploading', '-c', GetoptLong::OPTIONAL_ARGUMENT],
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
    if(!optsHash.key?('--bcmHost') or !optsHash.key?('--grp') or !optsHash.key?('--inputDb') or !optsHash.key?('--assembly') or !optsHash.key?('--trackName') or !optsHash.key?('--emailAddress'))
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
     Finally upload the converted file into Genboree using REST-based API. 

  COMMAND LINE ARGUMENTS:
     --bcmHost              	  | -s    => genboree hostname
     --grp             		  | -g    => user group name
     --inputDb          	  | -d    => user database name
     --assembly              	  | -a    => The template the user's database is based on
     --trackName             	  | -t    => Track name for of the remote data to acquire
                                       (type:subtype)
     --emailAddress          	  | -e    => Email address providing to downloader
     --deleteTrackBeforeUploading | -c    => [optional flag] Cause the track to be deleted prior to upload)
     --help                  	  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  1)
  ruby BRL_UCSC_importer_API_complete.rb -s bcmHost -g grp -d inputDb -a assembly -t trackName -e emailAddress -c deleteTrackBeforeUploading
"
end

class MyImporter
  def initialize(inputsHash)
  end 

  def mysql(opts, stream)
    IO.popen("mysql #{opts}", 'w') {|io| io.puts stream}
  end

  def import(inputsHash) 
    # Set some key vars to use in making resource URI
    # usr = 'yxb4544'
    # pwd = 'xiaorong75'

    # calling the class BRL::Genboree::Genbrc to verify login configuration file ownership and access priviledge
    genbrc = BRL::Genboree::Genbrc.new()
    usr = genbrc['proline.brl.bcm.tmc.edu']['login']
    pwd = genbrc['proline.brl.bcm.tmc.edu']['password']

    bcmHost = inputsHash['--bcmHost'].strip
    grp = inputsHash['--grp'].strip
    inputDb = inputsHash['--inputDb'].strip
    assembly = inputsHash['--assembly'].strip
    trackName = inputsHash['--trackName'].strip
    emailAddress = inputsHash['--emailAddress'].strip

    #----------------------FUNCTION 0: Put project description through resource path
    prj = 'UCSC Importer'
    #description = "Download UCSC tracks and convert them into Genboree LFF format and load the result file into Genboree using REST API"
    description ='{
      "text" : "Purpose: Download UCSC tracks and convert them into Genboree LFF format and load the result file into Genboree using REST API",             
      "refs" :                         
      {
        "AnnoList_LFF" : "proline.brl.bcm.tmc.edu"
      }
    }
    '
    group_project_rsrcURI =
      "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
      "/prj/#{CGI.escape(prj)}/description?"
    group_project_usrpw = SHA1.hexdigest("#{usr}#{pwd}")
    group_project_gbToken = SHA1.hexdigest(
      group_project_rsrcURI + group_project_usrpw + (group_project_gbTime=Time.now.to_i.to_s))

    group_project_fullURI = "#{group_project_rsrcURI}gbLogin=#{usr}" +
              "&gbTime=#{group_project_gbTime}&gbToken=#{group_project_gbToken}"
    begin
    group_project_repIO = err = nil
    group_project_repIO = open(group_project_fullURI, :method => :put, :body=>description)
    rescue => err
    end
    if(group_project_repIO)
      group_project_successObj = JSON.parse(group_project_repIO.read) 
      #puts group_project_successObj['data']['text']
    else
      group_project_failObj = JSON.parse(err.io.read)
      $stderr.puts group_project_failObj['status']['statusCode']
      $stderr.puts group_project_failObj['status']['msg']
      exit(FATAL)
    end


    #-----------------------End of FUNCTION 0

    #----------------------FUNCTION 1: check whether the user who tries to touch resources belongs to the given group
    group_user_rsrcURI =
      "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
      "/usrs?"
    group_user_usrpw = SHA1.hexdigest("#{usr}#{pwd}")
    group_user_gbToken = SHA1.hexdigest(
      group_user_rsrcURI + group_user_usrpw + (group_user_gbTime=Time.now.to_i.to_s))

    group_user_fullURI = "#{group_user_rsrcURI}gbLogin=#{usr}" +
              "&gbTime=#{group_user_gbTime}&gbToken=#{group_user_gbToken}"
    begin
    group_user_repIO = err = nil
    group_user_repIO = open(group_user_fullURI, :method => :get)
    rescue => err
    end
    puts "Check user login - #{usr}, please wait..."
    if(group_user_repIO)
      group_user_successObj = JSON.parse(group_user_repIO.read) 
      group_user_successObj['data'].each { |xx| 
        if(xx['text'] == "#{usr}")
          $stderr.puts group_user_successObj['status']['statusCode']
          $stderr.puts group_user_successObj['status']['msg']
          puts "User login- #{usr} is found in this group, now check the existence of input db for this group on server side..."
        end
      }
    else
      group_user_failObj = JSON.parse(err.io.read)
      $stderr.puts group_user_failObj['status']['statusCode']
      $stderr.puts group_user_failObj['status']['msg']
      exit(FATAL)
    end
    #-----------------------End of FUNCTION 1

    #------------------------FUNCTION 2: check whether the input database exists in the given group
    group_database_rsrcURI =
      "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
      "/db/#{CGI.escape(inputDb)}?"
    group_database_usrpw = SHA1.hexdigest("#{usr}#{pwd}")
    group_database_gbToken = SHA1.hexdigest(
      group_database_rsrcURI + group_database_usrpw + (group_database_gbTime=Time.now.to_i.to_s))

    group_database_fullURI = "#{group_database_rsrcURI}gbLogin=#{usr}" +
              "&gbTime=#{group_database_gbTime}&gbToken=#{group_database_gbToken}"
    begin
    group_database_repIO = err = nil
    group_database_repIO = open(group_database_fullURI, :method => :get)
    rescue => err
    end
    puts "Check server database - #{inputDb}, please wait..."
    if(group_database_repIO)
      group_database_successObj = JSON.parse(group_database_repIO.read)
      $stderr.puts group_database_successObj['status']['statusCode']
      $stderr.puts group_database_successObj['status']['msg']
      if(group_database_successObj['data']['name'] == "#{inputDb}")
        puts "Database- #{inputDb} is found in this group, now check the existence of files to be operated on server side..."
      end
    else
      group_database_failObj = JSON.parse(err.io.read)
      $stderr.puts group_database_failObj['status']['statusCode']
      $stderr.puts group_database_failObj['status']['msg']
      exit(FATAL)
    end
    #----------------------End of FUNCTION 2

    #----------------------FUNCTION 3: check track availablity---------------------
    group_database_track_rsrcURI =
      "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
      "/db/#{CGI.escape(inputDb)}/trk/#{CGI.escape(trackName)}?"
    group_database_track_usrpw = SHA1.hexdigest("#{usr}#{pwd}")
    group_database_track_gbToken = SHA1.hexdigest(
      group_database_track_rsrcURI + group_database_track_usrpw + (group_database_track_gbTime=Time.now.to_i.to_s))

    group_database_track_fullURI = "#{group_database_track_rsrcURI}gbLogin=#{usr}" +
              "&gbTime=#{group_database_track_gbTime}&gbToken=#{group_database_track_gbToken}"
    begin
    group_database_track_repIO = err = nil
    group_database_track_repIO = open(group_database_track_fullURI, :method => :get)
    rescue => err
    end
    puts "Check track- #{trackName} on server side, please wait..."
    if(group_database_track_repIO)
      group_database_track_successObj = JSON.parse(group_database_track_repIO.read)
      $stderr.puts group_database_track_successObj['status']['statusCode']
      $stderr.puts group_database_track_successObj['status']['msg']
      if(group_database_track_successObj['data']['name'] == "#{trackName}")
        puts "Track- #{trackName} is found on server side, we will delete the old one first, then upload..."
        if(inputsHash.key?('--deleteTrackBeforeUploading'))
          $stderr.puts "Track deletion not implemented yet! The server will keep adding the track/annotations..."
          ### this part will be updated when DELETE functionality is available later
        end
      end
    else
      group_database_track_failObj = JSON.parse(err.io.read)
      $stderr.puts group_database_track_failObj['status']['statusCode']
      $stderr.puts group_database_track_failObj['status']['msg']
      puts "You can upload your track now if you meet the following compatibility:"
    end
    #----------------------End of FUNCTION 3



    #-----------------------

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
	database_upload VARCHAR (80) NOT NULL,
	url_label VARCHAR (100) NOT NULL,
	url VARCHAR (300) NOT NULL,
	ucsc_description VARCHAR (3000) NOT NULL,
        PRIMARY KEY (db_name, remote_track_name, class_name)         
      )")

      # prepare statement for use within insert loop
      sth = dbh.prepare("INSERT INTO data_acquisition_complete(db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output, database_upload, url_label, url, ucsc_description) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
      # read each line from file, split into values, and insert into database
      File.open("data_acquisition_complete_data.txt", "r") do |f|
        f.each_line do |line|
          db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output, database_upload, url_label, url, ucsc_description = line.chomp.split("\t")
          sth.execute(db_name, remote_track_name, class_name, host, file_to_download, d_directory_output, converter_name, file_to_output, c_directory_output, database_upload, url_label, url, ucsc_description)
        end
      end

      puts "A list of remote data (tracks) that are compatible with user selected assembly - #{assembly} and uploaded databases - #{inputDb} and the tracks available for: (i) dynamic download and (ii) conversion to lff via a converter and (iii) upload to geneboree through REST API:"
      sth = dbh.execute("SELECT data_acquisition_complete.remote_track_name, data_acquisition_complete.database_upload FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}' AND data_acquisition_complete.database_upload = '#{inputDb}'")
      sth.fetch do |row| 
        puts "#{assembly} \t" + row[1] + "\t" + row[0]
      end
      sth.finish

      row_counter = 0
      puts "\nGiven input of a genome assembly version and a list of one or more track names, the program actually goes and downloads the correct file(s) for the track(s) and after downloading them, converts them automatically to LFF. Finally, upload the converted file into Genboree using REST-based API"

      sth = dbh.execute("SELECT data_acquisition_complete.remote_track_name, data_acquisition_complete.class_name, data_acquisition_complete.host, data_acquisition_complete.file_to_download, data_acquisition_complete.d_directory_output, data_acquisition_complete.converter_name, data_acquisition_complete.file_to_output, data_acquisition_complete.c_directory_output FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}' AND data_acquisition_complete.remote_track_name = '#{trackName}'")
      sth.fetch do |row| 
        if(("#{assembly}" == "hg18" && "#{row[0]}" == "Fosmid:EndPairs") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Iafrate2") ||("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Locke") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Redon") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sebat2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Tuzun") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Tuzun") || ("#{assembly}" == "hg18" && "#{row[0]}" == "CNP:Sharp2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Conrad2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Hinds2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "DEL:Mccarroll") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Variants:TCAG.v3") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:Genes") || ("#{assembly}" == "hg18" && "#{row[0]}" == "BAC:EndPairs") || ("#{assembly}" == "hg18" && "#{row[0]}" == "AFFY:GNF1H") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:HuEx 1.0") || ("#{assembly}" == "hg18" && "#{row[0]}" == "AFFY:U95") || ("#{assembly}" == "hg18" && "#{row[0]}" == "GNF:Atlas 2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:U133") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Affy:U133Plus2") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:EST") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:mRNA") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:Spliced EST") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:xenoEst") || ("#{assembly}" == "hg18" && "#{row[0]}" == "UCSC:UniGene") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:Genes") || ("#{assembly}" == "mm9" && "#{row[0]}" == "BAC:EndPairs") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:EST") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:mRNA") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:Spliced EST") || ("#{assembly}" == "mm9" && "#{row[0]}" == "UCSC:xenomRNA") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:GNF1M") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:MOE430") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74A") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74B") || ("#{assembly}" == "mm9" && "#{row[0]}" == "AFFY:U74C") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Special Expression:Sex Gene") || ("#{assembly}" == "mm8" && "#{row[0]}" == "AFFY:EXON") || ("#{assembly}" == "mm7" && "#{row[0]}" == "MicroRNA:PicTar") || ("#{assembly}" == "mm7" && "#{row[0]}" == "TAG:CAGE TC"))
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
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o hapmapLdPhCeu.txt.gz -p hapmapLdPhChbJpt.txt.gz -q hapmapLdPhYri.txt.gz")
        elsif("#{assembly}" == "hg18" && "#{row[0]}" == "DIS:CCC")
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o cccTrendPvalBd.txt.gz -p cccTrendPvalCad.txt.gz -q cccTrendPvalCd.txt.gz -u cccTrendPvalHt.txt.gz -v cccTrendPvalRa.txt.gz -w cccTrendPvalT1d.txt.gz -x cccTrendPvalT2d.txt.gz")
        elsif(("#{assembly}" == "hg18" && "#{row[0]}" == "DIS:GAD") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:Microsatellites") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:Simple Repeats") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:SNPs (128)") || ("#{assembly}" == "hg18" && "#{row[0]}" == "Polymorphisms:Repeat Masker") || ("#{assembly}" == "hg17" && "#{row[0]}" == "Polymorphisms:SNPs (125)") || ("#{assembly}" == "hg16" && "#{row[0]}" == "Polymorphisms:SNPs") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:SNPs (128)") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Microsatellites") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Simple Repeats") || ("#{assembly}" == "mm9" && "#{row[0]}" == "Polymorphisms:Repeat Masker") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Mapping:MGI QTL") || ("#{assembly}" == "mm5" && "#{row[0]}" == "Mapping:MGI QTL") || ("#{assembly}" == "mm8" && "#{row[0]}" == "Mapping:WSSD Coverage") || ("#{assembly}" == "mm6" && "#{row[0]}" == "Alignment:ChainSelf"))
          ###call downloader for each track
          system("ruby BRL_UCSC_universal_downloader.rb -o #{row[2]} -a #{assembly} -f #{row[3]} -d #{row[4]} -e #{emailAddress}")
          ###call converter for each track
          puts "Converting starts...\n"
          system("ruby #{row[5]} -t #{row[0]} -l '#{row[1]}' -i #{row[4]} -f #{row[6]} -d #{row[7]} -o #{row[3]}")
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
        system("cp #{row[7]}/#{row[6]} converted_file.txt")    
      end
      sth.finish

      if(row_counter == 0)
        puts "\nSorry,track #{trackName} is not a valid track name, so downloading and converting did not occur. Please use the track name available in database for correct input!!!\n\n"
      #===========================upload into proline using API
      else
        sio = StringIO.new
        fh = File.open("converted_file.txt")
        $stderr.puts "File size: #{File.size(fh)} bytes"
        $stderr.puts Time.now.to_s
        fh.each_line { |line|
          sio.print(line)
          if(sio.size > 30_000_000)
            $stderr.puts "#{Time.now.strftime('%H:%M:%S')} Got 30MB chunk of LFF lines (chunk is #{sio.size} bytes). Current line #: #{fh.lineno}"
            rsrcURI =
              "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
              "/db/#{CGI.escape(inputDb)}/annos?"
            # Must computer AUTHENTICATION parameter values to add to
            # the end of our resource URI:
            #
            # 1) Compute digested user+pass
            usrpw = SHA1.hexdigest("#{usr}#{pwd}")
            # 2) Compute gbToken, saving the current time as a side effect
            gbToken = SHA1.hexdigest(
              rsrcURI + usrpw + (gbTime=Time.now.to_i.to_s))
            # Now construct the final URI to actually use in request:
            # Make fullURI (rsrcURI + auth params)
            fullURI = "#{rsrcURI}gbLogin=#{usr}" +
                    "&gbTime=#{gbTime}&gbToken=#{gbToken}"
            begin
            repIO = err = nil
            sio.seek(0)
            bigLFFString = sio.read()
            repIO = open(fullURI, :method=>:put, :body=>bigLFFString)
            rescue => err
            end
            successObj = JSON.parse(repIO.read) if(repIO) 
            failObj = JSON.parse(err.io.read) unless(repIO)
            if(repIO.nil?)
              $stderr.puts failObj['status']['statusCode']
              $stderr.puts failObj['status']['msg']
            end
            sio.truncate(0)
            sio.rewind
          elsif(fh.eof?)
            $stderr.puts "#{Time.now.strftime('%H:%M:%S')} Process LAST chunk of LFF lines (#{sio.size} bytes)"
            rsrcURI =
              "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
              "/db/#{CGI.escape(inputDb)}/annos?"
            # Must computer AUTHENTICATION parameter values to add to
            # the end of our resource URI:
            #
            # 1) Compute digested user+pass
            usrpw = SHA1.hexdigest("#{usr}#{pwd}")
            # 2) Compute gbToken, saving the current time as a side effect
            gbToken = SHA1.hexdigest(
              rsrcURI + usrpw + (gbTime=Time.now.to_i.to_s))
            # Now construct the final URI to actually use in request:
            # Make fullURI (rsrcURI + auth params)
            fullURI = "#{rsrcURI}gbLogin=#{usr}" +
                    "&gbTime=#{gbTime}&gbToken=#{gbToken}"
            begin
            repIO = err = nil
            sio.seek(0)
            bigLFFString = sio.read()
            repIO = open(fullURI, :method=>:put, :body=>bigLFFString)
            rescue => err
            end
            successObj = JSON.parse(repIO.read) if(repIO) 
            failObj = JSON.parse(err.io.read) unless(repIO)
            if(repIO.nil?)
              $stderr.puts failObj['status']['statusCode']
              $stderr.puts failObj['status']['msg']
            end
            sio.truncate(0)
            sio.rewind
          end
        }
      end 
      #insert URL related information
      sth = dbh.execute("SELECT data_acquisition_complete.url_label, data_acquisition_complete.url, data_acquisition_complete.ucsc_description FROM data_acquisition_complete WHERE data_acquisition_complete.db_name = '#{assembly}' AND data_acquisition_complete.remote_track_name = '#{trackName}'")
      sth.fetch do |row| 
        rsrcURI =
          "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
          "/db/#{CGI.escape(inputDb)}/trk/#{CGI.escape(trackName)}/urlLabel?"
        usrpw = SHA1.hexdigest("#{usr}#{pwd}")
        gbToken = SHA1.hexdigest(
          rsrcURI + usrpw + (gbTime=Time.now.to_i.to_s))
        fullURI = "#{rsrcURI}gbLogin=#{usr}" +
                "&gbTime=#{gbTime}&gbToken=#{gbToken}"
        begin
        repIO = err = nil
        bigLFFString = "#{row[0]}"
        repIO = open(fullURI, :method=>:put, :body=>bigLFFString)
        rescue => err
        end
        successObj = JSON.parse(repIO.read) if(repIO) 
        failObj = JSON.parse(err.io.read) unless(repIO)
        if(repIO.nil?)
          $stderr.puts failObj['status']['statusCode']
          $stderr.puts failObj['status']['msg']
        end

        rsrcURI =
          "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
          "/db/#{CGI.escape(inputDb)}/trk/#{CGI.escape(trackName)}/url?"
        usrpw = SHA1.hexdigest("#{usr}#{pwd}")
        gbToken = SHA1.hexdigest(
          rsrcURI + usrpw + (gbTime=Time.now.to_i.to_s))
        fullURI = "#{rsrcURI}gbLogin=#{usr}" +
                "&gbTime=#{gbTime}&gbToken=#{gbToken}"
        begin
        repIO = err = nil
        bigLFFString = "#{row[1]}"
        repIO = open(fullURI, :method=>:put, :body=>bigLFFString)
        rescue => err
        end
        successObj = JSON.parse(repIO.read) if(repIO) 
        failObj = JSON.parse(err.io.read) unless(repIO)
        if(repIO.nil?)
          $stderr.puts failObj['status']['statusCode']
          $stderr.puts failObj['status']['msg']
        end

        rsrcURI =
          "http://#{bcmHost}/REST/v1/grp/#{CGI.escape(grp)}" +
          "/db/#{CGI.escape(inputDb)}/trk/#{CGI.escape(trackName)}/description?"
        usrpw = SHA1.hexdigest("#{usr}#{pwd}")
        gbToken = SHA1.hexdigest(
          rsrcURI + usrpw + (gbTime=Time.now.to_i.to_s))
        fullURI = "#{rsrcURI}gbLogin=#{usr}" +
                "&gbTime=#{gbTime}&gbToken=#{gbToken}"
        begin
        repIO = err = nil
        bigLFFString = "#{row[2]}"
        repIO = open(fullURI, :method=>:put, :body=>bigLFFString)
        rescue => err
        end
        successObj = JSON.parse(repIO.read) if(repIO) 
        failObj = JSON.parse(err.io.read) unless(repIO)
        if(repIO.nil?)
          $stderr.puts failObj['status']['statusCode']
          $stderr.puts failObj['status']['msg']
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




