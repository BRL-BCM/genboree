#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Main class for copying files from one db to another
class FileCopier

  # Constructor
  # [+optsHash+] hash with command line options
  # [+returns+] nil
  def initialize(optsHash)
    @inputFile = optsHash['--inputFile']
    @outputDB = optsHash['--outputDB']
    @dbrcKey = optsHash['--dbrcKey']
    @userId = optsHash['--userId']
    @deleteSourceFiles = optsHash['--deleteSourceFiles']
    @scratchDir = optsHash['--scratchDir']
    # Put the rest of the stuff in a begin rescue block so that we can 'handle' if anything goes wrong
    begin
      copyFiles() # Download the tracks and then upload them one by one making API calls
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
    $stderr.puts "All done"
    exit(0)
  end

  # Downloads and uploads files from source to destination
  # [+returns+] nil
  def copyFiles()
    # First make sure we have a valid key to make API calls
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    if(@dbrcKey)
      dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
      # get super user, pass and hostname
      @user = dbrc.user
      @pass = dbrc.password
    else
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(genbConfig, dbrcFile)
      @user = suDbDbrc.user
      @pass = suDbDbrc.password
    end
    inputFiles = @inputFile.split(",")
    files = []
    inputFiles.each { |file|
      files << file
    }
    filehelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    # Loop over each input URI
    # Download and upload the data and metadata for each file
    files.each { |file|
      $stderr.puts "file uri: #{file}"
      uri = URI.parse(file)
      host = uri.host
      origPath = uri.path
      path = uri.path
      path << "?gbKey=#{dbHelperObj.extractGbKey(file)}" if(dbHelperObj.extractGbKey(file))
      # First get the metadata of the file
      apiCaller = WrapperApiCaller.new(host, path, @userId)
      apiCaller.get()
      if(!apiCaller.succeeded?)
        $stderr.puts "Could not get metadata for file: #{file.inspect}:\n#{apiCaller.respBody.inspect}\nContinuing..."
      end
      resp = apiCaller.parseRespBody
      metadata = resp['data']

      # remove query string from meta data retrieval
      uri2 = URI.parse(path)
      path = uri2.path

      path << "/data?"
      path << "gbKey=#{dbHelperObj.extractGbKey(file)}" if(dbHelperObj.extractGbKey(file))
      apiCaller = WrapperApiCaller.new(host, path, @userId)
      fileName = "#{@scratchDir}/#{Time.now.to_f}.txt"
      ww = File.open(fileName, "w")
      $stderr.puts "Downloading file: #{path} from host: #{host}"
      apiCaller.get() {|chunk| ww.print chunk}
      ww.close()
      raise "Could not get data for file: #{file.inspect}\n#{apiCaller.respBody.inspect}\nCannot proceed..." if(!apiCaller.succeeded?)
      destUri = @outputDB.dup()
      # We need to check if the output target is a database, a 'files' area or a subdir
      # If we get a '/' its either a db or 'files', else its a subdir
      targetType = filehelperObj.subdir(destUri)
      dbUri = dbHelperObj.extractPureUri(destUri)
      tempUri = URI.parse(dbUri)
      destHost = tempUri.host
      destPath = tempUri.path
      nameOfFile = File.basename(filehelperObj.extractName(file))
      fileAttrs = {}
      fileAttrs['createdDate'] = Time.now
      fileAttrs['modifiedDate'] = Time.now
      fileAttrs['modifiedBy'] = @userId
      fileAttrs['label'] = metadata['label']
      fileAttrs['description'] = metadata['description']
      fileAttrs['attributes'] = metadata['attributes']
      destPath.gsub!("?", "")
      # Upload file first
      tempPath = destPath.dup()
      if(targetType == "/")
        tempPath << "/file/#{CGI.escape(nameOfFile)}/data"
      else
        tempPath << "/file#{targetType}/#{CGI.escape(nameOfFile)}/data"
      end
      tempPath << "gbKey=#{dbHelperObj.extractGbKey(dbUri)}" if(dbHelperObj.extractGbKey(dbUri))
      $stderr.puts("uploading file to: #{tempPath.inspect}")
      apiCaller = WrapperApiCaller.new(destHost, tempPath, @userId)
      apiCaller.put({}, File.open(fileName))
      # Set file related stuff
      fileAttrs.each_key { |key|
        if(!fileAttrs[key].nil? and key != 'gbUploadInProgress' and key != 'gbPartialEntity')
          tempPath = destPath.dup()
          if(targetType == "/")
            tempPath << "/file/#{CGI.escape(nameOfFile)}/#{key}?"
          else
            tempPath << "/file#{targetType}/#{CGI.escape(nameOfFile)}/#{key}?"
          end
          tempPath << "gbKey=#{dbHelperObj.extractGbKey(dbUri)}" if(dbHelperObj.extractGbKey(dbUri))
          apiCaller = WrapperApiCaller.new(destHost, tempPath, @userId)
          if(key == 'attributes')
            payload = {'data' => {'attributes' => fileAttrs[key]}}
          else
            payload = {'data' => {'text' => fileAttrs[key]}}
          end
          apiCaller.put(payload.to_json)
          $stderr.puts "Could not set #{key.inspect} for file: #{nameOfFile.inspect}.\n#{apiCaller.respBody.inspect}\n" if(!apiCaller.succeeded?)
        end
      }
      # Delete the source file if performing a move
      if(@deleteSourceFiles)
        origPath.gsub!("/data?", "?")
        origPath << "gbKey=#{dbHelperObj.extractGbKey(file)}" if(dbHelperObj.extractGbKey(file))
        apiCaller = WrapperApiCaller.new(host, origPath, @userId)
        $stderr.puts "Deleting file: #{origPath} from host: #{host}"
        apiCaller.delete()
        $stderr.puts "Could not delete data for file: #{file.inspect}\n#{apiCaller.respBody.inspect}\nContinuing..." if(!apiCaller.succeeded?)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Deleting file: #{fileName}")
      `rm -f #{fileName}`
    }
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    exit(14)
  end

end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is used for for downloading a list of one or more files and then uploading them into a new database/files(can also be subdir under files area)

  Notes: Intended to be called via the Genboree Workbench, by the fileCopierWrapper.rb script
  => Both input and output need to be full REST URIs
  => The script will not check if the file(s) with the same name exist in the output db or not.

  outputDatabase=
    -i  --inputFile                     => REST URI for input file(s) (required)
    -0  --outputDB                      => REST URI for output database/files
    -k  --dbrcKey                       => dbrcKey to make API calls (optional. If not provided will use BRL::Genboree::GenboreeUtil.getSuperuserDbrc() to get superuser user and pwd)
    -u  --userId                        => Genboree userid (This is used to send emails back to the user) (optional)
    -d  --deleteSourceFiles
    -s  --scratchDir                    => optional (will use pwd if not provided)
    -v  --version                       => Version of the program
    -h  --help                          => Display help

    Usage: ruby fileCopier.rb -i http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock\/file\/s%20%203%20sequence%20run18.txt?,http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock\/file\/s%20%203%20sequence%20run19.txt -o http:\/\/10.15.7.29\/REST\/v1\/grp\/EDACC%20-%20Test%20New%20Features\/db\/newSchemaForBlock?

  "
  def self.printUsage(additionalInfo=nil)
    puts DEFAULTUSAGEINFO
    puts additionalInfo unless(additionalInfo.nil?)
    if(additionalInfo.nil?)
      exit(0)
    else
      exit(15)
    end
  end

  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end

  def self.parseArgs()
    optsArray=[
      ['--inputFile','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--outputDB','-o',GetoptLong::REQUIRED_ARGUMENT],
      ['--dbrcKey','-k',GetoptLong::OPTIONAL_ARGUMENT],
      ['--userId','-u',GetoptLong::OPTIONAL_ARGUMENT],
      ['--deleteSourceFiles','-d',GetoptLong::OPTIONAL_ARGUMENT],
      ['--scratchDir','-s',GetoptLong::OPTIONAL_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def self.performFileCopier(optsHash)
    fileCopierObj = FileCopier.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performFileCopier(optsHash)
