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
  class BigFilesWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for generating big* files for tracks in Genboree.
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
        @type = @settings['type']
        @groupAndDbHash = @settings['groupAndDbHash']
        @isHdhv = false
        @typeHash = {}
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
        @inputs.each { |input|
          trkName = @trkApiHelper.extractName(input)
          @inputFile = downloadTrack(input)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading entrypoints...")
          dbUri = URI.parse(@dbApiHelper.extractPureUri(input))
          host = dbUri.host
          rsrcPath = dbUri.path
          groupName = @grpApiHelper.extractName(input)
          dbName = @dbApiHelper.extractName(input)
          tmpPath = "#{rsrcPath}/eps?"
          tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(host, tmpPath, @userId)
          apiCaller.get()
          refFileWriter = File.open("chrom.sizes", "w")
          apiCaller.parseRespBody['data']['entrypoints'].each { |rec|
            refFileWriter.puts "#{rec['name']}\t#{rec['length']}"
          }
          refFileWriter.close()
          @errFile = @outFile = @outputFile = nil
          exitstatus = 0
          if(@type == "auto")
            if(@isHdhv)
              exitstatus = runBigWig(input)
            else
              exitstatus = runBigBed(input)
            end
          else
            if(@type == "bigwig")
              exitstatus = runBigWig(input)
            else
              exitstatus = runBigBed(input)
            end
          end
          if(exitstatus != 0)
            raise "BigWig/BigBed failed.\n\nCheck #{@outFile} and #{@errFile} for more information. "
          end
          # Copy the big file to the server
          bigFileRsrcPath = rsrcPath.dup()
          bigFileRsrcPath << "/file/#{@outputFile}/data?fileType=bigFile&trackName=#{CGI.escape(trkName)}"
          bigFileRsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(host, bigFileRsrcPath, @userId)
          apiCaller.put({}, File.open(@outputFile))
          if(!apiCaller.succeeded?)
            @errUserMsg = "Could not put file: #{@outputFile} to host: #{host}.\nAPI Error Message:\n#{apiCaller.respBody.inspect}"
            raise "API Call FAILED to put big* file.Error:\n#{apiCaller.respBody.inspect}"
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Copied over big file to host: #{host}")
          end
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing files: #{@inputFile} and #{@outputFile}")
          `rm -f #{@inputFile} #{@outputFile}`
          payload = nil
          attributeType = nil
          if(@type == "auto")
            if(@isHdhv)
              @typeHash[input] = "bigWig"
              attributeType = "BigWig"
            else
              @typeHash[input] = "bigBed"
              attributeType = "BigBed"
            end
          else
            if(@type == "bigwig")
              attributeType = "BigWig"
              @typeHash[input] = "bigWig"
            else
              attributeType = "BigBed"
              @typeHash[input] = "bigBed"
            end
          end
        }
      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          @errUserMsg = outStream if(@errUserMsg.nil? or @errUserMsg.empty?)
        else
          @errUserMsg = File.read(@errFile) if(File.exists?(@errFile) and (@errUserMsg.nil? or @errUserMsg.empty?))
          # Add more info in email if the error is because of overlapping regions
          if(@errUserMsg =~ /Overlapping/)
            @errUserMsg << "\n\nNOTE: Running BigWig File generation is not supported for data with overlapping regions since the UCSC bigwig program does not support overlapping data.\nIf this data was uploaded via formats other than bedGraph/wig, we recommend using the BigBed Files generation tool."
          end
        end
        # Try to clean up @inputFile and @outputFile (gzip them, since there was an error)
        `gzip -9 #{@inputFile} #{@outputFile}`
        @exitCode = 30
      end
      return @exitCode
    end

    def runBigWig(input)
      @outputFile = "trackAnnos.bw"
      @errFile = "bedGraphToBigWig.err"
      @outFile = "bedGraphToBigWig.out"
      command = "bedGraphToBigWig #{@inputFile} chrom.sizes #{@outputFile} > #{@outFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      exitObj = $?.dup()
      return exitObj.exitstatus
    end

    def runBigBed(input)
      @outputFile = "trackAnnos.bb"
      @errFile = "bedToBigBed.err"
      @outFile = "bedToBigBed.out"
      command = "bedToBigBed #{@inputFile} chrom.sizes #{@outputFile} > #{@outFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      exitObj = $?.dup()
      return exitObj.exitstatus
    end

    def downloadTrack(input)
      inputUri = URI.parse(input)
      trkName = @trkApiHelper.extractName(input)
      if(@type == "auto")
        @isHdhv = false
        tmpPath = "#{inputUri.path}/attributes?"
        tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
        apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
        apiCaller.get()
        resp = apiCaller.parseRespBody['data']
        resp.each { |attr|
          if(attr['text'] == 'gbTrackRecordType')
            @isHdhv = true
            break
          end
        }
        apiCaller = tmpFile = nil
        if(@isHdhv)
          tmpFile = "#{CGI.escape(trkName)}.bedgraph"
          tmpPath = "#{inputUri.path}/annos?format=bedGraph&spanAggFunction=avg"
          tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
        else
          tmpFile = "#{CGI.escape(trkName)}.lff"
          tmpPath = "#{inputUri.path}/annos?format=bed&spanAggFunction=avg"
          tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
        end
      else
        if(@type == "bigwig")
          tmpFile = "#{CGI.escape(trkName)}.bedgraph"
          tmpPath = "#{inputUri.path}/annos?format=bedGraph&spanAggFunction=avg"
          tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
        else
          tmpFile = "#{CGI.escape(trkName)}.lff"
          tmpPath = "#{inputUri.path}/annos?format=bed&spanAggFunction=avg"
          tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
          apiCaller = WrapperApiCaller.new(inputUri.host, tmpPath, @userId)
        end
      end
      ff = File.open(tmpFile, 'w')
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading track: #{trkName.inspect}")
      apiCaller.get() { |chunk| ff.print(chunk) }
      ff.close
      `grep -v 'track' #{tmpFile} > #{tmpFile}.tmp; mv #{tmpFile}.tmp #{tmpFile}`
      return tmpFile
    end

    def prepSuccessEmail()
      additionalInfo = "You can use the following links to either download the big* files or visualize the data in the UCSC genome browser (if the database has been unlocked)\n\n"
      @typeHash.each_key { |input|
        dbUri = URI.parse(@dbApiHelper.extractPureUri(input))
        tmpPath = dbUri.path
        tmpPath << "?gbKey=#{@dbApiHelper.extractGbKey(input)}" if(@dbApiHelper.extractGbKey(input))
        apiCaller = WrapperApiCaller.new(dbUri.host, tmpPath, @userId)
        apiCaller.get()
        resp = apiCaller.parseRespBody['data']
        dbVer = resp['version']
        gbKey = resp['gbKey']
        additionalInfo << "#{@trkApiHelper.extractName(input)}:\n\n"
        additionalInfo << "Download #{@typeHash[input]} file:\n"
        if(dbVer =~ /^\S/)
          if(!gbKey.empty?)
            additionalInfo << "#{input.chomp("?")}/#{@typeHash[input]}?gbKey=#{gbKey}\n\n"
            additionalInfo << "Use this link to view the track in the UCSC browser.\n"
            customText = "#{input.chomp("?")}?gbKey=#{CGI.escape(gbKey)}&format=ucsc_browser&ucscType=#{@typeHash[input]}&ucscSafe=on"
            additionalInfo << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{dbVer}&hgct_customText=#{CGI.escape(customText)}\n\n"
          else
            additionalInfo << "#{input.chomp("?")}/#{@typeHash[input]}?gbKey=xxxxx\n\n"
            additionalInfo << "This database has not been unlocked. After unlocking, use this link to view the track in the UCSC browser after replacing the 'xxxxx' with the correct gbkey.\n"
            customText = "#{input.chomp("?")}?gbKey=xxxxx&format=ucsc_browser&ucscType=#{@typeHash[input]}&ucscSafe=on"
            additionalInfo << "http://genome.ucsc.edu/cgi-bin/hgTracks?db=#{dbVer}&hgct_customText=#{CGI.escape(customText)}\n\n"
          end
        end
        additionalInfo << "\n\n"
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return successEmailObject
    end

    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::BigFilesWrapper)
end
