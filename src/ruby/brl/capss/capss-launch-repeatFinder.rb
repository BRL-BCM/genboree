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

class RepeatFinder
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'clrf-'
	REGULAR_REPEAT = 20
	REPEAT_FINDER = '/users/hgsc/andrewj/work/brl/src/ruby/brl/capss/capss-repeatFinding-fromOverlaps.rb '
	OUT_DIR = 'reads'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		findRepeats()
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

	def	findRepeats()
		graphFile = @params['--graphFile']
		# For each array, put the 'trimming' of each project on the cluster
		$stderr.puts '-'*50
		$stderr.puts "Submitting pool 'screenings' to cluster:\n\n"
		topLevel = "#{@params['--topDir']}/poolProjects"
		queue = @params['--queue']
		jobCount = 0
		origDir = Dir.pwd
		@arrayLayout.each { |arrayID, rowArrays|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				jobCount += 1
				projDir = "#{topLevel}/array.#{arrayID}/#{poolID}"
				outDir = "#{projDir}/#{@outDir}"
				next unless(File.exists?(graphFile))
				Dir.chdir(outDir)
				lsfMsgDir = "../lsfMsgs"
				jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
				Dir.safeMkdir(lsfMsgDir)
				cmdStr = "'#{REPEAT_FINDER} -p ^#{poolID} -r #{@regRepeat} -o #{outDir} -f #{graphFile} \> #{outDir}/repeatFinder.out 2\> #{outDir}/repeatFinder.err'"
				lsf = BRL::LSF::LSFBatchJob.new(jobName)
				lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
				lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
				File.delete(lsf.errorFile) if(File.exists?(lsf.errorFile))
				File.delete(lsf.outputFile) if(File.exists?(lsf.outputFile))
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
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--outDir', '-o', GetoptLong::OPTIONAL_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--graphFile', '-g', GetoptLong::REQUIRED_ARGUMENT],
									['--regularRepeat', '-r', GetoptLong::OPTIONAL_ARGUMENT],
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
		@outDir = optsHash.key?('--outDir') ? optsHash['--outDir'] : OUT_DIR
		@regRepeat = optsHash.key?('--regularRepeat') ? optsHash['--regularRepeat'].to_i : REGULAR_REPEAT
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
    -t     => Top-level output dir where to put project dir-trees for each array
    -o     => [optional, 'reads'] Where to put various repeat list files, pruned graph files, etc, under the project dir tree.
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -g     => Graph file of *all* overlaps, to process for each pool of each array.
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-repeatFinder.rb -t ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

finder = BRL::CAPSS::RepeatFinder.new()
finder.run()
exit(0)
