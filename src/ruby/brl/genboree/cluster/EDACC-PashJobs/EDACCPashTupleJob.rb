#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/cluster/ruby/TupleSpaceJob'
require 'brl/genboree/cluster/Pash3.0Jobs/generatePash3.0Commands'


class PashTupleJob
  DEBUG = false 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
    @sequenceFile = @optsHash['--sequenceFile']
    @genomeName = @optsHash['--genomeName']
    @dataType = @optsHash['--dataType']
    @outputFile = @optsHash['--outputFile']
    @outputDirectory = File.dirname(@outputFile) 
    @outputHost = @optsHash['--outputHost']
    @pashTwoLffArgs = ""
    if (@optsHash.key?('--class')) then
			@pashTwoLffArgs << " -c #{@optsHash['--class']}"
    else
			@pashTwoLffArgs << " -c Pash"
    end
    if (@optsHash.key?('--type')) then
			@pashTwoLffArgs << " -t #{@optsHash['--type']}"
    else
			@pashTwoLffArgs << " -t Pash"
    end
    if (@optsHash.key?('--subtype')) then
			@pashTwoLffArgs << " -s #{@optsHash['--subtype']}"
    else
			@pashTwoLffArgs << " -s Hit"
    end
  end

  def work()
		genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()
    @machineName = genboreeConfig.machineName
    pashCommandsGenerator = BRL::Genboree::Pash::Pash3CommandGenerator.new()
    pashCommandsGenerator.sequenceFile = @sequenceFile
    pashCommandsGenerator.genomeName = @genomeName
    pashCommandsGenerator.dataType = @dataType
    pashCommandsGenerator.topPercent = 0.01
    pashCommandsGenerator.numberOfTopMatches = 1
    mapFile = "#{File.basename(@outputFile)}.pash"
    pashCommandsGenerator.mapFile = mapFile
    commandList = pashCommandsGenerator.generateCommands()
    $stderr.puts "command list #{commandList.join(";")}" if (DEBUG)
    commandList.push "pashTwo2lff.rb -f #{mapFile} -o #{File.basename(@outputFile)} #{@pashTwoLffArgs}"
    commandList.push "sleep 2"
    commandList.push "bzip2 #{mapFile} "
    # finally, upload the lff track to a specified database
    outputDirectory = @outputDirectory
    begin
      tupleSpaceJob = BRL::Genboree::Pash::TupleSpaceJob.new()
      tupleSpaceJob.outputDirectory=outputDirectory
      tupleSpaceJob.inputFilesNeedCopy=[ @sequenceFile ]
      tupleSpaceJob.commandList = commandList
      $stderr.puts "executing command #{tupleSpaceJob.commandList.join(";")}, with output directory #{tupleSpaceJob.outputDirectory}" if (DEBUG)

      tupleSpaceJob.jobName = "Pash_anchoring"
      tupleSpaceJob.jobType = "Pash"
      # ignore everything but the mappings
      tupleSpaceJob.outputIgnoreList = []
      jobResources = {}
      tupleSpaceJob.jobResources=jobResources
      tupleSpaceJob.removeTemporaryFiles = false
      tupleSpaceJob.uniqueJobTicket = "Pash.Anchor.#{Time.now().to_i}"
      tupleSpaceJob.notificationEmail = "coarfa@bcm.edu"
      tupleSpaceJob.outputHost = @outputHost
      tupleSpaceJob.sourceHost = @machineName
      tupleSpaceJob.submit()
    rescue => err
      $stderr.puts "caught exception"
      $stderr.puts err.message
      $stderr.puts err.backtrace.inspect
    end
  end

  def PashTupleJob.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--sequenceFile',   	  '-q', GetoptLong::REQUIRED_ARGUMENT],
									['--genomeName',     	  '-g', GetoptLong::REQUIRED_ARGUMENT],
									['--dataType',       	  '-d', GetoptLong::REQUIRED_ARGUMENT],
									['--class', 						'-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--type', 							'-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--subtype', 					'-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--outputFile',      	'-o', GetoptLong::REQUIRED_ARGUMENT],
									['--outputHost',      	'-H', GetoptLong::REQUIRED_ARGUMENT],
									['--help',           		'-h', GetoptLong::NO_ARGUMENT]
								]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		PashTupleJob.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			PashTupleJob.usage("USAGE ERROR: some required arguments are missing")
		end

		PashTupleJob.usage() if(optsHash.empty?);
		return optsHash
	end

	def PashTupleJob.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Submits a Pash 3.0 job to a ruby cluster. The pash mapping results are converted to Lff,
using the class, type, subtype attributes specified as arguments.

COMMAND LINE ARGUMENTS:
  --sequenceFile   | -q   => sequence file
  --genomeName     | -g   => genome name
  --class          | -c   => [optional] Override the LFF class value to use.
                           Defaults to 'Pash'.
  --type           | -t   => [optional] Override the LFF type value to use.
                           Defaults to 'Pash'.
  --subtype        | -s   => [optional] Override the LFF subtype value to use.
                           Defaults to 'Hit'.
  --outputFile     | -o   => output file on EDACC Galaxy host 
  --outputHost     | -H   => output host for mapping files
  --help           | -h   => [optional flag] Output this usage info and exit

USAGE:
  EDACCPashTupleJob.rb -q chipSeqLane.fa -g hg18 -c Pash -t ChIpSeq_H3K4me3 -s Hits -o pash.chipseq.lff -H myhost.bio.lab
";
	exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = PashTupleJob.processArguments()
# Instantiate analyzer using the program arguments
PashTupleJob = PashTupleJob.new(optsHash)
# Analyze this !
PashTupleJob.work()
exit(0);
