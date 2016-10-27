#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/genboree/dbUtil'
require 'brl/util/emailer'
require 'getoptlong'
require 'open4'
    # == Overview
    # This ruby scipt serves as a command line tool that can be invoked in order to submit a job for running on the cluster
    # to the scheduler. The details of the job are specified as arguments following appropriate command line flags. The aspects of the job
    # which can be specified are:
    #   The required input files
    #   The list of commands to be run
    #   The list of resources necessary for the job
    #   The output directory where results are to be transferred
    #   Whether the temporary directory used for job execution should be retained
    #   The email to which information about the job execution must be sent
    class CommandWrapper

      def initialize(optsHash)
        @optsHash = optsHash
        setParameters()
      end

      def setParameters()
        @inputFile = @optsHash['--inputFile']
        @email = @optsHash['--email']
        @jobName = @optsHash['--jobName']
        @outLog = ""
        @errLog = ""
        initStdStreams()
      end

      def initStdStreams()
        # Close & promote gc
        @si = nil
        @so.close if(@so.respond_to?(:close))
        @so = nil
        @se.close if(@se.respond_to?(:close))
        # Create as in-memory io streams:
        @so = StringIO.new()
        @se = StringIO.new()
      end

      def work()
        @errNo = 0
        @errMsg = ""
        fh = File.open(@inputFile,"r")
        fh.each_line { |cmd|
            cmd.chomp!
            # First, have to ensure our in-memory io streams for stdout and stderr have been cleared.
            # Else they'll have stuff from previous command.
            initStdStreams()
            # Run command, capturing output
            status = Open4::spawn(cmd, :stdout => @so, :stderr => @se, :quiet => true, :raise => false)
            # We want to keep the stdout and stderr of all commands
            # - we'll divide each command's streams with -----
            @outLog << "\n#{('-'*50)}\n" unless(fh.lineno <= 1)
            @outLog << @so.string
            @errLog << "\n#{('-'*50)}\n" unless(fh.lineno <= 1)
            @errLog << @se.string
            if(status.nil?)
              @errNo = -1 # No valid errNo in this case
              @errLog << "ERROR: CommandWrapper: Command not found or similar error trying to spawn() this command:\n  '#{cmd.inspect}'"
            elsif(status.exitstatus != 0)
              @errNo = status.exitstatus
              @errLog << "ERROR: CommandWrapper: Command failed with non-zero exitstatus '#{cmd.inspect}'"
            end
        }
        fh.close

        ofh = File.open("#{@jobName}.out","w")
        ofh.puts @outLog
        ofh.close

        efh = File.open("#{@jobName}.error","w")
        efh.puts @errLog
        efh.close

        sendEmail
        return @errNo
      end

      def sendEmail
        email = BRL::Util::Emailer.new()
        subjectTxt = ""
        bodyTxt = ""
        if(@errNo != 0)
          subjectTxt = "BRL Cluster: #{@jobName} did not finish succesfully"
        else
          subjectTxt = "BRL Cluster: #{@jobName} completed succesfully"
        end
          email.setHeaders('raghuram@bcm.edu', @email, subjectTxt)
          email.setMailFrom('raghuram@bcm.edu')
          email.addRecipient(@email)
          if((@errNo != 0))
            bodyTxt = "Your job #{@jobName} did not finish succesfully\n\n"
            bodyTxt += "The job errored out with the following message:\n"
            bodyTxt += @errMsg
            bodyTxt += "\n"
          else
            bodyTxt += "Your job #{@jobName} completed succesfully!\n"
          end
          bodyTxt += "\nThe standard output stream of the job was:\n"
          bodyTxt += @outLog
          bodyTxt += "\n"
          bodyTxt += "\nThe standard error stream of the job was:\n"
          bodyTxt += @errLog
          email.setBody(bodyTxt)
          email.send()
      end

      def CommandWrapper.processArguments()
        optsArray = [
          ['--inputFile',  '-i', GetoptLong::REQUIRED_ARGUMENT],
          ['--email', '-e', GetoptLong::REQUIRED_ARGUMENT],
          ['--jobName','-j', GetoptLong::REQUIRED_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        if(optsHash.key?('--help')) then
          CommandWrapper.usage()
        end

        unless(progOpts.getMissingOptions().empty?)
          CommandWrapper.usage("USAGE ERROR: some required arguments are missing")
        end
        if(optsHash.empty?) then
          CommandWrapper.usage()
        end
        return optsHash
      end

      def CommandWrapper.usage(msg='')
        unless(msg.empty?)
          puts "\n#{msg}\n"
        end
        puts "PROGRAM DESCRIPTION:
        This ruby script is invoked as a command line tool in a programmatic context to submit a job for running on the cluster to the scheduler.
        This script accepts command line arguments and flags that allow full specification of all aspects of the job to be run on the cluster

        COMMAND LINE ARGUMENTS:
        -k or --keepDir         => This flag is optional and does not require arguments. If specified,
        the temporary directory used for job execution on the cluster will not be deleted.
        By default (flag not specified) the directory will be deleted
        -o or --outputDir       => This flag is required and should be followed by the output directory into which the results of
        the job should be copied. This directory should be specified in the rsync format hostname:dirname/
        -e or --email           => This flag is required and should be followed by the email to which notifications about the job should be sent
        -c or --commands        => This flag is required and should be followed by a list of commands to be executed on the cluster
        -i or --inputFiles      => This flag is optional and if used should be followed by a list of input files to be copied over to the temporary
        working directory for succesful execution of the commands that constitute the job.
        -r or --resources       => This flag is optional and if present should be follwed by a comma separated list of
        cluster resources being requested as name value pairs -- name1=value1, name2 =value2
        -j or --jsonFile        => This optional flag specifies the file containing the json formatted string that specifies any
        environment variables or genboree config variables that need to be altered before job execution
        -p or --resourcePaths   => This optional flag is used to specify a resource identifier string for this job which can be used to track resource usage
        -l or --outputFileList  => Output files requiring special handling that need to be moved to a different place can be specified using this optional flag.
        The 'rest' of the output files go to the default output dir.
      --jobName               => This optional flag is to be used only in the rare case when the job name needs to be pre-specified. In this case the scheduler will not
        auto-generate a job name
        USAGE:
        ./clusterJobScheduler.rb -o brl3.brl.bcm.tmc.edu:/usr/local/brl/home/raghuram/ -e raghuram@bcm.edu -c date"
        exit(2);
      end
    end


    ########################################################################################
    # MAIN
    ########################################################################################

    # Process command line options
    optsHash = CommandWrapper.processArguments()
    commandWrapper = CommandWrapper.new(optsHash)
    status=commandWrapper.work().to_i
    exit(status)
# module BRL ; module Cluster ;
