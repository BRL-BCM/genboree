#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/apiCaller'
# ARJ: not used and will require a valid and readable GENB_CONFIG file
# be present in order to use (which can be done, but nice if don't have to).
# - if used, will need to run with proper GENB_CONFIG set up.
# require 'brl/genboree/rest/helpers/databaseApiUriHelper'

include BRL::Genboree::REST


class UploadFile

  ##Intitialization of data
  def initialize(optsHash)
   
    @file         = optsHash["--file"]
    @db           = optsHash["--db"]
    @grp          = optsHash["--grp"]
    @path         = optsHash["--path"]
    if(@path) # then ensure has right form (no leading /)
      @path =~ /^\/?(.+)$/
      @path = $1
    end
    @dbrc         = optsHash["--dbrc"]
    dbrc          = BRL::DB::DBRC.new(nil, @dbrc)
    @host         = dbrc.host
    @pass         = dbrc.password
    @user         = dbrc.user
  end
  
 
 
 ##Upload specified file to specifed database in geboree
  def uploadUsingAPI(fileName, db, grp)
    infile   = File.open(fileName)
    
    # Build API rsrcPath:
    path = "/REST/v1/grp/#{CGI.escape(grp)}/db/#{CGI.escape(db)}/file"
    path += "/#{CGI.escape(@path)}" if(@path)
    path += "/#{CGI.escape(File.basename(fileName))}/data"
    @apicaller.setRsrcPath(path)
    
    @apicaller.put(infile)
    if @apicaller.succeeded?
      $stdout.puts "Successfully uploaded #{fileName} "
    else
      $stderr.puts @apicaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{@apicaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
      @exitCode = @apicaller.apiStatusObj['statusCode']
      raise "#{@apicaller.apiStatusObj['msg']}"
    end
  end
  
 ##Upload histogram 
 def uploadData()
      @apicaller = ApiCaller.new(@host,"",@user,@pass)
      uploadUsingAPI(@file, @db,  @grp)
 end
 
  def UploadFile.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

    PROGRAM DESCRIPTION:
    uploads files to genboree 
    COMMAND LINE ARGUMENTS:
    --file         | -f => Input file to upload
    --db           | -d => Database
    --grp          | -g => Group
    --dbrc         | -D => Dbrc key to pull host, user name, and password information
    --path         | -p => [Optional] subdir path within DB's files area in which to place file
    --help         | -h => [Optional flag]. Print help info and exit.

    usage:

    uploadFile.rb -f exampleBAM.bam -d 'smallRNA input hawkins' -g arpit_group -D someAPi
    ";
    exit;
  end #

  # Process Arguments form the command line input
  def UploadFile.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--file'   ,'-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--db'     ,'-d', GetoptLong::REQUIRED_ARGUMENT],
                  ['--grp'    ,'-g', GetoptLong::REQUIRED_ARGUMENT],
                  ['--dbrc'   ,'-D', GetoptLong::REQUIRED_ARGUMENT],
                  ['--path'   ,'-p', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--help'   ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    UploadFile.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    UploadFile.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = UploadFile.processArguments()
UploadFile1 = UploadFile.new(optsHash)
UploadFile1.uploadData()
rescue => err
    $stderr.puts err.backtrace.join("\n")
end
