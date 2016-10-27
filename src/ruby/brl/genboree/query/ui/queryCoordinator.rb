#! /usr/bin/env ruby

########################################################################################
# Project: Boolean Query Engine and UI
#
# queryCoordinator.rb - This file performs a 
#   1. Perform an API call to apply a saved query to a valid API resource
#   2. Write the results of this query to a tab-delimited file
#   3. Notifies the user (command-line or email)
#
# Arguments:
# -o, --options (REQUIRED) : A JSON formatted object representing the options
#     queryURI:   The API URI that represents the saved query.
#     targetURI:  The API URI that represents the resource list to apply the query against.
#     dataPath:   A path on the local disk where the results should be saved.
# -d, --daemonize (OPTIONAL): Run the coordinator as a daemon (default when called from web)
########################################################################################

require 'rubygems'
require 'cgi'
require 'uri'
require 'json'
require 'getoptlong'
require 'fileutils'
require 'logger'
require 'brl/util/emailer'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/data/refEntity'


###############################################################################
# BEGIN Utility methods to create necessary runtime files and to apply a Query
###############################################################################

###############################################################################
# The +printUsage+ method will alert the user of the usage information for the
# queryCoordinator. This is displayed when the user specifies the -h/--help
# arguments. MFS (BNI)
#
# * Arguments : none
###############################################################################
def printUsage()
  print <<USAGE
queryCoordinator usage:
ruby queryCoordinator.rb [OPTIONS]

OPTIONS:
  -h, --help      : Print this usage information
  -d, --daemonize : Run the coordinator as a daemon, if an email address is
                    provided in the options then an email notification will be
                    sent upon completion.
  -o, --options   : Specify options for the Query Engine JSON formatted object
                    containing the following attributes (required),
      queryURI  :   The API URI that represents the saved query.
      targetURI :   The API URI that represents the resource list to apply the
                    query against.  This URI *must* end in "/query" or else the
                    query will not be applied.
      userLogin  :   The username used to access the API.
      passwd    :   The password used to access the API.
      dbrcKey   :   If a password is not provided, then a dbrc key must be present
      dataPath  :   A path on the local disk where the results should be saved.
  -l, --log       : The path to the debug log output.
  -j, --job       : The Job ID for this task, (optional) 
                    eg) '-j "123456_1"'
USAGE
exit(2)
end

