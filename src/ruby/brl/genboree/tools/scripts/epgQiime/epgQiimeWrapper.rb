#!/usr/bin/env ruby
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/scripts/randomForest/matrixCreator'
require 'brl/genboree/tools/scripts/epgQiime/epgQiimeDriver'
require 'brl/genboree/tools/scripts/randomForest/uploadHelper'
require 'stringio'
module BRL; module Genboree; module Tools; module Scripts
        
  class EpgQiimeWrapper < BRL::Genboree::Tools::ToolWrapper
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    VERSION = "1.1"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running Qiime for epigenomic data.
      This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)" ]
    }
    TOOL_TITLE = "Epg Qiime"
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
        @scratch = "#{@jobConf['context']['scratchDir']}"
        system("mkdir -p #{@scratch}")
        @resultDir = "#{@scratch}/QIIME_result"
        @plotDir = "#{@scratch}/QIIME_result/plots"
        @userId = @jobConf['context']['userId']
        @analysis  = @jobConf['settings']['analysisName']
        @esValue = "N/A"
        @matrixFileName = "otuTable"
        @mappingFileName = "mapping.txt"
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
        @metrics = ["euclidean",
      "binary_chisq",
      "binary_chord",
      "binary_euclidean",
      "binary_hamming",
      "binary_jaccard",
      "binary_lennon",
      "binary_ochiai",
      "binary_pearson",
      "binary_sorensen_dice",
      "bray_curtis",
      "canberra",
      "chisq",
      "chord",
      "gower",
      "hellinger",
      "kulczynski",
      "manhattan",
      "morisita_horn",
      "pearson",
      "soergel",
      "spearman_approx",
      "specprof"
    ]
      rescue => err
        @errUserMsg << "ERROR: Could not set up required variables for running job.\n"
        @err = err
        @exitCode = 22
      end
      
      return @exitCode
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
      "noAttributes" => @noAttributes,
      "qiimeFormat" => true}
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
 
   def compression
      system("mkdir -p #{@scratch}/htmlPages/#{String::makeSafeStr(@analysis)}/QIIME/#{@jobId}")
      system("cp -r #{@plotDir} #{@scratch}/htmlPages/#{String::makeSafeStr(@analysis)}/QIIME/#{@jobId}")
      Dir.chdir(@resultDir)
      system("tar czf raw.results.tar.gz * --exclude=plots")
      system("tar czf plots.result.tar.gz #{@plotDir}")
      return EXIT_OK
   end
    
    
    def createMappingFile(attrNames, attrValues, trkUriLists, mappingFile)
      fh = File.open(mappingFile,"w")
      fh.print("#Track")
      attrNames.each{|aa| fh.print("\t#{aa}")}
      fh.puts
      @trkUriLists.each{|tl|
        tl.each{|track|
          trackName = @trkApiHelper.extractName(track)
          fh.print(CGI.escape(trackName))
          attrNames.each{|aa| fh.print("\t#{attrValues[aa][CGI.escape(trackName)]}")}
          fh.puts
        }
      }
      fh.close
    end
    
   
   def projectPlot
     prefix = "#{@scratch}/htmlPages/#{String::makeSafeStr(@analysis)}/QIIME/#{CGI.escape(@jobId)}"
     @projectName = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new.extractName(@projectUri)
      Dir.chdir("#{prefix}/plots")
      twoDImagePresent = `find ./ -type f -name *.png`
      threeDImagePresent = `find ./ -type f -name *.kin`
     if(twoDImagePresent.empty? and threeDImagePresent.empty?)  then # No Plots present
           writeErrorHtml("#{prefix}/plots")
     else
       writeIndexHtmlFile("#{prefix}/plots")
     end
      uploadHelper = UploadHelper.new(@projectUri,@userId)
      uploadHelper.projectUri = @projectUri
      uploadHelper.rsyncFiles(prefix,"additionalPages")
      addLinks()
      return EXIT_OK
   end
   
  def addLinks()
      # First get the existing news items
      $stderr.puts "Adding links to project page"
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
                              "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a QIIME job (#{@jobId}) and the results are available at the links below.
                              <ul>
                                <li><b>Study Name</b>: #{String::makeSafeStr(@analysis)}</li>
                                <li><b>Job Name</b>: #{@jobId}</li>
                                <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobId))}/plots/index.html\">Link to results</a></li>
                                
                              </ul>"
                            }
                          )
        payload = {"data" => existingItems}
      else
        newItems = [
                      {
                        'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                        "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a QIIME job (#{@jobId}) and the results are available at the links below.
                        <ul>
                          <li><b>Study Name</b>: #{String::makeSafeStr(@analysis)}</li>
                          <li><b>Job Name</b>: #{@jobId}</li>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobId))}/plots/cdhitIndex.html\">Link to cdhit results</a></li>
                          <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobId))}/plots/cdhit-normalizedIndex.html\">Link to cdhit-normalized results</a></li>
                        </ul>"
                      }
                  ]
        payload = {"data" => newItems}
      end
      apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
      apiCaller.put(payload.to_json)
      raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
    end
  # Creates index html files
  # [+type+] cdhit or cdhit-normalized
  # [+returns+] nil
  def writeIndexHtmlFile(dir)
    $stderr.puts "Writing out index html pages"
    indexWriter = File.open("#{dir}/index.html", "w")
    cdhitBuff = "
                  <html>
                    <body style=\"background-color:#C6DEFF\">
                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: QIIME Results</th>
                        </tr>
                "
    cdhitBuff << "
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
                    <tr style=\"background-color:white\">
                      <td style=\"border-left:2px solid black;border-right:2px solid black;\">
                        <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;width:700px;\">
                          <tr>
                            <td>
                              Below are the beta diversity metric results for this QIIME job. Clicking on the links will open up metric plots/images on your browser. Pages with
                              <b>2D Plots</b>
                              will show a simple 2-dimensional image, while pages with
                              <b>3D Plots</b>
                              will use a Java Applet to view and manipulate the 3-dimensional plot
                              <span style=\"font-size: 80%;\">
                                (
                                  <a href=\"http://www.java.com\">Download Java</a>
                                )
                              </span>
                              .
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                "
    cdhitBuff << "
                    <tr style=\"background-color:white\">
                      <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                        <table  border=\"0\" cellspacing=\"0\" style=\"width:50%;margin:10px auto 10px auto;\">
                          <tr>
                            <th colspan=\"1\" style=\"border-bottom:1px solid black; width:300px;background-color:white;\">QIIME Plots</th>
                          </tr>

                    "
    metricsSize = @metrics.size
    metricNo = 0
    @metrics.each { |metric|
      metricNo += 1
      if(metricNo < metricsSize )
        cdhitBuff << "
                      <tr>
                        <td style=\"border-left:1px solid black;border-right:1px solid black;padding-left:5px;\">#{metric.gsub(/_/," ")}"
      else
        cdhitBuff << "
                      <tr>
                        <td style=\"border-left:1px solid black;border-right:1px solid black;border-bottom:1px solid black;padding-left:5px;\">#{metric.gsub(/_/," ")}"
      end
      if(File.directory?("./#{metric}_3d-all"))
        Dir.entries("./#{metric}_3d-all").each { |file|
          cdhitBuff << " <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobId))}/plots/#{metric}_3d-all/#{file}\">(3D)</a>" if(file =~ /\.html/)
        }
      end
      if(File.directory?("./#{metric}_2d-all"))
        Dir.entries("./#{metric}_2d-all").each { |file|
          cdhitBuff << " <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobId))}/plots/#{metric}_2d-all/#{file}\">(2D)</a>" if(file =~ /\.html/)
        }
      end
      cdhitBuff << "  </td>
                    </tr>
                  "
    }
    cdhitBuff << "
                            </table>
                          </td>
                        </tr>
                      </table
                    </body>
                  </html>
                "
    indexWriter.print(cdhitBuff)
    indexWriter.close()
  end


  # Called when no plots are present. Writes out job info and an error message in the index html file
  def writeErrorHtml(dir)
    genbConfig = BRL::Genboree::GenboreeConfig.load()
    $stderr.puts "Writing out error html..."
      indexWriter = File.open("#{dir}/index.html", "w")
      indexWriter.print("
                                <html>
                                  <body style=\"background-color:#C6DEFF\">
                                    <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                                      <tr>
                                        <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: QIIME Results (#{type})</th>
                                      </tr>
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
                                      <tr style=\"background-color:white\">
                                        <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                                          <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;width:700px;\">
                                            <tr>
                                              <td style=\"color:red;\">
                                                ERROR: The job did not appear to generate any 2D or 3D plots. There may have been a problem with the run.</br></br>
                                                Please contact genboree_admin@genboree.org with all the information above for help with this error.
                                              </td>
                                            </tr>
                                          </table>
                                        </td>
                                      </tr>
                                    </table>
                                  </body>
                                </html>
                              "
                            )
      indexWriter.close()
  end

    
    def uploadData
      system("rm -rf trksDownload")
      uploadHelper = UploadHelper.new(@dbUri,@userId)
      filePrefix = "file/QIIME/#{CGI.escape(@analysis)}"
      uploadHelper.uploadFile("#{filePrefix}/otu.table","#{@scratch}/#{@matrixFileName}")
      uploadHelper.uploadFile("#{filePrefix}/plots.result.tar.gz","#{@resultDir}/plots.result.tar.gz")
      uploadHelper.uploadFile("#{filePrefix}/raw.results.tar.gz","#{@resultDir}/raw.results.tar.gz")
      uploadHelper.uploadFile("#{filePrefix}/settings.json","#{@scratch}/jobFile.json")
      uploadHelper.uploadFile("#{filePrefix}/mapping.txt","#{@scratch}/#{@mappingFileName}")
      return EXIT_OK
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
        @trkUriLists = matrixCreator.getTrkUriLists()
        validAttrs = []
        @attrNames.each{|attrName|
          validAttr = true
          skipMsg = ""
          if (@valueCounts[attrName].keys.length == 1) then
            skipMsg = "Discarding attribute #{attrName} because all tracks have the same attribute value"
            validAttr = false
          elsif (@valueCounts[attrName].keys.length == matrixCreator.getNumTracks)
            skipMsg = "Discarding attribute #{attrName} because each track has a different attribute value"
            validAttr = false
          else
            @valueCounts[attrName].each_key{|kk|
              if(kk == :error) then
                skipMsg = "Discarding attribute #{attrName} because of its value could not be retrieved successfully for all inputs"
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
          quitMsg = "None of the specified features/attributes have correct, sufficient values. Unable to run Epg Qiime"
          $stderr.debugPuts(__FILE__,__method__,"ERROR",quitMsg)
          @errUserMsg << "#{quitMsg}\n"
          @errInternalMsg << "#{quitMsg}\n"
          @exitCode = 30
        else
          matrixCreator.createMatrix
          system("mkdir -p #{@resultDir}")
          system("mkdir -p #{@plotDir}")
          createMappingFile(validAttrs,@attrValues,@trkUriLists,"#{@scratch}/#{@mappingFileName}")
          epgQiimeDriver = BRL::Script::EpgQiimeDriver.new
          @exitCode = epgQiimeDriver.runQiime(validAttrs,"#{@scratch}/#{@matrixFileName}","#{@scratch}/#{@mappingFileName}",@resultDir,@plotDir,@metrics)
          if(@exitCode != EXIT_OK) then raise "Qiime Driver did not finish successfully" end
        
        compression()
        exitCode = $?.exitstatus
        if(exitCode !=0 ) then
          errMsg = "Compression of files failed"
          @errUserMsg << "#{errMsg}\n"
          @exitCode = exitCode
        else
          uploadData()
          exitCode = $?.exitstatus
          if(exitCode !=0 ) then
            errMsg = "Result upload failed"
            @errUserMsg << "#{errMsg}\n"
            @exitCode = exitCode
          else
            projectPlot()
            exitCode = $?.exitstatus
            if(exitCode != 0 ) then
              errMsg = "The job did not appear to generate any 2D or 3D plots. There may have been a problem with the run."
              @errUserMsg << "#{errMsg}\n"
              @exitCode = exitCode
            else
              @exitCode = EXIT_OK
            end
          end
        end
      end
      rescue => err
        @err = err
        @errUserMsg << "ERROR: Running Epg Qiime failed (#{err.message.inspect}).\n"
        @errInternalMsg << "ERROR: Unexpected error trying to run Epg Qiime."
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
  BRL::Script::main(BRL::Genboree::Tools::Scripts::EpgQiimeWrapper)
end
