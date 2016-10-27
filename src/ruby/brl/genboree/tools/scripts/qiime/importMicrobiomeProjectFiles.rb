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
class ImportMicrobiomeProjectFiles

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    @emptyPlots = false
    initMetricHash()
    begin
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseJsonFile(@jsonFile)
      importMicrobiomeFiles()
      addLinks()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
    exit(21) if(@emptyPlots)
  end

  # Initializes beta metric hash to be used for link labels
  # [+returns+] nil
  def initMetricHash()
    @betaMetrics = {
                      "euclidean" => "Euclidean",
                      "binary_jaccard" => "Binary Jaccard",
                      "hellinger" => "Hellinger",
                      "unweighted_unifrac_full_tree" => "Unweighted Unifrac Full Tree",
                      "soergel" => "Soergel",
                      "binary_pearson" => "Binary Pearson",
                      "morisita_horn" => "Morisita Horn",
                      "gower" => "Gower",
                      "spearman_approx" => "Spearman Approximation",
                      "binary_pearson" => "Binary Pearson",
                      "unifrac_G" => "Unifrac, G",
                      "canberra" => "Canberra",
                      "gower" => "Gower",
                      "chisq" => "Chi-squared",
                      "kulczynski" => "Kulczynski",
                      "morisita_horn" => "Morisita Horn",
                      "pearson" => "Pearson",
                      "chisq" => "Chi-squared",
                      "pearson" => "Pearson",
                      "binary_lennon" => "Binary Lennon",
                      "weighted_unifrac" => "Weighted Unifrac",
                      "unweighted_unifrac" => "Unweighted Unifrac",
                      "unweighted_unifrac" => "Unweighted Unifrac",
                      "bray_curtis" => "Bray Curtis",
                      "canberra" => "Canberra",
                      "unifrac_G_full_tree" => "Unifrac, G, Full Tree",
                      "binary_lennon" => "Binary Lennon",
                      "weighted_unifrac" => "Weighted Unifrac",
                      "unifrac_G_full_tree" => "Unifrac, G, Full Tree",
                      "kulczynski" => "Kulczynski",
                      "bray_curtis" => "Bray Curtis",
                      "specprof" => "Specprof",
                      "binary_euclidean" => "Binary Euclidean",
                      "specprof" => "Specprof",
                      "spearman_approx" => "Spearman Approximation",
                      "binary_chord" => "Binary Chord",
                      "weighted_normalized_unifrac" => "Weighted Nomalized Unifrac",
                      "binary_jaccard" => "Binary Jaccard",
                      "binary_chord" => "Binary Chord",
                      "binary_hamming" => "Binary Hamming",
                      "binary_sorensen_dice" => "Binary Sorensen Dice",
                      "weighted_normalized_unifrac" => "Weighted Normalized Unifrac",
                      "hellinger" => "Hellinger",
                      "chord" => "Chord",
                      "manhattan" => "Manhattan",
                      "binary_hamming" => "Binary Hamming",
                      "binary_euclidean" => "Binary Euclidean",
                      "binary_sorensen_dice" => "Binary Sorensen Dice",
                      "chord" => "Chord",
                      "soergel" => "Soergel",
                      "binary_ochiai" => "Binary Ochiai",
                      "unifrac_G" => "Unifrac, G",
                      "manhattan" => "Manhattan",
                      "binary_ochiai" => "Binary Ochiai",
                      "euclidean" => "Euclidean",
                      "unweighted_unifrac_full_tree" => "Unweighted Unifrac Full Tree"
                    }
    @sortedMetrics = @betaMetrics.keys.sort
  end

  # Copies dir structure of the job to the target project
  # [+returns+] nil
  def importMicrobiomeFiles()
    # Change dir to plots
    Dir.chdir("#{@inputDir}")
    Dir.chdir("./QIIME/#{CGI.escape(@jobName)}/plots")
    # First make sure that there is at least one 3d/2d image. If not write out an error message
    twoD = nil
    threeD = nil
    twoD = `find ./ -type f -name *.png`
    threeD = `find ./ -type f -name *.kin`
    if(twoD.empty? and threeD.empty?) # No Plots present
      writeErrorHtml()
      @emptyPlots = true
    else
      # Make index.html files for both cdhit-normalized and cdhit
      Dir.entries(".").each { |dir|
        if(dir == 'cdhit')
          writeIndexHtmlFile(type='cdhit')
        elsif(dir == 'cdhit-normalized')
          writeIndexHtmlFile(type='cdhit-normalized')
        else
          # Do nothing
        end
      }
    end
    # Now rsync the entite tree to the server
    Dir.chdir(@inputDir)
    Dir.chdir("./QIIME")
    #cmd = "rsync -avz ./#{CGI.escape(@jobName)} #{ApiCaller.getDomainAlias(@host)}:/usr/local/brl/local/apache/htdocs/projects/#{CGI.escape(@projectName)}/genb^^additionalPages/"
    #exitStatus = system(cmd)
    #if(!exitStatus)
    #  raise "rsync failed: #{cmd}"
    #end
    escapedJobName = CGI.escape(@jobName)
    Dir.chdir(escapedJobName)
    `tar -cf #{escapedJobName}.tar *`
    `gzip #{escapedJobName}.tar`
    uriObj = URI.parse(@projectUri)
    rsrcPath = "#{uriObj.path}/additionalPages/file/#{escapedJobName}/#{escapedJobName}.tar.gz?extract=true"
    apiCaller = WrapperApiCaller.new(uriObj.host, rsrcPath, @userId)
    apiCaller.put({}, File.open("#{escapedJobName}.tar.gz"))
  end

  # Called when no plots are present. Writes out job info and an error message in the index html file
  def writeErrorHtml()
    types = ['cdhit', 'cdhit-normalized']
    genbConfig = BRL::Genboree::GenboreeConfig.load()
    $stderr.puts "Writing out error html..."
    types.each { |type|
      cdhitIndexWriter = File.open("./#{type}Index.html", "w")
      cdhitIndexWriter.print(
                              "
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
                                      <tr style=\"background-color:white\">
                                        <td style=\"border-left:2px solid black;border-right:2px solid black;border-bottom:2px solid black;\">
                                          <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;width:700px;\">
                                            <tr>
                                              <td style=\"color:red;\">
                                                ERROR: The job did not appear to generate any 2D or 3D plots. Unfortunately, the underlying QIIME tool
												or the pipeline that drives QIIME died while trying to create your plots, reporting errors to Genboree.
												There may have been a problem with the run.</br></br>
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

      cdhitIndexWriter.close()
    }

  end

  # Adds links in the 'news' section of the project page
  # The links are to the index pages of cdhit and cdhit-normalized
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
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a QIIME job (#{@jobName}) and the results are available at the links below.
                            <ul>
                              <li><b>Study Name</b>: #{@studyName}</li>
                              <li><b>Job Name</b>: #{@jobName}</li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/cdhitIndex.html\">Link to cdhit results</a></li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/cdhit-normalizedIndex.html\">Link to cdhit-normalized results</a></li>
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran a QIIME job (#{@jobName}) and the results are available at the links below.
                      <ul>
                        <li><b>Study Name</b>: #{@studyName}</li>
                        <li><b>Job Name</b>: #{@jobName}</li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/cdhitIndex.html\">Link to cdhit results</a></li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/cdhit-normalizedIndex.html\">Link to cdhit-normalized results</a></li>
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
  def writeIndexHtmlFile(type='cdhit')
    $stderr.puts "Writing out index html pages"
    cdhitIndexWriter = File.open("./#{type}Index.html", "w")
    cdhitBuff = "
                  <html>
                    <body style=\"background-color:#C6DEFF\">
                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: QIIME Results (#{type})</th>
                        </tr>
                "
    cdhitBuff << "
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
    metricsSize = @sortedMetrics.size
    metricNo = 0
    @sortedMetrics.each { |metric|
      metricNo += 1
      if(metricNo < metricsSize )
        cdhitBuff << "
                      <tr>
                        <td style=\"border-left:1px solid black;border-right:1px solid black;padding-left:5px;\">#{@betaMetrics[metric]}"
      else
        cdhitBuff << "
                      <tr>
                        <td style=\"border-left:1px solid black;border-right:1px solid black;border-bottom:1px solid black;padding-left:5px;\">#{@betaMetrics[metric]}"
      end
      if(File.directory?("./#{type}/#{metric}_3d-all"))
        Dir.entries("./#{type}/#{metric}_3d-all").each { |file|
          cdhitBuff << " <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/#{type}/#{metric}_3d-all/#{file}\">(3D)</a>" if(file =~ /\.html/)
        }
      end
      if(File.directory?("./#{type}/#{metric}_2d-all"))
        Dir.entries("./#{type}/#{metric}_2d-all").each { |file|
          cdhitBuff << " <a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@jobName))}/plots/#{type}/#{metric}_2d-all/#{file}\">(2D)</a>" if(file =~ /\.html/)
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
    cdhitIndexWriter.print(cdhitBuff)
    cdhitIndexWriter.close()

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

  Description: This script is used for copying the Microbiome files (html, plots, etc) from a specified input directory to a target project.
  The tool will generate an index in the 'news' section of the project page with links to the individual html pages in the input directory
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

  def self.performImportMicrobiomeProjectFiles(optsHash)
    impfObj = ImportMicrobiomeProjectFiles.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportMicrobiomeProjectFiles(optsHash)
