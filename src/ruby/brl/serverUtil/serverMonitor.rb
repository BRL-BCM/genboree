#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'dbi'
require 'ping'
require 'timeout'
require 'open-uri'
require 'mechanize'
require 'webrick'

BLANK_RE = /^\s*$/
COMMENT_RE = /^\s*#/
PROB_EXT = '.problem.report.count'

module BRL ; module ServerUtil

# ##############################################################################
# CLASS: MonitorResult
# ##############################################################################
class MonitorResult
	attr_accessor :pingOk, :mysqlOk, :apacheOk, :tomcatOk, :browserOk, :monitorBad

	def initialize()
		@pingOk, @mysqlOk, @apacheOk, @tomcatOk, @browserOk, @monitorBad = false, false, false, false, false, false
	end

	def isOk?() # nil is 'ok' because it means the test is not performed (n/a)
		return	(
							(@pingOk.nil? or @pingOk) and
							(@mysqlOk.nil? or @mysqlOk) and
							(@apacheOk.nil? or @apacheOk) and
							(@tomcatOk.nil? or @tomcatOk) and
							(@browserOk.nil? or @browserOk) and
							(!@monitorBad)
						)
	end
end

# ##############################################################################
# CLASS: Monitor
# ##############################################################################
class Monitor
	PROP_KEYS = %w{
									output.emailAddresses
									output.report.interval
									output.log.dir
									input.domainList
									input.checkDomain
									input.checkPing
									input.mysqlDbrcNames
									inputs.mysqlDbNames
									input.apacheURLs
									input.tomcatURLs
									input.browserURLs
									input.browserHTMLTimeouts
									input.browserIMAGETimeouts
									param.ping.timeout
								}
	EMAIL_FROM = 'brl_admin@brl.bcm.tmc.edu'

	attr_accessor :monitorResults, :emailAddresses, :domains, :domainChecks, :domainPings
	attr_accessor :dbrcNames, :dbNames, :apacheURLs, :tomcatURLs, :browserURLs
	attr_accessor :browserHtmlTimeouts, :browserImgTimeouts
	attr_accessor :dbrcFileName, :emailFrom, :pingTimeout, :logDir, :logWriter

	# Initialize
	def initialize(optsHash)
		@optsHash = optsHash
		@emailFrom = EMAIL_FROM
		# Get dbrcfile name
		@dbrcFileName = ENV['DB_ACCESS_FILE'].dup.untaint
		# Parse options from file and command line
		parseOptions()
		# Set up logging
		@logFile = "#{@logDir}/#{Time.now.year}-#{Time.now.month}-#{Time.now.day}-#{Time.now.hour}:#{Time.now.min}:#{Time.now.sec}.serverMonitor.log.gz"
		@logWriter = BRL::Util::TextWriter.new(@logFile, "w+", true)
		@logWriter.sync = true
		@logWriter.puts "#{Time.now} STATUS: Server monitor started. (PID: #{$$})"
	end

	# Clean up
	def clear()
		@logWriter.puts "#{Time.now} STATUS: Server monitor done. Cleaning up."
		@logWriter.close unless(@logWriter.nil?)
		return
	end

	# Check each domain for appropriate upness
	def checkServers()
		@logWriter.puts "#{Time.now} STATUS: begin checking each server."
		@domains.each_index { |ii|
			domain = @domains[ii]
			checkDomain = @domainChecks[ii].nil? ? false : @domainChecks[ii]
			next unless(checkDomain)
			@logWriter.puts "#{Time.now} START: check '#{domain}'."
			# Check things
			result = MonitorResult.new()
			# Check Ping
			doPing = @domainPings[ii].nil? ? false : @domainPings[ii]
			result.pingOk = doPing ? checkPing(domain) : nil
			# Check Mysql
			dbrcName = @dbrcNames[ii]
			result.mysqlOk = (dbrcName.nil? ? nil : (dbrcName ? checkMysql(dbrcName) : false))
			# Check Apache
			apacheUrl = @apacheURLs[ii]
			result.apacheOk = (apacheUrl.nil? ? nil : (apacheUrl ? checkHttpURL(apacheUrl) : false))
			# Check Tomcat
			tomcatUrl = @tomcatURLs[ii]
			result.tomcatOk = (tomcatUrl.nil? ? nil : (tomcatUrl ? checkHttpURL(tomcatUrl) : false))
			# Check browser (both HTML and main image)
			browserUrl = @browserURLs[ii]
			result.browserOk = (browserUrl.nil? ? nil : (browserUrl ? checkBrowserURL(browserUrl, browserHtmlTimeouts[ii], browserImgTimeouts[ii]) : false))
			# Send email if problems
		  sendEmail = handleProblemFile(domain, result)
		  sendEmailNotice(domain, result) if(sendEmail)
			@logWriter.puts "#{Time.now} END: done check of '#{domain}'."
		}
		return
	end

	# Ping the domain
	def checkPing(domain)
		@logWriter.puts "#{Time.now} CHECK: try to ping machine at '#{domain}'."
		retVal = false
		begin
			retVal = Ping.pingecho(domain, @pingTimeout)
			@logWriter.puts "    RESULT: ping returned '#{retVal}'."
		rescue TimeoutError => terr
			@logWriter.puts "    RESULT: ping FAIL. Timed out. Machine not reachable or not responding."
			retVal = false
		rescue Exception => err
			@logWriter.puts "    RESULT: ping FATAL. Something went wrong.\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
			retVal = false
		end
		return retVal
	end

	# Ping the mysql server
	def checkMysql(dbrcRecordName)
		@logWriter.puts "#{Time.now} CHECK: try to db-ping MySQL for DBRC entry '#{dbrcRecordName}'."
		retVal = false
		begin
			# Get dbrc record for domain
			dbrc = BRL::DB::DBRC.new(@dbrcFileName, dbrcRecordName)
			# Get database handle for domain
			dbh = DBI.connect(dbrc.driver, dbrc.user, dbrc.password)
			# Ping Domain
			retVal = dbh.ping
			dbh.disconnect
			@logWriter.puts "    RESULT: db-ping returned '#{retVal}'."
		rescue DBI::DatabaseError => err
			@logWriter.puts "    RESULT: db-ping FAIL. Error type: '#{err.class}'\n\n    ErrorMessage:\n#{err.message}\n\n"
			retVal = false
		rescue Exception => err
			@logWriter.puts "    RESULT: db-ping FATAL. Something went wrong.\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
			retVal = false
		end
		return retVal
	end

	# Check http URL
	def checkHttpURL(url)
		@logWriter.puts "#{Time.now} CHECK: try to get http response from '#{url}'."
		retVal = false
		statusCode = nil
		begin
			# Get the response for URL
			open(url) { |httpFileHandle|
				statusCode = httpFileHandle.status.first.to_i
			}
			@logWriter.puts "    RESULT: got http response '#{statusCode}'."
		rescue OpenURI::HTTPError,Errno::ECONNREFUSED => err
			@logWriter.puts "    RESULT: http FAIL. Error type: '#{err.class}'."
		rescue Exception => err
			@logWriter.puts "    RESULT: http FATAL. Something went wrong.\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
			statusCode = false
		end
		return (statusCode == 200) # Plain HTTP OK response is 200.
	end

	def checkBrowserURL(url, htmlTimeout, imgTimeout)
		@logWriter.puts "#{Time.now} CHECK: try to get http response from '#{url}'."
		retVal = false
		statusCode = nil
		status = nil
		begin
			agt = WWW::Mechanize.new()
			@logWriter.puts "    DEBUG: WWW::Mechanize => #{agt}"
			# Check that we can get the HTML fast
			# We're not logged in and the we also need to trick the "in-browser" javascript code
			#        so that we can get around the special redirection page that enforces "in-browserness".
			#        This means that when requesting a browser page via a URL, we ACTUALLY get a redirect page
			#        NOT the page we're trying to get at.
			#        This page has the necessary JavaScript code on it to set a cookie dynamically and then do
			#        a Javascript redirect to the correct URL. We'll parse that info out of the Javascript code,
			#        set a cookie manually (we can't run Javascript), and then go after the real page.
			# All of this should happen quite fast.
			redirectPage = nil
			browserPage = nil
			status = Timeout::timeout(htmlTimeout) {
        # FIRST: get the url, which ends up actually giving use the redirection page contents.
        redirectPage = agt.get(url)
				@logWriter.puts "    DEBUG: redirect page length => #{redirectPage.body.length}"
				# SECOND: extract the <script> elements from the page
				scriptElems = redirectPage.search("//script")
				# THIRD: go through the <script> elements and try to find (a) the cookie info to set and (b) the URL to relocate to
				tgtUrlStr = nil
				cookieName = nil
				cookieValue = nil
				scriptElems.each { |elem|
          unless(elem.empty?)
            if(elem.innerText =~ /tgt\s*=\s*"([^"]+)"/)
              tgtUrlStr = $1
              @logWriter.puts "    DEBUG: redirect target => #{tgtUrlStr}"
            end
            if(elem.innerText =~ /setCookie\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"/)
              cookieName = $1
              cookieValue = $2
              @logWriter.puts "    DEBUG: redirect cookie => #{cookieName}=#{cookieValue}"
            end
          end
        }
				if(tgtUrlStr.nil? or cookieName.nil? or cookieValue.nil?)
          statusCode = false
          raise "--> ERROR: redirect page doesn't look like it should."
				end
				# FOURTH: create a URI from the target and set the cookie for it in our agent
				tgtUri = URI.parse(tgtUrlStr)
				cookie = WWW::Mechanize::Cookie.new(cookieName, cookieValue)
				cookie.domain = tgtUri.host
				agt.cookie_jar.add(tgtUri, cookie)
				# FIFTH: get the actual browser page now that we have the necessary cookie and info
				browserPage = agt.get(tgtUri)
				true # for status
			}
			puts "status = #{status.inspect}"
			if(browserPage.nil? or browserPage.body.length < 128 )
				statusCode = false
				raise "---> ERROR: either status is false (#{status}), browser page is nil (failed to get page) or browser page is short (#{browserPage.body.length}) for getting url '#{url}' with timeout of '#{htmlTimeout}'"
			end
			@logWriter.puts "    DEBUG: browser page length => #{browserPage.body.length}"
			# Check that we can get the IMAGE fast
			imgs = browserPage.search("//img[@usemap]").select{|xx| xx["src"] =~ /genb[_\.0-9]+\.png/ }
			url =~ /^(http:\/\/[^\/\?]+)/
			urlBase = $1
			imgUrl = urlBase + "/#{imgs.first['src']}"
			img = nil
			@logWriter.puts "    DEBUG: urlBase => #{urlBase} ; imgUrl => #{imgUrl}"
			status = Timeout.timeout(imgTimeout) {
				img = agt.get(imgUrl)
				@logWriter.puts "    DEBUG: img => #{img.body.length}"
				true # for status
			}
			if(img.body.length < 128)
				statusCode = false
				raise "---> ERROR: either status is false (#{status}) or img is short (#{img.body.length}) for getting url '#{imgUrl}' with timeout of '#{htmlTimeout}'"
			end
			# everything is ok
			statusCode = true
		rescue TimeoutError => terr
			@logWriter.puts "    RESULT: browser response timeliness FAIL. Timed out. Machine not responding fast enough."
			statusCode = false
		rescue Exception => err
			@logWriter.puts "    RESULT: browser response timeliness FATAL. Something went wrong.\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
			statusCode = false
		end
		return statusCode
	end

  def handleProblemFile(domain, result)
    sendEmail = false
    probFileName = "#{@logDir}/#{domain}#{PROB_EXT}"
    @logWriter.puts "    START: handle problem file #{probFileName} (result ok? #{result.isOk?})"
    # If result is ok, check for problem file and delete it if it exists. Don't send email.
    if(result.isOk?())
      File.delete(probFileName) if(File.exist?(probFileName))
      sendEmail = false
    else # result is not ok
      newCount = @problemReportInterval
      sendEmail = true # only false if we've already sent and still counting down until next "reminder"
      begin # rescue errors reading count file
        # Check if problem file exists
        if(File.exist?(probFileName) and File.size?(probFileName))
          # If it does exists, decrement the count.
          probFile = File.open(probFileName)
          oldCount = probFile.readline.strip.to_i
          probFile.close()
          newCount = oldCount - 1
        end
      rescue => err
        result.monitorBad = true
        @logWriter.puts "    DEBUG: monitor failed to read problem count file #{probFileName}\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
      ensure
        # If the count becomes 0, do send email and make the new count the max.
        if(newCount < 1 or result.monitorBad)
          sendEmail = true
          newCount = @problemReportInterval
        else # do not send email and just write new count value
          sendEmail = false
        end
      end
      begin # rescue problems writing count file
        # Regardless, we now need to write a value to probFile
        probFile = File.open(probFileName, 'w+')
        probFile.getLock()
        probFile.puts newCount
        probFile.close() # releases lock
      rescue => err
        @logWriter.puts "    DEBUG: monitor failed to write problem count file\n\n    Error type: '#{err.class}'\n\nError message:\n#{err.message}\n\n    Error Backtrace:\n" + err.backtrace.join("\n") + "\n\n"
        result.monitorBad = true
        sendEmail = true
      end
    end
    @logWriter.puts "    END: handle problem file #{probFileName}"
    return sendEmail
  end

	# Send emails
	def sendEmailNotice(domain, result)
		@logWriter.puts "#{Time.now} START: Make emails and send them off."
		# Need to construct an SMS-length email (160 char limit) message from
		# test results. Send a separate email to each address to save message space.
		begin
			# Ping Ok?
			pingStr = 'Ping: ' + (result.pingOk.nil? ? 'n/a' : (result.pingOk ? 'ok' : 'XX'))
			# Mysql Ok?
			mysqlStr = 'MySQL: ' + (result.mysqlOk.nil? ? 'n/a' : (result.mysqlOk ? 'ok' : 'XX'))
			# Apache Ok?
			apacheStr = 'Apache: ' + (result.apacheOk.nil? ? 'n/a' : (result.apacheOk ? 'ok' : 'XX'))
			# Tomcat Ok?
			tomcatStr = 'Tomcat: ' + (result.tomcatOk.nil? ? 'n/a' : (result.tomcatOk ? 'ok' : 'XX'))
			# Browser Ok?
			browserStr = 'Browser: ' + (result.browserOk.nil? ? 'n/a' : (result.browserOk ? 'ok' : 'TOO SLOW'))
			# Monitor did bad things?
			monitorBadStr = (result.monitorBad ? "Monitor: HAS ERRORS" : "")
			# Make full message
			emailBody = "\r\n-->\r\n#{domain}:\r\n\r\n#{pingStr}\r\n#{mysqlStr}\r\n#{apacheStr}\r\n#{tomcatStr}\r\n#{browserStr}\r\n#{monitorBadStr}\r\n\r\n(#{$$})"
			# Send emails
			@emailAddresses.each { |emailAddress|
				emailer = BRL::Util::Emailer.new()
				emailer.setHeaders('brl_admin@brl.bcm.tmc.edu', emailAddress, 'SERVER ALERT:')
				emailer.setRecipients(emailAddress)
				emailer.setMailFrom('brl_admin@brl.bcm.tmc.edu')
				emailer.setBody(emailBody)
				emailer.send()
				@logWriter.puts "    EMAIL: sent to '#{emailAddress}'."
			}
			@logWriter.puts "#{Time.now} END: Emails sent regarding '#{domain}'."
		rescue Exception => err
			@logWriter.puts "    EMAIL: email FATAL. Something went wrong.\r\n\r\nError message:\r\n#{err.message}\r\n\r\n    Error Backtrace:\r\n" + err.backtrace.join("\r\n") + "\r\n\r\n"
			return false
		else
			return true
		end
	end

	# Parse options hash
	def parseOptions()
		@propTable = BRL::Util::PropTable.new(File.open(@optsHash['--propFile']))
		# If options supplied on command line instead, use them rather than those in propfile
		PROP_KEYS.each {	|propName|
			argPropName = "--#{propName}"
			@propTable[propName] = @optsHash[argPropName] unless(@optsHash[argPropName].nil?)
		}
		# Verify the proptable contains what we need
		@propTable.verify(PROP_KEYS)
		# Grab the settings from the properties table
		@pingTimeout = @propTable['param.ping.timeout'].to_i
		@logDir = @propTable['output.log.dir']
		@emailAddresses = (@propTable['output.emailAddresses'].nil? or @propTable['output.emailAddresses'].empty?) ?
												[] :
												@propTable['output.emailAddresses']
		@domains =	(@propTable['input.domainList'].nil? or @propTable['input.domainList'].empty?) ?
									[] :
									@propTable['input.domainList']
		@domainChecks = @propTable['input.checkDomain'].map {|xx| xx.strip! ; ((xx =~ /yes|true|1/i) ? true : false ) }
		@domainPings = @propTable['input.checkPing'].map! {|xx| xx.strip! ; ((xx =~ /yes|true|1/i) ? true : false ) }
		@dbrcNames =	(@propTable['input.mysqlDbrcNames'].nil? or @propTable['input.mysqlDbrcNames'].empty?) ?
										[] :
										@propTable['input.mysqlDbrcNames']
		@dbrcNames.map!{|xx| if(xx =~ /<none>/) then nil else xx end  }
		@dbNames =	(@propTable['inputs.mysqlDbNames'].nil? or @propTable['inputs.mysqlDbNames'].empty?) ?
										[] :
										@propTable['inputs.mysqlDbNames']
		@dbNames.map!{|xx| if(xx =~ /<none>/) then nil else xx end }
		@apacheURLs = (@propTable['input.apacheURLs'].nil? or @propTable['input.apacheURLs'].empty?) ?
										[] :
										@propTable['input.apacheURLs']
		@apacheURLs.map!{|xx| if(xx =~ /<none>/) then nil else xx end }
		@tomcatURLs = (@propTable['input.tomcatURLs'].nil? or @propTable['input.tomcatURLs'].empty?) ?
										[] :
										@propTable['input.tomcatURLs']
		@tomcatURLs.map!{|xx| if(xx =~ /<none>/) then nil else xx end }
		@browserURLs = (@propTable['input.browserURLs'].nil? or @propTable['input.browserURLs'].empty?) ?
										[] :
										@propTable['input.browserURLs']
		@browserURLs.map!{|xx| if(xx =~ /<none>/) then nil else xx end }
		@browserHtmlTimeouts = (@propTable['input.browserHTMLTimeouts'].nil? or @propTable['input.browserHTMLTimeouts'].empty?) ?
										[] :
										@propTable['input.browserHTMLTimeouts']
		@browserHtmlTimeouts.map!{|xx| if(xx =~ /<none>/) then nil else xx.to_i end }
		@browserImgTimeouts = (@propTable['input.browserIMAGETimeouts'].nil? or @propTable['input.browserIMAGETimeouts'].empty?) ?
										[] :
										@propTable['input.browserIMAGETimeouts']
		@browserImgTimeouts.map!{|xx| if(xx =~ /<none>/) then nil else xx.to_i end }
		@problemReportInterval = @propTable['output.report.interval'].to_i
		return
	end

	# Process command line args
	def Monitor.processArguments()
		optsArray =	[
									['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		Monitor.usage() if(optsHash.empty? or optsHash.key?('--help'))
		return optsHash
	end

	def Monitor.usage(msg='')
		puts "\n#{msg}\n" unless(msg.empty?)
		puts "

  PROGRAM DESCRIPTION:
    Checks various machines for reachability and upness of their server applications.

    The various machine names and servers to check are specified in the
    configuration file.

    Meant to be run from a cronjob.

    DBRC file must be available from the $DB_ACCESS_FILE environmental variable.

    COMMAND LINE ARGUMENTS:
      -p    => Name of the properties file with all the configuration info.
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
    serverMonitory.rb -p config.properties
	"
		exit(BRL::Genboree::USAGE_ERROR)
	end
end

end ; end # end BRL ; end ServerUtil


# ##############################################################################
# MAIN
# ##############################################################################
# Parse args
optsHash = BRL::ServerUtil::Monitor.processArguments()
# Create new monitor
monitor = BRL::ServerUtil::Monitor.new(optsHash)
begin
	# Do check
	monitor.checkServers()
rescue Exception => err
  monitor.logWriter.puts "\n\nERROR: #{err.message}\n\n'" + err.backtrace.join("\n") + "\n\n"
ensure
	# Clean up
	monitor.clear()
end
exit(0)
