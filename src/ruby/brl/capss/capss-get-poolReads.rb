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

class PoolReadRetriever
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	PREP_READS_CMD = '/home/hgsc/share/bin/hgsc-wrap-assembly -p '
	JOB_NAME_BASE = 'cgpr'


	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		createOutputDirs()
		scheduleRetrievals()
		feedback()
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

	def	createOutputDirs()
		topLevel = "#{@params['--outDir']}/poolProjects"
		Dir.recursiveSafeMkdir(topLevel)
		@arrayLayout.each { |arrayID, rowArrays|
			arrayDir = "#{topLevel}/array.#{arrayID}"
			Dir.recursiveSafeMkdir(arrayDir)
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID| Dir.recursiveSafeMkdir("#{arrayDir}/#{poolID}") }
		}
		return
	end

	def	scheduleRetrievals()
		# For each array, put the 'assembly' of each project on the cluster
		$stderr.puts '-'*50
		$stderr.puts "Submitting pool 'assemblies' to cluster:\n\n"
		topLevel = "#{@params['--outDir']}/poolProjects"
		queue = @params['--queue']
		jobCount = 0
		@arrayLayout.each { |arrayID, rowArrays|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				jobCount += 1
				projDir = "#{topLevel}/array.#{arrayID}/#{poolID}"
				origDir = Dir.pwd
				Dir.chdir(projDir)
				lsfMsgDir = "./lsfMsgs"
				jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
				Dir.safeMkdir("#{lsfMsgDir}")
				cmdStr = "#{PREP_READS_CMD} #{poolID}"
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

	def	feedback()
		puts '-'*50
		puts "The pool projects for arrays #{@arrayLayout.keys.sort.join(',')} are being populated with reads."
		puts "Some vector screening and such will also be done. This is done through an inefficient means: via 'assembly'."
		puts "The assembly will produce some other files which may be of interest to you, including identification of "
		puts "low qual reads and such."
		puts "The assemblies are done when all the jobs matching the pattern '#{JOB_NAME_BASE}-*' are done."
		puts "'(bjobs | grep #{JOB_NAME_BASE}' to monitor)"
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
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
    -o     => Top-level output dir where to put project dir-trees for each array
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
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

retriever = BRL::CAPSS::PoolReadRetriever.new()
retriever.run()
exit(0)

