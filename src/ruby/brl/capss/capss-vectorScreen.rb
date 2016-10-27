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

class PoolReadVectorScreener
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'csv-'
	READ_FILE = 'consed.fasta.x2n.fa.screen'
	COURSE_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-coarse.fa"
	FINE_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-fine.fa"
	ATLAS_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-atlas.fa"
	FINE_SCREEN_OPTS = "-minmatch 12 -penalty -2 -minscore 20 -screen "
	COURSE_SCREEN_OPTS = "-minmatch 20 -penalty -2 -minscore 30 -screen -bandwidth 8"
	CROSS_MATCH = "/home/hgsc/bin/cross_match-19990329.manyreads "

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		screenVector()
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

	def	screenVector()
		# For each array, put the 'trimming' of each project on the cluster
		$stderr.puts '-'*50
		$stderr.puts "Submitting pool 'screenings' to cluster:\n\n"
		topLevel = "#{@params['--outDir']}/poolProjects"
		queue = @params['--queue']
		jobCount = 0
		@arrayLayout.each { |arrayID, rowArrays|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				jobCount += 1
				projDir = "#{topLevel}/array.#{arrayID}/#{poolID}"
				readsDir = "#{projDir}/reads"
				origDir = Dir.pwd
				Dir.chdir(readsDir)
				lsfMsgDir = "../lsfMsgs"
				jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
				Dir.safeMkdir("#{lsfMsgDir}")
				cmdStr = "'#{CROSS_MATCH} #{@readFileName} #{FINE_SCREEN_FILE} #{FINE_SCREEN_OPTS} \>fine.screen.out 2\>fine.screen.err ; mv -f #{@readFileName}.screen #{@readFileName}.fine ; #{CROSS_MATCH} #{@readFileName}.fine #{COURSE_SCREEN_FILE} #{COURSE_SCREEN_OPTS} \> course.screen.out 2\> course.screen.err ; mv -f #{@readFileName}.fine.screen #{@readFileName}.fine.course ; ln -s ./#{@readFileName}.qual ./#{@readFileName}.fine.screen.qual'"
				lsf = BRL::LSF::LSFBatchJob.new(jobName)
				lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
				lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
				lsf.queueName = queue
				lsf.commandStrToRun = cmdStr
				lsf.submit()
				Dir.chdir(origDir)
				$stderr.puts lsf.bsubMsg
			}
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--readFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
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
		@readFileName = optsHash.key?('--readFile') ? optsHash['--readFile'] : READ_FILE
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
    -o     => Top-level output dir where to put project dir-trees for each array
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -r     => [optional] Read file name to process for each pool of each array (consed.fasta.x2n.fa.screen)
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-get-poolReads.rb -o ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

trimmer = BRL::CAPSS::PoolReadVectorScreener.new()
trimmer.run()
exit(0)
