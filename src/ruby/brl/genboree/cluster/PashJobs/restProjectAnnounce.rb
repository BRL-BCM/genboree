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

	def RestUtils.projectAnnounce(user, group, project, samFile)
		genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()
		dbHost = genboreeConfig.dbHost
		userName=user
		gbPassword 	= RestUtils.getUserPassword(user)

		#
		##httpResp = apiCaller3.put(payload,  {:grp => 'coarfa_group', :db => 'testDB1'} )

		apiCaller3 = ApiCaller.new(
							 dbHost,
							 "/REST/v1/grp/{grp}/prj/{prj}/news")
		# Must set the login info, since not provided yet:
		sleep (2)
		apiCaller3.setLoginInfo(userName, gbPassword)

		hh = apiCaller3.get( {:grp => group, :prj => project} )
		nn = apiCaller3.parseRespBody()
		t = Time.now
		dateNow = "#{t.year}/#{t.month}/#{t.day}"
		nn['data'] << { "date"=>"#{dateNow}",
			"updateText"=>"Mapping finished<br><a href=\"#{File.basename(samFile)}\"> SAM file #{File.basename(samFile)} </a><br><a href=\"#\">Level 1 XML file<br><a href=\"#\">Read mapping statistics</a>" }
		$stderr.puts "Putting #{nn}"
		sleep (2)
		apiCaller4 = ApiCaller.new(
							 dbHost,
							 "/REST/v1/grp/{grp}/prj/{prj}/news")
		# Must set the login info, since not provided yet:
		sleep (2)
		apiCaller4.setLoginInfo(userName, gbPassword)
		apiCaller4.put(nn.to_json,  {:grp => group, :prj => project})
		b=apiCaller4.parseRespBody()
		$stderr.puts "response body "
		b.keys.each {|k|
			$stderr.puts "#{k} ---  #{b[k]}"
		}
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
		@samFile = @optsHash['--samFile']
		@group = @optsHash['--group']
		@database = @optsHash['--database']
		@user = @optsHash['--user']
		@project = @optsHash['--project']
  end

  def work()
		BRL::RestUtils.projectAnnounce(@user, @group, @project, @samFile)
  end

  def RestLffUpload.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--samFile',   '-s', GetoptLong::REQUIRED_ARGUMENT],
				          ['--group',     '-g', GetoptLong::REQUIRED_ARGUMENT],
									['--database',  '-d', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--user',      '-u', GetoptLong::REQUIRED_ARGUMENT],
                  ['--project',   '-P', GetoptLong::REQUIRED_ARGUMENT],
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
  Genboree project update via the REST API.

COMMAND LINE ARGUMENTS:
  --samFile        | -s   => SAM file
  --group          | -o   => group
  --database       | -d   => database
  --project        | -P   => project
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
