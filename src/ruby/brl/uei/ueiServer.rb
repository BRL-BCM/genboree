#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'socket'
require 'timeout'
require 'brl/util/util'					# for standard extensions of Ruby classes
require 'brl/uei/ueiManager'		# for UEIManager class (which does all the work)
$VERBOSE = true

module BRL ; module UEI
	# SOME MODULE CONSTANTS
	INIT_PORT = 12395
	SERVER_WAIT = 60
	NEW_UEI, NEW_UEIS, UEI_ASSIGNED, UEIS_ASSIGNED, ASSIGN_TIME, ASSIGN_TIMES =
		'newuei', 'newueis', 'ueiassigned', 'ueisassigned', 'assigntime', 'assigntimes'
	OK_REPLY, YES_REPLY, NO_REPLY, BAD_REPLY =
		'OK ', 'YES ', 'NO ', 'BAD '
	# Form of Commands:																Form of Response:
	#		GET newUEI																		OK <newUEI>\r\n
	# 	GET newUEIs <num>															OK <newUEI_1> <newUEI_2> <newUEI_num>\r\n
	# 	IS UEIAssigned <uei>													YES <uei>\r\n
	#																									NO <uei>\r\n
	#		IS UEIAssigned  <uei_1> <uei_2> <uei_3> ...
	#		IS UEIsAssigned <uei_1> <uei_2> <uei_3> ... 	YES <uei_1>\r\nYES <uei_2>\r\nNO <uei_3>\r\n ...
	#		GET assignTime <uei>													OK <uei> DD-MM-YY hh:mm:ss\r\n
	#		GET assignTime <uei_1> <uei_2> <uei_3> ...
	# 	GET assignTimes <uei_1> <uei_2> <uei_3> ...   OK <uei_1> DD-MM-YY hh:mm:ss\r\nOK <uei_2> DD-MM-YY hh:mm:ss\r\nOK <uei_3> DD-MM-YY hh:mm:ss\r\n ...
	#
	# For BAD uei's that are handed to us, the response lines look like:
	#		BAD <uei> <message>
	# Note that if the uei hasn't been assigned, then that's not BAD
	#
	# For protocol violations, return message looks like:
	# 	FAIL <message>

	# CLASS: UEIClientError
	# PURPOSE: 	Represents anticipated errors that can happen within the methods of
	#					 	UEIClient and UEIServer
	class UEIClientError < StandardError ; end

	# CLASS: UEIServer
	# PURPOSE:
	class UEIServer
		attr_accessor :port
		attr_reader :listenSocket, :connSocket, :ueiManager

		# FUNCTION: initialize
		# PURPOSE:	Instantiates the server class and enters the listen loop.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: reference to a UEIServer object.
		def initialize(port=BRL::UEI::INIT_PORT)
			@port = port.to_i
			if(ENV['DB_ACCESS_FILE'].nil? or ENV['DB_ACCESS_FILE'].empty?)
				$stderr.puts	"#{Time.now()}	SERVER can't start because missing environmental variable DB_ACCESS_FILE. Is your Apache set up properly?"
				raise "#{Time.now()}	SERVER can't start because missing environmental variable DB_ACCESS_FILE. Is your Apache set up properly?"
			else
				@ueiManager = BRL::UEI::UEIManager.new(ENV['DB_ACCESS_FILE'])
			end
			@connSocket = nil
			@listenSocket = nil
		end

		# ######################################################################
		# Socket Stuff
		# ######################################################################
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
			while(@connSocket = @listenSocket.accept()) # blocks until a client connects
				$stderr.puts	"#{Time.now()}  SERVER Received connection from #{@connSocket.peeraddr()[3]}:#{@connSocket.peeraddr()[1]}"
				begin
					timeout(BRL::UEI::SERVER_WAIT) {
						payload = @connSocket.gets # <-- all messages are \r\n terminated for this convenience
						unless(payload.nil? or payload.empty?) # ignore clients that don't send us anything
							payload.strip!
							continue = self.processCommand(payload)
						end
					}
				rescue TimeoutError => timeError
					$stderr.puts 	"#{Time.now()}  SERVER ERROR: Received connection from " +
												"#{@connSocket.peeraddr()[3]}:#{@connSocket.peeraddr()[1]} but the message took to long to arrive or " +
												"wasn't properly \\r\\n terminated. Disconnecting that client and going back to listening."
					self.fail("Server Timed out. Server took too long to process your request. Therefore you were disconnected.")
				end
				@connSocket.close() unless(connSocket.nil? or connSocket.closed?())
				@connSocket = nil
			end
		end

		def shutdown()
			@connSocket.close() unless(@connSocket.nil? or @connSocket.closed?())
			listenSocket.close() unless(listenSocket.nil? or listenSocket.closed?())
			$stderr.puts "#{Time.now()}  SERVER exiting by request."
			exit(0);
		end
		# ##########################################################################

		# ##########################################################################
		# UEI Serving Stuff
		# ##########################################################################
		def processCommand(payload)
			$stderr.puts	"#{Time.now()}  SERVER          Client issued command >>#{payload}<<"
			command = ''
			commandArgs = ''
			# check payload format and chop it up into args...set appropriate args when none

			# First, what command category are we dealing with?
			didMatch = (payload =~ /^(GET|IS)\s+(\S+)(?:\s+(.*))?$/i)
			unless(didMatch.nil?)
				category = $1
				command = $2.downcase
				commandArgs = []
				unless($3.nil?)
					commandArgs = $3.split(/\s+/)
				end
			else # bad command
				$stderr.puts 	"#{Time.now()}  SERVER WARNING: Received connection from " +
											"#{@connSocket.peeraddr()[3]}:#{@connSocket.peeraddr()[1]} but the message format isn't recognized. (message: '#{payload}' " +
											"Disconnecting that client and going back to listening."
				return false
			end

			# Determine what to do:
			case command
				when	BRL::UEI::NEW_UEI
					return self.newUEIs(1)
				when	BRL::UEI::NEW_UEIS
					return self.newUEIs(commandArgs[0].strip.to_i)
				when	BRL::UEI::UEI_ASSIGNED,
				      BRL::UEI::UEIS_ASSIGNED
					return self.ueisAssigned(commandArgs)
				when	BRL::UEI::ASSIGN_TIME,
							BRL::UEI::ASSIGN_TIMES
					return self.assignTimes(commandArgs)
				else
					$stderr.puts "#{Time.now()}  SERVER WARNING: Asked to process invalid command number '#{command}'\n\n"
					return false
			end # case command
		end # def processCommand(payload)

		# ###############
		protected
		# ###############
		# Form of Commands:																Form of Response:
			#		GET newUEI																		OK <newUEI>\r\n
			# 	GET newUEIs <num>															OK <newUEI_1> <newUEI_2>...<newUEI_num>\r\n
			# 	IS UEIAssigned <uei>													YES <uei>\r\n
			#																									NO <uei>\r\n
			#		IS UEIAssigned  <uei_1> <uei_2> <uei_3> ...
			#		IS UEIsAssigned <uei_1> <uei_2> <uei_3> ... 	YES <uei_1>\r\nYES <uei_2>\r\nNO <uei_3>\r\n ...
			#		GET assignTime <uei>													OK <uei> DD-MM-YY hh:mm:ss\r\n
			#		GET assignTime <uei_1> <uei_2> <uei_3> ...
			# 	GET assignTimes <uei_1> <uei_2> <uei_3> ...   OK <uei_1> DD-MM-YY hh:mm:ss\r\nOK <uei_2> DD-MM-YY hh:mm:ss\r\nOK <uei_3> DD-MM-YY hh:mm:ss\r\n ...
			#
			# For BAD uei's that are handed to us, the response lines look like:
			#		BAD <uei> <message>
			# Note that if the uei hasn't been assigned, then that's not BAD
			#
			# For protocol violations, return message looks like:
			# 	FAIL <message>
		def newUEIs(arg)
			unless(arg !~ /^(\d+)$/)
				# bad arg, fail
				self.fail("The argument for newUEIs is an integer. '#{$1}' is not an integer. Cannot execute command.")
				return false
			end
			ueiArray = @ueiManager.getNewUEIs(arg, @connSocket.peeraddr()[3])
			ueiListStr = ueiArray.join(' ')
			@connSocket.print(BRL::UEI::OK_REPLY + ueiListStr + "\r\n")
			return true
		end

		def ueisAssigned(args)
			ueiAssignedHash = @ueiManager.areUEIsAssigned?(args)
			reply = ''
			ueiAssignedHash.each {
				|ueiStr, assigned|
				if(assigned.nil?)
					reply << BRL::UEI::BAD_REPLY + ueiStr
				elsif(assigned)
					reply << BRL::UEI::YES_REPLY + ueiStr
				else # assigned = false
					reply << BRL::UEI::NO_REPLY + ueiStr
				end
				reply << "\r\n"
			}
			@connSocket.print(reply)
			return true
		end

		def assignTimes(args)
			ueiTimesHash = @ueiManager.getTimeStampsForUEIs(args)
			reply = ''
			ueiTimesHash.each {
				|ueiStr, timeStr|
				if(timeStr.nil?)
					reply << BRL::UEI::BAD_REPLY + "#{ueiStr}"
				else
					reply << BRL::UEI::OK_REPLY + "#{ueiStr} #{timeStr}"
				end
				reply << "\r\n"
			}
			@connSocket.print(reply)
			return true
		end

		def fail(message)
			@connSocket.print "FAIL #{message}\r\n"
		end
	end # class UEIServer
