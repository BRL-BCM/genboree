#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'socket'
require 'timeout'
require 'brl/util/util'					# for standard extensions of Ruby classes
require 'brl/pash/tcpActionControlledClient' # For any module/class vars we might need
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module PASH
	# SOME MODULE CONSTANTS
	MAX_COUNT = 8
	MAX_PORT = 65000
	SERVER_WAIT = 10

	# CLASS: TCPActionControllerServer
	# PURPOSE: 	Instances of this class respond to messages from TCPActionControllerClients
	#						and respond.
	class TCPActionControllerServer
		attr_accessor :port, :actionCount, :maxActionCount
		attr_reader :listenSocket

		# FUNCTION: initialize
		# PURPOSE:	Instantiates the server class and enters the listen loop.
		#	ARGUMENTS: [integer], [string]
		# RETURN VALUE: reference to a TCPActionControlledClient object.
		def initialize(maxActionCount=BRL::PASH::MAX_COUNT, port=BRL::PASH::INIT_PORT)
			@port = port.to_i
			@actionCount = 0
			@maxActionCount = maxActionCount.to_i
		end

		def bindSocket()
			currPort = @port
			# Let's try to bind a port to listen on
			begin
				@listenSocket = TCPServer.new(nil, currPort)
			rescue # all errors
				currPort+= 1 # Increment port # and try that one
				retry # starts back at "begin"
			end
			@port = currPort
			$stderr.puts "#{Time.now()}  SERVER bound to local port #{@port}."
		end

		def listen()
			$stderr.puts "#{Time.now()}  SERVER listening for connections."
			while(connectedSocket = @listenSocket.accept()) # blocks until a client connects
				$stderr.puts	"#{Time.now()}  SERVER Received connection from #{connectedSocket.peeraddr()[3]}:#{connectedSocket.peeraddr()[1]}"
				begin
					timeout(BRL::PASH::SERVER_WAIT) {
						payload = connectedSocket.gets # <-- all messages are \r\n terminated for this convenience
						unless(payload.nil? or payload.empty?) # ignore clients that don't send us anything
							payload.chomp!
							continue = self.processCommand(connectedSocket, payload)
							break unless(continue)
						end
					}
				rescue TimeoutError => timeError
					$stderr.puts 	"#{Time.now()}  SERVER ERROR: Received connection from " +
												"#{connectedSocket.peeraddr()[3]}:#{connectedSocket.peeraddr()[1]} but the message took to long to arrive or " +
												"wasn't properly \\r\\n terminated. Disconnecting that client and going back to listening."
				end
				connectedSocket.close() unless(connectedSocket.nil? or connectedSocket.closed?())
			end
		end

		def shutdown(connectedSocket)
			connectedSocket.close() unless(connectedSocket.nil? or connectedSocket.closed?())
			listenSocket.close() unless(listenSocket.nil? or listenSocket.closed?())
			$stderr.puts "#{Time.now()}  SERVER exiting by request."
			exit(0);
		end

		def processCommand(connectedSocket, payload)
			$stderr.puts	"#{Time.now()}  SERVER          Client issued command >>#{payload}<<"
			command = ''
			commandArgs = ''
			if(payload =~ /(\d+)(?:\:(.+))?/)
				command = $1
				command = command.to_i
				unless($2.nil?)
					commandArgs = $2
				end
			else
				$stderr.puts 	"#{Time.now()}  SERVER WARNING: Received connection from " +
											"#{connectedSocket.peeraddr()[3]}:#{connectedSocket.peeraddr()[1]} but the message format isn't recognized. " +
											"Disconnecting that client and going back to listening."
				return true
			end

			# Determine what to do:
			case command
				when	BRL::PASH::DO_ACTION
					if(@actionCount < @maxActionCount)
						tmpCnt = @actionCount
						@actionCount+= 1
						connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::YES_MSG}:#{tmpCnt}\r\n")
					else
						connectedSocket.print("#{BRL::PASH::BAD_REPLY}:#{BRL::PASH::NO_MSG}:#{@actionCount}\r\n")
					end
				when BRL::PASH::DONE_ACTION
					tmpCnt = @actionCount
					@actionCount -= 1
					connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::OK_MSG}:#{tmpCnt}\r\n")
					if(@actionCount < 0)
						$stderr.puts "#{Time.now()}  SERVER WARNING: Somehow the action count has become negative! (became #{@actionCount}). Reset to 0, but what is going on?"
						@actionCount = 0
					end
				when BRL::PASH::RESET
					tmpCnt = @actionCount
					@actionCount = 0
					connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::OK_MSG}:#{tmpCnt}\r\n")
				when BRL::PASH::GET_ACTION_COUNT
					connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::OK_MSG}:#{@actionCount}\r\n")
				when BRL::PASH::SHUTDOWN_SERVER
					connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::OK_MSG}:#{@actionCount}\r\n")
					self.shutdown(connectedSocket);
				when BRL::PASH::NEW_MAX
					if(commandArgs.nil? or commandArgs.empty?)
						$stderr.puts "#{Time.now}  SERVER WARNING: was asked to set new max action count, but message format not correct (received '#{payload}'). Doing nothing."
					else
						begin
							newMax = commandArgs.to_i
							tmpMax = @maxActionCount
							@maxActionCount = newMax
							connectedSocket.print("#{BRL::PASH::OK_REPLY}:#{BRL::PASH::OK_MSG}:#{tmpMax}\r\n")
						rescue => err
							warnStr = "Was asked to set new max action count, but invalid new max '#{commandArgs}'. Can't convert to integer. Doing nothing."
							connectedSocket.print("#{BRL::PASH::BAD_REPLY}: #{warnStr}\r\n")
							$stderr.puts "#{Time.now}  SERVER WARNING: #{warnStr}\r\n"
						end
					end
				else
					$stderr.puts "#{Time.now()}  SERVER WARNING: Asked to process invalid command number '#{command}'\n\n"
			end # case command
			# $stderr.puts	"#{Time.now()}  SERVER          Client dealt with"
			return true
		end # def processCommand(connectedSocket, payload)
	end # class TCPActionControllerServer
