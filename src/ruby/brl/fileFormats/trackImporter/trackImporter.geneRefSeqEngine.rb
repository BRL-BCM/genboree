#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'
require 'net/ftp'
require 'brl/fileFormats/trackImporter/trackImporter.utility'
require 'brl/fileFormats/trackImporter/trackImporter.refseq2lff'

# == Overview.
# This class is the engine for using the standard UCSC converter to transfer
# information from the UCSC database to the Genboree Database
#
#
module BRL; module TrackImporter
    class GeneRefSeqEngine
      # CONSTRUCTOR. Creates an instance of the GeneRefSeqEngine class and
      # completes the initial configuration.
      #
      # [+returns+]   Instance of +ImporterClass+
      def initialize()
      end

      # Runs the engine by completing the following tasks
      # * Downloads the appropriate SQL and Data File
      # * Converts file to the LFF Format
      # * Validates the file
      # * Uploads the file to Genboree
      # The program will not proceed to the next step unless the previous steps
      # completed succesfully.
      #
      # [+trackData+]  The track information needed to run the engine
      # [+returns+]   An Array containg an error code and message
      def run(trackData)
        @trackData = trackData
        @genbConf = BRL::Genboree::GenboreeConfig.load()

        @exitValue = 0
        @errorMessage = ""
        @additionalLines = ""

        puts("Downloading Selected Files - #{@trackData.key}")
        begin
          updatedFiles = BRL::TrackImporter::Utility.downloadAllFiles(@trackData)
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
          convertFile()
        end

        if(@exitValue == 0)
          begin
            BRL::TrackImporter::Utility.uploadAllFiles(@trackData)
          rescue StandardError => uploadError
            @exitValue = -1
            @errorMessage = "Error uploading file"
            @additionalLines = uploadError
            $stderr.puts("ERROR Uploading #{@trackData.key} - " + uploadError)
            $stderr.puts(uploadError.backtrace.join("\n"))
          end
        end

        #returns an array with the Exit Value and Error Message
        [@exitValue, @errorMessage, @additionalLines]
      end

      # ########################################################################
      private #All methods below this point are private
      # ########################################################################

      # Converts a file using the UCSC To LFF Converter
      # [+returns+]   Nothing
      def convertFile()
        puts("Converting Selected File - #{@trackData.key}")

        begin
          converterClass = RefSeq2lff.new()
          
          optsHash = Hash.new()
          optsHash['--refFlatFile'] = "#{@trackData.dataFile.split(",")[0]}"
          optsHash['--trackName'] =  "#{@trackData.lffType}:#{@trackData.lffSubType}"
          optsHash['--refGeneFile'] = "#{@trackData.dataFile.split(",")[1]}"
          optsHash['--refLinkFile'] = "#{@trackData.dataFile.split(",")[2]}"
          optsHash['--refSeqStatusFile'] = "#{@trackData.dataFile.split(",")[3]}"
          optsHash['--refSeqSummaryFile'] = "#{@trackData.dataFile.split(",")[4]}"
          optsHash['outputFile'] = "#{@trackData.outputFile}"

          converterClass.main(optsHash)
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
      def GeneRefSeqEngine.setParameters(oldHash)
        newParameters = Hash.new;
        newParameters['key'] = oldHash['--key']
        newParameters['lffClass'] = oldHash['--class']
        newParameters['lffType'] = oldHash['--type']
        newParameters['lffSubType'] = oldHash['--subtype']
        newParameters['configFile'] = oldHash['--configFile']
        newParameters['sqlFile'] = oldHash['--sqlFile']
        newParameters['dataFile'] = oldHash['--dataFile']
        newParameters['outputFile'] = oldHash['--outputFile']
        newParameters['--userID'] = oldHash['--userID']
        newParameters['--refseqID'] = oldHash['--refSeqID']

        return newParameters
      end

      # Process the arguments that have been passed in and makes sure the required
      # ones are met.
      # [+returns+]   nothing
      def GeneRefSeqEngine.processArguments()
        # We want to add all the prop_keys as potential command line options
        optsArray = [
          ['--key',          '-k', GetoptLong::REQUIRED_ARGUMENT],
          ['--class',        '-c', GetoptLong::REQUIRED_ARGUMENT],
          ['--type',         '-t', GetoptLong::REQUIRED_ARGUMENT],
          ['--subtype',      '-s', GetoptLong::REQUIRED_ARGUMENT],
          ['--configFile',   '-o', GetoptLong::REQUIRED_ARGUMENT],
          ['--sqlFile',      '-i', GetoptLong::REQUIRED_ARGUMENT],
          ['--dataFile',     '-d', GetoptLong::REQUIRED_ARGUMENT],
          ['--outputFile',   '-f', GetoptLong::REQUIRED_ARGUMENT],
          ['--userID',       '-u', GetoptLong::REQUIRED_ARGUMENT],
          ['--refSeqID',     '-r', GetoptLong::REQUIRED_ARGUMENT],
          ['--help',         '-h', GetoptLong::NO_ARGUMENT]
        ]

        progOpts = GetoptLong.new(*optsArray)
        optsHash = progOpts.to_hash
        GeneRefSeqEngine.usage() if(optsHash.key?('--help'));

        unless(progOpts.getMissingOptions().empty?)
          GeneRefSeqEngine.usage("USAGE ERROR: some required arguments are missing")
        end

        GeneRefSeqEngine.usage() if(optsHash.empty?);

        optsHash = GeneRefSeqEngine.setParameters(optsHash);

        return optsHash
      end

      # Displays a message to a user if either the required variables are missing or
      #  the help command line argument is raised
      # [msg]         [optional; default=''] The message to display to the user
      # [+returns+]   nothing
      def GeneRefSeqEngine.usage(msg='')
        unless(msg.empty?)
          puts("\n#{msg}\n")
        end
        puts "PROGRAM DESCRIPTION:
        The UCSC To LFF converter Engine serves as a way of converting information from
        the UCSC genomic database to the Genboree LFF format.

        This script also requires teh genboree configuarion file to have a resources
        directory entry named resourcesDir

        COMMAND LINE ARGUMENTS:
        -k    => Key
        -c    => Name of the class
        -t    => Name of the type
        -s    => Name of the Subtype
        -o    => The configuration file URL
        -i    => The schema input file URL
        -d    => Tthe data file file URL
        -f    => Name of the output file
        -u    => User ID Number
        -r    => Reference ID Number of the database
        -h    => [optional flag] Output this usage info and exit.

        USAGE:
        trackImporter.geneRefSeqEngine.rb -k key -c Class -t Type -s SubType -o config.json -i http://someURL.edu/all_bacends.sql -d http://someURL.edu/all_bacends.txt.gz -f all_bacends.out.data -u 12345 -r 987654";
        exit(134);
      end
    end
  end; end

#optsHash = BRL::UcscTrackImporter::UcscConverterEngine.processArguments()
#converterEngineClass = BRL::UcscTrackImporter::UcscConverterEngine.new(optsHash)
#converterEngineClass.run()