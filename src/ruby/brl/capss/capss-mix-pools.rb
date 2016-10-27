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

module BRL ; module CAPSS

class PoolReadMixer
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	ROW,COL = 0,1
	# Retrieval command (base)
	JOB_NAME_BASE = 'csv-'
	SEQ_FILE = 'reads/consed.fasta.x2n.fa.screen.pass.fine.course'
	QUAL_FILE = 'reads/consed.fasta.x2n.fa.screen.pass.qual'
	OK_BAC_FILE = 'ok.bacs.fon'
	BAD_BAC_FILE = 'fail.missingPools.fon'
	OK_READS_FILE = 'ok.reads.fon'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
		@clonePools = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		loadIgnorePoolList()
		mixPoolReads()
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

	def loadIgnorePoolList()
		@ignorePoolList = {}
		return unless(@params.key?('--ignorePoolFile') and File.exists?(@params['--ignorePoolFile']))
		reader = BRL::Util::TextReader.new("#{@params['--ignorePoolFile']}")
		reader.each { |line|
			line.strip!
			next if(line =~ /^\s*$/ or line =~ /^\s*#/)
			@ignorePoolList[line] = ''
		}
		reader.close()
		return
	end

	def	mixPoolReads()
		queue = @params['--queue']
		jobCount = 0
		okBacWriter = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{OK_BAC_FILE}")
		failBacWriter = BRL::Util::TextWriter.new("#{@params['--outDir']}/#{BAD_BAC_FILE}")
		@clonePools.each { |cloneID, arrays|	# For each clone in the array
			$stderr.puts "Mixing Clone: '#{cloneID}'"
			pools = []
			fileMissing = false
			@clonePools[cloneID].each { |arrayID, poolList|
				pools << poolList[ROW]
				pools << poolList[COL]
				poolList.each { |pool|
					seqFile = "#{@params['--readSrcDir']}/array.#{arrayID}/#{pool}/#{SEQ_FILE}"
					qualFile = "#{@params['--readSrcDir']}/array.#{arrayID}/#{pool}/#{QUAL_FILE}"
					unless(File.exists?(seqFile) and File.exists?(qualFile))
						$stderr.puts "\tWARNING: either '#{seqFile}' or '#{qualFile}' are missing"
						fileMissing = true
						break
					end
				}
			}
			# Skip it if one of its pools is in the ignore list
			anyIgnorePools = false
			pools.collect { |pool| anyIgnorePools = true if(@ignorePoolList.key?(pool)) }
			# Make a destination dir for it
			cmd = "mkdir -p #{@params['--outDir']}/#{cloneID}"
			`cmd`
			# Touch a pools ID file
			cmd = "touch #{@params['--outDir']}/#{cloneID}/#{pools.join('-')}"
			`cmd`
			# If all the seq and qual files exist for the bac, mix and write bac name to success fon
			if(fileMissing) # write bac name to failure fon
				failBacWriter.puts cloneID
			else # go ahead and mix
				seqCmd = qualCmd = "cat "
				poolList.collect { |pool|
					seqCmd += "#{@params['--readSrcDir']}/array.#{arrayID}/#{pool}/#{SEQ_FILE} "
					qualCmd += "#{params['--readSrcDir']}/array.#{arrayID}/#{pool}/#{QUAL_FILE} "
				}
				seqCmd += " > #{@params['--outDir']}/#{cloneID}/mix.reads.fa.screen.pass"
				qualCmd += " > #{@params['--outDir']}/#{cloneID}/mix.reads.fa.screen.pass.qual"
				# `#{seqCmd} ; #{qualCmd}`
				jobCount += 1
				lsfMsgDir = "#{@params['--outDir']}/#{cloneID}/lsfMsgs"
				Dir.safeMkdir("#{lsfMsgDir}")
				jobName = "#{JOB_NAME_BASE}-#{jobCount}"
				cmdStr = "'#{seqCmd} ; #{qualCmd}'"
				lsf = BRL::LSF::LSFBatchJob.new(jobName)
				lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
				lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
				lsf.queueName = queue
				lsf.commandStrToRun = cmdStr
				lsf.submit()
				$stderr.puts lsf.bsubMsg
				okBacWriter.puts cloneID
			end
			exit(0)
		}
		okBacWriter.close()
		failBacWriter.close()
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--outDir', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--arrayList', '-a', GetoptLong::REQUIRED_ARGUMENT],
									['--layoutDir', '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--readSrcDir', '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--queue', '-q', GetoptLong::OPTIONAL_ARGUMENT],
									['--ignorePoolFile', '-i', GetoptLong::OPTIONAL_ARGUMENT],
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
    -o     => Top-level output dir where to put mix project reads
    -a     => Comma separated list of array numbers to get from database
    -l     => Dir where the array layout files (from capss-get-arrayLayouts) can be found.
    -s     => Src dir where the pool project dirs containing the pool reads for each array can be found.
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    -v     => [optional flag] Verbose output on stderr.
    -h     => [optional flag] Output this usage info and exit
  USAGE:
    capss-mix-pools.rb -o ./poolMix/arrays_17+19_minus_some_pools -l ./mapsAndIndices -a 23,24 -s ./poolProjects

";
		exit(134);
	end
end

end ; end

mixer = BRL::CAPSS::PoolReadMixer.new()
mixer.run()
exit(0)
