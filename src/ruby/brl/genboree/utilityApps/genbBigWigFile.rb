#!/usr/bin/env ruby

require 'brl/util/emailer'
require 'brl/genboree/abstract/resources/ucscBigFile'
require 'brl/genboree/abstract/resources/wigFile'

module BRL ; module Genboree
  # See the command help notes below in usage() for information about this command
  # This class should contain all the 'wig' specific methods
  #
  # All functionality that is common to the bigBed process is defined in UCSCBigFileConverter
  #
  #
  class GenbBigWigFile < BRL::Genboree::Abstract::Resources::UCSCBigFileConverter
    def initialize(optsHash)
      $stderr.puts "STATUS: init"
      super(optsHash)
      @fileType = 'bigWig'
      # The command name of that converts the wig file to bigWig format
      @bigFileName = optsHash['--bigWigFileName']
      @txtFileName = "task_#{@taskId}.wig"
      @chrSizesFileName = "task_#{@taskId}.chr.sizes"
      @converterName = 'wigToBigWig'
      @converterOutFileName = "#{@converterName}_task_#{@taskId}.out"
      @converterErrFileName = "#{@converterName}_task_#{@taskId}.err"
      @msgFileName = "genbBigWigFile_task_#{@taskId}.msg"
      @logFileName = "genbBigWigFile_task_#{@taskId}.log"
      @jobSubmittedFlagFileName = 'bigWig.jobSubmitted'
      $stderr.puts "STATUS: init done"
    end

    # Requires @ftypeAttributesHash to determine if the track is hdhv
    def getAnnoFileObj()
      $stderr.puts "STATUS: start getting file object"
      # Use fixedStep for hdhv tracks because the wig file is smaller
      # but fdata2 tracks can only use variable step.
      if(@ftypeAttributesHash['gbTrackRecordType'].nil?)
        wigFileObj = BRL::Genboree::Abstract::Resources::VWigFile.new(@dbu, @txtFileName)
      else
        wigFileObj = BRL::Genboree::Abstract::Resources::FWigFile.new(@dbu, @txtFileName)
      end
      $stderr.puts "STATUS: done getting file obj"
      return wigFileObj
    end

    def makeMessageBody()
      # Determine if the file creation was successful or not
      if(@converterStatus and File.exists?(@bigFileName)) # and @errBuffer.length == 0) # ARJ <= @errBuffer ends up with debug output from wig file download and other stuff, can't check length
        @hostname = '<servername>' if(@hostname.nil?)
        @gbKey = 'xxxxxxxx' if(@gbKey.nil?)
        body = "GENBOREE NOTICE: BigWig file created.\n\n"
        body << "This email is to confirm that your request to create the bigWig file for the following resource is complete\n"
        if(@groupName and @refSeqName and @trackName)
          body << "Group: #{@groupName}\n"
          body << "Database: #{@refSeqName}\n"
          body << "Track: #{@trackName}\n\n"
          body << "You can retrieve the bigWig file using the API resource URL:\n"
          body << "http://#{@hostname}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@refSeqName)}/trk/#{Rack::Utils.escape(@trackName)}/bigWig\n\n"
          body << "At the end of the following URL, If the gbKey is 'xxxxxxxx', replace it with the 'real' gbKey after unlocking the database\n"
          body << "http://#{@hostname}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@refSeqName)}/trk/#{CGI.escape(@trackName)}/bigWig?gbKey=#{CGI.escape(@gbKey)}\n\n"
          body << "If unlocked, use this link to view the track in the UCSC browser.  Be sure to use the correct gbKey.\n"
          customText = "http://#{@hostname}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@refSeqName)}/trk/#{CGI.escape(@trackName)}?gbKey=#{CGI.escape(@gbKey)}&format=ucsc_browser&ucscType=bigWig&ucscSafe=on"
          body << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{@genomeTemplate}&hgct_customText=#{CGI.escape(customText)}\n\n"
          body << "Or view all the bigWig tracks for this database in the UCSC browser.  Be sure to use the correct gbKey.\n"
          customText = "http://#{@hostname}/REST/#{BRL::REST::Resource::VER_STR}/grp/#{CGI.escape(@groupName)}/db/#{CGI.escape(@refSeqName)}/trks?gbKey=#{CGI.escape(@gbKey)}&format=ucsc_browser&ucscType=bigWig&ucscSafe=on"
          body << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{@genomeTemplate}&hgct_customText=#{CGI.escape(customText)}\n"
        elsif(@refSeqId and @ftypeId )
          body << "refSeqId: #{@refSeqId}\n"
          body << "ftypeId: #{@ftypeId}\n"
        end
      else
        body = "GENBOREE NOTICE: BigWig file NOT created.\n\n"
        body << "There were errors trying to create the bigWig file for the following resource.\n"
        if(@groupName and @refSeqName and @trackName)
          body << "Group: #{@groupName}\n"
          body << "Database: #{@refSeqName}\n"
          body << "Track: #{@trackName}\n\n"
        end
        body << "\n\nERRORS from UCSC (wigToBigWig):\n"
        @errBuffer.rewind
        @errBuffer.each { |line|
          body << line
        }
        body << "\n\nSTDOUT:\n"
        @outBuffer.rewind
        @outBuffer.each { |line|
          body << line
        }
      end
      return body
    end

    def GenbBigWigFile.processArguments()
      optsArray = [
                    ['--bigWigFileName', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--track', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--genbConf', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--genboreeGroup', '-g', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--genboreeDatabase', '-d', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--archiveSrc', '-z', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--taskId', '-y', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--deleteSrc', '-x', GetoptLong::NO_ARGUMENT],
                    ['--email', '-e', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--hostname', '-n', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--noLock', '-l', GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      GenbBigWigFile.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      GenbBigWigFile.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    def GenbBigWigFile.usage(msg='')
      puts "\n#{msg}\n" unless(msg.empty?)
      puts "

      PROGRAM DESCRIPTION:

        Create a bigwig file from a Genboree database for a track.  Specify
        the group name and database name and track name (-g -d -t).

        BigWig files are generated from Wig files.  They are an indexed binary
        version of the wig data which can be used by UCSC to quickly query
        large data sets

        For more detail about bigwig files, go here:
        http://genome.ucsc.edu/goldenPath/help/bigWig.html

        This command will do the following
          - Write the wig file to disk for the specified database and track.
          - once the wig file is written and closed, execute the
            wigToBigWig convertor.
          - once conversion is complete, the source files, and log files are
            zipped or deleted depending on command line options specified.

      IMPLEMENTED FOR:
        This command is wrapped with GenbTaskWrapper and executed by a
        PUT request to the bigWig API resource
        See ... for more detail.

      COMMAND LINE ARGUMENTS:

      --bigWigFileName        |   -b    => The name of the bigwig file that will
                                           be created. Full path.
      --track                 |   -t    => [optional] Track Name (URL escaped)
      --genboreeGroup         |   -g    => [optional] Genboree Group, must
                                           be used with --genboreeDatabase
      --genboreeDatabase      |   -d    => [optional] Genboree Database (refname),
                                           must be used with --genboreeGroup
      --genbConf              |   -c    => [optional] Name of Genboree config file to use.
                                           Defaults to GENB_CONFIG environmental
                                           variable. But -some- config file must
                                           be found!
      --dbrcKey               |   -k    => [optional] Override the dbrcKey in the
                                           config file and use this key instead.
                                           Will still look in the .dbrc file listed
                                           under the dbrcFile in the config file.
      --archiveSrc            |   -z    => [optional] Archive the source files
                                           (wig, chr.sizes)
      --taskId                |   -y    => [optional] The taskId. Used by
                                           genbTaskWrapper.
      --deleteSrc             |   -x    => [optional flag] Delete the source files
                                           (wig, chr.sizes)
      --email                 |   -e    => [optional] Sends a confirmation email
                                           to the address specified
      --hostname              |   -n    => [optional] Name of the server where the
                                           file will reside. Used in email.
      --noLock                |   -l    => Don't use the lockfile which limits the
                                           number of simultaneous jobs on the system
      --help                  |   -h    => [optional flag] Output usage
                                           info and exit.

        USAGE:
        genbBigWig.rb -b file.bb -r 123 -f 4
        genbBigWig.rb -b file.bb -g myGroup -d myDatabase -t Known%3AGene
      "
      exit(BRL::Genboree::USAGE_ERROR)
    end

  end

end ; end

# --------------------------------------------------------------------------
# MAIN (command line execution begins here)
# --------------------------------------------------------------------------
begin
  # process args
  optsHash = BRL::Genboree::GenbBigWigFile.processArguments()
  # instantiate
  bigWigObj = BRL::Genboree::GenbBigWigFile.new(optsHash)
  # call
  bigWigObj.run
  exitVal = BRL::Genboree::OK
rescue => err
	errTitle =  "(#{$$}) #{Time.now()} GenbBigWigFile - FATAL ERROR: Couldn't create file for some reason. Exception listed below."
	errstr   =  "   The error message was: '#{err.message}'.\n"
	errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
	$stderr.puts errTitle + errstr
	exitVal = BRL::Genboree::FATAL
ensure
	# close any open files
	if(!bigWigObj.nil?)
    bigWigObj.finish()
	end
  $stdout.close()
  $stderr.close()
end

exit(exitVal)