###############################################################################
# The +executeQuery+ method will make a API call to execute a save query.
###############################################################################
def executeQuery()
  begin
    # Run API caller
    @debugLog.debug("[executeQuery] Creating API Caller...")
    if(@options['passwd'].nil?)
      # User password not provided, get it from the database
      dbUtil = BRL::Genboree::DBUtil.new(@options['dbrcKey'], nil)
      userObj = dbUtil.getUserByName(@options['userLogin']).first()
      @options['passwd'] = userObj['password'] # TODO: When digests are stored in the DB, use digest
    end

    # Chop off our hostname if present in the targetUri & queryUri
    queryUri = URI.parse(@options['queryURI']).path()   
    targetUri = URI.parse(@options['targetURI']).path()

    # Get our group and db to assist user when locating results
    group = (@options['saveGroup'].nil?) ? '' : CGI.unescape(@options['saveGroup'])
    db = (@options['saveDb'].nil?) ? '' : CGI.unescape(@options['saveDb'])

    # First, determine our response format from the resources metadata
    apiCaller = BRL::Genboree::REST::ApiCaller.new(@hostname, targetUri + '/queryable', @options['userLogin'], @options['passwd'])
    apiCaller.get()
    respFormat = apiCaller.parseRespBody['data']['responseFormat']
    respFormat = (respFormat.nil? or respFormat.empty?) ? 'tabbed' : respFormat

    # Now that we have the targetUri setup, point the apiCaller there
    targetUri += "/query?responseFormat=#{respFormat}"
    query = BRL::Genboree::REST::Data::RefEntity.new(false, queryUri)
    apiCaller.setRsrcPath(targetUri)
  
    # Ensure our dirs exist before we write the API response to the file
    @debugLog.debug("[executeQuery] Target URI: #{targetUri}")
    @debugLog.debug("[executeQuery] Save Group: #{group}")
    @debugLog.debug("[executeQuery] Save Db: #{db}")
    @debugLog.debug("[executeQuery] Query URI: #{queryUri}")
    @debugLog.debug("[executeQuery] Calling API URI to apply query...")
    @debugLog.debug("[executeQuery] Creating data path to store results (#{respFormat} formatted): #{@options['dataPath']}...")
    FileUtils.makedirs(@options['dataPath'])
    
    # Get a (possibly) chunked response from the apiCaller, and write to our file
    output = nil
    filename = ''
    apiCaller.get(nil, query.to_json) { |chunk|
      # Lazily setup our file for writing so that we can check our
      # content_type (affects the filename)
      # FIXME - detect error response codes and respond appropriately
      if(output.nil?)
        filename = "#{@filesPrefix}-output"
        filename += ".lff" if(apiCaller.httpResponse.content_type == "text/lff")
        output = File.open(File.join(@options['dataPath'], filename), "w")
      end

      # And now write each chunk to our file
      output.print(chunk)
    }
    
    output.close() unless(output.nil?)

    # Notify the user
    # TODO - When the tabbed file viewer is done, link to that?
    @statusString = ""
    @statusString << "Your Boolean Query has been executed (job ID: #{@uniqueId}). "
    @statusString << "Your results can be accessed by visiting the Genboree Workbench:\n"
    @statusString << "http://#{@hostname}/java-bin/workbench.jsp\n\n"
    @statusString << "Navigate to your results file using the 'Data Selector' tree on the left of the page\n\n"
    @statusString << "The following steps can assist you to locate your file if you are new to the Workbench:\n"
    @statusString << "1. Click the triangle next to the group '#{group}' node\n"
    @statusString << "2. Click the triangle next to the 'Databases' node\n"
    @statusString << "3. Click the triangle next to the database '#{db}' node\n"
    @statusString << "4. Click the triangle next to the 'Files' node\n"
    @statusString << "5. Click the triangle next to the 'queryResults' node\n"
    @statusString << "6. Click the '#{filename}' node\n"
    @statusString << "7. The 'Details' table on the right side of the page with show the information for your file. "
    @statusString << "Press the 'Click to Download File' link to save your results to your computer.\n"
    @statusString << "\n\nIf you have any questions, please contact your Genboree administrator.\n"
    @debugLog.debug("[executeQuery] Finished executing Boolean Query...")
  rescue => e
    raise RuntimeError.new("There was an error executing the Boolean Query: #{e}\n#{e.backtrace.join(' \n')}")
  end
end

###############################################################################
# The +notifyUser+ method will alert the user of the outcome of the Query.
# It will create a message and send it to the users provided email address,
# If no email address provided, prints to stdout.
# Method uses the BRL emailer utility, courtesy of ARJ (BRL). MFS (BNI)
#
# * Arguments :
#  - +String+ -> The message to display
#  - +String+ -> The email address to send to
###############################################################################
def notifyUser(message, emailAddr=nil)
  unless(emailAddr.nil?)
    # Log our info for debug purposes
    debugInfo = "[notifyUser] Preparing email notification...\n"
    debugInfo << "\temail to: #{emailAddr}\n"
    debugInfo << "\temail from: #{@genbConf.gbFromAddress}"
    @debugLog.debug(debugInfo)

    begin
      email = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      # Set From:, To:, Subject:
      email.setHeaders(@genbConf.gbFromAddress, emailAddr, "Genboree Has Run Your Queued Boolean Query Job")

      # Now set who to send the email as (a valid user at the SMTP host)
      email.setMailFrom(@genbConf.gbFromAddress)

      # Now add user(s) who will receive the email.
      email.addRecipient(emailAddr)

      # Add the body of your email message
      email.setBody(message + "\nThank You,\nThe Genboree Team")
      sendOk = email.send()
      if(sendOk)
        @debugLog.debug("[notifyUser] Sending of email succeeded.")
      else
        @debugLog.debug(  "[notifyUser] Sending of email failed. Emailer reports this error:\n" +
                          "#{email.sendError.class}: #{email.sendError.message}\n  " +
                          email.sendError.backtrace.join("\n  ") )
      end
    rescue => err
      @debugLog.error("[notifyUser] An error occurred while preparing and sending the nofication!\n#{err}")
    end

  else
    @debugLog.debug("[notifyUser] Printing to console...")
    puts "\n#{message}"
  end
  @debugLog.debug("[notifyUser] User notification complete...")
