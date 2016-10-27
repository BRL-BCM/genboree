#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
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
class ImportRDPFiles

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    begin
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseJsonFile(@jsonFile)
      importRDPFiles()
      addLinks()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end


  # Copies dir structure of the RDP job to the target project
  # [+returns+] nil
  def importRDPFiles()
    # Change dir to 'RDPreport' under the job dir
    Dir.chdir("#{@inputDir}/RDPreport")
    path = @inputDir.split("/")
    @jobDir = path.last
    # Write the index html file
    writeIndexHtmlFile()
    # Now rsync the entite tree to the server
    Dir.chdir(@inputDir)
    #Dir.chdir("../")
    `tar -cf #{@jobDir}.tar *`
    `gzip #{@jobDir}.tar`
    uriObj = URI.parse(@projectUri)
    rsrcPath = "#{uriObj.path}/additionalPages/file/#{@jobDir}/#{@jobDir}.tar.gz?extract=true"
    apiCaller = WrapperApiCaller.new(uriObj.host, rsrcPath, @userId)
    apiCaller.put({}, File.open("#{@jobDir}.tar.gz"))
  end

  # Adds links in the 'news' section of the project page
  # [+returns+] nil
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
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a RDP job (#{@jobName}) and the results are available at the link below.
                            <ul>
                              <li><b>Study Name</b>: #{@studyName}</li>
                              <li><b>Job Name</b>: #{@jobName}</li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/RDPreport/plotsIndex.html\">Link to result plots</a></li>
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a RDP job (#{@jobName}) and the results are available at the link below.
                      <ul>
                        <li><b>Study Name</b>: #{@studyName}</li>
                        <li><b>Job Name</b>: #{@jobName}</li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/RDPreport/plotsIndex.html\">Link to result plots</a></li>
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
    $stderr.puts "Writing out index html page"
    plotsIndexWriter = File.open("./plotsIndex.html", "w")
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
                          <td style=\"background-color:white\"><b>Study Name:</b></td><td style=\"background-color:white\">#{@studyName}</td>
                        </tr>
                        <tr>
                          <td style=\"background-color:white\"><b>Job Name:</b></td><td style=\"background-color:white\">#{@jobName}</td>
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
                          <th colspan=\"1\" style=\"border-bottom:1px solid black; width:300px;background-color:white;\">RDP Plots</th>
                        </tr>

                "
    # Count the number of PNGs in the dir

    pngNo = 0
     Dir.entries('../RDPreport').each { |file|
      if(file =~ /\.PNG/)
          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px solid black;border-left: 1px solid black;background-color:white;\">
                        <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/RDPreport/#{file}\">#{file.gsub(".PNG", "").capitalize}</a>
                      </td>
                    </tr>
                  "
      end
     }

    png = 0
    Dir.entries("../RDPfigure").each { |file|
      png += 1 if(file =~ /\.PNG/)
    }
    Dir.entries('../RDPfigure').each { |file|
      if(file =~ /\.PNG/)
        pngNo += 1
        if(pngNo < png)
          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px solid black;border-left: 1px solid black;background-color:white;\">
                        <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/RDPfigure/#{file}\">#{file.gsub(".tsv.R.PNG", "").capitalize}</a>
                      </td>
                    </tr>
                  "
        else
          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px solid black;border-left:1px solid black;border-bottom:1px solid black;background-color:white\">
                        <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/RDPfigure/#{file}\">#{file.gsub(".tsv.R.PNG", "").capitalize}</a>
                      </td>
                    </tr>
                  "
        end

      end

    }
    plotBuff << "
                            </table>
                          </td>
                        </tr>
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
    @userFirstName = @context['userFirstName']
    @userLastName = @context['userLastName']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @studyName = jsonObj['settings']['studyName']
    @jobName = jsonObj['settings']['jobName']
    @featureList = jsonObj['settings']['featureList']
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    @scratchDir = jsonObj['context']['scratchDir']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)

    # Make sure we have a target project
    outputs = jsonObj['outputs']
    prjApiHelper = BRL::Genboree::REST::Helpers::ProjectApiUriHelper.new()
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
    exit(14)
  end



end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This script is used for copying the RDP files from a specified input directory to a target project.
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

  def self.performImportRDPFiles(optsHash)
    rdpObj = ImportRDPFiles.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportRDPFiles(optsHash)