end ; end # end BRL ; end PASH

# ##############################################################################
# When run on the command line:
# ##############################################################################
if(__FILE__ == $0)
	module RunUEIServer
		require 'getoptlong'

		def RunUEIServer.processArguments
			progOpts =
				GetoptLong.new(
					['--port',					'-p', GetoptLong::OPTIONAL_ARGUMENT],
					['--help',					'-h', GetoptLong::NO_ARGUMENT]
				)

			optsHash = progOpts.to_hash
			if(optsHash.key?('--help'))
				RunUEIServer.usage()
			end
			return optsHash
		end

		def RunUEIServer.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

	PROGRAM DESCRIPTION:


		Log info is printed on stderr, so you might want to redirect that somewhere.

	COMMAND LINE ARGUMENTS:
		--port, -p             Optionsal. Set the local port at which to start looking for a free port.
		                       Default is #{BRL::UEI::INIT_PORT}
		--help, -h             Flag. Print this help info.

	USAGE:
		ueiServer.rb
		ueiServer.rb --port 11456

	";
			exit(2);
		end
	end # module RunUEIServer

	# ############################################################################
	# MAIN
	# ############################################################################
	optsHash = RunUEIServer.processArguments()
	lclPort = BRL::UEI::INIT_PORT

	# Check optional args
	if(optsHash.key?('--port')) then lclPort = optsHash['--port'].to_i end

	# Create server
	ueiServer = BRL::UEI::UEIServer.new(lclPort)

	# Bind server to port
	ueiServer.bindSocket()

	# Start it listening
	ueiServer.listen()
end # if(__FILE__ == $0)
