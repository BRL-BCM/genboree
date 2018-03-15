#!/usr/bin/env ruby
########################################################
############ exogenousTaxoTree wrapper #################
# This wrapper generates the exogenous taxonomy tree   #
# using the output from exogenousSTARMapping for       #
# a single sample.                                     #
# Modules used in this pipeline:                       #
# 1. exceRptPipeline                                   #
########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'parallel'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/tools/FTPtoolWrapper'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ExogenousTaxoTreeWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "4.6.2"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'exogenousTaxoTree'. 
                        This tool generates the exogenous taxonomy tree for a sample using the output from exogenousSTARMapping.
                        This tool is intended to be called via the exceRptPipeline wrapper (batch-processing).
                        However, it can also be called on a stand-alone basis if necessary.",
      :authors      => [ "William Thistlethwaite (thistlew@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def processJobConf()
      begin
        # Getting relevant variables from "context"
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Grab group name and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        # Set up tool version variables used throughout this tool
        @toolVersion = @settings['toolVersion']
        # Set up settings
        @analysisName = @settings['analysisName']
        @javaRam = @settings['javaRam']
        @remoteStorageArea = @settings['remoteStorageArea'] if(@settings['remoteStorageArea'])
        @subUserId = @settings['subUserId'] # Only exists in batch-processing mode
        @subUserId = @userId unless(@subUserId)
        @isFTPJob = @settings['isFTPJob'] # Only exists in batch-processing mode
        @postProcDir = @settings['postProcDir'] # Only exists in batch-processing mode
        @coreResultsArchive = @settings['coreResultsArchive'] # Only exists in stand-alone jobs
        @fullResultsArchive = @settings['fullResultsArchive'] # Only exists in stand-alone jobs (sometimes)
        @sampleID = @settings['sampleID'] # Only exists in running one-off re-processing jobs
        @standAloneJob = @settings['standAloneJob'] # Only exists in stand-alone mode
        # Setting to fix exogenous read alignments by re-sorting them (necessary for older read alignments generated for v4 Atlas, for example)
        @resortReads = @settings['resortReads']
        # Setting to fix exogenous rRNA taxonomy trees (related to exceRpt failing to clear reads properly in earlier iteration of taxonomy tree program)
        @fixExogenousRibosomalRNATree = @settings['fixExogenousRibosomalRNATree']
        # Setting to fix incorrectly parsed metazoa and vertebrate reads
        @fixMetazoaAndVertebrates = @settings['fixMetazoaAndVertebrates']
        # Setting to fix virus-related reads (replace Genbank IDs with NCBI Taxonomy IDs)
        @fixViruses = @settings['fixViruses']
        # If this setting is true, then we'll read in our virus GI ID to virus species table and set up a hash accordingly (GI ID -> species)
        if(@fixViruses)
          @virusIDToSpeciesTable = File.read(@toolConf.getSetting('settings', 'virusIDToSpeciesTable'))
          @virusIDToSpeciesHash = {}
          @virusIDToSpeciesTable.each_line { |currentLine|
            virusID = currentLine.split("\t")[0]
            species = currentLine.split("\t")[1]
            @virusIDToSpeciesHash[virusID] = species
          }
        end
        # Setting to update language related to deprecated virus names
        @fixVirusDeprecationTag = @settings['fixVirusDeprecationTag']
        # Create sniffer to check that file formats are as expected
        @sniffer = BRL::Genboree::Helpers::Sniffer.new()
        # Array which captures error messages that occur when unarchiving input files
        @errInputs = []
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error with processJobConf: #{err}")
        @errUserMsg = "ERROR: Could not set up required variables for running job." if(@errUserMsg.nil?)
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # @return [FixNum] @exitCode code corresponding to whether tool run was successful or not (and if not, what error message should be given to user)
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN individual run of exogenous taxonomy tree generation (version #{@toolVersion})")
        # Set up API URI helper for processing inputs currently in email to user
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        # Grab location of makefile
        @smRNAMakefile = ENV['SMALLRNA_MAKEFILE']
        # Grab input file and cut off file:// prefix so that we have the location on disk (in cluster shared scratch area)
        @inputFile = ""
        # If our job is being run as part of the exceRpt job pipeline, then we just need to grab the read alignments input file and move it from our shared cluster area to our local node
        unless(@standAloneJob)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Job is being run as part of the exceRpt job pipeline.")
          @inputFile = @inputs[0].clone
          @inputFile.slice!("file://")
          `mv #{@inputFile} #{@scratchDir}/#{File.basename(@inputFile)}`
          @inputFile = "#{@scratchDir}/#{File.basename(@inputFile)}"
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Job is being run as a stand-alone job.")
          # Otherwise, the job is being launched as a stand-alone job.
          @inputFiles = []
          # Let's download all of the input files.
          downloadFiles(@inputs, true)
          # If there is only one extracted file (as expected), then we're good to go and we save the path to that file in @inputFile
          if(@inputFiles.size == 1)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "We only found one valid input file (as expected), so that's good!")
            @inputFile = @inputFiles[0]
          end
          # If we didn't find any valid files, then we'll print errors below.
          if(@inputFile.empty?)
            @errUserMsg = "We were unable to find a valid .txt input containing your exogenous alignments.\nMore information can be found below if available."
          end
          # Raise an error if we came across one during our downloading / extracting of archive
          raise @errUserMsg unless(@errUserMsg.nil?)
          # Cut off file:// prefix for actually dealing with the input file
          @inputFile.slice!("file://")
          # Next, we will download the sample's CORE_RESULTS archive from Genboree (since we will be updating its contents with the new exogenous genomic tree, at the very least)
          downloadFiles(@coreResultsArchive, false)
          # Grab file path for downloaded CORE_RESULTS archive
          @coreResultsArchive = File.basename(@coreResultsArchive)
          @coreResultsArchive.slice!("?")
          @coreResultsArchive = "#{@scratchDir}/#{@coreResultsArchive}"
          # If @fixExogenousRibosomalRNATree is true, then we need to download the full results archive as well (as it stores the source file necessary for regenerating the exogenous rRNA tree)
          if(@fixExogenousRibosomalRNATree)
            downloadFiles(@fullResultsArchive, false)
            @fullResultsArchive = File.basename(@fullResultsArchive)
            @fullResultsArchive.slice!("?")
            @fullResultsArchive = "#{@scratchDir}/#{@fullResultsArchive}"
          end
        end
        # If we are going to fix the exogenous rRNA tree associated with our sample, then we need to do some pre-processing before we can generate that new tree.
        if(@fixExogenousRibosomalRNATree)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Now generating exogenous rRNA read alignments file")
          # Unzip the exogenous_rRNA_Aligned.out.bam file (used for grabbing the exogenous rRNA read alignments) to the scratch directory.
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "1) Unzipping exogenous_rRNA_Aligned.out.bam file")
          command = "unzip -j #{@fullResultsArchive} #{@sampleID}/EXOGENOUS_rRNA/exogenous_rRNA_Aligned.out.bam -d #{@scratchDir}"
          exitStatus = system(command)
          unless(exitStatus)
            @errUserMsg = "Could not unzip the .bam file required to re-process exogenous rRNA tree."
            raise @errUserMsg
          end
          
          # Grab necessary columns from exogenous_rRNA_Aligned.out.bam file to create the exogenous rRNA read alignments file
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "2) Grabbing necessary columns from exogenous_rRNA_Aligned.out.bam file (to create exogenous rRNA read alignments file)")
          command = "samtools view #{@scratchDir}/exogenous_rRNA_Aligned.out.bam | cut -d $'\t' -f 1,3,4,6,10 > #{@scratchDir}/ExogenousRibosomalAlignments.txt"
          exitStatus = system(command)
          unless(exitStatus)
            @errUserMsg = "Could not begin converting the exogenous rRNA .bam file to grab read alignments."
            raise @errUserMsg
          end
          # Replace all tab characters with space characters in exogenous rRNA read alignments file (this is expected by exceRpt's taxonomy tree program)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "3) Replacing tabs with spaces in exogenous rRNA read alignments file")
          ribosomalAlignments = File.open("#{@scratchDir}/ExogenousRibosomalAlignments.txt", 'r')
          newRibosomalAlignments = File.open("#{@scratchDir}/ExogenousRibosomalAlignmentsNew.txt", 'a')
          ribosomalAlignments.each_line { |currentLine|
            currentLine.gsub!("\t", " ")
            newRibosomalAlignments.write(currentLine)
          }
          ribosomalAlignments.close()
          newRibosomalAlignments.close()
          `mv #{@scratchDir}/ExogenousRibosomalAlignmentsNew.txt #{@scratchDir}/ExogenousRibosomalAlignments.txt`
          # Sort exogenous rRNA reads and only save unique reads
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "4) Sort exogenous rRNA read only save unique reads")
          command = "cat #{@scratchDir}/ExogenousRibosomalAlignments.txt | sort -k 1,1 -k 2,2 | uniq > #{@scratchDir}/ExogenousRibosomalAlignmentsNew.txt"
          exitStatus = system(command)
          unless(exitStatus)
            @errUserMsg = "Could not finish converting the exogenous rRNA .bam file to grab read alignments."
            raise @errUserMsg
          end
          `mv #{@scratchDir}/ExogenousRibosomalAlignmentsNew.txt #{@scratchDir}/ExogenousRibosomalAlignments.txt`
          # Finally, we're done with creating our exogenous rRNA read alignments file.
          @inputFileForRibosomal = "#{@scratchDir}/ExogenousRibosomalAlignments.txt"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done with creating exogenous rRNA read alignments file")
        end
        # If we need to fix the exogenous read alignments, we'll do that here.
        if(@fixMetazoaAndVertebrates or @fixViruses or @fixVirusDeprecationTag)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We are fixing metazoa and vertebrate reads (fixing improperly tab-delimited read IDs)") if(@fixMetazoaAndVertebrates)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We are fixing virus reads (replacing GenBank IDs with NCBI taxonomy names)") if(@fixViruses)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We are fixing the virus deprecation tag in our reads") if(@fixVirusDeprecationTag)
          # We will write fixed output to new file (with .NEW suffix)
          newFilePath = "#{@inputFile}.NEW"
          newFile = File.open(newFilePath, 'a')
          # Open original file and read through each line - if line contains issue, we'll fix the line
          originalFile = File.open(@inputFile, 'r')
          originalFile.each_line { |currentLine|
            # FIX FOR METAZOA AND VERTEBRATES
            if(@fixMetazoaAndVertebrates)
              # In this issue, read IDs for metazoa and vertebrates were improperly tab-delimited so that there were too many columns.
              # This code fixes that issue.  
              if(currentLine.include?("\tMetazoa\t") or currentLine.include?("\tVertebrate\t"))
                currentLineSplit = currentLine.split("\t")
                if(currentLine.include?("Metazoa"))
                  typeIndex = currentLineSplit.index("Metazoa")
                else
                 typeIndex = currentLineSplit.index("Vertebrate")
                end 
                readID = []
                otherPart = []
                0.upto(typeIndex-1) { |currentIndex| readID << currentLineSplit[currentIndex] }
                readID = readID.join(":")
                typeIndex.upto(currentLineSplit.size-1) { |currentIndex| otherPart << currentLineSplit[currentIndex] }
                otherPart = otherPart.join("\t")
                currentLine = "#{readID}\t#{otherPart}"
              end
            # FIX FOR VIRUSES
            elsif(@fixViruses)
              # In this issue, species names were GenBank IDs instead of NCBI taxonomy names.
              # This code fixes that issue.
              currentLineSplit = currentLine.split("\t")
              if(currentLineSplit[1] == "Virus")
                virusID = currentLineSplit[2]
                species = @virusIDToSpeciesHash[virusID]
                unless(species.nil?)
                  currentLineSplit[2] = species.chomp()
                else
                  currentLineSplit[2] = "#{virusID} (not used in taxonomy tree because GenBank ID is deprecated or associated with removed record)"
                end
                currentLine = currentLineSplit.join("\t")
              end
            elsif(@fixVirusDeprecationTag)
              # In this issue, older read alignment files generated by our code had a less informative tag to indicate deprecation.
              # This code fixes that issue by explaining in more detail why the species was not used in the taxonomy tree generation.
              currentLineSplit = currentLine.split("\t")
              if(currentLineSplit[1] == "Virus")
                currentLineSplit[2].gsub!("(deprecated)", "(not used in taxonomy tree because GenBank ID is deprecated or associated with removed record)")
              end
              currentLine = currentLineSplit.join("\t")
            end
            # After fixing the line (or not), we'll write it to our new file
            newFile.write(currentLine)
          }
          # Close file handles and then replace the old file with the new file
          originalFile.close()
          newFile.close()
          `mv #{newFilePath} #{@inputFile}`
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done fixing metazoa and vertebrate reads (improper tab-delimited read IDs fixed)") if(@fixMetazoaAndVertebrates)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done fixing virus reads (GenBank IDs replaced with NCBI taxonomy names)") if(@fixViruses)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done fixing virus deprecation tags") if(@fixVirusDeprecationTag)
        end
        # If we need to re-sort the reads (reads must be sorted by read ID in order for taxonomy tree program to work properly), we'll do that here
        if(@resortReads)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Re-sorting exogenous genomic reads")
          `sort -k1,1 #{@inputFile} >> #{@inputFile}.NEW`
          `mv #{@inputFile}.NEW #{@inputFile}`
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done re-sorting exogenous genomic reads")
        end
        # If we've updated the exogenous read alignments at all, then let's recompress them and upload them to Genboree
        if(@fixMetazoaAndVertebrates or @fixViruses or @fixVirusDeprecationTag or @resortReads)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We've updated our exogenous genomic read alignments, so we're going to re-upload them to Genboree")
          # Let's re-archive the fixed file so we can upload it to Genboree
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Re-archiving the fixed version of exogenous genomic read alignments")
          `cd #{File.dirname(@inputFile)} ; tar -zcvf #{@sampleID}_#{@analysisName}_ExogenousGenomicAlignments.FIXED.tgz *`
          fixedArchive = "#{File.dirname(@inputFile)}/#{@sampleID}_#{@analysisName}_ExogenousGenomicAlignments.FIXED.tgz"
          # Parse target URI for outputs
          targetUri = URI.parse(@outputs[0])
          # Specify full resource path
          unless(@remoteStorageArea)
            rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?"
          else
            rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?"
          end
          rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          # Upload fixed archive to Genboree
          uploadFile(targetUri.host, rsrcPath, @subUserId, fixedArchive, {:analysisName => @analysisName, :outputFile => "EXOGENOUS_GENOME_OUTPUT/#{File.basename(fixedArchive)}"})      
        end
        # @failedRun keeps track of whether the sample was successfully processed
        @failedRun = false
        # Run sample through exogenous taxonomy tree program
        begin
          @inputFileForRibosomal = nil unless(@inputFileForRibosomal)
          unless(@inputFileForRibosomal)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree method to process sample #{@inputFile} (exogenous genomic)")
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree method to process sample #{@inputFile} (both exogenous genomic and rRNA)")   
          end
          exogenousTaxoTree(@inputFile, @inputFileForRibosomal)
        rescue => err
          # If an error occurs, we'll mark the run as failed and set the error message accordingly
          @failedRun = true
          @errUserMsg = err.message.inspect
          @errBacktrace = err.backtrace.join("\n")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Error message: #{@errUserMsg}")
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Backtrace: #{@errBacktrace}")
        end
        # If run failed for some reason, then we raise our error
        if(@failedRun)
          raise @errUserMsg
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE exogenousTaxoTree (version #{@toolVersion}). END.")
        # DONE exogenousTaxoTree
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Exogenous Taxonomy Tree Generation (version #{@toolVersion}) failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run Exogenous Taxonomy Tree Generation (version #{@toolVersion})." if(@errInternalMsg.nil?)
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    # Download input files from database. Perform initial extraction (of multi-file archives) if requested
    # @return [nil]
    def downloadFiles(inputs, extractFiles)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input files using threads #{inputs.inspect}")
      # If job is not local, then we need to download our inputs. Otherwise, our inputs will be the local file paths.
      unless(@localJob)
        uriPartition = @fileApiHelper.downloadFilesInThreads(inputs, @userId, @scratchDir)
        localPaths = uriPartition[:success].values
      else
        localPaths = inputs
      end
      if(extractFiles)
        # We will traverse all of the downloaded files, one at a time.
        localPaths.each { |tmpFile|
          checkForInputs(tmpFile, tmpFile, true)
        }
      end
      return
    end

    # Method that is used recursively to check what inputs each submitted file contains
    # @param [String] inputFile file name or folder name currently being checked
    # @param [boolean] continueExtraction boolean that determines whether we're going to extract the current file (only used for those files grabbed from Workbench)
    # @param [String] originalSource the original source file (archive, most likely) that the current file was originally part of. This info is used for error reporting.
    # @return [nil]
    def checkForInputs(inputFile, originalSource, continueExtraction=false)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Current input file: #{inputFile}")
      # If we have an empty file (not inside of an archive!) then let's check that here.
      # We won't continue to check the file if it's empty at this stage.
      expError = false
      if(File.zero?(inputFile))
        @errInputs[:emptyFiles] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"
      else
        # First, check to see if inputFile is a directory. If it's not, we'll just extract it.
        unless(File.directory?(inputFile))
          if(continueExtraction)
            exp = BRL::Util::Expander.new(inputFile)
            begin
              exp.extract()
            rescue => err
              expError = true
              @errInputs[:badArchives] << File.basename(inputFile)     
            end
            unless(expError)
              oldInputFile = inputFile.clone()
              inputFile = exp.uncompressedFileName
              # Delete old archive if there was indeed an archive (it's uncompressed now so we don't need to keep it around)
              `rm -f #{oldInputFile}` unless(exp.compressedFileName == oldInputFile)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uncompressed file name: #{inputFile}")
            end
          end
        end
        unless(expError)
          # Now, we'll check to see if the file is a directory or not - remember, we could have 
          # uncompressed a directory above!
          if(File.directory?(inputFile))
            # If we have a directory, grab all files in that directory and send them all through checkForInputs recursively
            allFiles = Dir.entries(inputFile)
            allFiles.each { |currentFile|
              next if(currentFile == "." or currentFile == ".." or currentFile == "__MACOSX")
              checkForInputs("#{inputFile}/#{currentFile}", originalSource, false)
            }
          else
            # OK, so we have a file. First, let's make the file name safe 
            fixedInputFile = File.basename(inputFile).makeSafeStr(:ultra)
            # Get full path of input file and replace last part of that path (base name) with fixed file name
            inputFileArr = inputFile.split("/")
            inputFileArr[-1] = fixedInputFile
            fixedInputFile = inputFileArr.join("/")
            # Rename file so that it has fixed file name
            `mv #{Shellwords.escape(inputFile)} #{fixedInputFile}`
            # Check to see if file is empty. We have to do this again because it might have been inside of a (non-empty) archive earlier!
            if(File.zero?(fixedInputFile))
              @errInputs[:emptyFiles] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"     
            else
              # Sniff file and see whether it's ASCII
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file type of #{fixedInputFile}")
              @sniffer.filePath = fixedInputFile
              fileType = @sniffer.autoDetect()
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in format #{fileType}")
              unless(fileType == "ascii")
                @errInputs[:badFormat] << "#{File.basename(inputFile)}\n(with original source archive #{File.basename(originalSource)})"
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Input file #{fixedInputFile} is in correct format (ASCII)")
                @inputFiles.push("file://#{fixedInputFile}")
              end
            end
          end
        end
      end
      return
    end

    # Run exogenousTaxoTree on a particular sample
    # @param [String] inFile path to file name for input file (exogenous genomic read alignments)
    # @param [String or nil] inFileRibosomal path to file name for other input file (exogenous rRNA read alignments)
    # @return [nil]
    def exogenousTaxoTree(inFile, inFileRibosomal)
      # Variables used for .out / .err files for exogenousTaxoTree run(s)
      errFileGenomic = "#{@scratchDir}/#{@sampleID}.err"
      errFileRibosomal = "#{@scratchDir}/#{@sampleID}.Ribosomal.err" if(inFileRibosomal)
      # Create Java command to run exogenous taxonomy tree program for our exogenous genomic reads
      command = "#{ENV['JAVA_EXE']} -Xms#{@settings['javaRam']} -Xmx#{@settings['javaRam']} -jar #{ENV['EXCERPT_TOOLS_EXE']} ProcessExogenousAlignments -taxonomyPath #{ENV['EXCERPT_DATABASE']}/NCBI_taxonomy_taxdump -min 0.001 -frac 0.95 -batchSize 500000 -minReads 3 -alignments #{inFile} > #{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt 2>> #{errFileGenomic}"
      # Launching Java command
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command for generation of taxonomy tree for exogenous genomic reads: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree command completed for #{inFile} (genomic reads) (exit code: #{statusObj.exitstatus})")
      # Check whether there was an error with the taxonomy tree generation for exogenous genomic reads
      foundError = findError(exitStatus, errFileGenomic)
      # If there was no error found, then let's proceed
      unless(foundError)
        # Now, let's see whether we need to run the taxonomy tree program for the exogenous rRNA reads
        if(@fixExogenousRibosomalRNATree)
          command = "#{ENV['JAVA_EXE']} -Xmx#{@settings['javaRam']} -jar #{ENV['EXCERPT_TOOLS_EXE']} ProcessExogenousAlignments -taxonomyPath #{ENV['EXCERPT_DATABASE']}/NCBI_taxonomy_taxdump -min 0.001 -frac 0.95 -minReads 3 -batchSize 20000 -alignments #{inFileRibosomal} --rdp > #{@scratchDir}/ExogenousRibosomalAlignments.result.taxaAnnotated.txt 2>> #{errFileRibosomal}"
          # Launching Java command
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command for generation of taxonomy tree for exogenous rRNA reads: #{command}")
          exitStatus = system(command)
          statusObj = $?
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "exogenousTaxoTree command completed for #{inFileRibosomal} (rRNA reads) (exit code: #{statusObj.exitstatus})")
          # Check whether there was an error with the taxonomy tree generation for exogenous rRNA reads
          foundError = findError(exitStatus, errFileRibosomal)
        end
        # Let's check again to see whether there was any error found (in case we just processed the exogenous rRNA reads)
        unless(foundError)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "We didn't find any errors when generating our tree(s), so we'll upload them to Genboree and do any other necessary archiving / transferring of files")
          # Create temporary directory where CORE_RESULTS archive will be unzipped
          tempCoreResultsDir = "#{@scratchDir}/TEMP_CORE_RESULTS_DIR"
          `mkdir -p #{tempCoreResultsDir}`
          # Unzip CORE_RESULTS archive to temp dir
          `tar -zxvf #{Shellwords.escape(@coreResultsArchive)} -C #{tempCoreResultsDir}`
          # Copy exogenous genomic taxonomy tree file to the proper directory inside of archive
          `mkdir -p #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_genomes`
          `cp -r #{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_genomes/ExogenousGenomicAlignments.result.taxaAnnotated.txt`
          # If we need to, copy exogenous rRNA taxonomy tree file to the proper directory inside of archive
          if(@fixExogenousRibosomalRNATree)
            `mkdir -p #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_rRNA`
            `cp -r #{@scratchDir}/ExogenousRibosomalAlignments.result.taxaAnnotated.txt #{tempCoreResultsDir}/#{@sampleID}/EXOGENOUS_rRNA/ExogenousRibosomalAlignments.result.taxaAnnotated.txt`
          end
          # Delete old copy of CORE_RESULTS archive
          `rm -f #{@coreResultsArchive}`
          # If we're fixing the metazoa / vertebrate alignments, we need to update the exogenous_genomes read count in the .stats file associated with the sample.
          if(@fixMetazoaAndVertebrates)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Because the metazoa and vertebrates were updated in the exogenous genomic read alignments, we need to recalculate the exogenous_genomes read count in the .stats file associated with the sample.")
            statsFile = File.read("#{tempCoreResultsDir}/#{@sampleID}.stats")
            newExogenousGenomeCount = `cat #{inFile} | cut -d $'\t' -f 1 | uniq | wc -l`.chomp
            newExogenousGenomeCountLine = "exogenous_genomes\t#{newExogenousGenomeCount}"
            statsFile.gsub!(/^exogenous_genomes\t\d+/, newExogenousGenomeCountLine)
            File.open("#{tempCoreResultsDir}/#{@sampleID}.stats", 'w') { |file| file.write(statsFile) }
            `cp #{"#{tempCoreResultsDir}/#{@sampleID}.stats"} #{@scratchDir}/#{@sampleID}.stats`
          end
          # Re-zip the (new) contents of the CORE_RESULTS archive in the same place as the previous version
          `cd #{tempCoreResultsDir} ; tar -zcvf #{@coreResultsArchive} *`
          # Delete the unzipped CORE_RESULTS directory (we're done compressing it again)
          `rm -rf #{tempCoreResultsDir}`
          # Let's also move our CORE_RESULTS archive to the post-processing area, since we've updated it
          `cp #{@coreResultsArchive} #{@postProcDir}/runs/#{File.basename(@coreResultsArchive)}` unless(@standAloneJob)
          # If we're running an FTP job, we need to copy the CORE_RESULTS archive to the shared area (so that erccFinalProcessing can use it for parsing reads and other FTP exceRpt tasks).
          if(@isFTPJob and !@standAloneJob)
            sharedCoreArchive = "#{@settings['jobSpecificSharedScratch']}/samples/#{@sampleID}/#{File.basename(@coreResultsArchive)}"
            `cp #{@coreResultsArchive} #{sharedCoreArchive}`
          end
          # If we reprocessed the exogenous rRNA tree, then we need to add that to our full results archive as well.
          if(@fixExogenousRibosomalRNATree)
            `cd #{@scratchDir} ; mkdir -p #{@sampleID}/EXOGENOUS_rRNA`
            `cp #{@scratchDir}/ExogenousRibosomalAlignments.result.taxaAnnotated.txt #{@scratchDir}/#{@sampleID}/EXOGENOUS_rRNA/`
            command = "cd #{@scratchDir} ; zip -g #{File.basename(@fullResultsArchive)} #{@sampleID}/EXOGENOUS_rRNA/ExogenousRibosomalAlignments.result.taxaAnnotated.txt"
            exitStatus = system(command)
            unless(exitStatus)
             @errUserMsg = "Could not add the exogenous rRNA taxonomy tree to the full results archive."
              raise @errUserMsg
            end            
          end
          # Transfer files to user's Genboree database
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring CORE_RESULTS archive and taxonomy tree file for this sample #{inFile} to the server")
          transferFiles(@coreResultsArchive, @fullResultsArchive, "#{@scratchDir}/ExogenousGenomicAlignments.result.taxaAnnotated.txt", "#{@scratchDir}/ExogenousRibosomalAlignments.result.taxaAnnotated.txt", "#{@scratchDir}/#{@sampleID}.stats")
        end
      end
      return
    end
          
    # Transfer output files to the user database for a particular sample
    # @param [String] coreResultsArchive path to core results archive
    # @param [String] fullResultsrchive path to full results archive (everything up until exogenous genomes)
    # @param [String] taxoTreeGenomic path to exogenous genomic taxonomy tree file
    # @param [String] taxoTreeRibosomal path to exogenous ribosomal taxonomy tree file 
    # @param [String] statsFile path to .stats file
    # @return [nil]
    def transferFiles(coreResultsArchive, fullResultsArchive, taxoTreeGenomic, taxoTreeRibosomal, statsFile)
      # Parse target URI for outputs
      targetUri = URI.parse(@outputs[0])
      # Specify full resource path
      unless(@remoteStorageArea)
        rsrcPath = "#{targetUri.path}/file/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?" 
      else
        rsrcPath = "#{targetUri.path}/file/#{CGI.escape(@remoteStorageArea)}/exceRptPipeline_v#{@toolVersion}/{analysisName}/#{CGI.escape(@sampleID)}/{outputFile}/data?" 
      end
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # CORE_RESULTS archive to CORE_RESULTS subdir
      uploadFile(targetUri.host, rsrcPath, @subUserId, coreResultsArchive, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{File.basename(coreResultsArchive)}"})
      # Exogenous genomic taxo file to EXOGENOUS_GENOMES subdir
      uploadFile(targetUri.host, rsrcPath, @subUserId, taxoTreeGenomic, {:analysisName => @analysisName, :outputFile => "EXOGENOUS_GENOME_OUTPUT/#{File.basename(taxoTreeGenomic)}"})
      # Exogenous genomic taxo file to CORE_RESULTS subdir/sampleID/EXOGENOUS_genomes
      uploadFile(targetUri.host, rsrcPath, @subUserId, taxoTreeGenomic, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{@sampleID}/EXOGENOUS_genomes/#{File.basename(taxoTreeGenomic)}"})
      # .stats file with new exogenous genomes count (only used if @fixMetazoaAndVertebrates is true)
      if(@fixMetazoaAndVertebrates)
        uploadFile(targetUri.host, rsrcPath, @subUserId, statsFile, {:analysisName => @analysisName, :outputFile => File.basename(statsFile)})
        uploadFile(targetUri.host, rsrcPath, @subUserId, statsFile, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{File.basename(statsFile)}"})
      end
      # Exogenous rRNA taxo file to CORE_RESULTS subdir/sampleID/EXOGENOUS_rRNA
      if(@fixExogenousRibosomalRNATree)
        uploadFile(targetUri.host, rsrcPath, @subUserId, fullResultsArchive, {:analysisName => @analysisName, :outputFile => File.basename(fullResultsArchive)})
        uploadFile(targetUri.host, rsrcPath, @subUserId, taxoTreeRibosomal, {:analysisName => @analysisName, :outputFile => "CORE_RESULTS/#{@sampleID}/EXOGENOUS_rRNA/#{File.basename(taxoTreeRibosomal)}"})
      end
      return
    end
    
    # Upload a given file to Genboree server
    # @param host [String] host that user wants to upload to
    # @param rsrcPath [String] resource path that user wants to upload to
    # @param userId [Fixnum] genboree user id of the user
    # @param inputFile [String] full path of the file on the client machine where data is to be pulled
    # @param templateHash [Hash<Symbol, String>] hash that contains (potential) arguments to fill in URI for API put command
    # @return [nil]
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
    end

    # Try hard to detect errors
    # - exceRpt Pipeline can exit with 0 status even when it clearly failed.
    # - So we need to aggressively go looking for any errors.
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for smallRNA-seq Pipeline.
    # @param [String] errFile path to file where error output is stored from run
    # @return [boolean] indicating if a smallRNA-seq Pipeline error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus, errFile)
      retVal = false
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      cmd = "grep -P \"^ERROR\\s\" #{errFile}"
      errorMessages = `#{cmd}`
      if(errorMessages.strip.empty?)
        retVal = false
      else
        retVal = true
      end
      # Did we find anything?
      if(retVal or !exitStatus)
        # Here, we mark the current run as failed and set its error message correspondingly
        @failedRun = true
        @errUserMsg = "Exogenous Taxonomy Tree job failed.\nMessage from exceRpt:\n\""
        @errUserMsg << (errorMessages || "[No error info available from exceRpt]")
      end
      return retVal
    end

############ END of methods specific to this runExceRpt wrapper
    
########### Email 

    # Method to send success e-mail to user
    def prepSuccessEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      return nil
    end
    
    # Method to send failure e-mail to user
    def prepErrorEmail()
      # Update jobFile.json with updated contents
      toolJobFile = "#{@scratchDir}/jobFile.json"
      File.open(toolJobFile,"w") do |jobFile|
        jobFile.write(JSON.pretty_generate(@jobConf))
      end
      # Email object
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = @analysisName
      inputsText                      = customBuildSectionEmailSummary(@inputs)
      emailErrorObject.inputsText     = inputsText
      outputsText                     = buildSectionEmailSummary(@outputs[0])
      emailErrorObject.outputsText    = outputsText
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      emailErrorObject.erccTool = true
      # Remove settings that are unnecessary for user e-mail
      cleanUpSettingsForEmail()
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

    # When we send our success or failure email, there are certain settings that we don't want to send the user (because they're not helpful, redundant, etc.).
    # @return [nil]  
    def cleanUpSettingsForEmail()
      if(@settings['endogenousLibraryOrder'])
        @settings['endogenousLibraryOrder'].gsub!("gencode", "Gencode")
        @settings['endogenousLibraryOrder'].gsub!(",", " > ")
      end
      @settings.delete("indexBaseName")
      @settings.delete("newSpikeInLibrary")
      @settings.delete("existingLibraryName")
      @settings.delete("jobSpecificSharedScratch")
      @settings.delete("listOfJobIds")
      @settings.delete("autoDetectAdapter") unless(@settings['adapterSequence'] == "other")
      @settings.delete("manualAdapter") unless(@settings['adapterSequence'] == "other" and @settings['autoDetectAdapter'] == "no")
      @settings.delete("otherDataRepo") unless(@settings['anticipatedDataRepo'] == "Other")
      @settings.delete("piID")
      @settings.delete("platform")
      @settings.delete("processingPipeline")
      @settings.delete("processingPipelineIdAndVersion")
      @settings.delete("processingPipelineVersion")
      unless(@settings["randomBarcodesEnabled"])
        @settings.delete("randomBarcodeLength")
        @settings.delete("randomBarcodeLocation")
        @settings.delete("randomBarcodeStats")
      end
      @settings.delete("subjobDir")
      @settings.delete("toolVersionPPR")
      @settings["priorityList"].gsub!(",", " > ") if(@settings["priorityList"])
      @settings.delete("adSeqParameter")
      @settings.delete("adapterSequence")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("bowtieSeedLength")
      @settings.delete("calib")
      @settings.delete("exRNAHost")
      @settings.delete("exRNAKb")
      @settings.delete("exRNAKbGroup")
      @settings.delete("exRNAKbProject")
      @settings.delete("failedFtpDir")
      @settings.delete("finalizedMetadataDir")
      @settings.delete("finishedFtpDir")
      @settings.delete("dataArchiveLocation")
      @settings.delete("genboreeKbArea")
      @settings.delete("manifestLocation")
      @settings.delete("metadataArchiveLocation")
      @settings.delete("outputHost")
      @settings.delete("anticipatedDataRepo")
      @settings.delete("dataRepoSubmissionCategory")
      @settings.delete("dbGaP")
      @settings.delete("grantNumber")
      @settings.delete("piName")
      @settings.delete("javaRam")
      @settings.delete("localExecution")
      @settings.delete("numThreads")
      @settings.delete("postProcOutputDir")
      @settings.delete("useLibrary")
      @settings.delete("endogenousMismatch")
      @settings.delete("exogenousMapping")
      @settings.delete("exogenousMismatch")
      @settings.delete("genomeBuild")
      @settings.delete("manifestFile")
      @settings.delete("postProcDir")
      @settings.delete("subUserId")
      @settings.delete("uploadRawFiles")
      @settings.delete("remoteStorageArea") if(@settings["remoteStorageArea"] == nil)
      # Delete local path to post-processing input dir
      @settings.delete('postProcDir')
      @settings.delete('exogenousMappingInputDir')
      # Delete information about number of threads / tasks for exogenous mapping (used in exogenousSTARMapping wrapper)
      @settings.delete('numThreadsExo')
      @settings.delete('numTasksExo') 
      @settings.delete("toggleMultiSelectListButton")
      @settings.delete('numberField_fractionForMinBaseCallQuality')
      @settings.delete('numberField_minReadLength')
      @settings.delete('numberField_readRemainingAfterSoftClipping')
      @settings.delete('numberField_trimBases5p')
      @settings.delete('numberField_trimBases3p')
      @settings.delete('numberField_minAdapterBases3p')
      @settings.delete('numberField_downsampleRNAReads')
      @settings.delete('numberField_bowtieSeedLength')
      @settings.delete('minBaseCallQuality') if(@settings['exceRptGen'] == 'thirdGen') # We can delete minimum base-call quality if user submitted 3rd gen exceRpt job
      @settings.delete('exRNAAtlasURL')
      @settings.delete("uploadReadCountsDocs")
      @settings.delete('listOfExogenousTaxoTreeJobIds')
      @settings.delete('coreResultsArchive')
      @settings.delete('exogenousTaxoTreeJobIDDir')
      @settings.delete('importantJobIdsDir')
      @settings.delete('exogenousRerunDir')
      @settings.delete('filePathToListOfExogenousJobIds')
      @settings.delete('wbContext')
      @settings.delete('exogenousClaves')
      @settings.delete('backupFtpDir')
      
    end

    def customBuildSectionEmailSummary(section)
      sectionHash = {}
      countDisplay = 1
      ##Only display 10 input items as max
      section.each { |file|
        uriObj = URI.parse(file)
        scheme = uriObj.scheme
        if(scheme =~ /file/)
          type = scheme
          baseName = File.basename(uriObj.path)
        else
          type = @apiUriHelper.extractType(file)
          baseName = File.basename(@apiUriHelper.extractName(file))
        end
        sectionHash["#{countDisplay}. #{type.capitalize}"] = baseName
        # We want to display only 9 files and keep record if there are more than
        # 9,
        # which would be shown by "...."
        if(countDisplay == 9 and section.size > 9)
          sectionHash["99"] = "....."
          break
        end
        countDisplay += 1
      }
      return sectionHash
    end

  end
end; end ; end ; end

# If we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExogenousTaxoTreeWrapper)
end
