#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'socket'
require 'timeout'
require 'brl/util/util'					# for standard extensions of Ruby classes
require 'brl/uei/ueiServer'			# for module constants
# ##############################################################################
$VERBOSE = true

# Form of Commands:																Form of Response:
	#		GET newUEI																		OK <newUEI>\r\n
	# 	GET newUEIs <num>															OK <newUEI_1>\r\nOK<newUEI_2>\r\n...OK <newUEI_num>\r\n
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

module BRL ; module UEI
	# SOME MODULE CONSTANTS
	DEF_HOST = 'alanine.brl.bcm.tmc.edu'
	REPLY_TIMEOUT = 10

	class UEIClientError < StandardError ; end
	# CLASS: UEIClientClient
	# PURPOSE: 	Instances of this class can contact the UEIServer
	#						and issue various requests. It does a bunch of error checking and
	#						raises errors when something goes wrong.
	class UEIClient
		attr_accessor :port, :host
		attr_reader :socket

		GET_NEW_UEIS, ARE_ASSIGNED, GET_TIMESTAMPS =
		 0,1,2

		# FUNCTION: initialize
		# PURPOSE:	Instantiates the client object and tries to connect to the server.
		#           Optionally takes the port and host name as arguments if you want
		#           to override the defaults.
		#	ARGUMENTS: [integer], [string]
		# RETURN VALUE: reference to a UEIClient object.
		def initialize(port=BRL::UEI::INIT_PORT, host=BRL::UEI::DEF_HOST)
			@port, @host = port.to_i, host
			@host.strip!
			@host.gsub(/[a-zA-Z0-9_\.\-]/, '#') 	# replace bad chars in host name
			# Can throw error...we will catch typical ones
			begin
				@socket = TCPSocket.new(@host, @port)
			rescue SocketError => sockErr
				raise(UEIClientError,
					"\nERROR: couldn't connect to a Server at '#{@host}:#{port}'. " +
					"Probably some problem with the host name '#{@host} (invalid characters replaced with '#').\n" +
					"The internal error message was:\n\t#{sockErr.message}\n\n")
			rescue SystemCallError => sysErr
				raise(UEIClientError,
					"\nERROR: couldn't connect to a Server at '#{@host}:#{port}'. " +
					"Probably some problem with the port '#{@port}', maybe it's not the one the server is listening on, " +
					"or the server is not running at all.\nThe internal error message was:\n\t#{sysErr.message}\n\n")
			end
		end # def initialize(port=BRL::UEI::UEIClientClient::INIT_PORT, host=BRL::UEI::UEIClientClient::DEF_HOST, initCounter=0)

		# FUNCTION: close
		# PURPOSE:	Attempts to close the socket connection to the server.
		#	ARGUMENTS: none
		# RETURN VALUE: none
		def close()
			unless(@socket.nil?() or @socket.closed?())
				@socket.close()
			end
		end

		def getNewUEIs(num)
			num = num.to_i
			return self.sendCommand(GET_NEW_UEIS, REPLY_TIMEOUT, [ num ])
		end

		def areAssigned(ueiArray)
			return self.sendCommand(ARE_ASSIGNED, REPLY_TIMEOUT, ueiArray)
		end

		def getTimeStamps(ueiArray)
			return self.sendCommand(GET_TIMESTAMPS, REPLY_TIMEOUT, ueiArray)
		end

		########
		protected # following methods/data are private to this class and its kids
		########
		# FUNCTION: sendCommand
		# PURPOSE:	Sends the given command using the given reply timeout, and the
		#           optional command arguments to send, which may be ignored if not
		#						needed for the command provided.
		#	ARGUMENTS: integer, integer, [array]
		# RETURN VALUE: The server's reply to the message.
		def sendCommand(command, replyTimeout, commandArgs)
			if(@socket.nil? or @socket.closed?())
				raise(UEIClientError, "\nERROR: Socket not connected to a server for some reason? Very odd.\n\n")
			end
			retValue = nil
			case command
				when	GET_NEW_UEIS
					retValue = []
					@socket.print("GET newUEIs #{commandArgs[0]}\r\n")
					payload = self.getReply()
					if(payload =~ /^OK\s+(.*)$/)
						retValue = $1.split(/\s+/)
					else
						raise(UEIClientError, "\nERROR: server sent back an unexpected reply: '#{payload}'\n\n")
					end
				when	GET_TIMESTAMPS
					retValue = {}
					@socket.print("GET assignTimes #{commandArgs.join(' ')}\r\n")
					payload = self.getReply()
					payloadLines = payload.split(/\r\n/)
					payloadLines.each {
						|line|
						line.strip!
						line =~ /^(\S+)\s+(\S+)\s+(.*)$/
						answerStr, uei, timeStr = $1,$2,$3
						retValue[uei] = ((answerStr =~ /OK/) ? timeStr : nil)
					}
				when	ARE_ASSIGNED
					retValue = {}
					@socket.print("IS UEIsAssigned #{commandArgs.join(' ')}\r\n")
					payload = self.getReply()
					payloadLines = payload.split(/\r\n/)
					payloadLines.each {
						|line|
						line.strip!
						replyFields = line.split(/\s+/)
						answerStr, uei = *replyFields
						retValue[uei] = ((answerStr =~ /YES/) ? true : (answerStr =~ /BAD/) ? 'BAD UEI!' : false)
					}
					p payload
				else
					raise(UEIClientError, "\nERROR: Asked to send invalid command number '#{command}'\n\n")
			end # case command
			return retValue
		end

		def getReply()
			payload = ''
			begin
				status = timeout(BRL::UEI::REPLY_TIMEOUT) {
					payload = @socket.read
				}
			rescue TimeoutError => timeErr
				raise(UEIClientError, "\nERROR: Sorry, server didn't reply within #{replyTimeout} seconds. " +
																			"Dunno if it received the command packet or what. Ugh.\n")
			rescue StandardError => stdErr
				raise(UEIClientError, "\nERROR: Connection with the server was cut off or some fatal error occurred. " +
																			"Might want to check server logs. Error was:\n#{stdErr.message}\n")
			end
			if(payload.nil?) # then server half cut off
				raise(UEIClientError, "\nERROR: Connection with the server was cut off or some fatal error occurred. " +
																			"Might want to check server logs.\n")
			end
			payload.chomp!()
			payload.strip!()
			@socket.close() unless(@socket.nil? or @socket.closed?()) # can only issue 1 command!
			return payload
		end

	end # class UEIClientClient
