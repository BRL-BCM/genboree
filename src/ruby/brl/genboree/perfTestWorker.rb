#!/usr/bin/env ruby
# ##############################################################################
# $Copyright:$
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# For standard BRL extensions to built-ins
require 'brl/util/textFileUtil' # For TextReader/Writer convenience classes
require 'net/http'
require 'uri'
require 'timeout'
require 'brl/pash/tcpActionControlledClient'
require 'GSL'
include GSL::Random

# CONSTANTS
GLOBAL_RNG = GSL::Random::RNG.new2(GSL::Random::RNG::CMRG)
GLOBAL_RNG.set(Time.now().to_i  ^ ($$+($$<<15)))
BASE_START = 10000
BASE_STOP = 180_000_000
EPSILON = 3000
REQ_WAIT = 5
DENSE_REF_IDS = [ 155, 184, 200 ]
SPARSE_REF_IDS = [ 77, 78, 79 ]
DENSE_ENTRY_POINTS =	{
												155 => [ 'Hs1-b16', 'Hs2-b16' ],
												184	=> [ 'chr3' ],
												200 => [ 'chr3' ]
											}
SPARSE_ENTRY_POINTS = {
												77 => [ 'Hs1-b15', 'Hs2-b15' ],
												78 => [ 'Mm1-b3', 'Mm2-b3' ],
												79 => [ 'Rn1-b3.1', 'Rn2-b3.1' ]
											}
TYES_RE = /^YES/
TOK_COUNT_RE = /^OK\:(\d+)/
TIME_RE = /(TIME TO RUN\:\s+\d+\.\d+)/
 
unless(ARGV.size == 5)
	$stderr.puts "\n\nUSAGE:\n  perfTestWorker.rb [DENSE|SPARSE] <clientID> <numRepeatedAccesses> <numSimultaneousTests> '<quotedMessage>'\n\n"
	exit(134)
end

tMode = ARGV[0].upcase
tClientID = ARGV[1]
tReps = ARGV[2].to_i
tSimulCount = ARGV[3].to_i
tMessage = ARGV[4]

$stderr.puts "\n#{'-'*50}\nClient ID: '#{tClientID}'\nDoing: '#{tReps}' reps for each of '#{tSimulCount}' simultaneous clients\nMessage: '#{tMessage}'"

status = false
begin
	if(tSimulCount > 1)
		status = timeout(48000) {
			tacc = BRL::PASH::TCPActionControllerClient.new()
			taccReply = tacc.canDoAction?
			$stderr.puts "canDoAction reply: '#{taccReply}'"
			unless(taccReply =~ TYES_RE) then raise StandardError, "The action controller can-do reply was not expected: '#{taccReply}'" ;	end
			loop {
				tacc = BRL::PASH::TCPActionControllerClient.new()
				taccReply = tacc.getActionCount()
				$stderr.puts "getActionCount Reply: '#{taccReply}'"
				unless(taccReply =~ TOK_COUNT_RE) then raise StandardError, "The action controller count reply was not expected: '#{taccReply}'" ;	end
				workerCount = $1.to_i
				$stderr.puts "Current # Workers: '#{workerCount}'"
				if(workerCount < tSimulCount)
					sleep 2
					redo
				else
					$stderr.puts "Enough Simultaneous Workers READY\n#{'-'*50}"
					break
				end
			}
		}
	end
rescue TimeoutError => tErr
	puts "\n\nERROR: timed out waiting for simultaneous workers. (>480sec)\n\n"
	$stderr.puts "\n\nERROR: timed out waiting for simultaneous workers. (>480sec)\n\n"
	exit(136)
rescue StandardError => err
	puts "\n\nERROR: Something really bad happened:\n'#{err.message}'\n'" + err.backtrace.join("\n") + "\n"
end

totalGenbTimes = []
totalConnectTimes = []
tReps.times { |ii|
	$stderr.puts "Iteration '#{ii}' =>"
	# Pick a start
	tStart = BASE_START + ((GLOBAL_RNG.uniform * 2 * EPSILON).floor - EPSILON)
	$stderr.puts "\ttStart: '#{tStart}'"
	# Pick a stop
	tStop = BASE_STOP + ((GLOBAL_RNG.uniform * 2 * EPSILON).floor - EPSILON)
	$stderr.puts "\ttStop: '#{tStop}'"
	# Pick a refId
	refIds = (tMode == 'DENSE' ? DENSE_REF_IDS : SPARSE_REF_IDS)
	tDbID = refIds.choose(GLOBAL_RNG, 1)[0]
	$stderr.puts "\ttDbID: '#{tDbID}'"
	# Pick an entrypoint
	eps = (tMode == 'DENSE' ? DENSE_ENTRY_POINTS : SPARSE_ENTRY_POINTS)
	tEntryPoint = eps[tDbID].choose(GLOBAL_RNG, 1)[0]
	$stderr.puts "\ttEntryPoint: '#{tEntryPoint}'"
	# Make URL bits
	domain = 'valine.brl.bcm.tmc.edu'
	resource = "/~brlweb/genbPerfTest.rhtml?pi=#{tStart}&pt=#{tStop}&pr=#{tDbID}&pe=#{tEntryPoint}&pu=2"
	http = Net::HTTP.new(domain, 80)
	http.read_timeout = 9000
	startConnTime = Time.now.to_i
	http.start
	startGenbTime = Time.now.to_i
	perfTestReply = nil
	loop {
		begin
			perfTestReply = http.get(resource)
		rescue
			redo
		else
			break
		end
	}
	totalGenbTimes << (Time.now.to_i - startGenbTime)
	http.finish
	totalConnectTimes << (Time.now.to_i - startConnTime)
	# $stderr.puts perfTestReply
	perfTestReply.body.each { |line|
		if(line =~ TIME_RE)
			$stderr.puts "SUCCESS: Found time record in Perf Test Reply"
			puts "CLIENT: #{tClientID} REP: #{ii} MSG: #{tMessage}\n\tRefID: #{tDbID}\n\tChr: #{tEntryPoint}\n\t#{$1}"
		end
	}
	sleep(REQ_WAIT)
}
totalConnectTime = 0 ; totalConnectTimes.map { |xx| totalConnectTime += xx }
totalGenbTime = 0 ; totalGenbTimes.map { |xx| totalGenbTime += xx }
puts "\n\nTOTAL TIME MAKING/DOING CONNECTION STUFF: #{totalConnectTime} (avg: #{GSL::Stats::mean1(totalConnectTimes)}, sd: #{GSL::Stats::sd1(totalConnectTimes)})"
puts "TOTAL TIME FOR REMOTE GENBOREE TO FINISH: #{totalGenbTime} (avg: #{GSL::Stats::mean1(totalGenbTimes)}, sd: #{GSL::Stats::sd1(totalGenbTimes)})"

exit(0)
