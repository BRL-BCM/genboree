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

## TODO CC the top-level class usage in this script is idiotic.
## Reorganize at high level while using the scriptDriver.rb

# Main Class
class ImportGenes

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    @useDavid = false
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
    # Change dir to 'RDPreport' under the job dir
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "going to import project files...")
    Dir.chdir("#{@inputDir}")
    path = @inputDir.split("/")
    @jobDir = path.last
    formatTheFile()
    makeLink()
    writeIndexHtmlFile()
    # Write the index html file
    # Now rsync the entite tree to the server
    Dir.chdir(@inputDir)
    Dir.chdir("../")
    system("mkdir -p #{CGI.escape(@studyName)}")
    system("cp -r ./#{@jobDir} #{CGI.escape(@studyName)}")
    #escapedStudyName = CGI.escape(@studyName)
    #Dir.chdir(escapedStudyName)
    #`tar -cf #{escapedStudyName}.tar *; gzip #{escapedStudyName}.tar`
    #uriObj = URI.parse(@projectUri)
    #apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/additionalPages/file/#{escapedStudyName}/#{escapedStudyName}.tar.gz?extract=true", @userId)
    #apiCaller.put({}, File.open("#{escapedStudyName}.tar.gz"))
    cmd = "rsync -avz #{CGI.escape(@studyName)} #{WrapperApiCaller.getDomainAlias(@host)}:/usr/local/brl/local/apache/htdocs/projects/#{CGI.escape(@projectName)}/genb^^additionalPages/"
    exitStatus = system(cmd)
    if(!exitStatus)
      raise "rsync failed: #{cmd}"
    end
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
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Epigenomic Signals Experiment Sets Comparison Tool (#{CGI.unescape(@studyName)}) and the results are available at the link below.
                            <ul>
                              <li><b>Study Name</b>: #{CGI.unescape(@studyName)}</li>
                              <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/matrix/plotsIndex.html\">Link to results</a></li>
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Epigenomic Signals Experiment Sets Comparison Tool (#{CGI.unescape(@studyName)}) and the results are available at the link below.
                      <ul>
                        <li><b>Study Name</b>: #{CGI.unescape(@studyName)}</li>
                        <li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/matrix/plotsIndex.html\">Link to results </a></li>
                      </ul>"
                    }

                ]
      payload = {"data" => newItems}
    end
    apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
    apiCaller.put(payload.to_json)
    raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
  end

  ##format the file. Rank first followed be gene name
  def formatTheFile
    system("cp #{@inputDir}/sorted_geneList #{@scratch}/sorted_geneList")
    file = File.open("#{@scratch}/sorted_geneList")
    fileW = File.open("#{@scratch}/sorted_geneList.temp", "w+")
    file.each {|gene|
      gene.chomp!
      c = gene.split(/\t/)
      fileW.puts "#{c[1]}\t#{c[0]}"
      }
    fileW.close
    file.close
    system("sort -k1n #{@scratch}/sorted_geneList.temp > #{@scratch}/sorted_geneList.xls")
  end

  def updateXYHash (newXAttr, newYAttr, xyAttrValsPairHash, xyAttrValsPairStruct)
    xyKey = "#{newXAttr}\t#{newYAttr}"
    if(!xyAttrValsPairHash.key?(xyKey)) then
      xyAttrValsPairHash[xyKey] = xyAttrValsPairStruct.new(newXAttr, newYAttr)
    end
  end

  def getBrowserXYAttributes(xyAttrValsPairHash)
    xattrValsArray = []
    yattrValsArray = []
    xyAttrValsPairHash.keys.each {|xyKey|
      keyParts = xyKey.split(/\t/)
      xattrValsArray.push(keyParts[0])
      yattrValsArray.push(keyParts[1])
    }
    xattrVals = xattrValsArray.join(",")
    yattrVals = yattrValsArray.join(",")
    return [xattrVals, yattrVals]
  end

   ##building page to see gene list in gene browser
  def makeLink()
    xyAttrValsPairStruct = Struct.new(:x, :y)
    xyAttrValsPairHash = {}
    xattrVals = ""
    yattrVals = ""

    @escapedDatabasesList = Set.new()

    ##New parameter settings for creating atlas link. Reading track info from SET A
    file1 = File.open("#{@scratch}/tmpFile1.txt")
    file1.each{|line|
      line.strip!
      path = URI.parse(line).path
      host = URI.parse(line).host
      puts path
      tmpPath = "#{path}?detailed=minDetails"
      tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
      api = WrapperApiCaller.new(host,tmpPath,@userId)
      api.get
      respHash = api.parseRespBody
      puts respHash
      xattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaAssayType"])},"
      yattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaSampleType"])},"

      newXAttr = CGI.escape(respHash["data"]["attributes"]["eaAssayType"])
      newYAttr = CGI.escape(respHash["data"]["attributes"]["eaSampleType"])
      unless(newXAttr.nil? or newYAttr.nil? or newXAttr !~ /\S/ or newYAttr !~ /\S/)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "have normal ; newYAttr = #{newYAttr.inspect}")
        updateXYHash(newXAttr, newYAttr, xyAttrValsPairHash, xyAttrValsPairStruct)

        line =~  /^(.+\/db\/[^\/\?]+)/
        currentDb = $1
        if(@dbApiHelper.extractGbKey(line))
          currentDb <<"?gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
        end
        @escapedDatabasesList.add(CGI.escape(currentDb))
      end
    }
    file1.close

    ##New parameter settings for creating atlas link. Reading track info from SET B
    file2 = File.open("#{@scratch}/tmpFile2.txt")
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "file2 = #{file2.inspect}")
    file2.each{|line|
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "line = #{line.inspect}")
      line.strip!
      path = URI.parse(line).path
      host = URI.parse(line).host
      puts path
      tmpPath = "#{path}?detailed=minDetails"
      tmpPath << "&gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
      api = WrapperApiCaller.new(host,tmpPath,@userId)
      api.get
      respHash = api.parseRespBody
      puts respHash
      xattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaAssayType"])},"
      yattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaSampleType"])},"

      newXAttr = CGI.escape(respHash["data"]["attributes"]["eaAssayType"])
      newYAttr = CGI.escape(respHash["data"]["attributes"]["eaSampleType"])
      $stderr.debugPuts(__FILE__, __method__, "DBEUG", "line:\n#{line.inspect}\nrespHash\n\n#{respHash.inspect}\n\n")
      unless(newXAttr.nil? or newYAttr.nil? or newXAttr !~ /\S/ or newYAttr !~ /\S/)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "have tumor ; newYAttr = #{newYAttr.inspect}")
        updateXYHash(newXAttr, newYAttr, xyAttrValsPairHash, xyAttrValsPairStruct)
        line =~  /^(.+\/db\/[^\/\?]+)/
        currentDb = $1
        if(@dbApiHelper.extractGbKey(line))
          currentDb <<"?gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
        end
        @escapedDatabasesList.add(CGI.escape(currentDb))
      end
    }
    file2.close

    xattrVals.chomp!(",")
    yattrVals.chomp!(",")

    ##Building gene list for ATLAS
    #picking only top 10 genes
    counter = 0
    geneString10 = ""
    geneString5 = ""

    list = %x{cut -f2 sorted_geneList.xls}
    geneArray = list.split(/\n/)
    geneArray.uniq!
    geneArray.each {|gene|
      if(counter <10 )
        if(counter < 5)
          geneString5 << "#{CGI.escape(gene)},"
        end
        geneString10 << "#{CGI.escape(gene)},"
      end
      counter += 1
      }
    geneString5.chomp!(',')
    geneString10.chomp!(',')


