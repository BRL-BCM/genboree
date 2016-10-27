#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'socket'
require 'timeout'
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/pash/tcpActionControlledServer' # For any module/class vars we might need
require 'brl/pash/tcpActionControlledClient' # For the client class that does the commo work.
$VERBOSE = (ENV['RUBY_VERBOSE'] == 'true' ? true : (ENV['RUBY_VERBOSE'] == 'false' ? false : nil))

module AskActionServer
	# FUNCTION: processArguments
	# PURPOSE:	To read the command line arguments the user provided to our program
	#						and put them in to a convenient-to-use Hash object so we can get at
	#						the values.
	#	ARGUMENTS: None
	# RETURN VALUE: a Hash object, whose keys are the command line option names
	def AskActionServer.processArguments()
		# The GetoptLong library will help us with this task, if we tell it what options
		# we are looking for.
		progOpts =
			GetoptLong.new(
				['--doActionQuery', '-d',	GetoptLong::NO_ARGUMENT],
				['--finished', 			'-f',	GetoptLong::NO_ARGUMENT],
				['--shutdown',			'-s',	GetoptLong::NO_ARGUMENT],
				['--getCount',			'-c', GetoptLong::NO_ARGUMENT],
				['--reset',					'-r', GetoptLong::NO_ARGUMENT],
				['--newMax',        '-m', GetoptLong::OPTIONAL_ARGUMENT],
				['--host',					'-o', GetoptLong::OPTIONAL_ARGUMENT],
				['--port',					'-p', GetoptLong::OPTIONAL_ARGUMENT],
				['--help',					'-h', GetoptLong::NO_ARGUMENT]
			)
		optsHash = progOpts.to_hash		# Convert the GetoptLong object to a Hash
		# If the user didn't give any arguments or asked for help, print the usage info and exit
		usage() if(optsHash.empty? or optsHash.key?('--help'))
		# The user must one (and only one) of these options.
		numOpts = 0
		['--doActionQuery', '--finished', '--shutdown', '--getCount', '--reset', '--newMax'].each {
			|optStr|
			if(optsHash.key?(optStr))
				numOpts+= 1
				optsHash['cmdToExecute'] = optStr
			end
		}
		if(numOpts > 1)
			AskActionServer.usage("ERROR: Only 1 of these options: [-d, -f, -s, -c, -r, -m] can be specified at a time. Sorry, bye.")
		elsif(numOpts < 1)
			AskActionServer.usage("ERROR: You must specify 1 of these options [-d, -f, -s, -c, -r, -m, -h]. Sorry, bye.")
		end
		return optsHash
	end # def processArguments()

	# FUNCTION: usage()
	# PURPOSE:	Prints usage information on the screen.
	#	ARGUMENTS: an optional message string, which will be printed. Default is no message.
	# RETURN VALUE: none, program exits
	def AskActionServer.usage(msg='')			# if msg not provided, use empty message String as the default
		unless(msg.empty?)	# print the message if any
			puts "\n#{msg}\n"
		end
		# Print the following multi-line String to the screen
		puts "

    PROGRAM DESCRIPTION:
      Connects to a TCPActionControllerServer and performs a given command.
      The reply, if any  will be printed to stdout. In the case of fatal error, an
      error message is printed on stdout and the exit status is 4.

      For the --doActionQuery (-d) option flag, the exit status can be 3-fold:
        0  Yes, go ahead
        1  No, don't go ahead
        >1 Failure, a fatal error occurred (serious problem)

      That is to say: 'No' is not the same as 'Failure'.

      Only one of [-d, -f, -s, -c, -r, -m] may be specified. Please note that
      all these are flags except for -m (--newMax) which takes an argument.

    COMMAND LINE ARGUMENTS:
      --doActionQuery, -d  Flag. Ask server if it can do action.
                           Replies: 'YES:<oldCnt>' or 'NO:<currCnt>'
      --finished, -f       Flag. Tell server client is done doing action.
                           Replies: 'OK:<oldCnt>'
      --shutdown,  -s      Flag. Shutdown the server.
                           Replies: 'OK:<currCnt>'
      --getCount, -c       Flag. Get the current action count from the server.
                           Replies: 'OK:<currCnt>'
      --reset, -r          Flag. Reset the server's count.
                           Replies: 'OK:<oldCnt>'
      --newMax, -m         Set a new maximum count on the server.
                           Replies: 'OK:<oldMax>'
      --host, -o           Optional. Specify server host name (FQDN please).
                           Default is #{BRL::PASH::DEF_HOST}.
      --port, -p           Optional. Specify server port.
                           Default is #{BRL::PASH::INIT_PORT}.
      --help, -h           Print this usage info.

    EXAMPLE USAGE:
    askActionServer.rb -d
    askActionServer.rb -f -h 'my.specialServer.com' --port=34059

    ";

		# Quit the program
		exit(BRL::PASH::USER_EXIT);
	end

	# FUNCTION: dispatchCommand
	# PURPOSE:	Sends specified command to the server and deals with reply
	#						appropriately. Prints to stdout and exits with success or error
	#						error code, as appropriate.
	#	ARGUMENTS: an optional message string, which will be printed. Default is no message.
	# RETURN VALUE: none, program exits
	def AskActionServer.dispatchCommand(client, cmdToExecute, optsHash)
		begin
			case cmdToExecute
			when '-d', '--doActionQuery'
					reply = client.canDoAction?()
			when '-f', '--finished'
					reply = client.doneAction()
			when '-s', '--shutdown'
					reply = client.shutdownServer()
			when '-c', '--getCount'
					reply = client.getActionCount()
			when '-r', '--reset'
					reply = client.reset()
			when '-m', '--newMax'
					commandArgs = optsHash['--newMax']
					if(commandArgs.nil? or commandArgs.empty?)
							AskActionServer.usage("ERROR: if you want a new maximum count, you have to specify the maximum!")
					end
					reply = client.newMax(commandArgs)
			end
			if(reply =~ /^(?:#{BRL::PASH::YES_MSG}|#{BRL::PASH::OK_MSG})/)
				#puts "YES: please proceed with your action."
				reply.strip!()
				puts reply
				exit(BRL::PASH::YES_EXIT)
			elsif(reply =~ /^#{BRL::PASH::NO_MSG}/)
				#puts "NO: do not proceed with your action"
				reply.strip!()
				puts reply
				exit(BRL::PASH::NO_EXIT)
			else
				AskActionServer.fail(reply)
			end
#				when '-d', '--doActionQuery'
#					reply = client.canDoAction?()
#					reply.strip!()
#					if(reply =~ /^#{BRL::PASH::YES_MSG}/)
#						#puts "YES: please proceed with your action."
#						exit(BRL::PASH::YES_EXIT)
#					elsif(reply =~ /^#{BRL::PASH::NO_MSG}/)
#						puts "NO: do not proceed with your action"
#						exit(BRL::PASH::NO_EXIT)
#					else
#						AskActionServer.fail(reply)
#					end
#				when '-f', '--finished'
#					reply = client.doneAction()
#					if(reply =~ /^#{BRL::PASH::OK_MSG}/)
#						puts "OK: server acknowledges you are done."
#						exit(BRL::PASH::YES_EXIT)
#					else
#						AskActionServer.fail(reply)
#					end
#				when '-s', '--shutdown'
#					reply = client.shutdownServer()
#					if(reply =~ /^#{BRL::PASH::OK_MSG}/)
#						puts "OK: server is shutting down."
#						exit(BRL::PASH::YES_EXIT)
#					else
#						AskActionServer.fail(reply)
#					end
#				when '-c', '--getCount'
#					reply = client.getActionCount()
#					if(reply =~ /^#{BRL::PASH::OK_MSG}:(\d+)/)
#						actionCount = $1
#						puts "COUNT: #{actionCount}"
#						exit(BRL::PASH::YES_EXIT)
#					else
#						AskActionServer.fail(reply)
#					end
#				when '-r', '--reset'
#					reply = client.reset()
#					if(reply =~ /^#{BRL::PASH::OK_MSG}/)
#						puts "OK: resetting count to 0."
#						exit(BRL::PASH::YES_EXIT)
#					else
#						AskActionServer.fail(reply)
#					end
#				when '-m', '--newMax'
#					commandArgs = optsHash['--newMax']
#					if(commandArgs.nil? or commandArgs.empty?)
#							AskActionServer.usage("ERROR: if you want a new maximum count, you have to specify the maximum!")
#					end
#					reply = client.newMax(commandArgs)
#					if(reply =~ /#{BRL::PASH::OK_MSG}/)
#						puts "OK: new max action count is #{commandArgs}."
#						exit(BRL::PASH::YES_EXIT)
#					else
#						AskActionServer.fail(reply)
		rescue => err
			puts "\nFAILURE!\nSome fatal error occurred. More details/suggestions follow:\n\n#{err.backtrace}\n\n#{err.message}\n"
		end
	end # def dispatchCommand(cmdToExecute)

	# FUNCTION: fail
	# PURPOSE:	For semi-cleanliness. Prints standard failed-don't-understand-reply
	#						error message and exits.
	#	ARGUMENTS: none
	# RETURN VALUE: none, program exits
	def AskActionServer.fail(reply)
		puts "FAILURE! : Got a nonsensical reply '#{reply}'. Dunno what happened."
		exit(BRL::PASH::FATAL_EXIT)
	end
end # class AskActionServer

# ##############################################################################
# MAIN
#		Program will start running here!
# ##############################################################################
# Get the command line arguments to the program.
optsHash = AskActionServer.processArguments()		# Call the function (defined above) and save return value in a variable

# Figure out which host and port to use
host, port = BRL::PASH::DEF_HOST, BRL::PASH::INIT_PORT
if(optsHash.key?('--host'))
	host = optsHash['--host']
	host.strip!()
end
if(optsHash.key?('--port'))
	port = optsHash['--port']
	port.strip!().to_i
end

# Try to make a new client and connect it to the server:
client = nil
begin
	client = BRL::PASH::TCPActionControllerClient.new(port, host)
rescue StandardError => stdErr
	puts "\nFAILURE!\nCouldn't connect to remote server. The reason is explained in this detailed error message:\n\n#{stdErr.message}"
	exit(BRL::PASH::FATAL_EXIT)
end

# Fire off appropriate command and print reply message:
begin
	AskActionServer.dispatchCommand(client, optsHash['cmdToExecute'].strip, optsHash)
rescue StandardError => stdErr
	puts "\nFAILURE!\nCouldn't perform the command you requested. The reason is explained in the detailed error message:\n\n#{stdErr.message}"
	exit(BRL::PASH::FATAL_EXIT)
end

# DONE
