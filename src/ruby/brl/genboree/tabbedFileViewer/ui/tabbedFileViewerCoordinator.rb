#! /usr/bin/env ruby

########################################################################################
# Tabbed File Viewer - tabbedFileViewerCoordinator.rb
#   This helper script will execute a sort on a tab separated data file (which can be of
#   sort of tabbed data, but usually the result of a tool execution, like the queryCoordinator)
#   Because many of these data files can be large, it supports running in Daemonized mode 
#   so that any calling script will not block. Note that the while this method can be 
#   executed from the command line, the most common usage will be for the Tabbed File Viewer UI 
#   to invoke the sort command from the Genboree Workbench. In that case, the UI will properly 
#   make the call to daemonize or not based on size of the data file. 
#
# Arguments:
# -o, --options (REQUIRED) : A JSON formatted object representing the VGP options (for drawing and running)
# -d, --daemonize (OPTIONAL): Run the coordinator in a daemonized mode (default when called from web)
#
# Developed by Bio::Neos, Inc. (BIONEOS)
# under a software consulting contract for:
# Baylor College of Medicine (CLIENT)
# Copyright (c) 2010 CLIENT owns all rights.
# To contact BIONEOS, visit http://bioneos.com
########################################################################################

require 'cgi'
require 'json'
require 'logger'
require 'getoptlong'
require 'brl/util/emailer'
require 'brl/genboree/genboreeUtil'

###############################################################################
# The +printUsage+ method will alert the user of the usage information for the
# vgpCoordinator. This is displayed when the user specifies the -h/--help
# arguments. MFS (BNI)
#
# * Arguments : none
# FIXME
###############################################################################
def printUsage()
  print <<USAGE
tabbedFileViewerCoordinator usage:
ruby tabbedFileViewerCoordinator.rb [OPTIONS]

OPTIONS:
  -h, --help      : Print this usage information
  -d, --daemonize : Run the coordinator as a Daemon, if an email address is provided in the options
                    then an email notification will be sent upon completion
  -o, --options   : Specify the VGP options as a JSON formatted object (eg '{"config" : {"userId" : 1}}')
  -j, --job       : The desired Job ID for this VGP run, optional (eg '-j "123456_1"')

NOTE: A config object is required! Either specified via -o <object> or -f <pathToFile>
USAGE
exit(2)
end