# CC --> fix grid view

    #@httplLink5 = "http://#{@host}/epigenomeatlas/geneViewer.rhtml?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}"
    #@httplLink5 << "&gbGridYAttr=eaSampleType&gbGridXAttr=eaAssayType&grpName=#{CGI.escape(@grp)}"
    #@httplLink5 << "&dbName=#{CGI.escape(@db)}&geneNames=#{geneString5}"
    #
    #
    #@httplLink10 = "http://#{@host}/epigenomeatlas/geneViewer.rhtml?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}"
    #@httplLink10 << "&gbGridYAttr=eaSampleType&gbGridXAttr=eaAssayType&grpName=#{CGI.escape(@grp)}"
    #@httplLink10 << "&dbName=#{CGI.escape(@db)}&geneNames=#{geneString10}"

    xyattrValsPair = getBrowserXYAttributes(xyAttrValsPairHash)
    xattrVals = xyattrValsPair[0]
    yattrVals = xyattrValsPair[1]


    @httplLink5 =  "http://#{@host}/java-bin/multiGeneViewer.jsp?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}&gbGridYAttr=eaSampleType"
    @httplLink5 << "&gbGridXAttr=eaAssayType&dbList=#{@escapedDatabasesList.to_a.join(",")}&geneNames=#{geneString5}"


    @httplLink10 =  "http://#{@host}/java-bin/multiGeneViewer.jsp?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}&gbGridYAttr=eaSampleType"
    @httplLink10 << "&gbGridXAttr=eaAssayType&dbList=#{@escapedDatabasesList.to_a.join(",")}&geneNames=#{geneString10}"

    @httplLinkFile= "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/matrix/sorted_geneList.xls"

    @httpGeneCluster = nil
    @httpTermCluster = nil
    @httpFunctionalChart = nil
    @httpFunctionalAnnotationTable = nil

    if (@useDavid) then
      if (File.exists?("#{@inputDir}/DAVID/chartReport.xls")) then
        @httpFunctionalChart = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/DAVID/chartReport.xls"
      end

      if (File.exists?("#{@inputDir}/DAVID/tableReport.xls")) then
        @httpFunctionalAnnotationTable = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/DAVID/tableReport.xls"
      end

      if (File.exists?("#{@inputDir}/DAVID/geneClusterReport.xls")) then
        @httpGeneCluster = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/DAVID/geneClusterReport.xls"
      end

      if (File.exists?("#{@inputDir}/DAVID/termClusterReport.xls")) then
        @httpTermCluster = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{CGI.escape(CGI.escape(@studyName))}/DAVID/termClusterReport.xls"
      end
    end
    # CC - add the results of gene ontology
  end

  # Creates index html file
  # [+returns+] nil
  def writeIndexHtmlFile()
    $stderr.debugPuts(__FILE__, __method__, "Importing Heatmap", "Writing out index html page")
    plotsIndexWriter = File.open("./plotsIndex.html", "w+")
    plotBuff = "<html>
                  <body style=\"background-color:#C6DEFF\">
                      <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                        <tr>
                          <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: Epigenomic Comparison</th>
                        </tr>
                "
    plotBuff << "
                  <tr style=\"background-color:white;\">
                    <td style=\"border-left:2px solid black;border-right:2px solid black;\">
                      <table cellspacing=\"0\" border=\"0\" style=\"padding-left:35px;padding-top:15px;padding-bottom:10px;\">
                        <tr>
                          <td style=\"background-color:white\"><b>Study Name:</b></td><td style=\"background-color:white\">#{CGI.unescape(@studyName)}</td>
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
                          <th colspan=\"1\" style=\"border-bottom:1px solid black; width:800px;background-color:white;\">Epigenomic Changes Plots</th>
                        </tr>

                "

          plotBuff <<
                  "
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white;\">
                         <a href=\'#{@httplLink5}'\">Gene browser view of the top 5 genes overlapping with discriminating regions of interest</a>
                      </td>
                    </tr>
                    <tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                         <a href=\'#{@httplLink10}'\">Gene browser view of the top 10 genes overlapping with discriminating regions of interest</a>
                      </td>
                    </tr>
                    <tr>
                    <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                         <a href=\'#{@httplLinkFile}'\">Ranked list of genes overlapping with discriminating regions of interest</a>
                      </td>
                    </tr>
       "
    if (@useDavid) then
      if (@httpGeneCluster != nil) then
        plotBuff << "<tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@httpGeneCluster}'\">Gene clustering for genes overlapping with discriminating regions of interest</a>
                        </td>
                      </tr>"
      end

      if (@httpTermCluster!= nil) then
        plotBuff << "<tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@httpTermCluster}'\">Functional annotation clustering for genes overlapping with discriminating regions of interest</a>
                        </td>
                      </tr>"
      end

      if (@httpFunctionalChart!= nil) then
        plotBuff << "<tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@httpFunctionalChart}'\">Functional annotation chart for genes overlapping with discriminating regions of interest</a>
                        </td>
                      </tr>"
      end

      if (@httpFunctionalAnnotationTable!= nil) then
        plotBuff << "<tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@httpFunctionalAnnotationTable}'\">Functional annotation table for genes overlapping with discriminating regions of interest</a>
                        </td>
                      </tr>"
      end
    end
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
    @scratch = jsonObj["context"]["scratchDir"]
    @userFirstName = @context['userFirstName']
    @userLastName = @context['userLastName']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @studyName = jsonObj['settings']['analysisName']
    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @studyName = CGI.escape(@studyName)
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


    ##Finding the db and grp name for the tracks INSIDE the track entity list
    ## to create the atlas link. Only 1st trackSet is enough to find the db and grp of tracks
    uri       = URI.parse(@inputs[0])
    @path1    = uri.path.chomp('?')
    tmpPath = "#{@path1}/data?"
    tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@inputs[0])}" if(@dbApiHelper.extractGbKey(@inputs[0]))
    apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
    apicaller.get()
      if apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "ATLAS LINK TOOL", "1st trackSet downloaded successfully")
      else
        $stderr.debugPuts(__FILE__, __method__, "ATLAS LINK TOOL- ERROR", apicaller.parseRespBody().inspect)
        exitCode = apicaller.apiStatusObj['statusCode']
      end
      apicaller.parseRespBody
      trackURI = ""
      apicaller.apiDataObj.each { |obj|
        trackURI = obj['url']
        break
      }

    @db  = @dbhelper.extractName(trackURI)
    @grp = @grph.extractName(trackURI)

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
    exit(14)
  end



end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Arpit Tandon

  Description: This script is used for making ATLAS links to a target project.
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

  def self.performImportGenes(optsHash)
    rdpObj = ImportGenes.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performImportGenes(optsHash)