end ; end # end BRL ; end PASH

# ##############################################################################
# When run on the command line:
# ##############################################################################
if(__FILE__ == $0)
	module RunActionServer
		require 'getoptlong'

		def RunActionServer.processArguments
			progOpts =
				GetoptLong.new(
					['--maxActionCount','-m', GetoptLong::OPTIONAL_ARGUMENT],
					['--port',					'-p', GetoptLong::OPTIONAL_ARGUMENT],
					['--help',					'-h', GetoptLong::NO_ARGUMENT]
				)

			optsHash = progOpts.to_hash
			if(optsHash.key?('--help'))
				RunActionServer.usage()
			end
			return optsHash
		end

		def RunActionServer.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

	PROGRAM DESCRIPTION:
		Launches an action server that will count the number of clients performing
		a controlled action, allow clients to ask if they can begin their
		controlled action, and such. The 'askActionServer.rb' client can be used
		to change some of the runtime parameters of this server, including the
		maximum number of actions allowed at once and resetting of the count to 0.
		That client can also be used to get the current number of controlled
		actions being performed.

		Log info is printed on stderr, so you might want to redirect that somewhere.

	COMMAND LINE ARGUMENTS:
		--maxActionCount, -m   Optional. Set the maximum number of simultaneous controlled actions.
		                       Default is #{BRL::PASH::MAX_COUNT}
		--port, -p             Optionsal. Set the local port at which to start looking for a free port.
		                       Default is #{BRL::PASH::INIT_PORT}
		--help, -h             Flag. Print this help info.

	USAGE:
		runActionServer.rb
		runActionServer.rb -m 20 --port 11456

	";
			exit(2);
		end
	end # module TestPropTable

	# ############################################################################
	# MAIN
	# ############################################################################
	optsHash = RunActionServer.processArguments()
	maxActions = BRL::PASH::MAX_COUNT
	lclPort = BRL::PASH::INIT_PORT

	# Check optional args
	if(optsHash.key?('--maxActionCount')) then maxActions = optsHash['--maxActionCount'].to_i	end
	if(optsHash.key?('--port')) then lclPort = optsHash['--port'].to_i end

	# Create server
	actionServer = BRL::PASH::TCPActionControllerServer.new(maxActions, lclPort)

	# Bind server to port
	actionServer.bindSocket()

	# Start it listening
	actionServer.listen()
end # if(__FILE__ == $0)