end

########################################################################################
# END utility methods
########################################################################################

########################################################################################
# BEGIN Processing and generating return content/notification
########################################################################################

# Declare required variables
@filesPrefix = ""
@statusString = ""
@currScratchSpace = ""
@chromDefFilePath = ""
@lffFilePath = ""
@segsLffFilePath = ""
@paramFilePath = ""
@options = Hash.new
@userEmail = nil
@daemonize = false
jsonString = ""
filePath = ""
debugLogPath = "/usr/local/brl/data/genboree/temp/query/queryCoordinator.debug"
@uniqueId = Time.now.to_i.to_s + "_#{rand(65525)}"

optsArray = [['--help', '-h', GetoptLong::NO_ARGUMENT],
             ['--daemonize', '-d', GetoptLong::NO_ARGUMENT],
             ['--options', '-o', GetoptLong::REQUIRED_ARGUMENT],
             ['--job', '-j', GetoptLong::OPTIONAL_ARGUMENT],
             ['--log', '-l', GetoptLong::OPTIONAL_ARGUMENT]]

progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
if(optsHash.key?('--help')) then
  printUsage()
end

unless(progOpts.getMissingOptions().empty?)
  printUsage
end
if(optsHash.empty?) then
  printUsage()
end

# Load our config file to access Genboree constants
@genbConf = BRL::Genboree::GenboreeConfig.load()

# Setup necessary variables
@hostname = ENV["HTTP_HOST"] || @genbConf.machineName
@daemonize = true unless optsHash['--daemonize'].nil?
filePath = optsHash['--file'] unless optsHash['--file'].nil?
@uniqueId = optsHash['--job'] 
@uniqueId = Time.now.to_i.to_s + "_#{rand(65525)}" if(@uniqueId.nil?)
debugLogPath = optsHash['--log'] unless optsHash['--log'].nil?

# Make the log (and stderr/stdout logging, if needed) path if necessary.
debugLogPathDir = File.dirname(debugLogPath)
FileUtils.mkdir_p(debugLogPathDir)

# Read our options, JSON formatted object. First check for the file specified, then the options struct
jsonString = optsHash['--options'] unless optsHash['--options'].nil?
@options.merge!(JSON.parse(jsonString)) unless jsonString.empty?

# Ensure the required options are present
if(@options.nil? or
   @options["userLogin"].nil? or
   (@options["passwd"].nil? and @options["dbrcKey"].nil?) or
   @options["queryURI"].nil? or
   @options["targetURI"].nil? or
   @options["dataPath"].nil?)

  raise ArgumentError
end

# What's the basis for our various file names?
@filesPrefix = @options["userLogin"].to_s + "_" + @uniqueId

# Check if we are daemonized - if so, daemonize and go forth
if(@daemonize)
  require 'daemons'
  Daemons.daemonize
  # ARJ => fix up the stderr & stdout streams
  #   NOTE: errors up to this point may be missed since no where for stderr content to go
  #
  # First, we note that STDERR and $stderr are NOT the same thing!
  #
  # > Remember: the global variable $stderr is where Ruby actually sends
  # > standard error output.  The constant STDERR is just a saved
  # > copy of the value $stderr got when Ruby started up.
  #
  # > If the is a Ruby library and is well-behaved,
  # > then you don't have to mess with STDERR; just change $stderr to
  # > point to someplace else.
  #
  # Since we are daemonizing [here], the contents of STDERR are likely suspect
  # at best (e.g. original streams have been clossed), non-existent
  # (new process with closed stderr/stdout/stdin streams), or something. Regardless,
  # let's not manipulate a system constant (<- constant...). Same goes for
  # STDOUT.
  #
  # Let's play with $stderr and $stdout instead.
  # For safety, we'll direct these streams to their own files, independent of
  # anything else we're messing with. We'll put them in the same dir as debugLogPath
  # 
  # We also should reset the umask since it is cleared when daemonized. (MFS, BNI)
  File.umask(002)
  $stderr = File.new("#{debugLogPathDir}/#{@filesPrefix}.queryCoordinator.err", "w+")
  $stdout = File.new("#{debugLogPathDir}/#{@filesPrefix}.queryCoordinator.out", "w+")
  # We further note that:
  # - *we* don't need to close $stderr nor $stdout; Ruby closes that when it exits
  # - this is not needed if running on the command line non-daemonized...user will
  #   redirect stderr & stdout themselves and thus $stderr and $stdout will be appropriately set
