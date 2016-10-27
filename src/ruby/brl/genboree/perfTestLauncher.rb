#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# For standard BRL extensions to built-ins
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'fileutils'
require 'brl/pash/tcpActionControlledClient'
require 'brl/lsf/lsfBatchJob'

# CONSTANTS
WORKER = "ruby ~/work/brl/src/ruby/brl/genboree/perfTestWorker.rb"


# Arguments
unless(ARGV.size == 5)
	$stderr.puts "\n\nUSAGE:\n  perfTestLauncher.rb [DENSE|SPARSE] <numRepeatedAccesses> <numSimultaneousTests> '<quotedMessage>' <queue>\n\n"
	exit(134)
end

tMode = ARGV[0]
tReps = ARGV[1].to_i
tSimultCount = ARGV[2].to_i
tMessage = ARGV[3]
tQueue = ARGV[4]

FileUtils.mkdir_p('./lsfMsgs')
# Make sure this is reset from previous
tacc = BRL::PASH::TCPActionControllerClient.new()
puts taccReply = tacc.reset
tacc = BRL::PASH::TCPActionControllerClient.new()
puts taccReply = tacc.newMax(tSimultCount)

tSimultCount.times { |ii|
	jobName = "ptw.#{$$}.#{ii}"
	cmdStr = "\"#{WORKER} #{tMode} #{jobName} #{tReps} #{tSimultCount} \\'#{tMessage}\\' > ./client.#{ii}.out 2> ./client.#{ii}.err \""
	lsf = BRL::LSF::LSFBatchJob.new(jobName)
	lsf.errorFile = "./lsfMsgs/#{jobName}.err"
	lsf.outputFile = "./lsfMsgs/#{jobName}.out"
	lsf.queueName = tQueue
	lsf.commandStrToRun = cmdStr
	lsf.submit()
}

exit(0)
