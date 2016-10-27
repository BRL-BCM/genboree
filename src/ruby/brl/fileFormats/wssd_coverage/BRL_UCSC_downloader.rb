#!/usr/bin/env ruby
##################### No warning!
$VERBOSE = nil

# ###################################################################################################################################
# Program: A downloader which can download the files from UCSC given info about the external host, the path, the requested file list, etc. 
# from command line parameters

# ##################################################################################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'net/ftp'
require 'timeout'

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
                ['--assemblyName', '-a', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileName', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--dDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
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
  # If there is NOT any required argument file missing, then return an empty array; otherwise, report error
  elsif(optsMissing.length != 0)
    usage("Error:the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Download requested source file(s) given a particular assembly version of a species available from UCSC.

  COMMAND LINE ARGUMENTS:
    --hostFile              | -o    => UCSC host address to contact
    --assemblyName          | -a    => Assembly version to download
    --fileName              | -f    => File name to download
    --dDirectoryOutput      | -d    => The directory where downloaded files should go
    --emailAddress          | -e    => Email address to provide
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE: ruby BRL_UCSC_downloader.rb -o host -a assembly_for_a_species -f fileList -d directoryOutputFileGo -e email_address
  i.e. 
       ruby BRL_UCSC_downloader.rb -o hgdownload.cse.ucsc.edu -a mm8 -f wssdCoverage.txt.gz -d /users/ybai/work/Mouse_Project3//WSSD_Coverage -e ybai@ws59.hgsc.bcm.tmc.edu

"
end

class MyDownloader
  def initialize(inputsHash)
  end
  def download(inputsHash)
    hostFile = inputsHash['--hostFile'].strip
    assemblyName = inputsHash['--assemblyName'].strip
    fileName = inputsHash['--fileName'].strip
    dDirectoryOutput = inputsHash['--dDirectoryOutput'].strip  
    emailAddress = inputsHash['--emailAddress'].strip
    # start to connect to host  
    begin
      puts "Checking connections.."
      timeout(8000){
        ftp = Net::FTP.open(hostFile) do |ftp|
          ftp.passive = true
          puts "Checking user name and password..."
          begin
            ftp.login('anonymous', emailAddress)
          rescue Net::FTPError
            $stderr.puts "Could authentificate... Details: " + $!
            exit(FAILED)
          else
            puts "Authentification is ok..."
          end
          puts "Checking availbility of given assembly on host side...."
          # --------------------------------------------------------
          # If the assembly is available, start downloading; otherwise, output the message and no downlaoding happens... 
          #---------------------------------------------------------
          begin
            current_assembly = assemblyName
            ftp.chdir("goldenPath/#{current_assembly}/database")
            Dir.chdir("#{dDirectoryOutput}")
            puts "Starting downloading...."
            files = ftp.nlst(fileName) 
            files.each {|file| ftp.getbinaryfile(file, file)}
            puts "Downloading completes! Please check your directory for files, thank you!"
          rescue Net::FTPError => err
            $stderr.puts "No downloading occurrs.... Details: #{err.message}" 
            exit(FAILED)
          end
	end
      }
    rescue Timeout::Error
      $stderr.puts "Timeout while connecting to server.."
      exit(FAILED)
    end 
  end 
end

# ##############################################################################
# MAIN
# ##############################################################################
begin
  $stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
  optsHash = processArguments()
  downloader = MyDownloader.new(optsHash)
  downloader.download(optsHash)
  $stderr.puts "#{Time.now} DONE"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end


