#!/usr/bin/env ruby

# Load libraries
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/rest/helpers/projectApiUriHelper'
require 'uri'
require 'brl/genboree/rest/wrapperApiCaller'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
include BRL::Genboree::REST


# Main Class
class ImportGenes

  DEBUG_CC = true

  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @inputDir = optsHash['--inputDir']
    @jsonFile = optsHash['--jsonFile']
    @jobId = nil
    @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()

    begin
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
   # system("mkdir -p #{CGI.escape(@studyName)}")
    currDir = Dir.pwd
    Dir.chdir(@scratch)
    #Dir.chdir("../")
    #system("cp -r ./#{@jobDir} #{CGI.escape(@studyName)}")
    fileBaseName = File.basename(@inputDir)
    `tar -cf #{fileBaseName}.tar *; gzip #{fileBaseName}.tar`
    #cmd = "rsync -avz #{File.basename(@inputDir)} #{ApiCaller.getDomainAlias(@host)}:/usr/local/brl/local/apache/htdocs/projects/#{CGI.escape(@projectName)}/genb^^additionalPages/"
    #$stderr.debugPuts(__FILE__, __method__, "SampleCentricLimma rsync", cmd)
    #puts cmd
    #exitStatus = system(cmd)
    #$stderr.debugPuts(__FILE__, __method__, "SampleCentricLimma rsync result", exitStatus)
    #if(!exitStatus)
    #  raise "rsync failed: #{cmd}"
    #end
    uriObj = URI.parse(@projectUri)
    apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/additionalPages/file/#{fileBaseName}/#{fileBaseName}.tar.gz?extract=true", @userId)
    apiCaller.put({}, File.open("#{fileBaseName}.tar.gz"))
    Dir.chdir(currDir)
  end


  # Adds links in the 'news' section of the project page
  # [+returns+] nil
  def addLinks()
    # First get the existing news items
    $stderr.debugPuts(__FILE__, __method__, "Importing Sample Centric Limma Analysis", "Adding links to project page")
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
    bufferlink = ""
    @attributes.each{ |arr|
      geneListFilePath = "#{@scratch}/#{arr}/sorted_geneList"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Attribute #{arr.inspect}: Looking for #{geneListFilePath.inspect}...")
      if(File.exists?(geneListFilePath))
        bufferlink << "<li><a href=\"/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/#{arr}/plotsIndex.html\">Link to #{arr} results</a></li>\n"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "...found file. Adding link to bufferlink variable.")
      end
    }

    if(!existingItems.empty?)
      existingItems.push(
                          {
                            'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                            "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Sample Centric Limma Analysis Tool (#{CGI.unescape(@studyName)}) and the results are available at the link below.
                            <ul>
                              <li><b>Study Name</b>: #{CGI.unescape(@studyName)}</li>
                              #{bufferlink}
                            </ul>"
                          }
                        )
      payload = {"data" => existingItems}
    else
      newItems = [
                    {
                      'date' =>  Time.now.localtime.strftime("%m/%d/%Y"),
                      "updateText" => "#{@userFirstName.capitalize} #{@userLastName.capitalize} ran Sample Centric Limma Analysis Tool (#{CGI.unescape(@studyName)}) and the results are available at the link below.
                      <ul>
                        <li><b>Study Name</b>: #{CGI.unescape(@studyName)}</li>
                        #{bufferlink}
                      </ul>"
                    }

                ]
      payload = {"data" => newItems}
    end
    $stderr.puts "DEBUG: payload for proj news:\n\n#{payload.inspect}\n\n"
    apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
    apiCaller.put(payload.to_json)
    raise "ApiCaller 'put' news failed:\n #{apiCaller.respBody}" if(!apiCaller.succeeded?)
  end

  ##format the file. Rank first followed be gene name
  def formatTheFile
    @attributes.each{|arr|
      if(File.exists?("#{@scratch}/#{arr}/sorted_geneList"))
        file = File.open("#{@scratch}/#{arr}/sorted_geneList")
        Dir.chdir("#{@scratch}/#{arr}")
        fileW = File.open("sorted_geneList.temp", "w+")
        file.each {|gene|
          gene.chomp!
          c = gene.split(/\t/)
          fileW.puts "#{c[1]}\t#{c[0]}"
          }
        fileW.close
        file.close
        system("sort -k1n sorted_geneList.temp > sorted_geneList.xls")
        Dir.chdir(@scratch)
      end
    }
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

    @arrHash = Hash.new{|a,b| a[b] = Hash.new{|k,v| k[v] = []}}
    @db= nil
    @grp = nil
    @attributes.each{|arr|
      if(File.exists?("#{@scratch}/#{arr}/sorted_geneList.xls"))
        xattrVals = ""
        yattrVals = ""

        xyAttrValsPairHash = {}

        @escapedDatabasesList = Set.new()
        ##New parameter settings for creating atlas link. Reading track info from SET A
        file1 = File.open("#{@scratch}/tmpFile.txt")
        file1.each { |line|
          line.strip!
          # TODO: Maybe check if URI.parse() succeeds? Also, maybe do just once?
          path = URI.parse(line).path
          host = URI.parse(line).host
          # puts path
          $stderr.debugPuts(__FILE__, __method__, "Parsing input tracks", "line=|#{line}|  path=|#{path}| and host=#{host}") if (DEBUG_CC)

          path =~ /REST\/v1\/grp\/(.*)\/db\/(.*)\/trk/
          if (@db == nil) then
            @grp = $1
            @db = $2
            $stderr.debugPuts(__FILE__, __method__, "initializing for input score tracks the groups/databases", "group=#{@grp}  database=#{@db} ")
          elsif (@db !=$2 || @grp != $1) then
            $stderr.debugPuts(__FILE__, __method__, "input score tracks from different groups/databases", "prevGroup=#{@grp}  prevDb=#{@db} currentGoup=#{$1} currentDb=#{$2}")
            displayErrorMsgAndExit("Input score tracks were chosen from different groups/databases: previous group=#{@grp}  previous database=#{@db} current group=#{$1} current database=#{$2}")
          end
          rsrcPath = "#{path}?detailed=minDetails"
          rsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
          api = WrapperApiCaller.new(host,rsrcPath,@userId)
          api.get
          respHash = api.parseRespBody
          puts respHash
          xattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaAssayType"])},"
          yattrVals << "#{CGI.escape(respHash["data"]["attributes"]["eaSampleType"])},"
          $stderr.debugPuts(__FILE__, __method__, "respHash attributes", "#{CGI.escape(respHash["data"]["attributes"].keys.join("---"))}") if (DEBUG_CC)

          newXAttr = CGI.escape(respHash["data"]["attributes"]["eaAssayType"])
          newYAttr = CGI.escape(respHash["data"]["attributes"]["eaSampleType"])
          unless(newXAttr.nil? or newYAttr.nil? or newXAttr !~ /\S/ or newYAttr !~ /\S/)
            updateXYHash(newXAttr, newYAttr, xyAttrValsPairHash, xyAttrValsPairStruct)

            line =~  /^(.+\/db\/[^\/\?]+)/
            currentDb = $1
            if(@dbApiHelper.extractGbKey(line))
              currentDb <<"&gbKey=#{@dbApiHelper.extractGbKey(line)}" if(@dbApiHelper.extractGbKey(line))
            end
            @escapedDatabasesList.add(CGI.escape(currentDb))
          end
        }
        file1.close

        xattrVals.chomp!(",")
        yattrVals.chomp!(",")

        ##Building gene list for ATLAS
        #picking only top 10 genes
        counter = 0
        geneString10 = ""
        geneString5 = ""

        list = %x{cut -f2 #{@scratch}/#{arr}/sorted_geneList.xls}
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


        #httplLink5 = "http://#{@host}/epigenomeatlas/geneViewer.rhtml?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}"
        #httplLink5 << "&gbGridYAttr=eaSampleType&gbGridXAttr=eaAssayType&grpName=#{CGI.escape(@grp)}"
        #httplLink5 << "&dbName=#{CGI.escape(@db)}&geneNames=#{geneString5}"


        #httplLink10 = "http://#{@host}/epigenomeatlas/geneViewer.rhtml?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}"
        #httplLink10 << "&gbGridYAttr=eaSampleType&gbGridXAttr=eaAssayType&grpName=#{CGI.escape(@grp)}"
        #httplLink10 << "&dbName=#{CGI.escape(@db)}&geneNames=#{geneString10}"

        xyattrValsPair = getBrowserXYAttributes(xyAttrValsPairHash)
        xattrVals = xyattrValsPair[0]
        yattrVals = xyattrValsPair[1]

        httplLink5 =  "http://#{@host}/java-bin/multiGeneViewer.jsp?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}&gbGridYAttr=eaSampleType"
        httplLink5 << "&gbGridXAttr=eaAssayType&dbList=#{@escapedDatabasesList.to_a.join(",")}&geneNames=#{geneString5}"

        httplLink10 =  "http://#{@host}/java-bin/multiGeneViewer.jsp?xattrVals=#{xattrVals}&yattrVals=#{yattrVals}&gbGridYAttr=eaSampleType"
        httplLink10 << "&gbGridXAttr=eaAssayType&dbList=#{@escapedDatabasesList.to_a.join(",")}&geneNames=#{geneString10}"

        httplLinkFile= "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/#{arr}/sorted_geneList.xls"

        @arrHash[arr]["httplLink5"] = httplLink5
        @arrHash[arr]["httplLink10"] = httplLink10
        @arrHash[arr]["httplLinkFile"] = httplLinkFile


        # CC --> load gene ontology enrichment results onto the project page

        httpGeneCluster = nil
        httpTermCluster = nil
        httpFunctionalChart = nil
        httpFunctionalAnnotationTable = nil

        if (File.exists?("#{@inputDir}/DAVID/#{arr}/chartReport.xls")) then
          httpFunctionalChart = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/DAVID/#{arr}/chartReport.xls"
        end

        if (File.exists?("#{@inputDir}/DAVID/#{arr}/tableReport.xls")) then
          httpFunctionalAnnotationTable = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/DAVID/#{arr}/tableReport.xls"
        end

        if (File.exists?("#{@inputDir}/DAVID/#{arr}/geneClusterReport.xls")) then
          httpGeneCluster = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/DAVID/#{arr}/geneClusterReport.xls"
        end

        if (File.exists?("#{@inputDir}/DAVID/#{arr}/termClusterReport.xls")) then
          httpTermCluster = "/projects/#{CGI.escape(@projectName)}/genb%5E%5EadditionalPages/#{File.basename(@inputDir)}/DAVID/#{arr}/termClusterReport.xls"
        end

        @arrHash[arr]["httpTermCluster"] = httpTermCluster
        @arrHash[arr]["httpGeneCluster"] = httpGeneCluster
        @arrHash[arr]["httpFunctionalChart"] = httpFunctionalChart
        @arrHash[arr]["httpFunctionalAnnotationTable"] = httpFunctionalAnnotationTable

      end

    }

  end

  # Creates index html file
  # [+returns+] nil
  def writeIndexHtmlFile()
    @arrHash.each{|k,v|
      $stderr.debugPuts(__FILE__, __method__, "Building Atlas links", "for #{k} attribute")
      plotsIndexWriter = File.open("#{@scratch}/#{k}/plotsIndex.html", "w+")
      plotBuff = "<html>
                    <body style=\"background-color:#C6DEFF\">
                        <table cellspacing=\"0\" style=\"margin:10px auto 10px auto;\">
                          <tr>
                            <th colspan=\"1\" style=\"border-bottom:2px solid black;width:100%;\">Table of Content: Sample Centric Limma Analysis</th>
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
                           <a href=\'#{@arrHash[k]['httplLink5']}'\">Gene browser view of the top 5 genes overlapping with discriminating regions of interest </a>
                        </td>
                      </tr>
                      <tr>
                        <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@arrHash[k]['httplLink10']}'\">Gene browser view of the top 10 genes overlapping with discriminating regions of interest </a>
                        </td>
                      </tr>
                      <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                           <a href=\'#{@arrHash[k]['httplLinkFile']}'\">Ranked list of genes overlapping with discriminating features of interest </a>
                        </td>
                      </tr>
         "


         # CC --> add the links to the gene enrichment results


         if (@arrHash[k]["httpGeneCluster"] != nil) then
          plotBuff << "<tr>
                        <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                             <a href=\'#{@arrHash[k]["httpGeneCluster"]}'\">Gene clustering for genes overlapping with discriminating regions of interest</a>
                          </td>
                        </tr>"
        end

        if (@arrHash[k]["httpTermCluster"]!= nil) then
          plotBuff << "<tr>
                        <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                             <a href=\'#{@arrHash[k]["httpTermCluster"]}'\">Functional annotation clustering for genes overlapping with discriminating regions of interest</a>
                          </td>
                        </tr>"
        end

        if (@arrHash[k]["httpFunctionalChart"]!= nil) then
          plotBuff << "<tr>
                        <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                             <a href=\'#{@arrHash[k]["httpFunctionalChart"]}'\">Functional annotation chart for genes overlapping with discriminating regions of interest</a>
                          </td>
                        </tr>"
        end

        if (@arrHash[k]["httpFunctionalAnnotationTable"] != nil) then
          plotBuff << "<tr>
                        <td style=\"vertical-align:top;border-right:1px ;background-color:white\">
                             <a href=\'#{@arrHash[k]["httpFunctionalAnnotationTable"]}'\">Functional annotation table for genes overlapping with discriminating regions of interest</a>
                          </td>
                        </tr>"
        end


    # CC --> add the links to the enrichment results


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
    }

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
    @attributes = jsonObj["settings"]["attributesForLimma"]
    @studyName = CGI.escape(@studyName)
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    #@host = ApiCaller.getDomainAlias(dbrc.driver.split(/:/).last)
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
    @host     = uri.host

    resrH = BRL::Genboree::REST::Helpers::ApiUriHelper.new(@gbConfig)
    if(resrH.extractType(@inputs[0]) == "entityList")
      trackURI = uri
    else
      apicaller = WrapperApiCaller.new(@host,"#{@path1}?connect=true",@userId)
      apicaller.get
      trackURI = apicaller.parseRespBody["data"]["refs"][BRL::Genboree::REST::Data::DetailedTrackEntity::REFS_KEY]
    end

    @db  = @dbhelper.extractName(trackURI)
    @grp = @grph.extractName(trackURI)

    $stderr.debugPuts(__FILE__, __method__, "Preparing group and database for the tracks", "db=#{@db} and grp=#{@grp}") if (DEBUG_CC)

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
