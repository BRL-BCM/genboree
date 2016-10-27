#!/usr/bin/env ruby
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/wrapperApiCaller'

module BRL; module Genboree; module Tools; module Scripts
  class SparkDriver < BRL::Genboree::Tools::ToolWrapper
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    VERSION = "1.1"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'Spark' tool by Cydney Nelson.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ]
    }
    TOOL_TITLE = "Spark"
    NON_SPARK_SETTINGS = { 'analysisName' => true, 'clusterQueue' => true, 'roiTrack' => true, 'positionalInputsTool' => true, 'roiTrkSelect' => true }
    # ------------------------------------------------------------------
    # ATTRIBUTES
    # ------------------------------------------------------------------
    attr_accessor :userEmail, :inputFile, :analysisName, :jobId

    # ------------------------------------------------------------------
    # INTERFACE METHODS
    # ------------------------------------------------------------------
    # processJobConf()
    #  . code to extract needed information from the @jobConf Hash, typically to instance variables
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . Do not send email, that will be done automatically from @err* variables
    #  . if a problem is encountered, make sure to set @errInternalMsg with lots of details.
    #    - if the problem is due to an Exception, save it in @err AND use Script::formatException() to help set a sensible @errInternalMsg
    #    - ToolWrapper will automatically log @errInternalMsg to stderr.
    def processJobConf()
      begin
        @emailMessage = @analysisName = @apiExitCode = nil
        @fileCounter = Hash.new { |hh,kk| hh[kk] = 0 }
        @seenGff3Names = Hash.new { |hh, kk| hh[kk] = 0 }
        @outputUri = @outputs.last
        @analysisName = @settings['analysisName']
        @uploadMessage = nil
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @err = err
        @exitCode = 22
      end
      return @exitCode
    end

    def prepSuccessEmail()
      # Build some input info:
      inputInfo = {
        "ROI Track" => @trkApiHelper.extractName(@settings['roiTrack']),
        "# of Data Tracks" => @numDataTracks
      }
      # Build some output info:
      outputInfo = {
        "Output Host" => @dbApiHelper.extractHost(@outputs.first),
        "Output DB"   => @dbApiHelper.extractName(@outputs.first)
      }
      # Filter the settings
      settingsToEmail = [ "normType", "k", "regionLabel", "statsType", "numBins" ]
      emailSettings = {}
      settingsToEmail.each { |kk|
        emailSettings[kk] = @settings[kk]
      }
      # Build tree to results file:
      resultFileLocation = <<-EOS
  Host: #{@dbApiHelper.extractHost(@outputs.first)}
    Grp: #{@grpApiHelper.extractName(@outputs.first)}
      Db: #{@dbApiHelper.extractName(@outputs.first)}
        Files Area:
        * Spark - Results/
          * #{@settings['analysisName']}/
            * #{@archiveName}
      EOS
      # Build link to results file:
      fileUri = URI.parse(@archiveUrl)
      resultFileURL = {
        @archiveName => "http://#{fileUri.host}/java-bin/apiCaller.jsp?rsrcPath=#{CGI.escape(@archiveUrl)}&fileDownload=true&promptForLogin=true&errorFormal=html"
      }
      additionalInfo = "To view your results in the Spark GUI:\n  (a) download and unzip the results archive and then\n  (b) launch Spark  via Java Web Start and open the analysis folder.\nSpark Java Web Start Link:\n  http://www.bcgsc.ca/downloads/spark/current/start.jnlp\n"
      
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "ADDITIONALINFO: #{additionalInfo}")
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE, @userEmail, @jobId, @userFirstName, @userLastName, @analysisName, inputInfo, outputInfo, emailSettings, additionalInfo, resultFileLocation, resultFileURL)
      return successEmailObject
    end

    def prepErrorEmail()
      # Build some input info:
      inputInfo = {
        "ROI Track" => @trkApiHelper.extractName(@settings['roiTrack']),
        "# of Data Tracks" => @numDataTracks
      }
      # Build some output info:
      outputInfo = {
        "Output Host" => @dbApiHelper.extractHost(@outputs.first),
        "Output DB"   => @dbApiHelper.extractName(@outputs.first)
      }
      # Filter the settings
      settingsToEmail = [ "normType", "k", "regionLabel", "statsType", "numBins" ]
      emailSettings = {}
      settingsToEmail.each { |kk|
        emailSettings[kk] = @settings[kk]
      }
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE, @userEmail, @jobId, @userFirstName, @userLastName, @analysisName, inputInfo, outputInfo, emailSettings, "")
      # Should always set these exit codes if at all possible
      errorEmailObject.errMessage = @errUserMsg
      errorEmailObject.exitStatusCode = @exitCode
      errorEmailObject.apiExitCode = @apiExitCode
      return errorEmailObject
    end

    # Downloads the input track(s)/file(s) and runs the tool
    # [+returns+] nil
    def run()
      begin
        # prepare the directory structure
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Preparing directory structure...")
        escAnalysisName = CGI.escape(@analysisName)
        resultsDir = escAnalysisName.gsub(/(?:%[a-fA-F0-9]{2,2})+/, "_")
        tmpDataDir = File.expand_path("./tmpData/")
        resultsDir = File.expand_path("./#{resultsDir}/")
        system("mkdir -p #{tmpDataDir}")
        system("mkdir -p #{resultsDir}")
        # Download the input
        dataFiles = []
        regionUri = @settings['roiTrack']
        @regionTrack = @trkApiHelper.extractName(regionUri)
        # A. GET REGION GFF3
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading ROIs as GFF3...")
        fileName = makeRsrcUriAndFileName(regionUri, "gff", true)
        regionsFile = File.expand_path(fileName)
        # Download the score data to cluster
        downloadStatus = downloadROI(regionUri, regionsFile)
        # B. GET DATA FWIG(s)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading data tracks as fwigs...")
        @numDataTracks = 0
        # Collect trks to download (including those within track entity lists
        trkUris = []
        @inputs.each { |input|
          # Ensure we're matching against the *path* part of a URI, not some uri that's in a parameter or something
          uri = URI.parse(input) rescue false
          if(uri)
            if(uri.path =~ %r{/trks/entityList/})     # Have track list, collect get all tracks within
              trks = downloadTrackEntityList(input)
              if(trks)
                trks.each { |trkUri|
                  trkUris << trkUri
                }
              end
            elsif(uri.path =~ %r{/trk/})              # Have just a track, collect just it
              trkUris << input
            end
          end
        }
        # Download the annos in each data track collected
        urlHash = {}
        trkUris.each { |trkUri|
          @numDataTracks += 1
          fileName = makeRsrcUriAndFileName(trkUri, "wig")
          fileName = File.expand_path(fileName)
          urlHash[trkUri] = fileName
        }
        # Download Tracks
        retVal = @trkApiHelper.getDataFilesForTracksWithThreads(urlHash, 'fwig', 'rawdata', nil, @userId)
        if(retVal and retVal.empty?)
          @errUserMsg = "Failed to download the tracks: #{urlHash.keys.inspect} from server after many attempts.\nPlease try again later."
          raise @errUserMsg
        else
        # Add file to list of data files
          dataFiles = urlHash.collect() {|hh, kk| kk}
        end
        # Next write the properties.txt file
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Write Spark properties file...")
        prpWriter = File.open("#{resultsDir}/properties.txt", "w")
        @settings.each_key { |opts|
          unless(NON_SPARK_SETTINGS.key?(opts)) # skip Genboree-specific settings
            optsObj = @settings[opts]
            if(!optsObj.nil? and !optsObj.empty?)
              if(optsObj.is_a?(Array))
                optsObj.compact!
                prpWriter.puts "#{opts}=#{optsObj.join(",")}"
              else
                prpWriter.puts "#{opts}=#{CGI.escape(optsObj)}"
              end
            end
          end
        }
        # "sampleNames"
        prpWriter.print "sampleNames="
        trkUris.each_index { |ii|
          trkUri = trkUris[ii]
          trkName = @trkApiHelper.extractName(trkUri)
          trkName.gsub!(/[^A-Za-z0-9_\.\-%@:]/, '-')
          prpWriter.print trkName
          prpWriter.print ',' unless(ii >= (trkUris.size - 1))
        }
        prpWriter.puts ''
        # TODO: do we need to turn off the Spark_Cache dir or point it elsewhere maybe? (or not relevant b/c of URL only?)
        prpWriter.puts "dataFiles=#{dataFiles.join(",")}"
        prpWriter.puts "regionsFile=#{regionsFile}"
        prpWriter.close()
        # PHASE 1 - PREPROCESSING
        # Spark log file location
        sparkLogFile = "#{resultsDir}/Spark.log"
        # - build appropriate path to jar
        @outFile, @errFile = "Spark.out", "Spark.err"
        jarPath = self.class.buildJarPath('Spark.jar')
        preProcCmd = "java -Xms6144m -Xmx9216m -jar #{jarPath} -l #{sparkLogFile} -p #{resultsDir}/ > ./#{@outFile} 2> ./#{@errFile} "
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Spark preprocessing/analysis command to run:\n    #{preProcCmd}")
        exitStatus = system(preProcCmd)
        statusObj = $?
        body = ''
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spark preprocessing/analysis command completed (exit code: #{statusObj.exitstatus})")
        # Try hard to detect errors
        # - Spark can exit with 0 status even when it clearly failed.
        # - Makes automation hard.
        # - So we need to aggressively go looking for any errors.
        foundSparkError = findSparkError(exitStatus)
        unless(foundSparkError)
          # Spark command ran OK
          # Remove the tmp data files we downloaded
          rmTmpDataCmd = "rm -rf #{tmpDataDir}"
          # Compress Spark results tree
          @archiveName = "./#{File.basename(resultsDir)}.zip"
          zipCmd = "zip -9 -r #{@archiveName} ./#{File.basename(resultsDir)}"
          $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Zip Spark results dir with this command:\n    #{zipCmd}")
          system(zipCmd)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload results zip to target Genboree database...")
          # Get just path part to database
          rcscNew = @dbApiHelper.extractPath(@outputUri)
          rcscNew << "/file/Spark%20-%20Results/#{escAnalysisName}/{file}/data"
          apiCaller = WrapperApiCaller.new(@dbApiHelper.extractHost(@outputUri), rcscNew, @userId)
          @archiveUrl = apiCaller.fillApiUriTemplate({ :file => File.basename(@archiveName) })
          fileObj = File.open("./#{@archiveName}")
          apiCaller.put({ :file => @archiveName }, fileObj)
          fileObj.close unless(fileObj.closed?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "ApiCall put() of results zip replied with:\n\n#{apiCaller.respBody}\n\n #{apiCaller.succeeded?}")
          if(apiCaller.succeeded?)
            # Clean up intermediate files
            `rm -f *.raw *.wig *.gff`
            `rm -rf #{resultsDir}`
          else
            # Compress intermediate files
            `bzip2 *.raw *.wig *.gff`
            raise "ERROR: could not upload Zip archive of results to output database. Tried to upload #{File.basename(@archiveName) unless(fileObj.nil?)} using this resource path: #{rcscNew.inspect}."
          end
        end
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Spark failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to prep or run Spark." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # ------------------------------------------------------------------
    # Get the file name for each of the resource uris including the roi track or file
    def makeRsrcUriAndFileName(uri, trkFileExt, regionsData=false)
      rsrcName = @fileApiHelper.extractName(uri)
      rsrcName = @trkApiHelper.extractName(uri) unless(rsrcName)
      # Make file name we can use for downloading data
      subStr = (regionsData ? "_" : "")
      fileNameBase = CGI.escape(rsrcName).gsub(/(?:%[a-fA-F0-9]{2,2})+/, subStr)
      # Use @fileCounter if more than one track with same name (different DBs etc)
      fileCounterStr = (@fileCounter[fileNameBase] == 0 ? '' : ".#{@fileCounter[fileNameBase]}")
      @fileCounter[fileNameBase] += 1
      fileName = "#{fileNameBase}_#{fileCounterStr}.#{trkFileExt}"
      return fileName
    end

    # Line is assumed to be a gff3 line with a proper Name attribute.
    # This will shim in an appropriate ID attribute based on the name.
    def gff3IdShim(line)
      retVal = line
      fields = line.split(/\t/)
      if(fields.size >= 9)
        avps = fields[8]
        # ONLY SHIM in ID if there is no ID attribute already!
        if(avps !~ /(?:(?:^)|(?:;\s*))ID=[^\t\n;]+/) # then has no ID
          # find the value of Name attribute (which it MUST have)
          avps =~ /(?:(?:^)|(?:;\s*))Name=([^\t\n;]+)/
          recName = $1 || 'UNKNOWN'
          recName.strip!
          # make ID from name by uniquifying IF NECESSARY
          nameCount = @seenGff3Names[recName]
          @seenGff3Names[recName] += 1
          idStr = ((nameCount > 0) ? "#{recName}.#{nameCount}" : recName)
          avps = "ID=\"#{idStr}\"; #{avps}"
        end
        fields[8] = avps
        # rebuild line
        retVal = fields.join("\t")
      end
      return retVal
    end

    # Downloads ROI track.
    # Shim after the download and clean up
    def downloadROI(uri, fileName)
      downStatus = true
      rsrcName = @fileApiHelper.extractName(uri)
      begin
        if(rsrcName) # is a file
          retVal = @fileApiHelper.downloadFile(uri, @userId, "#{fileName}.raw")
          if(!retVal)
            downStatus = false
            @errUserMsg = "Failed to download the ROI file: #{fileName} from server after many attempts.\nPlease try again later."
            raise @errUserMsg
          end
        else # track
          retVal = @trkApiHelper.getDataFileForTrack(uri, "gff3", 'rawdata', nil, "#{fileName}.raw", @userId)     
          if(!retVal)
            downStatus = false
            @errUserMsg = "Failed to download the ROI track: #{uri.inspect} from server after many attempts.\nPlease try again later."
            raise @errUserMsg
          end
        end
        # We need to shim in some kind of "ID" attribute for each GFF3 record.
        # TODO: is this still necessary for new Spark?
        # Apply GFF3 Shim for lines
        writer = File.open(fileName, "w+")
        reader = File.open("#{fileName}.raw")
        reader.each_line { |line|
          writer.puts gff3IdShim(line)
        }
        reader.close
        writer.close
      rescue => err
        downStatus = false
        @errUserMsg = "Failed to download the ROI file: #{fileName} from server after many attempts.\nDetails : #{err.message}."
        raise @errUserMsg
      end
      return downStatus
    end

    # Downloads the contents of a track entity list (if rsrcUri is a track entity list)
    # and returns an Array of the track URIs within.
    def downloadTrackEntityList(rsrcUri)
      retVal = nil
      begin
        if(listName = @trkListApiHelper.extractName(rsrcUri))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading track entity list #{listName.inspect}")
          host = @trkListApiHelper.extractHost(rsrcUri)
          trkListPath = @trkListApiHelper.extractPath(rsrcUri, true) # true means include gbKey if present
          apiCaller = WrapperApiCaller.new(host, trkListPath, @userId)
          httpResp = apiCaller.get()
          if(apiCaller.succeeded?)
            retVal = []
            apiCaller.parseRespBody()
            apiCaller.apiDataObj.each { |urlEntity|
              retVal << urlEntity['url']
            }
          else # API FAILED
            raise "ERROR: API download of track entity list #{rsrcUri.inspect} failed. Returned #{httpResp.inspect}. Response payload:\n\n#{apiCaller.respBody}\n\n"
          end
        end
      rescue => err
        @err = err
        @errInternalMsg = err.message
        @errUserMsg = "ERROR: failure during download of track entity list contents."
        raise err
      end
      return retVal
    end

    def fixGffFileQuotes()
      fixCmd = %q@ find . -type f -name '*.gff' -exec ruby -F$'\t' -i -nae 'if($F.size >= 9) then $F[8].gsub!(/([^=;\t\n]+)=\s*([^";\t\n]+)\s*(;|$)/) { |match| "#{$1}=\"#{$2.strip}\" #{$3}"} ; puts $F.join("\t") ; else ; puts $_ ; end ;' {} \; @
      fixCmdOut = `#{fixCmd}`
      $stderr.puts "STATUS: Fix GFF command exit status: #{$?.exitstatus}. Find command output:\n#{fixCmdOut.inspect}"
    end

    # Try hard to detect errors
    # - Spark can exit with 0 status even when it clearly failed.
    # - Makes automation hard.
    # - So we need to aggressively go looking for any errors.
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for Spark.
    # @return [boolean] indicating if a Spark error was found or not.
    #   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findSparkError(exitStatus)
      retVal = false
      sparkErrorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(exitStatus and File.size("./#{@errFile}") <= 0)
        # So far, so good. Look for ERROR lines on stdout too.
        cmd = "grep -P \"^ERROR\\s\" ./#{@outFile}"
        sparkErrorMessages = `#{cmd}`
        if(sparkErrorMessages.strip.empty?)
          retVal = false
        else
          retVal = true
        end
      else
        sparkErrorMessages = File.read("./#{@errFile}")
        if(sparkErrorMessages.strip.empty?)
          sparkErrorMessages = File.read("./#{@outFile}")
        end
        retVal = true
      end

      # Did we find anything?
      if(retVal)
        @errUserMsg = "Spark Failed. Message from Spark:\n\""
        @errUserMsg << (sparkErrorMessages || "[No error info available from Spark]")
        @errUserMsg << "    \"\n\n"
        @errInternalMsg = @errUserMsg
        @exitCode = 30
      end

      return retVal
    end
  end # class SparkDriver < BRL::Genboree::Tools::ToolWrapper
end ; end ; end ; end # module BRL; module Genboree; module Tools; module Scripts


########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Tools::Scripts::SparkDriver)
end