end ; end # module BRL ; module UEI

# ##############################################################################
# When run on the command line, use as a user-tool:
# ##############################################################################
if(__FILE__ == $0)
	module RunUEIClient
		require 'getoptlong'

		COMMAND_LIST = ['--newUEIs', '--areAssigned', '--timeStamps']
		NEW_CMD = '--newUEIs'
		ASSIGNED_CMD = '--areAssigned'
		TIME_CMD = '--timeStamps'

		def RunUEIClient.processArguments
			progOpts =
				GetoptLong.new(
					['--newUEIs',       '-n', GetoptLong::OPTIONAL_ARGUMENT],
					['--areAssigned',		'-a', GetoptLong::OPTIONAL_ARGUMENT],
					['--timeStamps',    '-t', GetoptLong::OPTIONAL_ARGUMENT],
					['--port',					'-p', GetoptLong::OPTIONAL_ARGUMENT],
					['--host',				  '-o', GetoptLong::OPTIONAL_ARGUMENT],
					['--help',					'-h', GetoptLong::NO_ARGUMENT]
				)

			optsHash = progOpts.to_hash
			if(optsHash.key?('--help'))
				RunUEIClient.usage()
			end

			unless(optsHash.key?('--newUEIs') or optsHash.key?('--areAssigned') or optsHash.key?('--timeStamps'))
				RunUEIClient.usage("ERROR: you need to specify at least one of -n, -a, or -t and provide an argument for them.")
			end
			return optsHash
		end

		def RunUEIClient.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "

	PROGRAM DESCRIPTION:


		When run from the command line, tests the various class functions.

	COMMAND LINE ARGUMENTS:
		--newUEIs, -n          Optional. Request some # of new UEIs.
		--areAssigned, -a      Optional. Ask if uei is assigned (can be comma-separated list)
		--timeStamps, -t       Optional. Ask for timestamps of ueis (can be comma-separated list)
		--port, -p             Optional. Set the local port at which to start looking for a free port.
		                       Default is #{BRL::UEI::INIT_PORT}
		--host, -o             Optional. Set the host name of the machine running the
		                       UEI server. FQDN please. Defaults is #{BRL::UEI::DEF_HOST}.
		--help, -h             Flag. Print this help info.

	USAGE:
		ueiClient.rb
		ueiClient.rb --port 11456

	";
			exit(2);
		end
	end # module RunUEIClient

	# ############################################################################
	# MAIN
	# ############################################################################
	optsHash = RunUEIClient.processArguments()
	lclPort = BRL::UEI::INIT_PORT
  lclHost = BRL::UEI::DEF_HOST

	# Check optional args
	if(optsHash.key?('--port')) then lclPort = optsHash['--port'].to_i end
	if(optsHash.key?('--host')) then lclHost = optsHash['--host'].to_i end
	# Create client and connect
	ueiClient = BRL::UEI::UEIClient.new(lclPort, lclHost)

	# TEST COMMANDS
	RunUEIClient::COMMAND_LIST.each {
		|cmdStr|
		next unless(optsHash.key?(cmdStr))
		args = optsHash[cmdStr].split(',')
		case cmdStr
			when RunUEIClient::NEW_CMD
				ueiArray = ueiClient.getNewUEIs(args[0])
				resultStr = ueiArray.join("\n")
				puts "Your new ueis are:\n#{resultStr}"
			when RunUEIClient::ASSIGNED_CMD
				ueiHash = ueiClient.areAssigned(args)
				resultStr = ''
				ueiHash.each {
					|key, val|
					resultStr << "#{key} #{val}\n"
				}
				puts "The assignment statuses are:\n#{resultStr}\n"
			when RunUEIClient::TIME_CMD
				ueiHash = ueiClient.getTimeStamps(args)
				resultStr = ''
				ueiHash.each {
					|key, val|
					resultStr << "#{key} #{val}\n"
				}
				puts "The assignment statuses are:\n#{resultStr}\n"
			else
				RunUEIClient.usage("ERROR: can't figure out what command you wanted to run. What is '#{cmdStr}'?")
		end
	}
end # if(__FILE__ == $0)
