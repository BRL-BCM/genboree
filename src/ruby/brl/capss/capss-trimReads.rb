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

class PoolReadTrimmer
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	VECTOR50 = '/home/grok2/seqbank/screen/screen-atlas.fa'
	# TRIM_READS_CMD = "/home/hgsc/bin/atlas-window-1.7 -p 20 -l 50 -w 50 -e 1.25 -x +s +t +f +q "
	#TRIM_READS_CMD = "/home/hgsc/bin/atlas-window-1.7 -p 20 -l 100 -w 50 -x +s -t +f +q " # rat 10x10 thing
	JOB_NAME_BASE = 'ct-'
	READ_FILE = './reads/consed.fasta.x2n.fa.screen.fine.course'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		trimReads()
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

	def	trimReads()
		# For each array, put the 'trimming' of each project on the cluster
		$stderr.puts '-'*50
		$stderr.puts "Submitting pool 'trimmings' to cluster:\n\n"
		topLevel = "#{@params['--topDir']}/poolProjects"
		queue = @params['--queue']
		jobCount = 0
		origDir = Dir.pwd
		@arrayLayout.each { |arrayID, rowArrays|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				jobCount += 1
				projDir = "#{topLevel}/array.#{arrayID}/#{poolID}"
				Dir.chdir(projDir)
				lsfMsgDir = "./lsfMsgs"
				jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
				Dir.safeMkdir("#{lsfMsgDir}")
				unless(File.exists?(@readFileName))
					$stderr.puts "NOTE: need to gunzip your fasta/qual files, hang on..."
					`gunzip #{@readFileName}.gz`
					`gunzip #{@readFileName}.qual.gz`
				end
				cmdStr = "#{TRIM_READS_CMD} #{@readFileName}"
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
									['--topDir', '-t', GetoptLong::REQUIRED_ARGUMENT],
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
    -o     => Top-level dir where project is located. Source and Output dirs will be relative to this.
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -r     => [optional] Read file nameof each pool of each array to process. Relative to pool's project dir. There must be a .qual file of the same name. (reads/consed.fasta.x2n.fa.screen.fine.course)
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-trimReads.rb -o /home/po4a/brl/capss/seaUrchin/06-10-2003 -l /home/po4a/brl/capss/seaUrchin/06-10-2003/mapAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

trimmer = BRL::CAPSS::PoolReadTrimmer.new()
trimmer.run()
exit(0)
