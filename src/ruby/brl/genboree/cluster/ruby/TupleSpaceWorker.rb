#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'rinda/tuplespace'

class TupleSpaceWorker
  DEBUG = true

  @@genboreeClusterTmpDir = "/usr/local/brl/data/tupleSpace/tmp"
  @@scratchDirectory      = "/usr/local/brl/data/tupleSpace/scratch"
  @@rootRsyncUtility      = "rsync -avz -e /usr/bin/ssh "
  @@sgeScriptSettingsFile = "/usr/local/brl/local/tupleSpace/tsbashrc"

  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
  end

  def work()
    while (1)
      sleep(1)
      genboreeConfig = BRL::Genboree::GenboreeConfig.new()
      genboreeConfig.loadConfigFile()
      tupleSpaceServerPort = genboreeConfig.tupleSpaceServerPort
      tupleSpaceServer = genboreeConfig.tupleSpaceServer
      if (!genboreeConfig.clusterTmpDir.nil?) then
        @@genboreeClusterTmpDir = genboreeConfig.clusterTmpDir
      end
      if (!genboreeConfig.clusterScratchDirectory.nil?) then
        @scratchDirectory = genboreeConfig.clusterScratchDirectory
      else
        @scratchDirectory = @@scratchDirectory
      end
      if (!genboreeConfig.rootRsyncUtility.nil?) then
        @@rootRsyncUtility = genboreeConfig.rootRsyncUtility
      end
      destinationMachine = genboreeConfig.destinationMachine
      ts = DRbObject.new(nil, "druby://#{tupleSpaceServer}:#{tupleSpaceServerPort}")

      $stderr.puts "#{ts} #{ts.class}"
      begin
		# NOTE: try to see if a different tuple is available (suspend) or if the
		# table suspend activity has the suspend status set
        tuple = ['work', nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        answer = ts.take(tuple, 5)
        $stderr.puts "#{tuple}"
        if (answer.nil?) then
          next
        end
        $stderr.puts "=======================================================================================" if(DEBUG)
        answer.each { |k,v|
          $stderr.puts "k=#{k} v=#{v}"
        }
        startTime = Time.now()

        scriptName = answer[5]
        baseScriptName = File.basename(scriptName)
        decoratedJobName = answer[4]
        jobTicket = answer[3]
        jobType = answer[1]
        jobName = answer[2]
        removeTempFiles = answer[6]
        outputDirectory = answer[7]
        emailAddress = answer[8]
        destinationMachine = answer[9]
        issuingMachine = answer[10]
        $stderr.puts "job type #{jobTicket} job name #{jobName} jobTicket #{jobTicket}, decoratedJobName #{decoratedJobName} script #{scriptName} removeTempFiles #{removeTempFiles} notificationEmail #{emailAddress}"
        emailMessage = nil

        # retrieve the script
        rsyncCommand = "#{@@rootRsyncUtility} #{issuingMachine}:#{scriptName} #{@@genboreeClusterTmpDir}/"
        $stderr.puts "about to rsync the ruby script: #{rsyncCommand}" if (DEBUG)
        rsyncStatus = system(rsyncCommand)
        $stderr.puts "rsync status #{$?.exitstatus}" if (DEBUG)
        # execute the script
        system("chmod +x #{@@genboreeClusterTmpDir}/#{baseScriptName} ")
        logFile = "#{@@genboreeClusterTmpDir}/log.#{decoratedJobName}"
        jobExitStatus = system("#{@@genboreeClusterTmpDir}/#{baseScriptName} > #{logFile} 2>&1")
        # rsync logs back
        $stderr.puts "about to rsync logs back " if (DEBUG)
        $stderr.puts "scratch dir content: #{Dir[@scratchDirectory]}"
        rsyncCommand = "#{@@rootRsyncUtility} #{logFile} #{destinationMachine}:#{outputDirectory}"
        system(rsyncCommand)
        # cleanup if requested
        $stderr.puts "removeTempFiles #{removeTempFiles}" if(DEBUG)
        if (removeTempFiles=="yes") then
          rmCommand = "/bin/rm -rf #{@scratchDirectory}/#{decoratedJobName} #{logFile}"
          $stderr.puts "rm command: #{rmCommand}"
          system(rmCommand)
        end
        stopTime = Time.now()
        exitStatusTuple = ['exitStatus',  jobType, jobName,  startTime, stopTime, emailAddress, emailMessage, jobExitStatus]
        wh = ts.write(exitStatusTuple)
        $stderr.puts "sent tuple #{exitStatusTuple.to_a.join(";")} w/ status #{wh}"
        $stderr.puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" if(DEBUG)
      rescue => err
        $stderr.puts "caught exception"
        $stderr.puts err.message
        $stderr.puts err.backtrace.inspect
      end
    end
  end

  def TupleSpaceWorker.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		TupleSpaceWorker.usage() if(optsHash.key?('--help'));


		unless(progOpts.getMissingOptions().empty?)
			TupleSpaceWorker.usage("USAGE ERROR: some required arguments are missing")
		end

		#TupleSpaceWorker.usage() if(optsHash.empty?);
		return optsHash
	end

	def TupleSpaceWorker.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Runs a tuple space finisher.

COMMAND LINE ARGUMENTS:
  --help             | -h   => [optional flag] Output this usage info and exit

USAGE:
  TupleSpaceWorker.rb
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = TupleSpaceWorker.processArguments()
# Instantiate analyzer using the program arguments
tupleSpaceWorker = TupleSpaceWorker.new(optsHash)
# Analyze this !
tupleSpaceWorker.work()
exit(0);
