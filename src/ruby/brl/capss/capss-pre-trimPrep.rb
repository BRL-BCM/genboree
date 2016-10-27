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

class PreTrimPrep
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	JOB_NAME_BASE = 'cptp-'
	DEFAULT_QUEUE = 'linux'
	X2N_READS_CMD = '/users/hgsc/andrewj/brl/bin/XtoNconverter.pl -f '
	GZ_CMD = 'gzip ./consed/edit_dir/*'

	def initialize()
		@colPools = {}
		@rowPools = {}
		@arrayLayout = {}
	end

	def run()
		@params = processArguments()
		loadArrayLayouts()
		prepPoolProj()
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

	def	prepPoolProj()
		topLevel = "#{@params['--outDir']}/poolProjects"
#		fa_fof = BRL::Util::TextWriter.new("#{topLevel}/reads.x2n.fa.fof", 'w+', false)
#		qual_fof = BRL::Util::TextWriter.new("#{topLevel}/reads.x2n.fa.qual.fof", 'w+', false)
#		x2n_fof = BRL::Util::TextWriter.new("#{topLevel}/reads.x2n.fof", 'w+', false)
		queue = @params['--queue']
		Dir.recursiveSafeMkdir(topLevel)
		origDir = Dir.pwd()
		jobCount = 0
		@arrayLayout.each { |arrayID, table|
			arrayDir = "#{topLevel}/array.#{arrayID}"
			Dir.recursiveSafeMkdir(arrayDir)
			(@rowPools[arrayID] | @colPools[arrayID]).each {
				|poolID|
				if(poolID.nil? or poolID.empty?)
					raise "ERROR: found a poolID that is nil or empty (#{poolID.inspect}) in array #{arrayID} [ jobCount: #{jobCount} ]"
				end
				poolDir = "#{arrayDir}/#{poolID}"
				# Create reads dir
				readsDir = "#{poolDir}/reads"
				editDir = "#{poolDir}/consed/edit_dir"
				readsFastaFile = "#{poolDir}/consed/edit_dir/consed.fasta.screen"
				Dir.recursiveSafeMkdir(readsDir)
				Dir.chdir(editDir)
				if(File.exists?(readsFastaFile))
					jobCount += 1
					projDir = "#{arrayDir}/#{poolID}"
					origDir = Dir.pwd
					Dir.chdir(projDir)
					lsfMsgDir = "./lsfMsgs"
					jobName = "#{JOB_NAME_BASE}-#{arrayID}-#{jobCount}"
					Dir.safeMkdir("#{lsfMsgDir}")
					cmdStr = "\"#{X2N_READS_CMD} #{readsFastaFile} ; mv -f #{readsFastaFile}.X2N #{readsDir}/consed.fasta.x2n.fa.screen ; cp -f #{readsFastaFile}.qual #{readsDir}/consed.fasta.x2n.fa.screen.qual ; #{GZ_CMD}\""
					lsf = BRL::LSF::LSFBatchJob.new(jobName)
					lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
					lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
					lsf.queueName = queue
					lsf.commandStrToRun = cmdStr
					lsf.submit()
					Dir.chdir(origDir)
					# Write to x2n.fa.fof, x2n.fa.qual.fof, x2n.fof files for this array
					fa_fof.puts "#{readsDir}/consed.fasta.x2n.fa.screen"
					qual_fof.puts "#{readsDir}/consed.fasta.x2n.fa.screen.qual"
					x2n_fof.puts "#{readsDir}/consed.fasta.x2n.fa.screen\n#{readsDir}/consed.fasta.x2n.fa.screen.qual"
				end
			}
		}
		fa_fof.close()
		qual_fof.close()
		x2n_fof.close()
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
    capss-pre-trimPreps.rb -o ./poolReads -l ./mapsAndIndices -a 23,24
";
		exit(134);
	end
end

end ; end

prepper = BRL::CAPSS::PreTrimPrep.new()
prepper.run()
exit(0)

un()
exit(0)

