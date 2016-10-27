#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'json'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


module BRL

class RestUtils
	DEBUG=false
	def RestUtils.getUserPassword(user)
		genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()

		# Load Genboree config file:
		genbConf = BRL::Genboree::GenboreeConfig.load()
		# Create DBUtil instance using dbrcFile mentioned in config
		# . note: process owner must be able to read this file
		# . for dev testing your can set your GENB_CONFIG env variable
		#   (in bash) to some alternative file that points to a .dbrc
		#   file you -can- read and that has appropriate records
		dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, genbConf.dbrcFile)
		# Get the genboreeuser record(s) (DBUtil methods are -supposed- to
		# return arrays of records uniformly, even methods that ought to return
		# a single record will be in a 1-row array. This is what the database
		# driver returns and the idea is not to muck with it. There are few
		# [old] methods that don't follow this policy but they are rare.
		userRecs = dbu.getUserByName(user)
		# Get the password (you have the full table record, can access by column
		# name for robustness and readable code):
		userRec = userRecs.first
		pw = userRec['password']
		return pw
	end

	def RestUtils.uploadLff(user, group, database, lffFile)
		genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()
		dbHost = genboreeConfig.dbHost
		userName=user
		gbPassword 	= RestUtils.getUserPassword(user)

		#
		##httpResp = apiCaller3.put(payload,  {:grp => 'coarfa_group', :db => 'testDB1'} )
		r = BRL::Util::TextReader.new(lffFile)
		done = false
		lffFileSize = File.size(lffFile)
		maxChunkSize = 10*1024*1024
		#maxChunkSize = 23
		if (lffFileSize % maxChunkSize ==0) then
		  numChunks = lffFileSize/maxChunkSize
		else
			numChunks = lffFileSize/maxChunkSize+1
		end
		buffer = ""

		1.upto(numChunks) {|i|
			if (buffer=="") then
				buffer = r.read(maxChunkSize)
			else
				rbuffer = r.read(maxChunkSize)
				buffer << rbuffer
			end
			tmpBuffer=""
			newLineFound = false
			$stderr.puts "new buffer >>#{buffer}<<" if (DEBUG)
			(buffer.size-1).downto(0) {|i|
				$stderr.puts "[#{i} out of #{buffer.size-1}] cmp #{buffer[i]} #{buffer[i,1]} vs #{?\n}" if (DEBUG)
				if (buffer[i]==?\n) then
					$stderr.puts "passed" if (DEBUG)
					if (i<buffer.size-1) then
						tmpBuffer = buffer[i+1,buffer.size-1-i]
						(i+1).upto(buffer.size-1) {|j|
							buffer[j]=?\n
						}
					else
						tmpBuffer = ""
					end
					newLineFound = true
					break
				end
			}
			if (newLineFound) then
				# put
						apiCaller3 = ApiCaller.new(
									 dbHost,
									 "/REST/v1/grp/{grp}/db/{db}/annos")
				# Must set the login info, since not provided yet:
		    sleep (2)
		    apiCaller3.setLoginInfo(userName, gbPassword)

				httpResp = apiCaller3.put(buffer,  {:grp => group, :db => database} )
				$stderr.print "attempted to put partial buffer
				#{buffer}
				of size #{buffer.size} and keeping tempBuffer
				#{tmpBuffer}
				of size #{tmpBuffer.size}" if (DEBUG)
				b=apiCaller3.parseRespBody()
				$stderr.puts "response body "
				b.keys.each {|k|
					$stderr.puts "#{k} ---  #{b[k]}"
				}
				buffer = tmpBuffer
			else
				$stderr.puts "one line/short buffer >>#{buffer}<< keep for cleanup" if (DEBUG)
				# keep the whole buffer for next step
			end
		}
		if (buffer != "") then

				$stderr.print "clean up last buffer
				#{buffer}
				of size #{buffer.size}" if (DEBUG)

				# put last line w/o a newline terminator
				# put
				httpResp = apiCaller3.put(buffer,  {:grp => group, :db => database} )
				b=apiCaller3.parseRespBody()
				$stderr.puts "response body "
				$stderr.puts "#{b.class} testDB1 uploaded #{apiCaller3.apiDataObj.size} ???"
				b.keys.each {|k|
					$stderr.puts "#{k} ---  #{b[k]}"
				}
				buffer = tmpBuffer
			else
				# keep the whole buffer for next step
			end
		end
	end
end

class RestLffUpload
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@lffFile = @optsHash['--lffFile']
		@group = @optsHash['--group']
		@database = @optsHash['--database']
		@user = @optsHash['--user']
  end

  def work()
		BRL::RestUtils.uploadLff(@user, @group, @database, @lffFile)
  end

  def RestLffUpload.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--lffFile',   '-l', GetoptLong::REQUIRED_ARGUMENT],
				          ['--group',     '-g', GetoptLong::OPTIONAL_ARGUMENT],
									['--database',  '-d', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--user',      '-u', GetoptLong::OPTIONAL_ARGUMENT],
								  ['--help',      '-h', GetoptLong::NO_ARGUMENT]
								]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		RestLffUpload.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			RestLffUpload.usage("USAGE ERROR: some required arguments are missing")
		end

		RestLffUpload.usage() if(optsHash.empty?);
		return optsHash
	end

	def RestLffUpload.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Staged uploading of lff files to Genboree via the REST API.

COMMAND LINE ARGUMENTS:
  --lffFile        | -l   => lff file
  --group          | -o   => group
  --database       | -d   => database
  --user           | -u   => user
  --help           | -h   => [optional flag] Output this usage info and exit

USAGE:
  rubyScript.rb  -r requiredArg -o optionalArg
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = RestLffUpload.processArguments()
# Instantiate analyzer using the program arguments
RestLffUpload = RestLffUpload.new(optsHash)
# Analyze this !
RestLffUpload.work()
exit(0);
