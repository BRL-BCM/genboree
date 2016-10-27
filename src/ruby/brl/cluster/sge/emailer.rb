#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################

#require 'brl/genboree/genboreeUtil'

require 'brl/genboree/dbUtil'
require 'brl/util/emailer'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobUtils'
require 'brl/cluster/clusterJobRunner'

require 'getoptlong'

module BRL
module Cluster
  class Emailer
    
    def initialize(optsHash)
      @optsHash = optsHash
      setParameters()
    end

    def setParameters()
      @subject = @optsHash['--subject']
      @from = @optsHash['--from']      
      @to = @optsHash['--to']
      @body = @optsHash['--body']      
    end

    def work()
      begin
      @genbConf = BRL::Genboree::GenboreeConfig.load
      email = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      # Set From:, To:, Subject:
      email.setHeaders(@from, @to, @subject)

      # Now set who to send the email as (a valid user at the SMTP host)
      email.setMailFrom(@from)

      # Now add user(s) who will receive the email.
      email.addRecipient(@to)

      # Add the body of your email message
      email.setBody(@body)
      email.send()
        rescue => @err
          $stderr.puts @err
          $stderr.puts @err.backtrace
        end
        return true
    end
    
    def Emailer.processArguments()
      optsArray = [ ['--subject',     '-s', GetoptLong::REQUIRED_ARGUMENT],       
                  ['--from',    '-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--to',    '-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--body',    '-b', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help','-h',GetoptLong::OPTIONAL_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      if(optsHash.key?('--help')) then
        Emailer.usage()
        @@argumentsOk = false
      end

      unless(progOpts.getMissingOptions().empty?)
        Emailer.usage("USAGE ERROR: some required arguments are missing")
        @@argumentsOk = false
      end
      if(optsHash.empty?) then
        Emailer.usage()
        @@argumentsOk = false
      end
      return optsHash
    end

    def Emailer.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "PROGRAM DESCRIPTION:
          This ruby script is invoked as a command line tool to send an email.
          
            
          COMMAND LINE ARGUMENTS:
            -s or --subject     => This flag is required and should be followed by the CGI Escaped subject of the email
            -f or --from        => This flag is required and should be followed by the sender of the email
            -t or --to          => This flag is required and should be followed by the email address of the recipient
            -b or --body        => This flag is required and should be followed by the CGI Escaped body of the email
            
            
          USAGE:
          ./emailer.rb -s cluster%20Job%20123 -f genboree_admin@bcm.edu -t raghuram@bcm.edu -b Thank%20you"
      exit(2);
    end
  end


########################################################################################
# MAIN
########################################################################################

  # Process command line options
  optsHash = Emailer.processArguments()
  emailer = Emailer.new(optsHash)
  emailer.work()


end
end # module BRL ; module Cluster ;

