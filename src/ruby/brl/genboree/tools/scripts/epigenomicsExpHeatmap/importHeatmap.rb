#!/usr/bin/env ruby

# Load libraries
require 'cgi'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'
require 'uri'
require 'brl/genboree/rest/wrapperApiCaller'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


# Main Class
class ImportHeatMap

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    begin
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseJsonFile(@jsonFile)
      path = @inputDir.split("/")
      @jobDir = path.last
      addLinks()
      importFiles()
      #addLinks()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  def importFiles()
    Dir.chdir("#{@inputDir}")
    path = @inputDir.split("/")
    @jobDir = path.last
    writeIndexHtmlFile()
    #cmd = "rsync -avz ./#{@jobDir} #{ApiCaller.getDomainAlias(@host)}:/usr/local/brl/local/apache/htdocs/projects/#{CGI.escape(@projectName)}/genb^^additionalPages/"
    uriObj = URI.parse(@projectUri)
    {
      "plotsIndex.html"                     => "plotsIndex.html",
      "matrix.txt.fixed.heatmap.svg.html"   => "heatmap.svg.html",
      "matrix.txt.fixed.corrplot.svg.html"  => "corrplot.svg.html",
      "matrix.txt.fixed.heatmap.png"        => "heatmap.png",
      "matrix.txt.fixed.corrplot.png"       => "corrplot.png"
    }.each_pair { |srcFile, tgtFile|
      tgtPath = "#{uriObj.path}/additionalPages/file/#{@jobDir}/#{tgtFile}"
      apiCaller = WrapperApiCaller.new(@host, tgtPath, @userId)
      apiCaller.put({}, File.open(srcFile))
      $stderr.debugPuts(__FILE__, __method__, "PROJECT FILE UPLOAD", "src file: #{srcFile.inspect}\n  - exists? #{File.exist?(srcFile)}\n  - size #{File.size(srcFile)}\n  - Tgt path: #{tgtPath.inspect}\n  - Success? #{apiCaller.succeeded?}")
    }
    # Graphlan variants as well:
    exts = ["png", "svg.html"]
    rowFiles = ["rowseq","rowsScaled","rowslogn","rowslog10"]
    colFiles = ["columnseq","columnsScaled","columnslogn","columnslog10"]
    pathPrefix = "#{uriObj.path}/additionalPages/file/#{@jobDir}"
    apiCaller = WrapperApiCaller.new(@host, "",@userId)
    exts.each { |ee|
      rowFiles.each { |rr|
        srcFile = "#{rr}.#{ee}"
        tgtPath = "#{pathPrefix}/#{rr}.#{ee}"
        apiCaller.setRsrcPath(tgtPath)
        apiCaller.put({}, File.open(srcFile))
        $stderr.debugPuts(__FILE__, __method__, "PROJECT FILE UPLOAD", "src file: #{srcFile.inspect}\n  exists? #{File.exist?(srcFile)}\n  - size #{File.size(srcFile)}\n  - Tgt path: #{tgtPath.inspect}\n  - Success? #{apiCaller.succeeded?}")
      }
      colFiles.each { |cc|
        srcFile = "#{cc}.#{ee}"
        tgtPath = "#{pathPrefix}/#{cc}.#{ee}"
        apiCaller.setRsrcPath(tgtPath)
        apiCaller.put({}, File.open(srcFile))
        $stderr.debugPuts(__FILE__, __method__, "PROJECT FILE UPLOAD", "src file: #{srcFile.inspect}\n  exists? #{File.exist?(srcFile)}\n  - size #{File.size(srcFile)}\n  - Tgt path: #{tgtPath.inspect}\n  - Success? #{apiCaller.succeeded?}")
      }
    }
  end

  # Adds links in the 'news' section of the project page
  # [+returns+] nil
  def addLinks()
    # First get the existing news items
    $stderr.debugPuts(__FILE__, __method__, "Importing Heatmap", "Adding links to project page")
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
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Epigenomic Heatmap Tool (#{@studyName}) and the results are available at the link below.
                            <ul>
                              <li><b>Study Name</b>: #{@studyName}</li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/plotsIndex.html\">Link to results</a></li>
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Epigenomic Heatmap Tool (#{@studyName}) and the results are available at the link below.
                      <ul>
                        <li><b>Study Name</b>: #{@studyName}</li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/plotsIndex.html\">Link to results </a></li>
                      </ul>"
                    }

                ]
      payload = {"data" => newItems}
    end
    apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
    apiCaller.put(payload.to_json)
    raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
  end


  # Creates index html file
  # [+returns+] nil
  def writeIndexHtmlFile()

     $stderr.debugPuts(__FILE__, __method__, "Importing Heatmap", "Writing out index html page")
    plotsIndexWriter = File.open("./plotsIndex.html", "w+")
    plotBuff = "<html>
                  <head>
                    <script type=\"text/javascript\" src=\"/javaScripts/workbench/d3/d3.brl.js\"> </script>
                    <script type=\"text/javascript\" src=\"/javaScripts/workbench/d3/helpers.js\"> </script>
                  </head>
                  <body style=\"background-color:#C6DEFF\">

                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: Epigenomic HeatMap</th>
                        </tr>
                "
    plotBuff << "
                  <tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;\">
                      <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;\">
                        <tr>
                          <td style=\"background-color:white\"><b>Study Name:</b></td><td style=\"background-color:white\">#{@studyName}</td>
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

    plotBuff << "
                  <tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                      <table  border=\"0\" cellspacing=\"0\" style=\"padding:15px 35px;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:1px solid black; width:800px;background-color:white;\">Epigenomic HeatMap Plots</th>
                        </tr>
                "
          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white;\">
                      <ul style=\"list-style:none;\">
                      <li>Heatmap&nbsp;
                      <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/heatmap.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/heatmap.svg.html\">SVG</a>]
              </sup>
                      </li>
                      <li>Correlation Plot&nbsp;
                        <sup>
                          [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/corrplot.png\">PNG</a>]&nbsp;
                          [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/corrplot.svg.html\">SVG</a>]
                        </sup>
                      </li>
                      </ul>
                      </td></tr>"
          plotBuff << "</table></td></tr>"

    plotBuff << "<tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                      <table  border=\"0\" cellspacing=\"0\" style=\"padding:15px 35px;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:1px solid black; width:800px;background-color:white;\">Newick Tree Visualizations</th>
                        </tr>"
          plotBuff << "<tr><td style=\"vertical-align:top;border-right:1px ;background-color:white;\">
          <ul style=\"list-style:none;font-weight:bold;\">"
          plotBuff << "<li>Equal Branch Lengths<br><ul style=\"list-style:none;font-weight:normal;\">
              <li>Rows&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowseq.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowseq.svg.html\">SVG</a>]
              </sup>
              </li>

              <li>Columns&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnseq.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnseq.svg.html\">SVG</a>]
              </sup>
              </li>
              </ul>
          </li>"
        plotBuff << "<li>Scaled Branch Lengths<br><ul style=\"list-style:none;font-weight:normal;\">
              <li>Rows&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowsScaled.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowsScaled.svg.html\">SVG</a>]
              </li>
              <li>Columns&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnsScaled.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnsScaled.svg.html\">SVG</a>]
              </sup>
              </li>
              </ul>
          </li>"
          plotBuff << "<li>Natural Log Scaled Branch Lengths<br><ul style=\"list-style:none;font-weight:normal;\">
              <li>Rows&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowslogn.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowslogn.svg.html\">SVG</a>]
              </li>
              <li>Columns&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnslogn.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnslogn.svg.html\">SVG</a>]
              </sup>
              </li>
              </ul>
          </li>"
          plotBuff << "<li>Log10 Scaled Branch Lengths<br><ul style=\"list-style:none;font-weight:normal;\">
              <li>Rows&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowslog10.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/rowslog10.svg.html\">SVG</a>]
              </li>
              <li>Columns&nbsp;
              <sup>
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnslog10.png\">PNG</a>]&nbsp;
              [<a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/columnslog10.svg.html\">SVG</a>]
              </sup>
              </li>
              </ul>
          </li>"
plotBuff << " </ul></td></tr>"
    plotBuff << "</table></td></tr>
                      </table>
                    </body>
                  </html>
                "
    plotsIndexWriter.print(plotBuff)
    plotBuff = ""
    plotsIndexWriter.close()

  end




  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseJsonFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @inputs = jsonObj['inputs']
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @scratch = jsonObj["context"]["scratchDir"]
    @userFirstName = @context['userFirstName']
    @userLastName = @context['userLastName']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @studyName = jsonObj['settings']['analysisName']
    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @studyName = CGI.escape(@studyName)
    @studyName = @studyName.gsub(/%[0-9a-f]{2,2}/i, "_")
    @studyName.gsub!(/\_/,' ')
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = ApiCaller.getDomainAlias(dbrc.driver.split(/:/).last)
    @scratchDir = jsonObj['context']['scratchDir']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)

    # Make sure we have a target project
    outputs = jsonObj['outputs']
    @grph  = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper 	= BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)

    @db  = @dbhelper.extractName(@inputs[0])
    @grp = @grph.extractName(@inputs[0])

    prjApiHelper = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new("/cluster.shared/local/conf/genboree/genboree.config.properties")
    @projectName = nil
    @projectUri = nil
    outputs.each { |output|
      if(output =~ BRL::Genboree::REST::Helpers::ProjectApiUriHelper::NAME_EXTRACTOR_REGEXP)
        @projectName = prjApiHelper.extractName(output)
        @projectUri = output
        # Replace host with this one:
        # Replace host with this one:
        aliasUri = ApiCaller.applyDomainAliases(@projectUri)
        uri = URI.parse(aliasUri)
        @host = uri.host
        break
      end
    }
    raise "No target Project found" if(@projectName.nil?)
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    exit(113)
  end



end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Arpit Tandon

  Description: This script is used for copying the png file from a specified input directory to a target project.
  The tool will generate an index in the 'news' section of the project page with links to the individual pdfs in the input directory
    -i  --inputDir                      => full path to input directory (needs to be CGI escaped)
    -j  --jsonFile                      => full path to json file (needs to be CGI escaped)
    -v  --version                       => Version of the program
    -h  --help                          => Display help

  "
  def self.printUsage(additionalInfo=nil)
    puts DEFAULTUSAGEINFO
    puts additionalInfo unless(additionalInfo.nil?)
    if(additionalInfo.nil?)
      exit(0)
    else
      exit(15)
    end
  end

  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end

  def self.parseArgs()
    optsArray=[
      ['--inputDir','-i',GetoptLong::REQUIRED_ARGUMENT],
      ['--jsonFile','-j',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def self.performImportHeatMap(optsHash)
    rdpObj = ImportHeatMap.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportHeatMap(optsHash)
