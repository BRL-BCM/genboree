#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/lsf/lsfBatchJob'

module BRL ; module CAPSS

class OverlapLauncher
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	OVERLAPPER_CMD = "/home/hgsc/bin/atlas-overlapper-1.70 "
	OVERLAPPER_OPTS = " -B 5 -R 2000 -H 2001 -m 8 -M 50 -S 999 -P 4 -b 0 -e 40000"
	JOB_NAME_BASE = 'clo-'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		loadFileOfFiles()
		submitOverlap()
		return
	end

	def loadArrayLayouts()
		@params['--arrayList'].each { |arrayID|
			# open layout file
			layoutFileName = "#{@params['--layoutDir']}/array.#{arrayID}.layout.txt"
			reader = BRL::Util::TextReader.new(layoutFileName)
			# skip header row
			reader.readline()
			# grab col pools row
			fields = reader.readline().split("\t")
			fields.shift ; fields.shift
			fields.map! { |aa| aa.strip }
			fields.delete_if { |aa| aa.empty? }
			@colPools[arrayID] = fields
			@rowPools[arrayID] = []
			# process row pool lines
			@arrayLayout[arrayID] = []
			reader.each { |line|
				line.strip!
				next if(line =~ /^\s*$/ or line =~ /^\s*#/)
				fields = line.split("\t")
				fields.shift
				fields.map! { |aa| aa.strip }
				@rowPools[arrayID] << fields.shift
				@arrayLayout[arrayID] << fields
			}
			reader.close()
		}
		return
	end

	def loadFileOfFiles()
		reader = BRL::Util::TextReader.new(@params['--faFof'])
		@faFofList = reader.readlines("\n")
		@faFofList.collect! { |xx| xx.strip }
		reader.close()
		return
	end

	def	submitOverlap()
		# For each array, put the 'trimming' of each project on the cluster
		$stderr.puts '-'*50
		$stderr.puts "Submitting pool 'global overlaps' to cluster:\n\n"
		topLevel = "#{@params['--outDir']}/poolProjects"
		queue = @params['--queue']
		jobCount = 0
		origDir = Dir.pwd
		dirRE = /^(.*)\/[^\/]+$/
		@faFofList.each { |fileName|
			dirName = fileName[ dirRE , 1 ]
			jobCount += 1
			Dir.chdir(dirName)
			lsfMsgDir = "./lsfMsgs"
			jobName = "#{JOB_NAME_BASE}-#{jobCount}"
			Dir.safeMkdir("#{lsfMsgDir}")
			cmdStr = "'#{OVERLAPPER_CMD} #{OVERLAPPER_OPTS} "
			cmdStr += " -s #{fileName} -o #{fileName}.graph -Q #{@params['--faFof']} > #{fileName}.overlapper.out 2> #{fileName}.overlapper.err ; gzip -f #{fileName}.graph'"
			lsf = BRL::LSF::LSFBatchJob.new(jobName)
			lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
			lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
			lsf.queueName = queue
			lsf.commandStrToRun = cmdStr
			lsf.submit()
			Dir.chdir(origDir)
			$stderr.puts lsf.bsubMsg
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--faFof', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--queue', '-q', GetoptLong::OPTIONAL_ARGUMENT],
									['--verbose', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		PROP_KEYS.each {
			|propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		optsHash['--arrayList'] = optsHash['--arrayList'].split(',')
		optsHash['--queue'] = DEFAULT_QUEUE unless(optsHash.key?('--queue'))
		@verbose = optsHash.key?('--verbose') ? true : false
		usage() unless(optsHash['--arrayList'].size > 0)
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -f     => File-of-files with locations of all the read seq files to examine.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-overlapper.rb -l /home/po4a/brl/capss/seaUrchin/06-10-2003/mapAndIndices -a 23,24 -f ./all.reads.fof
";
		exit(134);
	end
end

end ; end

launcher = BRL::CAPSS::OverlapLauncher.new()
launcher.run()
exit(0)
