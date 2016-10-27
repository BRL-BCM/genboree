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
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST


# Main Class
class ImportAlphaDivFiles

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    initPlotTypes()
    @plotTypeHash = {}
    @featureTypeHash = {}
    begin
      parseJsonFile(@jsonFile)
      importAlphaDivFiles()
      addLinks()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Initializes plot types (fixed list)
  # [+returns+] nil
  def initPlotTypes()
    @plotTypes = ["rankAbundancePlots", "renyiProfilePlots", "richnessPlots"]
    @subplotHash = {

                      "Accumfreq" => "Accumulative Frequency",
                      "Logabun" => "Log Abundance"
                    }
  end

  # Copies dir structure of the job to the target project
  # [+returns+] nil
  def importAlphaDivFiles()
    # Change dir to 'alphadiversity' under the job dir
    Dir.chdir("#{@inputDir}/alphadiversity")
    # Loop over each plot type and create the @plotTypeHash
    @plotTypes.each { |plotType|
      if(File.directory?("./#{plotType}"))
        @plotTypeHash[plotType] = {}
        Dir.entries("./#{plotType}").each { |png|
          next if(png == "." or png == "..")
          subplot = nil
          feature = nil
          file = nil
          @featureList.each { |column|
            if(png.index(column) == 0)
              subplot = png.split('-')[1].chomp('.PNG')
              feature = column
              file = png
              break
            elsif(png.index(column.gsub(/(?:[\\\/\?:\*"<>\|\s])+/, '_')) == 0) # replace some of the chars with an '_' and then try to find if the file exists
              subplot = png.split('-')[1].chomp('.PNG')
              feature = column
              file = png
              break
            else # Not found
              # Do nothing
            end
          }
          if(!@plotTypeHash[plotType].has_key?(subplot))
            @plotTypeHash[plotType][subplot] = {}
            @plotTypeHash[plotType][subplot][feature] = file
          else
            @plotTypeHash[plotType][subplot][feature] = file
          end
        }
      end
    }
    # Now make the @featureTypeHash
    @featureList.each { |feature|
      @featureTypeHash[feature] = {}
      @plotTypes.each { |plotType|
        if(File.directory?("./#{plotType}"))
          @featureTypeHash[feature][plotType] = {}
          Dir.entries("./#{plotType}").each { |png|
            next if(png == "." or png == "..")
            subplot = nil
            file = nil
            @featureList.each { |column|
              if(png.index(column) == 0)
                subplot = png.split('-')[1].chomp('.PNG')
                file = png
                break
              elsif(png.index(column.gsub(/(?:[\\\/\?:\*"<>\|\s])+/, '_')) == 0)
                subplot = png.split('-')[1].chomp('.PNG')
                file = png
                break
              else
                # Do nothing
              end
            }
            @featureTypeHash[feature][plotType][subplot] = file if(!@featureTypeHash[feature][plotType].has_key?(subplot))
          }
        end
      }
    }
    raise "ERROR: .PNG files could not be found." if(@plotTypeHash.empty? and @featureTypeHash.empty?)
    path = @inputDir.split("/")
    @jobDir = path.last
    # Write the index html file
    writeIndexHtmlFile()
    # Now rsync the entire tree to the server
    Dir.chdir(@inputDir)
    #Dir.chdir("../")
    `tar -cf #{@jobDir}.tar *`
    `gzip #{@jobDir}.tar`
    #cmd = "rsync -avz ./#{@jobDir} #{@host}:/usr/local/brl/local/apache/htdocs/projects/#{CGI.escape(@projectName)}/genb^^additionalPages/"
    #exitStatus = system(cmd)
    #if(!exitStatus)
    #  raise "rsync failed: #{cmd}"
    #end
    uriObj = URI.parse(@projectUri)
    rsrcPath = "#{uriObj.path}/additionalPages/file/#{@jobDir}/#{@jobDir}.tar.gz?extract=true"
    apiCaller = WrapperApiCaller.new(@host, rsrcPath, @userId)
    apiCaller.put({}, File.open("#{@jobDir}.tar.gz"))
  end

  # Adds links in the 'news' section of the project page
  # [+returns+] nil
  def addLinks()
    # First get the existing news items
    $stderr.puts "Adding links to project page"
    apiHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
    uri = URI.parse(@projectUri)
    @host = uri.host
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri = "#{rcscUri}/news?"
    rcscUri << "gbKey=#{apiHelper.extractGbKey(@projectUri)}" if(apiHelper.extractGbKey(@projectUri))
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
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a Alpha Diversity job (#{@jobName}) and the results are available at the link below.
                            <ul>
                              <li><b>Study Name</b>: #{@studyName}</li>
                              <li><b>Job Name</b>: #{@jobName}</li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/alphadiversity/plotsIndex.html\">Link to result plots</a></li>
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a AlphaDiversity job (#{@jobName}) and the results are available at the link below.
                      <ul>
                        <li><b>Study Name</b>: #{@studyName}</li>
                        <li><b>Job Name</b>: #{@jobName}</li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/alphadiversity/plotsIndex.html\">Link to result plots</a></li>
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
  # [+returns+] nil
  def writeIndexHtmlFile()
    $stderr.puts "Writing out index html page"
    plotsIndexWriter = File.open("./plotsIndex.html", "w")
    plotBuff = "<html>
                    <body style=\"background-color:#C6DEFF\">
                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: Alpha Diversity Results</th>
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
                          <th colspan=\"2\" style=\"border-bottom:1px solid black; width:300px;background-color:white;\">Alpha Diversity Plots</th>
                        </tr>
                        <tr>
                          <th style=\"width=50%;border-bottom:1px solid black;\">By Plot Type</th>
                          <th style=\"width=49%;border-bottom:1px solid black;\">By Feature Type</th>
                        </tr>
                        <tr>
                          <td style=\"vertical-align:top;border-right:1px solid black\">
                "


    # <td> for classification by plot types
    plotBuff << "<ul>" if(@plotTypeHash.keys.size > 0) # begin <ul> For plotTypes
    @plotTypeHash.each_key { |plotType|
      plotBuff << "
                    <li>
                      Plot: #{plotType.gsub("Plots", "").capitalize}

                  "
      plotBuff << "<ul>" if(@plotTypeHash[plotType].keys.size > 0) # begin <ul> For subplots
      @plotTypeHash[plotType].each_key { |subplot|
        plotBuff << "
                      <li>
                        Subplot: #{subplot.capitalize}
                    "
        plotBuff << "<ul>" if(@plotTypeHash[plotType][subplot].keys.size > 0) # begin <ul> For features
        @plotTypeHash[plotType][subplot].each_key { |feature|
          plotBuff << "
                        <li style=\"padding-right:7px;\">
                          Feature: <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/alphadiversity/#{plotType}/#{@plotTypeHash[plotType][subplot][feature]}\">#{feature}</a>
                        </li>
                      "
        }
        plotBuff << "</ul>" if(@plotTypeHash[plotType][subplot].keys.size > 0) # end </ul> For features
        plotBuff << "</li>" # end </li> for subplot
      }
      plotBuff << "</ul>" if(@plotTypeHash[plotType].keys.size > 0) # end </ul> For subplots
      plotBuff << "</li>" # end </li> for plotType
    }
    plotBuff << "</ul>" if(@plotTypeHash.keys.size > 0) # end </ul> For plotTypes

    # End </td> for classification by plotTypes
    plotBuff << "</td>"

    # Start <td> for classification by feature type
    plotBuff << "<td style=\"vertical-align:top\">"
    plotBuff << "<ul>" if(@featureTypeHash.keys.size > 0) # begin <ul> For features
    @featureTypeHash.each_key { |feature|
      plotBuff << "
                    <li>
                      Feature: #{feature}

                  "
      plotBuff << "<ul>" if(@featureTypeHash[feature].keys.size > 0) # begin <ul> For plotType
      @featureTypeHash[feature].each_key { |plotType|
        plotBuff << "
                      <li>
                        Plot: #{plotType.gsub("Plots", "").capitalize}
                    "
        plotBuff << "<ul>" if(@featureTypeHash[feature][plotType].keys.size > 0) # begin <ul> For subplots
        @featureTypeHash[feature][plotType].each_key { |subplot|
          plotBuff << "
                        <li style=\"padding-right:7px;\">
                          Subplot: <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(@jobDir)}/alphadiversity/#{plotType}/#{@featureTypeHash[feature][plotType][subplot]}\">#{subplot}</a>
                        </li>
                      "
        }
        plotBuff << "</ul>" if(@featureTypeHash[feature][plotType].keys.size > 0) # end </ul> For subplot
        plotBuff << "</li>" # end </li> for plotType
      }
      plotBuff << "</ul>" if(@featureTypeHash[feature].keys.size > 0) # end </ul> For plotType
      plotBuff << "</li>" # end </li> for features
    }
    plotBuff << "</ul>" if(@featureTypeHash.keys.size > 0) # end </ul> For feature

    # End </td> for classification by featureTypes
    plotBuff << "</td>"

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
        uri = URI.parse(ApiCaller.applyDomainAliases(@projectUri))
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

  Description: This script is used for copying the alpha diversity files from a specified input directory to a target project.
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

  def self.performImportAlphaDivFiles(optsHash)
    adObj = ImportAlphaDivFiles.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportAlphaDivFiles(optsHash)
