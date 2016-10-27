#!/usr/bin/env ruby
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/scripts/randomForest/randomForestDriver'
require 'brl/genboree/tools/scripts/randomForest/matrixCreator'
require 'brl/genboree/tools/scripts/randomForest/uploadHelper'
require 'brl/util/util'
require 'stringio'
module BRL; module Genboree; module Tools; module Scripts
  class RandomForestWrapper < BRL::Genboree::Tools::ToolWrapper
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    VERSION = "1.1"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running random forest machine learning.
      This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)" ]
    }
    TOOL_TITLE = "Random Forest"
    # ------------------------------------------------------------------
    # ATTRIBUTES
    # ------------------------------------------------------------------
    attr_accessor :userEmail, :inputFile, :analysisName, :jobId,:jc


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
        @errUserMsg = ""
        @errInternalMsg = ""
        @inputs = @jobConf["inputs"]
        @outputs = @jobConf["outputs"]
        @outputs.each{|output|
          if(output =~ /\/prj\//) then
            @projectUri = output
          elsif (output =~ /\/db\//)
            @dbUri = output
          end
        }
        @jobId = @jobConf["context"]["jobId"]
        @scratch = @jobConf['context']['scratchDir']
        system("mkdir -p #{@scratch}")
        @userId = @jobConf['context']['userId']
        @analysis  = @jobConf['settings']['analysisName']
        @esValue = "N/A"
        @matrixFileName = "otuTable"
        @span = "avg"
        @noAttributes = false
        # Is the comparison based on chosen track attribute values?
        if(@jobConf['settings']["attributes"].nil? or @jobConf['settings']["attributes"].empty?) then
          @noAttributes = true
          @attrNames = ["Set"] # mock attribute for entity list comparison
        else
          @attrNames = @settings["attributes"]
        end
        @minValueCount = @jobConf['settings']['minValueCount']
        if(@minValueCount.nil? or @minValueCount.empty?) then @minValueCount = 2 else @minValueCount = @minValueCount.to_i end
        @firstName  = @jobConf['context']['userFirstName']
        @lastName   = @jobConf['context']['userLastName']
        @cutoff = @jobConf['settings']['cutoff']
        if(@cutoff.nil? or @cutoff.empty?) then
          @cutoffs = [10]
        else
          @cutoffs=[@cutoff]
        end
        @usingROI = true
        @roiTrack = @jobConf['settings']['roiTrack']
        if(@roiTrack.nil? or @roiTrack.empty?) then
          @usingROI = false
          case @jobConf["settings"]["resolution"]
          when "high"
            @resolution = 1000
          when "medium"
            @resolution = 10000
          when "low"
            @resolution = 100000
          else
            @resolution = 1000000
          end
        end
      rescue => err
        @errUserMsg << "ERROR: Could not set up required variables for running job.\n"
        @err = err
        @exitCode = 22
      end
      return @exitCode
    end

    ## Prepare successmail
    def prepSuccessEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      emailObject.inputsText    = buildSectionEmailSummary(@inputs)
      emailObject.outputsText   = buildSectionEmailSummary(@outputs)
      emailObject.settings      = @jobConf['settings']
      if(!(@errUserMsg.nil? or @errUserMsg.empty?)) then  emailObject.additionalInfo = @errUserMsg end
      emailObject.exitStatusCode = @exitCode
      prj =  @projectUri.split(/\/prj\//)[1].chomp!('?')
      @hostOutput = URI.parse(@projectUri).host
      emailObject.resultFileLocations = "http://#{@hostOutput}/java-bin/project.jsp?projectName=#{prj}"      
      return emailObject
    end

    def fillConfCopy
      return {"inputs" => @inputs,
        "scratch" => @scratch,
        "userId" => @userId,
        "esValue" => @esValue,
        "matrixFileName" => @matrixFileName,
        "usingROI" => @usingROI,
        "roiTrack" => @roiTrack,
        "resolution" => @resolution,
        "span" => @span,
        "attrNames" => @attrNames,
      "noAttributes" => @noAttributes}
    end

    ## Prepare Failure mail
    def prepErrorEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(TOOL_TITLE,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      emailObject.inputsText    = buildSectionEmailSummary(@inputs)
      emailObject.outputsText   = buildSectionEmailSummary(@outputs)
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errUserMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

    def projectPlot
      @projectName = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new.extractName(@projectUri)
      writeIndexHtmlFile()
      uploadHelper = UploadHelper.new(@projectUri,@userId)
      uploadHelper.projectUri = @projectUri
      uploadHelper.rsyncFiles(@scratch,"additionalPages")
      addLinks()
    end

    def addLinks()
      # First get the existing news items
      $stderr.debugPuts(__FILE__,__method__,"STATUS","Adding links to project page")
      uri = URI.parse(@projectUri)
      @host = uri.host
      rcscUri = uri.path
      rcscUri = rcscUri.chomp("?")
      rcscUri = "#{rcscUri}/news?"
      rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@projectUri)}" if(@dbApiHelper.extractGbKey(@projectUri))
      apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
      apiCaller.get()
      raise "ApiCaller 'get' news Failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
      existingNews = apiCaller.parseRespBody
      existingItems = existingNews['data']
      payload = nil
      if(!existingItems.empty?)
        existingItems.push(
        {
          'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
          "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a Machine Learning job (#{@jobId}) and the results are available at the link below.
          <ul>
          <li><b>Study Name</b>: #{String::makeSafeStr(@analysis)}</li>
          <li><b>Job Name</b>: #{@jobId}</li>
          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/mlIndex.html\">Link to result plots</a></li>
          </ul>"
        }
        )
        payload = {"data" => existingItems}
      else
        newItems = [
          {
            'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a Machine Learning job (#{@jobId}) and the results are available at the link below.
            <ul>
            <li><b>Study Name</b>: #{String::makeSafeStr(@analysis)}</li>
            <li><b>Job Name</b>: #{@jobId}</li>
            <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/mlIndex.html\">Link to result plots</a></li>
            </ul>"
          }

        ]
        payload = {"data" => newItems}
      end
      apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
      apiCaller.put(payload.to_json)
      raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
    end




    def writeIndexHtmlFile()
      $stderr.puts "Writing out index html page"
      plotsIndexWriter = File.open("#{@scratch}/mlIndex.html", "w")
      plotBuff = "<html>
      <body style=\"background-color:#C6DEFF\">
      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
      <tr>
      <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: RDP Results</th>
      </tr>
      "
      plotBuff << "
      <tr style=\"background-color:white;\">
      <td style=\"border-left:2px solid black;border-right:2px solid black;\">
      <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;\">
      <tr>
      <td style=\"background-color:white\"><b>Study Name:</b></td><td style=\"background-color:white\">#{String::makeSafeStr(@analysis)}</td>
      </tr>
      <tr>
      <td style=\"background-color:white\"><b>Job Name:</b></td><td style=\"background-color:white\">#{@jobId}</td>
      </tr>
      <tr>
      <td style=\"background-color:white\"><b>User:</b></td><td style=\"background-color:white\">#{@userFirstName.capitalize} #{@userLastName.capitalize}</td>
      </tr>
      <tr>
      <td style=\"background-color:white\"><b>Date:</b></td><td style=\"background-color:white\">#{Time.now.localtime.strftime("%Y/%m/%d %R %Z")}</td>
      </tr>
      </table>
      </td>
      </tr>
      "
      # Check if there are any plots
      Dir.chdir("#{@scratch}/RF_Boruta")
      images = nil
      images = `find ./ -type f -name '*.PNG'`
      $stderr.debugPuts(__FILE__,__method__,"DEBUG",images.inspect)
      if(images.empty?)
        plotBuff <<  "
        <tr style=\"background-color:white\">
        <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
        <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;width:700px;\">
        <tr>
        <td style=\"color:red;\">
        The job did not appear to generate any plots.</br>
        </td>
        </tr>
        </table>
        </td>
        </tr>
        "
      else
        Dir.entries("./").each { |dir|
          next if(dir == '.' or dir == '..' or !File.directory?(dir))
          plots = nil
          plots = `find ./#{dir}/graph -type f -name '*.PNG'`
          
          $stderr.debugPuts(__FILE__,__method__,"DEBUG",plots.inspect)
          if(!plots.empty?)
            plotBuff << "
            <tr style=\"background-color:white;\">
            <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
            <table  border=\"0\" cellspacing=\"0\" style=\"padding:15px 35px;\">
            <tr>
            <th colspan=\"1\" style=\"border-bottom:1px solid black; width:300px;background-color:white;\">#{dir}</th>
            </tr>

            "

            png = 0
            Dir.entries("./#{dir}/graph").each { |file|
              png += 1 if(file =~ /\.PNG/)
            }
            pngNo = 0
            Dir.entries("./#{dir}/graph").each { |file|
              if(file =~ /\.PNG/)
                file = File.basename(file)
                pngNo += 1
                if(pngNo < png)
                  plotBuff <<
                  "
                  <tr>
                  <td style=\"vertical-align:top;border-right:1px solid black;border-left:1px solid black;background-color:white\">
                  <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/RF_Boruta/#{dir}/graph/#{file}\">#{file.gsub(".PNG", "").capitalize}</a>
                  </td>
                  </tr>
                  "
                else
                  plotBuff <<
                  "
                  <tr>
                  <td style=\"vertical-align:top;border-right:1px solid black;border-left:1px solid black;border-bottom:1px solid black;background-color:white\">
                  <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobId)}/RF_Boruta/#{dir}/graph/#{file}\">#{file.gsub(".PNG", "").capitalize}</a>
                  </td>
                  </tr>
                  "
                end

              end
            }
          end
          plotBuff << "
          </table>
          </td>
          </tr>
          "
        }
      end

      plotBuff << "
      </table>
      </body>
      </html>
      "
      plotsIndexWriter.print(plotBuff)
      plotBuff = ""
      plotsIndexWriter.close()
    end



    def upload
      Dir.chdir(@scratch)
      system("rm -rf trksDownload")
      system("tar czf raw.result.tar.gz * --exclude=*.log")
      @cutoffs.each{|cutoff|
        system("tar czf #{cutoff}.result.tar.gz `find . -name '*#{cutoff}_[sortedImportance|bag]*.txt'`")
      }
      uploadHelper = UploadHelper.new(@dbUri,@userId)
      uploadHelper.uploadFile("file/RandomForest/#{CGI.escape(@analysis)}/raw.result.tar.gz","#{@scratch}/raw.result.tar.gz")
      ##uploading otu table
      @cutoffs.each{|cutoff|
        uploadHelper.uploadFile("file/RandomForest/#{CGI.escape(@analysis)}/otu_abundance_cutoff_#{cutoff}.result.tar.gz","#{@scratch}/#{cutoff}.result.tar.gz")
      }
      uploadHelper.uploadFile("file/RandomForest/#{CGI.escape(@analysis)}/RF_Summary.xls","#{@scratch}/RF_Boruta/RF_summary.xls")
    end

    # Downloads the input track(s)/file(s) and runs the tool
    # [+returns+] nil
    def run()
      begin
        @confCopy = fillConfCopy
        matrixCreator = BRL::Genboree::Tools::Scripts::MatrixCreator.new(@confCopy)
        matrixCreator.validateSettings
        @valueCounts = matrixCreator.getValueCounts()
        @attrValues = matrixCreator.getAttrValues()
        rfDriver = BRL::Script::RandomForestDriver.new
        validAttrs = []
        @attrNames.each{|attrName|
          validAttr = true
          skipMsg = ""
          
          $stderr.debugPuts(__FILE__,__method__,"DEBUG","#{attrName},#{@valueCounts[attrName].inspect},#{@valueCounts[attrName].keys.length}")
          if (@valueCounts[attrName].keys.length == 1) then
            skipMsg = "Discarding attribute #{attrName} because all tracks have the same attribute value"
            validAttr = false
          elsif (@valueCounts[attrName].keys.length == matrixCreator.getNumTracks)
            skipMsg = "Discarding attribute #{attrName} because each track has a different attribute value"
            validAttr = false
          else
            @valueCounts[attrName].each_key{|kk|
              if(kk == :error) then
                skipMsg = "Discarding attribute #{attrName} because its value could not be retrieved successfully for all inputs"
                validAttr = false
              elsif(@valueCounts[attrName][kk] < @minValueCount) then
                skipMsg = "Discarding attribute #{attrName} because it has too few values. The minimum number required is #{@minValueCount}"
                validAttr = false
              end
            }
          end
          if(validAttr) then
            validAttrs << attrName
          else
            $stderr.debugPuts(__FILE__,__method__,"STATUS",skipMsg)
            @errUserMsg << "#{skipMsg}\n"
          end
        }
        if(validAttrs.empty?) then
          quitMsg = "None of the specified features/attributes have correct, sufficient values. Unable to run RandomForest"
          $stderr.debugPuts(__FILE__,__method__,"ERROR",quitMsg)
          @errUserMsg << "#{quitMsg}\n"
          @errInternalMsg << "#{quitMsg}\n"
          @exitCode = 30
        else
          matrixCreator.createMatrix
          @exitCode = rfDriver.runRandomForest(validAttrs,@attrValues,"#{@scratch}/#{@matrixFileName}",@scratch, @cutoffs)
         
          if(@exitCode != EXIT_OK) then raise "Random Forest Driver did not finish successfully" end
        end
        if(@exitCode == EXIT_OK) then
          projectPlot()
          upload()
        end
      rescue => err
        @err = err
        @errUserMsg << "ERROR: Running Random Forest failed (#{err.message.inspect}).\n"
        @errInternalMsg << "ERROR: Unexpected error trying to run Random Forest."
        $stderr.debugPuts(__FILE__,__method__,"ERROR","Details: #{err.message}")
        $stderr.debugPuts(__FILE__,__method__,"ERROR",err.backtrace.join("\n"))
        @exitCode = 30
      end
      return @exitCode
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
  BRL::Script::main(BRL::Genboree::Tools::Scripts::RandomForestWrapper)
end
