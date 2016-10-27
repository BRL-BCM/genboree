#!/usr/bin/env ruby
require 'json'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/fileFormats/trackImporter/trackImporter.utility'

# == Overview.
# This class imports information from the several databases to Genboree. This process
# includes downloading, converting, validating, and uploading. At the end of the
# process an email summary is sent to the user.
#
# ==  Notes
# This program currently imports a subset of the total tables available. More
# engines can be written to provide greater coverage.
#
module BRL; module TrackImporter
    class ImporterClass
      # CONSTRUCTOR. Creates an instance of the importer class and completes the
      # initial configuration.
      #
      # [+optsHash+]  A set of configuration variables.
      #               * --workingDir  = directory to work in
      #               * --masterKeys  = keys deliminated by ,
      #               * --refSeqId  = RefSeqId to import into
      #               * --userId  = user running the command
      #               * --email  = email address to send the results to
      #               * --deleteWhenDone  = Whether to clean up or not afterwards
      # [+returns+]   Instance of +ImporterClass+
      def initialize(optsHash)
        @optsHash = optsHash
        setParameters()
        @genbConf = BRL::Genboree::GenboreeConfig.load()
      end

      # Converts the track data and uploads it into Genboree.  By completing the
      # following steps
      # * Finish Setting up the environment and
      # * Gather the information from the Keys passed in
      # * Run the proper engine for converting the information
      # * Gather the results of each conversion engine
      # * Email the results to the user
      # [+returns+] nothing
      def run()
        begin

          puts("Setting Up Environment")
          #Set up lock
        #  @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:otherGenbDb)
        #  @dbLock.getPermission()

          # Set up the working environment and variables
          homeDir = Dir.getwd
          Dir.chdir(@workingDir)
          @keysToRun = Array.new
          @keysToRun =@masterKeys.split(",")
          splitDir = @workingDir.split("/")
          @jobID = splitDir[splitDir.size - 1]
          @dbrc = @optsHash["--dbrcKey"]
          @buildVersion = @buildVersion.downcase
          puts @genbConf.gbResourcesDir

          keysFileName = "#{@genbConf.gbResourcesDir}/importer/#{@buildVersion}/trackImporter.info"

          @dbu =  BRL::Genboree::DBUtil.new(@dbrc, nil, nil)
          #@group = @dbu.selectGroupById(@optsHash["--groupId"])[0]['groupName']
          #@database = @dbu.selectRefseqById(@optsHash["--refSeqId"])[0]['refseqName']
          @groupName = @dbu.selectGroupByName(@optsHash["--groupId"])[0]['groupId']
          @databaseName = @dbu.selectRefseqByName(@optsHash["--refSeqId"])[0]['refSeqId']

          @group = @groupName
          @database = @databaseName

          @groupName = @optsHash["--groupId"]
          @databaseName = @optsHash["--refSeqId"]




          @results = Hash.new()
          keysFile = BRL::Util::TextReader.new(keysFileName)
          keyList = Hash.new
          # Loop through keys
          keysFile.each { |line|
            arrSplit = line.strip.split(/\t/)
            key = arrSplit[0]
            if(key !~ /^#/) then
              keyList[key] = arrSplit
            end
          }
          noKeys = true
           @keysToRun.each{|key|
            if(keyList.has_key?(key)) then
              puts "Found key #{key}"
              noKeys = false
              arrSplit = keyList[key]
              nameObjName = @dbu.getUserByName(@optsHash["--userId"])[0]
              nameObj = nameObjName
              nameObjName = @optsHash["--userId"]

              name = nameObj["name"]
              password = nameObj["password"]

              trackData = BRL::TrackImporter::Utility::arrayToTrackData(arrSplit)
              #trackData[:userId] = @optsHash['--userId']
              #trackData[:refSeqId] = @optsHash['--refSeqId']
              trackData[:userId] = nameObjName
              trackData[:refSeqId] = @databaseName
              trackData[:password] = password
              trackData[:groupId] = @groupName
              trackData[:host] = @optsHash['--host']


              #Custom Class, Type and Subtype
              lffTypeSubTypedata = getClassification(arrSplit)
              trackData[:lffType] = lffTypeSubTypedata[0]
              trackData[:lffSubType] = lffTypeSubTypedata[1]

              if(trackData.overideLFFClass != ".")
                trackData[:lffClass] = trackData.overideLFFClass
              end
              if(trackData.overideLFFType != ".")
                trackData[:lffType] = trackData.overideLFFType
              end
              if(trackData.overideLFFSubType != ".")
                trackData[:lffSubType] = trackData.overideLFFSubType
              end
              trackData[:configFile] = @buildVersion + "/" + trackData.configFile
              #Select Proper Engine
              begin

                fileName = trackData.engine
                fileName = fileName[0,1].downcase + fileName[1, fileName.length]

                require "brl/fileFormats/trackImporter/trackImporter.#{fileName}"
                engine = Object.const_get("BRL").const_get("TrackImporter").const_get(trackData.engine).new()
                returnArray = engine.run(trackData)

              rescue StandardError => bang
                $stderr.puts("ERROR in trackImporter.importer - " + bang)
                $stderr.puts(bang.backtrace.join("\n"))
                returnArray = [-1, "Error launching engine", "Unable to launch engine #{trackData.engine}"]
              end

              trackData[:exitCode] = returnArray[0]
              trackData[:error] = returnArray[1]
              trackData[:message] = returnArray[2]
              trackData[:host] = @optsHash["--host"]
              #Place the time stamp
              track = "#{trackData.lffType}:#{trackData.lffSubType}"
              #nameObj = @dbu.getUserByUserId(@optsHash["--userId"])[0]
              nameObjName = @dbu.getUserByName(@optsHash["--userId"])[0]
              nameObj = nameObjName
              nameObjName = @optsHash["--userId"]

              name = nameObj["name"]
              password = nameObj["password"]
              #Add a time stamp to each track to keep track of when it was last imported
              timeStamp(track, name, password)

              #Send an email for each track that is run
              trackEmail(track, trackData)

              @results[key] = trackData
            else
              puts "Did not find key #{key}"
            end
          } #End Loop through Keys
          keysFile.close

          #Email
          finalEmail()
          if(!noKeys) then
           #Cleanup
          Dir.chdir(homeDir)
          if(!@deleteWhenDone.nil?)
            puts("Deleting Working Directory")
            FileUtils.rm_rf(@workingDir)
          else
            puts("Compressing Working Directory")
            `gzip #{@workingDir}/*`
          end
        end
        rescue StandardError => bang
          $stderr.puts("ERROR in trackImporter.importer - " + bang)
          $stderr.puts(bang.backtrace.join("\n"))
        ensure
          # When done, release the permission so someone else can run:
         # @dbLock.releasePermission()
        end
      end

      # Process the arguments that have been passed in and makes sure the required
      # ones are met.
      # [+returns+]   nothing
      def ImporterClass.processArguments()
        # We want to add all the prop_keys as potential command line options
        optsArray = [
          ['--workingDir',        '-w', GetoptLong::REQUIRED_ARGUMENT],
          ['--masterKeys',         '-k', GetoptLong::REQUIRED_ARGUMENT],
          ['--refSeqId',      '-r', GetoptLong::REQUIRED_ARGUMENT],
          ['--userId',   '-u', GetoptLong::REQUIRED_ARGUMENT],
          ['--groupId', '-g', GetoptLong::REQUIRED_ARGUMENT],
          ['--email',    '-e', GetoptLong::REQUIRED_ARGUMENT],
          ['--deleteWhenDone',   '-d', GetoptLong::NO_ARGUMENT],
          ['--buildVersion',   '-v', GetoptLong::REQUIRED_ARGUMENT],
          ['--host' , '-H',  GetoptLong::REQUIRED_ARGUMENT],
          ['--dbrcKey' ,'-D', GetoptLong::REQUIRED_ARGUMENT],
          ['--help',         '-h', GetoptLong::NO_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        ImporterClass.usage() if(optsHash.key?('--help'));

        unless(progOpts.getMissingOptions().empty?)
          ImporterClass.usage("USAGE ERROR: some required arguments are missing")
        end

        ImporterClass.usage() if(optsHash.empty?);
        return optsHash
      end

      # Displays a message to a user if either the required variables are missing or
      #  the help command line argument is raised
      # [msg]         [optional; default=''] The message to display to the user
      # [+returns+]   nothing
      def ImporterClass.usage(msg='')
        unless(msg.empty?)
          puts("\n#{msg}\n")
        end
        puts "
  PROGRAM DESCRIPTION:
    The Track importer serves as a command line interface to allow the
    importation of files from the several databases. It downloads, converts,
    validates, and then uploads the requested information to a requested
    Genboree database. The program will then send an email to the provided email
    address that the task either failed or was successful.

    COMMAND LINE ARGUMENTS:
      -w    => Directory to work in
      -k    => Keys from the import list
      -r    => database name of the user database
      -u    => User name of the requester
      -g    => Group name of the database
      -e    => Email address to send the fail/success email
      -v    => Build Version
      -d    => Specify to delete the working directory
      -H    => host name
      -D    => dbrc Key
      -h    => [optional flag] Output the help info and exit.

    USAGE:
    trackImporter.importer.rb -w workingdir -k hapmapAllelesMacaque -r 12345 -u 12345 -g 12345 -e yourname@email.com -d";
        exit(134);
      end

      # ########################################################################
      private #Methods
      # ########################################################################

      # Takes the parameters that have been passed in and turns them into class
      #  variables
      # [+returns+]   nothing
      def setParameters()
        @workingDir = @optsHash['--workingDir']
        @masterKeys = @optsHash['--masterKeys']
        @refSeqId = @optsHash['--refSeqId']
        @userId = @optsHash['--userId']
        @groupId = @optsHash['--groupId']
        @email = @optsHash['--email']
        @buildVersion = @optsHash['--buildVersion']
        @deleteWhenDone = @optsHash['--deleteWhenDone']
      end

      # Sets the Type, and Subtype
      # [+arguments+] Argument Array with raw data
      # [+returns+] Array with the Type and Subtype
      def getClassification(arguments)
        type = arguments[3];
        subType = arguments[4];

        if(type.length + subType.length > 18)
          type = /^(\S+)(.+)$/.match(arguments[3])[1].strip
          subType = /^(\S+)(.+)$/.match(arguments[3])[2].strip

          if(subType.length <= 1)
            type = /^(\S+)(.+)$/.match(arguments[4])[1].strip
            subType = /^(\S+)(.+)$/.match(arguments[4])[2].strip
          end

          if(type.include?(" "))
            type = type.split(" ")[0]
          end

          if(subType.include?(" "))
            subType = subType.split(" ")[0]
          end

          if(type.length + subType.length > 18)
            if(type.length > subType.length)
              newLength = 18 - subType.length
              type = type[0, newLength]
            else
              newLength = 18 - type.length
              subType = subType[0, newLength]
            end
          end
        end
        [type, subType]
      end

      # Emails the user with the results of conversion
      # [+returns+]   nothing
      def finalEmail()
        puts("Emailing User")

        # Create an emailer instance, using the SMTP host from the config file:
        emailer = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
        #Set headers, sender, recipients, and header of the email
        emailer.setHeaders(@genbConf.gbFromAddress, @email, "GENBOREE NOTICE: Track Importer Job #{@jobID} Complete")
        emailer.setMailFrom(@genbConf.gbFromAddress)
        emailer.addRecipient(@email)
        emailer.addHeader("Bcc: #{@genbConf.gbBccAddress}")

        messageBody = "Dear Genboree User,\n\n"

        messageBody += "Regarding the following data import job:\n\n"
        messageBody += "     JOB ID: #{@jobID}\n"
        messageBody += "     GROUP: #{@group}\n"
        messageBody += "     DATABASE: #{@database}\n\n"

        messageBody += "Here are the results of your latest import.\n\n"

        @keysToRun.each{ |key|
          if(@results.has_key?(key)) then
            trackData = @results[key]

          messageBody += "The track \"#{trackData.lffType}:#{trackData.lffSubType}\" (Importable track \"#{key}\")"
          if(trackData.exitCode == 0)
            messageBody += " was succesfully imported\n"
          else
            messageBody += " encountered the following error while attempting to import\n\n"
            messageBody += "     ERROR: #{trackData.error}\n"
            if(trackData.message != "")
              messageBody += "     MESSAGE: #{trackData.message} \n"
            end
          end
          else
            messageBody += "No importable tracks found for key: #{key}"
          end
          messageBody += "\n"
        }
          messageBody += "\nYou should have received specific emails about each of the results above. \n"
          messageBody += "\nJob ID: #{@jobID} \n"

        messageBody += "\nIf you have any questions please contact a Genboree Administrator (genboree_admin@genboree.org) with the above information. \n\n"

        messageBody += "Thank you for using Genboree,\nGenboree Team";

        emailer.setBody(messageBody)
        # Send the email
        emailer.send()

      end

      def timeStamp(track, name, password)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(@optsHash['--host'], "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/{attrName}/value", name, password)
        payload = { "data" => { "text" => "#{Time.now.to_f}" } }
        hr = apiCaller.put(payload.to_json, { :grp => @group, :db => @database, :trk => track, :attrName => "gbTrackImportTime" })
      end

      # Emails the user with the results of conversion
      # [+returns+]   nothing
      def trackEmail(trackName, trackData)
        puts("Emailing Track User")

        # Create an emailer instance, using the SMTP host from the config file:
        emailer = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
        #Set headers, sender, recipients, and header of the email
        emailer.setHeaders(@genbConf.gbFromAddress, @email, "GENBOREE NOTICE: Track Importer Status")
        emailer.setMailFrom(@genbConf.gbFromAddress)
        emailer.addRecipient(@email)
        emailer.addHeader("Bcc: #{@genbConf.gbBccAddress}")

        messageBody = "Dear Genboree User,\n\n"

        messageBody += "Regarding the following data import job:\n\n"
        messageBody += "     JOB ID: #{@jobID}\n"
        messageBody += "     GROUP: #{@group}\n"
        messageBody += "     DATABASE: #{@database}\n\n"

        messageBody += "The track \"#{trackData.lffType}:#{trackData.lffSubType}\" (Importable track \"#{trackData.key}\")"
        if(trackData.exitCode == 0)
          messageBody += " was succesfully imported\n"
        else
          emailer.setHeaders(@genbConf.gbFromAddress, @email, "GENBOREE NOTICE: Track Importer Status - ERROR importing #{trackData.location} track #{trackName}")
          messageBody += "  encountered an error while attempting to import: \n\n"
          messageBody += "     ERROR: #{trackData.error} \n"
          if(trackData.message != "")
            messageBody += "     MESSAGE: #{trackData.message} \n"
          end
          messageBody += "\nIf you would like any help with this please contact a Genboree Administrator (genboree_admin@genboree.org) with the above information. \n"
        end
        messageBody += "\nThank you for using Genboree,\nGenboree Team";

        emailer.setBody(messageBody)
        # Send the email
        emailer.send()

      end
    end
  end ; end

optsHash = BRL::TrackImporter::ImporterClass.processArguments()
importClass = BRL::TrackImporter::ImporterClass.new(optsHash)
importClass.run()
