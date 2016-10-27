#!/usr/bin/env ruby

require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/expander'

module BRL; module Genboree; module Tools; module Scripts
  class SparkPreanalysisWrapper < BRL::Genboree::Tools::ToolWrapper
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    VERSION = "1.1"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This wrapper runs one preanalysis Spark job; i.e. one .wig + .gff combination.",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} -j ./jobFile.json",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    TOOL_TITLE = "Spark Preanalysis Job"
    # ------------------------------------------------------------------
    # ATTRIBUTES
    # ------------------------------------------------------------------

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
        @emailMessage =  @apiExitCode = @wigFile = nil
        # Create a results area where we'll run Spark
        @resultsDir       = File.expand_path("./resultsDir")
        @atlasURL         = @settings["atlasURL"]
        @propFileTemplate = File.expand_path(@settings["propFileTemplate"])
        @orgVersion       = @settings["orgVersion"]
        @dataFileName     = @settings["dataFileName"]
        @regionsURL       = @settings["regionsURL"]
        @regionLabel      = File.basename(@regionsURL, '.gff').gsub(/_/, ' ')
        @sampleNames      = File.basename(@dataFileName, '.wig.gz').gsub(/[^A-Za-z0-9_\.\-%@:]/, '-')
        @canonicalWigFileUrl = ''
        @inputs.each { |input|
          @canonicalWigFileUrl = input if(input.size > @canonicalWigFileUrl.size)
        }
        @canonicalWigFilePath = "#{@resultsDir}/#{File.basename(@canonicalWigFileUrl)}"
        @regionsFile = "#{@resultsDir}/#{File.basename(@regionsURL)}"
        @rsyncTargetDir = @outputs.first
        `mkdir -p #{@resultsDir}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracted these settings from jobFile:\n\n  @atlasURL => #{@atlasURl.inspect}\n  @propFileTemplate => #{@propFileTemplate.inspect}\n  @orgVersion => #{@orgVersion.inspect}\n  @dataFileName => #{@dataFileName.inspect}\n  @regionsURL => #{@regionsURL.inspect}\n  @regionLabel => #{@regionLabel.inspect}\n  @sampleNames => #{@sampleNames.inspect}\n  @rsyncTargetDir => #{@rsyncTargetDir.inspect}\n  @canonicalWigFileUrl => #{@canonicalWigFileUrl.inspect}\n  @canonicalWigFilePath => #{@canonicalWigFilePath.inspect}\n  @resultsDir => #{@resultsDir.inspect}\n\n")
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @err = err
        @exitCode = 22
      end
      return @exitCode
    end

    def prepSuccessEmail()
      # Build some input info:
      inputInfo = {}
      @inputs.each_index { |ii|
        inputInfo["Input ##{ii+1}"] = @inputs[ii]
      }
      # Build some output info:
      outputInfo = {
        "Rsync Target" => @outputs.first
      }
      # Filter the settings
      settingsToEmail = [ "atlasURL", "propFileTemplate", "orgVersion", "dataFileName", "regionsURL" ]
      emailSettings = {}
      settingsToEmail.each { |kk|
        emailSettings[kk] = @settings[kk]
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE, @userEmail, @jobId, @userFirstName, @userLastName, "Spark Preanalysis Job", inputInfo, outputInfo, emailSettings)
      return successEmailObject
    end

    def prepErrorEmail()
      # Build some input info:
      inputInfo = {}
      @inputs.each_index { |ii|
        inputInfo["Input ##{ii+1}"] = @inputs[ii]
      }
      # Build some output info:
      outputInfo = {
        "Rsync Target" => @outputs.first
      }
      # Filter the settings
      settingsToEmail = [ "atlasURL", "propFileTemplate", "orgVersion", "dataFileName", "regionsURL" ]
      emailSettings = {}
      settingsToEmail.each { |kk|
        emailSettings[kk] = @settings[kk]
      }
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE, @userEmail, @jobId, @userFirstName, @userLastName, "Spark Preanalysis Job", inputInfo, outputInfo, emailSettings, "")
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
        getRegionsFile()
        getDataFile()
        createPropertiesFile()
        runSpark()
        rsyncSparkResults()
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of Spark failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to prep or run Spark." if(@errInternalMsg.nil?)
        @exitCode = 30
      ensure
        cleanup()
      end
      return @exitCode
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # ------------------------------------------------------------------
    def getRegionsFile()
      @regionsFile = downloadFileAtUrl(@regionsURL, @regionsFile, true)
      return @regionsFile
    end

    def getDataFile()
      @uncompCanonicalWigFile = downloadFileAtUrl(@canonicalWigFileUrl, @canonicalWigFilePath)
      return @uncompCanonicalWigFile
    end

    def downloadFileAtUrl(url, outputFile, uncompress=true)
      retVal = outputFile
      # Now download file
      wgetCmd = "rm -f #{outputFile} ; wget -o ./wget.log -O #{outputFile} #{url}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading a file with this wget command:\n\n  #{wgetCmd.inspect}\n\n")
      wgetOut = `#{wgetCmd}`
      exitStatusObj = $?
      if(exitStatusObj.success?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloaded a file (#{File.size(@regionsFile).commify} bytes)")
      else
        @errUserMsg = "ERROR: Could not download file via url (#{url.inspect}) using wget. wget exit code: #{exitStatusObj.exitstatus.inspect}. wget output:\n\n#{wgetOut}\n\n"
        @errInternalMsg = @errUserMsg
        @exitCode = 42
        raise "ERROR: wget download error."
      end
      # Should we try uncompressing the file? (Shouldn't hurt even for plain text)
      if(uncompress)
        # Expand file, put in convenient place
        expander = BRL::Util::Expander.new(outputFile)
        expander.extract('text')
        `mv #{expander.uncompressedFileList.first} #{@resultsDir}/`
        retVal = "#{@resultsDir}/#{File.basename(expander.uncompressedFileList.first)}"
        # Clean up expansion intermediaries
        expander.removeIntermediateCompFiles()
        `rm -rf #{expander.tmpDir}`
        `rm -rf #{outputFile}` unless(File.expand_path(outputFile) == File.expand_path(retVal)) # i.e. no actual expansion
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Expanded file & removed compressed original. File now available at #{retVal.inspect} (#{File.size(retVal).commify} bytes)")
      end
      return retVal
    end

    def createPropertiesFile()
      @propTemplateStr = File.read(@propFileTemplate)
      @propTemplateStr.gsub!(/\{REGION_LABEL\}/, @regionLabel)
      @propTemplateStr.gsub!(/\{SAMPLE_NAMES\}/, @sampleNames)
      @propTemplateStr.gsub!(/\{ORG_VERSION\}/, @orgVersion)
      @propTemplateStr.gsub!(/\{WIG_FILE_PATH\}/, @uncompCanonicalWigFile)
      @propTemplateStr.gsub!(/\{GFF_FILE_PATH\}/, @regionsFile)
      propFile = File.open("#{@resultsDir}/properties.txt", "w+")
      propFile.write(@propTemplateStr)
      propFile.close
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Created Spark properties file. Contents:\n\n  " + @propTemplateStr.gsub(/\n/, "\n  ") + "\n")
      return @propTemplateStr
    end

    def runSpark()
      # PHASE 1 - PREPROCESSING
      # Spark log file location
      sparkLogFile = "#{@resultsDir}/Spark.log"
      # - build appropriate path to jar
      @outFile, @errFile = "Spark.out", "Spark.err"
      jarPath = self.class.buildJarPath('Spark.jar')
      preProcCmd = "java -Xms1024m -Xmx4096m -jar #{jarPath} -l #{sparkLogFile} -p #{@resultsDir}/ > ./#{@outFile} 2> ./#{@errFile} "
      $stderr.debugPuts(__FILE__, __method__, "COMMAND", "Spark preanalysis command to run:\n\n    #{preProcCmd}\n\n")
      exitStatus = system(preProcCmd)
      statusObj = $?
      body = ''
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Spark preanalysis command completed (exit status: #{exitStatus} ; exit code: #{statusObj.exitstatus})")
      if(statusObj.exitstatus != 0 or File.size("./#{@errFile}") > 0) # FAILED: pre-proc error; collect info (we check the .err file since it looks like pre-processing can fail without exiting with non-0)
        @errUserMsg = "\nSpark failed to run successfully (Exit code:#{statusObj.exitstatus}).\nMessage from Spark:\n\""
        errorReader = File.open("./#{@errFile}")
        errorReader.each_line { |line|
          @errUserMsg << "    #{line}"
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        if(File.size("./#{@outFile}") > 0)
          @errUserMsg << "  Spark Status Messages:\n\""
          outReader = File.open("./#{@outFile}")
          outReader.each_line { |line|
            @errUserMsg << "    #{line}"
          }
          outReader.close()
          @errUserMsg.chomp!
          @errUserMsg << "    \""
        end
        @exitCode = 30
        raise
      end
      return @exitCode
    end

    def rsyncSparkResults()
      # Create a tmp target subdir which will rsync to the real target
      @tmpTargetDir = "./tmpTarget/"
      `mkdir -p #{@tmpTargetDir}/`
      # Create the appropriate dir tree under which the Spark files will live
      # - remove the known root @atlasURL
      wigUrlPartial = @canonicalWigFileUrl.sub(@atlasURL, '')
      # - get just the dir path
      wigUrlPath = File.dirname(wigUrlPartial)
      # - create the dir path
      tmpTargetPath = File.expand_path("#{@tmpTargetDir}/#{wigUrlPath}")
      `mkdir -p #{tmpTargetPath}`
      # Move all the .dat and .stats file Spark made to that location
      `find #{@resultsDir}/ -type f -name "*.dat" -exec mv {} #{File.expand_path(tmpTargetPath)}/ \\;`
      `find #{@resultsDir}/ -type f -name "*.stats" -exec mv {} #{File.expand_path(tmpTargetPath)}/ \\;`
      # Collect the relative paths to the files we moved into place
      findOut = `find #{@tmpTargetDir} -type f`
      canonicalRelativePaths = []
      findOut.each_line { |line|
        canonicalRelativePath = line.strip.gsub(/#{@tmpTargetDir}/, '')
        canonicalRelativePaths << canonicalRelativePath
      }
      # Create relative softlinks from alternative locations to this canonical location
      @inputs.each { |inputUrl|
        unless(inputUrl == @canonicalWigFileUrl)  # Already handled the canonical one
          # Get just the dir path
          # - remove the known root @atlasURL
          altWigUrlPartial = inputUrl.sub(@atlasURL, '')
          # - get just the dir path
          altWigUrlPath = File.dirname(altWigUrlPartial)
          # - create the dir path
          altTmpTargetPath = File.expand_path("#{@tmpTargetDir}/#{altWigUrlPath}")
          `mkdir -p #{altTmpTargetPath}`
          # Now for each canonical file we moved in place, create a link TO it FROM alt location
          altDepth = altWigUrlPath.split(/\//).size
          altParentPath = "../" * altDepth
          canonicalRelativePaths.each { |canonicalRelativePath|
            relPath2Canonical = "#{altParentPath}#{canonicalRelativePath}"
            lnCmd = "ln -s #{relPath2Canonical} #{File.expand_path(altTmpTargetPath)}/"
            `#{lnCmd}`
          }
        end
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done setting up temporary Spark preanalysis dir tree, including softlinks.")
      # Rsync the tmpTargetDir contents to @rsyncTargetDir
      `rsync -rlD #{@tmpTargetDir}/ #{@rsyncTargetDir}/ > rsync.spark.results.out 2> rsync.spark.results.err`
      exitStatusObj = $?
      if(exitStatusObj.success?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Rsync'd Spark preanalysis results to target locations.")
      else
        @errUserMsg = "ERROR: Could not rsync the Spark results to the target location. Rsync exit status: #{exitStatusObj.exitstatus.inspect}. See rsync .out and .err files for more details."
        @errInternalMsg = @erruserMsg
        @exitCode = 43
        raise "ERROR: rsync error."
      end
      return true
    end

    def cleanup()
      # Remove the tmp data file we downloaded
      `rm -f #{@uncompCanonicalWigFile}`
      if(@exitCode == 0)
        # Remove results dir and temp target dir
        `rm -rf #{@resultsDir} #{@tmpTargetDir}`
      else
        # Compress what we can
        `tar czvf #{@resultsDir}.tar.gz #{@resultsDir}`
        `tar czvf #{@tmpTargetDir}.tar.gz #{@tmpTargetDir}`
      end
      return true
    end
  end # class SparkPreanalysisWrapper < BRL::Genboree::Tools::ToolWrapper
end ; end ; end ; end # module BRL; module Genboree; module Tools; module Scripts

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Tools::Scripts::SparkPreanalysisWrapper)
end
