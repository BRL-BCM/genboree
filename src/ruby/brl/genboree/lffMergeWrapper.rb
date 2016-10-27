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
require 'brl/util/emailer'
require 'brl/genboree/genboreeUtil'

$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module Genboree
	OK_CODE, FAIL_CODE, USAGE_ERR, FATAL_ERR = 4,8,16,32
	FATAL, OK, OK_WITH_ERRORS, FAILED = 1,0,2,3
	INPUT_FMTS = ['lff','blat','blast']
	STDERR_LOG = '/usr/local/brl/local/apache/htdocs/logs/catalina.out'
	# Regular expressions
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	HEADER_RE = /^\s*\[/
	EC_RE = /^EC\: (\d+)$/
	# Char codes
	OCTOTHORP_ASCII = 35
	OPENBRACKET_ASCII = 91
	MAX_NUM_ERRS = 150
	MAX_EMAIL_ERRS = 50
	MAX_EMAIL_SIZE = 30_000
	MAX_NUM_REC = 3_000_000
	MERGE_SUFFIX = 'merged.lff'
	FROM_HDR = 'genboree_admin@genboree.org'
	PROP_KEYS = 	%w{
										program.sizeChecker
										program.merger
										program.noMerger
										program.ruby
										program.blat2lff
										program.blast2lff
										output.outputDir
										output.baseUrl
									}

class LFFMergeWrapper
	attr_accessor :lffFileName, :maxNumRecs, :emailAddresses, :maxNumRecs, :jobID
	attr_accessor :inputFormat

	def initialize(optsHash)
		@baseUrl = nil
		@params = optsHash
		@lffFileName = File.expand_path(optsHash['--lffFile'])
		@emailAddresses = optsHash['--emailAddressList'].split(',')
		@bccAddresses = optsHash.key?('--bccAddressList') ? optsHash['--bccAddressList'].split(',') : []
		@validRefSeqFile = optsHash.key?('--validRefSeqFile') ? File.expand_path(optsHash['--validRefSeqFile']) : nil
		@maxNumRecs = optsHash.key?('--maxNumRecs') ? optsHash['--maxNumRecs'].to_i : MAX_NUM_REC
		@noMerge = optsHash.key?('--noMerge') ? true : false
		@inputFormat = optsHash.key?('--inputFormat') ? optsHash['--inputFormat'].strip.downcase : INPUT_FMTS[0]


		##########################################################################
		# Process the properties file to get location of needed programs
		@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
		# If options supplied on command line instead, use them rather than those in propfile
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			unless(optsHash[argPropName].nil?)
				@propTable[propName] = optsHash[argPropName]
			end
		}
		# Verify the proptable contains what we need
		@propTable.verify(PROP_KEYS)
		@urlParam = ''
		if(optsHash.key?('--output.baseUrl'))
			@urlParam = "--output.baseUrl=http://#{optsHash['--output.baseUrl'].strip}/temp/lffMerge"
			@baseUrl = "http://#{optsHash['--output.baseUrl'].strip}/temp/lffMerge"
		end
		@ruby = ((@propTable['program.ruby'].nil? or @propTable['program.ruby'].strip.empty?) ? '' : File.expand_path(@propTable['program.ruby']))
		@sizeChecker = @ruby + ' ' + File.expand_path(@propTable['program.sizeChecker'])
		@blat2lff = @ruby + ' ' + File.expand_path(@propTable['program.blat2lff'])
		@blast2lff = @ruby + ' ' + File.expand_path(@propTable['program.blast2lff'])
		if(@noMerge)
			@merger = @ruby + ' ' + File.expand_path(@propTable['program.noMerger'])
		else
			@merger = @ruby + ' ' + File.expand_path(@propTable['program.merger'])
		end
		@outDir = @propTable['output.outputDir']
		if(@baseUrl.nil?)
			@baseUrl = (@propTable['output.baseUrl'].nil? or @propTable['output.baseUrl'].empty?) ? nil : @propTable['output.baseUrl']
		end
		return
	end

	def setLowPriority()
		begin
			Process.setpriority(Process::PRIO_USER, 0, 19)
		rescue
		end
		return
	end

	def run()
		##########################################################################
    # Set low priority (or at least try to....)
 		##########################################################################
		setLowPriority()
		##########################################################################
		# Assign job id and print it to stderr.
		##########################################################################
		@jobID = BRL::Util::Job.makeJobTicket()
		$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - JOB ID ASSIGNED"
		##########################################################################
		# Check the input format arg
		##########################################################################
		unless(INPUT_FMTS.member?(@inputFormat))
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - CANCELLED: Usage error -> invalid input format specified ('#{@inputFormat}')"
			return USAGE_ERR
		end
		##########################################################################
		# If the input is not in LFF, we have to run a converter on it first
		##########################################################################
		@origFile = nil
		if(@inputFormat == INPUT_FMTS[1]) # then blat
			# we want an outfile of known name:
			convertOutFile = @lffFileName + '.tmp'
			convertCode = nil
			cmdStr = "#{@blat2lff} -f #{@lffFileName} -o #{convertOutFile} ; echo \"EC: \"$? "
			cmdPipe = IO.popen(cmdStr, 'r')
			convertOut = cmdPipe.read
			cmdPipe.close
			convertCode = extractExitCode(convertOut)
			convertCode = (convertCode.nil? ? FATAL_ERR : convertCode.to_i)
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - DONE blat file conversion (exit code '#{convertCode}')"

			if(convertCode  == FATAL_ERR or convertCode == USAGE_ERR) # FUBAR!
				msgTitle = "Genboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\nFATAL ERROR: Data processing unsuccessful at conversion step, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
				puts msgTitle
				return FATAL
			elsif(convertCode == FAILED) # Too many parse errors
				$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - CANCELLED: Too many parse errors (#{MAX_NUM_ERRS}+) converting blat file. Email sent to \"#{@emailAddresses.join(',')}\"."
				subject = 'Genboree Upload: Job cancelled - too many file format errors'
				body = "\n\nGenboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\n#{convertOut}"

#				$stderr.puts "WRAPPER--> convert out size: '#{convertOut.size}'"
#				$stderr.puts "WRAPPER--> some of convert out:\n '#{convertOut[0,2048]}'"

				sendWarningEmail(subject, body)
				return FAILED
			else # OK
				@origFile = @lffFileName + '.orig'
				File.rename(@lffFileName, @origFile)
				File.rename(convertOutFile, @lffFileName)
			end
		elsif(@inputFormat == INPUT_FMTS[2]) # then blast
			# we want an outfile of known name:
			convertOutFile = @lffFileName + '.tmp'
			convertCode = nil
			cmdStr = "#{@blast2lff} -f #{@lffFileName} -o #{convertOutFile} ; echo \"EC: \"$? "
			cmdPipe = IO.popen(cmdStr, 'r')
			convertOut = cmdPipe.read
			cmdPipe.close
			convertCode = extractExitCode(convertOut)
			convertCode = (convertCode.nil? ? FATAL_ERR : convertCode.to_i)

			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - DONE blast file conversion (exit code '#{convertCode}')"

			if(convertCode  == FATAL_ERR or convertCode == USAGE_ERR) # FUBAR!
				msgTitle = "Genboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\nFATAL ERROR: Data processing unsuccessful at conversion step, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
				puts msgTitle
				return FATAL
			elsif(convertCode == FAILED) # Too many parse errors
				$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - CANCELLED: Too many parse errors (#{MAX_NUM_ERRS}+) converting blast file. Email sent to \"#{@emailAddresses.join(',')}\"."
				subject = 'Genboree Upload: Job cancelled - too many file format errors'
				body = "\n\nGenboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\n#{convertOut}"

				sendWarningEmail(subject, body)
				return FAILED
			else # OK
				@origFile = @lffFileName + '.orig'
				File.rename(@lffFileName, @origFile)
				File.rename(convertOutFile, @lffFileName)
			end
		# else then lff
		end
		##########################################################################
		# Check file size. Collect exit code and stdout.
		$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - STARTING sizeChecker on\n\t'#{@lffFileName}' "
		sizeCheckOut = `#{@sizeChecker} -f #{@lffFileName} -m #{@maxNumRecs}`
		sizeCheckCode = $?.to_i >> 8
		$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - DONE sizeChecker"
		if(sizeCheckCode == FATAL_ERR or sizeCheckCode == USAGE_ERR) # FUBAR!
			msgTitle = "Genboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\nFATAL ERROR: Data processing unsuccessful, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
			puts msgTitle
			return FATAL
		elsif(sizeCheckCode == FAIL_CODE) # TOO BIG!
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - CANCELLED: Too many annotations. Email sent to \"#{@emailAddresses.join(',')}\"."
			# Prep an email and send the error messages
		  subject = 'Genboree Upload: Job cancelled - too many annotations'
			body = "\nGenboree Upload Job ID: #{@jobID}\nSTATUS: cancelled\nREASON:\n\n#{sizeCheckOut}"
			sendWarningEmail(subject, body)
			return FAILED
		elsif(sizeCheckCode == OK_CODE) # SIZE OK!
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Size OK. STARTING Merger on\n\t'#{@lffFileName}' "
			##########################################################################
			# Merge
			mergerCode = nil
			cmdStr = "#{@merger} -p #{@params['--propFile']} -f #{@lffFileName} #{@validRefSeqFile.nil?() ? '' : ('-r ' + @validRefSeqFile)} #{@urlParam} ;  echo \"EC: \"$?"
			cmdPipe = IO.popen(cmdStr, 'r')
 			mergerOut = cmdPipe.read
 			cmdPipe.close
			mergedFile = "#{@outDir}/#{File.basename(@lffFileName)}.#{MERGE_SUFFIX}"
			mergerCode = extractExitCode(mergerOut)
			mergerCode = (mergerCode.nil? ? FATAL_ERR : mergerCode.to_i)

			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - DONE running merge program"

			##########################################################################
			# What was results of merge?
			case mergerCode
				when FATAL, USAGE_ERR  # FUBAR!
					msgTitle = "Genboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\nFATAL ERROR: Data processing unsuccessful, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
					puts msgTitle
					return FATAL
				when OK
					puts "Your annotation upload (id: #{@jobID}) was successful and encountered no problems.\n"
					$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Merge job was successful. No email sent."
					if(File.size(mergedFile) > 0)
						unless(@baseUrl.nil?) # do we need to gzip and make url?
							url = doGzip(mergedFile)
							if(url.nil?)
								puts "\nHOWEVER, we had a problem making it available to you as a URL."
								puts "Please email the Genboree admin for help (genboree_admin@bcm.tmc.edu)."
							else # gzipped ok
								puts "\nYou can download the uploaded data in LFF form at:"
								puts url + "\n\n"
								$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Url for raw data:\n#{url}"
							end
						end
					else
						puts "\nHOWEVER, none of the resulting annotations met minimum size and/or quality criteria.\n"
					end
					return OK
				when FAILED # too many parse errors
					$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - CANCELLED: Too many parse errors (#{MAX_NUM_ERRS}+). Email sent to \"#{@emailAddresses.join(',')}\"."
					subject = 'Genboree Upload: Job cancelled - too many file format errors'
					body = "\n\nGenboree Upload Job ID: #{@jobID}\n\nSTATUS: cancelled\n\nREASON:\n\n#{mergerOut}"
					sendWarningEmail(subject, body)
					return FAILED
				when OK_WITH_ERRORS # just a few errors
					puts "Annotation upload (id: #{@jobID}) was successful,\nbut some bad annotations were found (and thus ignored)."
					puts "\nYou should receive an email detailing the errors found in the bad annotations."
					$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Merge job was successful, but had some errors."
					$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Email sent to \"#{@emailAddresses.join(',')}\"."
					subject = 'Genboree Upload: Job partially successful.'
					body = "\n\nGenboree Upload Job ID: #{@jobID}\n\nSTATUS: partially successful\n\n"
					if(File.size(mergedFile) > 0)
						unless(@baseUrl.nil?) # do we need to gzip and make url?
							url = doGzip(mergedFile)
							if(url.nil?)
								body +=  "HOWEVER, we also had a problem making the uploaded file available to you as a URL.\n"
								body +=  "Please email the Genboree admin for help (genboree_admin@bcm.tmc.edu).\n"
								puts  "HOWEVER, we also had a problem making the uploaded file available to you as a URL."
								puts "Please email the Genboree admin for help (genboree_admin@bcm.tmc.edu)."
								gzipOK = false
							else # gzipped ok
								body +=  "\nYou can download the results of the partially successful upload in lff form at:\n"
								body +=  url + "\n\n"
								puts "\nYou can download the results of the partially successful upload in lff form at:"
								puts url
								puts ''
								gzipOK = true
								$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - Url for raw data:\n#{url}"
							end
						end
					end
					body += (gzipOK ? "REASON:\n\n" : "MERGING-RELATED MESSAGES & WARNINGS:\n\n")
					body += "Some uploading occurred, but some bad annotations were found (and ignored).\n\n"
					unless(File.size(mergedFile) > 0)
						body += "Furthermore, none of the resulting annotations met minimum size and/or quality criteria.\n"
						puts "\nFurthermore, none of the resulting annotations met minimum size and/or quality criteria."
					end
					body += "\nError details:\n\n#{mergerOut.strip}"
					sendWarningEmail(subject, body)
					return OK_WITH_ERRORS
				else
					raise "#{Time.now()} (id: #{@jobID}) Unexpected exit code '#{mergerCode}' returned from merger program."
			end
		else # WTF ?
			raise "#{Time.now()} (id: #{@jobID}) Problem running size-checker. Unexpected exit code '#{sizeCheckCode}' from size checker."
		end
	end

	def extractExitCode(str)
		ec = nil
		# scan for special exit code string
		str.scan(EC_RE) { |codeStr| ec = $1.to_i}
		# remove that line from the output
		str.gsub!(EC_RE, '')
		# return the code
		return ec
	end

	def doGzip(mergedFile)
		##########################################################################
		# Cp & Gzip
		gzipFile = "#{@outDir}/#{@jobID}-#{File.basename(mergedFile)}.gz"
		gzipOut = `gzip -c #{mergedFile} > #{gzipFile}`
		File.chmod(0444, gzipFile)
		gzipCode = $?.to_i >> 8
		lffZipOut = `gzip #{@lffFileName}`
		lffZipCode = $?.to_i >> 8
		if(gzipCode != 0)
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - gzip of merge output failed. The error code was '#{gzipCode}'."
			url = nil
		elsif(lffZipCode != 0)
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - gzip of input file failed. The error code was '#{lffZipCode}'."
		else # gzip worked
			# File.delete(mergedFile) # Don't remove...Java can't read the gzipped file
			unless(@baseUrl.nil?)
				url = "#{@baseUrl}/#{File.basename(gzipFile)}"
			end
		end
		unless(@origFile.nil?)
			origZipOut = `gzip #{@origFile}`
			origZipCode = $?.to_i >> 8
		end
		return url
	end

	def sendWarningEmail(subject, body)
		# Prep an email and send the error messages
		begin
      genbConfig = BRL::Genboree::GenboreeConfig.new()
      genbConfig.loadConfigFile()
			emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
			emailer.setHeaders(FROM_HDR, @emailAddresses.join(', '), subject)
			emailer.addHeader("Bcc: #{@bccAddresses.join(', ')}") unless(@bccAddresses.empty?)
			emailer.setRecipients((@emailAddresses | @bccAddresses))
			emailer.setMailFrom(FROM_HDR)
			emailer.setBody(body)
			emailer.send()
		rescue Exception => err
			$stderr.puts "#{Time.now()} (id: #{@jobID}) MERGE WRAPPER - WARNING: tried to send email, but possible error:\n\n#{err.message}\n\n#{err.backtrace}\n"
		end
		return
	end

	def LFFMergeWrapper.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[	['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--emailAddressList', '-e', GetoptLong::REQUIRED_ARGUMENT],
									['--validRefSeqFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--maxNumRecs', '-m', GetoptLong::OPTIONAL_ARGUMENT],
									['--bccAddressList', '-b', GetoptLong::OPTIONAL_ARGUMENT],
									['--output.baseUrl', '-u', GetoptLong::OPTIONAL_ARGUMENT],
									['--noMerge', '-n', GetoptLong::OPTIONAL_ARGUMENT],
									['--inputFormat', '-i', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		LFFMergeWrapper.usage() if(optsHash.empty? or optsHash.key?('--help'))
		return optsHash
	end

	def LFFMergeWrapper.usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "\nUSAGE: lffMergeWrapper.rb -p <propFile> -f <lffFile> -e <addr1,addr2,...> -b <addr1,addr2,...> -r <file.txt> -m <maxRecords> -i blat\n\n"
		exit(USAGE_ERR)
	end
end

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
	optsHash = BRL::Genboree::LFFMergeWrapper::processArguments()
	$stderr.puts "\n#{Time.now()} (id: <notYetAssigned>) MERGE WRAPPER - Pipeline STARTING"
	wrapper = BRL::Genboree::LFFMergeWrapper.new(optsHash)
	exitCode = wrapper.run()
rescue Exception => err
	errTitle = "#{Time.now()} (id: #{wrapper.nil? ? '<notYetAssigned>' : wrapper.jobID}) MERGE WRAPPER - Pipeline FATAL ERROR: Data processing unsuccessful, due to a fatal error.\n"
	msgTitle = "\n\nGenboree Upload Job ID: #{wrapper.nil? ? '<notYetAssigned>' : wrapper.jobID}\n\nSTATUS: cancelled\n\nREASON:\n\nFATAL ERROR: Data processing unsuccessful, due to a fatal error.\n\nPlease contact the Genboree admin. This error has been dated and logged.\n"
	errstr =   "    The error message was: '#{err.message}'.\n"
	errstr +=  "    The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	puts msgTitle
	$stderr.puts errTitle + errstr
	exitCode = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} (id: #{wrapper.nil? ? '<notYetAssigned>' : wrapper.jobID}) MERGE WRAPPER - Pipeline DONE"
$stderr.puts "#{Time.now()} (id: #{wrapper.nil? ? '<notYetAssigned>' : wrapper.jobID}) MERGE WRAPPER - EXIT CODE: '#{exitCode}'"
exit(exitCode)