###############################################################################
# Perform the actual sort. This will sort the specified data file by the 
# appropriate key (tab) and then move the results to the correct path. This
# method will also operate in deamonized mode if the data file is large
#
# * Arguments:
# [+userLogin+]      The user executing the sort, needed for the lockfile
# [+sortField+]      The column to sort on
# [+sortDir+]        The direction sort, either ASC or DESC
# [+srcFilePath+]    The full path to the source data file to sort
# [+sortedFilePath+] The full path that the results of the sort should be stored
###############################################################################
def executeSort(userLogin, sortField, sortDir, srcFilePath, sortedFilePath)
  # NOTE: We store the sort in an intermediate temp location so that if a user happens to return to the 
  #     : workbench, they won't see the currently-being-sorted file in the tree. Moved to final location on complete
  tmpSortPath = File.join(File.dirname(sortedFilePath), "#{File.basename(sortedFilePath)}_#{Time.now().to_f.round.to_s}.partial")

  # First, we need to grab the header line and make sure it stays at the top for future reads
  # (That is if the first line is a header line, if not, we ignore it)
  File.open(srcFilePath) { |rootFile|
    header = rootFile.readline()

    if(header.match(%r{^\s*#+(.+)}))
      # Our first line was a header line, so write it out to the dest. file
      File.open(tmpSortPath, "w") { |destFile|
        destFile << header
        destFile.flush()
      }
    end
  }

  # Build our sort command - only store non comment lines
  col, index = sortField.split(":").map { |val| val.chomp() }
  sortCmd = "grep -v \"^#\" #{srcFilePath} | sort +#{index.to_i + 1} -#{index.to_i + 2}"
  sortCmd << " -r" if(sortDir.downcase() == "desc")
  sortCmd << " >> #{tmpSortPath} ; mv -f #{tmpSortPath} #{sortedFilePath}"
  @debugLog.info("[executeSort] Going to sort by #{col}, in #{sortDir} order -> #{sortedFilePath}")
  @debugLog.debug("[executeSort] Sort command: #{sortCmd}")

  # Touch our lockfile (this is somewhat unnecessary for the quickSort jobs)
  FileUtils.touch(File.join(@genbConf.gbJobBaseDir, userLogin, 'tabbedFileViewer', @sortJob, 'sort.lock'))
  
  # Now perform the actual sort
  system(sortCmd)

  # When our sort is done, remove the lockfile
  File.delete(File.join(@genbConf.gbJobBaseDir, userLogin, 'tabbedFileViewer', @sortJob, 'sort.lock'))
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
  unless(emailAddr.nil? or emailAddr.empty?)
    # Log our info for debug purposes
    debugInfo = "Preparing email notification...\n"
    debugInfo << "\temail to: #{emailAddr}\n"
    debugInfo << "\temail from: #{@genbConf.gbFromAddress}"
    @debugLog.debug(debugInfo)

    begin
      email = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      # Set From:, To:, Subject:
      email.setHeaders(@genbConf.gbFromAddress, emailAddr, "Genboree Has Sorted Your Data File")

      # Now set who to send the email as (a valid user at the SMTP host)
      email.setMailFrom(@genbConf.gbFromAddress)

      # Now add user(s) who will receive the email.
      email.addRecipient(emailAddr)

      # Add the body of your email message
      email.setBody(message + "\nThank You,\nThe Genboree Team")
      sendOk = email.send()
      
      if(sendOk)
        $stderr.puts("[notifyUser] User (#{emailAddr}) successfully notified of long running sort completion.")
      else
        $stderr.puts("[notifyUser] Sending of email failed. Emailer reports this error:\n" +
                     "#{email.sendError.class}: #{email.sendError.message}\n  " + email.sendError.backtrace.join("\n  "))
      end
    rescue => err
      @debugLog.error("[notifyUser] An error occurred while preparing and sending the long running sort completion nofication!\n#{err}")
    end
  end
  
  @debugLog.debug("[notifyUser] User notification complete")
end

########################################################################################
# BEGIN Processing and generating return content/notification
########################################################################################

# Declare required variables
@debugLog = nil
@sortJob = -1
@statusString = ''
@genbConf = BRL::Genboree::GenboreeConfig.load()

optsArray = [['--help', '-h', GetoptLong::NO_ARGUMENT],
             ['--daemonize', '-d', GetoptLong::NO_ARGUMENT],
             ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
             ['--results', '-r', GetoptLong::REQUIRED_ARGUMENT],
             ['--column', '-c', GetoptLong::REQUIRED_ARGUMENT],
             ['--direction', '-t', GetoptLong::REQUIRED_ARGUMENT],
             ['--email', '-e', GetoptLong::REQUIRED_ARGUMENT],
             ['--user', '-u', GetoptLong::REQUIRED_ARGUMENT],
             ['--grp', '-g', GetoptLong::REQUIRED_ARGUMENT],
             ['--db', '-b', GetoptLong::REQUIRED_ARGUMENT],
             ['--orig', '-o', GetoptLong::REQUIRED_ARGUMENT],
             ['--job', '-j', GetoptLong::REQUIRED_ARGUMENT],
             ['--log', '-l', GetoptLong::REQUIRED_ARGUMENT]]

progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
if(optsHash.key?('--help') or optsHash.empty?())
  printUsage()
end

@daemonize = (optsHash['--daemonize'].nil?()) ? false : true
@sortJob = optsHash['--job'] || "sort-#{Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0')}"
dataFile = optsHash['--file'] || ''
resultsFile = optsHash['--results'] || ''
sortField = optsHash['--column'] || ''
sortDir = optsHash['--direction'] || ''
userEmail = optsHash['--email'] || ''
userLogin = optsHash['--user'] || ''
grp = optsHash['--grp'] || ''
db = optsHash['--db'] || ''
origFile = optsHash['--orig'] || ''
debugLogPath = optsHash['--log'] || '/usr/local/brl/data/genboree/temp/tabbedFileViewerSort.debug'
FileUtils.mkdir_p(File.dirname(debugLogPath))

# Now, check to see if we should run daemonized
if(@daemonize)
  require 'daemons'
  Daemons.daemonize

  # Make sure to reset our stderr and stdout streams
  File.umask(002)
  $stderr = File.new("#{File.dirname(debugLogPath)}/tabbedFileViewerSort.err", "w+")
  $stdout = File.new("#{File.dirname(debugLogPath)}/tabbedFileViewerSort.out", "w+")
end

# Setup our debug log
@debugLog = Logger.new(debugLogPath)
@debugLog.level = Logger::DEBUG
@debugLog.datetime_format = "%Y-%m-%d %H:%M:%S, "

begin
  @debugLog.info('-' * 60)
  @debugLog.info('Sort operation initiated')
  # First check our required arguments, make sure they have been specified
  {
    'user' => userLogin,
    'file' => dataFile, 
    'results' => resultsFile, 
    'column' => sortField, 
    'direction' => sortDir
  }.each_pair { |key, arg| raise ArgumentError.new("A required parameter was missing! #{key}") if(arg.empty?()) }

  executeSort(userLogin, sortField, sortDir, dataFile, resultsFile)

  # Set our statusString to the success message
  @statusString = "Genboree has successfully sorted your data file #{origFile}.\nTo view the sorted data, please return to "
  @statusString << "the Genboree Workbench and locate your data file in the 'Data Selector' tree. "
  unless(grp.empty?() or db.empty?() or origFile.empty?())
    hostname = ENV["HTTP_HOST"] || @genbConf.machineName
    @statusString << "\n\nYour sorted data file can be accessed by visiting the Genboree Workbench:\n"
    @statusString << "http://#{hostname}/java-bin/workbench.jsp\n\n"
    @statusString << "Navigate to your sorted file using the 'Data Selector' tree on the left of the page\n\n"
    @statusString << "The following steps can assist you to locate your file if you are new to the Workbench:\n"
    @statusString << "1. Click the triangle next to the group '#{grp}' node\n"
    @statusString << "2. Click the triangle next to the 'Databases' node\n"
    @statusString << "3. Click the triangle next to the database '#{db}' node\n"
    @statusString << "4. Click the triangle next to the 'Files' node\n"
    @statusString << "6. Click the '#{origFile}' node\n"
    @statusString << "The 'Details' table on the right side of the page with show the information for your file.\n\n"
  end
  @statusString << "You can either:\n"
  @statusString << "1. Drag the data file to the 'Input Data' box and select the 'Tabbed File Viewer' from the 'Data --> Files' menu\n"
  @statusString << "2. Or you can press the 'Click to Download File' link from the 'Details' box to save the sorted data file locally\n"

rescue Exception => e
  @statusString = "An internal error has occurred while trying to complete sort job #{@sortJob} on your data file (#{dataFile}). "
  @statusString << "Please contact your Genboree administrator, #{@genbConf.gbAdminEmail} and alert them of the sort job ID and following error:\n"
  @statusString << "ERROR: #{e.message()}"

  debugLine = "An internal error occurred for sort job ID #{@sortJob} while trying to sort the following data file: #{dataFile}.\n"
  debugLine << "ERROR: #{e.message()}\n"
  debugLine << "EXCEPTION: #{e}\n"
  debugLine << e.backtrace.join("\n")
  @debugLog.error(debugLine)
ensure
  notifyUser(@statusString, userEmail)

  # Cleanup
  @debugLog.info('Sort operation finished')
  @debugLog.info('-' * 60)
  @debugLog.close()
end
