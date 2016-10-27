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
  class CuffdiffWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running the 'Cuffdiff' tool.
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
        @timeSeries = @settings['timeSeries']
        @minAlignmentCount = @settings['minAlignmentCount']
        @multiReadCorrect = @settings['multiReadCorrect']
        @upperQuartileNorm = @settings['upperQuartileNorm']
        @fragLenMean = @settings['fragLenMean']
        @fragLenStdev = @settings['fragLenStdev']
        @numImportSamples = @settings['numImportSamples']
        @numBootstrapSamples = @settings['numBootstrapSamples']
        @bootstrapFrac = @settings['bootstrapFrac']
        @maxMleIter = @settings['maxMleIter']
        @hitsNorm = @settings['hitsNorm']
        @poissonDisp = @settings['poissonDisp']
        @maxBundleFrags = @settings['maxBundleFrags']
        # Set up the labels for each input bam file
        @labelHash = Hash.new { |hh, kk|
          hh[kk] = []
        }
        @sampleList = @settings['sampleList']
        @settings.each_key { |setting|
          if(setting =~ /^sampleName/)
            label = @settings[setting]
            @labelHash[label] = @sampleList[setting]
          end
        }
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@labelHash: #{@labelHash.inspect}")
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
        # Run the tool
        # - We use cufflinks 2 package now, via a module load in the .pbs file. The command remains the same though: "cuffdiff"
        @outFile = "./cuffdiff.out"
        @errFile = "./cuffdiff.err"
        command = "cuffdiff -p #{@numCores} -o #{@scratchDir} "
        command << " -T " if(@timeSeries)
        command << " -u " if(@multiReadCorrect)
        command << " -N " if(@upperQuartileNorm)
        command << " --poisson-dispersion " if(@poissonDisp)
        if(@hitsNorm == "totalHitsNorm")
          command << "--total-hits-norm "
        else
          command << " --compatible-hits-norm "
        end
        command << " -m #{@fragLenMean} -s #{@fragLenStdev} --max-mle-iterations #{@maxMleIter} "
        command << " --num-importance-samples #{@numImportSamples}  --num-bootstrap-samples #{@numBootstrapSamples} --bootstrap-fraction #{@bootstrapFrac} "
        command << " --max-bundle-frags #{@maxBundleFrags}"
        command << " -L "
        count = 0
        fileList = ""
        fileArray = []
        @labelHash.each_key { |label|
          if(count == 0)
            command << "#{label.makeSafeStr()}"
          else
            command << ",#{label.makeSafeStr()}"
          end
          @labelHash[label].each { |file|
            fileArray << downloadFile(file)
          }
          fileList << fileArray.join(",")
          fileList << " "
          count += 1
          fileArray.clear()
        }
        command << " #{@genbConf.clusterGTFDir}/#{@refGenome}/refGene.gtf "
        command << "  #{fileList} "
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "Cuffdiff failed to run"
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
        end
        preProcessFile()
        transferFiles()
        # Nuke the input files
        fileArray.each { |file|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing file: #{file}")
          `rm -f #{file}`
        }
      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          @errUserMsg = outStream
        else
          errStream = ""
          errStream = File.read(@errFile) if(File.exists?(@errFile))
          @errUserMsg = errStream if(!errStream.empty?)
        end
        @exitCode = 30
      end
      return @exitCode
    end

    # Only process files with the 'fpkm_tracking' and 'diff' extensions
    # For files that have more than 1 line, i.e, have data, corresponding .xls files
    # will be generated. Files without data will be zipped and transferred to the 'raw' dir under the analysis dir
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
        if(file =~ /\.fpkm_tracking/ or file =~ /\.diff/)
          ff = File.open(file)
          newFile = "#{file}.withGeneName.xls"
          ww = File.open(newFile, "w")
          outBuff = ""
          lineCount = 0
          start = 1
          ff.each_line { |line|
            line.strip!
            fields = line.split(/\t/)
            lastFieldIndex = fields.size - 1
            if(lineCount == 0)
              outBuff << "#{fields[0]}\tgene_Name"
            else
              outBuff << "#{fields[0]}\t#{aliasHash[fields[0]]}"
            end
            for ii in 1..lastFieldIndex
              outBuff << "\t#{fields[ii]}"
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
          if(lineCount == 1)
            `zip #{file}.zip #{file}`
            @transferFileList.push("#{file}.zip")
            `rm #{newFile}`
          else
            @transferFileList.push("#{file}")
            @transferFileList.push(newFile)
          end
        else
          # Skip
        end
      }
      aliasHash = {}
    end

    def transferFiles()
      targetUri = URI.parse(@outputs[0])
      @transferFileList.each { |file|
        if(file !~ /\.zip/)
          tmpPath = "#{targetUri.path}/file/Cuffdiff/#{CGI.escape(@analysisName)}/#{file}/data?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          apiCaller = WrapperApiCaller.new(targetUri.host, tmpPath, @userId)
        else
          tmpPath = "#{targetUri.path}/file/Cuffdiff/#{CGI.escape(@analysisName)}/raw/#{file}/data?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          apiCaller = WrapperApiCaller.new(targetUri.host, tmpPath, @userId)
        end
        apiCaller.put({}, File.open(file))
      }
    end


    def downloadFile(file)
      fileBase = @fileApiHelper.extractName(file)
      tmpFile = "#{@scratchDir}/#{Time.now.to_f}_#{CGI.escape(fileBase)}"
      ww = File.open(tmpFile, "w")
      inputUri = URI.parse(file)
      tmpPath = "#{inputUri.path}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(file)}" if(@dbApiHelper.extractGbKey(file))
      apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
      apiCaller.get() { |chunk| ww.print(chunk) }
      ww.close()
      if(!apiCaller.succeeded?)
        @errUserMsg = "Failed to download file: #{fileBase} from server"
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
      return tmpFile
    end

    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "  Database: '#{@dbName}'\n  Group: '#{@groupName}'\n\n" +
                        "You can download result files from the '#{@analysisName}' folder under the 'Cuffdiff' directory.\n" +
                        "Note that files without data are stored under the 'raw' folder.\n\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end


    def prepErrorEmail()
      #additionalInfo = ""
      #additionalInfo << "     Track: '#{@trackName}'\n" if(@trackName)
      #additionalInfo << "       Class: '#{@className}'\n" if(@className)
      #additionalInfo << "     Database: '#{@dbName}'\n       Group: '#{@groupName}'\n\n" +
      #                  "Began at: #{@startTime}.\nEnding at: #{Time.now}\n\n"
      additionalInfo = "     Error message from Cuffdiff:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CuffdiffWrapper)
end
