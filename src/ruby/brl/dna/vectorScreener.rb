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

module BRL ; module DNA

class VectorScreener
	# CONSTANTS
	PROP_KEYS =	%w{
								}
	DEFAULT_QUEUE = 'linux'
	# Retrieval command (base)
	JOB_NAME_BASE = 'vs'
	COURSE_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-coarse.fa"
	FINE_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-fine.fa"
	# ATLAS_SCREEN_FILE = "/home/grok2/seqbank/screen/screen-atlas.fa"
	FINE_SCREEN_OPTS = "-minmatch 12 -penalty -2 -minscore 20 -screen "
	COURSE_SCREEN_OPTS = "-minmatch 20 -penalty -2 -minscore 30 -screen -bandwidth 8"
	CROSS_MATCH = "/home/hgsc/bin/cross_match-19990329.manyreads "
	BLANK_RE = /^\s*$/
	COMMENT_RE = /^\s*#/
	NO_QUEUE_RE = /^NONE$/
	
	def initialize()
		@fastaFiles = []
	end

	def run()
		@params = processArguments()
		# Suck in fof
		loadFof()
		# Prep lsfoutput dir
		@lsfMsgDir = './lsfMsgs'
		Dir.safeMkdir(@lsfMsgDir)
		# Submit screens
		screenVector()
		return
	end

	def loadFof()
		reader = BRL::Util::TextReader.new(@fileOfFiles)
		reader.each { |line|
			line.strip!
			next if(line =~ BLANK_RE or line =~ COMMENT_RE)
			@fastaFiles << line
		}
		reader.close
		return
	end

	def	screenVector()
		# Screen each file
		$stderr.puts '-'*50
		$stderr.puts "Submitting fasta 'screenings' to cluster:\n\n"
		jobCount = 0
		origDir = Dir.pwd
		@fastaFiles.each { |fullFile|
		$stderr.puts fullFile
			next unless(File.exists?(fullFile))
			jobCount += 1
			workDir = File.dirname(fullFile)
		$stderr.puts workDir
			file = File.basename(fullFile)
			Dir.chdir(workDir)
			jobName = "#{JOB_NAME_BASE}-#{jobCount}"
			cmdStr =	"#{CROSS_MATCH} #{file} #{FINE_SCREEN_FILE} #{FINE_SCREEN_OPTS} \>fine.screen.out 2\>fine.screen.err ; " +
								"mv -f #{file}.screen #{file}.fine ; " +
								"#{CROSS_MATCH} #{file}.fine #{COURSE_SCREEN_FILE} #{COURSE_SCREEN_OPTS} \> course.screen.out 2\> course.screen.err ; " +
								"mv -f #{file}.fine.screen #{file}.fine.course ; "
			if(@linkQual and File.exists?("#{file}.qual"))
				cmdStr += "ln -s ./#{file}.qual ./#{file}.fine.screen.qual"
			end
			if(@gzipSrc)
				cmdStr += "gzip #{file} ; gzip #{file}.fine "
			end
			unless(@queue.nil?)
				cmdStr += "'"
				cmdStr = "'" + cmdStr
				lsf = BRL::LSF::LSFBatchJob.new(jobName)
				lsf.errorFile = "#{@lsfMsgDir}/#{jobName}.err"
				lsf.outputFile = "#{@lsfMsgDir}/#{jobName}.out"
				lsf.queueName = @queue
				lsf.commandStrToRun = cmdStr
				lsf.submit()
				Dir.chdir(origDir)
				$stderr.puts lsf.bsubMsg
			else # run locally
				`#{cmdStr}`
			end
		}
		return
	end

	def processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
									['--fileOfFiles', '-f', GetoptLong::REQUIRED_ARGUMENT],
									['--queue', '-q', GetoptLong::OPTIONAL_ARGUMENT],
									['--gzipSrc', '-z', GetoptLong::OPTIONAL_ARGUMENT],
									['--linkQual', '-l', GetoptLong::OPTIONAL_ARGUMENT],
									['--vectorFile', '-v', GetoptLong::OPTIONAL_ARGUMENT],
									['--contaminationFile', '-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--fineScreenParamStr', GetoptLong::OPTIONAL_ARGUMENT],
									['--courseScreenParamStr', GetoptLong::OPTIONAL_ARGUMENT],
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
		@fileOfFiles = optsHash['--fileOfFiles']
		@queue = optsHash.key?('--queue') ? optsHash['--queue'] : DEFAULT_QUEUE
		@queue.strip!
		if(@queue =~ NO_QUEUE_RE or @queue =~ BLANK_RE) 
			@queue = nil
		end
		@gzipSrc = optsHash.key?('--gzipSrc') ? true : false
		@linkQual = optsHash.key?('--linkQual') ? true : false
		@vectorFile = optsHash.key?('--vectorFile') ? optsHash['--vectorFile'] : FINE_SCREEN_FILE
		@contamFile = optsHash.key?('--contaminationFile') ? optsHash['--contaminationFile'] : COURSE_SCREEN_FILE
		@fineScreenParamStr = optsHash.key?('--fineScreenParamStr') ? optsHash['--fineScreenParamStr'] : FINE_SCREEN_OPTS
		@courseScreenParamStr = optsHash.key?('--courseScreenParamStr') ? optsHash['--courseScreenParamStr'] : COURSE_SCREEN_FILE
		return optsHash
	end

	def usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "

PROGRAM DESCRIPTION:

	Does a fine and course screen on the files listed in the .fof file provided.
	Output file is saved with .fine.course.fa extension.

  COMMAND LINE ARGUMENTS:
    -f     => File-of-files containing the name of each fasta file you want to screen.
    -q     => [optional] LSF cluster to use. Default is 'linux'.
    					- Use 'short' for small input files.
    					- Use 'NONE' keyword to not use the queue.
    -z     => [optional flag] Do you want the source file zipped? Default is no.
    -l     => [optional flag] If a .qual exists for your file, do you want a softlink to it?
               Defualt is no.
    -v     => [optional] Name of vector screen file (fine screen). A default is provided.
    -c     => [optional] Name of a contamination screen file (course screen).
              A default is provided.
    -h     => [optional flag] Output this usage info and exit

    Advanced:
    --fineScreenParamStr    => Override '#{FINE_SCREEN_OPTS}'
                               as the vector screen cross-match options.
    --courseScreenParamStr  => Override '#{COURSE_SCREEN_OPTS}'
                               as the contamination cross-match options.

  USAGE:
    vectorScreen.rb -f myFastaList.fof -z -l

";
		exit(134);
	end
end

end ; end

screener = BRL::DNA::VectorScreener.new()
screener.run()
exit(0)
