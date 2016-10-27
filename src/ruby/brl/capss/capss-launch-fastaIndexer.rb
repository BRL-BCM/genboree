#!/usr/bin/env ruby

=begin
=end
# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' 		# for PropTable class
require 'brl/lsf/lsfBatchJob'
require 'brl/dna/fastaRecord'

module BRL ; module CAPSS

class IndexLauncher
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	ROW,COL = 0,1
	# Retrieval command (base)
	JOB_NAME_BASE = 'clfi-'
	SEQ_FILE = 'reads/consed.fasta.x2n.fa.screen.fine.course'
	QUAL_FILE = 'reads/consed.fasta.x2n.fa.screen.fine.course.qual'
	INDEXER = File.expand_path('~/work/brl/src/ruby/brl/capss/capss-fastaIndexer.rb ')
	QUEUE = 'linux'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@clonePools = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		indexFastaFiles()
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
				rowPool = fields.shift
				@rowPools[arrayID] << rowPool
				@arrayLayout[arrayID] << fields

			}
			reader.close()
		}
		# fill clone pool info
		@arrayLayout.each { |arrayID, arrayLayout|
			@rowPools[arrayID].size.times { |ii|
				rowPool = @rowPools[arrayID][ii]
				@colPools[arrayID].size.times { |jj|
					colPool = @colPools[arrayID][jj]
					cloneID = arrayLayout[ii][jj]
					@clonePools[cloneID] = {} unless(@clonePools.key?(cloneID))
					@clonePools[cloneID][arrayID] = [] unless(@clonePools[cloneID].key?(arrayID))
					@clonePools[cloneID][arrayID][ROW] = rowPool
					@clonePools[cloneID][arrayID][COL] = colPool
				}
			}
		}
		return
	end

	def	indexFastaFiles()
		topDir = @params['--topDir'] + '/poolProjects'
		origDir = Dir.pwd()
		jobCount = 0
		@rowPools.keys.each { |arrayID|
			(@rowPools[arrayID] | @colPools[arrayID]).each { |poolID|
				poolDir = "#{topDir}/array.#{arrayID}/#{poolID}"
				seqFileName = "#{poolDir}/#{SEQ_FILE}"
				qualFileName = "#{poolDir}/#{QUAL_FILE}"
				jobCount += 1
				Dir.chdir(poolDir)
				lsfMsgDir = "./lsfMsgs"
				jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
				Dir.safeMkdir("#{lsfMsgDir}")
				cmdStr = "#{INDEXER} -q #{qualFileName} -s #{seqFileName} "
				lsf = BRL::LSF::LSFBatchJob.new(jobName)
				lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
				lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
				File.delete(lsf.errorFile) if(File.exists?(lsf.errorFile))
				File.delete(lsf.outputFile) if(File.exists?(lsf.outputFile))
				lsf.queueName = @queue
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
		@queue = optsHash.key?('--queue') ? optsHash['--queue'] : QUEUE
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
    -t     => Top-level output dir where to put mix project reads
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-launch-fastaIndexer.rb -t . -l ./mapsAndIndices -a 23,24

";
		exit(134);
	end
end

end ; end

launcher = BRL::CAPSS::IndexLauncher.new()
launcher.run()
exit(0)
