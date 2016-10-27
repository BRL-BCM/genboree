#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/cluster/ruby/TupleSpaceJob'
require 'brl/genboree/cluster/PashJobs/generatePashCommands'


class PashTupleJob
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
    @sequenceFile = @optsHash['--sequenceFile']
    @genomeName = @optsHash['--genomeName']
    @dataType = @optsHash['--dataType']
    @outputDirectory = @optsHash['--outputDirectory']

    @pashTwoLffArgs = ""
    if (@optsHash.key?('--class')) then
			@pashTwoLffArgs << " -c #{@optsHash['--class']}"
    end
    if (@optsHash.key?('--type')) then
			@pashTwoLffArgs << " -t #{@optsHash['--type']}"
    end
    if (@optsHash.key?('--subtype')) then
			@pashTwoLffArgs << " -s #{@optsHash['--subtype']}"
    end
    # todo: add extension
    # todo: add additional avps that will be copied onto every annotation
    @userName = @optsHash['--gbUserName']
    @database = @optsHash['--gbDatabase']
    @group = @optsHash['--gbGroup']
    @project = @optsHash['--project']
  end

  def work()
    pashCommandsGenerator = BRL::Genboree::Pash::PashCommandGenerator.new()
    pashCommandsGenerator.sequenceFile = @sequenceFile
    pashCommandsGenerator.genomeName = @genomeName
    pashCommandsGenerator.dataType = @dataType
    pashCommandsGenerator.topPercent = 0.01
    pashCommandsGenerator.numberOfTopMatches = 1
		mapFile = "#{File.basename(@sequenceFile)}.onto.#{@genomeName}"
		pashCommandsGenerator.mapFile = mapFile
    commandList = pashCommandsGenerator.generateCommands()
    $stderr.puts "command list #{commandList.join(";")}"

    commandList.push "pashTwo2lff.rb -f #{mapFile} -o #{mapFile}.lff #{@pashTwoLffArgs}"
    # finally, upload the lff track to a specified database
    commandList.push("restLffUpload.rb -l #{mapFile}.lff -u #{@userName} -g #{@group} -d #{@database}")
    commandList.push("restProjectAnnounce.rb -s #{mapFile}.lff -u #{@userName} -g #{@group} -P #{@project}")
    outputDirectory = @outputDirectory
    begin
      tupleSpaceJob = BRL::Genboree::Pash::TupleSpaceJob.new()
      tupleSpaceJob.outputDirectory=outputDirectory
      tupleSpaceJob.inputFilesNeedCopy=[ @sequenceFile ]
      tupleSpaceJob.commandList = commandList
      $stderr.puts "executing command #{tupleSpaceJob.commandList.join(";")}, with output directory #{tupleSpaceJob.outputDirectory}"

      tupleSpaceJob.jobName = "Pash_anchoring"
      tupleSpaceJob.jobType = "Pash"
      tupleSpaceJob.outputIgnoreList = []
      jobResources = {}
      tupleSpaceJob.jobResources=jobResources
      tupleSpaceJob.removeTemporaryFiles = false
      tupleSpaceJob.uniqueJobTicket = "Pash.Anchor.#{Time.now().to_i}"
      tupleSpaceJob.notificationEmail = "coarfa@bcm.edu"
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
									['--gbUserName', 			  '-U', GetoptLong::REQUIRED_ARGUMENT],
									['--gbGroup',					  '-G', GetoptLong::REQUIRED_ARGUMENT],
									['--gbDatabase',			  '-D', GetoptLong::REQUIRED_ARGUMENT],
									['--class', 						'-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--type', 							'-t', GetoptLong::OPTIONAL_ARGUMENT],
									['--subtype', 					'-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--outputDirectory', 	'-o', GetoptLong::REQUIRED_ARGUMENT],
									['--project', 	        '-P', GetoptLong::REQUIRED_ARGUMENT],
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
  It does something.

COMMAND LINE ARGUMENTS:
  --sequenceFile   | -q   => sequence file
  --genomeName     | -g   => genome name
  --class          | -c   => [optional] Override the LFF class value to use.
                           Defaults to 'Pash'.
  --type           | -t   => [optional] Override the LFF type value to use.
                           Defaults to 'Pash'.
  --subtype        | -s   => [optional] Override the LFF subtype value to use.
                           Defaults to 'Hit'.
  --outputDirectory| -o   => output directory
  --project        | -P   => project name where the mapping will be announced
  --help           | -h   => [optional flag] Output this usage info and exit

USAGE:
  rubyScript.rb  -r requiredArg -o optionalArg
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
