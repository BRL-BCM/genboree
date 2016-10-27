#!/usr/bin/env ruby
require 'net/ftp'

# == Overview.
# This class is the engine for using the wib importer to transfer
# information from the UCSC database to the Genboree Database
#
#
module BRL; module TrackImporter
    class WibEngine
      # CONSTRUCTOR. Creates an instance of the WibEngine class and
      # completes the initial configuration.
      #
      # [+returns+]   Instance of +WibEngine+
      def initialize()
      end

      # Runs the engine by completing the following tasks
      # * Downloads the appropriate WIB and WIG File
      # * Passes the data to the wibImporter
      # The program will not proceed to the next step unless the previous steps
      # completed succesfully.
      #
      # [+returns+]   An Array containg an error code and message
      def run(trackData)
        @trackData = trackData

        @exitValue = 0
        @errorMessage = ""
        @additionalLines = ""
        puts("Downloading Wig Files - #{@trackData.key}")
        begin

          updatedFiles = BRL::TrackImporter::Utility.downloadAllFiles(@trackData)

          @host = URI(@trackData.dataFile).scheme + "://" + URI(@trackData.dataFile).host

          trackData.mappingFile = updatedFiles[0]
          trackData.dataFile = updatedFiles[1]
        rescue StandardError => downloadError
          @exitValue = -1
          @errorMessage = "Error retrieving files"
          @additionalLines = downloadError
          $stderr.puts("ERROR Downloading #{@trackData.key} - " + downloadError)
          $stderr.puts(downloadError.backtrace.join("\n"))
        end
        if(@exitValue == 0)
          getWibFiles()
        end

        if(@exitValue == 0)
          runWibEngine()
        end

        #returns an array with the Exit Value and Error Message
        [@exitValue, @errorMessage, @additionalLines]
      end

      # ########################################################################
      private #All methods below this point are private
      # ########################################################################

      def getWibFiles()
        reader = BRL::Util::TextReader.new("#{Dir.pwd}/#{@trackData.dataFile}")
        myWibFiles = Array.new
        @wibFiles = String.new

        reader.each { |line|
          arrSplit = line.strip.split(/\t/)
          wibFile = arrSplit[8]

          if(not myWibFiles.include?(wibFile))
            myWibFiles << wibFile
          end
        }

        myWibFiles.each { |downloadFile|
          begin
            BRL::TrackImporter::Utility.downloadFileFTP( @host + downloadFile)

            fileParts = downloadFile.split("/")

            if(not @wibFiles == "")
              @wibFile += ","
            end
            @wibFiles += "#{fileParts[fileParts.length - 1]}"
          rescue StandardError => bang
            @exitValue = -1
            @errorMessage = "Error retrieving #{downloadFile} Wib file(s) from Server"
            $stderr.puts("ERROR Downloading #{downloadFile} - " + bang)
            $stderr.puts(bang.backtrace.join("\n"))
          end
        }
      end

      # Converts a file using the WibImporter
      # [+returns+]   Nothing
      def runWibEngine()
        
        puts("Running Wib Engine - #{@trackData.key}")
        
        begin
          runCommand = "importWibInGenboree.rb "
          runCommand += "-f #{@trackData.dataFile} "
          runCommand += "-w #{@wibFiles} "
          runCommand += "-t '#{@trackData.lffType}:#{@trackData.lffSubType}' "
          runCommand += "-g #{@trackData.groupId} "
          runCommand += "-d #{@trackData.refSeqId} "
          runCommand += "-u #{@trackData.userId} "
          runCommand += "> #{Dir.pwd}/importWib.#{@trackData.key}.data.out 2> #{Dir.pwd}/importWib.#{@trackData.key}.error.out"

          puts runCommand

          if(not system(runCommand))
            @exitValue = -1
            @errorMessage = ("ERROR Uploading #{@trackData.key}")
            $stderr.puts("ERROR Uploading #{@trackData.key} - Bad Return from System Call")
          end
        rescue StandardError => bang
          @exitValue = -1
          @errorMessage = "Error Converting Class"
          $stderr.puts("ERROR Converting #{@trackData.key} - " + bang)
          $stderr.puts(bang.backtrace.join("\n"))
        end
      end

      # Takes the parameters that have been passed in and turns them into class
      #  variables
      # [+returns+]   nothing
      def WibEngine.setParameters(oldHash)
        newParameters = Hash.new;
        newParameters['key'] = oldHash['--key']
        newParameters['lffType'] = oldHash['--type']
        newParameters['lffSubType'] = oldHash['--subtype']
        newParameters['wigFile'] = oldHash['--wigFile']
        newParameters['--userID'] = oldHash['--userID']
        newParameters['--refseqID'] = oldHash['--refSeqID']
        newParameters['--groupID'] = oldHash['--groupID']

        return newParameters
      end

      # Process the arguments that have been passed in and makes sure the required
      # ones are met.
      # [+returns+]   nothing
      def WibEngine.processArguments()
        # We want to add all the prop_keys as potential command line options
        optsArray = [
          ['--key',          '-k', GetoptLong::REQUIRED_ARGUMENT],
          ['--wigFile',      '-w', GetoptLong::REQUIRED_ARGUMENT],
          ['--type',         '-t', GetoptLong::REQUIRED_ARGUMENT],
          ['--subtype',      '-s', GetoptLong::REQUIRED_ARGUMENT],
          ['--groupID',      '-g', GetoptLong::REQUIRED_ARGUMENT],
          ['--refSeqID',     '-r', GetoptLong::REQUIRED_ARGUMENT],
          ['--userID',       '-u', GetoptLong::REQUIRED_ARGUMENT],
          ['--help',         '-h', GetoptLong::NO_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        WibEngine.usage() if(optsHash.key?('--help'));

        unless(progOpts.getMissingOptions().empty?)
          WibEngine.usage("USAGE ERROR: some required arguments are missing")
        end

        WibEngine.usage() if(optsHash.empty?);

        optsHash = WibEngine.setParameters(optsHash);

        return optsHash
      end

      # Displays a message to a user if either the required variables are missing or
      #  the help command line argument is raised
      # [msg]         [optional; default=''] The message to display to the user
      # [+returns+]   nothing
      def WibEngine.usage(msg='')
        unless(msg.empty?)
          puts("\n#{msg}\n")
        end
        puts "PROGRAM DESCRIPTION:
        The UCSC Wib Engine serves as a way of converting information from
        the UCSC genomic database that requires the use of WIB files to display
        data.

        COMMAND LINE ARGUMENTS:
        -k    => Key
        -t    => Name of the type
        -s    => Name of the Subtype
        -w    => The wig file URL
        -u    => User ID Number
        -r    => Reference ID Number of the database
        -g    => Group that the database belongs in
        -h    => [optional flag] Output this usage info and exit.

        USAGE:
        trackImporter.wibEngine.rb -k key -t Type -s SubType -w http://someURL.edu/all_bacends.wig -u 12345 -r 987654 -g group_name";
        exit(134);
      end
    end
  end; end

#optsHash = BRL::UcscTrackImporter::WibEngine.processArguments()
#wibEngineClass = BRL::UcscTrackImporter::WibEngine.new(optsHash)
#wibEngineClass.run()