#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'socket'
require 'timeout'
require 'brl/util/util'					# for standard extensions of Ruby classes
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module BRL ; module PASH
	# SOME MODULE CONSTANTS
	INIT_PORT = 10395
	DEF_HOST = 'alanine.brl.bcm.tmc.edu'
	OK_REPLY, BAD_REPLY, DO_ACTION, DONE_ACTION, RESET, GET_ACTION_COUNT, SHUTDOWN_SERVER, NEW_MAX =
			0,1,2,4,8,16,32,64
	REPLY_TIMEOUT = 10
	YES_EXIT, NO_EXIT, USER_EXIT, FATAL_EXIT = 0,1,2,4
	YES_MSG, NO_MSG, OK_MSG = 'YES', 'NO', 'OK'

	# CLASS: TCPActionControllerError
	# PURPOSE: 	Represents anticipated errors that can happen within the methods of
	#					 	TCPActionControllerClient and TCPActionControllerServer
	class TCPActionControllerError < StandardError ; end

	# CLASS: TCPActionControllerClient
	# PURPOSE: 	Instances of this class can contact the TCPActionControllerServer
	#						and issue various requests. It does a bunch of error checking and
	#						raises errors when something goes wrong.
	class TCPActionControllerClient
		attr_accessor :port, :host
		attr_reader :socket

		# FUNCTION: initialize
		# PURPOSE:	Instantiates the client object and tries to connect to the server.
		#           Optionally takes the port and host name as arguments if you want
		#           to override the defaults.
		#	ARGUMENTS: [integer], [string]
		# RETURN VALUE: reference to a TCPActionControlledClient object.
		def initialize(port=BRL::PASH::INIT_PORT, host=BRL::PASH::DEF_HOST)
			@port, @host = port.to_i, host
			@host.strip!
			@host.gsub(/[a-zA-Z0-9_\.\-]/, '#') 	# replace bad chars in host name
			# Can throw error...we will catch typical ones
			begin
				@socket = TCPSocket.new(@host, @port)
			rescue SocketError => sockErr
				raise(TCPActionControllerError,
					"\nERROR: couldn't connect to a Server at '#{@host}:#{port}'. " +
					"Probably some problem with the host name '#{@host} (invalid characters replaced with '#').\n" +
					"The internal error message was:\n\t#{sockErr.message}\n\n")
			rescue SystemCallError => sysErr
				raise(TCPActionControllerError,
					"\nERROR: couldn't connect to a Server at '#{@host}:#{port}'. " +
					"Probably some problem with the port '#{@port}', maybe it's not the one the server is listening on, " +
					"or the server is not running at all.\nThe internal error message was:\n\t#{sysErr.message}\n\n")
			end
		end # def initialize(port=BRL::PASH::TCPActionControllerClient::INIT_PORT, host=BRL::PASH::TCPActionControllerClient::DEF_HOST, initCounter=0)

		# FUNCTION: close
		# PURPOSE:	Attempts to close the socket connection to the server.
		#	ARGUMENTS: none
		# RETURN VALUE: none
		def close()
			unless(@socket.nil?() or @socket.closed?())
				@socket.close()
			end
		end

		# FUNCTION: canDoAction?
		# PURPOSE:	Sends a query to the server asking if the action is allowed at
		#						this time. Takes an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: The server's reply to the query.
		def canDoAction?(replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			return self.sendCommand(BRL::PASH::DO_ACTION, replyTimeout)
		end

		# FUNCTION: doneAction
		# PURPOSE:	Sends a message to the server saying that the action is completed.
		#						Takes an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: The server's reply to the message.
		def doneAction(replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			return self.sendCommand(BRL::PASH::DONE_ACTION, replyTimeout)
		end

		# FUNCTION: reset
		# PURPOSE:	Sends a message to the server telling it to reset its counter to
		#           0. Takes an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: The server's reply to the message.
		def reset(replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			return self.sendCommand(BRL::PASH::RESET, replyTimeout)
		end

		# FUNCTION: newMax
		# PURPOSE:	Sends a message to the server telling it to use a new maximum
		#						number of actions. Also takes an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: integer, [integer]
		# RETURN VALUE: The server's reply to the message.
		def newMax(newMaximum, replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			commandArgs = [ newMaximum ]
			return self.sendCommand(BRL::PASH::NEW_MAX, replyTimeout, commandArgs)
		end

		# FUNCTION: getActionCount
		# PURPOSE:	Sends a query to the server asking for the current count.Takes
		#           an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: The server's reply to the query.
		def getActionCount(replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			return self.sendCommand(BRL::PASH::GET_ACTION_COUNT, replyTimeout)
		end

		# FUNCTION: shutdownServer
		# PURPOSE:	Sends a message to the server telling it to shutdown (exit).
		#						Server should be unresponsive after this, until restarted.
		#           Takes an optional timeout argument, the number of
		#						seconds to wait for a reply from the server before giving up.
		#	ARGUMENTS: [integer]
		# RETURN VALUE: The server's reply to the message.
		def shutdownServer(replyTimeout=BRL::PASH::REPLY_TIMEOUT)
			return self.sendCommand(BRL::PASH::SHUTDOWN_SERVER, replyTimeout)
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
		def sendCommand(command, replyTimeout, commandArgs=nil)
			if(@socket.nil? or @socket.closed?())
				raise(TCPActionControllerError, "\nERROR: Socket not connected to a server for some reason? Very odd.\n\n")
			end
			case command
				when	BRL::PASH::DO_ACTION,
							BRL::PASH::DONE_ACTION,
							BRL::PASH::RESET,
							BRL::PASH::GET_ACTION_COUNT,
							BRL::PASH::SHUTDOWN_SERVER
					@socket.print("#{command}\r\n")
				when	BRL::PASH::NEW_MAX
					if(commandArgs.nil? or commandArgs.empty?)
						raise(TCPActionControllerError, "\nERROR: if you want a new maximum count, you have to specify the maximum! (sendCommand called without commandArgs)\n\n")
					end
					@socket.print("#{command}:#{commandArgs[0]}\r\n")
				else
					raise(TCPActionControllerError, "\nERROR: Asked to send invalid command number '#{command}'\n\n")
			end

			payload = ''
			begin
				status = timeout(replyTimeout) {
					payload = @socket.gets
				}
			rescue TimeoutError => timeErr
				raise(TCPActionControllerError, "\nERROR: Sorry, server didn't reply within #{replyTimeout} seconds. " +
																				"Dunno if it received the command packet or what. Ugh.\n")
			rescue StandardError => stdErr
				raise(TCPActionControllerError, "\nERROR: Connection with the server was cut off or some fatal error occurred. " +
																				"Might want to check server logs.\nThe following Standard Error occured:\n'#{stdErr.message}'\n'#{stdErr.backtrace}'")
			end
			if(payload.nil?) # then server half cut off
				raise(TCPActionControllerError, "\nERROR: Connection with the server was cut off or some fatal error occurred. " +
																				"Might want to check server logs.\nThe payload was nil! Status: '#{status}'")
			end
			payload.chomp!()
			payload.strip!()
			if(payload =~ /^(?:#{BRL::PASH::OK_REPLY}|#{BRL::PASH::BAD_REPLY}):(.*)$/)
				message = $1
				message.strip!();
				return message
			else
				raise(TCPActionControllerError, "\nERROR: Received bad reply from server. Maybe it's not a TCPActionControllerServer listening " +
				                                "at '#{@host}:#{port}'? I expected a reply beginning with '#{BRL::PASH::OK_REPLY}:' but I got back #{payload}\n\n")
			end
			@socket.close() unless(@socket.nil? or @socket.closed?()) # can only issue 1 command!
		end
	end # class TCPActionControllerClient
end ; end # module BRL ; module PASH
