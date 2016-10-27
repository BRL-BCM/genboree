#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CufflinksWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'Cufflinks' tool.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @refGenome = @settings['refGenome']
        @multiReadCorrect = @settings['multiReadCorrect']
        @maskFile = @settings['maskFile']
        @fragLenMean = @settings['fragLenMean']
        @fragLenStdev = @settings['fragLenStdev']
        @upperQuartileNorm = @settings['upperQuartileNorm']
        @maxMleIter = @settings['maxMleIter']
        @numImportSamples = @settings['numImportSamples']
        @hitsNorm = @settings['hitsNorm']
        @label = @settings['label']
        @minIsoformFrac = @settings['minIsoformFrac']
        @preMrnaFrac = @settings['preMrnaFrac']
        @juncAlpha = @settings['juncAlpha']
        @minFragsPerTransfrag = @settings['minFragsPerTransfrag']
        @overhangTolerance = @settings['overhangTolerance']
        @maxClosureIntron = @settings['maxClosureIntron']
        @maxBundleLength = @settings['maxBundleLength']
        @maxBundleFrags = @settings['maxBundleFrags']
        @minIntronLength = @settings['minIntronLength']
        @trim3AvgCovThresh = @settings['trim3AvgCovThresh']
        @trim3DropOffFrac = @settings['trim3DropOffFrac']
        @noFauxReads = @settings['noFauxReads']
        @overhang3Tolerance = @settings['overhang3Tolerance']
        @intronOverhangTolerance = @settings['intronOverhangTolerance']
        # Set up group and db name
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        @transferFileList = []
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        fileBase = "#{@format}_upload"
        command = ""
        @user = @pass = nil
        @outFile = @errFile = ""
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
        @inputFile = nil
        # Download the input from the server
        downloadFile()
        # Run the tool
        # - We use cufflinks 2 package now, via a module load in the .pbs file. The command remains the same though: "cuffdiff"
        @outFile = "./cufflinks.out"
        @errFile = "./cufflinks.err"
        command = "cufflinks -p #{@numCores} -o #{@scratchDir} -G #{@genbConf.clusterGTFDir}/#{@refGenome}/refGene.gtf "
        command << " -m #{@fragLenMean} -s #{@fragLenStdev} --max-mle-iterations #{@maxMleIter} "
        command << " --num-importance-samples #{@numImportSamples}  "
        command << " -L #{@label} -F #{@minIsoformFrac} -j #{@preMrnaFrac} -a #{@juncAlpha} --min-frags-per-transfrag #{@minFragsPerTransfrag} "
        command << " --overhang-tolerance #{@overhangTolerance} --max-bundle-length #{@maxBundleLength} --max-bundle-frags #{@maxBundleFrags} --min-intron-length #{@minIntronLength} "
        command << " --trim-3-avgcov-thresh #{@trim3AvgCovThresh} --trim-3-dropoff-frac #{@trim3DropOffFrac} --3-overhang-tolerance #{@overhang3Tolerance} "
        command << " --intron-overhang-tolerance #{@intronOverhangTolerance} "
        if(@hitsNorm == "totalHitsNorm")
          command << " --total-hits-norm "
        else
          command << " --compatible-hits-norm "
        end
        if(@maskFile)
          command << " -M "
        end
        if(@multiReadCorrect)
          command << " -u "
        end
        if(@noFauxReads)
          command << " --no-faux-reads "
        end
        if(@upperQuartileNorm)
          command << " --upper-quartile-norm "
        end
        command << "  #{@inputFile} "
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Cufflinks failed to run"
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
        end
        preProcessFile()
        transferFiles()
        # Nuke the input file:
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing #{@inputFile}")
        `rm -f #{@inputFile}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done.")
      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          errStream = ""
          errStream = File.read(@errFile) if(File.exists?(@errFile))
          @errUserMsg = errStream if(!errStream.empty?)
        end
        @exitCode = 30
      end
      return @exitCode
    end

    def preProcessFile()
      # Construct a hash of aliases
      aliasFile = File.open("#{@genbConf.clusterGTFDir}/#{@refGenome}/refLink.txt")
      aliasHash = {}
      aliasFile.each_line { |line|
        line.strip!
        fields = line.split(/\t/)
        aliasHash[fields[2]] = fields[0]
      }
      aliasFile.close()
      Dir.entries(".").each { |file|
        ff = ww = nil
        next if(file == '.' or file == '..')
        if(file =~ /genes\.fpkm_tracking/ or file =~ /isoforms\.fpkm_tracking/ or file =~ /transcripts\.gtf/)
          ff = File.open(file)
          newFile = nil
          if(file =~ /\.gtf/)
            newFile = "transcripts.withGeneName.gtf"
          else
            newFile = "#{file}.withGeneName.xls"
          end
          ww = File.open(newFile, "w")
          outBuff = ""
          lineCount = 0
          start = 1
          ff.each_line { |line|
            line.strip!
            fields = line.split(/\t/)
            lastFieldIndex = fields.size - 1
            if(file !~ /\.gtf/)
              if(lineCount == 0)
                outBuff << "#{fields[0]}\tgene_Name"
              else
                outBuff << "#{fields[0]}\t#{aliasHash[fields[0]]}"
              end
              for ii in 1..lastFieldIndex
                outBuff << "\t#{fields[ii]}"
              end
            else
              geneId = fields[8].split(";")[0].strip.split(" ")[1]
              geneName = aliasHash[geneId]
              fields[8] = "Name \"#{geneName}\"; #{fields[8]}"
              for ii in 0..lastFieldIndex
                outBuff << "\t#{fields[ii]}"
              end
            end
            outBuff << "\n"
            if(outBuff.size >= 128_000)
              ww.print(outBuff)
              outBuff = ""
            end
            lineCount += 1
          }
          if(!outBuff.empty?)
            ww.print(outBuff)
            outBuff = ""
          end
          ff.close()
          ww.close()
          @transferFileList.push(file)
          @transferFileList.push(newFile)
        else
          # Skip
        end
      }
      aliasHash = {}
    end

    def transferFiles()
      targetUri = URI.parse(@outputs[0])
      @transferFileList.each { |file|
        if(file =~ /withGeneName/)
          tmpPath = "#{targetUri.path}/file/Cufflinks/#{CGI.escape(@analysisName)}/#{file}/data?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          apiCaller = WrapperApiCaller.new(targetUri.host, tmpPath, @userId)
        else
          tmpPath = "#{targetUri.path}/file/Cufflinks/#{CGI.escape(@analysisName)}/raw/#{file}/data?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          apiCaller = WrapperApiCaller.new(targetUri.host, tmpPath, @userId)
        end
        apiCaller.put({}, File.open(file))
        if(apiCaller.succeeded?)
          `rm -f #{file}`
        end
      }
    end


    def downloadFile()
      input = @inputs[0]
      fileBase = @fileApiHelper.extractName(input)
      tmpFile = "#{@scratchDir}/#{Time.now.to_f}_#{CGI.escape(fileBase)}"
      ww = File.open(tmpFile, "w")
      inputUri = URI.parse(input)
      tmpPath = "#{inputUri.path}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
      apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
      apiCaller.get() { |chunk| ww.print(chunk) }
      ww.close()
      if(!apiCaller.succeeded?)
        @errUserMsg = "Failed to download file: #{fileBase} from server"
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
      @inputFile = tmpFile
    end

    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "  Database: '#{@dbName}'\n  Group: '#{@groupName}'\n\n" +
                        "You can download result files from the '#{@analysisName}' folder under the 'Cufflinks' directory.\n\n\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end


    def prepErrorEmail()
      #additionalInfo = ""
      #additionalInfo << "     Track: '#{@trackName}'\n" if(@trackName)
      #additionalInfo << "       Class: '#{@className}'\n" if(@className)
      #additionalInfo << "     Database: '#{@dbName}'\n       Group: '#{@groupName}'\n\n" +
      #                  "Began at: #{@startTime}.\nEnding at: #{Time.now}\n\n"
      additionalInfo = "     Error message from Cufflinks:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CufflinksWrapper)
end
