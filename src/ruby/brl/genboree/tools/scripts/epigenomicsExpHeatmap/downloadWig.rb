#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/normalize/index_sort'
require "brl/genboree/rest/helpers/trackApiUriHelper"
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/script/scriptDriver'
include GSL
include BRL::Genboree::REST


# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  class DownloadWigScript < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--scoreTrack" =>  [ :REQUIRED_ARGUMENT, "-s", "CGI escaped uri for score track" ],
      "--userId" =>  [ :REQUIRED_ARGUMENT, "-u", "userId to compute hostmap for" ],
      "--output" =>  [ :REQUIRED_ARGUMENT, "-o", "output directory" ],
      "--roiTrack" =>  [ :OPTIONAL_ARGUMENT, "-r", "CGI escaped uri for ROI track (if used)" ],
      "--spanAggFunction"=>  [ :OPTIONAL_ARGUMENT, "-S", "SpanAggFunction to use. Defaults to \"avg\"" ],
      "--resolution"=>  [ :OPTIONAL_ARGUMENT, "-R", "Resolution to use. Used only in the absence of ROI track" ],
      "--esValue"=>  [ :OPTIONAL_ARGUMENT, "-e", "Empty String value to be used for regions with no annotation. Defaults to N/A" ],
      "--bedGraph"=>  [ :NO_ARGUMENT, "-b", "Download as bedGraph. Preferrable when only coords and scores are needed. Avoids overhead of heavyweight lff" ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Script to run IDR Inherits from ScriptDriver",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)"],
      :examples => [
        "#{File.basename(__FILE__)} -i ./test22.bed.gz -o ./idrTemp/ -n 2",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      validateAndProcessArgs()
      @exitCode = EXIT_OK
      if(@bedGraph) then
        if(@roiTrack.nil?) then
          downloadBedGraphWithResolution
        else
          downloadBedGraphWithROI
        end
      else
        if(@roiTrack.nil?) then
          downloadWithResolution
        else
          downloadWithROI
        end
      end
      # Must return a suitable exit code number
      return @exitCode
    end
    
    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    
    def validateAndProcessArgs
      @scoreTrack = @optsHash['--scoreTrack']
      @userId = @optsHash['--userId']
      @roiTrack = @optsHash['--roiTrack']
      @output = File.expand_path(@optsHash['--output'])
      if(@roiTrack.nil? or @roiTrack.empty?) then @roiTrack = nil end
      @resolution = @optsHash['--resolution']
      if(@resolution.nil? or @resolution.empty?) then @resolution = 10000 else @resolution = @resolution.to_i end
      @spanAggFunction = @optsHash['--spanAggFunction']
      if(@spanAggFunction.nil? or @spanAggFunction.empty?) then @spanAggFunction = "avg" end
      @bedGraph = (@optsHash['--bedGraph'].nil?) ? false : true
      @esValue = @optsHash['--esValue']
      if(@esValue.nil?) then @esValue = "N/A" end
    end

    def downloadWithResolution
    trackApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new("")
    scrTrkHost = trackApiHelper.extractHost(@scoreTrack)
    apiCaller = WrapperApiCaller.new(scrTrkHost, "", @userId)
    ##Downloading offset file to get the length of each chromosome
    chrHash = {}    
    epsPath = "#{trackApiHelper.dbApiUriHelper.extractPath(@scoreTrack)}/eps?#{URI.parse(@scoreTrack).query}"    
    apiCaller.setRsrcPath(epsPath)
    apiCaller.get
    apiCaller.parseRespBody()
    apiCaller.apiDataObj["entrypoints"].each{|ii| chrHash[ii["name"]] = ii["length"].to_i}
    rsrcPath = "#{trackApiHelper.extractPath(@scoreTrack)}/annos?#{URI.parse(@scoreTrack).query}&format=vwig&span={resolution}&spanAggFunction={spanAggFunction}&emptyScoreValue={esValue}&addCRC32Line=true"
    apiCaller.setRsrcPath(rsrcPath)    
    saveFile = File.open("#{@output}/#{CGI.escape(trackApiHelper.extractName(@scoreTrack))}","w+")
    outFile = "#{@output}/#{CGI.escape(trackApiHelper.extractName(@scoreTrack))}.wig"
    saveFile2 = File.open(outFile,"w+")
    @startPoint = 0
    @endPoint = 0
    @chr = ""
    buff = ''
    ##Downloading wig files
    httpResp = apiCaller.get(
    {
      :spanAggFunction     => @spanAggFunction,
      :resolution => @resolution,
      :esValue  => "N/A"
    }) { |chunk|
      fullChunk = "#{buff}#{chunk}"
      buff = ''
      fullChunk.each_line { |line|
        if(line[-1].ord == 10)
          saveFile2.write line
          if(line =~ /variable/)
            @startPoint = 0
            @chr = line.split(/chrom=/)[1].split(/span/)[0].strip!
        end
          unless(line=~/track/ or line =~/variable/)
            columns = line.split(/\s/)
            score = columns[1]
            @endPoint = columns[0].to_i + @resolution
            if(@endPoint > chrHash[@chr])
              @endPoint = chrHash[@chr]
            end
            saveFile.write("#{@lffClass}\t#{@chr}:#{@startPoint}-#{@endPoint}\t#{@lffType}\t#{@lffSubType}\t#{@chr}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}\n")
            @startPoint = @endPoint
          end
        else
          buff += line
        end
      }
    }
    saveFile.close
    saveFile2.close
    if(apiCaller.succeeded?)
      $stdout.puts "Successfully downloaded  wig file"
      if(!File.verifyCheckSum(outFile)) then
          errMsg = "Retrieved and Computed checksums for #{outFile} do not match"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
          @exitCode = 152
          
          raise errMsg
        end
    else
      $stderr.puts apiCaller.parseRespBody().inspect
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      @exitCode = apiCaller.apiStatusObj['statusCode']
      
      raise "#{apiCaller.apiStatusObj['msg']}"
    end
  end
    
    
    def downloadBedGraphWithResolution
      begin
        trackApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new("")
        scrTrkHost = trackApiHelper.extractHost(@scoreTrack)
        apiCaller = WrapperApiCaller.new(scrTrkHost, "", @userId)
        rsrcPath = "#{trackApiHelper.extractPath(@scoreTrack)}/annos?#{URI.parse(@scoreTrack).query}&format={format}&span={resolution}&spanAggFunction={spanAggFunction}&emptyScoreValue={esValue}&addCRC32Line=true&ucscTrackHeader=true"
        apiCaller.setRsrcPath(rsrcPath)
        #system("mkdir -p #{@output}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "FILLED apiCaller rsrcPath: " +rsrcPath)
        outFile = "#{@output}/#{CGI.escape(trackApiHelper.extractName(@scoreTrack))}"
        saveFile = File.open(outFile,"w+")
        buff = ''
        ## downloading lff/bedgraph file        
        httpResp = apiCaller.get(
        {
          :esValue  => "N/A",
          :format   => "bedGraph",
          :spanAggFunction     => @spanAggFunction,
          :resolution => @resolution
        }){ |chunk|
          saveFile.write chunk
        }
        saveFile.close
      rescue => err
        $stderr.puts "ERROR raised: #{err.message}\n#{err.backtrace.join("\n")}"
      end

      if(apiCaller and apiCaller.succeeded?)
        $stdout.puts "Successfully downloaded file"
        if(!File.verifyCheckSum(outFile)) then
          errMsg = "Retrieved and Computed checksums for #{outFile} do not match"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
          @exitCode = 152
          @errMsg = errMsg
          raise errMsg
        end
      else
        errMsg = "ApiCaller failed.host:#{scrTrkHost}; httpResp: #{apiCaller.httpResponse.inspect}; hostAuthMap: #{apiCaller.hostAuthMap.inspect}; rsrcPath:\n  #{apiCaller.rsrcPath.inspect} st:#{@scoreTrack.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
        @exitCode = 152
        @errMsg = errMsg
        raise errMsg
      end
    end
    
    
    def downloadBedGraphWithROI
      begin
        trackApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new("")
        roiHost = trackApiHelper.extractHost(@roiTrack)
        apiCaller = WrapperApiCaller.new(roiHost, "", @userId)
        rsrcPath = "#{trackApiHelper.extractPath(@roiTrack)}/annos?#{URI.parse(@roiTrack).query}&format={format}&scoreTrack={scrTrack}&spanAggFunction={spanAggFunction}&emptyScoreValue={esValue}&addCRC32Line=true&ucscTrackHeader=true"
        apiCaller.setRsrcPath(rsrcPath)
        #system("mkdir -p #{@output}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "FILLED apiCaller rsrcPath: " +rsrcPath)
        outFile = "#{@output}/#{CGI.escape(trackApiHelper.extractName(@scoreTrack))}"
        saveFile = File.open(outFile,"w+")
        buff = ''
        ## downloading lff/bedgraph file        
        httpResp = apiCaller.get(
        {
          :scrTrack => @scoreTrack,
          :esValue  => "N/A",
          :format   => "bedGraph",
          :spanAggFunction     => @spanAggFunction
        }){ |chunk|
          saveFile.write chunk
        }
        saveFile.close
      rescue => err
        $stderr.puts "ERROR raised: #{err.message}\n#{err.backtrace.join("\n")}"
      end

      if(apiCaller and apiCaller.succeeded?)
        $stdout.puts "Successfully downloaded file"
        if(!File.verifyCheckSum(outFile)) then
          errMsg = "Retrieved and Computed checksums for #{outFile} do not match"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
          @exitCode = 152
          @errMsg = errMsg
          raise errMsg
        end
      else
        errMsg = "ApiCaller failed.host:#{roiHost}; httpResp: #{apiCaller.httpResponse.inspect}; hostAuthMap: #{apiCaller.hostAuthMap.inspect}; rsrcPath:\n  #{apiCaller.rsrcPath.inspect} st:#{@scoreTrack.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
        @exitCode = 152
        @errMsg = errMsg
        raise errMsg
      end
    end
    
    
    def downloadWithROI
      begin
        trackApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new("")
        roiHost = trackApiHelper.extractHost(@roiTrack)
        apiCaller = WrapperApiCaller.new(roiHost, "", @userId)
        rsrcPath = "#{trackApiHelper.extractPath(@roiTrack)}/annos?#{URI.parse(@roiTrack).query}&format=lff&scoreTrack={scrTrack}&spanAggFunction={spanAggFunction}&emptyScoreValue={esValue}&addCRC32Line=true"
        apiCaller.setRsrcPath(rsrcPath)
        system("mkdir -p #{@output}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "FILLED apiCaller rsrcPath: " +rsrcPath)
        outFile = "#{@output}/#{CGI.escape(trackApiHelper.extractName(@scoreTrack))}"
        saveFile = File.open(outFile,"w+")
        buff = ''
        ## downloading lff/bedgraph file        
        httpResp = apiCaller.get(
        {
          :scrTrack => @scoreTrack,
          :esValue  => "N/A",
          :format   => "lff",
          :spanAggFunction     => @spanAggFunction
        }){ |chunk|
          saveFile.write chunk
          #fullChunk = "#{buff}#{chunk}"
          #buff = ''
          #fullChunk.each_line { |line|
          #  if(line[-1].ord == 10)
          #    saveFile.write line
          #  else
          #    buff += line
          #  end
          #}
        }
        saveFile.close
      rescue => err
        $stderr.puts "ERROR raised: #{err.message}\n#{err.backtrace.join("\n")}"
      end

      if(apiCaller and apiCaller.succeeded?)
        $stdout.puts "Successfully downloaded file"
        if(!File.verifyCheckSum(outFile)) then
          errMsg = "Retrieved and Computed checksums for #{outFile} do not match"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
          @exitCode = 152
          @errMsg = errMsg
          raise errMsg
        end
      else
        errMsg = "ApiCaller failed.host:#{roiHost}; httpResp: #{apiCaller.httpResponse.inspect}; hostAuthMap: #{apiCaller.hostAuthMap.inspect}; rsrcPath:\n  #{apiCaller.rsrcPath.inspect} st:#{@scoreTrack.inspect}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
        @exitCode = 152
        @errMsg = errMsg
        raise errMsg
      end
    end

  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::DownloadWigScript)
end


# USAGE
# shuffler.rb {inputFilePath} @outputDirPath} {number of subfiles}