end

# Debug logger - make the log path if necessary
@debugLog = Logger.new(debugLogPath)
@debugLog.level = Logger::DEBUG
@debugLog.datetime_format = "%Y-%m-%d %H:%M:%S, "

begin # actual processing
  @debugLog.info("-" * 60)
  @debugLog.debug("Boolean Query Coordinator started...")
  raise ArgumentError if(jsonString.empty?)

  @userEmail = @options["userEmail"]
  configDebug = "Boolean Query Config Options:\n"
  configDebug << "  userEmail: #{@userEmail}\n"
  configDebug << "  userLogin : #{@options["userLogin"]}\n"
  @debugLog.debug(configDebug)

  # Apply the query
  executeQuery()
rescue JSON::ParserError => e
  # If there was an error with the JSON, alert the user
  @statusString << "An internal system error has occurred while executing your Boolean Query (job ID: #{@uniqueId}), "
  @statusString << "please contact your Genboree administrator for assistance.\n"
  @statusString << "*ERROR*: The received JSON data was malformed!\n"

  debugLine = "An internal system error has occurred (job ID: #{@uniqueId})!\n"
  debugLine << "ERROR: The received JSON data was malformed!\n"
  debugLine << "EXCEPTION: #{e}\n"
  debugLine << e.backtrace.join("\n")
  @debugLog.error(debugLine)
rescue ArgumentError => e
  missingParams = Array.new
  if(@options.empty?)
    missingParams << "Config parameters object empty"
  else
    missingParams << "Missing config parameters: "
    missingParams << "userLogin" if @options["userLogin"].nil?
    missingParams << "no passwd or dbrcKey (one or the other is required)" if (@options["passwd"].nil? and @options["dbrcKey"].nil?)
    missingParams << "queryURI" if @options["queryURI"].nil?
    missingParams << "targetURI" if @options["targetURI"].nil?
    missingParams << "dataPath" if @options["dataPath"].nil?
  end

  @statusString << "An internal system error has occurred while executing your Boolean Query (job ID: #{@uniqueId}), "
  @statusString << "please contact your Genboree administrator for assistance.\n"
  @statusString << "*ERROR*: Required parameters were missing!\n  #{missingParams.join("\n  ")}\n"

  debugLine = "An internal system error has occurred (job ID: #{@uniqueId})!\n"
  debugLine << "ERROR: Required parameters were missing!\n#{missingParams.join(("\n\t"))}\n"
  debugLine << "EXCEPTION: #{e}\n"
  debugLine << e.backtrace.join("\n")
  @debugLog.error(debugLine)
rescue Exception => e
  # Failsafe, if any other error occurs (perhaps with the fork?), alert the user
  @statusString << "An internal system error has occurred while executing your Boolean Query (job ID: #{@uniqueId}), "
  @statusString << "please contact your Genboree administrator for assistance.\n"
  @statusString << "*ERROR*: An unknown error has occurred!\n"

  debugLine = "An internal system error has occurred (job ID: #{@uniqueId})!\n"
  debugLine << "ERROR: An unknown error has occurred!\n"
  debugLine << "EXCEPTION: #{e}\n"
  debugLine << e.backtrace.join("\n")
  @debugLog.error(debugLine)
ensure
  notifyUser(@statusString, @userEmail)
end

########################################################################################
# END Processing
########################################################################################
