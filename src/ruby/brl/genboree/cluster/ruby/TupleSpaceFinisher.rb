#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'rinda/tuplespace'
require 'brl/util/emailer'

class TupleSpaceFinisher
  DEBUG = true
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
      ts = DRbObject.new(nil, "druby://#{tupleSpaceServer}:#{tupleSpaceServerPort}")
      $stderr.puts "#{ts} #{ts.class}"
      begin
          #tuple = ['exitStatus', nil, nil, nil, nil, nil, nil]
         tuple = ['exitStatus', nil, nil, nil, nil, nil, nil, nil]
        # tuple = [nil, nil, nil, nil, nil, nil, nil, nil, nil]
        
        answer = ts.take(tuple, 5)
        $stderr.puts "#{tuple}"
        if (answer.nil?) then
          next
        end
        answer.each {|k,v|
          $stderr.puts "k=#{k} v=#{v}"
        }
        jobName = answer[2]
        notificationEmail  = answer[5]
        $stderr.puts "job type #{answer[1]} job name #{jobName} start time #{answer[3]}, stop time #{answer[4]}, email address #{notificationEmail} email message #{answer[6]} exit status #{answer[7]}"
		
		email = BRL::Util::Emailer.new() # uses BCM smpt host/port by default
		# Set what lay people think of as the email "headers"
		# (what -appears- in From:, To:, Subject:)
		# Note: you can also override the Date: header as the 4th arg...defaults
		# to right now
		email.setHeaders("cluster@genboree.org", "manuelg@bcm.edu", "Your job #{jobName} execution status")
		# Now set who to send the email as (must be valid user at the
		# host)...this is NOT NECESSARILY the same as the "From:" header; i.e.
		# you can do simple spoofing by making them different
		email.setMailFrom("coarfa@bcm.edu")
		# Now add user(s) who will receive the email. Again, this is
		# not necessarily the same as what appears in the To: header
		email.addRecipient("#{notificationEmail}")
		# Add the body of your email message
		email.setBody("Your job started at #{answer[3]} and completed at #{answer[4]}. The exit status was #{answer[7]}")
		# Send email
		email.send()
      rescue Exception => e
        puts e.message
      end  
    end
  end
  
  def TupleSpaceFinisher.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--serverURI',       '-s', GetoptLong::OPTIONAL_ARGUMENT],
									['--propertiesFile',  '-p', GetoptLong::OPTIONAL_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		TupleSpaceFinisher.usage() if(optsHash.key?('--help'));
		
		
		unless(progOpts.getMissingOptions().empty?)
			TupleSpaceFinisher.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		#TupleSpaceFinisher.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def TupleSpaceFinisher.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Runs a tuple space Finisher.

COMMAND LINE ARGUMENTS:
  --serverURI        | -s   => server URI (to be deprecated)
  --propertiesFile   | -p   => properties file, containing server information and job types served by current node)
  --help             | -h   => [optional flag] Output this usage info and exit

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
optsHash = TupleSpaceFinisher.processArguments()
# Instantiate analyzer using the program arguments
tupleSpaceFinisher = TupleSpaceFinisher.new(optsHash)
# Analyze this !
tupleSpaceFinisher.work()
exit(0);
